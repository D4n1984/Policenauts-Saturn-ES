[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CuePath,
    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory,
    [string]$ChdmanPath
)

$ErrorActionPreference = 'Stop'
# Resolve the packaged tool after parameter binding: Windows PowerShell 5.1
# can leave $PSScriptRoot empty while evaluating a parameter default with -File.
if ([string]::IsNullOrWhiteSpace($ChdmanPath)) {
    $ChdmanPath = Join-Path $PSScriptRoot 'tools\chdman.exe'
}
$expectedInputTrack1Bytes = 524338416L
$expectedInputTrack1Sha256 = '956b9e06ef0e622d04aa2a1aabbebe305f06c7cefc87485d7e67cd6af3ee6938'
$expectedInputTrack2Bytes = 4812192L
$expectedInputTrack2Sha256 = '4227a2f565934ddb8e92635c41f58eb39655231f107cba518e79220e33fd1ee2'
$expectedOutputTrack1Bytes = 533050224L
$expectedOutputTrack1Sha256 = '14b56dd660a667ba291cc138317ff8e17506ebe1a42e6b62c58f117d7dbf5baf'
$expectedPatchSha256 = '207ade8d67f310e430abbea4d1956d6670bac71591ba1eb5951729f36add6784'
$expectedXdeltaSha256 = '732980d52f9220dc81817ccdd0c295eadce8a0048a24c2a771a73f791ac824e9'
$expectedOutputIsoSha256 = '6e4510fbb70b2d03ec2ce34ece0bb3c289c05e8aead93fca38c0e37850b9a0aa'

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-Chdman([string[]]$ChdArguments, [string]$LogName) {
    # Start-Process preserves native stderr as a log without turning progress into
    # PowerShell errors. All generated logs are kept with the output.
    $quotedArguments = ($ChdArguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $stdoutPath = Join-Path $outDir ($LogName + '.stdout.log')
    $stderrPath = Join-Path $outDir ($LogName + '.stderr.log')
    Write-Host "chdman: $LogName"
    $process = Start-Process -FilePath $chdmanFullPath -ArgumentList $quotedArguments -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if ($process.ExitCode -ne 0) {
        throw "chdman $LogName terminó con código $($process.ExitCode); se conservan la salida parcial y los registros en $outDir."
    }
}

$cueFullPath = [IO.Path]::GetFullPath($CuePath)
if (-not (Test-Path -LiteralPath $cueFullPath -PathType Leaf)) { throw "No encuentro el CUE: $cueFullPath" }
$cueText = Get-Content -LiteralPath $cueFullPath -Raw
if ($cueText -notmatch '(?im)^\s*TRACK\s+01\s+MODE1/2352\s*$') { throw 'El CUE no declara TRACK 01 MODE1/2352.' }
if ($cueText -notmatch '(?im)^\s*TRACK\s+02\s+AUDIO\s*$') { throw 'El CUE no declara TRACK 02 AUDIO.' }
if ($cueText -notmatch '(?im)^\s*INDEX\s+01\s+00:00:00\s*$') { throw 'El CUE no tiene INDEX 01 00:00:00 requerido para Track 1.' }
if ($cueText -notmatch '(?im)^\s*INDEX\s+00\s+00:00:00\s*$' -or $cueText -notmatch '(?im)^\s*INDEX\s+01\s+00:02:00\s*$') { throw 'El pregap/audio de Track 2 no coincide con el CUE japonés esperado.' }
$fileMatches = [regex]::Matches($cueText, '(?im)^\s*FILE\s+"(?<name>[^"]+)"\s+BINARY\s*$')
if ($fileMatches.Count -ne 2) { throw 'Se requiere el CUE japonés de dos BIN separados (Track 1 y Track 2).' }
$cueDir = [IO.Path]::GetDirectoryName($cueFullPath)
$track1 = [IO.Path]::GetFullPath([IO.Path]::Combine($cueDir, $fileMatches[0].Groups['name'].Value))
$track2 = [IO.Path]::GetFullPath([IO.Path]::Combine($cueDir, $fileMatches[1].Groups['name'].Value))
if (-not (Test-Path -LiteralPath $track1 -PathType Leaf)) { throw "No encuentro el BIN de Track 1: $track1" }
if (-not (Test-Path -LiteralPath $track2 -PathType Leaf)) { throw "No encuentro el BIN de Track 2: $track2" }
if ((Get-Item -LiteralPath $track1).Length -ne $expectedInputTrack1Bytes) { throw 'Tamaño inesperado para el BIN japonés de Track 1.' }
if ((Get-Sha256 $track1) -ne $expectedInputTrack1Sha256) { throw 'SHA256 incorrecto para el BIN japonés de Track 1; no se aplicó el parche.' }
if ((Get-Item -LiteralPath $track2).Length -ne $expectedInputTrack2Bytes) { throw 'Tamaño inesperado para el BIN japonés de Track 2.' }
if ((Get-Sha256 $track2) -ne $expectedInputTrack2Sha256) { throw 'SHA256 incorrecto para el audio japonés; no se aplicó el parche.' }

$patchPath = Join-Path $PSScriptRoot 'disc1_jp_to_es_v1_0.vcdiff'
$xdeltaPath = Join-Path $PSScriptRoot 'xdelta3.exe'
if ((Get-Sha256 $patchPath) -ne $expectedPatchSha256) { throw 'El archivo VCDIFF no coincide con su hash esperado.' }
if (-not (Test-Path -LiteralPath $xdeltaPath -PathType Leaf)) { throw 'Falta xdelta3.exe junto al aplicador.' }
if ((Get-Sha256 $xdeltaPath) -ne $expectedXdeltaSha256) { throw 'xdelta3.exe no coincide con el binario oficial fijado.' }
$chdmanFullPath = [IO.Path]::GetFullPath($ChdmanPath)
if (-not (Test-Path -LiteralPath $chdmanFullPath -PathType Leaf)) { throw "Falta chdman.exe: $chdmanFullPath. Usa -ChdmanPath para indicar otra instalación." }
$outDir = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $outDir) { throw "La carpeta de salida ya existe; elige una carpeta nueva para no sobrescribir archivos: $outDir" }

[void](New-Item -ItemType Directory -Path $outDir)
$outTrack1Name = 'Policenauts_ES_v1.0_Disc1_Track1.bin'
$outTrack2Name = 'Policenauts_ES_v1.0_Disc1_Track2.bin'
$outCueName = 'Policenauts_ES_v1.0_Disc1.cue'
$outTrack1 = Join-Path $outDir $outTrack1Name
$outTrack2 = Join-Path $outDir $outTrack2Name
$outCue = Join-Path $outDir $outCueName
& $xdeltaPath -d -s $track1 $patchPath $outTrack1
if ($LASTEXITCODE -ne 0) { throw "xdelta3 terminó con código $LASTEXITCODE; se conserva la salida parcial para inspección." }
if ((Get-Item -LiteralPath $outTrack1).Length -ne $expectedOutputTrack1Bytes) { throw 'Tamaño inesperado en Track 1 generado.' }
if ((Get-Sha256 $outTrack1) -ne $expectedOutputTrack1Sha256) { throw 'SHA256 inesperado en Track 1 generado.' }
Copy-Item -LiteralPath $track2 -Destination $outTrack2
if ((Get-Sha256 $outTrack2) -ne $expectedInputTrack2Sha256) { throw 'El audio copiado no coincide con el BIN japonés original.' }

@"
FILE "$outTrack1Name" BINARY
  TRACK 01 MODE1/2352
    INDEX 01 00:00:00
FILE "$outTrack2Name" BINARY
  TRACK 02 AUDIO
    INDEX 00 00:00:00
    INDEX 01 00:02:00
"@ | Set-Content -LiteralPath $outCue -Encoding ASCII

$outChdName = 'Policenauts_ES_v1.0_Disc1.chd'
$outChd = Join-Path $outDir $outChdName
Write-Host 'Creando CHD y comprobando su integridad...'
Invoke-Chdman -ChdArguments @('createcd', '-i', $outCue, '-o', $outChd) -LogName 'chd_create'
Invoke-Chdman -ChdArguments @('verify', '-i', $outChd) -LogName 'chd_verify'
Invoke-Chdman -ChdArguments @('info', '-i', $outChd) -LogName 'chd_info'

# A successful container check alone does not establish that the source tracks
# survived conversion. Extract each track and compare it byte for byte by SHA256.
$roundtripDir = Join-Path $outDir '_chd_roundtrip_verification'
[void](New-Item -ItemType Directory -Path $roundtripDir)
$roundtripCue = Join-Path $roundtripDir 'roundtrip.cue'
Invoke-Chdman -ChdArguments @('extractcd', '-i', $outChd, '-o', $roundtripCue, '-sb') -LogName 'chd_extract'
$roundtripText = Get-Content -LiteralPath $roundtripCue -Raw
$roundtripFiles = [regex]::Matches($roundtripText, '(?im)^\s*FILE\s+"(?<name>[^"]+)"\s+BINARY\s*$')
if ($roundtripFiles.Count -ne 2) { throw 'La extracción CHD no contiene las dos pistas esperadas; se conserva para inspección.' }
if ($roundtripText -notmatch '(?im)^\s*TRACK\s+01\s+MODE1/2352\s*$' -or $roundtripText -notmatch '(?im)^\s*TRACK\s+02\s+AUDIO\s*$' -or $roundtripText -notmatch '(?im)^\s*INDEX\s+00\s+00:00:00\s*$' -or $roundtripText -notmatch '(?im)^\s*INDEX\s+01\s+00:02:00\s*$') { throw 'Las pistas o el pregap extraídos del CHD no coinciden con la estructura esperada.' }
$roundtripTrack1 = Join-Path $roundtripDir $roundtripFiles[0].Groups['name'].Value
$roundtripTrack2 = Join-Path $roundtripDir $roundtripFiles[1].Groups['name'].Value
if ((Get-Sha256 $roundtripTrack1) -ne $expectedOutputTrack1Sha256 -or (Get-Sha256 $roundtripTrack2) -ne $expectedInputTrack2Sha256) { throw 'El contenido extraído del CHD no reproduce exactamente los BIN generados; se conservan todos los archivos.' }

$manifest = [ordered]@{
    state = 'EXPERIMENTAL_ES_v1_0_RUNTIME_VALIDATION_REQUIRED'
    source_cue = [IO.Path]::GetFileName($cueFullPath)
    source_track1_sha256 = $expectedInputTrack1Sha256
    source_track2_sha256 = $expectedInputTrack2Sha256
    patch_sha256 = $expectedPatchSha256
    target_cooked_iso_sha256 = $expectedOutputIsoSha256
    output_track1_sha256 = Get-Sha256 $outTrack1
    output_track2_sha256 = Get-Sha256 $outTrack2
    output_track1_bytes = (Get-Item -LiteralPath $outTrack1).Length
    output_audio_bytes = (Get-Item -LiteralPath $outTrack2).Length
    output_cue = $outCueName
    output_chd = $outChdName
    output_chd_sha256 = Get-Sha256 $outChd
    output_chd_bytes = (Get-Item -LiteralPath $outChd).Length
    chdman_sha256 = Get-Sha256 $chdmanFullPath
    chd_integrity_verified = $true
    chd_roundtrip_track_hashes_verified = $true
    chd_roundtrip_directory = '_chd_roundtrip_verification'
    audio_preserved_from_japanese_disc = $true
    gameplay_validation = 'Not established by this patch process.'
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir 'patch_manifest.json') -Encoding UTF8
Write-Host "Parche aplicado y hashes comprobados. BIN/CUE: $outCue"
Write-Host "CHD creado, verificado y extraído sin cambios en las pistas: $outChd"
Write-Host "CHD SHA256: $($manifest.output_chd_sha256)"
Write-Host "Track 1 SHA256: $expectedOutputTrack1Sha256"
Write-Host "Audio japonés preservado; SHA256: $expectedInputTrack2Sha256"



