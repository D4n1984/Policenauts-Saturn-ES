# Policenauts para Sega Saturn — instrucciones del parche

Este parche experimental traduce al español el **disco 1** de la edición japonesa de *Policenauts* para Sega Saturn. Los discos 2 y 3 no están incluidos. No es necesario instalar por separado el parche inglés.

## Requisitos

- Windows con PowerShell, o Linux/macOS con `xdelta3`, `chdman` y Python 3 instalados.
- Una copia propia del disco 1 japonés, extraída en un CUE y dos BIN situados en la misma carpeta.
- Una carpeta de salida que todavía no exista y espacio suficiente para la imagen y los archivos de comprobación.
- Un emulador o dispositivo compatible con imágenes CHD de Sega Saturn.

El CUE debe indicar `MODE1/2352` para la pista 1 y `AUDIO` para la pista 2, con `INDEX 00 00:00:00` e `INDEX 01 00:02:00` para esta última. El aplicador acepta la edición cuyos BIN tienen estos SHA-256:

| Archivo | SHA-256 |
| --- | --- |
| Pista 1 | `956b9e06ef0e622d04aa2a1aabbebe305f06c7cefc87485d7e67cd6af3ee6938` |
| Pista 2 | `4227a2f565934ddb8e92635c41f58eb39655231f107cba518e79220e33fd1ee2` |

## Aplicación en Windows

1. Descomprime el paquete y abre PowerShell en la carpeta que contiene `apply_patch.ps1`.
2. Ejecuta el siguiente comando, sustituyendo las rutas por las de tu CUE y tu carpeta de salida:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\apply_patch.ps1 `
  -CuePath "D:\Policenauts Japan Disc 1\Policenauts (Japan) (Disc 1).cue" `
  -OutputDirectory "D:\Policenauts_ES_Disc1"
```

La carpeta de salida debe ser nueva. El aplicador comprueba los archivos originales, aplica el parche y crea un CHD. Después verifica el CHD y compara sus dos pistas con los archivos generados. Los originales no se modifican.

## Aplicación en Linux y macOS

Instala las versiones nativas de `xdelta3`, `chdman` y Python 3 mediante el gestor de paquetes de tu sistema. Los ejecutables incluidos en el ZIP son para Windows. Este procedimiento manual todavía no se ha probado en Linux ni en macOS.

Descomprime el paquete y abre un terminal en la carpeta donde está `disc1_jp_to_es_v1_0.vcdiff`. Sustituye las tres rutas del ejemplo por los dos BIN indicados en tu CUE y una carpeta de salida que no exista. Comprueba que el CUE tenga la estructura indicada en los requisitos. Ejecuta el bloque completo:

```sh
TRACK1="/ruta/al/disco/Track 1.bin"
TRACK2="/ruta/al/disco/Track 2.bin"
SALIDA="/ruta/a/Policenauts_ES_Disc1"

set -eu
hash() { python3 -c 'import hashlib,sys; f=open(sys.argv[1],"rb"); h=hashlib.sha256(); [h.update(b) for b in iter(lambda:f.read(1048576),b"")]; print(h.hexdigest())' "$1"; }
[ "$(hash "$TRACK1")" = 956b9e06ef0e622d04aa2a1aabbebe305f06c7cefc87485d7e67cd6af3ee6938 ]
[ "$(hash "$TRACK2")" = 4227a2f565934ddb8e92635c41f58eb39655231f107cba518e79220e33fd1ee2 ]
[ "$(hash disc1_jp_to_es_v1_0.vcdiff)" = 207ade8d67f310e430abbea4d1956d6670bac71591ba1eb5951729f36add6784 ]
mkdir "$SALIDA"
xdelta3 -d -s "$TRACK1" disc1_jp_to_es_v1_0.vcdiff "$SALIDA/track1.bin"
[ "$(hash "$SALIDA/track1.bin")" = 14b56dd660a667ba291cc138317ff8e17506ebe1a42e6b62c58f117d7dbf5baf ]
cp "$TRACK2" "$SALIDA/track2.bin"
[ "$(hash "$SALIDA/track2.bin")" = 4227a2f565934ddb8e92635c41f58eb39655231f107cba518e79220e33fd1ee2 ]
cat > "$SALIDA/disco.cue" <<'CUE'
FILE "track1.bin" BINARY
  TRACK 01 MODE1/2352
    INDEX 01 00:00:00
FILE "track2.bin" BINARY
  TRACK 02 AUDIO
    INDEX 00 00:00:00
    INDEX 01 00:02:00
CUE
chdman createcd -i "$SALIDA/disco.cue" -o "$SALIDA/Policenauts_ES_v1.0_Disc1.chd"
chdman verify -i "$SALIDA/Policenauts_ES_v1.0_Disc1.chd"
```

Si una comprobación falla, el bloque se detiene; revisa las rutas y los hashes. Los originales permanecen intactos y cualquier salida parcial se conserva para inspección. A diferencia del aplicador de Windows, este procedimiento no extrae y compara de nuevo las pistas del CHD.

## Resultado

Abre `Policenauts_ES_v1.0_Disc1.chd` desde tu emulador o dispositivo. La carpeta de salida también contiene el CUE, los BIN, un manifiesto y los archivos utilizados para verificar las pistas.

La traducción no se ha comprobado mediante una partida completa. Conserva tus partidas y, al cambiar de versión, usa preferentemente una partida guardada desde el propio juego: la compatibilidad de los estados rápidos del emulador no está garantizada.

## Créditos y herramientas

La traducción se apoya en el trabajo de Policenauts Translation Project. El parche inglés acredita a GameZelda, FacundoARG, SaturnAR, Raizing y SkyBladeCloud en programación; a Marc Laidlaw, Raizing y cafe-alpha en traducción; y a IlDucci en gráficos.

El paquete incluye [xdelta3 3.2.2](https://github.com/jmacd/xdelta/releases/tag/v3.2.2) y `chdman` de [MAME 0.289](https://github.com/mamedev/mame/tree/mame0289), junto con sus avisos de licencia. Los hashes técnicos del paquete figuran en `provenance.json`.
