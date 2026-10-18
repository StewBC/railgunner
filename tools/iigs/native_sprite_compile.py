#!/usr/bin/env python3
"""Compile original IIgs sprites into bounded, row-addressable 65816 code.
No external sprite compiler or altered art is used. Each frame occupies its own
ALIGN32768 segment; dynamic color patterns are prepared on the ordinary stack.
"""
from pathlib import Path
import hashlib,json
from native_render_assets import source_frames
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/specialized/sprites'
def tokens(raw,parity,attr,row):
    pixels=[None]*26
    for x in range(24):
        bits=raw[row*3+x//8]
        role=(bits>>(6-(x&6)))&3 if attr else (2 if bits&(128>>(x&7)) else 0)
        pixels[x+parity]=None if role==0 else ('d' if role==2 else (11 if role==1 else 7))
    result=[]
    for x in range(0,26,2):
        preserve=fixed=dynamic=0
        for value,shift in zip(pixels[x:x+2],(4,0)):
            if value is None:preserve|=15<<shift
            elif value=='d':dynamic|=15<<shift
            else:fixed|=value<<shift
        result.append((preserve,fixed,dynamic))
    return result

def encoded_layout(code):
    """Exact instruction widths for the deliberately small emitted vocabulary."""
    offset=0;labels={};m16=True
    one={'php','sei','cld','phb','phd','tsc','pha','plb','tax','asl','clc','tcs','pld','plp','rtl','tay','tya','phy'}
    for line in code:
        if not line.startswith(' '):
            parts=line.split(None,1);labels[parts[0]]=offset
            if len(parts)==1:continue
            line=' '+parts[1]
        parts=line.strip().split(None,1)
        if not parts:continue
        op=parts[0].lower();arg=parts[1] if len(parts)>1 else ''
        if op in ('align','start','entry','anop','end','longa','longi'):continue
        if op in one:offset+=1
        elif op in ('sep','rep'):
            offset+=2
            if int(arg[1:].replace('$','0x'),0)&32:m16=op=='rep'
        elif op=='bne':offset+=2
        elif op=='dc':offset+=2*len(arg.split("'")[1].split(','))
        elif op=='ds':offset+=int(arg)
        elif op in ('jmp','pea'):offset+=3
        elif op in ('lda','sta','and','ora','adc','cmp'):
            offset+=4 if arg.startswith('>') else (3 if m16 else 2) if arg.startswith('#') else 3
        else:raise AssertionError((op,arg))
    return offset,labels

def generate(out=OUT):
    out=Path(out);out.mkdir(parents=True,exist_ok=True)
    frames,pointer,players=source_frames();lines=[' case on'];manifest=[]
    for frame,(name,raw) in enumerate(frames):
        prefix=f'nsc{frame}';segment=f'NSC{frame}'
        code=[' ALIGN 32768',f'{segment} START {segment}',f'ns_f{frame} ENTRY',' php',' sei',' cld',' rep #$30',' longa on',' longi on',' phb',' phd',' tsc',f' sta >{prefix}_save_s',' sep #$20',' longa off',' lda >$e0c068',f' sta >{prefix}_save_map',' lda #1',' pha',' plb',' rep #$20',' longa on',' lda >ns_inks+30',' tay',' sep #$20',' longa off',f' lda >{prefix}_save_map',' ora #$30',' sta >$e0c068',' lda >$e0c035',f' sta >{prefix}_save_shadow',' and #$f7',' sta >$e0c035',' rep #$20',' longa on',' lda >ns_variant',' asl a',' sta >ns_dispatch',' asl a',' asl a',' clc',' adc >ns_dispatch',' asl a',' asl a',' clc',' adc >ns_dispatch',' sta >ns_dispatch',' lda >ns_first',' asl a',' clc',' adc >ns_dispatch',' tax',f' jmp ({prefix}_rows,x)']
        # variant*42 = variant*(32+8+2), above computes42 exactly.
        rowlabels=[];stats=[]
        for attr in range(2):
            for parity in range(2):
                variant=attr*2+parity
                for row in range(21):
                    label=f'{prefix}_{variant}_{row}';rowlabels.append(label)
                    code += [label+' anop',' lda >ns_address',' tax'];visible=0;ops=0
                    ts=tokens(raw,parity,attr,row)
                    # Last odd byte is always masked: never touch outside13byte extent.
                    p,f,d=ts[12]
                    if p!=255:
                        code += [' sep #$20',' longa off',f' lda |${row*160+12:04x},x',f' and #${p:02x}',f' ora #${f:02x}']
                        if d:code += [f' ora >ns_inks+{((1 if d&15 else 0)+(2 if d&240 else 0))*2}']
                        code += [f' sta |${row*160+12:04x},x',' rep #$20',' longa on'];visible+=1;ops+=40
                    words=[]
                    for i in range(0,12,2):
                        words.append(tuple(ts[i][j]|(ts[i+1][j]<<8) for j in range(3)))
                    right=5
                    while right>=0:
                        p,f,d=words[right]
                        if p==0:
                            end=right
                            while right>=0 and words[right][0]==0:right-=1
                            run=list(range(end,right,-1))
                            direct=sum(8 if words[i][2]==65535 else 15 if words[i][2] else 9 for i in run)
                            stacked=13+sum(4 if words[i][2]==65535 else 13 if words[i][2] else 5 for i in run)
                            if stacked<=direct:
                                code += [' lda >ns_address',' clc',f' adc #{row*160+end*2+1}',' tcs'];ops+=13
                                for index in run:
                                    _,f,d=words[index]
                                    if d==65535:code += [' phy'];ops+=4
                                    elif d:
                                        mask=sum((1<<n) for n in range(4) if d&(15<<(n*4)))
                                        code += [f' lda >ns_inks+{mask*2}',f' ora #${f:04x}',' pha'];ops+=13
                                    else:code += [f' pea ${f:04x}'];ops+=5
                                    visible+=2
                            else:
                                for index in run:
                                    _,f,d=words[index]
                                    if d==65535:code += [' tya'];ops+=2
                                    elif d:
                                        mask=sum((1<<n) for n in range(4) if d&(15<<(n*4)))
                                        code += [f' lda >ns_inks+{mask*2}',f' ora #${f:04x}'];ops+=9
                                    else:code += [f' lda #${f:04x}'];ops+=3
                                    code += [f' sta |${row*160+index*2:04x},x'];ops+=6;visible+=2
                            continue
                        if p!=65535:
                            code += [f' lda |${row*160+right*2:04x},x',f' and #${p:04x}',f' ora #${f:04x}']
                            if d:
                                mask=sum((1<<n) for n in range(4) if d&(15<<(n*4)))
                                code += [f' ora >ns_inks+{mask*2}']
                            code += [f' sta |${row*160+right*2:04x},x'];visible+=2;ops+=24
                        right-=1
                    code += [' lda >ns_stop',f' cmp #{row+1}',f' bne {label}_next',f' jmp {prefix}_restore',label+'_next anop']
                    if row==20:code += [f' jmp {prefix}_restore']
                    stats.append(dict(variant=variant,row=row,visible_bytes=visible,base_cycle_ceiling=ops+30))
        code += [prefix+'_restore anop',f' lda >{prefix}_save_s',' tcs',' sep #$20',' longa off',f' lda >{prefix}_save_map',' sta >$e0c068',f' lda >{prefix}_save_shadow',' sta >$e0c035',' rep #$20',' longa on',' pld',' plb',' plp',' rtl',prefix+'_rows anop']
        code += [" dc i2'"+','.join(rowlabels[i:i+7])+"'" for i in range(0,len(rowlabels),7)]
        code += [prefix+'_save_s ds 2',prefix+'_save_map ds 1',prefix+'_save_shadow ds 1',prefix+'_end anop',' END']
        lines += code
        size,labels=encoded_layout(code)
        assert size<=32768,(frame,size)
        manifest.append(dict(compiled_bytes=size,dynamic_patch_offsets=[],row_entry_offsets={label:labels[label] for label in rowlabels},frame=frame,name=name,source_sha256=hashlib.sha256(raw).hexdigest(),segment=segment,rows=stats))
    # Bounded horizontal edge consumer uses immutable byte-role rows. Existing
    # baseline segments provide multicolor rows; these add original mono bits.
    mono=bytes(value for _,raw in frames for parity in range(2) for row in range(21)
               for triple in tokens(raw,parity,0,row) for value in triple)
    assert len(mono)==50778
    extra=[]
    for bank,blob in enumerate((mono[:24570],mono[24570:])):
        segment=f'NSMONO{bank}'
        lines += [' ALIGN 32768',f'{segment} START {segment}',f'ns_mono{bank} ENTRY']
        lines += [" dc h'"+blob[i:i+32].hex()+"'" for i in range(0,len(blob),32)]
        lines += [' END']
        extra.append(dict(segment=segment,bytes=len(blob),sha256=hashlib.sha256(blob).hexdigest()))
    (out/'compiled.s').write_text('\n'.join(lines)+'\n')
    dispatch=['ns_call_frame anop',' lda ro_frame',' asl a',' tax',' jmp (ns_calls,x)']
    for frame in range(31):dispatch += [f'ns_call_{frame} jsl ns_f{frame}',' rts']
    dispatch += ['ns_calls anop']
    dispatch += [" dc i2'"+','.join(f'ns_call_{n}' for n in range(i,min(i+8,31)))+"'" for i in range(0,31,8)]
    (out/'dispatch.s').write_text('\n'.join(dispatch)+'\n')
    result=dict(edge_mono_segments=extra,frames=manifest,pointer_map=pointer,player_frames=players,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),compiled_sha256=hashlib.sha256((out/'compiled.s').read_bytes()).hexdigest(),abi=dict(address='bank01 row0 left byte',first='inclusive sprite row',stop='exclusive sprite row',variant='attr*2+xparity',inks='16 expanded dynamic nibble masks'))
    (out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n');return result
if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,default=OUT);a=p.parse_args();m=generate(a.out);print('Compiled',len(m['frames']),'original frames, both parities and modes')
