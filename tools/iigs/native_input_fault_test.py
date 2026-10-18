#!/usr/bin/env python3
"""Injected Tool9 status branches; never claims real hardware command failure.

Runtime errors are injected only after the real request completed. An artificial
pending flag models ambiguous lifetime; clearing that artificial flag to finish
the test is not an ADB cancellation mechanism.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import socket
import sys
import time
ROOT=Path(__file__).resolve().parents[2]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--session',type=Path,required=True)
    p.add_argument('--scenario',choices=['read-modes','read-config','set-mode','busy','ambiguous'],required=True)
    p.add_argument('--base',type=lambda s:int(s,0),default=0xa0000)
    args=p.parse_args();session=json.loads(args.session.read_text());folder=args.session.parent
    manifest=json.loads((folder/'build-manifest.json').read_text());symbols=manifest['symbols']
    assert hashlib.sha256((folder/'Start').read_bytes()).hexdigest()==manifest['binary_sha256']==session['binary_sha256']
    sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
    from gs2debug import Client,BP_KIND_EXEC,BP_FLAG_ENABLED,BP_FLAG_TEMPORARY,REG_A,REG_P
    end=time.monotonic()+30
    while not Path(session['socket']).exists():
        if time.monotonic()>end:raise TimeoutError('Debugger socket')
        time.sleep(.05)
    c=Client();c.connect(session['socket']);c.hello()
    def addr(name):return args.base+symbols[name]
    def read(name,n=2):return c.read_mem(0,addr(name),n)
    def word(name):return int.from_bytes(read(name),'little')
    def write(name,value):c.write_mem(0,addr(name),value.to_bytes(2,'little'))
    def arm(name):return c.bp_set(kind=BP_KIND_EXEC,address=addr(name),flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
    def reach(bp,timeout=120):
        c.continue_();end=time.monotonic()+timeout
        while time.monotonic()<end:
            try:event=c.wait_stopped(timeout=min(5,end-time.monotonic()))
            except (TimeoutError,socket.timeout):continue
            assert event.bp_id==bp,event
            return c.get_regs()
        raise TimeoutError('Expected native breakpoint')
    result={'scope':__doc__,'scenario':args.scenario,'session':session,'helper_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    try:
        runtime=args.scenario in ('busy','ambiguous')
        label={'read-modes':'input_modes_result','read-config':'input_config_result','set-mode':'input_set_mode_result','busy':'input_submit_result','ambiguous':'input_submit_result'}[args.scenario]
        raw=reach(arm(label))
        assert read('probe_signature',8)==b'RGADB001'
        assert raw[13]&0x30==0, 'Foreground injection requires native16'
        if runtime:
            # The actual callback must already be complete before fabricating
            # an outstanding request, so no real callback can be unloaded.
            assert word('input_pending')==0,'Real request has not completed; do not inject'
            write('input_pending',1)
        error=0x0982 if args.scenario=='busy' else 0x0910
        c.set_regs(REG_A|REG_P,a=error,p=raw[13]|1)
        reach(arm('probe_wait'))
        if args.scenario=='busy':
            assert word('input_pending')==0 and word('input_fault')==0
            assert word('input_busy_count')==1
        elif args.scenario=='ambiguous':
            assert word('input_pending')==1 and word('input_fault')==error
            assert read('input_sampled',16)==bytes(16)
        else:
            assert word('probe_error')==error and word('input_active')==0
            assert word('input_pending')==0
        write('probe_command',255)
        if args.scenario=='ambiguous':
            reach(arm('probe_closing'),10)
            # Retain ownership and executable memory while lifetime is unknown.
            c.continue_();time.sleep(.05);c.pause();c.wait_stopped(timeout=5)
            assert word('input_pending')==1 and word('input_tool_owned')==1 and word('input_mode_owned')==1
            pc=struct.unpack_from('<H',c.get_regs(),16)[0]
            assert pc not in (symbols['probe_quit'],0xc071)
            result['retained_pending_state']={n:word(n) for n in ('input_pending','input_tool_owned','input_mode_owned','input_active','input_fault')}
            write('input_pending',0) # Release only the fabricated test condition.
        reach(arm('probe_quit'),10)
        for name in ('input_pending','input_tool_owned','input_mode_owned','input_active','input_cleanup_error'):
            assert word(name)==0,(name,word(name))
        if word('input_mode_known'):
            assert read('input_exit_mode',1)==read('input_old_mode',1)
        result['pass']=True
        result['fault']=word('input_fault')
        (folder/'input-fault-proof.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps({'pass':True,'scenario':args.scenario,'proof':str(folder/'input-fault-proof.json')}))
    finally:
        diagnostics={'regs':c.get_regs().hex(),'breakpoints':[str(bp) for bp in c.bp_list()],'pending':word('input_pending'),'fault':word('input_fault'),'ready':word('probe_ready')}
        (folder/'input-fault-final-state.json').write_text(json.dumps(diagnostics,indent=2)+'\n')
        c.quit()
if __name__=='__main__':main()
