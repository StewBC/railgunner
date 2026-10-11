#!/usr/bin/env python3
"""Embed the exact SDL inputs, without timestamps or runtime source paths."""
from pathlib import Path
import re
import sys
root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1])
tables = (root / 'src/core/data/tables.c').read_text()
defs = dict(re.findall(r'^#define\s+(\w+)\s+(\w+)',(root / 'src/core/const.h').read_text(),re.M))
def constant(name):
    value=defs[name]
    while value in defs: value=defs[value]
    return int(value,0)
mc0,mc1=constant('SPR_MC0_COLOR'),constant('SPR_MC1_COLOR')
entries = re.findall(r'\{ (SPR_PTR_\w+), "([^"]+\.bin)" \}', tables)
players = re.findall(r'"(player_\w+\.bin)"', tables)
def tokens(name, data):
    variants=[]
    for parity in range(2):
        values=[]
        for row in range(21):
            line=[0]*13
            for x in range(24):
                role=(data[row*3+x//8] >> (6-(x%8)//2*2))&3
                if not role: continue
                shift=((x+parity)&1)*4
                b=(x+parity)//2
                mask=15<<shift
                fixed=(mc0 if role==1 else mc1 if role==3 else 0)<<shift
                ink=mask if role==2 else 0
                line[b] |= (mask<<16)|(ink<<8)|fixed
            values.extend(line)
        variants.append("{"+",".join(str(v) for v in values)+"}")
    return f"const uint32_t {name}[2][273] = {{"+",".join(variants)+"};\n"

patterns={(0,0,0):0}
compiled_frames={}
def word_tokens(name, data):
    variants=[]
    frame=[]
    for parity in range(8):
        values=[]
        for row in range(21):
            mask=[0]*4; ink=[0]*4; fixed=[0]*4
            for x in range(24):
                role=(data[row*3+x//8] >> (6-(x%8)//2*2))&3
                if not role: continue
                shift=((x+parity)%8)*4; b=(x+parity)//8
                mask[b] |= 15<<shift
                if role==2: ink[b] |= 15<<shift
                else: fixed[b] |= (mc0 if role==1 else mc1)<<shift
            for b in range(4):
                token=(mask[b],ink[b],fixed[b])
                if token not in patterns: patterns[token]=len(patterns)
                values.append(patterns[token])
        frame.append(values)
        variants.append("{"+",".join(str(v)+'u' for v in values)+"}")
    compiled_frames[name]=frame
    return f"const uint32_t {name}[8][84] = {{"+",".join(variants)+"};\n"

def array(name, path, size):
    data = path.read_bytes()
    if len(data) != size: raise ValueError(f'{path}: expected {size} bytes')
    lines = [','.join(str(b) for b in data[i:i+32]) for i in range(0,len(data),32)]
    return f'const uint8_t {name}[{size}] = {{\n'+',\n'.join(lines)+'\n};\n'
text = '#include "assets.h"\n#include "data/tables.h"\n'
for name,rel,size in [('rg_charset','charset/railgunner_charset.bin',2048),('rg_title','screens/title_hires.bin',8000),('rg_title_colors','screens/title_hires_col.bin',1000)]:
    text += array(name, root / 'assets/c64' / rel,size)
font=(root / 'assets/c64/charset/railgunner_charset.bin').read_bytes()
text += 'const uint32_t rg_text_tiles[16][256][8] = {\n'
for color in range(16):
    text += '{'+','.join('{'+','.join(str(sum((color if b&(128>>x) else 0)<<(x*4) for x in range(8)))+'u' for b in font[glyph*8:glyph*8+8])+'}' for glyph in range(256))+'},\n'
text += '};\n'
title=(root / 'assets/c64/screens/title_hires.bin').read_bytes()
title_colors=(root / 'assets/c64/screens/title_hires_col.bin').read_bytes()
packed=[0]*8000
for cy in range(25):
    for cx in range(40):
        cell=cy*40+cx; fg=title_colors[cell]>>4; bg=title_colors[cell]&15
        for y in range(8):
            bits=title[cell*8+y]
            packed[(cy*8+y)*40+cx]=sum((fg if bits&(128>>x) else bg)<<(x*4) for x in range(8))
text += 'const uint32_t rg_title_packed[8000]={'+','.join(str(v)+'u' for v in packed)+'};\n'
for i,(_,name) in enumerate(entries):
    path=root / 'assets/c64/sprites' / name
    text += array(f'rg_sprite_{i}',path,64)
    text += tokens(f'rg_tokens_{i}',path.read_bytes())
    text += word_tokens(f'rg_word_tokens_{i}',path.read_bytes())
for i,name in enumerate(players):
    path=root / 'assets/c64/sprites' / name
    text += array(f'rg_player_{i}',path,64)
    text += tokens(f'rg_player_tokens_{i}',path.read_bytes())
    text += word_tokens(f'rg_player_word_tokens_{i}',path.read_bytes())
cargo_body=re.search(r'const uint8_t spr_cargo_disc\[[^]]+\] = \{(.*?)\};',tables,re.S).group(1)
cargo=bytes(int(v,16) for v in re.findall(r'0x([0-9A-Fa-f]+)',cargo_body))
if len(cargo)!=64: raise ValueError('cargo frame must be exactly 64 bytes')
text += word_tokens('rg_cargo_word_tokens',cargo)
ordered=list(patterns)
for color in range(16):
    ink=color*0x11111111
    text += f'const uint32_t rg_word_pair_{color}[][2] = {{'+','.join('{'+str(v[0])+'u,'+str((v[1]&ink)|v[2])+'u}' for v in ordered)+'};\n'
text += 'const uint32_t (*const rg_word_pairs[16])[2]={'+','.join(f'rg_word_pair_{c}' for c in range(16))+'};\n'
text += f'/* {len(ordered)} deduplicated masked word patterns. */\n'
text += 'const uint8_t *const rg_sprites[256] = {\n'
text += ''.join(f'[{ptr}]=rg_sprite_{i},\n' for i,(ptr,_) in enumerate(entries))
text += '[SPR_PTR_CARGO]=spr_cargo_disc,\n};\n'
text += 'const uint8_t *const rg_players[4]={'+','.join(f'rg_player_{i}' for i in range(4))+'};\n'
text += 'const uint32_t (*const rg_sprite_tokens[256])[273] = {\n'
text += ''.join(f'[{ptr}]=rg_tokens_{i},\n' for i,(ptr,_) in enumerate(entries))
text += '};\n'
text += 'const uint32_t (*const rg_player_tokens[4])[273] = {'+','.join(f'rg_player_tokens_{i}' for i in range(4))+'};\n'
text += 'const uint32_t (*const rg_sprite_word_tokens[256])[84] = {\n'
text += ''.join(f'[{ptr}]=rg_word_tokens_{i},\n' for i,(ptr,_) in enumerate(entries))
text += '[SPR_PTR_CARGO]=rg_cargo_word_tokens,\n};\n'
text += 'const uint32_t (*const rg_player_word_tokens[4])[84] = {'+','.join(f'rg_player_word_tokens_{i}' for i in range(4))+'};\n'
asm='.text\n.align 2\n'
text += '#ifdef __arm__\n'
for name,frame in compiled_frames.items():
    for parity,ids in enumerate(frame):
        label=f'{name}_blit_{parity}'
        text += f'extern void {label}(uint32_t *,const uint32_t (*)[2]);\n'
        asm += f'.align 2\n.global {label}\n.type {label},%function\n{label}:\n'
        for word,pattern in enumerate(ids):
            if not pattern: continue
            offset=pattern*8
            asm += f'    ldr r2,[r1,#{offset}]\n    ldr r3,[r1,#{offset+4}]\n'
            screen=(word//4)*160+(word%4)*4
            asm += f'    ldr r12,[r0,#{screen}]\n    bic r12,r12,r2\n    orr r12,r12,r3\n    str r12,[r0,#{screen}]\n'
        asm += f'    mov pc,lr\n.size {label},.-{label}\n'
def funcs(name): return '{'+','.join(f'{name}_blit_{p}' for p in range(8))+'}'
text += 'const RGCompiledSprite rg_compiled_sprites[256][8]={\n'
text += ''.join(f'[{ptr}]='+funcs(f'rg_word_tokens_{i}')+',\n' for i,(ptr,_) in enumerate(entries))
text += '[SPR_PTR_CARGO]='+funcs('rg_cargo_word_tokens')+',\n};\n'
text += 'const RGCompiledSprite rg_compiled_players[4][8]={'+','.join(funcs(f'rg_player_word_tokens_{i}') for i in range(4))+'};\n#endif\n'
out.parent.mkdir(parents=True,exist_ok=True)
asmout=out.with_name('assets-blit.S')
if not asmout.exists() or asmout.read_text()!=asm: asmout.write_text(asm)
out.parent.mkdir(parents=True,exist_ok=True)
if not out.exists() or out.read_text() != text:
    out.write_text(text)
    asmout.touch()

# Satisfy Make dependencies even when regenerated content is identical.
out.touch()
asmout.touch()
