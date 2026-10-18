#!/usr/bin/env python3
"""Measure a private deterministic native game scene in physical NTSC time.
Continuous completion controller; late frames finish and tearing is permitted.
Optional fixture inputs/foreground timers are explicit in the build manifest.
No debugger pauses occur inside the retained timing interval.
"""
from pathlib import Path
import argparse,hashlib,json,shutil,socket,struct,sys,time
import native_oracle
from native_game_pixels import render as original_render
def render(snapshot):return original_render(snapshot,sprite_top=8)
from native_png import save_png
ROOT=Path(__file__).resolve().parents[2]
def seed_stress(snapshot):
 # Renderer stress state: rail bonuses plus seven synchronized half-pixel-per-tick real drones.
 # Artificial placement/velocity is explicit; do not call this a legal playthrough.
 from native_render_assets import source_frames
 _,lookup,_=source_frames()
 cargo=next(i for i,f in enumerate(lookup) if f==30)
 for key in list(snapshot):
  if key.startswith('objects.'):
   snapshot[key]=[0]*24
 def field(name,slot,value):snapshot['objects.'+name][slot]=value
 for i in range(10):
  field('flags',i,3 if i in (0,8,9) else 11)
  field('kind',i,0 if i==0 else (4 if i>=8 else 1+(i%3)))
  x,y=(153,146) if i==0 else ((60+(i%4)*65,65+(i//4)*50) if i<8 else (169,146))
  field('x_lo',i,x&255);field('x_hi',i,x>>8);field('y_int',i,y)
  kind=snapshot['objects.kind'][i]
  field('sprite_ptr',i,248 if i==0 else (cargo if i==8 else (205 if i==9 else {1:203,2:199,3:195}[kind])))
  field('sprite_attr',i,0 if i==8 else 1)
  field('sprite_color',i,4 if i==0 or i==9 else (8 if i==8 else {1:6,2:5,3:2}[kind]))
  if 0<i<8:
   field('user',i,0);field('vy_frac',i,128);field('y_frac',i,0);field('reserved',i,{1:3,2:2,3:1}[kind])
 snapshot['free_stack']=[0]*23
 free=list(range(23,9,-1));snapshot['free_stack'][:len(free)]=free;snapshot['free_count']=len(free)
 snapshot['cargo_slot']=8;snapshot['parcel_slot']=9
 # In-flight fields are synthetic fixture state, normal update handlers remain live.
 snapshot['cargo_target']=0;snapshot['parcel_dir']=0

def active_play(samples,before):
 duration=0.0;commits=0;specialized=0;ticks=0;drops=0;previous=before
 previous_time=0.0;intervals=0;presentation_gap=0.0;longest_gap=0.0
 for sample in samples:
  now=sample['physical_seconds']
  if sample['game_mode']==3 and previous.get('game_mode',3)==3:
   duration+=now-previous_time
   commits+=(sample['rwp_commits']-previous['rwp_commits'])&65535
   specialized+=(sample['specialized_commits']-previous['specialized_commits'])&65535
   ticks+=(sample['platform_ticks']-previous['platform_ticks'])&0xffffffff
   drops+=(sample['clock_dropped']-previous['clock_dropped'])&0xffffffff
   if (sample['specialized_commits']-previous['specialized_commits'])&65535:presentation_gap=0.0
   else:presentation_gap+=now-previous_time
   longest_gap=max(longest_gap,presentation_gap)
   intervals+=1
  else:presentation_gap=0.0
  previous=sample;previous_time=now
 return dict(sampled_seconds=duration,presentations=commits,specialized_presentations=specialized,logic_ticks=ticks,dropped_ticks=drops,
             presentation_hz=commits/duration if duration else 0,specialized_presentation_hz=specialized/duration if duration else 0,logic_hz=ticks/duration if duration else 0,
             intervals=intervals,longest_sampled_presentation_gap_seconds=longest_gap,no_presentation_stall=longest_gap<=1.0,scope='Only adjacent sampled PLAY endpoints; transitions excluded')

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--session',type=Path,required=True);p.add_argument('--seconds',type=float,default=60);p.add_argument('--stress',action='store_true',help='Ten-object placement stress; synthetic seed, shipping logic and held fire unchanged');p.add_argument('--mid-level',action='store_true',help='Seed just beyond half quota, selecting dense late-half parameters');p.add_argument('--level',type=int,choices=[1,9,15],default=15);a=p.parse_args()
 folder=a.session.parent;s=json.loads(a.session.read_text());m=json.loads((folder/'build-manifest.json').read_text());sy=m['symbols'];gs=m['game_symbols'];base=0xa0000;proof=dict(scope=__doc__,session=s,binary_sha256=m['binary_sha256'],profile=m.get('profile'),fixture_input=m.get('fixture_input'),held_fire=m.get('held_fire'),mid_level=a.mid_level,requested_level=a.level)
 assert hashlib.sha256((folder/'Start').read_bytes()).hexdigest()==m['binary_sha256']
 assert m.get('profile') and m.get('fixture_input') and m.get('held_fire'),'Timing proof requires profiled continuous-fire fixture image'
 helper=Path(__file__).read_bytes();(folder/'native_continuous_profile.py').write_bytes(helper)
 for name in ['native_game_pixels.py','native_render_assets.py','native_png.py','native_continuous_profile.py']:shutil.copy2(ROOT/'tools/iigs'/name,folder/name)
 binary,oracle_manifest=native_oracle.build('c64');shutil.copy2(binary,folder/'host-oracle');(folder/'host-oracle-manifest.json').write_text(json.dumps(oracle_manifest,indent=2)+'\n')
 for path,digest in oracle_manifest['hashes'].items():
  origin=ROOT/path;assert hashlib.sha256(origin.read_bytes()).hexdigest()==digest,path
  target=folder/'oracle-source-snapshot'/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(origin,target)
 commands=f'reset\ncall game_init_enter\nset level 0 {a.level}\ncall waves_load\ncall hud_paint_full_line\ntick 50\ndump\n'
 initial=native_oracle.run_commands(commands,binary=folder/'host-oracle')[-1]
 if a.mid_level:
  commands=commands.rsplit('dump\n',1)[0]+f"set level_kills 0 {initial['level_quota']//2}\ncall waves_note_kill\ncall hud_paint_full_line\ndump\n"
 snapshot=native_oracle.run_commands(commands,binary=folder/'host-oracle')[-1];
 if a.stress:
  seed_stress(snapshot)
  proof['stress_scope']='Synthetic ten-object placement with synchronized half-pixel fractional velocities; actual shipping GAME and held-fire input. Separate from legal level9 workload.'
 (folder/'seed-state.json').write_text(json.dumps(dict(commands=commands,state=snapshot),indent=2)+'\n')
 sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'));from gs2debug import Client,BP_KIND_EXEC,BP_FLAG_ENABLED,BP_FLAG_TEMPORARY
 c=Client();failure=None
 def read(at,n):return b''.join(c.read_mem(0,at+i,min(65536,n-i)) for i in range(0,n,65536))
 def word(name,n=2):return int.from_bytes(read(base+sy[name],n),'little')
 def arm(name):return c.bp_set(kind=BP_KIND_EXEC,address=base+sy[name],flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
 def reach(bp,timeout=90):
  c.continue_();end=time.monotonic()+timeout
  while time.monotonic()<end:
   try:
    event=c.wait_stopped(timeout=10)
    if event.bp_id!=bp:raise RuntimeError('Unexpected native stop '+repr(event))
    return
   except (TimeoutError,socket.timeout):pass
  raise TimeoutError('Native breakpoint not reached')
 def native_state():
  for _ in range(100):
   raw=read(base,sy['native_end'])
   def get(name,n=2):return int.from_bytes(raw[sy[name]:sy[name]+n],'little')
   if get('clock_publish_seq')&1:continue
   result={name:get(name,width) for name,width in [('clock_last',4),('clock_delivered',4),('clock_dropped',4),('clock_fault',2),('clock_backwards',2),('clock_max_gap',2),('platform_ticks',4),('platform_fault',2),('input_fault',2),('rwp_fault',2),('rwp_commits',2),('rwp_repeats',2),('rwp_nochanges',2),('rwp_max_blackout',2),('rwp_last_words',2),('rwp_last_spans',2),('rd_words',2),('rd_count',2)]}
   result['specialized_commits']=get('sw_commits') if 'sw_commits' in sy else 0
   result['specialized_enabled']=get('sw_enabled')
   for name in ['rwp_draw_last','rwp_draw_max']:
    if name in sy:result[name]=get(name,4)
   for name,width in [('sw_rejected',2),('sw_reject_count',4),('sw_discard_count',4),('rc_generation',2),('rc_display_generation',2),('rc_pending',2)]:
    if name in sy:result[name]=get(name,width)
   if 'ng_game_max' in sy:
    result['logic_max_lines']=get('ng_game_max',4);result['logic_last_lines']=get('ng_game_last',4)
    result['_render_snapshot']=raw[sy['rc_candidate'] if get('rc_pending') else sy['rc_displayed']:][:2388].hex()
    result['stage_max_lines']=list(struct.unpack_from('<5I',raw,sy['ng_stage_max']));result['stage_last_lines']=list(struct.unpack_from('<5I',raw,sy['ng_stage_last']))
   return result
  raise RuntimeError('Clock publication remained odd')
 def seed_scene():
   buffers={'dp':(dp,bytearray(read(dp,256))),'game':(game+gs['game_state'],bytearray(read(game+gs['game_state'],gs['game_state_end']-gs['game_state'])))}
   for name,spec in state.items():
    value=snapshot[name];values=value if isinstance(value,list) else [value]
    blob=b''.join(int(v).to_bytes(spec['width'],'little') for v in values);assert len(blob)==spec['width']*spec['count']
    cursor=0
    for part in spec.get('parts',[spec]):
     size=part['count']*spec['width'];address=(dp if spec['space']=='dp' else game)+part['offset'];origin,buffer=buffers[spec['space']];at=address-origin
     if at<0 or at+size>len(buffer):
      assert name=='frame';c.write_mem(0,address,blob[cursor:cursor+size])
     else:buffer[at:at+size]=blob[cursor:cursor+size]
     cursor+=size
   for origin,buffer in buffers.values():c.write_mem(0,origin,bytes(buffer))
   for name,value in [('rc_pending',0),('rc_display_valid',0),('ng_fixture_phase',0),('ng_fixture_dir_timer',53),('ng_fixture_fire_timer',97)]:c.write_mem(0,base+sy[name],value.to_bytes(2,'little'))
   if 'sw_rejected' in sy:c.write_mem(0,base+sy['sw_rejected'],b'\x00\x00')
   return dict(level=snapshot['level'],lives=snapshot['lives'],mode=snapshot['mode'],frame=snapshot['frame'],allocated_slots=sum(bool(f&1) for f in snapshot['objects.flags']))
 try:
  deadline=time.monotonic()+30
  while True:
   try:
    c.connect(s['socket']);break
   except (FileNotFoundError,ConnectionRefusedError):
    if time.monotonic()>deadline:raise TimeoutError('Owned debugger startup')
    time.sleep(.1)
  c.hello();reach(arm('main_loop'),timeout=300)
  proof['policy']='Complete every prepared update; no cost admission or beam deadline veto'
  assert word('debug_ready')==1,'Native startup failed'
  game=word('debug_game_base',4);dp=word('debug_game_dp');state=m['state_map']
  # Freeze at a foreground boundary. Seed actual game state once, retaining
  # original code and the platform DP/clock/input ownership independently.
  proof['seed']=seed_scene()
  c.continue_();warmup_start=time.monotonic();end=warmup_start+90;stalled_warmup=False
  while True:
   current=native_state()
   if any(current[n] for n in ['clock_fault','platform_fault','rwp_fault']):raise RuntimeError('Native warmup fault '+repr(current))
   if word('rc_displayed_mode')==3 and current['specialized_commits']>=5:break
   if time.monotonic()>end:raise TimeoutError('Gameplay did not produce five completed updates')
   time.sleep(.1)
  # Reset diagnostic maxima at a safe boundary; this does not affect logic.
  # Stop outside timing before arming: a running VM can consume a temporary
  # breakpoint between bp_set and continue_, otherwise losing the stop.
  c.pause();c.wait_stopped(timeout=5)
  reach(arm('main_loop'))
  proof['warmup']=dict(ordinary_commits=word('rwp_commits'),completed_five_updates=True)
  for name,count in [('ng_game_max',4),('ng_stage_max',20),('clock_max_gap',2)]:c.write_mem(0,base+sy[name],bytes(count))
  for name,size in [('game_obs_max_allocated',2),('game_obs_max_render',2),('game_obs_max_onscreen',2),('game_obs_kind_max',14),('game_obs_samples',4)]:c.write_mem(0,game+gs[name],bytes(size))
  before=native_state();before.pop('_render_snapshot',None);samples=[];visible_peak=0;drawable_peak=0;render_peak_record=None;c.continue_();end=time.monotonic()+max(180,a.seconds*4)
  while True:
   current=native_state();elapsed=((current['clock_last']-before['clock_last'])&0xffffffff)*912/14318180
   render_blob=bytes.fromhex(current.pop('_render_snapshot'));_,render_stats=render(render_blob)
   if len(render_stats['visible_slots'])>visible_peak:
    visible_peak=len(render_stats['visible_slots']);render_peak_record=render_stats;(folder/'peak-render-snapshot.bin').write_bytes(render_blob)
   drawable_peak=max(drawable_peak,len(render_stats['drawable_slots']))
   rawdp=read(dp,165);sample={name:rawdp[m['raw_dp'][name]['offset']] for name in ['game_mode','level','level_kills','level_quota','player_dead','level_banner_t']}
   obs_raw=read(game+gs['game_obs_allocated'],gs['game_obs_peak_objects']-gs['game_obs_allocated'])
   def obs(name,size=2):
    at=gs[name]-gs['game_obs_allocated'];return int.from_bytes(obs_raw[at:at+size],'little')
   observer={name:obs(name,4 if name=='game_obs_samples' else 2) for name in ['game_obs_allocated','game_obs_render','game_obs_onscreen','game_obs_max_allocated','game_obs_max_render','game_obs_max_onscreen','game_obs_samples']}
   at=gs['game_obs_kind_max']-gs['game_obs_allocated'];observer['kind_max']=list(struct.unpack_from('<7H',obs_raw,at))
   sample['observer']=observer
   objects=read(game+gs['objects__obj_flags'],24);sample.update(physical_seconds=elapsed,allocated_slots=sum(bool(f&1) for f in objects),**current);samples.append(sample)
   (folder/'profile-progress.json').write_text(json.dumps(dict(physical_seconds=elapsed,game_mode=sample['game_mode'],specialized_commits=current['specialized_commits'],repeats=current['rwp_repeats'],clock_dropped=current['clock_dropped'])))
   if any(current[n] for n in ['clock_fault','clock_backwards','platform_fault','input_fault','rwp_fault']):raise RuntimeError('Native steady fault '+repr(current))
   if elapsed>=a.seconds:break
   if time.monotonic()>end:raise TimeoutError('Physical guest interval did not advance')
   time.sleep(.25)
  after=current;proof['per_tick_highwater']=observer
  proof['observed_render_highwater']=dict(sample_period_seconds=.25,pixel_visible=visible_peak,drawable=drawable_peak,peak=render_peak_record,scope='Sampled immutable render snapshots; candidate may not yet have committed')
  proof['timing']=dict(physical_seconds=elapsed,before=before,after=after,logic_rate=((after['platform_ticks']-before['platform_ticks'])&0xffffffff)/elapsed,presentation_rate=((after['rwp_commits']-before['rwp_commits'])&65535)/elapsed,dropped_ticks=(after['clock_dropped']-before['clock_dropped'])&0xffffffff,samples=samples)
  proof['active_play']=active_play(samples,before)
  proof['work_count_units']='dirty cells in specialized route; generic spans otherwise'
  proof['rwp_max_blackout_note']='Legacy compatibility placeholder, not a measured IRQ duration. Use continuous-sprite-result.json.'
  proof['render_stage_names']=['prepare_total','unused','unused','unused','unused']
  proof['sampled_play_object_counts']={str(count):sum(1 for v in samples if v['game_mode']==3 and v['observer']['game_obs_render']==count) for count in range(25)}
  # Timing is complete before any breakpoint or validation-scene mutation.
  # A normal run may now be idle in highscore/title, which emits no new wave.
  # Re-seed the same legal PLAY scene at a foreground boundary only in that
  # case. Its fresh pixels/beam trace form a separate correctness phase.
  # Stop outside timing before arming: a running VM can consume a temporary
  # breakpoint between bp_set and continue_, otherwise losing the stop.
  c.pause();c.wait_stopped(timeout=5)
  reach(arm('main_loop'))
  for name in ['rc_candidate','rc_displayed']:(folder/('post-timing-'+name+'.bin')).write_bytes(read(base+sy[name],2388))
  if proof['active_play']['specialized_presentations']==0:raise RuntimeError('No specialized presentations during retained PLAY interval')
  validation_mode=read(dp+m['raw_dp']['game_mode']['offset'],1)[0]
  proof['correctness_phase']=dict(outside_timing_window=True,mode_before=validation_mode,reseeded=validation_mode!=3 or a.stress)
  if validation_mode!=3 or a.stress:
   proof['correctness_phase']['seed']=seed_scene()
   proof['correctness_phase']['reason']='Outside timing: original workload seed restored for an completed validation update; synthetic ten-object seed when stress is enabled'
  for capture_attempt in range(64):
   reach(arm('rwp_pixels_complete'),timeout=30)
   selected_count=sum(bool(v) for v in struct.unpack('<24H',read(base+sy['sw_selected'],48)))
   if word('sw_enabled')==1 and word('sw_selected')==1 and (not a.stress or selected_count>=8):break
   reach(arm('rwp_complete'),timeout=30)
  else:raise RuntimeError('No specialized player redraw reached after transition')
  displayed=read(base+sy['rc_candidate'],2388);actual=read(0xe12000,32000);expected,stats=render(displayed)
  assert actual==expected,'Displayed gameplay pixels differ'
  for name,blob in [('frame.bin',actual),('displayed-snapshot.bin',displayed)]: (folder/name).write_bytes(blob)
  save_png(folder/'frame.png',actual);proof['pixels']=dict(compared_bytes=32000,mismatches=0,stats=stats)
  proof['framebuffer_pass']=True
  proof['captured_redraw_slots']=[i for i,v in enumerate(struct.unpack('<24H',read(base+sy['sw_selected'],48))) if v]
  proof['beam_trace_pass']=None
  proof['beam_scope']='Occasional tearing accepted; completed framebuffer correctness checked separately'
  reach(arm('rwp_complete'),timeout=30)
  assert read(base+sy['rc_displayed'],2388)==displayed,'Published snapshot differs from completed update'
  breakdown=[]
  labels=(['sw_prepare','sd_old_loop','sd_current_loop','sd_plan_cells','sd_plan_sprites','rwp_present','rwp_pixels_complete'] if 'sd_cells' in sy else ['sw_prepare','sw_prepare_ok','sw_closure','sw_cells','rd_emit','sw_plan','sw_cache_loop','sw_plan_strip_loop','sw_plan_done','rwp_present','rwp_pixels_complete'])
  for label in labels:
   if label not in sy:continue
   reach(arm(label),timeout=60)
   entry=c.get_trace(ago=0,count=1).entries[-1]
   stamp=struct.unpack_from('<Q',entry)[0]
   breakdown.append(dict(label=label,master_ticks=stamp))
  for prev,cur in zip(breakdown,breakdown[1:]):cur['elapsed_ms']=(cur['master_ticks']-prev['master_ticks'])*1000/14318180
  proof['diagnostic_stage_breakdown']=breakdown
  proof['diagnostic_stage_scope']='One later candidate with breakpoint pauses; outside retained timing. These elapsed guest cycles do not establish worst-case stage cost.'
  proof['functional_pass']=bool(proof.get('framebuffer_pass') and proof['active_play']['specialized_presentations']>=5 and proof['active_play']['no_presentation_stall'])
  proof['pass']=proof['active_play']['dropped_ticks']==0 and 58<=proof['active_play']['logic_hz']<=61 and proof['active_play']['specialized_presentations']>=5 and proof['active_play']['presentation_hz']>=29 and proof['active_play']['no_presentation_stall']
  if not proof['pass']:
   failure='Retained PLAY logic/presentation throughput gate failed'
   proof['failure']=failure
 except Exception as exc:
  failure=repr(exc);proof['failure']=failure;proof['pass']=False
  try:
   c.pause()
   try:c.wait_stopped(timeout=5)
   except (TimeoutError,socket.timeout):pass
   proof['failure_cpu_raw']=c.get_regs().hex()
   (folder/'failure-native-ram.bin').write_bytes(read(base,sy['native_end']))
   (folder/'failure-trace.zlib').write_bytes(__import__('zlib').compress(b''.join(c.get_trace(ago=0,count=16384).entries)))
   proof['failure_native_state']=native_state()
  except Exception as diagnostic_error:proof['failure_diagnostic_error']=repr(diagnostic_error)

 finally:
  proof['helper_sha256']=hashlib.sha256(helper).hexdigest();(folder/'continuous-profile.json').write_text(json.dumps(proof,indent=2)+'\n');c.quit()
 print(json.dumps({k:v for k,v in proof.items() if k not in ['session','timing','beam']},indent=2))
 if failure:raise SystemExit(failure)
if __name__=='__main__':main()
