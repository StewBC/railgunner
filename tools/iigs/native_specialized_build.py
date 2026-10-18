#!/usr/bin/env python3
"""Build the focused specialized PLAY renderer with shipping GAME and services.
The accepted native builder remains unchanged; source edits below are exact
anchors, and all generated assembly dependencies are frozen by that builder.
"""
from pathlib import Path
import sys,json,hashlib
import native_game_build as baseline
from native_sprite_compile import generate as compile_sprites
ROOT=Path(__file__).resolve().parents[2]

def main():
    code=Path(baseline.__file__).read_text()
    code=code.replace("from native_render_assets import source_frames,generate", "from native_render_assets import source_frames,generate as original_generate\nfrom native_specialized_build import specialized_generate as generate")
    code=code.replace("else [' copy src/iigs/render_'+module+'.asm']", "else [' copy '+relative+'/specialized_scene.s'] if module=='scene' else [' copy src/iigs/render_'+module+'.asm']")
    code=code.replace("renderer+=[' copy '+relative+'/lookup.s'", "renderer += [' copy src/iigs/direct_plan.asm',' copy src/iigs/continuous_wave.asm',' copy src/iigs/specialized_sprite.asm',' copy src/iigs/specialized_lifecycle.asm',' copy src/iigs/continuous_capture.asm',' copy '+relative+'/dispatch.s',' copy '+relative+'/specialized_adapter.s']\n    renderer+=[' copy '+relative+'/lookup.s'")
    code=code.replace("copy src/iigs/profile.asm'", "copy {relative}/specialized_profile.s'")
    # Compile original-art segments as a separate object: one combined ORCA/M
    # translation unit exhausts its symbol heap before all31frames are read.
    code=code.replace("    frozen,bindings=freeze_sources(out/'main.asm',out)", "    frozen,bindings=freeze_sources(out/'main.asm',out)\n    compiled_frozen,compiled_bindings=freeze_sources(out/'compiled.s',out)\n    bindings.update(compiled_bindings)")
    code=code.replace("relative+'/main\\n'", "relative+'/main\\n'+relative+'/compiled\\n'")
    code=code.replace("commands=[['iix','assemble','+L','+S',frozen.relative_to(ROOT).as_posix(),'keep='+relative+'/main'],", "commands=[['iix','assemble','+L','+S',frozen.relative_to(ROOT).as_posix(),'keep='+relative+'/main'],['iix','assemble','+L','+S',compiled_frozen.relative_to(ROOT).as_posix(),'keep='+relative+'/compiled'],")
    code=code.replace("['main.listing','chtyp.log','link.map'][i]", "['main.listing','compiled.listing','chtyp.log','link.map'][i]")
    code=code.replace("    paths += [ROOT/value['frozen'] for value in bindings.values()]", "    paths += [ROOT/value['frozen'] for value in bindings.values()]\n    paths += [out/'compiled-manifest.json',out/'generator-sources.json']+list((out/'generator-snapshot').glob('*.py'))")
    code=code.replace("segments=segments,commands=commands", "segments=segments,compiled_segments={name:dict(link_segment=int(index,16),entry='ns_f'+name[3:],entry_offset=0) for index,name in re.findall(r'^[0-9A-F]{8} [0-9A-F]{8} ([0-9A-F]{2}) Code: (NSC[0-9]+)$',(out/'link.map').read_text(),re.M)},compiled_manifest='compiled-manifest.json',generator_sources=json.loads((out/'generator-sources.json').read_text()),commands=commands")
    code=code.replace("paths=[Path(__file__).resolve(),out/'main.asm'", "paths=[out/'main.asm'")
    # The specialized production build has no admission or calibration path.
    code=code.replace("renderer += [' copy src/iigs/raster.asm']", "renderer = [line.replace(' copy src/iigs/render_object.asm',' copy '+relative+'/specialized_object.s').replace(' copy src/iigs/render_commit.asm',' copy '+relative+'/continuous_commit.s').replace(' copy src/iigs/render_damage.asm',' copy '+relative+'/continuous_damage.s') for line in renderer]\n    renderer += [' copy src/iigs/raster.asm']")
    code=code.replace("' jsr rc_publish',' inc debug_frames'", "' jsr sw_seed_bitmap',' jsr rc_publish',' inc debug_frames'")
    # Save bank01 before its first seed, restore it after input cleanup and
    # before the accepted E1/hardware restoration (including early shutdown).
    code=baseline.replace_once(code,"                          bne ng_close_input\n                          rep    #$30", "                          bne ng_close_input\n                          jsr sw_restore_bank01\n                          rep    #$30")
    code=baseline.replace_once(code,"source+=' copy '+relative+'/parity.s\\n'", "source+=' copy '+relative+'/parity.s\\n'\n    source+=' copy src/iigs/specialized_lifecycle_storage.asm\\n'")
    code=baseline.replace_once(code,"('ro_parity_1','ROPAR1')]):", "('ro_parity_1','ROPAR1'),('swl_caller_01','NSCALLER01')]):")
    code=baseline.replace_once(code,"    (out/'renderer.s').write_text", "    source=source.replace('src/iigs/continuous_clock.asm',relative+'/specialized_clock.s')\n    source=replace_once(source,'                          lda rc_pending\\n                          bne ng_have_candidate','                          lda rc_pending\\n                          bne ng_have_candidate\\n                          jsr sw_capture_due\\n                          beq main_loop')\n    source=source.replace('                          jsl game_capture','                          jsr sw_capture_stamp\\n                          jsl game_capture')\n    (out/'renderer.s').write_text")
    code=code.replace('timeout=120','timeout=600')
    exec(compile(code,str(Path(__file__).resolve()),'exec'),dict(__name__='__main__',__file__=__file__))

def specialized_generate(out):
    # Freeze generators before generation, and reject a concurrent compiler edit.
    snapshots=out/'generator-snapshot'
    snapshots.mkdir(exist_ok=True)
    generator_sources={}
    for filename in ('native_game_build.py','native_sprite_compile.py','native_specialized_build.py'):
        original=ROOT/'tools/iigs'/filename
        raw=original.read_bytes()
        frozen=snapshots/filename
        frozen.write_bytes(raw)
        generator_sources[original.relative_to(ROOT).as_posix()]=dict(frozen=frozen.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(raw).hexdigest())
    (out/'generator-sources.json').write_text(json.dumps(generator_sources,indent=2)+'\n')
    baseline.generate(out)
    compiled_manifest=compile_sprites(out)
    assert compiled_manifest['source_sha256']==generator_sources['tools/iigs/native_sprite_compile.py']['sha256'],'Compiler changed during generation'

    (out/'compiled-manifest.json').write_text(json.dumps(compiled_manifest,indent=2)+'\n')
    object_source=(ROOT/'src/iigs/render_object.asm').read_text()
    object_source=baseline.replace_once(object_source,'ro_draw                   lda ro_attr','''ro_draw                   lda rc_candidate_mode
                          cmp #3
                          bne ro_play_clip_ok
                          lda ro_span_row
                          cmp #8
                          bcs ro_play_clip_ok
                          lda #0
                          rts
ro_play_clip_ok           lda ro_attr''')
    (out/'specialized_object.s').write_text(object_source)
    scene=(ROOT/'src/iigs/render_scene.asm').read_text().replace('rs_render                 jsr rb_prepare','sw_baseline_render        jsr rb_prepare').replace('                          jsr rco_expand\n','')
    (out/'specialized_scene.s').write_text(scene)
    wave=(ROOT/'src/iigs/continuous_controller.asm').read_text()
    wave=baseline.replace_once(wave,' lda rd_boundary,x\n cmp rd_boundary+2,x\n beq rwp_strip_next',' lda sw_enabled\n beq rwp_generic_dirty\n lda sw_cell_start,x\n cmp sw_cell_start+2,x\n bne rwp_draw_strip\n lda sw_job_start,x\n cmp sw_job_start+2,x\n beq rwp_strip_next\n bra rwp_draw_strip\nrwp_generic_dirty lda rd_boundary,x\n cmp rd_boundary+2,x\n beq rwp_strip_next\nrwp_draw_strip anop')
    (out/'specialized_controller.s').write_text(wave)
    commit=(ROOT/'src/iigs/render_commit.asm').read_text()
    commit=baseline.replace_once(commit,'rw_ordinary               lda rw_admitted\n                          cmp #1\n                          bne rw_reject','rw_ordinary               lda rw_admitted\n                          cmp #1\n                          bne rw_reject\n                          bra rw_permitted')
    commit=baseline.replace_once(commit,'rw_span_done              inc rw_index','rw_span_done              inc rw_index\n                          lda rw_index\n                          and #7\n                          bne rw_span_no_service\n                          jsr render_service\nrw_span_no_service        anop')
    (out/'continuous_commit.s').write_text(commit)
    damage=(ROOT/'src/iigs/render_damage.asm').read_text()
    damage=baseline.replace_once(damage,'rd_mark_row               jsr render_service','rd_mark_row               lda rd_row\n                          and #7\n                          bne rd_mark_no_service\n                          jsr render_service\nrd_mark_no_service        anop')
    (out/'continuous_damage.s').write_text(damage)
    (out/'specialized_clock.s').write_text((ROOT/'src/iigs/continuous_clock.asm').read_text())
    profile=(ROOT/'src/iigs/profile.asm').read_text()
    start=profile.index('ng_profile_render         ')
    stop=profile.index('ng_record_stage           ',start)
    profile=profile[:start]+"""; Focused profiling must execute the exact production renderer gateway.
; Stage0 is total preparation, remaining generic stage slots are unused.
ng_profile_render lda ng_profile_enabled
 bne sw_profile_render
 jmp rs_render
sw_profile_render jsr clock_sample
 lda clock_time
 sta ng_stage_before
 lda clock_time+2
 sta ng_stage_before+2
 jsr rs_render
 sta sw_profile_result
 ldx #0
 jsr ng_record_stage
 lda sw_profile_result
 rts
sw_profile_result ds 2
"""+profile[stop:]
    (out/'specialized_profile.s').write_text(profile)
    (out/'specialized_adapter.s').write_text('''; Focused PLAY routing; transition/frontend retain accepted baseline path.
rs_render stz sw_enabled
 lda rc_display_valid
 beq sw_baseline
 lda rc_candidate_present
 cmp #1
 beq sw_baseline
 cmp rc_displayed_present
 bne sw_baseline
 lda rc_candidate_mode
 cmp #3
 bne sw_baseline
 cmp rc_displayed_mode
 bne sw_baseline
 lda #1
 sta sw_enabled
 jmp sw_prepare
sw_baseline jmp sw_baseline_render
sw_choose_strip lda sw_enabled
 beq sw_old_strip
 jmp sw_draw_strip
sw_old_strip jmp rw_copy_strip
; Seed masked-read source after every complete initial/transition E1 image.
sw_seed_bitmap jsr sw_save_bank01
 ldx #0
sw_seed_word lda >$e12000,x
 sta >$012000,x
 inx
 inx
 cpx #32000
 bcc sw_seed_word
 rts
sw_enabled ds 2
sw_commits ds 2
''')

if __name__=='__main__':main()
