# Policenauts para Sega Saturn — parche español 1.5

Este paquete traduce los tres discos de la edición japonesa de *Policenauts* para Sega Saturn. No es necesario instalar por separado el parche inglés. Se necesita una copia propia de cada disco; los archivos del juego no están incluidos.

Las correcciones recientes y los discos 2 y 3 requieren más pruebas en juego. Los cambios de disco, los enlaces del glosario, la sincronía y algunas escenas siguen pendientes de validación. Si encuentras errores, indícanos el disco, la escena y la frase.

El menú muestra `Ver 1.5 ESP` y el nombre `D4n1984`.

En la demostración inicial, un subtítulo puede solaparse con «2040 A.D.» y algunos textos aparecen solo parcialmente; ambos comportamientos también se han observado en una prueba equivalente de la referencia inglesa.

## Requisitos

- La copia japonesa de cada disco que quieras parchear, extraída en un CUE y dos BIN, en la misma carpeta.
- Una carpeta de salida nueva para cada disco y espacio para los archivos de trabajo y verificación.
- Un emulador o dispositivo compatible con imágenes CHD y cambio de disco.
- En Windows, PowerShell. En Linux o macOS, Python 3, `xdelta3` y `chdman` instalados desde el gestor de paquetes del sistema.

El CUE original debe contener dos pistas separadas, `MODE1/2352` y `AUDIO`; la pista de audio debe incluir `INDEX 00 00:00:00` e `INDEX 01 00:02:00`. El aplicador comprueba estos SHA-256:

| Pista japonesa | SHA-256 |
| --- | --- |
| Disco 1, pista 1 | `956b9e06ef0e622d04aa2a1aabbebe305f06c7cefc87485d7e67cd6af3ee6938` |
| Disco 2, pista 1 | `053d1b3111992d826d8c5db0feb6684e82fc3e8cc5f0f68d626366652ccaa9fc` |
| Disco 3, pista 1 | `bbe498ebb05d1657faf1d820d8ba24c67f112f335323a4c0fee7b89905c96a89` |
| Audio de los tres discos | `4227a2f565934ddb8e92635c41f58eb39655231f107cba518e79220e33fd1ee2` |

## Aplicación en Windows

Descomprime el paquete y abre PowerShell en la carpeta que contiene `apply_patch.ps1`. Ejecuta el comando correspondiente, cambiando las rutas por las tuyas:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\apply_patch.ps1 `
  -Disc 1 -CuePath "D:\Policenauts Japan Disc 1\Policenauts (Japan) (Disc 1).cue" `
  -OutputDirectory "D:\Policenauts_ES_Disc1"
```

Para los discos 2 y 3, usa `-Disc 2` o `-Disc 3`, la ruta al CUE correspondiente y otra carpeta de salida nueva.

## Aplicación en Linux y macOS

Instala Python 3, `xdelta3` y `chdman`. Descomprime el paquete y abre un terminal en esa carpeta. Ejecuta:

```sh
python3 apply_patch.py --disc 1 \
  --cue "/ruta/al/disco/Policenauts (Japan) (Disc 1).cue" \
  --output "/ruta/a/Policenauts_ES_Disc1"
```

Para los discos 2 y 3, cambia `--disc 1` por `--disc 2` o `--disc 3`, indica su CUE y una carpeta de salida diferente. Si las herramientas no están en `PATH`, añade `--xdelta /ruta/a/xdelta3` y `--chdman /ruta/a/chdman`. El aplicador de Python se ha probado con los ejecutables de Windows; falta probarlo en Linux y macOS.

## Resultado

El aplicador comprueba los originales, extrae los sectores de datos, aplica el parche, crea un CHD y verifica las dos pistas extrayéndolas de nuevo. Los originales no se modifican. Los resultados se llaman `Policenauts (Español) (Disc 1).chd`, `Policenauts (Español) (Disc 2).chd` y `Policenauts (Español) (Disc 3).chd`; también se conservan los archivos intermedios y de verificación.

Configura los tres discos en tu emulador según sus instrucciones para poder cambiarlos cuando el juego lo pida. Conserva tus partidas y usa preferentemente una partida guardada desde el propio juego al cambiar de versión; no se garantiza la compatibilidad de los estados rápidos.

## Créditos

Esta traducción se apoya en el trabajo de Policenauts Translation Project. Su parche acredita a GameZelda, FacundoARG, SaturnAR, Raizing y SkyBladeCloud en programación; a Marc Laidlaw, Raizing y cafe-alpha en traducción; y a IlDucci en gráficos.

El paquete incluye xdelta3 3.2.2 y chdman de MAME 0.289 para Windows, junto con sus avisos de licencia. *Policenauts* es propiedad de Konami; este proyecto de aficionados no está vinculado a la compañía.
