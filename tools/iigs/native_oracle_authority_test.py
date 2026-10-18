#!/usr/bin/env python3
"""Audit the explicit C64 spawn-choice oracle override against register semantics."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import native_oracle as oracle


def expected():
    result=bytearray()
    for mask in range(16):
        for last in range(4):
            for seed in range(256):
                candidates=[]
                x=0
                while x<4:
                    if mask&(1<<x):
                        if x==last and candidates:
                            saved=x
                            # Original count_quad_bits scans X=0..3 and
                            # returns X=4. Only the <2 path restores saved X.
                            count=sum(bool(mask&(1<<i)) for i in range(4))
                            x=4
                            if count<2:
                                x=saved
                                candidates.append(x)
                        else:
                            candidates.append(x)
                    x+=1
                if candidates:
                    state=seed or 1
                    state=((state<<1)^(0x1d if state&128 else 0))&255
                    chosen=candidates[state%len(candidates)]
                else:
                    chosen=3;state=seed
                result.extend((chosen,state))
    return bytes(result)


def main():
    c64_binary,manifest=oracle.build('c64')
    c_binary,_=oracle.build()
    out=oracle.ROOT/'build/iigs/native-oracle-c64'
    sources=sorted(p for p in (oracle.ROOT/'src/core').rglob('*.c') if p.name not in ('main.c','drones.c'))
    outputs={};commands=[]
    for authority,unit in [('c',oracle.ROOT/'src/core/drones.c'),('c64',out/'drones-c64-authority.c')]:
        driver=out/('roll-quad-'+authority+'.c')
        driver.write_text('#include <stdio.h>\n#include <string.h>\n#include "'+str(unit)+'"\n'
            'int main(void){Game g;unsigned mask,last,seed;for(mask=0;mask<16;++mask)for(last=0;last<4;++last)for(seed=0;seed<256;++seed){'
            'memset(&g,0,sizeof g);g.wave_quad_mask=(uint8_t)mask;g.spawn_last_quad=(uint8_t)last;g.rng_state=(uint8_t)seed;'
            'putchar(roll_quad(&g));putchar(g.rng_state);}return 0;}\n')
        binary=out/('roll-quad-'+authority)
        command=[shutil.which('cc'),'-std=c11','-O2','-Wall','-Wextra','-Werror','-I'+str(oracle.ROOT/'src/core'),str(driver)]+[str(p) for p in sources]+['-o',str(binary)]
        subprocess.run(command,check=True,capture_output=True);commands.append(command)
        outputs[authority]=subprocess.check_output([str(binary)])
        (out/('roll-quad-'+authority+'.bin')).write_bytes(outputs[authority])
    reference=expected()
    assert len(reference)==16*4*256*2
    assert outputs['c64']==reference
    differences=sum(outputs['c'][i:i+2]!=reference[i:i+2] for i in range(0,len(reference),2))
    assert differences>0,'Fixture no longer distinguishes the authority override'
    state_checks=[]
    def compare(commands):
        return (oracle.run_commands(commands,binary=c64_binary)[-1],
                oracle.run_commands(commands,binary=c_binary)[-1])
    a,b=compare('bare\nset rail_dmg_amt 0 77\nset rail_hit_left 0 66\nset rail_hit_slot 0 55\ncall rail_reset\ndump\n')
    assert [a[n] for n in ('rail_dmg_amt','rail_hit_left','rail_hit_slot')]==[77,66,55]
    assert [b[n] for n in ('rail_dmg_amt','rail_hit_left','rail_hit_slot')]==[0,0,255]
    state_checks.append('rail_reset preserves all three original strike scratch bytes')
    names=('death_phase','death_timer','death_fatal','death_flash','death_flash_t')
    fixture='bare\ncall objects_init\n'+''.join('set '+name+' 0 '+str(33+i)+'\n' for i,name in enumerate(names))+'call player_begin_deploy\ndump\n'
    a,b=compare(fixture)
    assert [a[n] for n in names]==[0]*5
    assert [b[n] for n in names]==list(range(33,38))
    state_checks.append('player init clears all five original death cache bytes')
    a,b=compare('bare\nset banner_col 0 3\nset banner_len 0 7\nset death_banner_col 0 12\nset death_banner_len 0 14\ndump\n')
    assert (a['banner_col'],a['banner_len'],a['death_banner_col'],a['death_banner_len'])==(12,14,12,14)
    assert (b['banner_col'],b['banner_len'],b['death_banner_col'],b['death_banner_len'])==(3,7,12,14)
    state_checks.append('normal/death setters and snapshots share one original span')
    fixture='bare\ncall objects_init\ncall player_begin_death_fatal\n'+('call player_update\n'*56)+'dump\n'
    a,b=compare(fixture)
    assert a['death_phase']==7 and a['player_dead']==1
    assert a['banner_len']==a['death_banner_len']>0
    assert a['banner_col']==a['death_banner_col']
    assert b['banner_len']==0 and b['death_banner_len']>0
    state_checks.append('actual fatal death paints and publishes the active shared span')
    result={'pass':True,'scope':__doc__,'cases':16*4*256,'shared_c_difference_cases':differences,'commands':commands,
        'state_checks':state_checks,'authority_overrides':manifest['authority_overrides'],'expected_sha256':hashlib.sha256(reference).hexdigest(),
        'actual_sha256':hashlib.sha256(outputs['c64']).hexdigest(),'helper_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (out/'authority-proof.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'pass':True,'cases':result['cases'],'shared_c_difference_cases':differences}))
if __name__=='__main__':main()
