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
cmake -S "llvm-project-$VER.src/runtimes" -B build-libcxx -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
  -DLIBCXX_ENABLE_SHARED=ON -DLIBCXX_ENABLE_STATIC=OFF \
  -DLIBCXXABI_ENABLE_SHARED=ON -DLIBCXXABI_ENABLE_STATIC=OFF \
  -DLIBCXX_INCLUDE_TESTS=OFF -DLIBCXX_INCLUDE_BENCHMARKS=OFF -DLIBCXXABI_INCLUDE_TESTS=OFF \
  -DLIBCXX_INSTALL_LIBRARY_DIR=lib -DLIBCXXABI_INSTALL_LIBRARY_DIR=lib \
  -DCMAKE_INSTALL_NAME_DIR=@rpath \
  -DLIBCXX_ENABLE_VENDOR_AVAILABILITY_ANNOTATIONS=OFF
cmake --build build-libcxx
cmake --install build-libcxx
otool -L "$PREFIX/lib/libc++.1.dylib"
