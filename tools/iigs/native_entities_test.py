#!/usr/bin/env python3
"""Fixed-call group3 entities equivalence; no realtime, input-device, audio, or full-mode claim."""
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
    parser.add_argument('--case',choices=['all','spawn','damage','cargo','parcels'],default='all')
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
    shutil.copy2(Path(__file__), folder/'native_entities_test.py')
    fields = sorted(mapping['state'])
    # Only common exported representations; death-banner inactive caches are absent.
    for name in fields:
        assert name in schema, name
        assert all(mapping['state'][name][k] == schema[name][k] for k in ('width','count')), name
    assert len(fields) == 142, len(fields)
    sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
    from gs2debug import Client
    client = Client()
    checks = []
    commands = ['bare']
    context = {'direct_calls_only':True, 'death_banner_owned':False}
    proof = {'scope':__doc__, 'case':args.case, 'fields':fields, 'binary_sha256':sha(folder/'Start'),
             'normalized_representation_exclusions':{'mode_state':{'source':['src/c64/render/bullets.asm:359','src/c64/game/drones.asm:768'],'reason':'Direct API fixture context only, never mode_run: bullet launch uses mode_state as temporary half-bit; drones apply_bullet_hit reloads the explicitly seeded target slot from mode_state. C uses locals/argument. Active full-mode context must be projected separately.'},'rail_reset':{'fields':['rail_dmg_amt','rail_hit_left','rail_hit_slot'],'reason':'Original rail::reset clears damage/heal arrays only; C also initializes scratch. Immediate strike_frame_reset restores shared FF hit-slot contract; remaining scratch is initially zero.'},'inactive_death_cache':'src/c64/game/player.asm:init clears all death fields on respawn; C player_init leaves old values. Excluded only after both player_dead==0 and native deploy_timer>0, with death-banner fixture ownership established.', 'banner_span':'After death banner takes ownership, shared C64 banner_col/len project to C death_banner_col/len; normal inactive cache is not compared.'},
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
        def fresh():
            ctl.command(1); commands[:]=['bare']; compare('bare')
            for native,host_name in [('objects::init','objects_init'),('screen_clear','screen_clear'),('rail::reset','rail_reset'),('rail::strike_frame_reset','rail_strike_frame_reset'),('bullets::init','bullets_init'),('cargo::init','cargo_init'),('parcels::init','parcels_init'),('drones::init','drones_init')]: call(native,host_name)
        if args.case in ('all','spawn'):
            fresh()
            seed('lives',0,4); seed('level',0,15)
            call('player::begin_deploy','player_begin_deploy')
            for i in range(45):call('player::update','player_update')
            for name,value in [('level_quota',255),('level_kills',200),('wave_flags',2),('wave_quad_mask',15),('wave_max_active',7),('wave_cd_min',1),('wave_cd_max',1),('drone_spawn_timer',1),('drone_speed_cap',15),('rng_state',17)]:seed(name,0,value)
            for i in range(120):
                seed('frame_count',0,i)
                call('drones::update','drones_update')
                call('cargo::update','cargo_update')
                call('parcels::update','parcels_update')
                call('objects::reap','objects_reap')
        if args.case in ('all','damage'):
            # A drone's HP, scoring, explosion, retirement; dying hits are ignored.
            fresh(); seed('level_quota',0,20)
            ret,outputs=call('objects::alloc','objects_alloc')
            slot=ret['x']; assert slot==1
            for name,value in [('flags',3),('kind',1),('reserved',3),('x_lo',80),('y_int',100)]:seed('objects.'+name,slot,value)
            seed('mode_state',0,slot)  # Original routine explicitly reloads slot from mode_state.
            for i in range(4):call('drones::apply_bullet_hit','drones_apply_bullet_hit',slot,x=slot)
            seed('wave_max_active',0,0)
            for i in range(60):
                call('drones::update','drones_update')
                call('objects::reap','objects_reap')
        if args.case in ('all','cargo'):
            # Cargo transport into each hub and full stacks/mine detonation.
            fresh()
            ret,outputs=call('objects::alloc','objects_alloc'); slot=ret['x']
            for name,value in [('flags',3),('kind',3),('x_lo',145),('y_int',122)]:seed('objects.'+name,slot,value)
            for hub in range(4):
                call('cargo::on_c_impact','cargo_on_c_impact',slot,x=slot)
                for i in range(30):call('cargo::update','cargo_update')
            assert ctl.snapshot(['ghij_stack','cargo_slot']) == {'ghij_stack':[1,1,1,1],'cargo_slot':255}
            call('cargo::reward_level_clear','cargo_reward_level_clear')
            assert ctl.snapshot(['ghij_stack'])['ghij_stack']==[1,1,1,0]
            for hub in range(4):seed('ghij_stack',hub,3)
            seed('mine_armed',0,1)
            call('player::begin_deploy','player_begin_deploy')
            for i in range(45):call('player::update','player_update')
            seed('objects.x_lo',0,169);seed('objects.x_hi',0,0);seed('objects.y_int',0,146)
            call('player::update','player_update')
        if args.case in ('all','parcels'):
            # Parcel threshold debt and actual spawning/travel/offscreen retirement.
            fresh()
            for name,value in [('level',1),('level_quota',9),('level_kills',3),('rng_state',29)]:seed(name,0,value)
            call('parcels::on_kill','parcels_on_kill')
            for i in range(220):call('parcels::update','parcels_update')
            seed('level_kills',0,6);call('parcels::on_kill','parcels_on_kill')
            for i in range(220):call('parcels::update','parcels_update')
            # All six pickup payloads with a live overlapping player.
            for payload in range(6):
                fresh();seed('lives',0,4)
                call('player::begin_deploy','player_begin_deploy')
                seed('deploy_timer',0,0);seed('lives',0,3);seed('objects.flags',0,3)
                seed('objects.x_lo',0,169);seed('objects.x_hi',0,0);seed('objects.y_int',0,146)
                ret,outputs=call('objects::alloc','objects_alloc');slot=ret['x']
                for name,value in [('flags',3),('kind',4),('x_lo',169),('y_int',146)]:seed('objects.'+name,slot,value)
                seed('parcel_slot',0,slot);seed('parcel_type',0,payload)
                seed('rail_dmg_d',10,2)
                call('parcels::update','parcels_update')
                pickup=ctl.snapshot(['parcel_slot','score0','score_2x','power_2x','clear_armed','lives','repair_timer'])
                assert pickup['parcel_slot']==255, ('pickup not collected',payload,pickup)
                name,value=[('score0',5),('score_2x',1),('power_2x',1),('clear_armed',1),('lives',4),('repair_timer',None)][payload]
                assert pickup[name]>0 if value is None else pickup[name]==value, (payload,pickup)
        proof['passed']=True
    except Exception as error:
        proof['passed']=False; proof['error']=repr(error)
        raise
    finally:
        (folder/'entities-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
        client.quit()
    print(json.dumps({'passed':True,'checks':len(checks),'fields':len(fields),'proof':str(folder/'entities-proof.json')}))

if __name__ == '__main__':
    main()
