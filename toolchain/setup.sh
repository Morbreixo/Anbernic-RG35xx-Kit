#!/bin/sh
# Prepara el compilador cruzado (zig 0.13 desde PyPI) en una máquina Linux x86_64.
# No necesita root. Probado en Ubuntu 24.04.
set -e
python3 -m pip install --user --break-system-packages "ziglang==0.13.0" 2>/dev/null || python3 -m pip install --break-system-packages "ziglang==0.13.0"
python3 -m ziglang version
command -v cmake >/dev/null || echo "AVISO: falta cmake (apt install cmake ninja-build)"
command -v ninja >/dev/null || echo "AVISO: falta ninja (apt install ninja-build)"
echo "Listo. Prueba:  $(dirname "$0")/zcc -o hola hola.c && file hola"
