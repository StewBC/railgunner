#!/usr/bin/env python3
"""Private, windowed 2 MB A3010 diagnostic deployment; shared emulator is read-only."""
from pathlib import Path
import os
import plistlib
import shutil
import subprocess
import sys
import argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--stage",action="store_true")
parser.add_argument("--instance",choices=("actual","eight","capacity"))
parser.add_argument("--scenario",type=int,choices=range(5))
parser.add_argument("--frames",type=int,default=30500)
args=parser.parse_args()
root = Path(__file__).resolve().parents[2]
source = Path(os.environ.get('ARCU_HOME', str(Path.home() / 'Applications/arculator')))
base = root / 'build/archie/arculator'
if args.instance: base = base / 'runs' / args.instance
if not (source / 'arculator').is_file():
    sys.exit('Set ARCU_HOME to the Arculator installation')
base.mkdir(parents=True, exist_ok=True)
for name in ('roms', 'podules', 'ddnoise', 'lib'):
    dst = base / name
    if not dst.exists():
        dst.symlink_to(source / name, target_is_directory=True)
if not (base / 'cmos').exists():
    shutil.copytree(source / 'cmos', base / 'cmos')
(base / 'configs').mkdir(exist_ok=True)
config = (source / 'configs/A3010.cfg').read_text()
config = config.replace('mem_size = 4096', 'mem_size = 2048')
if 'mem_size = 2048' not in config or 'rom_set = riscos311' not in config:
    sys.exit('Unrecognized baseline configuration')
(base / 'configs/A3010.cfg').write_text(config)
appdir = base / 'hostfs/!RGDiag'
appdir.mkdir(parents=True, exist_ok=True)
shutil.copy2(root / 'build/archie/railgunner,ff8', appdir / 'Diagnostic,ff8')
command='Diagnostic' if args.scenario is None else f'Diagnostic integrated {args.scenario} {args.frames}'
(appdir / '!Run,feb').write_text('Set RGDiag$Dir <Obey$Dir>\nWimpSlot -min 896K -max 896K\n<RGDiag$Dir>.'+command+'\n')
(base / 'arc.cfg').write_text((source / 'arc.cfg').read_text().replace('first_fullscreen = 1', 'first_fullscreen = 0'))
if args.stage:
    print(base)
    sys.exit(0)
if sys.platform == 'darwin':
    name='RailGunner Arculator'+(' '+args.instance if args.instance else '')
    bundle = base / (name+'.app')
    mac = bundle / 'Contents/MacOS'
    mac.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / 'arculator', mac / 'arculator')
    for name in ('roms','podules','ddnoise','lib','cmos','configs','hostfs'):
        dst = mac / name
        if not dst.exists(): dst.symlink_to(base / name, target_is_directory=True)
    shutil.copy2(base / 'arc.cfg', mac / 'arc.cfg')
    (bundle / 'Contents/Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier':'local.railgunner.arculator'+('.'+args.instance if args.instance else ''),
        'CFBundleName':name, 'CFBundleExecutable':'arculator',
        'CFBundlePackageType':'APPL','CFBundleVersion':'1'}))
    log = open(base / 'emulator.log','w')
    subprocess.Popen([str(mac / 'arculator'),'A3010'], cwd=mac, stdout=log, stderr=log, start_new_session=True)
else:
    shutil.copy2(source / 'arculator',base / 'arculator')
    subprocess.Popen([str(base / 'arculator'),'A3010'],cwd=base)
print('Open HostFS, then !RGDiag to play. Ctrl-Q exits.')
