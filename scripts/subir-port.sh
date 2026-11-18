#!/bin/sh
# Uso: ./subir-port.sh Carpeta.pak [binario]
# Sube el .pak a la consola y vuelve a dar permiso de ejecución (se pierde a veces).
PAK="$1"; BIN="${2:-}"
[ -d "$PAK" ] || { echo "No existe $PAK"; exit 1; }
NAME="$(basename "$PAK")"
adb push "$PAK" /userdata/Ports/
adb shell "cd '/userdata/Ports/$NAME' && chmod +x launch.sh ${BIN:+$BIN} && ls -l"
