#!/usr/bin/env python3
"""Host-only C gameplay oracle for native assembly tests; no IIgs C runtime.

Snapshots name semantic fields, never compiler-dependent Game bytes. Audio is
explicitly excluded. Pointer state uses table IDs/offsets. Native tests supply a
separate exported map and compare only the declared implemented module group.
"""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/iigs/native-oracle'
AUDIO_PREFIXES = ('mus_', 'sfx_', 'sid_')


def declarations(header, tag):
    text = re.sub(r'/\*.*?\*/', '', header.read_text(), flags=re.S)
    body = text.split('typedef struct ' + tag + ' {', 1)[1].split('} ' + tag + ';', 1)[0]
    return [part.strip() for part in body.split(';') if part.strip()]


def generated_fields():
    lines, excluded = [], []
    for declaration in declarations(ROOT / 'src/core/sim.h', 'Game'):
        match = re.fullmatch(r'(uint8_t|uint16_t|uint32_t)\s+(\w+)(\[[^]]+\])?', declaration)
        if match:
            kind, name, array = match.groups()
            if name == 'music_active' or name.startswith(AUDIO_PREFIXES):
                excluded.append(name)
                continue
            if array and kind != 'uint8_t':
                raise ValueError('Add semantic vector support for ' + declaration)
            lines.append(('RG_ARRAY' if array else 'RG_SCALAR') + '(' + name + ',' + kind + ')')
        elif declaration in ('Cell cells[SCREEN_H][SCREEN_W]', 'Object objects[OBJECT_CAPACITY]', 'const char *type_src'):
            continue
        else:
            raise ValueError('Unrecognized Game field: ' + declaration)
    for declaration in declarations(ROOT / 'src/core/objects.h', 'Object'):
        match = re.fullmatch(r'uint8_t\s+(\w+)', declaration)
        if not match:
            raise ValueError('Unrecognized Object field: ' + declaration)
        lines.append('RG_OBJECT(' + match[1] + ')')
    lines += ['RG_CELL(glyph)', 'RG_CELL(color)']
    return '\n'.join(lines) + '\n', excluded


def build(authority='c'):
    if authority not in ('c','c64'):
        raise ValueError('Unknown gameplay authority: '+authority)
    out=OUT if authority=='c' else ROOT/'build/iigs/native-oracle-c64'
    out.mkdir(parents=True, exist_ok=True)
    fields, excluded = generated_fields()
    include = out / 'native_oracle_fields.inc'
    include.write_text(fields)
    source = ROOT / 'tst/iigs/native_oracle.c'
    core_sources = sorted(path for path in (ROOT / 'src/core').rglob('*.c') if path.name != 'main.c')
    overrides=[]
    authority_inputs=[]
    if authority=='c64':
        original=ROOT/'src/core/drones.c'
        assembly=ROOT/'src/c64/game/drones.asm'
        expected_assembly_sha='dee9778767fcde8d50c55f132ccf8c557a695749619abacb592cf343ab219efa'
        if hashlib.sha256(assembly.read_bytes()).hexdigest()!=expected_assembly_sha:
            raise RuntimeError('C64 roll_quad authority binding changed; re-audit the documented host override')
        before="""        if (i == g->spawn_last_quad && count != 0 && count_quad_bits(g) >= 2) {
            continue;
        }"""
        after=before.replace('continue;', 'break;')
        text=original.read_text()
        if text.count(before)!=1:
            raise RuntimeError('C roll_quad authority hook no longer matches exactly once')
        adapted=out/'drones-c64-authority.c'
        adapted.write_text('/* Host test only: preserve original C64 roll_quad X clobber. */\n'+text.replace(before,after))
        core_sources=[adapted if path==original else path for path in core_sources]
        overrides.append(dict(id='roll_quad_count_helper_clobbers_x',
            scope='active spawning choice; not a snapshot exclusion',
            reason='C64 count_quad_bits returns X=4; skip path does not restore it; rq_next increments X to5 and ends scan',
            source='src/c64/game/drones.asm', source_sha256=expected_assembly_sha,
            original_c='src/core/drones.c', generated=str(adapted.relative_to(ROOT)),
            before=before, after=after))
        authority_inputs += [assembly,adapted]
        # The native source shares one banner span and clears death caches at
        # player init. Preserve those original state semantics explicitly.
        for unit,asm_name,pinned,hooks in [
            ('rail','rail','543ed9a17795b02992bb889e8d091a05242d8e0800e83750a114a3f79a540916',[
                ('rail_reset_preserves_strike_scratch',
                 '    g->rail_dmg_amt = 0;\n    g->rail_hit_left = 0;\n    g->rail_hit_slot = 0xFF;\n}',
                 '}')]),
            ('player','player','5b9b7927b65e619349ca7e63db1aa87184bc057630daf183f6122db0f8eb51dd',[
                ('player_init_clears_death_caches',
                 '    g->player_dead = 0;\n    g->player_was_centre = 0;',
                 '    g->player_dead = 0;\n    g->death_phase = 0;\n    g->death_timer = 0;\n    g->death_fatal = 0;\n    g->death_flash = 0;\n    g->death_flash_t = 0;\n    g->player_was_centre = 0;')])]:
            original=ROOT/('src/core/'+unit+'.c');assembly=ROOT/('src/c64/game/'+asm_name+'.asm')
            if hashlib.sha256(assembly.read_bytes()).hexdigest()!=pinned:
                raise RuntimeError('C64 '+unit+' authority binding changed; re-audit overrides')
            text=original.read_text()
            for ident,before,after in hooks:
                if text.count(before)!=1:raise RuntimeError('C64 authority hook must match once: '+ident)
                text=text.replace(before,after)
                overrides.append(dict(id=ident,scope='original C64 state semantics; no snapshot exclusion',
                    source=str(assembly.relative_to(ROOT)),source_sha256=pinned,
                    original_c=str(original.relative_to(ROOT)),before=before,after=after))
            if unit=='player':
                for field in ('col','len'):
                    before='g->death_banner_'+field;after='g->banner_'+field
                    count=text.count(before)
                    if count!=dict(col=3,len=2)[field]:raise RuntimeError('C64 shared banner hook changed: '+field)
                    text=text.replace(before,after)
                    overrides.append(dict(id='shared_death_banner_'+field,scope='active color-span behavior',
                        source=str(assembly.relative_to(ROOT)),source_sha256=pinned,
                        original_c=str(original.relative_to(ROOT)),before=before,after=after,matches=count))
            adapted=out/(unit+'-c64-authority.c');adapted.write_text('/* Host-only original C64 state semantics. */\n'+text)
            core_sources=[adapted if path==original else path for path in core_sources]
            authority_inputs += [assembly,adapted]
        # After all type/header definitions, alias accessors/setters to the same
        # actual fields. Stringified public field names and schema stay stable.
        text=source.read_text()
        before='static Game game;'
        if text.count(before)!=1:raise RuntimeError('Oracle shared-banner insertion anchor changed')
        text=text.replace(before,'#define death_banner_col banner_col\n#define death_banner_len banner_len\n'+before)
        text=text.replace('#include "../../src/core/main.c"','#include "'+str(ROOT/'src/core/main.c')+'"')
        adapted=out/'oracle-c64-authority.c';adapted.write_text(text)
        authority_inputs += [source,adapted]
        source=adapted
    compiler = shutil.which('cc')
    if not compiler:
        raise RuntimeError('Host C compiler cc is required for the optional oracle')
    binary = out / 'oracle'
    command = [compiler, '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror',
               '-I' + str(ROOT / 'src/core'), '-I' + str(out), str(source)]
    command += [str(path) for path in core_sources] + ['-o', str(binary)]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=120)
    (out / 'compile.log').write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(result.stderr)
    schema = json.loads(subprocess.check_output([str(binary), '--schema'], text=True))
    (out / 'schema.json').write_text(json.dumps(schema, indent=2) + '\n')
    inputs = [source, Path(__file__).resolve(), include]
    if authority=='c64':inputs += authority_inputs
    inputs += sorted((ROOT / 'src/core').rglob('*.c')) + sorted((ROOT / 'src/core').rglob('*.h'))
    manifest = dict(scope='host-only semantic oracle; no C code linked in native IIgs executable',
                    normalization=1, authority=authority, authority_overrides=overrides, command=command, host_machine=platform.machine(),
                    excluded_audio_fields=excluded, schema=schema,
                    binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                    hashes={str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs})
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return binary, manifest


def run_commands(commands, each_tick=False, binary=None):
    if binary is None:
        binary, _ = build()
    result = subprocess.run([str(binary)] + (['--each-tick'] if each_tick else []),
                            input=commands, text=True, capture_output=True, timeout=120)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return [json.loads(line) for line in result.stdout.splitlines()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    inputs = parser.add_mutually_exclusive_group()
    inputs.add_argument('--trace', type=Path, help='Existing tst/core trace; ignores its expected-output section')
    inputs.add_argument('--commands-file', type=Path, help='Oracle commands; use - for stdin')
    parser.add_argument('--authority',choices=['c','c64'],default='c',help='C64 applies explicit audited host-only behavior overrides; C remains the default')
    parser.add_argument('--each-tick', action='store_true', help='Emit a full semantic snapshot after every logic tick')
    parser.add_argument('--output', type=Path, help='Write JSON lines here instead of stdout')
    parser.add_argument('--schema', action='store_true')
    parser.add_argument('--build-only', action='store_true')
    args = parser.parse_args()
    binary, manifest = build(args.authority)
    if args.schema:
        print(json.dumps(manifest['schema'], indent=2))
        return
    if args.build_only or not (args.trace or args.commands_file):
        print(json.dumps(dict(binary=str(binary), fields=len(manifest['schema']),
                              excluded_audio_fields=manifest['excluded_audio_fields'])))
        return
    if args.trace:
        commands = args.trace.read_text().partition('\n===\n')[0]
    else:
        commands = sys.stdin.read() if str(args.commands_file) == '-' else args.commands_file.read_text()
    records = run_commands(commands.rstrip('\n') + '\n', args.each_tick, binary)
    output = ''.join(json.dumps(record, separators=(',', ':')) + '\n' for record in records)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output)
    else:
        print(output, end='')


if __name__ == '__main__':
    main()
