#!/usr/bin/env python3
"""Calibrate named-field snapshots against the existing, tested host driver."""
import hashlib
import json
from pathlib import Path
import subprocess
import native_oracle as oracle


def main():
    subprocess.run(['make', 'core'], cwd=oracle.ROOT, check=True)
    binary, manifest = oracle.build()
    results = []
    for trace in sorted((oracle.ROOT / 'tst/core').glob('*.trace')):
        commands = trace.read_text().partition('\n===\n')[0].rstrip('\n') + '\n'
        snapshots = [row for row in oracle.run_commands(commands, binary=binary) if row['kind'] == 'snapshot']
        reference = subprocess.run([str(oracle.ROOT / 'build/railgunner-core'), '/dev/stdin'],
                                   input=commands, text=True, capture_output=True, check=True).stdout
        dumps = [('frame ' + part if i else part).splitlines()
                 for i, part in enumerate(reference.split('\nframe '))]
        assert len(snapshots) == len(dumps), trace
        for state, lines in zip(snapshots, dumps):
            assert set(state) == set(manifest['schema']) | {'kind', 'normalization'}, trace
            for name, field in manifest['schema'].items():
                values = state[name] if isinstance(state[name], list) else [state[name]]
                assert len(values) == field['count'], (trace, name)
                assert all(isinstance(v, int) and 0 <= v < 1 << (field['width'] * 8) for v in values), (trace, name)
            assert state['type_src_id'] in (0, 1, 2), trace
            for line in lines:
                tokens = line.split()
                if tokens[:1] == ['frame']: assert state['frame'] == int(tokens[1]), trace
                if tokens[:1] == ['mode']: assert state['mode'] == int(tokens[1]), trace
                if tokens[:1] == ['free']: assert state['free_count'] == int(tokens[1]), trace
                if tokens[:1] == ['score']: assert [state[n] for n in ('score0', 'score1', 'score2')] == list(map(int, tokens[1:])), trace
            cells = ['cell %d %d %d %d' % (i // 40, i % 40, glyph, state['cells.color'][i])
                     for i, glyph in enumerate(state['cells.glyph']) if glyph not in (0, 32)]
            assert cells == [line for line in lines if line.startswith('cell ')], trace
            objects = []
            for i, flags in enumerate(state['objects.flags']):
                if flags:
                    values = [i, flags] + [state['objects.' + n][i] for n in ('kind', 'x_hi', 'x_lo', 'y_int', 'sprite_ptr', 'reserved')]
                    objects.append('obj ' + ' '.join(map(str, values)))
            assert objects == [line for line in lines if line.startswith('obj ')], trace
        results.append(dict(trace=str(trace.relative_to(oracle.ROOT)), sha256=hashlib.sha256(trace.read_bytes()).hexdigest(), snapshots=len(snapshots)))
    commands = 'bare\ncall objects_init\n' + 'call objects_alloc\n' * 24 + 'dump\n'
    rows = oracle.run_commands(commands, binary=binary)
    assert [row['slot'] for row in rows[:23]] == list(range(1, 24))
    assert rows[23]['status'] != 0 and rows[23]['slot'] == 255
    assert rows[-1]['free_count'] == 0
    rows = oracle.run_commands('bare\nset frame_count 0 255\ntick\nset tally_shots 0 65534\ncall tallies_note_shot\ncall tallies_note_shot\ntype-source 1 5\ndump\n', binary=binary)
    assert rows[-1]['frame_count'] == 0 and rows[-1]['tally_shots'] == 65535
    assert rows[-1]['type_src_id'] == 1 and rows[-1]['type_src_offset'] == 5
    result = dict(scope='host oracle calibration; no native assembly comparison yet',
                  fields=len(manifest['schema']), traces=results,
                  oracle_binary_sha256=manifest['binary_sha256'])
    result['pass'] = True
    result['helper_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    (oracle.OUT / 'calibration.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Host named-field oracle: %d traces, %d snapshots, %d fields PASS' %
          (len(results), sum(row['snapshots'] for row in results), len(manifest['schema'])))


if __name__ == '__main__':
    main()
