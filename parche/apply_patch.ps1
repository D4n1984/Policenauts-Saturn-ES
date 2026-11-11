[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('1','2','3')][string]$Disc,
    [Parameter(Mandatory=$true)][string]$CuePath,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$ChdmanPath
)
$ErrorActionPreference='Stop'
$audioHash='4227a2f565934ddb8e92635c41f58eb39655231f107cba518e79220e33fd1ee2'
$xdeltaHash='732980d52f9220dc81817ccdd0c295eadce8a0048a24c2a771a73f791ac824e9'
$configs=@{
 '1'=@{ RawSize=524338416L; RawHash='956b9e06ef0e622d04aa2a1aabbebe305f06c7cefc87485d7e67cd6af3ee6938'; CookedHash='516ad090242df694becad079c1f187294df7b1c3259ef2b5b9405217cf70fb56'; Patch='disc1_jp_to_es_v1_3.vcdiff'; PatchHash='59ff2b48fa107c2a2e83ac30ea5516fb3ed123a6ba50798a3cb818cd998ac806'; TargetSize=469903360L; TargetHash='197f65009239fba7a7d682773c85f9411f440edc88170ce5efcedea838aa6303' }
 '2'=@{ RawSize=560211120L; RawHash='053d1b3111992d826d8c5db0feb6684e82fc3e8cc5f0f68d626366652ccaa9fc'; CookedHash='1669ad792a25bade3709a19269c1a104d62e45de4f7849478f5950b17ec86c4b'; Patch='disc2_jp_to_es_v1_3.vcdiff'; PatchHash='2f7b2d862695c3ba2f0abc125b6aac6b6cbe119ab0e8b670950c43cc075e32e4'; TargetSize=494077952L; TargetHash='1b5abe75c6ca11706d378c725ea88cdc32d68cace57288b4be5caa498daef1e8' }
 '3'=@{ RawSize=513533328L; RawHash='bbe498ebb05d1657faf1d820d8ba24c67f112f335323a4c0fee7b89905c96a89'; CookedHash='8e0eb8a914e541318a6449f4512e9dbea45051dbae909556808adb2db3c6347f'; Patch='disc3_jp_to_es_v1_3.vcdiff'; PatchHash='55e41f679a948b25955ef8bc3dc22cfc75daf08d7f6237adea40946ef73a684a'; TargetSize=453435392L; TargetHash='fea82d152950336f1abdef9df04c5541b220282de6879e8a117169bb15849903' }
}
$config=$configs[$Disc]
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
if ([string]::IsNullOrWhiteSpace($ChdmanPath)) { $ChdmanPath=Join-Path $PSScriptRoot 'tools\chdman.exe' }
$xdelta=Join-Path $PSScriptRoot 'xdelta3.exe'
$patch=Join-Path $PSScriptRoot $config.Patch
$chdman=[IO.Path]::GetFullPath($ChdmanPath)
if (-not (Test-Path -LiteralPath $xdelta -PathType Leaf) -or (Hash $xdelta) -ne $xdeltaHash) { throw 'Falta xdelta3 o su hash no coincide.' }
if (-not (Test-Path -LiteralPath $patch -PathType Leaf) -or (Hash $patch) -ne $config.PatchHash) { throw 'Falta el parche del disco seleccionado o su hash no coincide.' }
if (-not (Test-Path -LiteralPath $chdman -PathType Leaf)) { throw 'No se encuentra chdman. Usa -ChdmanPath para indicar su ubicación.' }
$cue=[IO.Path]::GetFullPath($CuePath)
if (-not (Test-Path -LiteralPath $cue -PathType Leaf)) { throw 'No se encuentra el CUE.' }
$content=Get-Content -LiteralPath $cue -Raw
if ($content -notmatch '(?im)^\s*TRACK\s+01\s+MODE1/2352\s*$' -or $content -notmatch '(?im)^\s*TRACK\s+02\s+AUDIO\s*$' -or $content -notmatch '(?im)^\s*INDEX\s+01\s+00:00:00\s*$' -or $content -notmatch '(?im)^\s*INDEX\s+00\s+00:00:00\s*$' -or $content -notmatch '(?im)^\s*INDEX\s+01\s+00:02:00\s*$') { throw 'La estructura de pistas o pregap del CUE no coincide con el original esperado.' }
$matches=[regex]::Matches($content,'(?im)^\s*FILE\s+"(?<name>[^"]+)"\s+BINARY\s*$')
if ($matches.Count -ne 2) { throw 'Se necesita el CUE japonés con dos BIN separados.' }
$cueDir=[IO.Path]::GetDirectoryName($cue)
$track1=[IO.Path]::GetFullPath([IO.Path]::Combine($cueDir,$matches[0].Groups['name'].Value))
$track2=[IO.Path]::GetFullPath([IO.Path]::Combine($cueDir,$matches[1].Groups['name'].Value))
if (-not (Test-Path -LiteralPath $track1 -PathType Leaf) -or -not (Test-Path -LiteralPath $track2 -PathType Leaf)) { throw 'No se encuentran las dos pistas indicadas por el CUE.' }
if ((Get-Item -LiteralPath $track1).Length -ne $config.RawSize -or (Hash $track1) -ne $config.RawHash) { throw 'La pista 1 no corresponde al disco japonés seleccionado.' }
if ((Get-Item -LiteralPath $track2).Length -ne 4812192 -or (Hash $track2) -ne $audioHash) { throw 'La pista de audio no corresponde a la edición esperada.' }
$out=[IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $out) { throw 'La carpeta de salida ya existe; elige otra nueva.' }
[void](New-Item -ItemType Directory -Path $out)
Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class PolicenautsSectorExtractorV13 {
 public static void Run(string src,string dst) {
  const int rawSize=2352, userSize=2048, sectors=4096;
  byte[] input=new byte[rawSize*sectors], output=new byte[userSize*sectors];
  using (var r=new FileStream(src,FileMode.Open,FileAccess.Read,FileShare.Read))
  using (var w=new FileStream(dst,FileMode.CreateNew,FileAccess.Write,FileShare.None)) {
   long number=0;
   while(true) {
    int total=0,n;
    while(total<input.Length && (n=r.Read(input,total,input.Length-total))>0) total+=n;
    if(total==0)break;
    if(total%rawSize!=0)throw new InvalidDataException("Sector truncado");
    int count=total/rawSize;
    for(int i=0;i<count;i++,number++) {
     int p=i*rawSize;
     if(input[p]!=0 || input[p+11]!=0 || input[p+15]!=1)throw new InvalidDataException("Sector MODE1 invalido: "+number);
     for(int j=1;j<=10;j++)if(input[p+j]!=255)throw new InvalidDataException("Sync invalido: "+number);
     Buffer.BlockCopy(input,p+16,output,i*userSize,userSize);
    }
    w.Write(output,0,count*userSize);
   }
  }
 }
}
'@
$cooked=Join-Path $out 'original_datos_2048.iso'
Write-Host 'Comprobando y extrayendo sectores del disco japonés...'
[PolicenautsSectorExtractorV13]::Run($track1,$cooked)
if ((Hash $cooked) -ne $config.CookedHash) { throw 'La extracción de la pista no coincide con el hash esperado.' }
$target=Join-Path $out ("Policenauts_ES_v1.3_Disc{0}.iso" -f $Disc)
& $xdelta -d -s $cooked $patch $target
if ($LASTEXITCODE -ne 0) { throw 'xdelta no pudo aplicar el parche; se conserva la salida parcial.' }
if ((Get-Item -LiteralPath $target).Length -ne $config.TargetSize -or (Hash $target) -ne $config.TargetHash) { throw 'Los datos generados no coinciden con el hash esperado.' }
$audio=Join-Path $out 'audio.bin'; Copy-Item -LiteralPath $track2 -Destination $audio
if ((Hash $audio) -ne $audioHash) { throw 'La copia de audio no coincide.' }
$cueOut=Join-Path $out 'disco.cue'
@"
FILE "$([IO.Path]::GetFileName($target))" BINARY
  TRACK 01 MODE1/2048
    INDEX 01 00:00:00
FILE "audio.bin" BINARY
  TRACK 02 AUDIO
    INDEX 00 00:00:00
    INDEX 01 00:02:00
"@ | Set-Content -LiteralPath $cueOut -Encoding ASCII
$chd=Join-Path $out ("Policenauts_ES_v1.3_Disc{0}.chd" -f $Disc)
function RunChd([string[]]$NativeArgs,[string]$Name) {
 $quoted=($NativeArgs | ForEach-Object { '"'+$_+'"' }) -join ' '
 $process=Start-Process -FilePath $chdman -ArgumentList $quoted -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $out "$Name.stdout.log") -RedirectStandardError (Join-Path $out "$Name.stderr.log")
 if ($process.ExitCode -ne 0) { throw "chdman $Name terminó con error; consulta los registros en $out" }
}
RunChd @('createcd','-i',$cueOut,'-o',$chd) 'chd_create'
RunChd @('verify','-i',$chd) 'chd_verify'
$verify=Join-Path $out '_verificacion_chd';[void](New-Item -ItemType Directory -Path $verify)
$verifyCue=Join-Path $verify 'verificado.cue';RunChd @('extractcd','-i',$chd,'-o',$verifyCue,'-sb') 'chd_extract'
$verifyContent=Get-Content -LiteralPath $verifyCue -Raw
$verifyFiles=[regex]::Matches($verifyContent,'(?im)^\s*FILE\s+"(?<name>[^"]+)"\s+BINARY\s*$')
if ($verifyFiles.Count -ne 2 -or $verifyContent -notmatch '(?im)^\s*TRACK\s+01\s+MODE1/2048\s*$' -or $verifyContent -notmatch '(?im)^\s*TRACK\s+02\s+AUDIO\s*$' -or $verifyContent -notmatch '(?im)^\s*INDEX\s+00\s+00:00:00\s*$' -or $verifyContent -notmatch '(?im)^\s*INDEX\s+01\s+00:02:00\s*$') { throw 'La estructura del CHD extraído no coincide.' }
$v1=Join-Path $verify $verifyFiles[0].Groups['name'].Value;$v2=Join-Path $verify $verifyFiles[1].Groups['name'].Value
if ((Hash $v1) -ne $config.TargetHash -or (Hash $v2) -ne $audioHash) { throw 'Las pistas extraídas del CHD no coinciden.' }
$manifest=[ordered]@{ version='1.3'; disco=$Disc; original_track1_sha256=$config.RawHash; original_audio_sha256=$audioHash; patch_sha256=$config.PatchHash; target_iso_sha256=$config.TargetHash; output_chd_sha256=(Hash $chd); chd_verify=$true; chd_tracks_verified=$true; gameplay_validation='no acreditada' }
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'manifiesto.json') -Encoding UTF8
Write-Host "CHD creado y pistas verificadas: $chd"
