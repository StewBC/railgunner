#!/usr/bin/env python3
"""Compare every fixed native tick in the 13 existing traces, without audio.

C64-authority host overrides are explicit. Only MODE_PLAY transient mode_state scratch is projected; shared banner spans
compare strictly through the reviewed C64-authority aliases.
This is a semantic diagnostic, not a realtime performance measurement.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import time
import native_oracle
from native_core_test import Controller, ROOT


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--session',type=Path,required=True)
    p.add_argument('--map',type=Path,required=True)
    p.add_argument('--base',type=lambda x:int(x,0),default=0xa0000)
    p.add_argument('--trace',action='append',type=Path)
    args=p.parse_args()
    session=json.loads(args.session.read_text());folder=args.session.parent
    mapping=json.loads(args.map.read_text())
    manifest=json.loads((folder/'build-manifest.json').read_text())
    assert sha(folder/'Start')==session['binary_sha256']
    assert [v for k,v in manifest['hashes'].items() if k.endswith('/state-map.json')]==[sha(args.map)]
    shutil.copy2(args.map,folder/'tested-state-map.json')
    built,host_manifest=native_oracle.build(authority='c64')
    assert host_manifest['authority']=='c64'
    host=folder/'host-oracle';shutil.copy2(built,host)
    (folder/'host-oracle-manifest.json').write_text(json.dumps(host_manifest,indent=2)+'\n')
    for origin,metadata in [('native',manifest),('host',host_manifest)]:
        for relative,expected in metadata['hashes'].items():
            source=ROOT/relative
            assert sha(source)==expected, ('Source changed before freeze',relative)
            dest=folder/(origin+'-source-snapshot')/relative
            dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
    for name in ('native_full_test.py','native_core_test.py','native_oracle.py'):
        shutil.copy2(ROOT/'tools/iigs'/name,folder/name)
    schema=json.loads((built.parent/'schema.json').read_text())
    shutil.copy2(built.parent/'schema.json',folder/'host-schema.json')
    fields=sorted(mapping['state'])
    assert len(fields)==144
    for n,spec in mapping['state'].items():
        assert {k:spec[k] for k in ('width','count')}==schema[n]
    paths=args.trace or [ROOT/'tst/core'/name for name in ('hud.trace','audio.trace','story.trace','bullet.trace','hit.trace','quota.trace','tally.trace','hiscore.trace','cargo.trace','rail.trace','mine.trace','parcel.trace','gameover.trace')]
    paths=[path if path.is_absolute() else ROOT/path for path in paths]
    proof={'scope':__doc__,'binary_sha256':sha(folder/'Start'),'map_sha256':sha(args.map),
           'host_sha256':sha(host),'authority':'c64','direct_fields':fields,
           'emulator_speed':session['speed'],'helper_sha256':sha(Path(__file__)),
           'controller_sha256':sha(folder/'native_core_test.py'),
           'derived_fields':['type_src_id','type_src_offset','death_banner_col','death_banner_len'],
           'activation_rules':{
               'mode_state':'Strict in every frontend; original scratch target/half only in MODE_PLAY(3).',
               'banner_col/banner_len/death_banner_col/death_banner_len':'Both name pairs alias the one original physical span; reviewed C64-authority oracle exposes the same alias, all four compare strictly.'},
           'traces':[]}
    sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
    from gs2debug import Client
    client=Client()
    try:
        client.connect(session['socket']);client.hello();client.continue_()
        deadline=time.monotonic()+180
        while client.read_mem(0,args.base+mapping['mailbox']['core_ready'],2)!=b'\1\0':
            if time.monotonic()>deadline:raise TimeoutError('CORETEST startup')
            time.sleep(.1)
        assert client.read_mem(0,args.base+mapping['mailbox']['core_mailbox'],8)==mapping['signature'].encode()
        ctl=Controller(client,mapping,args.base)
        ptr_off=mapping['raw_dp']['type_src_lo']['offset']
        assert mapping['raw_dp']['type_src_hi']['offset']==ptr_off+1
        def snapshot():
            spaces={'game':ctl.game,'dp':ctl.dp,'driver':ctl.base};images={}
            for space,base in spaces.items():
                spans=[(part['offset'],part['offset']+part['count']*spec['width']) for spec in mapping['state'].values() if spec['space']==space for part in spec.get('parts',[spec])]
                if space=='dp':spans.append((ptr_off,ptr_off+2))
                first=min(a for a,b in spans);last=max(b for a,b in spans)
                if space=='driver':
                    cached_first,cached=ctl.last_completion
                    assert cached_first<=first and last<=cached_first+len(cached),'Frame not covered by published completion record'
                    images[space]=(cached_first,cached)
                else:
                    images[space]=(first,ctl.read(base+first,last-first))
            actual={}
            for name,spec in mapping['state'].items():
                first,raw=images[spec['space']]
                packed=b''.join(raw[part['offset']-first:part['offset']-first+part['count']*spec['width']] for part in spec.get('parts',[spec]))
                assert len(packed)==spec['count']*spec['width']
                values=[int.from_bytes(packed[i:i+spec['width']],'little') for i in range(0,len(packed),spec['width'])]
                actual[name]=values[0] if spec['count']==1 else values
            first,raw=images['dp'];pointer=int.from_bytes(raw[ptr_off-first:ptr_off-first+2],'little')
            source_id=0;offset=0
            if pointer:
                for ident,name in [(1,'story_text'),(2,'instructions_text')]:
                    data=mapping['native_data'][name];start=(ctl.game+data['offset'])&65535
                    if start<=pointer<start+data['bytes']:
                        source_id=ident;offset=pointer-start;break
                assert source_id, ('Unknown native text pointer',hex(pointer))
            actual['type_src_id']=source_id;actual['type_src_offset']=offset
            actual['death_banner_col']=actual['banner_col'];actual['death_banner_len']=actual['banner_len']
            return actual
        def compare(actual,expected,record):
            excluded=set()
            if expected['mode']==3:excluded.add('mode_state')
            differences={n:{'native':actual[n],'oracle':expected[n]} for n in actual if n not in excluded and actual[n]!=expected[n]}
            if differences:
                proof['failure']={'trace':record['name'],'frame':expected['frame'],'differences':differences}
                raise AssertionError(proof['failure'])
            payload=json.dumps({n:actual[n] for n in sorted(actual) if n not in excluded},sort_keys=True,separators=(',',':')).encode()
            record['_digest'].update(payload)
            record['comparisons']+=1
            record['minimum_active_fields']=min(record['minimum_active_fields'],len(actual)-len(excluded))
            for name in excluded:
                if actual[name]!=expected[name]:
                    record['projected_differences'][name]=record['projected_differences'].get(name,0)+1
        for path in paths:
            source=path.read_text().split('===',1)[0]
            commands=[line.strip() for line in source.splitlines() if line.strip() and not line.lstrip().startswith('#') and line.strip()!='dump']
            expected=native_oracle.run_commands('reset\ndump\n'+'\n'.join(commands)+'\n',each_tick=True,binary=host)
            ticks=sum(line=='tick' for line in commands)
            assert len(expected)==ticks+1,(path,len(expected),ticks)
            ctl.command(1,variant=1)
            record={'name':path.name,'trace_sha256':sha(path),'ticks':ticks,'comparisons':0,'minimum_active_fields':148,'projected_differences':{},'_digest':hashlib.sha256()}
            proof['traces'].append(record)
            compare(snapshot(),expected[0],record)
            inputs={'dirs':0,'fire':0,'key_s':0,'key_i':0,'runstop':0};frame=0
            for line in commands:
                parts=line.split()
                if parts[0]=='dir':inputs['dirs']={'U':1,'D':2,'L':4,'R':8,'N':0}[parts[1]]
                elif parts[0]=='fire':inputs['fire']=int(parts[1])
                elif parts[0]=='key':inputs[{'S':'key_s','I':'key_i','RUNSTOP':'runstop'}[parts[1]]]=int(parts[2])
                elif line=='tick':
                    ctl.command(2,inputs=inputs);frame+=1;compare(snapshot(),expected[frame],record)
                    if frame%250==0:print(json.dumps({'trace':path.name,'frame':frame,'ticks':ticks}),flush=True)
                else:raise ValueError('Unsupported original trace command: '+line)
            record['normalized_sha256']=record.pop('_digest').hexdigest()
            print(json.dumps({'trace':path.name,'passed':True,'ticks':ticks}),flush=True)
        proof['passed']=True
    except Exception as error:
        proof['passed']=False;proof['error']=repr(error);raise
    finally:
        for record in proof['traces']:
            if '_digest' in record:record['normalized_sha256']=record.pop('_digest').hexdigest()
        (folder/'full-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
        try:client.quit()
        except (OSError,RuntimeError):pass
    print(json.dumps({'passed':True,'ticks':sum(r['ticks'] for r in proof['traces']),'proof':str(folder/'full-proof.json')}))

if __name__=='__main__':
    main()
