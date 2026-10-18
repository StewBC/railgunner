#!/usr/bin/env python3
"""Package the native S16 on a transfer disk and a private caller-supplied OS copy."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--binary',type=Path,default=Path('build/iigs/native-game-play/RAILGUNNER'))
 p.add_argument('--manifest',type=Path,default=Path('build/iigs/native-game-play/manifest.json'))
 p.add_argument('--template',type=Path,required=True);p.add_argument('--volume',required=True)
 p.add_argument('--out',type=Path,default=Path('build/iigs/native-game-package'));a=p.parse_args()
 if not a.volume.isalnum():p.error('Volume must be alphanumeric')
 out=(ROOT/a.out).resolve()
 if not out.is_relative_to(ROOT/'build'):p.error('Package output must remain under project build/')
 binary=(ROOT/a.binary).resolve();manifest=(ROOT/a.manifest).resolve();template=(ROOT/a.template).resolve()
 metadata=json.loads(manifest.read_text())
 if sha(binary)!=metadata['binary_sha256']:raise RuntimeError('Binary/manifest mismatch')
 if metadata.get('runtime')!='pure ORCA/M; no C objects or runtime':raise RuntimeError('Expected native game manifest')
 original_template_sha=sha(template);out.parent.mkdir(parents=True,exist_ok=True);commands=[]
 with tempfile.TemporaryDirectory(prefix='native-package-',dir=out.parent) as directory:
  stage=Path(directory);(stage/'Start').write_bytes(binary.read_bytes());(stage/'RAILGUNNER').write_bytes(binary.read_bytes())
  attributes='=Type(B3),AuxType(DB03),VersionCreate(00),MinVersion(80),Access(E3)\n'
  (stage/'_FileInformation.txt').write_text('Start'+attributes+'RAILGUNNER'+attributes)
  def run(args):
   command=['cadius']+[str(x) for x in args];result=subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
   commands.append(dict(command=command,returncode=result.returncode,output=result.stdout))
   if result.returncode:raise RuntimeError(result.stdout)
  boot=stage/'railgunner-boot.2mg';shutil.copy2(template,boot)
  run(['DELETEFILE',boot,'/'+a.volume+'/System/Start']);run(['ADDFILE',boot,'/'+a.volume+'/System',stage/'Start'])
  transfer=stage/'railgunner-transfer.2mg';run(['CREATEVOLUME',transfer,'RAILGUNNER','800KB']);run(['ADDFILE',transfer,'/RAILGUNNER',stage/'RAILGUNNER'])
  for image,path,label in [(boot,'/'+a.volume+'/System/Start','boot'),(transfer,'/RAILGUNNER/RAILGUNNER','transfer')]:
   run(['CHECKVOLUME',image]);extracted=stage/('verify-'+label);extracted.mkdir();run(['EXTRACTFILE',image,path,extracted])
   matches=[file for file in extracted.iterdir() if file.name.upper().startswith(('START#' if label=='boot' else 'RAILGUNNER#'))]
   assert len(matches)==1 and '#B3DB03' in matches[0].name.upper(),list(extracted.iterdir())
   assert matches[0].read_bytes()==binary.read_bytes(),'Extracted S16 differs'
  assert sha(template)==original_template_sha,'Caller template was modified'
  out.mkdir(exist_ok=True)
  for name in ['railgunner-boot.2mg','railgunner-transfer.2mg','RAILGUNNER']:
   shutil.copy2(stage/name,out/name)
  shutil.copy2(stage/'_FileInformation.txt',out/'_FileInformation.txt');shutil.copy2(manifest,out/'build-manifest.json')
  result=dict(scope='Native S16 packaging and exact disk extraction; emulator/hardware acceptance separate',binary_sha256=sha(binary),template=str(template),template_sha256=original_template_sha,speed=metadata.get('speed'),commands=commands,outputs={name:sha(out/name) for name in ['railgunner-boot.2mg','railgunner-transfer.2mg','RAILGUNNER']},helper_sha256=sha(Path(__file__)))
  (out/'package-manifest.json').write_text(json.dumps(result,indent=2)+'\n')
 print('Packaged '+str(out/'railgunner-boot.2mg')+' and '+str(out/'railgunner-transfer.2mg'))
if __name__=='__main__':main()
