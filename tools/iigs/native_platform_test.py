#!/usr/bin/env python3
"""Execute platform dispatch boundary with native stubs, not a performance gate."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/native-platform'
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    lines=[' case on',' ALIGN 32768','platform_test START PLATFORMTEST',' longa on',' longi on',' phb',' phd',' php',' rep #$30',' phk',' plb',' tdc',' sta debug_dp',' jsr pt_run',' sta >pt_result',' plp',' pld',' plb',' lda >pt_result',' rtl',' copy src/iigs/platform.asm','pt_run anop']
    # Per-case expected (clock calls,input calls,game calls,ticks,fault,quit).
    cases=[('idle',dict(pt_due=0),(1,0,0,0,0,0)),('due',dict(pt_due=1),(1,1,1,1,0,0)),('leave',dict(pt_due=1,input_leave_value=1),(1,1,0,0,0,1)),('inputfault',dict(pt_due=1,input_fault=1),(1,1,0,0,2,0)),('clockfault',dict(pt_due=1,pt_clock_error=1),(1,0,0,0,1,0)),('gamefault',dict(pt_due=1,game_status=1),(1,1,1,0,3,0)),('sticky',dict(pt_due=1,platform_fault=3),(0,0,0,0,3,0))]
    state='pt_due pt_clock_error pt_clock_calls pt_input_calls pt_snap_calls pt_decode_calls pt_game_calls platform_ticks platform_ticks+2 platform_fault platform_quit clock_fault input_fault input_leave_value game_status'.split()
    for n,(name,seed,expected) in enumerate(cases):
        for label in state:lines+=[' stz '+label]
        for label,value in seed.items():lines += [f' lda #{value}',' sta '+label]
        for label,value in [('dirs',10),('fire',1),('key_s',1),('key_i',0),('runstop',1)]:lines += [f' lda #{value}',' sta input_'+label+'_value']
        lines+=[' tsc',' sta pt_before_sp',' lda #$1000',' tcd',' pea $0404',' plb',' plb',' lda #$1234',' ldx #$5678',' ldy #$2345',' sed',' sec',' jsl platform_service',' php',' sta >pt_seen_a',' txa',' sta >pt_seen_x',' tya',' sta >pt_seen_y',' phb',' sep #$20',' longa off',' pla',' sta >pt_seen_db',' pla',' rep #$20',' longa on',' and #9',' sta >pt_seen_p',' cld',' tdc',' sta >pt_seen_dp',' phk',' plb',' lda debug_dp',' tcd',' tsc',' cmp pt_before_sp',f' beq pt_sp_ok_{n}',f' lda #{950+n}',' rts',f'pt_sp_ok_{n} anop']
        checks=[('pt_seen_a',0x1234),('pt_seen_x',0x5678),('pt_seen_y',0x2345),('pt_seen_p',9),('pt_seen_dp',0x1000),('pt_seen_db',4)]
        checks+=list(zip(['pt_clock_calls','pt_input_calls','pt_game_calls','platform_ticks','platform_fault','platform_quit'],expected))
        checks += [('pt_snap_calls',expected[1]),('pt_decode_calls',expected[1])]
        for i,(label,value) in enumerate(checks):lines += [' lda '+label,f' cmp #{value}',f' beq pt_ok_{n}_{i}',f' lda #{100*n+i+1}',' rts',f'pt_ok_{n}_{i} anop']
        if name=='due':
            lines += [' sep #$20',' longa off']
            for i,(label,value) in enumerate([('dirs',10),('fire',1),('key_s',1),('key_i',0),('runstop',1)]):
                lines+=[' lda game_input_'+label,f' cmp #{value}',f' beq pt_mail_ok_{i}',' rep #$20',' longa on',f' lda #{900+i}',' rts',f'pt_mail_ok_{i} anop',' longa off']
            lines+=[' rep #$20',' longa on']
    lines+=[' lda #0',' rts','clock_due inc pt_clock_calls',' lda pt_clock_error',' sta clock_fault',' lda pt_due',' rts','input_poll inc pt_input_calls',' rts','input_snapshot inc pt_snap_calls',' rts','input_decode inc pt_decode_calls',' rts','game_tick inc pt_game_calls',' lda #$ffff',' ldx #$abcd',' ldy #$cdef',' sec',' rtl']
    words='debug_dp clock_fault input_fault input_leave_value input_dirs_value input_fire_value input_key_s_value input_key_i_value input_runstop_value game_status pt_due pt_clock_error pt_clock_calls pt_input_calls pt_snap_calls pt_decode_calls pt_game_calls pt_seen_a pt_seen_x pt_seen_y pt_seen_p pt_seen_dp pt_seen_db pt_before_sp pt_result'.split()
    lines += [label+' ds 2' for label in words]
    lines += [label+' ds 1' for label in ['game_input_'+k for k in ('dirs','fire','key_s','key_i','runstop')]]+[' END']
    (OUT/'test.s').write_text('\n'.join(lines)+'\n')
    (OUT/'reporter.c').write_text('#include <stdio.h>\nextern unsigned platform_test(void);\nint main(void){unsigned r=platform_test();printf("native platform dispatch: %u\\n",r);return r!=0;}\n')
    commands=[['iix','assemble','+L','+S','build/iigs/native-platform/test.s','keep=build/iigs/native-platform/test'],['iix','compile','build/iigs/native-platform/reporter.c','keep=build/iigs/native-platform/reporter'],['iix','link','build/iigs/native-platform/reporter','build/iigs/native-platform/test','keep=build/iigs/native-platform/test-app'],['iix','build/iigs/native-platform/test-app']]
    for i,cmd in enumerate(commands):
        result=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
        (OUT/f'step-{i}.log').write_text(result.stdout)
        if result.returncode:raise RuntimeError(result.stdout[-5000:])
    assert result.stdout.strip()=='native platform dispatch: 0',result.stdout
    paths=[Path(__file__).resolve(),ROOT/'src/iigs/platform.asm',OUT/'test.s',OUT/'test-app']
    (OUT/'manifest.json').write_text(json.dumps(dict(scope=__doc__,cases=[c[0] for c in cases],commands=commands,hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}),indent=2)+'\n')
    print(result.stdout.strip())
if __name__=='__main__':main()
