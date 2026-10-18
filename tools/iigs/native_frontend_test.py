#!/usr/bin/env python3
"""Native group5 frontends and fixed-tick equivalence; no realtime, input-device, audio, or full-mode claim."""
import argparse
import hashlib
import json
import shutil
import sys
import time
from pathlib import Path
import native_oracle
from native_core_test import Controller, ROOT


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session', type=Path, required=True)
    parser.add_argument('--map', type=Path, required=True)
    parser.add_argument('--base', type=lambda s: int(s, 0), default=0xa0000)
    args = parser.parse_args()
    session = json.loads(args.session.read_text())
    folder = args.session.parent
    mapping = json.loads(args.map.read_text())
    manifest = json.loads((folder/'build-manifest.json').read_text())
    assert sha(folder/'Start') == session['binary_sha256']
    bindings = [v for k,v in manifest['hashes'].items() if k.endswith('/state-map.json')]
    assert bindings == [sha(args.map)], 'Map is not bound to this guest'
    shutil.copy2(args.map, folder/'tested-state-map.json')
    built, host_manifest = native_oracle.build(authority='c64')
    assert host_manifest['authority']=='c64'
    host = folder/'host-oracle'
    shutil.copy2(built, host)
    (folder/'host-oracle-manifest.json').write_text(json.dumps(host_manifest, indent=2)+'\n')
    schema = json.loads((built.parent/'schema.json').read_text())
    shutil.copy2(built.parent/'schema.json', folder/'host-schema.json')
    shutil.copy2(Path(__file__), folder/'native_frontend_test.py')
    fields = sorted(mapping['state'])
    # Every exported direct field compares strictly against the C64 authority.
    for name in fields:
        assert name in schema, name
        assert all(mapping['state'][name][k] == schema[name][k] for k in ('width','count')), name
    assert len(fields) == 144, len(fields)
    sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
    from gs2debug import Client
    for origin,metadata in [('host',host_manifest),('native',manifest)]:
        for rel,expected in metadata['hashes'].items():
            source=ROOT/rel
            assert sha(source)==expected, ('Source changed before freeze',rel)
            target=folder/(origin+'-source-snapshot')/rel
            target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    shutil.copy2(ROOT/'tools/iigs/native_core_test.py',folder/'native_core_test.py')
    client = Client()
    checks = []
    commands = ['bare']
    proof = {'scope':__doc__, 'fields':fields, 'binary_sha256':sha(folder/'Start'),
             'normalized_representation_exclusions':{},
             'map_sha256':sha(args.map), 'host_sha256':sha(host), 'schema_sha256':sha(folder/'host-schema.json'), 'helper_sha256':sha(Path(__file__)), 'checks':checks, 'commands':commands}
    try:
        client.connect(session['socket']); client.hello(); client.continue_()
        deadline = time.monotonic()+180
        while client.read_mem(0,args.base+mapping['mailbox']['core_ready'],2) != b'\1\0':
            assert time.monotonic()<deadline, 'Guest boot timeout'
            time.sleep(.1)
        assert client.read_mem(0,args.base+mapping['mailbox']['core_mailbox'],8) == mapping['signature'].encode()
        ctl = Controller(client,mapping,args.base)
        def compare(label):
            outputs = native_oracle.run_commands('\n'.join(commands+['dump'])+'\n', binary=host)
            expected = outputs[-1]
            actual = ctl.snapshot(fields)
            differences = {n:{'native':actual[n],'oracle':expected[n]} for n in fields if actual[n]!=expected[n]}
            assert not differences, (label,differences)
            checks.append({'label':label,'compared_fields':len(fields)})
            return outputs
        def seed(name,index,value):
            spec=mapping['state'][name]
            base={'game':ctl.game,'dp':ctl.dp,'driver':ctl.base}[spec['space']]
            client.write_mem(0,base+spec['offset']+index*spec['width'],value.to_bytes(spec['width'],'little'))
            commands.append(f'set {name} {index} {value}')
        def call(native,host_name,*host_args,**args):
            ret=ctl.invoke(native,**args)
            commands.append('call '+host_name+''.join(' '+str(v) for v in host_args))
            return ret,compare(host_name)
        def reset(cold=True):
            ctl.command(1,variant=1 if cold else 0)
            commands[:]=['reset' if cold else 'bare'];compare('cold' if cold else 'bare')
        reset(False);reset(True)
        call('title_text_enter','title_text_enter')
        for i in range(12):
            call('title_text_rotate_colors','title_text_rotate_colors')
            call('title_text_color_scores','title_text_color_scores')
        for stem in ('story','instructions'):
            call(stem+'_enter',stem+'_enter')
            for i in range(30):call(stem+'_update',stem+'_update')
            seed('input_fire_edge',0,1);call(stem+'_update',stem+'_update')
            seed('input_fire_edge',0,0)
            for i in range(20):call(stem+'_update',stem+'_update')
            seed('input_fire_edge',0,1);call(stem+'_update',stem+'_update')
            seed('input_fire_edge',0,0)
        seed('score0',0,123);seed('level',0,5);seed('tally_shots',0,99)
        ret,outputs=call('hiscore_qualifies','hiscore_qualifies')
        result=[o for o in outputs if o.get('kind')=='call'][-1]
        assert bool(ret['p']&1)==bool(result['value'])
        call('mode_set','mode_set',8,a=8)
        for inputs in ({'dirs':1},{'dirs':0},{'fire':1},{'fire':0},{'dirs':2},{'dirs':0},{'fire':1},{'fire':0},{'fire':1},{'fire':0}):
            complete={'dirs':0,'fire':0,'key_s':0,'key_i':0,'runstop':0};complete.update(inputs)
            for short,name in [('dirs','input_dirs'),('fire','input_fire'),('key_s','input_key_s'),('key_i','input_key_i'),('runstop','input_runstop')]:
                commands.append(f'set {name} 0 {complete[short]}')
            ctl.command(2,inputs=complete);commands.append('tick');compare('fixed high-score tick')
        reset(True)
        assert ctl.word('core_frame',4)==0
        proof['passed']=True
    except Exception as error:
        proof['passed']=False; proof['error']=repr(error)
        raise
    finally:
        (folder/'frontend-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
        client.quit()
    print(json.dumps({'passed':True,'checks':len(checks),'fields':len(fields),'proof':str(folder/'frontend-proof.json')}))

if __name__ == '__main__':
    main()
