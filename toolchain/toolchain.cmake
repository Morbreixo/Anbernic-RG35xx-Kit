# Uso: cmake -DCMAKE_TOOLCHAIN_FILE=<ruta>/toolchain.cmake -DANBERNIC_TC=<ruta a esta carpeta> ...
# Si no se pasa ANBERNIC_TC se usa la carpeta de este fichero.
if(NOT ANBERNIC_TC)
  get_filename_component(ANBERNIC_TC "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
endif()
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER   ${ANBERNIC_TC}/zcc)
set(CMAKE_CXX_COMPILER ${ANBERNIC_TC}/zcxx)
set(CMAKE_AR           ${ANBERNIC_TC}/zar)
set(CMAKE_RANLIB       ${ANBERNIC_TC}/zranlib)
# Dependencias compiladas por nosotros (yaml-cpp, etc.) se instalan en este prefijo
if(NOT ANBERNIC_PREFIX)
  set(ANBERNIC_PREFIX /work/prefix)
endif()
set(CMAKE_FIND_ROOT_PATH ${ANBERNIC_PREFIX})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
# Enlazar contra las .so de la consola sin tener todas sus dependencias
set(CMAKE_EXE_LINKER_FLAGS_INIT "-Wl,--allow-shlib-undefined")
