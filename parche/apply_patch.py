#!/usr/bin/env python3
"""Aplica el parche de Policenauts Saturn 1.5 en Linux/macOS."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path

HERE=Path(__file__).resolve().parent
AUDIO_HASH='4227a2f565934ddb8e92635c41f58eb39655231f107cba518e79220e33fd1ee2'
CONFIG={
 '1':dict(raw_bytes=524338416,raw_sha='956b9e06ef0e622d04aa2a1aabbebe305f06c7cefc87485d7e67cd6af3ee6938',cooked_sha='516ad090242df694becad079c1f187294df7b1c3259ef2b5b9405217cf70fb56',patch='disc1_jp_to_es.vcdiff',patch_sha='c39625ac83360bbbbb462bc21bde8d51807942ba4ca4f7f974c5ff5b945dd008',target_bytes=476891136,target_sha='ac3a9271f81e9bed89cfcea3cdf44188d8f4e17006b0d5f1f53473b289c6192d'),
 '2':dict(raw_bytes=560211120,raw_sha='053d1b3111992d826d8c5db0feb6684e82fc3e8cc5f0f68d626366652ccaa9fc',cooked_sha='1669ad792a25bade3709a19269c1a104d62e45de4f7849478f5950b17ec86c4b',patch='disc2_jp_to_es.vcdiff',patch_sha='4de92bd7d5f0bc68b6385b8206a8ddf0ed9d4d45266cf3a802e6e93eb9fb7a53',target_bytes=500459520,target_sha='56bf3a3153c9a15b5a307d16625702a852c27712f31695aa1b632331fa69aed9'),
 '3':dict(raw_bytes=513533328,raw_sha='bbe498ebb05d1657faf1d820d8ba24c67f112f335323a4c0fee7b89905c96a89',cooked_sha='8e0eb8a914e541318a6449f4512e9dbea45051dbae909556808adb2db3c6347f',patch='disc3_jp_to_es.vcdiff',patch_sha='7ac77c29f949c4b6108f063f67e0ab29a61c21dabd83c1d186375e0ec90d9365',target_bytes=459819008,target_sha='70ea53e1c6c88cbc78a256818dcfd29fabfa2d5413056a9215dc08bfcebadc75')}
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
 return h.hexdigest()
def cue_files(path,mode):
 data=path.read_text(encoding='utf-8-sig')
 expressions=[rf'(?im)^\s*TRACK\s+01\s+{re.escape(mode)}\s*$',r'(?im)^\s*TRACK\s+02\s+AUDIO\s*$',r'(?im)^\s*INDEX\s+01\s+00:00:00\s*$',r'(?im)^\s*INDEX\s+00\s+00:00:00\s*$',r'(?im)^\s*INDEX\s+01\s+00:02:00\s*$']
 if not all(re.search(p,data) for p in expressions):raise ValueError('La estructura de pistas o pregap del CUE no coincide.')
 names=re.findall(r'(?im)^\s*FILE\s+"([^"]+)"\s+BINARY\s*$',data)
 if len(names)!=2:raise ValueError('Se necesitan dos pistas BIN separadas.')
 return [(path.parent/n).resolve() for n in names]
def command(args,out,name):
 with (out/(name+'.stdout.log')).open('xb') as stdout,(out/(name+'.stderr.log')).open('xb') as stderr:
  subprocess.run(args,stdout=stdout,stderr=stderr,check=True)
def extract(source,dest):
 sync=b'\0'+b'\xff'*10+b'\0'
 with source.open('rb') as f,dest.open('xb') as g:
  while True:
   data=f.read(2352*4096)
   if not data:break
   if len(data)%2352:raise ValueError('Sector truncado')
   output=bytearray()
   for pos in range(0,len(data),2352):
    if data[pos:pos+12]!=sync or data[pos+15]!=1:raise ValueError('Sector MODE1/2352 inválido')
    output.extend(data[pos+16:pos+2064])
   g.write(output)
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--disc',choices=('1','2','3'),required=True);p.add_argument('--cue',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--xdelta',default='xdelta3');p.add_argument('--chdman',default='chdman');a=p.parse_args()
 c=CONFIG[a.disc]
 cue=a.cue.resolve(strict=True);track1,track2=cue_files(cue,'MODE1/2352')
 if track1.stat().st_size!=c['raw_bytes'] or sha(track1)!=c['raw_sha']:raise ValueError('La pista 1 no corresponde al disco japonés seleccionado.')
 if track2.stat().st_size!=4812192 or sha(track2)!=AUDIO_HASH:raise ValueError('La pista de audio no coincide.')
 patch=HERE/c['patch']
 if sha(patch)!=c['patch_sha']:raise ValueError('El hash del parche no coincide.')
 if not shutil.which(a.xdelta) or not shutil.which(a.chdman):raise ValueError('Instala xdelta3 y chdman, o indica sus rutas.')
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 cooked=out/'original_datos_2048.iso';print('Extrayendo sectores del original...',flush=True);extract(track1,cooked)
 if sha(cooked)!=c['cooked_sha']:raise ValueError('La pista extraída no coincide.')
 target=out/f'Policenauts_ES_v1.5_Disc{a.disc}.iso'
 command([a.xdelta,'-d','-s',str(cooked),str(patch),str(target)],out,'xdelta')
 if target.stat().st_size!=c['target_bytes'] or sha(target)!=c['target_sha']:raise ValueError('La ISO generada no coincide.')
 audio=out/'audio.bin';shutil.copyfile(track2,audio)
 if sha(audio)!=AUDIO_HASH:raise ValueError('La copia del audio no coincide.')
 cue_out=out/'disco.cue';cue_out.write_text(f'FILE "{target.name}" BINARY\n  TRACK 01 MODE1/2048\n    INDEX 01 00:00:00\nFILE "audio.bin" BINARY\n  TRACK 02 AUDIO\n    INDEX 00 00:00:00\n    INDEX 01 00:02:00\n',encoding='ascii')
 chd=out/f'Policenauts (Español) (Disc {a.disc}).chd';print('Creando y verificando el CHD...',flush=True)
 command([a.chdman,'createcd','-i',str(cue_out),'-o',str(chd)],out,'chd_create')
 command([a.chdman,'verify','-i',str(chd)],out,'chd_verify')
 check=out/'_verificacion_chd';check.mkdir();check_cue=check/'verificado.cue'
 command([a.chdman,'extractcd','-i',str(chd),'-o',str(check_cue),'-sb'],out,'chd_extract')
 v1,v2=cue_files(check_cue,'MODE1/2048')
 if sha(v1)!=c['target_sha'] or sha(v2)!=AUDIO_HASH:raise ValueError('Las pistas extraídas del CHD no coinciden.')
 manifest=dict(version='1.5',disco=a.disc,original_track1_sha256=c['raw_sha'],original_audio_sha256=AUDIO_HASH,patch_sha256=c['patch_sha'],target_iso_sha256=c['target_sha'],output_chd_sha256=sha(chd),chd_verify=True,chd_tracks_verified=True,gameplay_validation='no acreditada')
 (out/'manifiesto.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
 print('CHD creado y pistas verificadas:',chd)
if __name__=='__main__':main()
