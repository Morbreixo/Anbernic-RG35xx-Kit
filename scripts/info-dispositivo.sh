#!/bin/sh
# Ejecutar en el PC con la consola enchufada: ./info-dispositivo.sh > info.txt
# Saca lo necesario para comprobar que la consola no ha cambiado (firmware nuevo, etc.)
adb shell '
echo "== uname";      uname -a
echo "== os-release"; cat /etc/os-release
echo "== cpu";        grep -iE "model name|Features|Hardware" /proc/cpuinfo | sort -u
echo "== memoria";    grep -E "MemTotal|MemFree" /proc/meminfo
echo "== glibc";      strings /lib/libc.so.6 2>/dev/null | grep -m1 "GNU C Library" || ls -l /lib/libc.so.6
echo "== SDL";        ls -l /usr/lib/libSDL*.so* 2>/dev/null; readlink -f /usr/lib/libSDL-1.2.so.0 /usr/lib/libSDL2-2.0.so.0
echo "== gptokeyb";   which gptokeyb evmapy overclock.elf
echo "== discos";     df -h
echo "== ports";      ls /userdata/Ports
echo "== HOME";       echo $HOME; echo CPU_SPEED_GAME=$CPU_SPEED_GAME
'
