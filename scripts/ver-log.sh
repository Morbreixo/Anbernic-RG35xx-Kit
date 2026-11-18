#!/bin/sh
# Uso: ./ver-log.sh <juego>      -> muestra /tmp/<juego>.log de la consola
# Los logs van siempre a /tmp (RAM) para no escribir en la SD; se pierden al apagar.
adb shell "tail -60 '/tmp/${1:-juego}.log'"
