# Policenauts — parche local ES v1.0 (solo disco 1)

Paquete experimental para aplicar el disco 1 español directamente al volcado japonés de Sega Saturn. No requiere instalar por separado el parche inglés.

**Versión:** 1.0 ESP. **Incluye solo el disco 1.** La imagen no se ha validado íntegramente en juego; el paquete verifica hashes, pistas y contenedor, pero esto no acredita que todas las escenas, textos y funciones estén comprobados.

## Uso en Windows

Mantén juntos el CUE japonés original y sus dos BIN. Se acepta únicamente el Track 1 `MODE1/2352` y Track 2 `AUDIO` que coincidan con estos SHA-256:

- Track 1: `956b9e06ef0e622d04aa2a1aabbebe305f06c7cefc87485d7e67cd6af3ee6938`
- Track 2: `4227a2f565934ddb8e92635c41f58eb39655231f107cba518e79220e33fd1ee2`

Ejecuta PowerShell con una carpeta de salida nueva:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\apply_patch.ps1 `
  -CuePath "D:\Policenauts Japan Disc 1\Policenauts (Japan) (Disc 1).cue" `
  -OutputDirectory "D:\Policenauts_ES_v1.0_Disc1"
```

El aplicador conserva intactos los archivos fuente. Decodifica el delta, comprueba la pista generada, copia el audio japonés, crea el CHD, ejecuta `chdman verify` y extrae las pistas para verificar sus hashes. Conserva los registros y archivos de verificación en la salida.

## Revisión incluida

La ISO cocida objetivo mide 464.152.576 bytes y su SHA-256 es `6e4510fbb70b2d03ec2ce34ece0bb3c289c05e8aead93fca38c0e37850b9a0aa`. El Track 1 raw Mode 1/2352 esperado mide 533.050.224 bytes (226.637 sectores), SHA-256 `14b56dd660a667ba291cc138317ff8e17506ebe1a42e6b62c58f117d7dbf5baf`. El audio japonés se conserva byte a byte. El delta Japón→Español mide 46.980.767 bytes, SHA-256 `207ade8d67f310e430abbea4d1956d6670bac71591ba1eb5951729f36add6784`.

La aplicación local se completó correctamente. El CHD de comprobación fue verificado y extraído; hash SHA-256 `4125f5799560203a83bbf32ab0a35e1bc9638d284ab4b5b7f04748909f4bb0fb`. No se incluye el CHD ni ninguna imagen de disco en este paquete.

## Herramientas y procedencia

`xdelta3.exe` 3.2.2 procede del release oficial [jmacd/xdelta v3.2.2](https://github.com/jmacd/xdelta/releases/tag/v3.2.2), con licencia Apache 2.0 incluida. `tools\chdman.exe` corresponde a MAME 0.289; se incluyen sus avisos de licencia. Los hashes de herramientas, entradas, salida y parche constan en `provenance.json`.

La salida es experimental y queda pendiente una partida completa y la validación en distintos dispositivos. El paquete no contiene ROM, BIN/CUE, ISO ni CHD del juego.

## Créditos de las aportaciones inglesas de base

El readme original del parche inglés acredita a Policenauts Translation Project; programación: GameZelda, FacundoARG, SaturnAR, Raizing y SkyBladeCloud; traducción: Marc Laidlaw, Raizing y cafe-alpha; gráficos: IlDucci. Esta traducción se basa parcialmente en ese trabajo.

La extracción final del Track 1 se comprobó sector a sector: sincronización y modo, EDC, ECC P y ECC Q válidos en los 226.637 sectores. Al extraer sus 2.048 bytes de datos por sector, la ISO cocida resultante reproduce exactamente el SHA-256 objetivo indicado arriba.
