#!/usr/bin/env python3
"""Actual windowed IIgs <=8-row sprite fragment pixel/ABI/IRQ-duration diagnostic.
Owns the supplied VM and quits it. Main-loop bytes are patched only while paused
for an isolated JSR/owned completion marker; this is not gameplay throughput.
"""
import argparse,hashlib,json,os,signal,socket,struct,sys,time
from pathlib import Path
from native_render_assets import source_frames
ROOT=Path(__file__).resolve().parents[2]
def regs(raw):
 d=dict(zip(('pc','a','x','y','sp','d'),struct.unpack_from('<6H',raw,16)));d.update(p=raw[13],db=raw[14],pb=raw[15]);return d

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--session',type=Path,required=True);p.add_argument('--quick',action='store_true');p.add_argument('--irq-enabled',action='store_true');p.add_argument('--smoke',action='store_true');p.add_argument('--horizontal',action='store_true');a=p.parse_args();a.irq_enabled=True
 session=json.loads(a.session.read_text());folder=Path(session['folder']);m=json.loads((folder/'build-manifest.json').read_text());sy=m['symbols'];base=0xa0000
 sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
 from gs2debug import Client,BP_KIND_EXEC,BP_FLAG_ENABLED,BP_FLAG_TEMPORARY,REG_PC,REG_PB,REG_P,REG_D,REG_DB
 c=Client();result=dict(scope=__doc__,binary_sha256=m['binary_sha256'],cases=0,scenes=0,abi_failures=[],pixel_failures=[],quick=a.quick,smoke=a.smoke,horizontal=a.horizontal,irq_enabled=a.irq_enabled,max_irq_off_master_ticks=0,max_irq_off_lines=0,irq_cases=[])
 def addr(name):return base+sy[name]
 def read(at,n):return b''.join(c.read_mem(0,at+i,min(4096,n-i)) for i in range(0,n,4096))
 def write(at,data):
  for i in range(0,len(data),4096):c.write_mem(0,at+i,data[i:i+4096])
 def wait(timeout=180):
  end=time.monotonic()+timeout
  while time.monotonic()<end:
   try:return c.wait_stopped(timeout=min(5,end-time.monotonic()))
   except (TimeoutError,socket.timeout):
    (folder/'kernel-progress.json').write_text(json.dumps(dict(phase='waiting',cpu=regs(c.get_regs()),cases=result['cases'],scenes=result['scenes'])))
  raise TimeoutError('Native kernel completion not reached')
 original=None
 try:
  end=time.monotonic()+30
  while not Path(session['socket']).exists():
   if time.monotonic()>end:raise TimeoutError('Owned debug socket not created')
   time.sleep(.1)
  c.connect(session['socket']);c.hello()
  shutdown=c.bp_set(kind=BP_KIND_EXEC,address=addr('shutdown'),flags=BP_FLAG_ENABLED)
  ready=c.bp_set(kind=BP_KIND_EXEC,address=addr('main_loop'),flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
  c.continue_();event=wait(300)
  assert event.bp_id==ready,('startup',event,regs(c.get_regs()))
  assert int.from_bytes(read(addr('debug_ready'),2),'little')==1
  initial=regs(c.get_regs());original=read(addr('main_loop'),4)
  write(addr('main_loop'),bytes([0x20,sy['ns_draw']&255,sy['ns_draw']>>8,0xea]))
  frames,_,_=source_frames();guardkeys=('sp','d','db','p')
  def draw_fragment(frame,x,y,color,attr,first,stop,decimal=False):
   assert 0 < stop-first <= 8
   write(addr('ro_x'),struct.pack('<5H',x&65535,y&65535,frame,color,attr));write(addr('ns_first'),struct.pack('<2H',first,stop))
   state=(initial['p']&0xc3)|(8 if decimal else 0)|(0 if a.irq_enabled else 4)
   c.set_regs(REG_PC|REG_PB|REG_P|REG_D|REG_DB,pc=sy['main_loop'],pb=base>>16,p=state,d=0x1234,db=base>>16)
   before=regs(c.get_regs());mapping=read(0xe0c068,1)+read(0xe0c035,1)
   done=c.bp_set(kind=BP_KIND_EXEC,address=addr('main_loop')+3,flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
   c.continue_();event=wait(20);after=regs(c.get_regs())
   assert event.bp_id==done,('completion',event,after)
   assert after['a']==0,('ns_draw returned error',frame,x,y,after)
   if any(before[k]!=after[k] for k in guardkeys) or mapping!=read(0xe0c068,1)+read(0xe0c035,1):
    result['abi_failures'].append(dict(frame=frame,x=x,y=y,before=before,after=after))
   # Trace is pre-instruction state, measured in14.31818MHz master ticks.
   # Include the SEI instruction itself for a conservative upper bound; end
   # at the first instruction whose pre-state has IRQs enabled again.
   raw=c.get_trace(ago=0,count=4096).entries
   def pc(t):return t[15]*65536+struct.unpack_from('<H',t,16)[0]
   starts=[i for i,t in enumerate(raw) if pc(t)==addr('main_loop')]
   if not starts:
    raw=c.get_trace(ago=0,count=16384).entries
    starts=[i for i,t in enumerate(raw) if pc(t)==addr('main_loop')]
   assert starts,'Fragment entry evicted from instruction trace'
   raw=raw[starts[-1]:]+[c.get_regs()]
   irq_begin=None;longest=0;state=mapping[0];pixel_stack=False;normal_sp=None
   for i,t in enumerate(raw):
    cycle=struct.unpack_from('<Q',t)[0];op=t[12];status=t[13]
    if irq_begin is None and (op==0x78 or status&4):irq_begin=cycle
    elif irq_begin is not None and not status&4:
     longest=max(longest,cycle-irq_begin);irq_begin=None
    address=struct.unpack_from('<I',t,32)[0];flags=struct.unpack_from('<H',t,36)[0]
    if flags&16 and address in (0xe0c068,0xe1c068):
     state=t[28]
     if state&0x30==0x30:normal_sp=struct.unpack_from('<H',t,24)[0]
     else:pixel_stack=False
    if op==0x1b and state&0x30==0x30:
     stack_value=struct.unpack_from('<H',t,18)[0]
     pixel_stack=stack_value!=normal_sp
     if pixel_stack:assert 0x2000<=stack_value<0x9d00
    if pixel_stack:
     assert status&4,'IRQs enabled while S addresses pixels'
     assert op not in (0x20,0x22,0xfc,0x60,0x6b,0x40,0x08,0x28,0x0b,0x2b,0x8b,0xab,0x4b,0x58),'Normal stack instruction with pixel S'
   assert irq_begin is None,'Fragment returned with IRQs disabled'
   result['max_irq_off_master_ticks']=max(result['max_irq_off_master_ticks'],longest)
   result['max_irq_off_lines']=result['max_irq_off_master_ticks']/912
   result['irq_cases'].append(dict(frame=frame,x=x,y=y,attr=attr,first=first,stop=stop,master_ticks=longest,lines=longest/912))
   result['cases']+=1
  def draw(frame,x,y,color,attr,first=0,stop=21,decimal=False):
   for begin in range(first,stop,8):
    draw_fragment(frame,x,y,color,attr,begin,min(begin+8,stop),decimal=decimal)
  def oracle(image,frame,x,y,color,attr,first=0,stop=21):
   raw=frames[frame][1]
   for oy in range(first,stop):
    yy=y+oy
    if not 8<=yy<200:continue
    for ox in range(24):
     xx=x+ox
     if not 0<=xx<320:continue
     bits=raw[oy*3+ox//8];role=(bits>>(6-(ox&6)))&3 if attr else ((bits>>(7-(ox&7)))&1)
     if not role:continue
     ink=(0,11,color,7)[role] if attr else color;at=yy*160+xx//2;shift=0 if xx&1 else 4
     image[at]=(image[at]&~(15<<shift))|(ink<<shift)
  def scene(cases):
   expected=bytearray([0xa5]*32000);write(0x012000,expected);write(0xe12000,expected)
   for i,case in enumerate(cases):draw(*case,decimal=bool(i&1));oracle(expected,*case)
   actual=read(0xe12000,32000);shadow=read(0x012000,32000)
   mismatch=sum(x!=y for x,y in zip(actual,expected));shadowbad=sum(x!=y for x,y in zip(shadow,expected))
   if mismatch or shadowbad:
    result['pixel_failures'].append(dict(scene=result['scenes'],visible=mismatch,bank01=shadowbad,cases=cases))
    (folder/f"kernel-fail-{result['scenes']}.bin").write_bytes(actual)
   result['scenes']+=1
   (folder/'kernel-progress.json').write_text(json.dumps(dict(phase='scenes',cases=result['cases'],scenes=result['scenes'])))
   assert not mismatch and not shadowbad,result['pixel_failures'][-1:]
  if a.horizontal:
   # Every original frame at six real horizontal edge positions, separated in Y.
   for attr in range(2):
    for sx in (-23,-2,-1,297,298,319):
     for batch in range(0,31,8):
      scene([(f,sx,8+(f-batch)*24,9,attr) for f in range(batch,min(batch+8,31))])
    for color in (0,15):
     for sx in (-1,298):
      scene([(f,sx,8+i*44,color,attr) for i,f in enumerate((0,5,15,30))])
    for sx in (-1,298):
     for first,stop in ((0,1),(1,8),(8,16),(16,21)):
      scene([(f,sx,8+i*44,(f*3)&15,attr,first,stop) for i,f in enumerate((0,5,15,30))])
  for attr in range(2):
   for parity in range(2):
    for color in (() if a.horizontal else (9,) if a.smoke else (0,5,10,15) if a.quick else range(16)):
     scene([(f,(f%8)*40+parity,8+(f//8)*44,color,attr) for f in range(31)])
  for attr in range(2):
   for parity in range(2):
    scene([(f,(-23,-1,0,295,307,319)[f%6]+parity,(-20,0,7,8,179,190,199)[f%7],(f*7)&15,attr) for f in range(31)])
    for first,stop in (() if a.horizontal else ((0,1),(1,8),(8,16),(16,21))):
     scene([(f,(f%8)*40+parity,8+(f//8)*44,(f*3)&15,attr,first,stop) for f in ((0,5,6,17,30) if a.quick or a.smoke else range(31))])
  assert not result['abi_failures'],result['abi_failures'][:1]
  result['pass']=True
 finally:
  if original is not None:
   try:write(addr('main_loop'),original)
   except Exception:pass
  result['helper_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest();(folder/'continuous-sprite-result.json').write_text(json.dumps(result,indent=2)+'\n')
  try:c.quit()
  except Exception:
   try:os.kill(session['pid'],signal.SIGTERM)
   except ProcessLookupError:pass
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
