#!/bin/sh

# para entrar en la carpeta.pak
GAMEDIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "$GAMEDIR"

export SDL_JOYSTICK_DISABLE=1
export SDL_NOMOUSE=0

## CPU: MinUI's game speed (1.2 GHz)
overclock.elf $CPU_SPEED_GAME

# cruceta = raton, A = clic izq, B = clic der
gptokeyb "openxcom" -c "$GAMEDIR/openxcom-mouse.gptk" &
sleep 1

mkdir -p "$GAMEDIR/user" "$GAMEDIR/config"
# OpenXcom escribe su propio openxcom.log en user/: se redirige a /tmp con un enlace (nada de logs en la SD)
if [ ! -L "$GAMEDIR/user/openxcom.log" ]; then
    rm -f "$GAMEDIR/user/openxcom.log"
    ln -s /tmp/openxcom-juego.log "$GAMEDIR/user/openxcom.log" 2>/dev/null
fi
"$GAMEDIR"/openxcom -data "$GAMEDIR/data/" -user "$GAMEDIR/user/" -cfg "$GAMEDIR/config/" > /tmp/openxcom.log 2>&1

killall -9 gptokeyb
