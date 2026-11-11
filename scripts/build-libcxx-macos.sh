#!/usr/bin/env bash
# Compila libc++ / libc++abi (LLVM) como dylib para x86_64 con versión mínima MACOS_MIN.
# La libc++ del sistema no tiene std::filesystem antes de macOS 10.15, y ggml lo necesita.
# El install name queda como @rpath/libc++.1.dylib, así que se usa la copia junto al ejecutable.
# Uso: build-libcxx-macos.sh <versión LLVM> <prefijo de instalación>
set -euo pipefail
VER="$1"; PREFIX="$2"
: "${MACOS_MIN:=10.11}"
curl -fsSL -o llvm.tar.xz "https://github.com/llvm/llvm-project/releases/download/llvmorg-$VER/llvm-project-$VER.src.tar.xz"
tar xf llvm.tar.xz
# libc++ usa utimensat (macOS 10.13+); por debajo de 10.13 usamos su alternativa con utimes
sed -i '' 's/^#if defined(UTIME_OMIT)$/#if defined(UTIME_OMIT) \&\& !(defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__) \&\& __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ < 101300)/' "llvm-project-$VER.src/libcxx/src/filesystem/time_utils.h"
grep -n 'defined(UTIME_OMIT)' "llvm-project-$VER.src/libcxx/src/filesystem/time_utils.h"
# std::chrono llama a clock_gettime (macOS 10.12+): se enlaza nuestra versión dentro de la dylib
COMPAT="$PWD/clock_gettime-compat.o"
clang -c -O2 -arch x86_64 -mmacosx-version-min="$MACOS_MIN" -o "$COMPAT" \
  "$(cd "$(dirname "$0")" && pwd)/clock_gettime-compat-macos.c"
cmake -S "llvm-project-$VER.src/runtimes" -B build-libcxx -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
  -DLIBCXXABI_USE_LLVM_UNWINDER=OFF \
  -DLIBCXX_ENABLE_SHARED=ON -DLIBCXX_ENABLE_STATIC=OFF \
  -DLIBCXXABI_ENABLE_SHARED=ON -DLIBCXXABI_ENABLE_STATIC=OFF \
  -DLIBCXX_INCLUDE_TESTS=OFF -DLIBCXX_INCLUDE_BENCHMARKS=OFF -DLIBCXXABI_INCLUDE_TESTS=OFF \
  -DLIBCXX_INSTALL_LIBRARY_DIR=lib -DLIBCXXABI_INSTALL_LIBRARY_DIR=lib \
  -DCMAKE_INSTALL_NAME_DIR=@rpath \
  -DCMAKE_SHARED_LINKER_FLAGS="$COMPAT" \
  -DLIBCXX_ENABLE_VENDOR_AVAILABILITY_ANNOTATIONS=OFF
cmake --build build-libcxx
cmake --install build-libcxx
otool -L "$PREFIX/lib/libc++.1.dylib"
# Ninguna función de libSystem posterior a MACOS_MIN (el compilador las enlaza "weak" y en
# un macOS antiguo quedarían en NULL)
for f in "$PREFIX"/lib/libc++.1.dylib "$PREFIX"/lib/libc++abi.1.dylib; do
  if nm -m "$f" | grep '(undefined) weak external' | grep 'from libSystem'; then
    echo "ERROR: $f usa funciones del sistema que no existen en macOS $MACOS_MIN"; exit 1
  fi
done
