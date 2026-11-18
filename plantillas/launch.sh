#!/bin/sh
# Plantilla de lanzador para MiaUI. Va en /userdata/Ports/<Nombre>.pak/launch.sh
# Cambia JUEGO y los argumentos de la última línea.

# para entrar en la carpeta.pak
GAMEDIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "$GAMEDIR"

JUEGO=juego          # binario dentro del .pak

## Juegos de ratón: el mando lo traduce gptokeyb (ver controles.gptk)
export SDL_JOYSTICK_DISABLE=1
export SDL_NOMOUSE=0

## Juegos SDL2 con mando nativo: en vez de lo anterior
# export SDL_GAMECONTROLLERCONFIG="$(cat "$GAMEDIR/gamecontroller.txt")"

## CPU: velocidad de juego de MinUI (1.2 GHz). Valor fijo: overclock.elf 1488000
overclock.elf $CPU_SPEED_GAME

gptokeyb "$JUEGO" -c "$GAMEDIR/controles.gptk" &
sleep 1

# Log en /tmp (RAM), nunca en la SD
"$GAMEDIR/$JUEGO" > "/tmp/$JUEGO.log" 2>&1

killall -9 gptokeyb
