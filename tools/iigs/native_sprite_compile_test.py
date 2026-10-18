#!/usr/bin/env python3
"""Independently execute generated straight-line row instructions against source pixels.
This is a compiler semantic check, not a hardware shadow/beam timing proof.
"""
import re
from native_sprite_compile import generate,OUT
from native_render_assets import source_frames

def main():
    generate();text=(OUT/'compiled.s').read_text();frames,_,_=source_frames();checks=0
    mono=b''.join(bytes.fromhex(''.join(re.findall(r" dc h'([0-9a-f]+)'",text.split(f'NSMONO{bank} START NSMONO{bank}\n',1)[1].split(' END',1)[0]))) for bank in range(2))
    assert len(mono)==50778
    for frame,(_,raw) in enumerate(frames):
        for attr in range(2):
            for parity in range(2):
                for row in range(21):
                    label=f'nsc{frame}_{attr*2+parity}_{row}'
                    body=text.split(label+' anop\n',1)[1].split(' lda >ns_stop',1)[0].splitlines()
                    for color in range(16):
                        memory={};a=x=s=0;y=color*0x1111;width=16;base=0x3000
                        inks=[sum((color<<(n*4)) for n in range(4) if mask&(1<<n)) for mask in range(16)]
                        def read(at):return memory.get(at,0xa5)
                        def value(arg):
                            if arg=='>ns_address':return base
                            if arg.startswith('>ns_inks+'):
                                return inks[int(arg.split('+')[1])//2]&((1<<width)-1)
                            if arg.startswith('#'):return int(arg[1:].replace('$','0x'),0)
                            at=int(arg.split(',')[0].replace('|','').replace('$','0x'),0)+x
                            return read(at)|(read(at+1)<<8 if width==16 else 0)
                        def store(at,val,n):
                            for i in range(n):memory[at+i]=(val>>(i*8))&255
                        for line in body:
                            parts=line.strip().split(None,1);op=parts[0];arg=parts[1] if len(parts)>1 else ''
                            if op=='lda':a=value(arg)
                            elif op=='tax':x=a
                            elif op=='tya':a=y
                            elif op=='and':a&=value(arg)
                            elif op=='ora':a|=value(arg)
                            elif op=='adc':a=(a+value(arg))&65535
                            elif op=='tcs':s=a
                            elif op=='sta':store(int(arg.split(',')[0].replace('|','').replace('$','0x'),0)+x,a,width//8)
                            elif op in ('pea','pha','phy'):
                                val=int(arg.replace('$','0x'),0) if op=='pea' else y if op=='phy' else a
                                store(s-1,val,2);s-=2
                            elif op=='sep':width=8
                            elif op=='rep':width=16
                            elif op not in ('clc','longa'):raise AssertionError(line)
                        expected={}
                        for px in range(24):
                            bits=raw[row*3+px//8]
                            role=(bits>>(6-(px&6)))&3 if attr else ((bits>>(7-(px&7)))&1)
                            if not role:continue
                            ink=(0,11,color,7)[role] if attr else color
                            at=base+row*160+(px+parity)//2
                            old=expected.get(at,0xa5);shift=0 if (px+parity)&1 else 4
                            expected[at]=(old&~(15<<shift))|(ink<<shift)
                        if not attr:
                            for byte in range(13):
                                at=frame*1638+parity*819+row*39+byte*3
                                preserve,fixed,dynamic=mono[at:at+3]
                                actual=(0xa5&preserve)|fixed|(dynamic&(color*17))
                                assert actual==expected.get(base+row*160+byte,0xa5),(frame,parity,row,color,byte)
                        addresses=set(memory)|set(expected)
                        assert all(memory.get(at,0xa5)==expected.get(at,0xa5) for at in addresses),(frame,attr,parity,row,color,memory,expected)
                        checks+=1
    print(f'Generated row interpreter: {checks} original-art/mode/parity/row/color combinations PASS')
if __name__=='__main__':main()
