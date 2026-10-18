#!/usr/bin/env python3
"""Native clipped sprite baseline pixel oracle; no presentation/timing claim."""
from pathlib import Path
import hashlib,json,subprocess
from native_render_glyph_test import data
from native_render_assets import source_frames,generate
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/native-renderer/object'
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    paths=sorted((ROOT/'assets/c64/sprites').glob('*.bin'))
    frames,lookup,players=source_frames()
    generate(OUT)
    assets=b''.join(raw for _,raw in frames)
    image=bytearray([0x55]*32000)
    # Every source frame; both attributes, dynamic16colors, arbitrary Y/parity,
    # left/right/top/bottom clipping, overlapping priority-order spans.
    objects=[]
    for i in range(31):
        objects.append((i,(i%10)*32+(i&1)-5,(i//10)*55-7,i&15,i&1))
        objects.append((i,(i%10)*32+9-(i&1),150+(i//10)*17,(15-i)&15,1-(i&1)))
    # Only selected separate spans are recomposed. Native clipping must preserve
    # clean gaps rather than drawing whole sprites beyond their intersected spans.
    spans=[(y,x,width) for y in range(200) for x,width in [(0,14),(36,22),(92,26),(146,14)]]
    for frame,sx,sy,color,attr in objects:
        sprite=assets[frame*64:(frame+1)*64]
        for row,byte,width in spans:
            for x in range(byte*2,(byte+width)*2):
                ox=x-sx;oy=row-sy
                if not(0<=ox<24 and 0<=oy<21):continue
                b=sprite[oy*3+ox//8]
                role=(b>>(6-(ox&6)))&3 if attr else (b>>(7-(ox&7)))&1
                if not role:continue
                c=(0,11,color,7)[role] if attr else color
                at=row*160+x//2
                image[at]=(image[at]&240)|c if x&1 else (image[at]&15)|(c<<4)
    lines=[' case on',' ALIGN 32768','object_test START OBJECTTEST',' longa on',' longi on',' phb',' phk',' plb',' jsr ot_test',' plb',' rtl',' copy src/iigs/render_object.asm',' copy src/iigs/render_mask.asm',' copy src/iigs/render_lookup.asm',' copy build/iigs/native-renderer/object/lookup.s','ot_test ldx #31998',' lda #$5555','ot_seed sta >rr_candidate,x',' dex',' dex',' bpl ot_seed']
    for i,(frame,x,y,color,attr) in enumerate(objects):
        for name,value in [('frame',frame),('x',x&65535),('y',y&65535),('color',color),('attr',attr)]:lines += [f' lda #{value}',f' sta ro_{name}']
        lines += [' stz ro_span_row',f'ot_row_{i} anop']
        for col,width in [(0,14),(36,22),(92,26),(146,14)]:
            lines += [' lda ro_span_row',' asl a',' asl a',' asl a',' asl a',' asl a',' sta ot_temp',' asl a',' asl a',' clc',' adc ot_temp',f' adc #{col}',' sta ro_span_offset',f' lda #{width}',' sta ro_span_length',' jsr ro_draw',' cmp #0',f' beq ot_ok_{i}_{col}',' jmp ot_fail',f'ot_ok_{i}_{col} anop']
        lines += [' inc ro_span_row',' lda ro_span_row',' cmp #200',f' bcs ot_rows_done_{i}',f' jmp ot_row_{i}',f'ot_rows_done_{i} anop']
    lines += [' ldx #0','ot_compare lda >rr_candidate,x',' cmp >ot_expected,x',' beq ot_match',' jmp ot_fail','ot_match inx',' inx',' cpx #32000',' bcc ot_compare',' lda #0',' rts','ot_fail lda #1',' rts','ot_temp ds 2','object_test_end anop',' END',' ALIGN 32768','OBJECTCAND START OBJECTCAND','rr_candidate ENTRY',' ds 32000',' END',' ALIGN 32768','OBJECTART START OBJECTART']+data('ro_assets',assets)+[' END',' ALIGN 32768','OBJECTEXP START OBJECTEXP']+data('ot_expected',image)+[' END']
    at=lines.index(' lda #0',lines.index('ot_match inx'))
    lookup_test=[]
    for pointer,index in enumerate(lookup):
        if pointer in (248,249):continue
        lookup_test += [f' lda #{pointer}',' jsr ro_lookup',f' cmp #{index}',f' beq ot_lookup_{pointer}',' jmp ot_fail',f'ot_lookup_{pointer} anop']
    for frame,index in enumerate(players):
        for pointer in (248,249):
            lookup_test += [f' lda #{frame}',' sta ro_player_frame',f' lda #{pointer}',' jsr ro_lookup',f' cmp #{index}',f' beq ot_player_{frame}_{pointer}',' jmp ot_fail',f'ot_player_{frame}_{pointer} anop']
    lines[at:at]=lookup_test
    # Every frame must contribute occupied pixels under each attribute/parity;
    # sparse-only scenes can accidentally hide an entire asset in a clean gap.
    at=lines.index(' lda #0',lines.index('ot_player_3_249 anop'))
    coverage=[];full_code=[];full_data=[]
    for attr in (0,1):
        for parity in (0,1):
            case=attr*2+parity;full=bytearray([0x55]*32000)
            full_code += [' ldx #31998',' lda #$5555',f'ot_full_seed_{case} sta >rr_candidate,x',' dex',' dex',f' bpl ot_full_seed_{case}']
            for frame in range(31):
                sx=(frame%8)*40+parity;sy=(frame//8)*42+4;color=(frame+case)&15
                if not attr and color==5:color=6
                occupied=changed_pixels=0;raw=assets[frame*64:(frame+1)*64]
                for y in range(21):
                    for x in range(24):
                        b=raw[y*3+x//8];role=(b>>(6-(x&6)))&3 if attr else (b>>(7-(x&7)))&1
                        if not role:continue
                        occupied+=1;c=(0,11,color,7)[role] if attr else color
                        changed_pixels+=c!=5
                        dx=sx+x;dy=sy+y;pos=dy*160+dx//2
                        full[pos]=(full[pos]&240)|c if dx&1 else (full[pos]&15)|(c<<4)
                assert occupied>0 and changed_pixels>0,(frame,attr,parity)
                coverage.append(dict(frame=frame,attr=attr,parity=parity,occupied_pixels=occupied,changed_pixels=changed_pixels))
                for name,value in [('frame',frame),('x',sx),('y',sy),('color',color),('attr',attr)]:full_code += [f' lda #{value}',f' sta ro_{name}']
                full_code += [' stz ro_span_row',' stz ro_span_offset',' lda #160',' sta ro_span_length',f'ot_full_row_{case}_{frame} jsr ro_draw',' cmp #0',f' beq ot_full_ok_{case}_{frame}',' jmp ot_fail',f'ot_full_ok_{case}_{frame} lda ro_span_offset',' clc',' adc #160',' sta ro_span_offset',' inc ro_span_row',' lda ro_span_row',' cmp #200',f' bcc ot_full_row_{case}_{frame}']
            full_code += [' ldx #0',f'ot_full_compare_{case} lda >rr_candidate,x',f' cmp >ot_full_expected_{case},x',f' beq ot_full_match_{case}',' jmp ot_fail',f'ot_full_match_{case} inx',' inx',' cpx #32000',f' bcc ot_full_compare_{case}']
            full_data += [' ALIGN 32768',f'OTFULL{case} START OTFULL{case}']+data(f'ot_full_expected_{case}',full)+[' END']
    lines[at:at]=full_code;lines+=full_data
    lines += [' copy build/iigs/native-renderer/object/parity.s']
    (OUT/'test.s').write_text('\n'.join(lines)+'\n')
    (OUT/'reporter.c').write_text('#include <stdio.h>\nextern unsigned object_test(void);\nint main(void) { unsigned r=object_test(); printf("native object/span selftest: %u\\n",r); return r; }\n')
    commands=[['iix','assemble','+L','+S',str(OUT/'test.s'),'keep='+str(OUT/'test')],['iix','compile',str(OUT/'reporter.c'),'keep='+str(OUT/'reporter')],['iix','link',str(OUT/'reporter'),str(OUT/'test'),'keep='+str(OUT/'object-test')],['iix',str(OUT/'object-test')]]
    for i,cmd in enumerate(commands):
        p=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
        (OUT/f'step-{i}.log').write_text(p.stdout)
        if p.returncode:raise RuntimeError(p.stdout[-2000:])
    if p.stdout.strip()!='native object/span selftest: 0':raise RuntimeError(p.stdout)
    paths += [ROOT/'src/iigs/render_object.asm',ROOT/'src/iigs/render_mask.asm',ROOT/'src/iigs/render_lookup.asm',ROOT/'src/core/data/tables.c',ROOT/'src/core/const.h',Path(__file__).resolve(),OUT/'test.s',OUT/'object-test']
    (OUT/'manifest.json').write_text(json.dumps(dict(scope='Actual65816scalar sprite kernel clippedtoexactspans; noE1 orperformance claim',commands=commands,frames=31,objects=objects,compared_bytes=160000,occupied_coverage=coverage,hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}),indent=2)+'\n')
    print(p.stdout.strip())
if __name__=='__main__':main()
