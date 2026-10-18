#!/usr/bin/env python3
"""Exercise actual Tool9 ROM callbacks with host key-down/up injection."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import socket
import time
ROOT=Path(__file__).resolve().parents[2]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--session',required=True,type=Path)
    p.add_argument('--initial-modes',type=lambda v:int(v,0),default=0,help='Diagnostic fixture sets these mode bits before component startup, then restores the real caller')
    p.add_argument('--base',type=lambda v:int(v,0),default=0xa0000)
    args=p.parse_args(); session=json.loads(args.session.read_text());folder=args.session.parent
    manifest=json.loads((folder/'build-manifest.json').read_text());symbols=manifest['symbols']
    assert hashlib.sha256((folder/'Start').read_bytes()).hexdigest()==manifest['binary_sha256']==session['binary_sha256']
    sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
    from gs2debug import Client,BP_KIND_EXEC,BP_FLAG_ENABLED,BP_FLAG_TEMPORARY
    deadline=time.monotonic()+30
    while not Path(session['socket']).exists():
        if time.monotonic()>deadline:raise TimeoutError('Debugger socket')
        time.sleep(.05)
    c=Client();c.connect(session['socket']);c.hello()
    def read(name,count=2):return c.read_mem(0,args.base+symbols[name],count)
    def word(name):return int.from_bytes(read(name),'little')
    checks=[];held=set(); pressed=set()
    def expect(label):
        expected=bytes(sum(1<<(code%8) for code in held if code//8==i) for i in range(16))
        end=time.monotonic()+3
        dirs=(1 if held & {0x3e,0x0d} else 0)|(2 if held & {0x3d,0x01} else 0)|(4 if held & {0x3b,0x00} else 0)|(8 if held & {0x3c,0x02} else 0)
        values=[dirs,int(0x31 in held),int(1 in held),int(0x22 in held),int(0x35 in held),int({0x36,0x0c} <= held)]
        normalized=b''.join(value.to_bytes(2,'little') for value in values)
        while read('input_sampled',16)!=expected or read('input_dirs_value',12)!=normalized:

            if word('input_fault'):raise AssertionError(('input fault',word('input_fault')))
            if time.monotonic()>end:raise AssertionError((label,read('input_sampled',16).hex(),expected.hex()))
            time.sleep(.01)
        checks.append(label)
    def down(sdl,adb):c.key_down(sdl);pressed.add(sdl);held.add(adb)
    def up(sdl,adb):c.key_up(sdl);pressed.discard(sdl);held.discard(adb)
    try:
        if args.initial_modes:
            assert 0<args.initial_modes<256
            bp=c.bp_set(kind=BP_KIND_EXEC,address=args.base+symbols['probe_setup_entry'],flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
            c.continue_();end=time.monotonic()+120
            while True:
                try:event=c.wait_stopped(timeout=min(5,max(.01,end-time.monotonic())))
                except (TimeoutError,socket.timeout):
                    if time.monotonic()>end:raise TimeoutError('Mode fixture startup')
                    continue
                assert event.bp_id==bp
                break
            assert read('probe_signature',8)==b'RGADB001'
            c.write_mem(0,args.base+symbols['probe_test_mode_mask'],args.initial_modes.to_bytes(2,'little'))
        c.continue_();end=time.monotonic()+120
        while read('probe_signature',8)!=b'RGADB001' or word('probe_ready')!=1:
            if time.monotonic()>end:raise TimeoutError('Native input probe startup')
            time.sleep(.1)
        assert word('probe_error')==0,word('probe_error')
        initial={'modes':read('input_old_mode',1).hex(),'config':read('input_config',3).hex(),'status':word('input_initial_status')}
        expect('initial neutral')
        down(79,0x3c);expect('right down')
        down(82,0x3e);down(44,0x31);expect('right up-arrow and fire held together')
        up(79,0x3c);expect('right released independently')
        up(44,0x31);expect('fire released while up remains')
        up(82,0x3e);expect('all released')
        down(224,0x36);down(20,0x0c);expect('control plus Q')
        up(224,0x36);expect('modifier released first')
        up(20,0x0c);expect('Q released')
        down(44,0x31);down(44,0x31);expect('duplicate down remains held')
        up(44,0x31);expect('duplicate down needs one release')
        down(26,0x0d);down(7,0x02);expect('W D movement')
        down(22,0x01);expect('S gives down and start')
        # Matching GSSquared refills its two-byte ADB register only on SDL
        # events, not on Talk; three events queued before a poll strand the
        # third until another host event. Keep this functional mapping test
        # to one independent release at a time; retain the burst failure.
        up(26,0x0d);expect('W released while D S remain')
        up(7,0x02);expect('D released while S remains')
        up(22,0x01);expect('WASD released')
        down(12,0x22);expect('instructions key')
        up(12,0x22);down(41,0x35);expect('Escape gives runstop')
        up(41,0x35);expect('menu keys released')
        before=word('input_event_counter');down(44,0x31);up(44,0x31)
        end=time.monotonic()+3
        while (word('input_event_counter')-before)&65535 < 2:
            if time.monotonic()>end:raise TimeoutError('Short tap callback')
            time.sleep(.01)
        expect('short tap does not stick')
        # Stop at the call site after pending publication, before ROM submission.
        # A real accepted packet is then outstanding when closing is requested.
        c.pause();c.wait_stopped(timeout=5)
        bp=c.bp_set(kind=BP_KIND_EXEC,address=args.base+symbols['input_submit'],flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
        c.continue_();event=c.wait_stopped(timeout=5);assert event.bp_id==bp
        assert word('input_pending')==1
        before_close=word('input_packet_counter')
        c.write_mem(0,args.base+symbols['probe_command'],b'\xff\0')
        quit_bp=c.bp_set(kind=BP_KIND_EXEC,address=args.base+symbols['probe_quit'],flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
        c.continue_();event=c.wait_stopped(timeout=10);assert event.bp_id==quit_bp
        for name in ('input_pending','input_tool_owned','input_mode_owned','input_active','input_cleanup_error','input_fault'):
            assert word(name)==0,(name,word(name))
        assert word('input_packet_counter')!=before_close, 'Submitted callback did not drain'
        assert read('input_exit_mode',1)==read('input_old_mode',1), 'Unrelated ADB mode bits changed'
        checks.append('outstanding callback drained and all mode bits restored before QuitGS')
        if args.initial_modes:
            assert word('input_old_mode')&args.initial_modes==args.initial_modes
            assert word('probe_test_error')==0 and word('probe_test_tool_owned')==0 and word('probe_test_owned_mask')==0
            assert read('probe_test_exit_mode',1)==read('probe_test_caller_mode',1)
            checks.append('fixture restores original caller after testing pre-disabled autopoll and unrelated mode bit')
        result={'pass':True,'scope':'native Tool9 keyboard callbacks and release semantics; not gameplay timing','checks':checks,'initial':initial,'fixture_initial_mode_mask':args.initial_modes,'packet_count':word('input_packet_counter'),'event_count':word('input_event_counter'),'busy_count':word('input_busy_count'),'session':session,'helper_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        (folder/'input-proof.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps({'pass':True,'checks':len(checks),'proof':str(folder/'input-proof.json')}))
    finally:
        diagnostics={name:read(name,16 if name in ('input_held','input_sampled') else 2).hex() for name in ('input_pending','input_fault','input_active','input_packet_counter','input_busy_count','input_held','input_sampled')}
        (folder/'input-final-state.json').write_text(json.dumps(diagnostics,indent=2)+'\n')
        for key in pressed:c.key_up(key)
        c.quit()
if __name__=='__main__':main()
