#!/usr/bin/env python3
"""Execute the real native region waits and exposure accounting with scripted rasters.
Hardware scan-time stability is separately measured by native_continuous_profile.
"""
import json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/native-beam-schedule-test'

def main():
 OUT.mkdir(parents=True,exist_ok=True)
 lines=[' case on','beam_test START',' longa on',' longi on',' phb',' phk',' plb',' jsr test_run',' plb',' rtl','test_run anop']
 assertions=[]
 def emit(s):lines.extend(s.splitlines())
 def put(n,v):emit(f' lda #{v}\n sta {n}')
 def expect(n,v):
  i=len(assertions)+1;assertions.append((n,v))
  emit(f' lda {n}\n cmp #{v}\n beq test_ok_{i}\n lda #{i}\n rts\ntest_ok_{i} anop')
 # Each script ends at a legal release. Early/late phase, exact bottom, and wrap.
 sequences=[]
 for strip,seq in [(0,[8]),(0,[7,8]),(0,[136,261,0,7,8]),(12,[90,103,104]),(24,[199,200]),(24,[261]),(24,[0]),(24,[65]),(24,[66,199,200]),(0,[135])]:
  label=f'test_rasters_{len(sequences)}';sequences.append((label,seq))
  put('test_raster_read+1',label);put('test_raster_cursor',0);put('rw_strip',strip)
  emit(' jsr beam_wait_strip');expect('test_raster_cursor',2*len(seq))
 # First lower-bound crossing; a crossing during late work grants immediately.
 put('rc_displayed_mode',3);put('clock_line',200);put('clock_time',200)
 emit(' jsr beam_prepare_window');expect('beam_prepare_next',462)
 put('clock_line',238);put('clock_time',500)
 emit(' jsr beam_prepare_window');expect('beam_prepare_next',724)
 put('rc_pending',1);put('clock_time',501)
 emit(' jsr beam_prepare_window');expect('beam_prepare_next',724)
 put('ng_profile_enabled',1)
 # Trace elapsed physical time, including wrap and a full-refresh overrun.
 exposed=0
 for strip,startline,duration in [(0,8,20),(0,250,20),(24,250,40),(12,104,262),(0,135,126),(18,0,2),(18,144,2),(18,0,145)]:
  put('rw_strip',strip);put('beam_bottom',(strip+1)*8);put('clock_line',startline);put('clock_time',65520);put('clock_time+2',7)
  emit(' jsr beam_trace_begin')
  t=7*65536+65520+duration
  put('clock_time',t&65535);put('clock_time+2',t>>16);put('clock_line',(startline+duration)%262)
  emit(' lda #37\n jsr beam_trace_end\n sta test_result');expect('test_result',37)
  exposed+=int(strip*8<=startline<(strip+1)*8 or duration>=((strip*8-startline)%262))
  expect('beam_exposures',exposed)
 expect('beam_transactions',8);expect('beam_max_exposure',262)
 emit(' lda #0\n rts\n copy src/iigs/beam_schedule.asm\nraster_line ldy test_raster_cursor\ntest_raster_read lda |$0000,y\n inc test_raster_cursor\n inc test_raster_cursor\n rts\nclock_sample rts')
 for n,size in [('rc_pending',2),('rc_displayed_mode',2),('rw_strip',2),('ng_profile_enabled',2),('clock_time',4),('clock_line',2),('rc_generation',2),('sw_enabled',2),('test_raster_ptr',2),('test_raster_cursor',2),('test_result',2)]:emit(f'{n} ds {size}')
 for label,seq in sequences:emit(label+" dc i2'"+','.join(map(str,seq))+"'")
 emit(' END')
 (OUT/'test.s').write_text('\n'.join(lines)+'\n')
 (OUT/'reporter.c').write_text('#include <stdio.h>\nextern unsigned beam_test(void);\nint main(void){unsigned r=beam_test();printf("beam schedule: %u\\n",r);return r;}\n')
 commands=[['iix','assemble',str(OUT/'test.s'),'keep='+str(OUT/'assembly')],['iix','compile',str(OUT/'reporter.c'),'keep='+str(OUT/'reporter')],['iix','link',str(OUT/'reporter'),str(OUT/'assembly'),'keep='+str(OUT/'test')],['iix',str(OUT/'test')]]
 for i,cmd in enumerate(commands):
  p=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
  (OUT/f'{i}.log').write_text(p.stdout)
  if p.returncode:raise RuntimeError(p.stdout[-4000:])
 assert p.stdout.strip()=='beam schedule: 0',p.stdout
 (OUT/'result.json').write_text(json.dumps(dict(passed=True,assertions=len(assertions),scope=__doc__),indent=2)+'\n')
 print(f'Native beam scheduler: {len(assertions)} assertions PASS')
if __name__=='__main__':main()
