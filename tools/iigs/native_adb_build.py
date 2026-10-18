#!/usr/bin/env python3
"""Build the standalone native Tool9 configuration diagnostic."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/iigs/native-adb'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    commands=[]
    def run(args,log):
        result=subprocess.run(args,cwd=ROOT,text=True,capture_output=True,timeout=120)
        (OUT/log).write_text(result.stdout+result.stderr)
        commands.append(args)
        if result.returncode:raise RuntimeError(result.stdout+result.stderr)
    run(['iix','assemble','+L','+S','tst/iigs/native_adb_probe.asm','keep=build/iigs/native-adb/probe'],'assemble.log')
    run(['iix','link','+S','+L','build/iigs/native-adb/probe','keep=build/iigs/native-adb/ADBPROBE'],'link.map')
    symbols={label:int(address,16) for address,label in re.findall(r'\b([0-9A-F]{6})\s+((?:probe_|input_)\w+)',(OUT/'assemble.log').read_text()+(OUT/'link.map').read_text())}
    assert symbols['probe_end']<32768
    paths=[ROOT/'tst/iigs/native_adb_probe.asm',Path(__file__).resolve(),ROOT/'src/iigs/input.asm',OUT/'ADBPROBE']
    manifest={'scope':'Tool9 asynchronous keyboard diagnostic; not gameplay integration','binary_sha256':hashlib.sha256((OUT/'ADBPROBE').read_bytes()).hexdigest(),'symbols':symbols,'commands':commands,'hashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},'iix_sha256':hashlib.sha256(Path(shutil.which('iix')).read_bytes()).hexdigest()}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'binary':str(OUT/'ADBPROBE'),'symbols':symbols}))
if __name__=='__main__':main()
