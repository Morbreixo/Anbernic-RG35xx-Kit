#!/bin/sh
# Copia las librerías de la consola a ./sysroot para enlazar contra ellas.
# OJO: adb pull no crea carpetas intermedias, por eso el mkdir.
# El pull de /usr/lib termina con un error por un enlace roto (i386-linux-gnu):
# es normal, para entonces ya ha copiado todo lo útil.
set -x
mkdir -p sysroot/usr
adb pull /lib sysroot/lib
adb pull /usr/lib sysroot/usr/lib
# El firmware del kernel no hace falta para compilar (330 MB):
rm -rf sysroot/lib/firmware sysroot/lib/modules
