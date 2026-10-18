#!/usr/bin/env python3
"""Execute shipping colour routines: cadence, wrap, two writes and final rows."""
import json
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'build/iigs/native-highscore-color-test'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lines = [' case on', 'hs_test START', ' longa on', ' longi on',
             ' phb', ' phk', ' plb', ' jsr test_run', ' plb', ' rtl',
             'test_run sep #$30', ' longa off', ' longi off']
    checks = []
    def emit(text): lines.extend(text.splitlines())
    def expect(operand, value):
        n = len(checks) + 1
        checks.append([operand, value])
        emit(f' lda {operand}\n cmp #{value}\n beq test_ok_{n}\n rep #$30\n longa on\n longi on\n lda #{n}\n rts\n longa off\n longi off\ntest_ok_{n} anop')
    emit(' stz score_color_phase\n stz score_color_tick\n stz test_calls\n ldx #24\n lda #99\ntest_clear sta test_rows,x\n dex\n bpl test_clear\n jsr title_text_color_scores')
    expect('test_calls', 11)
    for step in range(21):
        row = step % 10
        for y in range(25):
            expect(f'test_rows+{y}', 7 if y == 5 + row else 15 if 5 <= y < 15 else 99)
        # Nine idle ticks produce no stores; the tenth restores old and paints new.
        emit(' stz test_calls')
        for _ in range(9): emit(' jsr title_text_rotate_colors')
        expect('test_calls', 0)
        emit(' jsr title_text_rotate_colors')
        expect('test_calls', 2)
        expect('test_old_row', 5 + row)
        expect('test_new_row', 5 + (row + 1) % 10)
    # Hold refresh restores cursor colours too, with the same selected row.
    emit(' stz test_calls\n jsr title_text_color_scores')
    expect('test_calls', 11)
    emit(' rep #$30\n longa on\n longi on\n lda #0\n rts\nSCORE_COLOR_PERIOD equ 10\nHS_ROW_SCORE0 equ 5\nCOL_LT_GRAY equ 15\nCOL_YELLOW equ 7\n copy src/iigs/highscore_color.asm')
    # Match the real painter clobbers: X=0, Y=40, A=colour; record every write.
    emit('screen_color_row sta test_rows,y\n pha\n tya\n ldx test_calls\n bne test_second\n sta test_old_row\n bra test_recorded\ntest_second sta test_new_row\ntest_recorded inc test_calls\n pla\n ldx #0\n ldy #40\n rts')
    for name, size in [('score_color_phase',1),('score_color_tick',1),('draw_i',1),('test_calls',1),('test_old_row',1),('test_new_row',1),('test_rows',25)]:
        emit(f'{name} ds {size}')
    emit(' END')
    (OUT/'test.s').write_text('\n'.join(lines)+'\n')
    (OUT/'reporter.c').write_text('#include <stdio.h>\nextern unsigned hs_test(void);\nint main(void){unsigned r=hs_test();printf("highscore colour: %u\\n",r);return r;}\n')
    commands = [['iix','assemble',str(OUT/'test.s'),'keep='+str(OUT/'assembly')], ['iix','compile',str(OUT/'reporter.c'),'keep='+str(OUT/'reporter')], ['iix','link',str(OUT/'reporter'),str(OUT/'assembly'),'keep='+str(OUT/'test')], ['iix',str(OUT/'test')]]
    for i, cmd in enumerate(commands):
        p = subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
        (OUT/f'{i}.log').write_text(p.stdout)
        if p.returncode: raise RuntimeError(p.stdout[-4000:])
    assert p.stdout.strip() == 'highscore colour: 0', p.stdout
    (OUT/'result.json').write_text(json.dumps(dict(passed=True,assertions=len(checks),scope=__doc__),indent=2)+'\n')
    print(f'Native high-score colours: {len(checks)} assertions PASS')


if __name__ == '__main__': main()
