#!/usr/bin/env python3
"""Exhaustive actual-65816 one-row rectangle masks (not an E1 timing test)."""
from pathlib import Path
import json
import hashlib
import subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/native-damage-opt'
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    source=''' case on
 ALIGN 32768
damage_test START DAMAGEOPT
 longa on
 longi on
 phb
 phk
 plb
 jsr rt_test
 plb
 rtl
 copy src/iigs/render_damage.asm
rt_test stz rt_left
rt_left_loop lda rt_left
 sta rt_right
rt_right_loop jsr rd_clear
 ldx #8
rt_zero stz rt_expected,x
 dex
 dex
 bpl rt_zero
 stz rt_col
 stz rt_byte
 lda #1
 sta rt_mask
rt_ref lda rt_col
 cmp rt_left
 bcc rt_clean
 cmp rt_right
 bcs rt_clean
 ldx rt_byte
 sep #$20
 longa off
 lda rt_expected,x
 ora rt_mask
 sta rt_expected,x
 rep #$20
 longa on
rt_clean asl rt_mask
 lda rt_mask
 cmp #256
 bcc rt_mask_ok
 lda #1
 sta rt_mask
 inc rt_byte
rt_mask_ok inc rt_col
 lda rt_col
 cmp #80
 bcc rt_ref
 lda rt_left
 sta rd_left
 lda rt_right
 sta rd_right
 lda #199
 sta rd_top
 lda #200
 sta rd_bottom
 jsr rd_mark
 cmp #0
 bne rt_bad
 ldx #0
rt_check lda rd_bitmap+1990,x
 cmp rt_expected,x
 bne rt_bad
 inx
 inx
 cpx #10
 bcc rt_check
 inc rt_cases
 inc rt_right
 lda rt_right
 cmp #81
 bcs rt_next_left
 jmp rt_right_loop
rt_next_left anop
 inc rt_left
 lda rt_left
 cmp #81
 bcs rt_done
 jmp rt_left_loop
rt_done anop
 lda rt_cases
 cmp #3321
 bne rt_bad
 lda #0
 rts
rt_bad lda #1
 rts
render_service rts
rt_expected ds 10
rt_left ds 2
rt_right ds 2
rt_col ds 2
rt_byte ds 2
rt_mask ds 2
rt_cases ds 2
 END
 copy src/iigs/render_storage.asm
'''
    (OUT/'test.s').write_text(source)
    (OUT/'reporter.c').write_text('#include <stdio.h>\nextern unsigned damage_test(void);\nint main(void) {unsigned r=damage_test(); printf("3321 native rectangle masks: %u\\n",r); return r;}\n')
    rel=OUT.relative_to(ROOT)
    commands=[['iix','assemble','+L','+S',str(rel/'test.s'),'keep='+str(rel/'test')],['iix','compile',str(rel/'reporter.c'),'keep='+str(rel/'reporter')],['iix','link',str(rel/'reporter'),str(rel/'test'),'keep='+str(rel/'test-run')],['iix',str(rel/'test-run')]]
    for i,cmd in enumerate(commands):
        r=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
        (OUT/f'step-{i}.log').write_text(r.stdout)
        if r.returncode:raise RuntimeError(r.stdout[-5000:])
    assert r.stdout.strip()=='3321 native rectangle masks: 0',r.stdout
    paths=[ROOT/'src/iigs/render_damage.asm',Path(__file__).resolve(),OUT/'test.s',OUT/'test-run']
    (OUT/'manifest.json').write_text(json.dumps(dict(scope='actual 65816 exhaustive X-range marking, no E1 timing claim',cases=3321,hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}),indent=2)+'\n')
    print(r.stdout.strip())
if __name__=='__main__':main()
