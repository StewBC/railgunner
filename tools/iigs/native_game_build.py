#!/usr/bin/env python3
"""Base template for native_specialized_build.py and its native production GAME.
Use make iigs-game; this module is not an alternative renderer entry point.
No C objects/runtime are compiled or linked. Caller supplies GS/OS media at launch.
"""
from pathlib import Path
import argparse,hashlib,json,re,subprocess
from native_render_assets import source_frames,generate
from native_render_glyph_test import data
from asm_transform import replace_once as asm_replace_once, replace_all, label_offset
ROOT=Path(__file__).resolve().parents[2]
PROFILES={'2.8mhz':0,'7.159mhz':1,'14.3mhz':2}
def replace_once(text,old,new):
    if text.count(old)!=1:raise RuntimeError('Lifecycle anchor changed: '+repr(old[:80]))
    return text.replace(old,new,1)
def freeze_sources(root,out):
    """Assemble immutable inputs even while separate component work continues."""
    bindings={};visiting=set()
    def visit(path):
        path=path.resolve()
        if path in bindings:return out/'source-snapshot'/path.relative_to(ROOT)
        if path in visiting:raise RuntimeError('Cyclic assembly COPY: '+str(path))
        if not path.is_relative_to(ROOT):raise ValueError('Assembly COPY outside repo: '+str(path))
        visiting.add(path);raw=path.read_bytes();text=raw.decode()
        def dependency(match):
            nested=visit(ROOT/match.group(1))
            return ' copy '+nested.relative_to(ROOT).as_posix()
        text=re.sub(r'^\s*copy\s+(\S+)\s*$',dependency,text,flags=re.M|re.I)
        target=out/'source-snapshot'/path.relative_to(ROOT)
        target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text)
        bindings[path]=dict(source_sha256=hashlib.sha256(raw).hexdigest(),frozen=target.relative_to(ROOT).as_posix(),frozen_sha256=hashlib.sha256(target.read_bytes()).hexdigest())
        visiting.remove(path);return target
    frozen=visit(root)
    return frozen,{str(path.relative_to(ROOT)):value for path,value in bindings.items()}
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game-source',type=Path,required=True)
    p.add_argument('--game-manifest',type=Path,required=True)
    p.add_argument('--speed',choices=PROFILES,default='2.8mhz')
    p.add_argument('--out',type=Path,default=Path('build/iigs/native-game'))
    p.add_argument('--held-fire',action='store_true',help='Hold fire continuously in deterministic input fixture')
    p.add_argument('--fixture-input',action='store_true',help='Deterministic held inputs for performance diagnostics only')
    p.add_argument('--profile',action='store_true',help='Record conservative foreground game/render stage costs')
    p.add_argument('--prepare-only',action='store_true')
    a=p.parse_args();out=(ROOT/a.out).resolve();game_source=(ROOT/a.game_source).resolve();game_manifest=(ROOT/a.game_manifest).resolve()
    if not out.is_relative_to(ROOT/'build'):raise ValueError('Output must remain under project build/')
    if not game_source.is_relative_to(ROOT/'build'):raise ValueError('Generated GAME source must remain under project build/')
    provenance_raw=game_manifest.read_bytes();provenance=json.loads(provenance_raw)
    game_relative=game_source.relative_to(ROOT).as_posix()
    if provenance.get('production_source')!=game_relative:raise RuntimeError('Manifest names another production GAME source')
    if provenance['hashes'].get(game_relative)!=hashlib.sha256(game_source.read_bytes()).hexdigest():raise RuntimeError('Production GAME source does not match its manifest')
    # Source binding is checked again at the production GAME generator boundary.
    out.mkdir(parents=True,exist_ok=True);relative=out.relative_to(ROOT).as_posix();generate(out)
    frames,_,_=source_frames()
    source=(ROOT/'src/iigs/main.asm').read_text()
    source=asm_replace_once(source,'                          pea    256','                          pea    512')
    source=asm_replace_once(source,'                          lda    debug_dp\n                          tcd','                          lda debug_dp\n                          beq ng_bad_dp\n                          and #$ff\n                          bne ng_bad_dp\n                          lda debug_dp\n                          cmp #$FE01\n                          bcc ng_allocated_dp_ok\nng_bad_dp                 jmp shutdown\nng_allocated_dp_ok        lda debug_dp\n                          tcd')
    source=asm_replace_once(source,'                          ldx    #254\n                          lda    #0\nclear_dp','                          ldx    #510\n                          lda    #0\nclear_dp')
    source=asm_replace_once(source,'; GAME_RENDERER_INSERT',f'                          copy   {relative}/renderer.s\n                          copy src/iigs/input.asm\n                          copy {relative}/platform.s\n                          copy src/iigs/profile.asm')
    platform=(ROOT/'src/iigs/platform.asm').read_text()
    platform=asm_replace_once(platform,'                          jsl game_tick','                          jsr ng_fixture_input\n                          jsr ng_timed_game_tick')
    platform+='\nng_profile_enabled dc i2\''+str(int(a.profile))+"'\n"
    platform+='\nng_fixture_enabled dc i2\''+str(int(a.fixture_input))+"'\n"
    platform+='\nng_fixture_fire_hold dc i2\''+str(int(a.held_fire))+"'\n"
    (out/'platform.s').write_text(platform)
    source=asm_replace_once(source,'clock_test_good           jsr    slice_init\n                          jsr    clock_init', '''clock_test_good           lda debug_dp
                          cmp #$FE01
                          bcc ng_dp_valid
                          jmp shutdown
ng_dp_valid               clc
                          adc #256
                          sta >game_dp
                          sta debug_game_dp
                          lda #game_prod_base
                          sta debug_game_base
                          lda #^GAME
                          and #$ff
                          sta debug_game_base+2
                          jsl game_start
                          lda >game_status
                          beq ng_game_started
                          jmp shutdown
ng_game_started           jsr ng_validate
                          beq ng_placement_ok
                          jmp shutdown
ng_placement_ok           jsr rc_reset
                          jsl game_capture
                          jsr rc_capture
                          jsr rs_render
                          beq ng_initial_composed
                          jmp shutdown
ng_initial_composed       jsr ng_blank_copy
                          beq ng_initial_copied
                          jmp shutdown
ng_initial_copied         jsr input_init
                          beq ng_input_ready
                          jmp shutdown
ng_input_ready            jsr input_poll
                          jsr clock_init''')
    source=asm_replace_once(source,'clock_ready               anop','''clock_ready               lda #1
                          sta render_service_enabled''')
    source=asm_replace_once(source,'                          lda    #1\n                          sta    debug_ready',f'''                          jsr rwp_init
                          beq ng_budget_ok
                          jmp shutdown
ng_budget_ok              lda #1
                          sta debug_ready''')
    start=label_offset(source,'main_loop');end=label_offset(source,'shutdown')
    source=source[:start]+'''main_loop                 jsl platform_service
                          lda platform_quit
                          ora platform_fault
                          bne ng_exit
                          lda rc_pending
                          bne ng_have_candidate
                          jsl game_capture
                          lda >game_status
                          bne ng_exit
                          jsr render_service
                          jsr rc_capture
                          bne main_loop
                          jsr rs_render
                          bne ng_render_fault
ng_have_candidate         lda rb_full
                          beq ng_ordinary
                          jsr ng_blank_copy
                          bne ng_render_fault
                          bra main_loop
ng_ordinary               jsr rwp_present
                          cmp #2
                          beq ng_render_fault
                          bra main_loop
ng_render_fault           lda #4
                          sta platform_fault
ng_exit                   jmp shutdown
''' +source[end:]
    source=asm_replace_once(source,'shutdown                  anop\n                          rep    #$30','''shutdown                  anop
                          rep #$30
                          longa on
                          longi on
                          stz render_service_enabled
ng_close_input            jsr input_close
                          cmp #0
                          bne ng_close_input
                          rep    #$30''')
    source=asm_replace_once(source,'debug_ready               ds     2','debug_game_base           ds 4\ndebug_game_dp             ds 2\ndebug_ready               ds     2')
    # Dedicated game DP is the second page of the one owned allocation.
    source+='\n copy src/iigs/render_storage.asm\n ALIGN 32768\nRENDERART START RENDERART\n'
    for label,path,size in [('rg_charset','charset/railgunner_charset.bin',2048),('rg_title_bits','screens/title_hires.bin',8000),('rg_title_colors','screens/title_hires_col.bin',1000)]:
        blob=(ROOT/'assets/c64'/path).read_bytes();assert len(blob)==size
        source+='\n'.join(data(label,blob))+'\n'
    source+='\n'.join(data('ro_assets',b''.join(raw for _,raw in frames)))+'\n END\n'
    source+=' copy '+relative+'/parity.s\n'
    source+=' ALIGN 32768\nGAME START GAME\n copy '+game_source.relative_to(ROOT).as_posix()+'\n copy src/iigs/observe.asm\n END\n'
    renderer=[]
    for module in ['snapshot','damage','restore','glyph','background','object','mask','lookup','scene','commit','wave','service']:
        renderer += [' copy '+relative+'/specialized_controller.s'] if module=='wave' else [' copy src/iigs/render_'+module+'.asm']
    # Hiding SHR exposes legacy text: make both text colours black until SHR returns.
    # Preserve the caller's colour byte, including on the error path.
    renderer+=[' copy '+relative+'/lookup.s','ng_blank_copy sep #$20',' longa off',' lda >$e0c022',' sta ng_blank_text_color',' lda #0',' sta >$e0c022',' lda #$61',' sta >$e0c029',' rep #$20',' longa on',' lda #2',' sta rw_mode',' stz rw_strip',' stz rw_words',' stz rw_spans','ng_blank_strip jsr rw_copy_strip',' cmp #0',' bne ng_blank_bad',' jsr render_service',' inc rw_strip',' lda rw_strip',' cmp #25',' bcc ng_blank_strip',' jsr rc_publish',' inc debug_frames',' sep #$20',' longa off',' lda #$e1',' sta >$e0c029',' lda ng_blank_text_color',' sta >$e0c022',' rep #$20',' longa on',' lda #0',' rts','ng_blank_bad sep #$20',' longa off',' lda ng_blank_text_color',' sta >$e0c022',' rep #$20',' longa on',' lda #1',' rts','ng_blank_text_color ds 1']
    renderer += [' copy src/iigs/raster.asm']
    renderer += ['ng_validate anop']
    for i,(label,segment) in enumerate([('rd_spans_a','RDSPANA'),('rd_spans_b','RDSPANB'),('rr_background','RDBACK'),('rr_candidate','RDCAND'),('rg_charset','RENDERART'),('game_prod_base','GAME'),('ro_parity_0','ROPAR0'),('ro_parity_1','ROPAR1')]):
        renderer += [f' lda #{label}',' and #$7fff',f' beq ng_align_{i}',' jmp ng_bad',f'ng_align_{i} lda #^{segment}',' and #$ff',' cmp #2',f' bcs ng_bank_low_{i}',' jmp ng_bad',f'ng_bank_low_{i} cmp #$80',f' bcc ng_bank_ok_{i}',' jmp ng_bad',f'ng_bank_ok_{i} anop']
    renderer+=[' lda #0',' rts','ng_bad lda #1',' rts','debug_misses ds 2','beam_sample ds 2']
    source=replace_all(source,'                          jsr rs_render','                          jsr ng_profile_render',expected=2)
    (out/'renderer.s').write_text('\n'.join(renderer)+'\n');(out/'main.asm').write_text(source)
    if a.prepare_only:print('Prepared '+str(out/'main.asm'));return
    (out/'link.script').write_text('+S +L\n'+relative+'/main\n')
    frozen,bindings=freeze_sources(out/'main.asm',out)
    for path,binding in bindings.items():
        if path in provenance['hashes'] and provenance['hashes'][path]!=binding['source_sha256']:raise RuntimeError('Production dependency changed after its semantic build: '+path)
    (out/'game-provenance.json').write_bytes(provenance_raw)
    commands=[['iix','assemble','+L','+S',frozen.relative_to(ROOT).as_posix(),'keep='+relative+'/main'],['iix','chtyp','-l','LINKER',relative+'/link.script'],['iix','assemble',relative+'/link.script','keep='+relative+'/RAILGUNNER']]
    for i,cmd in enumerate(commands):
        result=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
        (out/['main.listing','chtyp.log','link.map'][i]).write_text(result.stdout)
        if result.returncode:raise RuntimeError(result.stdout[-8000:])
    listing=(out/'main.listing').read_text()
    native_listing,game_listing=listing.split('GAME START GAME',1)
    def parse_symbols(text):
        return {label:int(address,16) for address,label in re.findall(r'\b([0-9A-F]{6})\s+([A-Za-z_]\w*)',text)}
    symbols=parse_symbols(native_listing)
    game_symbols=parse_symbols(game_listing)
    for label,address in parse_symbols((out/'link.map').read_text()).items():symbols.setdefault(label,address)
    assert symbols['native_end']<=32768,'Platform code/data exceeds bank-local halfbank'
    semantic_map_path=game_manifest.parent/provenance['state_map']
    semantic_map_raw=semantic_map_path.read_bytes()
    if provenance['hashes'].get(semantic_map_path.relative_to(ROOT).as_posix())!=hashlib.sha256(semantic_map_raw).hexdigest():raise RuntimeError('Native semantic state map changed')
    semantic_map=json.loads(semantic_map_raw)
    old_state=semantic_map['native_symbols']['game_state'];old_end=semantic_map['native_symbols']['game_state_end']
    delta=game_symbols['game_state']-old_state
    assert game_symbols['game_state_end']-game_symbols['game_state']==old_end-old_state
    state_map=json.loads(json.dumps(semantic_map['state']))
    for spec in state_map.values():
        if spec['space']=='game':
            assert old_state<=spec['offset']<old_end
            spec['offset']+=delta
            for part in spec.get('parts',[]):part['offset']+=delta
        elif spec['space']=='driver':
            spec.update(space='game',offset=game_symbols['game_frame'])
    (out/'state-map.json').write_text(json.dumps(dict(state=state_map,raw_dp=semantic_map['raw_dp'],game_state=game_symbols['game_state'],game_state_end=game_symbols['game_state_end']),indent=2)+'\n')
    raw=(out/'RAILGUNNER').read_bytes();pos=0;segments=[]
    while pos<len(raw):
        length=int.from_bytes(raw[pos:pos+4],'little');assert length>=48 and pos+length<=len(raw)
        segments.append(dict(bytes=int.from_bytes(raw[pos+8:pos+12],'little'),alignment=int.from_bytes(raw[pos+28:pos+32],'little')));pos+=length
    assert all(segment['bytes']<=32768 for segment in segments),'Application segment including appended observer exceeds halfbank'
    paths=[Path(__file__).resolve(),out/'main.asm',out/'renderer.s',out/'lookup.s',out/'parity.s',out/'game-provenance.json',out/'state-map.json']+list((ROOT/'assets/c64/sprites').glob('*.bin'))+[ROOT/'assets/c64/charset/railgunner_charset.bin',ROOT/'assets/c64/screens/title_hires.bin',ROOT/'assets/c64/screens/title_hires_col.bin']
    paths += [ROOT/value['frozen'] for value in bindings.values()]
    (out/'manifest.json').write_text(json.dumps(dict(stage='N2 silent native game integration; acceptance pending',runtime='pure ORCA/M; no C objects or runtime',speed=a.speed,profile=a.profile,fixture_input=a.fixture_input,held_fire=a.held_fire,game_provenance=provenance,source_bindings=bindings,symbols=symbols,game_symbols=game_symbols,state_map=state_map,raw_dp=semantic_map['raw_dp'],segments=segments,commands=commands,binary_sha256=hashlib.sha256(raw).hexdigest(),hashes={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}),indent=2)+'\n')
    print('Built '+str(out/'RAILGUNNER'))
if __name__=='__main__':main()
