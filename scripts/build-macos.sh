#!/usr/bin/env bash
# Compila whisper.cpp para macOS.
#   arm64  (Apple Silicon): macOS 11.0+, con Metal. Binario único estático.
# Accelerate va desactivado: ggml lo usa con ACCELERATE_NEW_LAPACK, que exige macOS 13.3.
#   x86_64 (Intel):         macOS 10.11+ (MACOS_MIN), solo CPU, con variantes de CPU
#                           (SSE2 ... AVX-512). Incluye su propia libc++ porque ggml usa
#                           std::filesystem, que la libc++ del sistema solo trae desde 10.15.
# Uso: build-macos.sh <arm64|x86_64> <carpeta whisper.cpp> <carpeta salida> [libc++ prefix]
set -euo pipefail
ARCH="$1"; SRC="$2"; OUT="$3"; LIBCXX="${4:-}"
mkdir -p "$OUT"
J=$(sysctl -n hw.ncpu)

if [ "$ARCH" = arm64 ]; then
  export MACOSX_DEPLOYMENT_TARGET=11.0
  cmake -S "$SRC" -B "$SRC/build-arm64" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_NATIVE=OFF \
    -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON \
    -DGGML_BLAS=OFF -DGGML_ACCELERATE=OFF \
    -DGGML_OPENMP=OFF \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF -DWHISPER_SDL2=OFF -DWHISPER_CURL=OFF
  cmake --build "$SRC/build-arm64" -j"$J" --target whisper-cli
  cp "$SRC/build-arm64/bin/whisper-cli" "$OUT"/
else
  : "${MACOS_MIN:=10.11}"
  export MACOSX_DEPLOYMENT_TARGET="$MACOS_MIN"
  [ -n "$LIBCXX" ] || { echo "falta la ruta de la libc++ propia"; exit 1; }
  CXXF="-nostdinc++ -isystem $LIBCXX/include/c++/v1"
  LDF="-nostdlib++ -L$LIBCXX/lib -lc++ -lc++abi -Wl,-rpath,@loader_path"
  cmake -S "$SRC" -B "$SRC/build-x86_64" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN" \
    -DCMAKE_CXX_FLAGS="$CXXF" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDF" -DCMAKE_SHARED_LINKER_FLAGS="$LDF" -DCMAKE_MODULE_LINKER_FLAGS="$LDF" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DCMAKE_INSTALL_RPATH=@loader_path \
    -DBUILD_SHARED_LIBS=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON \
    -DGGML_METAL=OFF \
    -DGGML_BLAS=OFF -DGGML_ACCELERATE=OFF \
    -DGGML_OPENMP=OFF \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF -DWHISPER_SDL2=OFF -DWHISPER_CURL=OFF
  cmake --build "$SRC/build-x86_64" -j"$J" --target whisper-cli
  B="$SRC/build-x86_64/bin"
  cp "$B"/whisper-cli "$OUT"/
  # dylibs con nombre de soname; variantes de CPU (.so) tal cual
  for f in "$B"/*.dylib; do [ -L "$f" ] || cp "$f" "$OUT"/; done
  for f in "$B"/libwhisper*.dylib "$B"/libggml*.dylib; do [ -L "$f" ] && cp -P "$f" "$OUT"/; done
  cp "$B"/libggml-cpu-*.so "$OUT"/
  cp "$LIBCXX"/lib/libc++.1.dylib "$LIBCXX"/lib/libc++abi.1.dylib "$OUT"/
  # Verificación: nada enlaza contra /usr/lib/libc++ y la versión mínima es MACOS_MIN
  for f in "$OUT"/whisper-cli "$OUT"/*.dylib "$OUT"/*.so; do
    [ -L "$f" ] && continue
    if otool -L "$f" | grep -q '/usr/lib/libc++'; then echo "ERROR: $f usa la libc++ del sistema"; exit 1; fi
    MIN=$(otool -l "$f" | awk '/LC_VERSION_MIN_MACOSX/{v=1} v&&/version/{print $2; exit} /LC_BUILD_VERSION/{b=1} b&&/minos/{print $2; exit}')
    echo "$(basename "$f"): minos=$MIN"
    [ "$MIN" = "$MACOS_MIN" ] || { echo "ERROR: $f requiere macOS $MIN"; exit 1; }
  done
fi
cp "$SRC/LICENSE" "$OUT"/LICENSE.txt
ls -la "$OUT"
