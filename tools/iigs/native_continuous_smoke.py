#!/usr/bin/env python3
"""Real keyboard navigation/movement/fire and completed-frame pixel smoke.
Owns one fresh windowed emulator. No fixture input or gameplay state injection.
"""
import argparse, hashlib, json, socket, sys, time
from pathlib import Path
from native_game_pixels import render
from native_png import save_png
ROOT=Path(__file__).resolve().parents[2]

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--session',type=Path,required=True)
 p.add_argument('--base',type=lambda x:int(x,0),default=0xa0000)
 a=p.parse_args();folder=a.session.parent;s=json.loads(a.session.read_text());m=json.loads((folder/'build-manifest.json').read_text());sy=m['symbols'];base=a.base
 assert not m.get('fixture_input'), 'Real input image required'
 assert hashlib.sha256((folder/'Start').read_bytes()).hexdigest()==m['binary_sha256']
 sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
 from gs2debug import Client,BP_KIND_EXEC,BP_FLAG_ENABLED,BP_FLAG_TEMPORARY
 c=Client();pressed=set();result={'scope':__doc__,'binary_sha256':m['binary_sha256'],'rom':s.get('rom','1')}
 def read(at,n):return b''.join(c.read_mem(0,at+i,min(4096,n-i)) for i in range(0,n,4096))
 def word(n,size=2):return int.from_bytes(read(base+sy[n],size),'little')
 def wait_for(predicate,seconds=30):
  end=time.monotonic()+seconds
  while not predicate():
   if time.monotonic()>end:raise TimeoutError('Real keyboard/render progress timeout')
   time.sleep(.03)
 def reach(label,timeout=60):
  bp=c.bp_set(kind=BP_KIND_EXEC,address=base+sy[label],flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
  c.continue_();end=time.monotonic()+timeout
  while time.monotonic()<end:
   try:
    event=c.wait_stopped(timeout=5)
    assert event.bp_id==bp, (label,event)
    return
   except (TimeoutError,socket.timeout):pass
  raise TimeoutError(label)
 def ticks(n):
  first=word('platform_ticks',4)
  wait_for(lambda:((word('platform_ticks',4)-first)&0xffffffff)>=n)
 def key(down,code):
  (c.key_down if down else c.key_up)(code)
  (pressed.add if down else pressed.discard)(code)
 def tap(code):
  key(True,code);ticks(5);key(False,code);ticks(20)
 def frame(label):
  snapshot=read(base+sy['rc_displayed'],2388);actual=read(0xe12000,32000);expected,stats=render(snapshot,sprite_top=8)
  differences=sum(x!=y for x,y in zip(actual,expected));save_png(folder/(label+'.png'),actual)
  (folder/(label+'-snapshot.bin')).write_bytes(snapshot)
  result[label]={'mismatches':differences,'stats':stats,'mode':word('rc_displayed_mode')}
  assert not differences,(label,differences)
 try:
  end=time.monotonic()+30
  while True:
   try:c.connect(s['socket']);break
   except (FileNotFoundError,ConnectionRefusedError):
    if time.monotonic()>end:raise
    time.sleep(.1)
  c.hello();reach('ng_blank_strip',180)
  # The shared full-screen transition must hide the caller's text colours.
  assert read(0xe0c022,1)==b'\0'
  assert not (read(0xe0c029,1)[0]&0x80)
  saved_text_color=read(base+sy['ng_blank_text_color'],1)
  result['black_transition']={'text_color':0,'saved_text_color':saved_text_color[0]}
  reach('main_loop')
  assert read(0xe0c022,1)==saved_text_color
  assert read(0xe0c029,1)[0]&0x80
  assert word('debug_ready')==1
  frame('title');c.continue_();ticks(30)
  tap(44)
  wait_for(lambda:word('rc_displayed_mode')==9,60)
  c.pause();c.wait_stopped(timeout=5);reach('main_loop');frame('past-heroes')
  c.continue_();ticks(30);tap(44)
  wait_for(lambda:word('rc_displayed_mode')==3,60)
  ticks(60)
  # D and Space are separate input events, each allowed to drain normally.
  key(True,7);ticks(5);assert word('input_dirs_value')!=0
  key(True,44);ticks(10);assert word('input_fire_value')==1
  result['held_input']={'dirs':word('input_dirs_value'),'fire':word('input_fire_value')}
  ticks(30);key(False,7);ticks(5);key(False,44);ticks(5)
  assert word('input_dirs_value')==0 and word('input_fire_value')==0
  c.pause();c.wait_stopped(timeout=5);reach('rwp_complete');frame('play')
  result['counters']={n:word(n,4 if n in ('platform_ticks','clock_dropped') else 2) for n in ['platform_ticks','clock_dropped','platform_fault','clock_fault','input_fault','rwp_fault','rwp_commits','rwp_repeats','sw_commits']}
  assert not any(result['counters'][n] for n in ('platform_fault','clock_fault','input_fault','rwp_fault','rwp_repeats'))
  # The separate lifecycle test verifies every saved caller byte/register.
  c.continue_();c.key_down(224,64);pressed.add(224);ticks(3);c.pause();c.wait_stopped(timeout=5)
  c.key_down(20,64);pressed.add(20);reach('native_quit',30)
  result['input_cleanup']={n:word(n) for n in ['input_pending','input_tool_owned','input_mode_owned','input_cleanup_error','debug_cleanup_error']}
  assert not any(result['input_cleanup'].values()),result['input_cleanup']
  result['pass']=True
 finally:
  for code in pressed:
   try:c.key_up(code)
   except Exception:pass
  result['helper_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
  (folder/'continuous-smoke.json').write_text(json.dumps(result,indent=2)+'\n')
  try:c.quit()
  except Exception:pass
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
