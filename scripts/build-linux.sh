#!/usr/bin/env bash
# Compila whisper.cpp para Linux (x86_64 o aarch64) con glibc >= 2.17
# (CentOS 7 / Ubuntu 14.04 / Debian 8). Se ejecuta dentro de la imagen manylinux2014
# (gcc 10, glibc 2.17) de la arquitectura correspondiente.
# Uso: build-linux.sh <carpeta-fuente-whisper.cpp> <carpeta-salida>
#   TARGET_ARCH (opcional): x86_64 | aarch64; por defecto la de la máquina.
#   VULKAN_PREFIX (opcional): carpeta de build-vulkan-deps-linux.sh; activa el backend GPU Vulkan
#                 (libggml-vulkan.so, que usa la libvulkan.so.1 del sistema si existe).
set -euo pipefail
SRC="$1"; OUT="$2"
ARCH="${TARGET_ARCH:-$(uname -m)}"
STRIP="${STRIP:-strip}"; OBJDUMP="${OBJDUMP:-objdump}"

if [ "$ARCH" = x86_64 ]; then
  # gcc 10 no conoce -mamx-* ni -mavxvnni: quitamos sapphirerapids y alderlake
  # (esas CPU caen a las variantes icelake/zen4 o haswell, que sí se compilan).
  sed -i -e "/ggml_add_cpu_backend_variant(sapphirerapids/d" -e "/ggml_add_cpu_backend_variant(alderlake/d" "$SRC/ggml/src/CMakeLists.txt"
else
  # gcc 10 no conoce +sme (armv9.2): esas CPU caen a la variante armv8.6 con SVE2.
  sed -i -e "/ggml_add_cpu_backend_variant(armv9.2_/d" "$SRC/ggml/src/CMakeLists.txt"
  # Constantes HWCAP/AT_HWCAP2 que no están en las cabeceras de glibc 2.17
  COMPAT="-include $(cd "$(dirname "$0")" && pwd)/glibc217-aarch64-compat.h"
fi

VK=()
if [ -n "${VULKAN_PREFIX:-}" ]; then
  VK=(-DGGML_VULKAN=ON -DCMAKE_PREFIX_PATH="$VULKAN_PREFIX" -DVulkan_GLSLC_EXECUTABLE="$VULKAN_PREFIX/bin/glslc")
fi

cmake -S "$SRC" -B "$SRC/build-linux" ${VK[@]+"${VK[@]}"} \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG ${COMPAT:-}" -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG ${COMPAT:-}" \
  -DBUILD_SHARED_LIBS=ON \
  -DGGML_NATIVE=OFF \
  -DGGML_BACKEND_DL=ON \
  -DGGML_CPU_ALL_VARIANTS=ON \
  -DGGML_OPENMP=OFF \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_SERVER=OFF \
  -DWHISPER_SDL2=OFF \
  -DWHISPER_CURL=OFF \
  -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
  -DCMAKE_SHARED_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
  -DCMAKE_MODULE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DCMAKE_INSTALL_RPATH='$ORIGIN'
cmake --build "$SRC/build-linux" -j"$(nproc)" --target whisper-cli

mkdir -p "$OUT"
B="$SRC/build-linux/bin"
cp -a "$B"/whisper-cli "$OUT"/
# librerías con el mismo nombre que el paquete actual (sin duplicados por enlaces)
cp -L "$B"/libwhisper.so.1 "$B"/libggml.so.0 "$B"/libggml-base.so.0 "$B"/libggml-cpu-*.so "$OUT"/
[ -z "${VULKAN_PREFIX:-}" ] || cp -L "$B"/libggml-vulkan.so "$OUT"/
cp "$OUT"/whisper-cli "$OUT"/main
cp "$SRC/LICENSE" "$OUT"/LICENSE.txt
"$STRIP" --strip-unneeded "$OUT"/whisper-cli "$OUT"/main "$OUT"/*.so*

# Verificación: ninguna dependencia por encima de GLIBC_2.17
MAXV=$(for f in "$OUT"/whisper-cli "$OUT"/*.so*; do "$OBJDUMP" -T "$f" | grep -o 'GLIBC_[0-9.]*'; done | sort -Vu | tail -1)
echo "Versión máxima de glibc requerida: $MAXV"
if [ "$MAXV" != "GLIBC_2.17" ] && [ "$(printf '%s\nGLIBC_2.17\n' "$MAXV" | sort -V | tail -1)" != "GLIBC_2.17" ]; then
  echo "ERROR: se requiere $MAXV (> 2.17)"; exit 1
fi
if for f in "$OUT"/whisper-cli "$OUT"/*.so*; do "$OBJDUMP" -p "$f"; done | grep NEEDED | grep -q 'libstdc++\|libgcc_s\|libgomp'; then
  echo "ERROR: dependencia dinámica de libstdc++/libgcc_s/libgomp"; exit 1
fi
ls -la "$OUT"
