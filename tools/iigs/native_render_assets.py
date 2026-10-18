#!/usr/bin/env python3
"""Generate bounded parity mask/fixed/dynamic-role byte rows for native renderer.
Two loader-owned <=32KiB segments,15/16frames. Width is13bytes per21row,
parity0's finalbyte transparent; every row token is3bytes(preserve,fixed,dynamic).
Thirty file assets plus the procedural cargo disc. Monochrome retains original
bitplanes for the baseline kernel.
"""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/native-renderer'
def source_frames():
    paths=sorted((ROOT/'assets/c64/sprites').glob('*.bin'))
    assert len(paths)==30
    frames=[(p.name,p.read_bytes()) for p in paths]
    tables=(ROOT/'src/core/data/tables.c').read_text()
    cargo=re.search(r'const uint8_t spr_cargo_disc\[[^]]+\] = \{(.*?)\};',tables,re.S).group(1)
    frames.append(('cargo_disc',bytes(int(v,16) for v in re.findall(r'0x([0-9a-fA-F]+)',cargo))))
    defs=dict(re.findall(r'^#define\s+(\w+)\s+(\w+)',(ROOT/'src/core/const.h').read_text(),re.M))
    def number(key):
        while key in defs:key=defs[key]
        return int(key,0)
    names={name:i for i,(name,_) in enumerate(frames)}
    lookup=[65535]*256
    for key,name in re.findall(r'\{ (SPR_PTR_\w+), "([^"\n]+\.bin)" \}',tables):lookup[number(key)]=names[name]
    lookup[number('SPR_PTR_CARGO')]=30
    players=[names[name] for name in re.findall(r'"(player_\w+\.bin)"',tables)]
    assert len(players)==4
    return frames,lookup,players

def generate(out=OUT):
    out.mkdir(parents=True,exist_ok=True)
    frames,lookup,players=source_frames()
    payload=bytearray()
    for name,raw in frames:
        assert len(raw)==64
        for parity in range(2):
            for row in range(21):
                roles=[0]*26
                for x in range(24):roles[x+parity]=(raw[row*3+x//8]>>(6-(x&6)))&3
                for x in range(0,26,2):
                    preserve=fixed=dynamic=0
                    for role,shift in [(roles[x],4),(roles[x+1],0)]:
                        if role==0:preserve|=15<<shift
                        elif role==1:fixed|=11<<shift
                        elif role==2:dynamic|=15<<shift
                        else:fixed|=7<<shift
                    payload+=bytes((preserve,fixed,dynamic))
    assert len(payload)==50778
    lines=['; generated immutable source role rows; exact frame ordering in assets.json']
    for segment,blob in enumerate((payload[:24570],payload[24570:])):
        lines += [' ALIGN 32768',f'ROPAR{segment} START ROPAR{segment}',f'ro_parity_{segment} ENTRY']
        lines += [" dc h'"+blob[i:i+32].hex()+"'" for i in range(0,len(blob),32)]
        lines += [' END']
    (out/'parity.s').write_text('\n'.join(lines)+'\n')
    manifest=dict(row_bytes=39,parity_bytes=819,frame_bytes=1638,segment_bytes=[24570,26208],pointer_map=lookup,player_frames=players,frames=[dict(index=i,name=name,sha256=hashlib.sha256(raw).hexdigest()) for i,(name,raw) in enumerate(frames)],payload_sha256=hashlib.sha256(payload).hexdigest())
    lookup_lines=['ro_pointer_map anop']+[" dc i2'"+','.join(map(str,lookup[i:i+16]))+"'" for i in range(0,256,16)]
    lookup_lines += ["ro_player_map dc i2'"+','.join(map(str,players))+"'"]
    lookup_lines += ['ro_bounds anop']
    bounds=[]
    for _,raw in frames:
        for attr in (0,1):
            points=[(x,y) for y in range(21) for x in range(24) if (((raw[y*3+x//8]>>(6-(x&6)))&3) if attr else ((raw[y*3+x//8]>>(7-(x&7)))&1))]
            box=[min(x for x,y in points),max(x for x,y in points)+1,min(y for x,y in points),max(y for x,y in points)+1] if points else [0,0,0,0]
            bounds.append(box);lookup_lines += [" dc i2'"+','.join(map(str,box))+"'"]
    manifest['opaque_bounds']=bounds
    (out/'lookup.s').write_text('\n'.join(lookup_lines)+'\n')
    (out/'assets.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return payload
def selftest(payload):
    frames,_,_=source_frames();checks=0
    for frame,(_,raw) in enumerate(frames):
        for parity in range(2):
            for row in range(21):
                for byte in range(13):
                    at=frame*1638+parity*819+row*39+byte*3
                    preserve,fixed,dynamic=payload[at:at+3]
                    for color in range(16):
                        for background in (0,0x55,0xab,0xff):
                            actual=(background&preserve)|fixed|(dynamic&(color*17))
                            expected=background
                            for nibble in (0,1):
                                x=byte*2+nibble-parity
                                role=(raw[row*3+x//8]>>(6-(x&6)))&3 if 0<=x<24 else 0
                                if role:
                                    ink=(0,11,color,7)[role];shift=0 if nibble else 4
                                    expected=(expected&~(15<<shift))|(ink<<shift)
                            assert actual==expected,(frame,parity,row,byte,color,background)
                            checks+=1
    return checks
if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--test',action='store_true');args=parser.parse_args()
    payload=generate()
    if args.test:print('Parity role tokens: '+str(selftest(payload))+' scalar combinations PASS')
