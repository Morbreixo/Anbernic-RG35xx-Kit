# Anbernic RG35XX — guía para ports

Todo lo que hace falta para portar juegos a mi RG35XX sin volver a investigar.
Primer port hecho con esto: **OpenXcom** (`../openxcom/Openxcom.pak`).

## Contenido de esta carpeta

| Carpeta / fichero | Qué es |
|---|---|
| `README.md` | Este documento: perfil de la consola, cómo compilar, cómo empaquetar, problemas conocidos |
| `toolchain/` | Compilador cruzado listo (zig): `zcc`, `zcxx`, `zstrip`, `toolchain.cmake`, `setup.sh` |
| `sysroot/` | Librerías `.so` copiadas de la consola (sin firmware). `LIBRERIAS.txt` = lista |
| `plantillas/` | `launch.sh` para MiaUI, `controles.gptk`, lista de teclas de gptokeyb |
| `scripts/` | Para el PC con la consola por adb: info, copiar sysroot, subir port, ver log |
| `referencia/` | Parche de OpenXcom (cursor por botones, teclado en pantalla, sello de arranque) y su lanzador |

## ⚠️ Reglas fijas

- **No escribir logs en la SD.** Ni `log.txt` dentro del `.pak` ni en ningún otro sitio de `/userdata`:
  todo log o salida de depuración va a **`/tmp`** (p. ej. `/tmp/eob.log`). La SD de la consola ya ha
  sufrido entradas dañadas (`Input/output error`) y hay que reducir escrituras al mínimo.
- En la SD solo se escribe lo imprescindible: partidas guardadas y configuración del juego.
- Si el propio juego crea su log dentro de su carpeta (p. ej. `openxcom.log` en OpenXcom), se cambia
  en el código o, si no se puede, se convierte en un enlace a `/tmp` desde el `launch.sh`
  (ver `referencia/openxcom-launch.sh`).

---

## 1. La consola

| | |
|---|---|
| Modelo | Anbernic **RG35XX original** (SoC Actions, `Hardware: gs705a`) |
| CPU | ARMv7 Cortex-A9, **NEON**, vfpv3 — 32 bits **hard-float (armhf)** |
| GPU | PowerVR SGX (libEGL/libGLESv1/v2 de IMG) |
| RAM | ~256 MB (≈116 MB libres en /tmp). Ojo con juegos que carguen mucho |
| Pantalla | **640x480** |
| Kernel | Linux 3.10.37 |
| Sistema | **Buildroot 2023.05.1** — interfaz **MiaUI** (basada en MinUI) |
| glibc | **2.37** → compilar para `glibc 2.37` o anterior |
| C++ | libstdc++ 6.0.29 en la consola (mejor no depender: enlazar libc++ estática) |
| SDL 1.2 | `libSDL-1.2.so.0` → **sdl12-compat 1.2.65** (SDL 1.2 encima de SDL2) |
| SDL 2 | 2.28.4 (también hay 2.26.5) + image, mixer, ttf, gfx, net |
| Otras | libpng16, libjpeg 8/9, zlib, ogg/vorbis, FLAC, mad, modplug, freetype, openal, ffmpeg, python 3.11… (ver `sysroot/LIBRERIAS.txt`) |
| No hay | `ldd`, `getconf`, `locale`, cabeceras (`/usr/include`) |
| Particiones | `/` 1.4 GB (casi lleno) · `/userdata` 57 GB (aquí va todo) |
| HOME | `/userdata/Profile` |
| Acceso | **adb** por USB · gestor web MiaUI en `http://192.168.137.100` (subir ficheros, permisos) |
| Herramientas | `gptokeyb` (versión antigua), `evmapy`, `overclock.elf`, variable `$CPU_SPEED_GAME` |

## 2. Cómo trabajamos (Claude + yo)

- Claude **no ve el USB**: su terminal es una máquina aislada. Yo ejecuto los `adb` y le pego la salida.
- Claude compila en su entorno en la nube (Ubuntu, con root) y me deja el resultado en la carpeta del proyecto.
- **Al empezar un port nuevo:** dar acceso a esta carpeta `anbernic` y a la del juego, y decirle
  *"lee anbernic/README.md"*. Si la consola cambió de firmware, pasar antes la salida de `scripts/info-dispositivo.sh`.

## 3. Compilar

### Compilador: zig como compilador cruzado
Elegido porque permite fijar la versión de glibc y trae libc++ estática, sin sysroot de glibc ni root.

```sh
toolchain/setup.sh                         # instala zig 0.13 desde PyPI
toolchain/zcc  -O2 -o hola hola.c          # C
toolchain/zcxx -O2 -o hola hola.cpp        # C++ (libc++ estática incluida)
toolchain/zstrip hola hola_strip           # quitar símbolos (78 MB → 5 MB en OpenXcom).
```
Objetivo: `-target arm-linux-gnueabihf.2.37 -mcpu=cortex_a9`. Añadir `-mfpu=neon -mfloat-abi=hard -O2 -fPIE -pie` (ver problemas conocidos: sin PIE, usar `stderr` hace segfault).

### Con CMake
```sh
cmake -S . -B build -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=/ruta/anbernic/toolchain/toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS="-O2 -mfpu=neon -mfloat-abi=hard"
ninja -C build
```

### Librerías
- **Las que trae la consola** (SDL, png, zlib…): enlazar contra las `.so` de `sysroot/`
  con `-Wl,--allow-shlib-undefined` (sus propias dependencias se resuelven en la consola).
  Si la librería del sysroot tiene nombre largo, copiarla como `libX.so` en una carpeta de enlace:
  lo que cuenta es el SONAME de dentro (p. ej. `libSDL-1.2.so.0`).
- **Cabeceras**: la consola no trae. Descargar el código de la misma versión
  (p. ej. `libsdl-org/SDL-1.2`, `SDL_image` y `SDL_mixer` rama `SDL-1.2`). Para `SDL_config.h`
  vale un `./configure` nativo cambiando `SIZEOF_VOIDP` a 4.
- **Las que no trae** (yaml-cpp, etc.): compilarlas estáticas con el mismo toolchain e instalarlas
  en un prefijo (`ANBERNIC_PREFIX`).
- **OpenGL**: no hay OpenGL de escritorio, solo GLES. Desactivar OpenGL en los juegos.

### Comprobar el binario antes de subirlo
```sh
file juego                                     # ELF 32-bit ARM, EABI5, armhf
readelf -d juego | grep NEEDED                 # todas deben existir en sysroot/
readelf -V juego | grep -o "GLIBC_[0-9.]*" | sort -Vu | tail -1   # ≤ 2.37
```

## 4. Empaquetar para MiaUI

- Los ports van en **`/userdata/Ports/<Nombre>.pak/`** (la extensión `.pak` es obligatoria).
- Dentro, un **`launch.sh`** (ver `plantillas/launch.sh`). Formato que usa el sistema:
  ```sh
  GAMEDIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
  cd "$GAMEDIR"
  overclock.elf $CPU_SPEED_GAME
  "$GAMEDIR"/juego "$GAMEDIR"/datos
  ```
- Guardar partidas y configuración **dentro del .pak** (que el juego no escriba en `$HOME`).
- **Logs: NUNCA en la tarjeta SD.** Redirigir la salida a `/tmp/<juego>.log` (RAM; se pierde al
  apagar, y es lo que queremos). Se lee con `scripts/ver-log.sh <juego>`.

### Controles
- Juegos SDL2 con soporte de mando: `export SDL_GAMECONTROLLERCONFIG="$(cat gamecontroller.txt)"`.
- Juegos de teclado/ratón: **gptokeyb** traduce el mando a teclas/ratón (`plantillas/controles.gptk`).
  - Es la **versión antigua** → ver `plantillas/gptokeyb-teclas.txt` (no hay `numpad*`, `f11`, `f12`).
  - La RG35XX original **no tiene sticks**: el ratón va con la cruceta.
- Para teclas especiales (como la tecla guide/home) otros ports usan `evmapy` (ver Diablo.pak).

## 5. Problemas conocidos y soluciones

| Problema | Solución |
|---|---|
| `adb pull /usr/lib usr/lib` falla | `adb pull` no crea carpetas intermedias: `mkdir -p usr` antes |
| El pull de `/usr/lib` acaba con error `i386-linux-gnu` | Enlace roto en la consola; lo útil ya está copiado |
| El juego no arranca tras actualizar el binario | Se perdió el permiso de ejecución: `adb shell chmod +x ...` |
| `SDL_WarpMouse` deja el cursor desplazado 40 px en vertical | sdl12-compat pone franjas negras (640x400 en 640x480): mover el cursor usa coordenadas físicas y leerlo, lógicas. Medir el desfase tras el primer movimiento y compensarlo (ver parche de OpenXcom, `PadNav::calibrate`) |
| Mensaje `SDL_KillThread(), an unforgivable curse` | Aviso de sdl12-compat al salir; inofensivo |
| `sh: locale: not found` | No hay `locale` en Buildroot; inofensivo. El juego no detecta idioma: fijarlo en su configuración |
| Juegos a 320x200 | Se ven a 640x400 con franjas arriba/abajo. Las fuentes del juego tienen trazo (1-2) y borde (3-5): al pintarlas a mano, respetar el borde |
| Traducciones de OpenXcom | No vienen en el repo; están en el de OpenXcom Extended (`MeridianOXC/OpenXcom`, `bin/*/Language/es-ES.yml`) |
| Entorno de Claude: copia del binario no actualizada | Al reenviar un fichero con el mismo nombre a veces llega la versión anterior: usar un nombre nuevo y comprobar con `md5sum` |
| Segmentation fault nada más arrancar, antes de `main`/primer `printf` (programas C que usan `stderr`/`stdout`) | Fallo de zig 0.13 con glibc en ARM: las variables `stdin/stdout/stderr` quedan con tamaño incorrecto y en la misma dirección. **Compilar siempre con `-fPIE -pie`** (se resuelven por la GOT). Se puede reproducir en el PC con `qemu-arm -L <carpeta con sysroot/lib> ./binario` |
| `qemu-arm` termina con código 1 sin decir nada | El fichero no tiene permiso de ejecución (se pierde al copiar): `chmod +x` |
| Driver de vídeo SDL2 de la consola | Se llama `mali`; render disponibles: `opengles2`, `opengles`, `software` |
| Botones A/B de gptokeyb | Comprobado con Chip's Challenge: en esta consola `a` = botón A físico y `b` = botón B (NO van cruzados, aunque la nota de Night Shift decía lo contrario) |
| ScummVM: menús en inglés aunque `gui_language=es_ES` | Con idioma no inglés ScummVM exige fuentes TTF: compilar con FreeType (`--enable-freetype2`, la consola trae `libfreetype.so.6` = 2.13.0) y llevar un tema con `scalable_file` + `fonts.dat` (ver `eob/EyeOfTheBeholder.pak/extra`) |
| ScummVM: `configure` deja `AR := zar cr cr` | Corregir a mano en `config.mk` tras cada `configure` |
| `zig objcopy --strip-all X X` deja el ELF truncado | Usar fichero de salida distinto |
| SDL2 de la consola en qemu: "dummy not available" | La SDL de la consola solo trae el driver `mali`. Para probar en el PC compilar SDL2 2.28.4 con zig (trae dummy/offscreen) o mejor compilar el juego también para x86 y probarlo con Xvfb |
| Los botones del mando llegan dos veces (por gptokeyb y por SDL) | Aunque se ponga `SDL_JOYSTICK_DISABLE=1`, SDL sigue viendo el mando como GameController: si el juego usa gptokeyb, no leer los botones del mando en el código |

## 6. Ideas reutilizables (en `referencia/`)

El parche de OpenXcom contiene tres piezas que se pueden llevar a otros juegos SDL 1.2/2:
1. **Cursor botón a botón**: la cruceta (vía gptokeyb como `insert/f6/pause/menu`) salta entre
   elementos clicables; movimiento libre con aceleración sobre zonas grandes o manteniendo L1/R1.
2. **Teclado en pantalla** semitransparente (tramado): se abre solo cuando el juego pide texto
   o con L1+R1; cruceta + A escribe, B borra, X Enter, Start cierra.
3. **Sello de arranque** (`splash.png`, 400x400, 256 colores) con fundido por paleta, saltable.

## 7. Ports con ScummVM (motor nativo, no emulación)

Primer caso: **Eye of the Beholder** (`../eob/`). Si un juego está soportado por ScummVM, es el camino más rápido:
- Compilar ScummVM **solo con el motor del juego** (`--disable-all-engines --enable-engine=...`): binario de ~13 MB.
- Receta completa y parche (modo cursor con Select, mensajes de diagnóstico del mando, sin "Volver al iniciador") en `../eob/port/`.
- `DATA_PATH` cambiado a `extra` (relativo): `kyra.dat`, `translations.dat`, tema y `fonts.dat` van en `<juego>.pak/extra/`.
- Se lanza directo al juego: `scummvm -c scummvm.ini --path=datos --savepath=save --fullscreen <target>`; al salir del juego se cierra ScummVM.
- `aspect_ratio=true` + `scale_factor=2`: los juegos de 320x200 llenan la pantalla de 640x480 sin franjas.
- **Sello de arranque genérico** para cualquier port: `plantillas/sello` (`sello imagen.bmp [ms]`, fuente en `plantillas/sello.c`).

## 8. Ports de juegos Java (sin JVM): traducir a C++

Primer caso: **La Abadía del Crimen Extensum** (`../abadia_extensum/`, detalles en `port/LEEME-port.md`).
La consola no tiene Java ni X11 y 256 MB no dan para una JVM: el juego se descompila y se **traduce a
C++** con un traductor propio, sobre un mini-runtime (Java2D por software, String, Data*Stream, Random…)
y SDL2. Resultado: binario de 1,5 MB, ~40 MB de RAM, idéntico al original fotograma a fotograma.

Receta reutilizable (todo en `abadia_extensum/port/tools/`):
1. Descompilar con **Vineflower** (y CFR para contrastar). Parchear en Java lo que dependa de Swing/AWT
   (ventana, ratón, `ImageIcon`, rutas del .jar) y sustituir el sonido por un stub.
2. `transpile.py` (necesita `javalang` + `javalang-fixes.py`): genera C++ con la semántica exacta de Java
   (enteros que desbordan, `>>>`, orden de evaluación izquierda→derecha, arrays con comprobación de
   límites, inicialización estática en orden de dependencias).
3. **Verificar contra el bytecode**: `verify_fields.py` (campos y llamadas de cada método = los del .class).
4. **Ejecución diferencial**: el .jar original con Java 8 en Xvfb (`tools/harness/Harness2.java`) y el port
   reciben el mismo guion de teclas por número de fotograma y las mismas semillas; se comparan volcados
   del estado completo e imágenes. Si difieren: trazas de llamadas con JDI (`harness/jdi/Tracer.java`,
   funciona sin info de depuración) contra `build-trace.sh`.
5. Errores típicos ya resueltos: variables `byte` que eran `int`, parámetros `boolean` reutilizados como
   `int`, cualificadores perdidos en campos estáticos, `default:` perdido por javalang, `(v = x).f = g(v)`.
6. Pintar a la resolución nativa del juego (320x240) y que la GPU escale x2 (nearest): mucho más rápido
   que escalar por software. Música en streaming (stb_vorbis), no decodificada entera.
