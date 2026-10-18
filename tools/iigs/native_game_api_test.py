#!/usr/bin/env python3
"""Build an isolated real GS/OS fixture for shipping GAME JSL ABI/capture.

Uses the shipping generated GAME body unchanged, a diagnostic mailbox driver,
and a separate capture segment. No C code is linked into the guest.
"""
import argparse,hashlib,json,re,shutil,subprocess,sys,time
from pathlib import Path
from native_core_test import Controller,ROOT
from native_abi_test import regs

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(cmd):
    p=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    if p.returncode:raise RuntimeError(p.stdout[-12000:])
    return p.stdout

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--core',type=Path,default=ROOT/'build/iigs/nativecore-group5')
    p.add_argument('--out',type=Path,default=ROOT/'build/iigs/native-game-api')
    args=p.parse_args();core=args.core.resolve();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    assert out.is_relative_to(ROOT/'build')
    rel=out.relative_to(ROOT).as_posix();text=(core/'coretest.asm').read_text()
    text=text.replace('lda #game_entry','lda #game_prod_base')
    text=text.replace('core_bank_ok              lda #1', '''core_bank_ok              lda core_game_dp
                          sta >game_dp
                          lda #rc_live_glyphs
                          sta core_capture_base
                          lda #^CAPTURE
                          and #255
                          sta core_capture_base+2
                          lda #1''')
    text=text.replace('core_tick                 jsl game_entry', 'core_tick                 jsl game_tick\n                          lda >game_status\n                          sta core_status')
    text=text.replace('core_invoke               jsl game_entry', '''core_invoke               lda core_command
                          cmp #1
                          bne api_capture
api_start_before          jsl game_start
api_start_after           bra api_status
api_capture               anop
api_capture_before        jsl game_capture
api_capture_after         anop
api_status                lda >game_status
                          sta core_status''')
    text=text.replace('core_frame                ds 4','core_frame                ds 4\ncore_capture_base         ds 4')
    text=text.replace('core_tick                 jsl game_tick','core_tick                 anop\napi_tick_before           jsl game_tick\napi_tick_after            anop')
    text=text.replace('                          bra core_loop','                          jmp core_loop')
    text=text.replace('copy '+core.relative_to(ROOT).as_posix()+'/core.s','copy '+core.relative_to(ROOT).as_posix()+'/game-production.s')
    text+='''\n                          ALIGN 32768
CAPTURE                   START CAPTURE
rc_live_glyphs            ENTRY
                          ds 1000
rc_live_colors            ENTRY
                          ds 1000
rc_live_objects           ENTRY
                          ds 384
rc_live_present           ENTRY
                          ds 2
rc_live_mode              ENTRY
                          ds 2
                          END
'''
    (out/'api.asm').write_text(text)
    (out/'listing').write_text(run(['iix','assemble','+L','+S',rel+'/api.asm','keep='+rel+'/main']))
    (out/'link.script').write_text('+S +L\n'+rel+'/main\n')
    run(['iix','chtyp','-l','LINKER',rel+'/link.script'])
    (out/'link.map').write_text(run(['iix','assemble',rel+'/link.script','keep='+rel+'/APITEST']))
    symbols={}
    for f in ('listing','link.map'):
        for a,n in re.findall(r'\b([0-9A-F]{6})\s+([A-Za-z_]\w*)',(out/f).read_text()):symbols[n]=int(a,16)
    manifest={'binary_sha256':sha(out/'APITEST'),'symbols':symbols,'scope':__doc__,'hashes':{}}
    for f in [out/'api.asm',core/'game-production.s',core/'game-translated.s',ROOT/'src/iigs/game_services.asm',Path(__file__)]:manifest['hashes'][str(f.relative_to(ROOT))]=sha(f)
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    template=ROOT.parent/'force/assets/iigs/disc/templat.2mg'
    assert template.is_file(),'Supplied Force GS/OS template is missing'
    launched=json.loads(run([sys.executable,'tools/iigs/native_probe.py','--binary',str(out/'APITEST'),'--manifest',str(out/'manifest.json'),'--source',str(out/'api.asm'),'--template',str(template),'--volume','FORCE']))
    folder=Path(launched['folder']) if 'folder' in launched else Path(launched['session']).parent
    session=json.loads((folder/'session.json').read_text())
    sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
    from gs2debug import Client,BP_KIND_EXEC,BP_FLAG_ENABLED,BP_FLAG_TEMPORARY,REG_A,REG_X,REG_Y,REG_DB,REG_P
    c=Client();proof={'scope':__doc__,'session':session,'binary_sha256':sha(folder/'Start'),'checks':[]}
    try:
        deadline=time.monotonic()+30
        while not Path(session['socket']).exists():
            assert time.monotonic()<deadline,'Debugger socket startup'
            time.sleep(.1)
        c.connect(session['socket']);c.hello();c.continue_();base=0xa0000
        def read(a,n):return b''.join(c.read_mem(0,a+i,min(4096,n-i)) for i in range(0,n,4096))
        def addr(n):return base+symbols[n]
        deadline=time.monotonic()+180
        while read(addr('core_ready'),2)!=b'\1\0':
            if time.monotonic()>deadline:raise TimeoutError('API startup')
            time.sleep(.1)
        mapping=json.loads((core/'state-map.json').read_text());old=json.loads((core/'manifest.json').read_text())['symbols']
        mapping['mailbox']={n:symbols[n] for n in mapping['mailbox']}
        ctl=Controller(c,mapping,base)
        def call(command,name):
            c.pause();c.wait_stopped(timeout=5)
            bp=c.bp_set(kind=BP_KIND_EXEC,address=addr('api_'+name+'_before'),flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
            c.write_mem(0,addr('core_command'),command.to_bytes(2,'little'));ctl.seq=(ctl.seq+1)&65535
            c.write_mem(0,addr('core_request_seq'),ctl.seq.to_bytes(2,'little'))
            c.continue_();e=c.wait_stopped(timeout=10);assert e.bp_id==bp
            caller=regs(c.get_regs())
            c.set_regs(REG_A|REG_X|REG_Y|REG_DB|REG_P,a=0xA537,x=0x1234,y=0xFEDC,db=0xE1,p=(caller['p']&0xCF)|9)
            before=regs(c.get_regs());bp=c.bp_set(kind=BP_KIND_EXEC,address=addr('api_'+name+'_after'),flags=BP_FLAG_ENABLED|BP_FLAG_TEMPORARY)
            c.continue_();e=c.wait_stopped(timeout=10);assert e.bp_id==bp
            after=regs(c.get_regs());assert {k:v for k,v in before.items() if k!='pc'}=={k:v for k,v in after.items() if k!='pc'},(before,after)
            proof['checks'].append({'call':name,'before':before,'after':after})
            c.set_regs(REG_DB|REG_P,db=caller['db'],p=caller['p'])
            c.continue_();deadline=time.monotonic()+5
            while ctl.word('core_completed_seq')!=ctl.seq:
                assert time.monotonic()<deadline;time.sleep(.002)
            assert ctl.word('core_status')==0
        call(1,'start');call(2,'tick')
        assert int.from_bytes(read(ctl.game+symbols['game_frame']-symbols['game_prod_base'],4),'little')==1
        def game(n):return ctl.game+symbols[n]-symbols['game_prod_base']
        glyph=bytes((i*37+3)&255 for i in range(1000));color=bytes(i&15 for i in range(1000))
        c.write_mem(0,game('SCREEN_RAM'),glyph);c.write_mem(0,game('COLOR_RAM'),color)
        arrays={'x_lo':bytes(range(24)),'x_hi':bytes(i&1 for i in range(24)),'y_int':bytes(30+i for i in range(24)),
                'sprite_ptr':bytes([248,249]+list(range(202,224))),'sprite_color':bytes(i&15 for i in range(24)),
                'sprite_attr':bytes(i*3 for i in range(24)),'kind':bytes(i%12 for i in range(24)),'flags':bytes(i*7 for i in range(24))}
        for n,v in arrays.items():c.write_mem(0,game('objects__obj_'+n),v)
        c.write_mem(0,game('native_player_frame'),b'\3\0');c.write_mem(0,game('native_present'),b'\0\0')
        c.write_mem(0,ctl.dp+mapping['raw_dp']['game_mode']['offset'],b'\11')
        call(3,'capture');capture=int.from_bytes(read(addr('core_capture_base'),4),'little')
        expected=bytearray(glyph+color)
        for i in range(24):
            words=[arrays['x_lo'][i]+256*arrays['x_hi'][i],arrays['y_int'][i],arrays['sprite_ptr'][i],3 if i<2 else 0,arrays['sprite_color'][i],arrays['sprite_attr'][i],arrays['kind'][i],arrays['flags'][i]]
            expected.extend(b''.join(w.to_bytes(2,'little') for w in words))
        expected+=b'\0\0\11\0'
        actual=read(capture,len(expected));assert actual==expected,[(i,a,b) for i,(a,b) in enumerate(zip(actual,expected)) if a!=b][:16]
        proof['capture_bytes']=len(expected);proof['capture_sha256']=hashlib.sha256(actual).hexdigest();proof['passed']=True
        print(json.dumps({'passed':True,'capture_bytes':len(expected),'folder':str(folder)}),flush=True)
    finally:
        (folder/'game-api-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
        try:c.quit()
        except (OSError,RuntimeError):pass
        c.close()
if __name__=='__main__':main()
