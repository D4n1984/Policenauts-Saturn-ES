# Aplicador verificable para Policenauts Saturn

Componente de infraestructura en desarrollo. **No incluye un parche español, no traduce un disco por sí solo y no es una versión jugable de Policenauts.** No contiene imágenes de discos, guiones, fuentes, parches ni código de otros proyectos.

El trabajo existente utiliza como referencia la pista ISO de la edición inglesa Saturn 1.0.1, SHA-1 `19538c0ec199c41fabd5e3a26edf9a6d43888ea0`. Esa referencia no identifica un disco japonés original ni sirve para prometer que este aplicador admite uno. Los insertadores existentes y las imágenes españolas de diagnóstico son experimentales. No se ha generado un delta a partir de ellas.

Para ofrecer un parche que parta del disco original faltan: identificar exactamente edición, revisión, pista y formato; registrar tamaño y SHA-256; resolver la cadena de transformación desde esa base; revisar procedencia y permisos de las contribuciones de terceros; completar traducción e inserción; y probar los discos y rutas de juego. El hash de una salida demuestra identidad binaria, no corrección lingüística, cobertura ni jugabilidad.

## Requisitos y alcance

- Python 3.10 o posterior, sin dependencias Python adicionales.
- Ejecutable local de xdelta3, facilitado aparte. No se descarga ni se distribuye aquí.
- Un manifiesto y un delta propios, junto con la base exacta indicada por el manifiesto.

Se procesa **un archivo por manifiesto**. No extrae CHD, no reconstruye pistas BIN/CUE, no genera M3U, no aplica ECC/EDC ni valida estructuras Saturn. El formato de entrada será exactamente el documentado en cada futura publicación. Un CHD o BIN no equivale a una pista ISO de 2048 bytes; no se debe cambiar simplemente la extensión. No incluye soporte ni versión PlayStation.

## Uso cuando exista un candidato de parche

El archivo del parche debe residir junto al manifiesto. Los nombres de los ejemplos son ilustrativos: estos archivos de juego no se incluyen.

```powershell
python patcher.py check --manifest .\manifest.json --source "D:\Mis discos\base_exacta.iso"
python patcher.py apply --manifest .\manifest.json --source "D:\Mis discos\base_exacta.iso" --output-dir "D:\Resultados\prueba_nueva" --xdelta "C:\Herramientas\xdelta3.exe" --allow-experimental
```

La carpeta de salida **no debe existir**; su carpeta padre debe existir. Primero se comprueban tamaño y SHA-256 de la base y del delta. xdelta3 escribe `resultado.partial` dentro de la carpeta nueva. Tras ejecutarlo, se comprueban otra vez base, delta y manifiesto para detectar cambios durante la operación. Solo tras verificar también el tamaño y SHA-256 esperado de la salida se renombra al nombre final y se crea `VERIFICADO.json`. Una salida experimental conserva ese estado. El programa no acepta rutas externas para el delta, no ejecuta comandos de shell y no modifica los archivos de entrada.

Si la ejecución falla después de crear la carpeta, conserva los archivos y `FALLO.json`; una interrupción abrupta del proceso puede impedir escribir ese diagnóstico. No se borra nada automáticamente. No usar un resultado sin `VERIFICADO.json`, ni tratar un resultado experimental como publicación aprobada. El manifiesto no está firmado: sus hashes no sustituyen la confianza en quien lo distribuye. Usar únicamente deltas y ejecutables de procedencia verificada.

## Preparar un manifiesto para un candidato propio

El autor genera el delta en su entorno, por ejemplo con `xdelta3 -e -s base.iso traducida.iso traduccion.xdelta`, manteniendo los discos fuera de esta carpeta. Este comando todavía no se ha ejecutado con discos del proyecto. Después puede describir esos tres archivos:

```powershell
python patcher.py make-manifest --source "D:\Privado\base.iso" --target "D:\Privado\traducida.iso" --patch .\traduccion.xdelta --manifest .\manifest.json --base-description "Edicion, revision y formato exactos, pendientes de validar" --label "Candidato de prueba, no aprobado"
```

La herramienta valida todos los campos en memoria antes de crear exclusivamente un manifiesto nuevo con estado `experimental`. Comprobarlo aplicando el delta desde la base exacta y comparando la salida con el candidato. La promoción editorial a `release` es una revisión explícita del manifiesto y exige evidencias independientes de contenido, procedencia y pruebas de juego. No se automatiza ni se deduce de pasar las pruebas del aplicador.

## Pruebas

```powershell
$env:XDELTA3 = "C:\Herramientas\xdelta3.exe"
python -B -m unittest -v test_patcher
```

Las pruebas crean exclusivamente datos sintéticos en una carpeta temporal nueva, que se muestra y se conserva sin limpieza. Comprueban la reconstrucción real mediante xdelta3, el rechazo de base o delta incorrectos, salida con hash inesperado, fallo del decodificador, claves repetidas, rutas externas, carpetas ya existentes y autorización explícita de candidatos experimentales. No prueban la traducción ni imágenes Saturn.

## Antes de publicar

Publicar este código solo permite compartir la infraestructura. Una distribución de la traducción requerirá además delta propio validado, manifiesto de la base exacta, instrucciones de extracción y aplicación, créditos, permisos y licencias correspondientes, y resultados de pruebas. Excluir imágenes, CSV de guion y herramientas ajenas. No se asigna aquí una licencia ni se presupone permiso para redistribuir aportaciones de otros proyectos.

