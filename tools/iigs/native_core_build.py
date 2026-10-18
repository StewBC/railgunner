#!/usr/bin/env python3
"""Build N1 CORETEST with native 8-bit gameplay and explicit service replacements."""
from pathlib import Path
import hashlib
import argparse
import json
import re
import shutil
import subprocess
from native_core import Adapter
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/nativecore'
FIELDS='flags kind x_frac x_lo x_hi y_frac y_int sprite_ptr sprite_color sprite_attr vx_frac vx_lo vx_hi vy_frac vy_int hitbox_id pending_events anim_state user reserved'.split()
COMMANDS=[]
SHARED='core_command core_call_id core_arg_a core_arg_x core_arg_y core_arg_carry core_input_dirs core_input_fire core_input_key_s core_input_key_i core_input_runstop core_game_dp core_status core_ret_a core_ret_x core_ret_y core_ret_p'.split()

def run(command,log):
    p=subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
    (OUT/log).write_text(p.stdout)
    COMMANDS.append({'command':command,'returncode':p.returncode,'log':log})
    if p.returncode:raise RuntimeError(p.stdout[-12000:])
    return p.stdout

def main():
    global OUT
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--group',type=int,choices=[1,2,3,4,5],default=1)
    parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    OUT=(ROOT/args.out).resolve() if args.out else ROOT/('build/iigs/nativecore' if args.group==1 else 'build/iigs/nativecore-group'+str(args.group))
    if not OUT.is_relative_to(ROOT/'build'):raise ValueError('Generated native core files must remain under project build/')
    relative=OUT.relative_to(ROOT).as_posix()
    schema_path=ROOT/'build/iigs/native-oracle/schema.json'
    if not schema_path.exists():raise RuntimeError('Required host oracle schema missing: '+str(schema_path)+'; build the native_oracle host tool first')
    schema=json.loads(schema_path.read_text())
    if not schema or 'objects.flags' not in schema:raise RuntimeError('Host oracle schema is incomplete')
    OUT.mkdir(parents=True,exist_ok=True)
    policy=json.loads((ROOT/'src/iigs/core-manifest.json').read_text())
    extension={}
    if args.group>=2:
        extension=json.loads((ROOT/('src/iigs/core-group'+str(args.group)+'-manifest.json')).read_text())
        policy['stage']=extension['stage']
        for path,names in extension['modules'].items():policy['modules'][path]=list(dict.fromkeys(policy['modules'].get(path,[])+names))
        policy['native_replacements'].update(extension['native_replacements'])
        policy['instruction_replacements']=extension.get('instruction_replacements',{})
        policy['calls']=list(dict.fromkeys(policy['calls']+extension['calls']))
    policy['native_symbols']=list(policy['native_replacements'])+['SCREEN_RAM','COLOR_RAM','native_present','game_entry','core_bare']+SHARED+['objects::obj_'+f for f in FIELDS]+['objects::free_stack','objects::free_count','objects::mux_objects_dirty']
    if args.group>=5:policy['native_symbols'] += ['native_border','objects::profile_marker','core_variant','core_ticks']
    adapter=Adapter(ROOT,policy);adapter.constants_from('src/c64/sys/const.asm');used_dp=adapter.direct_page_from('src/c64/sys/zeropage.asm')
    for path,names in extension.get('constants',{}).items():adapter.selected_constants_from(path,names)
    for path,procedures in policy['modules'].items():adapter.select(path,procedures)
    mutable=[];immutable=[];data_layout={};all_layout={}
    if args.group>=2:
        from native_core_data import collect,emit
        rows=[]
        for path,names in extension['data'].items():rows.extend(collect(adapter,path,names))
        mutable,immutable,data_layout=emit(adapter,rows,initialized=extension.get('initialized_mutable',()),all_layout=all_layout)
        adapter.symbols.add('native_player_frame')
    translated=adapter.emit();(OUT/'translated.s').write_text(translated)
    wrapper=[' longa on',' longi on','game_entry ENTRY',' phb',' phd',' php',' rep #$30',' longa on',' longi on',' phk',' plb',' lda #game_entry',' cmp #65536-(game_end-game_entry)',' bcc game_bank_ok',' beq game_bank_ok',' lda #$FFFE',' sta >core_status',' jmp game_return','game_bank_ok anop',' lda >core_game_dp',' tcd',' sep #$30',' longa off',' longi off',' jsr game_dispatch',' php',' sta >core_ret_a',' txa',' sta >core_ret_x',' tya',' sta >core_ret_y',' pla',' sta >core_ret_p','game_return anop',' sep #$20',' longa off',' pla',' sta >game_saved_p',' rep #$30',' longa on',' longi on',' pld',' plb',' sep #$20',' longa off',' lda >game_saved_p',' pha',' plp',' rtl','game_saved_p ds 2',' longa off',' longi off','game_dispatch lda >core_command',' cmp #1',' bne game_select_call',' jmp core_bare','game_select_call lda >core_call_id+1',' beq game_call_low',' lda #5',' sta >core_status',' rts','game_call_low lda >core_call_id']
    if args.group>=5:
        index=wrapper.index('game_select_call lda >core_call_id+1')
        wrapper[index:index+1]=['game_select_call cmp #2',' bne game_invoke_command',' lda >core_ticks+1',' bne game_bad_tick',' lda >core_ticks',' cmp #1',' bne game_bad_tick',' jsr native_fixed_tick',' rts','game_bad_tick lda #4',' sta >core_status',' rts','game_invoke_command lda >core_call_id+1']
    for i,name in enumerate(policy['calls'],1):wrapper += [f' cmp #{i}',f' bne game_call_next_{i}',' lda >core_arg_x',' tax',' lda >core_arg_y',' tay',' lda >core_arg_carry',' lsr a',' lda >core_arg_a',f' jsr {adapter.flat(name)}',' rts',f'game_call_next_{i} anop']
    wrapper += [' lda #5',' sta >core_status',' rts']
    native=['core_bare anop',' rep #$30',' longa on',' longi on',' ldx #game_state_end-game_state-2',' lda #0','core_zero_state sta >game_state,x',' dex',' dex',' bpl core_zero_state',' sep #$30',' longa off',' longi off',' rts','objects__init anop',' lda #<objects_state',' sta ptr_lo',' lda #>objects_state',' sta ptr_hi',' ldx #2',' lda #0','objects_zero_page ldy #0','objects_zero_byte sta (ptr_lo),y',' iny',' bne objects_zero_byte',' inc ptr_hi',' dex',' bne objects_zero_page',' lda #OBJF_ALLOCATED',' sta objects__obj_flags',' lda #OBJ_PLAYER',' sta objects__obj_kind',' lda #SPR_PTR_PLAYER_0',' sta objects__obj_sprite_ptr',' ldx #0',' lda #OBJECT_LAST','objects_seed_stack sta objects__free_stack,x',' sec',' sbc #1',' inx',' cpx #OBJECT_FREE_CAPACITY',' bne objects_seed_stack',' lda #OBJECT_FREE_CAPACITY',' sta objects__free_count',' lda #1',' sta objects__mux_objects_dirty',' rts','objects__clear_slot lda #0']
    if args.group>=5:
        index=native.index('objects__init anop')
        assert native[index-1]==' rts'
        native[index-1:index]=[' jsr native_reset_initialized',' lda >core_variant',' beq native_reset_done',' jsr native_cold_init','native_reset_done rts']
    native += [f' sta objects__obj_{f},x' for f in FIELDS]
    native += [' rts','objects__slot_referenced clc',' rts','objects__drain_irq_events rts','screen_blank rts','screen_unblank rts','vic_select_bank0 rts','vic_select_bank3 rts','vic_text_mode lda #0',' sta native_present',' jmp screen_clear']
    if args.group>=2:native += ['player__install_frame_a sta native_player_frame',' rts','sfx__play rts']
    if args.group>=3:native += ['sprite_mux_build__build clc',' rts']
    if args.group>=5:
        native += [' copy src/iigs/game_services.asm','native_reset_initialized anop']
        for name in extension['initialized_mutable']:
            flat=adapter.flat(name);count=data_layout[name]['count'];paired=count&~1
            native += [' rep #$30',' longa on',' longi on',f' ldx #{paired-2}',f'native_restore_{flat} lda native_initial__{flat},x',f' sta {flat},x',' dex',' dex',f' bpl native_restore_{flat}',' sep #$30',' longa off',' longi off']
            if count&1:native += [f' lda native_initial__{flat}+{count-1}',f' sta {flat}+{count-1}']
        native += [' rts']
    state=['game_state anop','objects_state anop']+[f'objects__obj_{f} ds 24' for f in FIELDS]+['objects__free_stack ds 23','objects__free_count ds 1','objects__mux_objects_dirty ds 2',' ds 6','native_present ds 2']+(['native_player_frame ds 2'] if args.group>=2 else [])+(['native_border ds 2','objects__profile_marker ds 2'] if args.group>=5 else [])+['SCREEN_RAM ds 1024','COLOR_RAM ds 1024','native_fixture_data ds 256']+mutable+([' ds 1'] if sum(v['count'] for v in data_layout.values())%2 else [])+['game_state_end anop']
    (OUT/'core.s').write_text('\n'.join(wrapper)+'\n copy '+relative+'/translated.s\n'+'\n'.join(native+immutable+state)+'\n')
    driver_source=ROOT/'src/iigs/coretest.asm'
    if relative!='build/iigs/nativecore':
        driver_source=OUT/'coretest.asm';driver_source.write_text((ROOT/'src/iigs/coretest.asm').read_text().replace('build/iigs/nativecore/core.s',relative+'/core.s'))
    if args.group>=5:
        text=driver_source.read_text()
        text=text.replace('                          cmp #3\n', '                          cmp #2\n                          beq core_tick\n                          cmp #3\n',1)
        text=text.replace('core_reset                lda core_variant\n                          beq core_bare_reset', 'core_reset                lda core_variant\n                          beq core_bare_reset\n                          cmp #1\n                          beq core_bare_reset')
        text=text.replace('                          stz core_frame+2\ncore_invoke', '                          stz core_frame+2\n                          bra core_invoke\ncore_invoke')
        text=text.replace('core_invoke               jsl game_entry', 'core_tick                 jsl game_entry\n                          lda core_status\n                          bne core_complete\n                          inc core_frame\n                          bne core_complete\n                          inc core_frame+2\n                          bra core_complete\ncore_invoke               jsl game_entry')
        text=text.replace("core_variant              dc i2'0'", "core_variant              ENTRY\n                          dc i2'0'").replace("core_ticks                dc i2'0'", "core_ticks                ENTRY\n                          dc i2'0'")
        driver_source.write_text(text)
    run(['iix','assemble','+L','+S',str(driver_source.relative_to(ROOT)),'keep='+relative+'/main'],'main.listing')
    (OUT/'link.script').write_text('+S +L\n'+relative+'/main\n')
    run(['iix','chtyp','-l','LINKER',relative+'/link.script'],'chtyp.log')
    run(['iix','assemble',relative+'/link.script','keep='+relative+'/CORETEST'],'link.map')
    symbols={}
    for name in ['main.listing','link.map']:
        for address,label in re.findall(r'\b([0-9A-F]{6})\s+([A-Za-z_]\w*)',(OUT/name).read_text()):symbols[label]=int(address,16)
    assert symbols['game_end']-symbols['game_entry']<=32768,'GAME exceeds guaranteed bank-local half bank'
    assert symbols['core_test_end']-symbols['core_test_entry']<=32768,'CORETEST driver exceeds half bank'
    raw=(OUT/'CORETEST').read_bytes();position=0;segments=[]
    while position<len(raw):
        length=int.from_bytes(raw[position:position+4],'little')
        if length<48 or position+length>len(raw):raise RuntimeError('Invalid linked OMF bounds')
        segments.append({'bytes':int.from_bytes(raw[position+8:position+12],'little'),'alignment':int.from_bytes(raw[position+28:position+32],'little')})
        position+=length
    assert len(segments)==3 and all(s['alignment']==32768 for s in segments[1:]),'Both native code segments require half-bank alignment'
    state_map={}
    aliases={'mode':'game_mode'}
    for name,entry in adapter.dp.items():
        cname=next((c for c,a in aliases.items() if a==name),name)
        if cname in schema:state_map[cname]={'space':'dp',**entry}
    for field in FIELDS:
        cname='objects.'+field
        if cname in schema:state_map[cname]={'space':'game','offset':symbols['objects__obj_'+field]-symbols['game_entry'],'width':1,'count':24}
    for cname,label,count in [('free_stack','objects__free_stack',23),('free_count','objects__free_count',1),('cells.glyph','SCREEN_RAM',1000),('cells.color','COLOR_RAM',1000),('present','native_present',1)]:state_map[cname]={'space':'game','offset':symbols[label]-symbols['game_entry'],'width':1,'count':count}
    if args.group>=2:
        state_map['player_frame']={'space':'game','offset':symbols['native_player_frame']-symbols['game_entry'],'width':1,'count':1}
        for name,entry in data_layout.items():
            cname=name.replace('bullets::','').replace('rail_data::dmg_','rail_dmg_').replace('rail_data::heal_mark_','heal_mark_').replace('rail_data::','')
            cname={'dmg_amt':'rail_dmg_amt','hit_left':'rail_hit_left','hit_slot':'rail_hit_slot'}.get(cname,cname)
            if cname in schema:state_map[cname]={'space':'game','offset':symbols[adapter.flat(name)]-symbols['game_entry'],**entry}
        state_map['tally_shots']={'space':'dp','offset':adapter.dp['tally_shots0']['offset'],'width':2,'count':1}
        if args.group>=3:
            for kind in 'abc':state_map['tally_kill_'+kind]={'space':'dp','offset':adapter.dp['tally_kill_'+kind+'0']['offset'],'width':2,'count':1}
    if args.group>=5:
        first=symbols['hs_line_1']-symbols['game_entry']
        for i in range(1,11):assert symbols['hs_line_'+str(i)]-symbols['game_entry']==first+(i-1)*38,'High-score row layout changed'
        state_map['hs_lines']={'space':'game','offset':first,'width':1,'count':370,'parts':[{'offset':first+i*38,'count':37} for i in range(10)]}
    state_map['frame']={'space':'driver','offset':symbols['core_frame']-symbols['core_test_entry'],'width':4,'count':1}
    mailbox_names='core_mailbox core_ready core_request_seq core_completed_seq core_command core_variant core_ticks core_call_id core_arg_a core_arg_x core_arg_y core_arg_carry core_input_dirs core_input_fire core_input_key_s core_input_key_i core_input_runstop core_game_base core_game_dp core_status core_frame core_ret_a core_ret_x core_ret_y core_ret_p core_cleanup_error'.split()
    byte_names={'core_arg_a','core_arg_x','core_arg_y','core_arg_carry','core_input_dirs','core_input_fire','core_input_key_s','core_input_key_i','core_input_runstop','core_ret_a','core_ret_x','core_ret_y','core_ret_p'}
    fields={name:symbols[name]-symbols['core_test_entry'] for name in mailbox_names}
    widths={name:1 if name in byte_names else 4 if name in ('core_game_base','core_frame') else 8 if name=='core_mailbox' else 2 for name in mailbox_names}
    mapping={'version':1,'signature':'N1CORE01','driver_entry':'core_test_entry','game_entry':'game_entry','mailbox':fields,'mailbox_widths':widths,'commands':{'reset':1,'invoke':3,'quit':255},'reset_variants':{'bare':0},'unsupported':['full sim_init reset','fixed-tick mode pipeline until later module groups'],'calls':{name:i for i,name in enumerate(policy['calls'],1)},'state':state_map,'dp_bytes':used_dp,'game_bytes':symbols['game_end']-symbols['game_entry'],'selected_procedures':adapter.procedures,'raw_dp':adapter.dp,'native_symbols':{name:symbols[name]-symbols['game_entry'] for name in ['SCREEN_RAM','COLOR_RAM','native_fixture_data','game_state','game_state_end']}}
    if args.group>=5:
        mapping['commands']['tick']=2;mapping['reset_variants']['cold']=1;mapping['unsupported']=[]
        mapping['derived_fields']={'type_src_id':'decode rawDP type_src_lo/hi against native_data text bounds','type_src_offset':'same pointer minus selected source base','death_banner_col':'active-context alias of rawDP banner_col','death_banner_len':'active-context alias of rawDP banner_len'}
        mapping['native_data']={name:{'offset':symbols[adapter.flat(name)]-symbols['game_entry'],'bytes':entry['width']*entry['count']} for name,entry in all_layout.items() if name in ('story_text','instructions_text')}
    for name,entry in state_map.items():
        if {key:entry[key] for key in ('width','count')}!=schema[name]:raise RuntimeError('Native/oracle schema layout differs: '+name)
    assert (symbols['game_state_end']-symbols['game_state'])%2==0,'Native bare reset requires an even state extent'
    mapping['native_symbols']['objects::mux_objects_dirty']=symbols['objects__mux_objects_dirty']-symbols['game_entry']
    (OUT/'state-map.json').write_text(json.dumps(mapping,indent=2)+'\n')
    production=None
    if args.group>=5:
        from native_game_export import emit as emit_production
        production=emit_production(ROOT,OUT,(OUT/'core.s').read_text())
    sources=[ROOT/'src/iigs/coretest.asm',ROOT/'src/iigs/core-manifest.json',ROOT/'src/c64/sys/const.asm',ROOT/'src/c64/sys/zeropage.asm',Path(__file__),ROOT/'tools/iigs/native_core.py',schema_path]+([ROOT/'tools/iigs/native_core_data.py',ROOT/('src/iigs/core-group'+str(args.group)+'-manifest.json'),driver_source] if args.group>=2 else [])+[ROOT/p for p in dict.fromkeys(list(policy['modules'])+list(extension.get('data',{})))]+[OUT/'core.s',OUT/'translated.s',OUT/'CORETEST',OUT/'state-map.json']
    if args.group>=5:sources += [ROOT/'src/iigs/game_services.asm',ROOT/'tools/iigs/native_game_export.py',production,OUT/'game-translated.s',OUT/'game-abi.json']
    manifest={'stage':policy['stage'],'binary_sha256':hashlib.sha256((OUT/'CORETEST').read_bytes()).hexdigest(),'symbols':symbols,'state_map':'state-map.json','hashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},'runtime':'pure ORCA/M native8 gameplay; no C objects','group':args.group,'production_source':str(production.relative_to(ROOT)) if production else None,'bank_contract':'both segments ALIGN32768, each <=32768 bytes; runtime game_entry bank guard','dp_bytes':used_dp,'segments':segments,'commands':COMMANDS,'iix_sha256':hashlib.sha256(Path(shutil.which('iix')).read_bytes()).hexdigest()}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Built CORETEST:',mapping['game_bytes'],'GAME bytes;',used_dp,'private DP bytes used')
if __name__=='__main__':main()
