#!/usr/bin/env python3
"""Windowed direct-cell renderer pixel proof; no beam timing claim.
Uses the real rs_render/sw_draw_strip entries of an immutable focused binary.
A paused diagnostic driver replaces only its owned main-loop bytes and restores
those bytes before closing the VM. Simulation/services are disabled for fixtures.
"""
import argparse,hashlib,json,os,signal,socket,struct,sys,time
from pathlib import Path
from native_scene_fixtures import fixtures as original_fixtures, snapshot, obj, background
from native_game_pixels import render
ROOT=Path(__file__).resolve().parents[2]
def fixtures():
 cases=original_fixtures()
 empty=snapshot(glyphs=bytes(1000),colors=bytes(1000))
 cases.append(('empty_no_change',empty,empty))
 dense=[(i,obj((i%8)*38,8+(i//8)*60,kind=i%6)) for i in range(24)]
 moved=[(slot,record[:]) for slot,record in dense]
 for slot,record in moved:record[0]+=1
 cases.append(('all24_slots',snapshot(dense),snapshot(moved)))
 cases.append(('all24_disappear',snapshot(dense),empty))
 return cases

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--session',type=Path,required=True);a=ap.parse_args()
 session=json.loads(a.session.read_text());folder=Path(session['folder']);m=json.loads((folder/'build-manifest.json').read_text());sy=m['symbols'];base=0xa0000
 sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
 from gs2debug import Client,BP_KIND_EXEC,BP_FLAG_ENABLED,BP_FLAG_TEMPORARY,REG_PC,REG_PB,REG_P,REG_DB
 c=Client();result=dict(scope=__doc__,binary_sha256=m['binary_sha256'],cases=[]);saved=None
 def addr(n):return base+sy[n]
 def read(at,n):return b''.join(c.read_mem(0,at+i,min(4096,n-i)) for i in range(0,n,4096))
 def write(at,blob):
  for i in range(0,len(blob),4096):c.write_mem(0,at+i,blob[i:i+4096])
 def put(n,v):write(addr(n),struct.pack('<H',v))
 def word(n):return int.from_bytes(read(addr(n),2),'little')
 def wait(timeout):
  deadline=time.monotonic()+timeout
  while time.monotonic()<deadline:
   try:return c.wait_stopped(timeout=min(5,deadline-time.monotonic()))
   except (TimeoutError,socket.timeout):pass
  raise TimeoutError('Native scene breakpoint')
 try:
  deadline=time.monotonic()+30
  while not Path(session['socket']).exists():
   if time.monotonic()>deadline:raise TimeoutError('Owned socket startup')
   time.sleep(.1)
  c.connect(session['socket']);c.hello();ready=c.bp_set(kind=BP_KIND_EXEC,address=addr('main_loop'),flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
  shutdown=c.bp_set(kind=BP_KIND_EXEC,address=addr('shutdown'),flags=BP_FLAG_ENABLED)
  c.continue_();event=wait(300);assert event.bp_id==ready,('startup',event)
  put('render_service_enabled',0)
  write(0xe0c029,b'\x61') # Approved blank-transition pixel diagnostic; no scan claim.
  opcode=read(addr('sw_copy_glyph'),4);assert opcode[0]==0xbf,opcode
  back_address=int.from_bytes(opcode[1:4],'little')
  # Assemble a small normal-stack driver in known owned code space. No compiler,
  # Toolbox or game state changes are part of fixture execution.
  code=bytearray();branches=[]
  def absolute(op,label):code.extend(bytes([op])+struct.pack('<H',sy[label]))
  absolute(0x20,'rs_render');code.extend(b'\xc9\x00\x00');branches.append(len(code));code.extend(b'\xd0\x00')
  code.extend(b'\xa9\x01\x00');absolute(0x8d,'rw_admitted');code.extend(b'\xa9\x02\x00');absolute(0x8d,'rw_mode');absolute(0x9c,'rw_strip');loop=len(code)
  absolute(0x20,'sw_choose_strip');code.extend(b'\xc9\x00\x00');branches.append(len(code));code.extend(b'\xd0\x00')
  absolute(0xee,'rw_strip');absolute(0xad,'rw_strip');code.extend(b'\xc9\x19\x00');at=len(code);code.extend(bytes([0x90,(loop-(at+2))&255]))
  absolute(0xad,'sw_enabled');code.extend(b'\xd0\x03')
  absolute(0x20,'sw_seed_bitmap')
  done=len(code);code.append(0xea)
  for at in branches:code[at+1]=(done-(at+2))&255
  assert sy['shutdown']-sy['main_loop']>=len(code)
  saved=read(addr('main_loop'),len(code));write(addr('main_loop'),code)
  for name,old,new in fixtures():
   expected,stats=render(new,sprite_top=8);old_image=render(old,sprite_top=8)[0]
   write(addr('rc_displayed'),old);write(addr('rc_candidate'),new)
   put('rc_display_valid',1);put('rc_pending',1)
   write(back_address,background(old));write(0x012000,old_image);write(0xe12000,old_image)
   before=read(0xe0c035,1)+read(0xe0c068,1)
   c.set_regs(REG_PC|REG_PB|REG_P|REG_DB,pc=sy['main_loop'],pb=base>>16,p=4,db=base>>16)
   bp=c.bp_set(kind=BP_KIND_EXEC,address=addr('main_loop')+done,flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
   c.continue_();event=wait(30);assert event.bp_id==bp,('fixture',name,event)
   assert word('sw_enabled')==int(name not in ('title_to_play','title_to_play_hud','play_to_title')),(name,'Unexpected renderer path')
   actual=read(0xe12000,32000);bank01=read(0x012000,32000)
   mismatch=sum(x!=y for x,y in zip(actual,expected));shadow_mismatch=sum(x!=y for x,y in zip(bank01,expected))
   assert before==read(0xe0c035,1)+read(0xe0c068,1),(name,'mapping leaked')
   selected=[i for i in range(24) if int.from_bytes(read(addr('sw_selected')+i*2,2),'little')]
   record=dict(name=name,mismatches=mismatch,shadow_mismatches=shadow_mismatch,selected=selected,
               expected_sha256=hashlib.sha256(expected).hexdigest(),visible_slots=stats['visible_slots'])
   result['cases'].append(record);(folder/'scene-progress.json').write_text(json.dumps(record))
   if mismatch or shadow_mismatch:
    (folder/(name+'-actual.bin')).write_bytes(actual);(folder/(name+'-expected.bin')).write_bytes(expected)
  assert all(not r['mismatches'] and not r['shadow_mismatches'] for r in result['cases']),result['cases']
  result['pass']=True
 finally:
  if saved is not None:
   try:write(addr('main_loop'),saved)
   except Exception:pass
  result['helper_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest();(folder/'continuous-scene-results.json').write_text(json.dumps(result,indent=2)+'\n')
  try:c.quit()
  except Exception:
   try:os.kill(session['pid'],signal.SIGTERM)
   except ProcessLookupError:pass
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
