"""Emit the shipping GAME segment body with explicit native16 entry points.

This removes CORETEST dispatch. Original adapted gameplay/services remain the
same generated body. Platform owns game_dp allocation and held input delivery.
"""
from pathlib import Path
import json


def emit(root, out, core_source):
    relative = out.relative_to(root).as_posix()
    marker = ' copy '+relative+'/translated.s\n'
    body = core_source[core_source.index(marker):]
    translated=(out/'translated.s').read_text()
    boundary=translated.index('; src/')
    constants=translated[:boundary]
    (out/'game-translated.s').write_text(translated[boundary:])
    body=body.replace(marker,' copy '+relative+'/game-translated.s\n',1)
    lines = ['; Generated shipping GAME body. Native16 JSL API, native E=0.',
             '; All API calls preserve A/X/Y/P/D/DBR/SP; result is game_status.',
             '; game_dp is an owned, nonzero, page-aligned bank-zero page.',
             ' longa on',' longi on','game_prod_base ENTRY']
    for name in ('game_start','game_tick','game_capture'):
        lines += [name+' ENTRY',' longa on',' longi on',' php',' phb',' phd',
                  ' pha',' phx',' phy',' rep #$30',' phk',' plb',' cld',
                  ' jsr game_validate',' bcc '+name+'_valid',' jmp game_restore',
                  name+'_valid anop']
        if name == 'game_start':
            lines += [' ldx #254',' lda #0','game_zero_dp sta 0,x',' dex',' dex',
                      ' bpl game_zero_dp',' stz game_frame',' stz game_frame+2',
                      ' sep #$30',' longa off',' longi off',' jsr core_bare',
                      ' rep #$30',' longa on',' longi on',' lda #1',' sta game_started']
        else:
            lines += [' lda game_started',' bne '+name+'_started',
                      ' lda #$FFFC',' sta game_status',' jmp game_restore',
                      name+'_started anop']
            if name == 'game_tick':
                lines += [' sep #$30',' longa off',' longi off',
                          ' jsr native_fixed_tick',' rep #$30',' longa on',' longi on',
                          ' inc game_frame',' bne game_tick_counted',' inc game_frame+2',
                          'game_tick_counted anop']
            else:
                lines += [' jsr game_capture_worker']
        lines += [' jmp game_restore']
    lines += ['game_restore rep #$30',' longa on',' longi on',' ply',' plx',
              ' pla',' pld',' plb',' plp',' rtl',
              'game_validate lda #game_prod_base',
              ' cmp #65536-(game_prod_end-game_prod_base)',' bcc game_bank_valid',
              ' beq game_bank_valid',' lda #$FFFE',' sta game_status',' sec',' rts',
              'game_bank_valid lda game_dp',' beq game_bad_dp',' and #255',
              ' bne game_bad_dp',' lda game_dp',' tcd',' stz game_status',' clc',' rts',
              'game_bad_dp lda #$FFFD',' sta game_status',' sec',' rts',
              'game_capture_worker ldx #998',
              'game_capture_cells lda SCREEN_RAM,x',' sta >rc_live_glyphs,x',
              ' lda COLOR_RAM,x',' sta >rc_live_colors,x',' dex',' dex',
              ' bpl game_capture_cells',' ldx #0',' ldy #0',
              'game_capture_object lda objects__obj_x_lo,y',' and #255',
              ' sta game_capture_x',' lda objects__obj_x_hi,y',' and #255',
              ' xba',' ora game_capture_x',' sta >rc_live_objects,x',
              ' lda objects__obj_y_int,y',' and #255',' sta >rc_live_objects+2,x',
              ' lda objects__obj_sprite_ptr,y',' and #255',' sta >rc_live_objects+4,x',
              ' cmp #$F8',' bcc game_capture_nonplayer',' cmp #$FA',
              ' bcs game_capture_nonplayer',' lda native_player_frame',' and #3',
              ' bra game_capture_frame','game_capture_nonplayer lda #0',
              'game_capture_frame sta >rc_live_objects+6,x']
    for field,offset in [('sprite_color',8),('sprite_attr',10),('kind',12),('flags',14)]:
        lines += [' lda objects__obj_'+field+',y',' and #255',
                  ' sta >rc_live_objects+'+str(offset)+',x']
    lines += [' txa',' clc',' adc #16',' tax',' iny',' cpy #24',
              ' bcs game_capture_objects_done',' jmp game_capture_object',
              'game_capture_objects_done lda native_present',' and #255',
              ' sta >rc_live_present',' lda game_mode',' and #255',
              ' sta >rc_live_mode',' rts',
              'game_dp ENTRY',' dc i2\'0\'','game_frame ENTRY',' ds 4',
              'game_status ENTRY',' ds 2','game_started ds 2',
              'game_capture_x ds 2','game_start_variant dc i2\'1\'']
    for name in ('dirs','fire','key_s','key_i','runstop'):
        lines += ['game_input_'+name+' ENTRY',' dc i1\'0\'',
                  'core_input_'+name+' equ game_input_'+name]
    lines += ['core_variant equ game_start_variant',' sep #$30',
              ' longa off',' longi off']
    text=constants+'\n'+'\n'.join(lines)+'\n'+body+'\ngame_prod_end anop\n'
    path=out/'game-production.s'
    path.write_text(text)
    abi={'source':str(path.relative_to(root)), 'segment':'GAME',
         'entry_points':['game_start','game_tick','game_capture'],
         'call':'native E=0, M=X=16, JSL; preserve A/X/Y/P/D/DBR/SP',
         'status':{'symbol':'game_status','width':2,'values':{'0':'success','FFFC':'not started','FFFD':'invalid DP','FFFE':'bank crossing'}},
         'owned_dp':{'symbol':'game_dp','width':2,'contract':'nonzero page-aligned bank-zero address; platform owns allocation'},
         'input':{n:1 for n in ('game_input_dirs','game_input_fire','game_input_key_s','game_input_key_i','game_input_runstop')},
         'frame':{'symbol':'game_frame','width':4,'contract':'reset at game_start, increments exactly once per game_tick'},
         'capture':'rc_live_glyphs/colors1000 bytes;24 slot-ordered16-byte descriptors; mode/present16',
         'capture_frame':'global logical player frame&3 for ptr F8/F9 only; zero otherwise',
         'lifecycle':'game_start cold launch only; normal new game/restart uses original mode pipeline'}
    (out/'game-abi.json').write_text(json.dumps(abi,indent=2)+'\n')
    return path
