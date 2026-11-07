# Toolchain para Windows on ARM con clang (ggml no admite MSVC puro en ARM sin GGML_NATIVE).
# Basado en cmake/arm64-windows-llvm.cmake de whisper.cpp, pero con un nivel de CPU más bajo:
# armv8.2-a+dotprod+fp16 cubre todos los equipos que admite Windows 11 en ARM
# (Snapdragon 850/7c/8c/8cx, SQ1/SQ2/SQ3, X Elite/X Plus...). Upstream usa armv8.7-a.
set( CMAKE_SYSTEM_NAME Windows )
set( CMAKE_SYSTEM_PROCESSOR arm64 )
set( target arm64-pc-windows-msvc )
set( CMAKE_C_COMPILER    clang )
set( CMAKE_CXX_COMPILER  clang++ )
set( CMAKE_C_COMPILER_TARGET   ${target} )
set( CMAKE_CXX_COMPILER_TARGET ${target} )
set( arch_c_flags "-march=armv8.2-a+dotprod+fp16 -fvectorize -ffp-model=fast -fno-finite-math-only" )
set( warn_c_flags "-Wno-format -Wno-unused-variable -Wno-unused-function -Wno-gnu-zero-variadic-macro-arguments" )
set( CMAKE_C_FLAGS_INIT   "${arch_c_flags} ${warn_c_flags}" )
set( CMAKE_CXX_FLAGS_INIT "${arch_c_flags} ${warn_c_flags}" )
