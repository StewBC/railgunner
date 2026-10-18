#!/usr/bin/env python3
"""Independent scalar pixels for the 2388-byte native render snapshot ABI."""
from pathlib import Path
import struct
from native_render_assets import source_frames
ROOT=Path(__file__).resolve().parents[2]
def render(snapshot, *, sprite_top=0):
    if len(snapshot)!=2388:raise ValueError('Expected exactly one render snapshot')
    if not 0<=sprite_top<=200:raise ValueError('Invalid sprite clipping row')
    charset=(ROOT/'assets/c64/charset/railgunner_charset.bin').read_bytes()
    title=(ROOT/'assets/c64/screens/title_hires.bin').read_bytes()
    title_colors=(ROOT/'assets/c64/screens/title_hires_col.bin').read_bytes()
    frames,lookup,players=source_frames()
    present,mode=struct.unpack_from('<2H',snapshot,2384)
    image=bytearray(32000);owners={};drawable=[]
    for cell in range(1000):
        if present==1:
            fg,bg=title_colors[cell]>>4,title_colors[cell]&15;bits=title[cell*8:cell*8+8]
        else:
            fg,bg=snapshot[1000+cell]&15,0;glyph=snapshot[cell];bits=charset[glyph*8:glyph*8+8]
        for sy,b in enumerate(bits):
            pixels=[fg if b&(128>>sx) else bg for sx in range(8)]
            at=(cell//40*8+sy)*160+cell%40*4
            image[at:at+4]=bytes(pixels[sx]*16+pixels[sx+1] for sx in range(0,8,2))
    records=[struct.unpack_from('<8H',snapshot,2000+slot*16) for slot in range(24)]
    ranks=[3,2,1,0,0,3]
    if present!=1:
        for rank in range(3,-1,-1):
            for slot,(x,y,ptr,player,color,attr,kind,flags) in enumerate(records):
                if (ranks[kind] if kind<6 else 3)!=rank or not flags&2:continue
                frame=players[player&3] if ptr in (248,249) else lookup[ptr&255]
                if frame==65535:continue
                raw=frames[frame][1];occupied=0
                for sy in range(21):
                    for sx in range(24):
                        px,py=x-24+sx,y-50+sy
                        if not(0<=px<320 and sprite_top<=py<200):continue
                        b=raw[sy*3+sx//8]
                        role=(b>>(6-(sx&6)))&3 if attr&1 else (b>>(7-(sx&7)))&1
                        if not role:continue
                        ink=(0,11,color&15,7)[role] if attr&1 else color&15
                        at=py*160+px//2;shift=0 if px&1 else 4
                        image[at]=(image[at]&~(15<<shift))|(ink<<shift)
                        owners[(px,py)]=slot;occupied+=1
                if occupied:drawable.append(slot)
    return bytes(image),dict(present=present,mode=mode,allocated_slots=sum(bool(r[7]&1) for r in records),drawable_slots=drawable,visible_slots=sorted(set(owners.values())),objects=records)
