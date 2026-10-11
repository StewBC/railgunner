#!/usr/bin/env python3
from pathlib import Path
import sys
def bits(sr):
    return ((sr&0x400000)>>15)|((sr&0x100000)>>14)|((sr&0x10000)>>11)|((sr&0x2000)>>9)|((sr&0x800)>>8)|((sr&0x80)>>5)|((sr&0x20)>>3)|((sr&4)>>2)
v=[bits(i<<10) for i in range(8192)]+[bits(i) for i in range(1024)]
s='.section .rodata\n.align 2\n.global rg_noise_table\nrg_noise_table:\n'
for i in range(0,len(v),32): s+=' .byte '+','.join(map(str,v[i:i+32]))+'\n'
Path(sys.argv[1]).write_text(s)
