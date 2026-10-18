#!/usr/bin/env python3
"""Fixed-call group2 equivalence; no realtime, input-device, audio, or full-mode claim."""
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
    built, host_manifest = native_oracle.build()
    host = folder/'host-oracle'
    shutil.copy2(built, host)
    (folder/'host-oracle-manifest.json').write_text(json.dumps(host_manifest, indent=2)+'\n')
    schema = json.loads((ROOT/'build/iigs/native-oracle/schema.json').read_text())
    shutil.copy2(ROOT/'build/iigs/native-oracle/schema.json', folder/'host-schema.json')
    shutil.copy2(Path(__file__), folder/'native_gameplay_test.py')
    fields = sorted(mapping['state'])
    # Only common exported representations; death-banner inactive caches are absent.
    for name in fields:
        assert name in schema, name
        assert all(mapping['state'][name][k] == schema[name][k] for k in ('width','count')), name
    assert len(fields) == 139, len(fields)
    sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
    from gs2debug import Client
    client = Client()
    checks = []
    commands = ['bare']
    context = {'direct_calls_only':True, 'death_banner_owned':False}
    proof = {'scope':__doc__, 'fields':fields, 'binary_sha256':sha(folder/'Start'),
             'normalized_representation_exclusions':{'mode_state':{'source':'src/c64/render/bullets.asm:359','reason':'Original launch_lane stores temporary half-bit in inactive mode_state; C uses local. Full mode integration must project active context.'},'rail_reset':{'fields':['rail_dmg_amt','rail_hit_left','rail_hit_slot'],'reason':'Original rail::reset clears damage/heal arrays only; C also initializes scratch. Immediate strike_frame_reset restores shared FF hit-slot contract; remaining scratch is initially zero.'},'inactive_death_cache':'src/c64/game/player.asm:init clears all death fields on respawn; C player_init leaves old values. Excluded only after both player_dead==0 and native deploy_timer>0, with death-banner fixture ownership established.', 'banner_span':'After death banner takes ownership, shared C64 banner_col/len project to C death_banner_col/len; normal inactive cache is not compared.'},
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
            assert context['direct_calls_only'] and all(not c.startswith('tick') and 'mode_run' not in c for c in commands), 'Scratch projection requires direct API fixture context'
            if context['death_banner_owned']:
                for name in ('banner_col','banner_len'):
                    expected[name] = expected['death_'+name]
            excluded = {'rail_dmg_amt','rail_hit_left','rail_hit_slot'} if label == 'rail_reset' else set()
            if context['death_banner_owned'] and actual['player_dead']==0 and expected['player_dead']==0 and actual['deploy_timer']>0:
                assert actual['death_phase']==0 and actual['death_flash_t']==0
                excluded |= {'death_phase','death_flash_t'}
            differences = {n:{'native':actual[n],'oracle':expected[n]} for n in fields if n not in excluded | {'mode_state'} and actual[n]!=expected[n]}
            assert not differences, (label,differences)
            checks.append({'label':label,'compared_fields':len(fields)-len(excluded | {'mode_state'}),'excluded_values':{n:{'native':actual[n],'oracle':expected[n]} for n in excluded | {'mode_state'} if actual[n]!=expected[n]}})
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
        ctl.command(1); compare('bare')
        for native,host_name in [('objects::init','objects_init'),('screen_clear','screen_clear'),('rail::reset','rail_reset'),('rail::strike_frame_reset','rail_strike_frame_reset'),('bullets::init','bullets_init')]:
            call(native,host_name)
        call('rail::strike_frame_reset','rail_strike_frame_reset')
        seed('lives',0,4)
        call('player::begin_deploy','player_begin_deploy')
        for i in range(45): call('player::update','player_update')
        seed('input_fire',0,1)
        call('bullets::update','bullets_update')
        seed('input_fire',0,0)
        for i in range(100): call('bullets::update','bullets_update')
        for native,host_name in [('rail::strike_frame_reset','rail_strike_frame_reset'),('rail::clear_heal_marks','rail_clear_heal_marks'),('rail::begin_repair','rail_begin_repair')]:
            call(native,host_name)
        for i in range(20): call('rail::repair_tick','rail_repair_tick')
        ret,outputs=call('player::at_intersection','player_at_intersection')
        result=[o for o in outputs if o.get('kind')=='call'][-1]
        assert bool(ret['p']&1)==bool(result['value'])
        for glyph in range(256):
            ret,outputs=call('bullets::half_from_glyph','bullets_half_from_glyph',glyph,a=glyph)
            result=[o for o in outputs if o.get('kind')=='call'][-1]
            assert (ret['p']&1)==result['status'], (glyph,ret,result)
            if not result['status']:
                off=mapping['raw_dp']['tmp0']['offset']
                assert client.read_mem(0,ctl.dp+off,1)[0]==result['half']
        # Both directions, both rails, endpoint clamps, and mounting at centre.
        for rail,dirs,x,y,count in [(0,8,327,146,5),(0,4,14,146,5),(1,1,169,59,5),(1,2,169,233,5),(0,1,169,146,8),(1,8,169,146,8)]:
            for name,value in [('player_rail',rail),('input_dirs',dirs),('player_move_dir',0),('player_cross_decided',0),('player_swing_t',0)]: seed(name,0,value)
            seed('objects.x_lo',0,x&255); seed('objects.x_hi',0,x>>8); seed('objects.y_int',0,y)
            ret,outputs=call('player::at_intersection','player_at_intersection')
            result=[o for o in outputs if o.get('kind')=='call'][-1]
            assert bool(ret['p']&1)==bool(result['value'])
            for i in range(count): call('player::update','player_update')
        seed('input_dirs',0,0)
        # Deterministic find hit/miss and retirement, independent of launch geometry.
        seed('bullet_active',0,1); seed('bullet_col',0,7)
        seed('bullet_row',0,12); seed('bullet_half',0,0)
        for col in (7,8):
            for name,value in [('draw_i',col),('draw_j',12),('tmp0',0)]:
                client.write_mem(0,ctl.dp+mapping['raw_dp'][name]['offset'],bytes([value]))
            ret,outputs=call('bullets::find_at','bullets_find_at',col,12,0)
            result=[o for o in outputs if o.get('kind')=='call'][-1]
            assert (ret['p']&1)==result['status']
            if not result['status']: assert ret['x']==result['slot']
        call('bullets::destroy','bullets_destroy',0,x=0)
        # Valid drone impact geometry; repeated same-slot hit must be idempotent.
        for approach in range(4):
            seed('objects.user',1,approach)
            seed('objects.x_lo',1,80); seed('objects.x_hi',1,0)
            seed('objects.y_int',1,100); seed('rail_dmg_amt',0,2)
            call('rail::strike_frame_reset','rail_strike_frame_reset')
            call('rail::apply_ab_hit','rail_apply_ab_hit',1,x=1)
            call('rail::apply_ab_hit','rail_apply_ab_hit',1,x=1)
        call('rail::begin_repair','rail_begin_repair')
        for i in range(64): call('rail::repair_tick','rail_repair_tick')
        for fatal in (True,False):
            context['death_banner_owned']=False
            ctl.command(1); commands[:]=['bare']; compare('bare death fixture')
            for native,host_name in [('objects::init','objects_init'),('screen_clear','screen_clear'),('rail::reset','rail_reset'),('rail::strike_frame_reset','rail_strike_frame_reset'),('bullets::init','bullets_init')]: call(native,host_name)
            seed('lives',0,4)
            call('player::begin_deploy','player_begin_deploy')
            for i in range(45): call('player::update','player_update')
            routine='player_begin_death_fatal' if fatal else 'player_begin_death_respawn'
            call('player::begin_death_fatal' if fatal else 'player::begin_death_respawn',routine)
            for i in range(156):
                # Seven 8-tick frames precede the shared banner allocation.
                if i==55: context['death_banner_owned']=True
                call('player::update','player_update')
        proof['passed']=True
    except Exception as error:
        proof['passed']=False; proof['error']=repr(error)
        raise
    finally:
        (folder/'gameplay-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
        client.quit()
    print(json.dumps({'passed':True,'checks':len(checks),'fields':len(fields),'proof':str(folder/'gameplay-proof.json')}))

if __name__ == '__main__':
    main()
