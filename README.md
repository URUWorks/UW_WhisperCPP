# UW_WhisperCPP

Compilaciones de [whisper.cpp](https://github.com/ggml-org/whisper.cpp) para Tero Subtitler pensadas
para funcionar en el mayor número de equipos posible, incluidos los antiguos.

| Paquete | Sistema mínimo | Notas |
|---|---|---|
| `whisper_linux.zip` | x86_64, glibc 2.17 (CentOS 7, Ubuntu 14.04, Debian 8) | libstdc++ estática, variantes de CPU, GPU con Vulkan |
| `whisper_linux_arm64.zip` | aarch64, glibc 2.17 | libstdc++ estática, variantes de CPU (armv8.0 ... armv8.6+SVE2) |
| `whisper_win64.zip` | Windows 7 SP1 x64 | runtime de C/C++ estático: no necesita Visual C++ Redistributable; GPU con Vulkan |
| `whisper_winarm64.zip` | Windows 10/11 en ARM | clang, armv8.2-a+dotprod+fp16, runtime estático |
| `whisper_macos_arm64.zip` | macOS 11.0 (Apple Silicon) | Metal, binario único |
| `whisper_macos_x86_64.zip` | macOS 10.11 (Intel) | solo CPU, variantes de CPU, incluye su propia libc++ |

En todos los x86-64 se incluyen las variantes `ggml-cpu-*` (desde SSE2 hasta AVX-512) y ggml carga
la mejor que soporte el procesador, así que también funciona en CPUs sin AVX.

## GPU

- **Windows x64 y Linux x64:** incluyen `ggml-vulkan.dll` / `libggml-vulkan.so` (NVIDIA, AMD e Intel).
  No hay que instalar nada aparte: usa la `vulkan-1.dll` / `libvulkan.so.1` que ya trae el driver de
  la tarjeta gráfica. Si el equipo no tiene Vulkan, esa librería no se carga y whisper sigue con la CPU.
- **macOS Apple Silicon:** Metal, integrado en el ejecutable.
- **macOS Intel, Windows arm64 y Linux arm64:** solo CPU.

## Cómo se actualiza

- **Automático:** el día 1 de cada mes el workflow mira la última versión de whisper.cpp. Si es nueva,
  compila los seis paquetes, los prueba y publica una Release con ese número (p. ej. `v1.9.5`)
  marcada como *latest*. Si no hay versión nueva, no hace nada.
- **A mano:** Actions → *Compilar whisper.cpp* → *Run workflow*. Se puede indicar un tag concreto y
  marcar *force* para recompilar una versión que ya existe.
- Descarga fija para otros workflows:
  `https://github.com/URUWorks/UW_WhisperCPP/releases/latest/download/whisper_win64.zip`
  (igual con `whisper_winarm64.zip`, `whisper_linux.zip`, `whisper_linux_arm64.zip`, `whisper_macos_arm64.zip` y `whisper_macos_x86_64.zip`).

## Detalles

- **Linux:** se compila dentro de `manylinux2014` (gcc 10). gcc 10 no admite AVX-VNNI ni AMX, así que no
  se generan las variantes `alderlake` ni `sapphirerapids`; esas CPU usan `haswell` o `icelake`/`zen4`.
  En aarch64 tampoco se generan las `armv9.2` (SME), y `scripts/glibc217-aarch64-compat.h` aporta las
  constantes HWCAP que faltan en las cabeceras de glibc 2.17. Para Vulkan no hay paquetes en CentOS 7, así
  que `scripts/build-vulkan-deps-linux.sh` compila las cabeceras, el loader (solo para enlazar) y `glslc`.
- **Windows x64:** `_WIN32_WINNT=0x0601` evita la única llamada de Windows 8+ que tiene ggml
  (`SetThreadInformation`), y `/MT` enlaza el runtime de forma estática. OpenMP va desactivado porque
  `vcomp140.dll` no existe en versión estática. `scripts/check-win7.py` revisa las importaciones de cada
  `.exe`/`.dll` y falla si aparece algo que Windows 7 no tiene.
- **Windows arm64:** ggml no admite MSVC puro en ARM, así que se usa clang. El nivel de CPU
  (armv8.2-a+dotprod+fp16) cubre todos los equipos de Windows 11 en ARM; el Snapdragon 835 queda fuera.
- **macOS Intel:** ggml usa `std::filesystem`, que la libc++ del sistema solo trae desde macOS 10.15.
  Por eso se compila una libc++ de LLVM con versión mínima 10.11 y se incluye junto al ejecutable.
  Accelerate va desactivado porque ggml usa la API nueva de LAPACK (macOS 13.3+).
- **macOS Apple Silicon:** mínimo 11.0, el primero que existe en ARM. Usa Metal y tampoco usa Accelerate,
  por el mismo motivo.
