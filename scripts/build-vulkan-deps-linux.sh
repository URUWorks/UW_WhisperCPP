#!/usr/bin/env bash
# Compila, dentro de manylinux2014 (glibc 2.17), lo necesario para el backend Vulkan de ggml:
#   - Vulkan-Headers (cabeceras, incluido vulkan.hpp)
#   - Vulkan-Loader  (solo para enlazar: en el equipo final se usa libvulkan.so.1 del sistema)
#   - glslc (shaderc), que compila los shaders durante la compilación
# No hay paquetes de esto para CentOS 7 y el SDK de LunarG necesita una glibc más nueva.
# Uso: build-vulkan-deps-linux.sh <prefijo de instalación>
set -euo pipefail
PREFIX="$1"
: "${VULKAN_SDK_TAG:=vulkan-sdk-1.4.363.0}"
: "${SHADERC_TAG:=v2026.4}"
J=$(nproc)
WORK="$(mktemp -d)"
cd "$WORK"

git clone -q --depth 1 -b "$VULKAN_SDK_TAG" https://github.com/KhronosGroup/Vulkan-Headers
cmake -S Vulkan-Headers -B build-headers -G Ninja -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --install build-headers

git clone -q --depth 1 -b "$VULKAN_SDK_TAG" https://github.com/KhronosGroup/Vulkan-Loader
cmake -S Vulkan-Loader -B build-loader -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DBUILD_WSI_XCB_SUPPORT=OFF -DBUILD_WSI_XLIB_SUPPORT=OFF -DBUILD_WSI_WAYLAND_SUPPORT=OFF \
  -DBUILD_WSI_DIRECTFB_SUPPORT=OFF -DBUILD_TESTS=OFF
cmake --build build-loader -j"$J"
cmake --install build-loader

git clone -q --depth 1 -b "$SHADERC_TAG" https://github.com/google/shaderc
python3 shaderc/utils/git-sync-deps
# ggml-vulkan también pide SPIRV-Headers (viene dentro de shaderc)
cmake -S shaderc/third_party/spirv-headers -B build-spirv-headers -G Ninja -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --install build-spirv-headers
cmake -S shaderc -B build-shaderc -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON \
  -DSPIRV_SKIP_TESTS=ON -DSPIRV_SKIP_EXECUTABLES=ON -DENABLE_GLSLANG_BINARIES=OFF
cmake --build build-shaderc -j"$J" --target glslc_exe
install -D build-shaderc/glslc/glslc "$PREFIX/bin/glslc"
"$PREFIX/bin/glslc" --version | head -1
rm -rf "$WORK"
