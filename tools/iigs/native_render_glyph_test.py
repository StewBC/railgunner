#!/usr/bin/env python3
"""Execute native glyph/title expansion against independently packed host pixels."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/native-renderer/glyph'
def data(label,blob):
    return [label+' ENTRY']+[" dc h'"+blob[i:i+32].hex()+"'" for i in range(0,len(blob),32)]
def compare_cells(tag,expected_label):
    lines=[' stz rg_cell',tag+'_cell jsr rg_expand',' cmp #0',f' beq {tag}_valid',' jmp gt_fail',tag+'_valid lda rg_offset',' sec',' sbc #1280',' sta gt_scan',' lda rg_cell']
    lines+=[' asl a']*5+[' sta gt_expect',' stz gt_scan_row',tag+'_row anop']
    for word in range(2):
        lines+=[' ldx gt_scan',' lda >rr_background,x',' sta gt_value',' ldx gt_expect',f' lda >{expected_label},x',' cmp gt_value',f' beq {tag}_word_{word}',' jmp gt_fail',f'{tag}_word_{word} inc gt_scan',' inc gt_scan',' inc gt_expect',' inc gt_expect']
    lines+=[' lda gt_scan',' clc',' adc #156',' sta gt_scan',' inc gt_scan_row',' lda gt_scan_row',' cmp #8',f' bcs {tag}_row_done',f' jmp {tag}_row',tag+'_row_done inc rg_cell',' lda rg_cell',' cmp #256',f' bcs {tag}_done',f' jmp {tag}_cell',tag+'_done anop']
    return lines


def packed(bits,fg,bg):
    pixels=[fg if bits&(128>>x) else bg for x in range(8)]
    return bytes(pixels[x]*16+pixels[x+1] for x in range(0,8,2))


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    charset=(ROOT/'assets/c64/charset/railgunner_charset.bin').read_bytes()
    title=(ROOT/'assets/c64/screens/title_hires.bin').read_bytes()
    colors=(ROOT/'assets/c64/screens/title_hires_col.bin').read_bytes()
    expected=[]
    for mode in (0,1):
        image=bytearray(32000)
        for cell in range(1000):
            glyph=cell*17&255; fg=colors[cell]>>4 if mode else cell&15; bg=colors[cell]&15 if mode else 0
            bits=title[cell*8:cell*8+8] if mode else charset[glyph*8:glyph*8+8]
            for row,b in enumerate(bits):
                pixels=[fg if b&(128>>x) else bg for x in range(8)]
                at=cell//40*1280+cell%40*4+row*160
                image[at:at+4]=bytes(pixels[x]*16+pixels[x+1] for x in range(0,8,2))
        expected.append(image)
    lines=[' case on',' ALIGN 32768','glyph_test START GLYPHTEST',' longa on',' longi on',' phb',' phk',' plb',' jsr gt_test',' plb',' rtl',' copy src/iigs/render_snapshot.asm',' copy src/iigs/render_glyph.asm',' copy src/iigs/render_damage.asm',' copy src/iigs/render_background.asm','gt_test ldx #0','gt_seed txa',' sta gt_temp',' asl a',' asl a',' asl a',' asl a',' clc',' adc gt_temp',' sep #$20',' longa off',' sta >rc_candidate_glyphs,x',' rep #$20',' longa on',' txa',' and #15',' sep #$20',' longa off',' sta >rc_candidate_colors,x',' rep #$20',' longa on',' inx',' cpx #1000',' bcc gt_seed']
    for mode in (0,1):
        lines += [f' lda #{mode}',' sta rc_candidate_present',' stz rg_cell',f'gt_cells_{mode} jsr rg_expand',' cmp #0',f' beq gt_cell_ok_{mode}',' jmp gt_fail',f'gt_cell_ok_{mode} inc rg_cell',' lda rg_cell',' cmp #1000',f' bcc gt_cells_{mode}',' ldx #0',f'gt_compare_{mode} lda >rr_background,x',f' cmp >gt_expected_{mode},x',f' beq gt_compare_ok_{mode}',' jmp gt_fail',f'gt_compare_ok_{mode} inx',' inx',' cpx #32000',f' bcc gt_compare_{mode}']
    # All256 original glyphs at every foreground color; synthetic title rows
    # expose all16 nibble masks at every foreground/background color pair.
    exhaustive=[]
    for color in range(16):
        tag=f'gt_all_{color}'
        lines+=[' stz rc_candidate_present',' ldx #0',tag+'_seed txa',' sep #$20',' longa off',' sta >rc_candidate_glyphs,x',f' lda #{color}',' sta >rc_candidate_colors,x',' rep #$20',' longa on',' inx',' cpx #256',f' bcc {tag}_seed']
        lines+=compare_cells(tag,tag+'_expected')
        exhaustive.append((tag+'_expected',b''.join(packed(b,color,0) for glyph in range(256) for b in charset[glyph*8:glyph*8+8])))
    pattern=bytes(range(1,256,34)) #01,23,45,67,89,AB,CD,EF =>all16 nibbles
    assert len(pattern)==8
    lines+=[' lda #1',' sta rc_candidate_present',' ldx #0','gt_title_seed txa',' sep #$20',' longa off',' sta >rg_title_colors,x',' rep #$20',' longa on',' inx',' cpx #256',' bcc gt_title_seed',' ldx #0','gt_title_bits anop']
    for at in range(0,8,2):lines+=[f' lda #{int.from_bytes(pattern[at:at+2],"little")}',f' sta >rg_title_bits+{at},x']
    lines+=[' txa',' clc',' adc #8',' tax',' cpx #2048',' bcc gt_title_bits']
    lines+=compare_cells('gt_title_all','gt_title_all_expected')
    exhaustive.append(('gt_title_all_expected',b''.join(packed(b,color>>4,color&15) for color in range(256) for b in pattern)))
    # Native changed-cell orchestration: title -> text invalidation, unchanged
    # generation empty, one glyph/color cell changes exactly16 aligned words.
    lines += [' stz rc_display_valid',' lda #1',' sta rc_pending',' stz rc_candidate_present',' jsr rb_prepare',' cmp #0',' beq gt_background_ok',' jmp gt_fail','gt_background_ok lda rb_changed',' cmp #1000',' beq gt_background_full',' jmp gt_fail','gt_background_full jsr rd_emit',' lda rd_words',' cmp #16000',' beq gt_background_words',' jmp gt_fail','gt_background_words jsr rc_publish',' lda #1',' sta rc_pending',' jsr rb_prepare',' lda rb_changed',' beq gt_background_unchanged',' jmp gt_fail','gt_background_unchanged jsr rd_emit',' lda rd_words',' beq gt_background_empty',' jmp gt_fail','gt_background_empty sep #$20',' longa off',' lda rc_candidate_colors+999',' eor #1',' sta rc_candidate_colors+999',' rep #$20',' longa on',' jsr rb_prepare',' lda rb_changed',' cmp #1',' beq gt_background_one',' jmp gt_fail','gt_background_one jsr rd_emit',' lda rd_words',' cmp #16',' beq gt_background_one_words',' jmp gt_fail','gt_background_one_words lda rd_count',' cmp #8',' beq gt_background_one_spans',' jmp gt_fail','gt_background_one_spans anop']
    lines += [' lda #1000',' sta rg_cell',' jsr rg_expand',' cmp #1',' beq gt_invalid_ok',' jmp gt_fail','gt_invalid_ok lda #0',' rts','gt_fail lda #1',' rts','gt_temp ds 2','gt_scan ds 2','gt_expect ds 2','gt_scan_row ds 2','gt_value ds 2','glyph_test_end anop',' END',' ALIGN 32768','GLYPHBACK START GLYPHBACK','rr_background ENTRY',' ds 32000',' END',' ALIGN 32768','GLYPHART START GLYPHART']
    for label,blob in [('rg_charset',charset),('rg_title_bits',title),('rg_title_colors',colors)]:lines+=data(label,blob)
    lines += [' END']
    for mode,image in enumerate(expected):lines+=[' ALIGN 32768',f'GLYPHEXP{mode} START GLYPHEXP{mode}']+data(f'gt_expected_{mode}',image)+[' END']
    for number,(label,blob) in enumerate(exhaustive):lines+=[' ALIGN 32768',f'GLYPHALL{number} START GLYPHALL{number}']+data(label,blob)+[' END']
    lines += [' ALIGN 32768','RDSPANA START RDSPANA','rd_spans_a ENTRY',' ds 24000',' END',' ALIGN 32768','RDSPANB START RDSPANB','rd_spans_b ENTRY',' ds 24000',' END']
    at=lines.index(' END');lines[at:at]=[' copy src/iigs/render_service.asm','renderer_platform_service rtl']
    (OUT/'test.s').write_text('\n'.join(lines)+'\n')
    (OUT/'reporter.c').write_text('#include <stdio.h>\nextern unsigned glyph_test(void);\nint main(void) { unsigned r=glyph_test(); printf("native glyph/title selftest: %u\\n",r); return r; }\n')
    commands=[['iix','assemble','+L','+S',str((OUT/'test.s').relative_to(ROOT)),'keep='+str(OUT/'test')],['iix','compile',str(OUT/'reporter.c'),'keep='+str(OUT/'reporter')],['iix','link',str(OUT/'reporter'),str(OUT/'test'),'keep='+str(OUT/'glyph-test')],['iix',str(OUT/'glyph-test')]]
    for i,cmd in enumerate(commands):
        p=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
        (OUT/f'step-{i}.log').write_text(p.stdout)
        if p.returncode:raise RuntimeError(p.stdout[-5000:])
    if p.stdout.strip()!='native glyph/title selftest: 0':raise RuntimeError(p.stdout)
    paths=[ROOT/'src/iigs/render_glyph.asm',ROOT/'src/iigs/render_snapshot.asm',ROOT/'src/iigs/render_damage.asm',ROOT/'src/iigs/render_background.asm',Path(__file__).resolve(),OUT/'test.s',OUT/'glyph-test']
    (OUT/'manifest.json').write_text(json.dumps(dict(scope='Native background cell expansion only; no sprite/composition/E1/performance claim',commands=commands,compared_frame_bytes=64000,exhaustive_glyph_colors=4096,title_color_pairs=256,exhaustive_compared_bytes=sum(len(blob) for label,blob in exhaustive),lookup_bytes=32,hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}),indent=2)+'\n')
    print(p.stdout.strip())
if __name__=='__main__':main()
