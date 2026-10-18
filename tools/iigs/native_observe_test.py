#!/usr/bin/env python3
"""Execute profile-only native observer against independent slot-count fixtures."""
from pathlib import Path
import hashlib,json,struct,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/native-observe'
FIELDS='flags kind x_lo x_hi y_int sprite_ptr sprite_color sprite_attr'.split()
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 slots=[]
 for i in range(24):
  x=[0,1,343,344][i%4]; y=[29,30,249,250][i//4%4]
  slots.append(dict(flags=[0,1,2,3][i%4],kind=i%8,x_lo=x&255,x_hi=x>>8,y_int=y,sprite_ptr=248 if i==1 else 100+i,sprite_color=i,sprite_attr=i&1))
 # Independent mixed corners, rendered retiring/free flags, and unknown kinds.
 slots[0].update(flags=2,x_lo=1,y_int=30)
 slots[1].update(flags=3,x_lo=1,y_int=30)
 slots[2].update(flags=2,x_lo=87,x_hi=1,y_int=249)
 allocated=sum(bool(s['flags']&1) for s in slots)
 rendered=sum(bool(s['flags']&2) for s in slots)
 onscreen=sum(bool(s['flags']&2) and 1<=s['x_lo']+256*s['x_hi']<=343 and 30<=s['y_int']<=249 for s in slots)
 kinds=[sum(bool(s['flags']&2) and min(s['kind'],6)==k for s in slots) for k in range(7)]
 peak=b''.join(struct.pack('<8H',s['x_lo']+256*s['x_hi'],s['y_int'],s['sprite_ptr'],3 if s['sprite_ptr'] in (248,249) else 0,s['sprite_color'],s['sprite_attr'],s['kind'],s['flags']) for s in slots)
 lines=[' case on',' ALIGN 32768','observe_test START OBSERVETEST',' longa on',' longi on',' phb',' phd',' phk',' plb',' jsr ot_test',' pld',' plb',' rtl','game_mode equ 5',' copy src/iigs/observe.asm','game_dp dc i2\'8192\'','native_player_frame dc i2\'7\'','native_present dc i2\'1\'']
 for name in FIELDS:lines += [f'objects__obj_{name} dc h\''+bytes(s[name] for s in slots).hex()+"'"]
 lines += ['ot_test lda #4',' sta >$002005',' lda #$1000',' tcd',' lda #$0202',' pha',' plb',' plb',' tsc',' sta >ot_s',' lda #$1234',' ldx #$5678',' ldy #$cdef',' sed',' sec',' php',' jsl game_observe',' php',' pha',' txa',' sta >ot_x',' tya',' sta >ot_y',' pla',' sta >ot_a',' sep #$20',' longa off',' pla',' cmp 1,s',' beq ot_p_ok',' jmp ot_bad_p','ot_p_ok pla',' rep #$20',' longa on',' cld',' tsc',' cmp >ot_s',' beq ot_s_ok',' jmp ot_bad','ot_s_ok tdc',' cmp #$1000',' beq ot_d_ok',' jmp ot_bad','ot_d_ok phb',' sep #$20',' longa off',' pla',' cmp #2',' beq ot_b_ok',' rep #$20',' longa on',' jmp ot_bad','ot_b_ok rep #$20',' longa on',' phk',' plb']
 checks=[('ot_a',0x1234),('ot_x',0x5678),('ot_y',0xcdef),('game_obs_allocated',allocated),('game_obs_render',rendered),('game_obs_onscreen',onscreen),('game_obs_max_allocated',allocated),('game_obs_max_render',rendered),('game_obs_max_onscreen',onscreen),('game_obs_samples',1),('game_obs_peak_present',1),('game_obs_peak_mode',4),('game_obs_peak_player_frame',7),('game_obs_peak_sample',1)]+[(f'game_obs_kind_current+{i*2}',n) for i,n in enumerate(kinds)]+[(f'game_obs_kind_max+{i*2}',n) for i,n in enumerate(kinds)]
 for i,(name,value) in enumerate(checks):lines += [f' lda {name}',f' cmp #{value}',f' beq ot_ok_{i}',' jmp ot_bad',f'ot_ok_{i} anop']
 lines+=[' lda >$002005',' and #255',' cmp #4',' beq ot_mode_unchanged',' jmp ot_bad','ot_mode_unchanged ldx #0','ot_soa lda objects__obj_flags,x',' cmp ot_expected_soa,x',' beq ot_soa_ok',' jmp ot_bad','ot_soa_ok inx',' inx',' cpx #192',' bcc ot_soa',' ldx #0','ot_peak lda game_obs_peak_objects,x',' cmp ot_expected,x',' beq ot_peak_ok',' jmp ot_bad','ot_peak_ok inx',' inx',' cpx #384',' bcc ot_peak',' ldx #22',' lda #0','ot_retire sta objects__obj_flags,x',' dex',' dex',' bpl ot_retire',' lda #$ffff',' sta game_obs_samples',' jsl game_observe',' lda game_obs_allocated',' ora game_obs_render',' ora game_obs_onscreen',' ora game_obs_samples',' beq ot_empty_ok',' jmp ot_bad','ot_empty_ok lda game_obs_samples+2',' cmp #1',' beq ot_carry_ok',' jmp ot_bad','ot_carry_ok lda game_obs_max_render',f' cmp #{rendered}',' beq ot_max_kept',' jmp ot_bad','ot_max_kept lda game_obs_peak_sample',' cmp #1',' beq ot_peak_kept',' jmp ot_bad','ot_peak_kept lda #0',' rts','ot_bad_p pla',' rep #$20',' longa on','ot_bad cld',' phk',' plb',' lda #1',' rts','ot_a ds 2','ot_x ds 2','ot_y ds 2','ot_s ds 2','ot_expected_soa anop']+[" dc h'"+bytes(s[name] for s in slots).hex()+"'" for name in FIELDS]+['ot_expected anop']+[" dc h'"+peak[i:i+32].hex()+"'" for i in range(0,len(peak),32)]+[' END']
 (OUT/'test.s').write_text('\n'.join(lines)+'\n')
 (OUT/'reporter.c').write_text('#include <stdio.h>\nextern unsigned observe_test(void);\nint main(void){unsigned r=observe_test();printf("native observer selftest: %u\\n",r);return r;}\n')
 rel=OUT.relative_to(ROOT)
 commands=[['iix','assemble','+L','+S',str(rel/'test.s'),'keep='+str(rel/'test')],['iix','compile',str(rel/'reporter.c'),'keep='+str(rel/'reporter')],['iix','link',str(rel/'reporter'),str(rel/'test'),'keep='+str(rel/'observer-test')],['iix',str(rel/'observer-test')]]
 for i,cmd in enumerate(commands):
  r=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
  (OUT/f'step-{i}.log').write_text(r.stdout)
  if r.returncode:raise RuntimeError(r.stdout[-6000:])
 if r.stdout.strip()!='native observer selftest: 0':raise RuntimeError(r.stdout)
 paths=[ROOT/'src/iigs/observe.asm',Path(__file__).resolve(),OUT/'test.s',OUT/'observer-test']
 (OUT/'manifest.json').write_text(json.dumps(dict(scope='native diagnostic count/capture and caller ABI only; no game performance claim',allocated=allocated,render=rendered,onscreen=onscreen,kind_counts=kinds,hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}),indent=2)+'\n')
 print(r.stdout.strip())
if __name__=='__main__':main()
