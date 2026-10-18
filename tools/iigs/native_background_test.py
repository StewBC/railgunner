#!/usr/bin/env python3
"""Rebuild native glyph oracle with six paired-background comparison regressions.

The C reporter is test-only. Golden Gate executes shipping 65816 routines;
this checks pixels/damage, and makes no E1 or physical timing claim.
"""
from pathlib import Path
from types import SimpleNamespace
import hashlib
import json
import subprocess
import native_render_glyph_test as glyph

CASES = [
    ('glyphs', [0], 1),
    ('glyphs', [1], 2),
    ('glyphs', [38, 39], 4),
    ('colors', [0], 128),
    ('colors', [1], 64),
    ('colors', [998, 999], 16),
]


def main():
    out = glyph.ROOT / 'build/iigs/native-background-opt'
    original_out, original_subprocess = glyph.OUT, glyph.subprocess
    injected = False

    def run(command, **kwargs):
        nonlocal injected
        if command[:2] == ['iix', 'assemble'] and not injected:
            injected = True
            path = out / 'test.s'
            source = path.read_text()
            # Exercise the hot loop across real service calls with X/Y/A/flags
            # deliberately clobbered by the platform callback. The service
            # wrapper must preserve its caller's scan cursor and batch counter.
            start = 'gt_test ldx #0'
            callback = 'renderer_platform_service rtl'
            if source.count(start) != 1 or source.count(callback) != 1:
                raise RuntimeError('Glyph service fixture anchor changed')
            source = source.replace(start, 'gt_test lda #1\n sta render_service_enabled\n ldx #0')
            source = source.replace(callback, 'renderer_platform_service ldx #$abcd\n ldy #$5678\n lda #$1234\n sec\n rtl')
            extra = []
            for n, (plane, cells, mask) in enumerate(CASES):
                # Publish the previous complete candidate before changing it.
                extra += [' jsr rc_publish', ' lda #1', ' sta rc_pending']
                for cell in cells:
                    extra += [' sep #$20', ' longa off',
                              f' lda rc_candidate_{plane}+{cell}',
                              f' eor #{mask}',
                              f' sta rc_candidate_{plane}+{cell}',
                              ' rep #$20', ' longa on']
                extra += [' jsr rb_prepare', ' lda rb_changed',
                          f' cmp #{len(cells)}', f' beq gt_pair_changed_{n}',
                          ' jmp gt_fail', f'gt_pair_changed_{n} jsr rd_emit',
                          ' lda rd_words', f' cmp #{16 * len(cells)}',
                          f' beq gt_pair_words_{n}', ' jmp gt_fail',
                          f'gt_pair_words_{n} anop']
            anchor = 'gt_background_one_spans anop'
            if source.count(anchor) != 1:
                raise RuntimeError('Glyph generator insertion anchor changed')
            path.write_text(source.replace(anchor, anchor + '\n' + '\n'.join(extra)))
        return subprocess.run(command, **kwargs)

    try:
        glyph.OUT = out
        # Isolate the generator's runner; do not modify subprocess globally.
        glyph.subprocess = SimpleNamespace(run=run, PIPE=subprocess.PIPE,
                                          STDOUT=subprocess.STDOUT)
        glyph.main()
    finally:
        glyph.OUT, glyph.subprocess = original_out, original_subprocess
    if not injected:
        raise RuntimeError('Native background fixtures were not assembled')
    manifest_path = out / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    manifest['paired_comparison_cases'] = [
        dict(plane=plane, cells=cells, xor_mask=mask,
             expected_changed=len(cells), expected_damage_words=16 * len(cells))
        for plane, cells, mask in CASES
    ]
    path = Path(__file__).resolve()
    manifest['hashes'][str(path.relative_to(glyph.ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print('native background paired regressions: 6 passed')


if __name__ == '__main__':
    main()
