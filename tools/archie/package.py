#!/usr/bin/env python3
"""Build standalone HostFS and native Acorn ZIP applications."""
from pathlib import Path
import hashlib
import struct
import zipfile
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/archie/release'
APP_NAME='!RGunner'
APP=OUT/APP_NAME
APP.mkdir(parents=True,exist_ok=True)
(APP/'COPYING,fff').write_bytes((ROOT/'UNLICENSE').read_bytes())
(APP/'SDKLicence,fff').write_bytes((ROOT/'src/archie/SDK-LICENSE.txt').read_bytes())
(APP/'Credits,fff').write_text('Game art and sound by Grok; cleanup and tiles by Stefan Wessels.\nCode by Grok and Codex, support from Claude. Produced by Stefan Wessels, 2026.\nArchieSDK Copyright 2024 The ArchieSDK Authors; licence: SDKLicence.\nNative SWI contracts use OSLib headers (Jonathan Coxhead and maintainers).\nVideo banking independently adapted from public-domain Time Pilot code.\n')
(APP/'!RunImage,ff8').write_bytes((ROOT/'build/archie/railgunner,ff8').read_bytes())
boot='Set RailGunner$Dir <Obey$Dir>\nIconSprites <RailGunner$Dir>.!Sprites\n'
(APP/'!Boot,feb').write_text(boot)
(APP/'!Run,feb').write_text(boot+'WimpSlot -min 896K -max 896K\n<RailGunner$Dir>.!RunImage\n')
(APP/'!Help,fff').write_text('RailGunner for A3010 / 2 MB / RISC OS 3.11\n\nEither joystick port or cursors/WASD: direction.\nJoystick fire or Space: fire/start/select.\nS: story (also down). I: instructions. Escape: RUN/STOP.\nCtrl-Q: quit and restore sound/display. Scores remain in RAM.\n\nNative 20.833 kHz sound; no external sound module required.\nEmulator and actual A3010 hardware evaluation passed. See src/archie/README.md in the source tree.\n')
# Old-format Mode 12 sprite: independent palette, packed pixels and mask.
width,height,row=34,17,20
pixels=bytearray(row*height); mask=bytearray(row*height)
for y in range(height):
    for x in range(width):
        rail=abs(x-17)<2 or abs(y-8)<1
        disc=((x-17)/2)**2+(y-8)**2<22
        if rail or disc:
            i=y*row+x//2; shift=(x%2)*4
            pixels[i]|=(9 if disc else 5)<<shift; mask[i]|=15<<shift
palette=b''.join(struct.pack('<II',c,c) for c in [0xffffff00,0xdddddd00,0xbbbbbb00,0x99999900,0x77777700,0x55555500,0x33333300,0,0x99440000,0x00eeee00,0x00cc0000,0x0000dd00,0xbbeeee00,0x00885500,0x00bbff00,0xffbb0000])
image_offset=44+len(palette); mask_offset=image_offset+len(pixels); size=mask_offset+len(mask)
header=struct.pack('<I12s7I',size,APP_NAME.lower().encode('ascii'),row//4-1,height-1,0,(width*4-1)%32,image_offset,mask_offset,12)
(APP/'!Sprites,ff9').write_bytes(struct.pack('<III',1,16,16+size)+header+palette+pixels+mask)
files=sorted(APP.iterdir())
# RISC OS 3 filing systems limit leaf names to ten characters. The Filer
# looks up the icon sprite using the application directory's name.
assert len(APP_NAME)<=10
assert all(len(p.name.rsplit(',',1)[0])<=10 for p in files)
sprite=(APP/'!Sprites,ff9').read_bytes()
assert sprite[16:28].split(b'\0',1)[0]==APP_NAME.lower().encode('ascii')
(OUT/'SHA256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+APP_NAME+'/'+p.name+'\n' for p in files))
for native in (False,True):
    target=OUT/('RailGunner-RISCOS.zip' if native else 'RailGunner-HostFS.zip')
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        for p in files:
            name,ft=p.name.rsplit(',',1)
            info=zipfile.ZipInfo(APP_NAME+'/'+(name if native else p.name),(2026,10,11,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            if native:
                cs=(2208988800+1791676800)*100
                load=0xfff00000|(int(ft,16)<<8)|((cs>>32)&255)
                info.extra=struct.pack('<HH4sIIII',0x4341,20,b'ARC0',load,cs&0xffffffff,3,0)
            z.writestr(info,p.read_bytes())
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None
        for i in z.infolist():
            assert z.read(i)==(APP/(i.filename.split('/')[-1]+(','+next(p.name.rsplit(',',1)[1] for p in files if p.name.rsplit(',',1)[0]==i.filename.split('/')[-1]) if native else ''))).read_bytes()
    print(target)
