# Compila whisper.cpp para Windows.
#  x64:   Windows 7 SP1 en adelante.
#    - _WIN32_WINNT=0x0601: ggml no usa APIs de Windows 8+ (p. ej. SetThreadInformation).
#    - Variantes de CPU (SSE2 ... AVX-512) cargadas en tiempo de ejecución.
#  arm64: Windows 10/11 en ARM (no existe Windows 7 para ARM). Se compila con clang,
#         porque ggml no admite MSVC puro en ARM; nivel de CPU armv8.2-a+dotprod+fp16.
#    - Si está instalado el SDK de Vulkan ($env:VULKAN_SDK), añade el backend GPU Vulkan
#      (ggml-vulkan.dll). Usa la vulkan-1.dll que instala el driver de la tarjeta gráfica;
#      si no existe, ggml no carga esa DLL y sigue con la CPU.
#  En ambos: runtime de C/C++ estático (/MT), así que no hace falta instalar el
#  Visual C++ Redistributable; y sin OpenMP (vcomp140.dll no existe en versión estática).
# Uso: build-windows.ps1 -Src <carpeta whisper.cpp> -Out <carpeta salida> [-Arch x64|arm64]
param(
  [Parameter(Mandatory)][string]$Src,
  [Parameter(Mandatory)][string]$Out,
  [ValidateSet('x64','arm64')][string]$Arch = 'x64'
)
$ErrorActionPreference = 'Stop'
$build = Join-Path $Src "build-win-$Arch"

$common = @(
  '-DCMAKE_BUILD_TYPE=Release',
  '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW',
  '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded',
  '-DBUILD_SHARED_LIBS=ON',
  '-DGGML_NATIVE=OFF',
  '-DGGML_BACKEND_DL=ON',
  '-DGGML_OPENMP=OFF',
  '-DWHISPER_BUILD_TESTS=OFF',
  '-DWHISPER_BUILD_SERVER=OFF',
  '-DWHISPER_SDL2=OFF',
  '-DWHISPER_CURL=OFF'
)

if ($Arch -eq 'x64') {
  $win7 = '/D_WIN32_WINNT=0x0601 /DWINVER=0x0601'
  $vk = @()
  if ($env:VULKAN_SDK) { $vk = @('-DGGML_VULKAN=ON') }
  cmake -S $Src -B $build -G 'Visual Studio 17 2022' -A x64 -T v143 @common @vk `
    -DGGML_CPU_ALL_VARIANTS=ON `
    "-DCMAKE_C_FLAGS=/DWIN32 /D_WINDOWS $win7" `
    "-DCMAKE_CXX_FLAGS=/DWIN32 /D_WINDOWS /EHsc /GR $win7"
  if ($LASTEXITCODE) { throw 'cmake configure falló' }
  cmake --build $build --config Release --target whisper-cli -- /m
  if ($LASTEXITCODE) { throw 'cmake build falló' }
  $bin = Join-Path $build 'bin\Release'
} else {
  $tc = Join-Path $PSScriptRoot 'arm64-windows-llvm.cmake'
  cmake -S $Src -B $build -G Ninja "-DCMAKE_TOOLCHAIN_FILE=$tc" @common
  if ($LASTEXITCODE) { throw 'cmake configure falló' }
  cmake --build $build --target whisper-cli
  if ($LASTEXITCODE) { throw 'cmake build falló' }
  $bin = Join-Path $build 'bin'
}

New-Item -ItemType Directory -Force $Out | Out-Null
Copy-Item "$bin\whisper-cli.exe", "$bin\*.dll" $Out
Copy-Item (Join-Path $Src 'LICENSE') (Join-Path $Out 'LICENSE.txt')
Get-ChildItem $Out
