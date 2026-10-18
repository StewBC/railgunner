#!/usr/bin/env python3
"""Fixed-call group4 progression equivalence; no realtime, input-device, audio, or full-mode claim."""
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
    shutil.copy2(Path(__file__), folder/'native_progress_test.py')
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
            ctl.command(1);commands[:]=['bare'];compare('bare')
            for native,host_name in [('objects::init','objects_init'),('screen_clear','screen_clear'),('rail::reset','rail_reset'),('rail::strike_frame_reset','rail_strike_frame_reset'),('cargo::init','cargo_init'),('parcels::init','parcels_init'),('score::reset','score_reset'),('tallies::reset','tallies_reset')]:call(native,host_name)
        fresh()
        for score in (0,1,254,255,256,65535,65536,999998,999999):
            for increment in (0,1,2,255):
                for i in range(3):seed('score'+str(i),0,(score>>(8*i))&255)
                call('score::add_n','score_add_n',increment,a=increment)
                call('score::paint_if_dirty','score_paint_if_dirty')
        for multiplier in (0,1):
            for i in range(3):seed('score'+str(i),0,0)
            seed('score_2x',0,multiplier);seed('power_2x',0,1);call('score::add_hit','score_add_hit')
            assert ctl.snapshot(['score0'])['score0']==1+multiplier
        for value in (0,255,256,65534,65535):
            seed('tally_shots',0,value);call('tallies::note_shot','tallies_note_shot')
            for kind,name in [(1,'a'),(2,'b'),(3,'c')]:
                seed('objects.kind',1,kind);seed('tally_kill_'+name,0,value)
                call('tallies::note_kill','tallies_note_kill',1,x=1)
        for lives in (0,1,4,8,255):
            for level in (1,15,255):
                seed('lives',0,lives);seed('level',0,level);seed('level_quota',0,20);seed('level_kills',0,19)
                call('hud::paint_full_line','hud_paint_full_line')
                seed('hud_status_dirty',0,1);call('hud::paint_status_if_dirty','hud_paint_status_if_dirty')
        for level in (0,1,2,8,15,255):
            seed('level',0,level);seed('rail_dmg_d',10,2)
            call('waves::load','waves_load')
            assert ctl.snapshot(['rail_dmg_d'])['rail_dmg_d'][10]==2
        for level in (1,15):
            fresh();seed('level',0,level);seed('level_quota',0,3);seed('level_kills',0,3)
            seed('rail_dmg_d',10,2);seed('ghij_stack',0,1);seed('ghij_last',0,0)
            call('waves::check_clear','waves_check_clear')
            remaining=ctl.snapshot(['level_banner_t'])['level_banner_t'];assert remaining>0
            for i in range(remaining):call('waves::update_banner','waves_update_banner')
            current=ctl.snapshot(['level','victory','pending_mode','rail_dmg_d'])
            assert current['rail_dmg_d'][10]==2
            assert current['level']==(2 if level==1 else 15)
            assert current['victory']==(1 if level==15 else 0)
        for victory in (0,1):
            fresh();seed('level',0,15);seed('victory',0,victory)
            seed('score0',0,63);seed('score1',0,66);seed('score2',0,15)
            for name,value in [('tally_shots',65535),('tally_kill_a',999),('tally_kill_b',1000),('tally_kill_c',65535)]:seed(name,0,value)
            call('tallies::paint_gameover','tallies_paint_gameover')
        proof['passed']=True
    except Exception as error:
        proof['passed']=False; proof['error']=repr(error)
        raise
    finally:
        (folder/'progress-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
        client.quit()
    print(json.dumps({'passed':True,'checks':len(checks),'fields':len(fields),'proof':str(folder/'progress-proof.json')}))

if __name__ == '__main__':
    main()
