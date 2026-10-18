#!/usr/bin/env python3
"""Actual native exact-length copy kernel test; destination redirected to test RAM.
Physical E1 status/beam proof remains the standalone emulator gate.
"""
from pathlib import Path
import subprocess,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/iigs/native-renderer/commit'
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 source=(ROOT/'src/iigs/render_commit.asm').read_text().replace('>$e12000','>ct_output')
 (OUT/'kernel.s').write_text(source)
 lines=[' case on',' ALIGN 32768','commit_test START COMMITTEST',' longa on',' longi on',' phb',' phk',' plb',' jsr ct_test',' plb',' rtl',f' copy {OUT}/kernel.s','ct_test lda #1',' sta rw_mode',' sta rw_admitted',' stz ct_n','ct_case inc ct_n',' ldx #0','ct_fill txa',' eor #$569a',' sta >rr_candidate,x',' lda #$a5a5',' sta >ct_output,x',' inx',' inx',' cpx #32000',' bcc ct_fill',' lda #3999',' sta rd_boundary',' lda #4001',' sta rd_boundary+2',' lda #0',' sta >rd_spans_a+23994',' lda ct_n',' asl a',' sta ct_length',' sta rd_strip_words',' sta >rd_spans_a+23996',' sta >rd_spans_b+2',' lda #32000',' sec',' sbc ct_length',' sta ct_end',' sta >rd_spans_b',' stz rw_strip',' stz rw_words',' stz rw_spans',' php',' sei',' jsr rw_copy_strip',' plp',' cmp #0',' bne ct_fail',' lda rw_spans',' cmp #2',' bne ct_fail',' lda ct_n',' asl a',' cmp rw_words',' bne ct_fail',' ldx #0','ct_verify txa',' cmp ct_length',' bcc ct_changed',' cmp ct_end',' bcs ct_changed',' lda #$a5a5',' bra ct_compare','ct_changed txa',' eor #$569a','ct_compare cmp >ct_output,x',' bne ct_fail',' inx',' inx',' cpx #32000',' bcc ct_verify',' lda ct_n',' cmp #80',' bcs ct_pass',' jmp ct_case','ct_pass lda #0',' rts','ct_fail lda ct_n',' rts','ct_n ds 2','ct_length ds 2','ct_end ds 2','rd_boundary ds 52','rd_strip_words ds 50',' END',' ALIGN 32768','CAND START CAND','rr_candidate ENTRY',' ds 32000',' END',' ALIGN 32768','CTOUT START CTOUT','ct_output ENTRY',' ds 32000',' END',' ALIGN 32768','SPANA START SPANA','rd_spans_a ENTRY',' ds 24000',' END',' ALIGN 32768','SPANB START SPANB','rd_spans_b ENTRY',' ds 24000',' END']
 (OUT/'test.s').write_text('\n'.join(lines)+'\n')
 (OUT/'reporter.c').write_text('#include <stdio.h>\nextern unsigned commit_test(void);\nint main(void){unsigned r=commit_test();printf("native copy kernel: %u\\n",r);return r;}\n')
 commands=[['iix','assemble','+L','+S',str(OUT/'test.s'),'keep='+str(OUT/'test')],['iix','compile',str(OUT/'reporter.c'),'keep='+str(OUT/'reporter')],['iix','link',str(OUT/'reporter'),str(OUT/'test'),'keep='+str(OUT/'copy-test')],['iix',str(OUT/'copy-test')]]
 for i,cmd in enumerate(commands):
  p=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120);(OUT/f'step-{i}.log').write_text(p.stdout)
  if p.returncode:raise RuntimeError(p.stdout[-2000:])
 assert p.stdout.strip()=='native copy kernel: 0',p.stdout
 paths=[Path(__file__).resolve(),ROOT/'src/iigs/render_commit.asm',OUT/'test.s',OUT/'kernel.s',OUT/'copy-test']
 (OUT/'manifest.json').write_text(json.dumps(dict(scope=__doc__,lengths=80,spans=160,banks=[3999,4000],compared_bytes=80*32000,hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}),indent=2)+'\n');print(p.stdout.strip())
if __name__=='__main__':main()
