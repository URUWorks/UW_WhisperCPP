#!/usr/bin/env python3
"""Comprueba que los .exe/.dll no dependan de nada que Windows 7 SP1 no tenga.

- Sin runtime de Visual C++ ni UCRT (VCRUNTIME*, MSVCP*, VCOMP*, ucrtbase, api-ms-win-*).
- Sin funciones de KERNEL32/ADVAPI32 que aparecieron en Windows 8 o posterior.
- Versión de SO/subsistema en la cabecera PE <= 6.1.

Uso: python check-win7.py <carpeta> [--solo-runtime]   (necesita dumpbin en el PATH)
  --solo-runtime: solo comprueba que no dependa del runtime de Visual C++ (para arm64,
                  donde el mínimo es Windows 10 y las APIs de Windows 8+ están disponibles).
"""
import pathlib, re, subprocess, sys

DLL_PROHIBIDAS = re.compile(r"^(vcruntime|msvcp|vcomp|ucrtbase|concrt|api-ms-win-)", re.I)

# Funciones introducidas en Windows 8+ (lista no exhaustiva, la más habitual en C/C++).
FUNCIONES_WIN8 = {
    "AddDllDirectory", "RemoveDllDirectory", "SetDefaultDllDirectories",
    "CopyFile2", "CreateFile2", "CreateFileMappingFromApp", "MapViewOfFileFromApp",
    "DiscardVirtualMemory", "OfferVirtualMemory", "ReclaimVirtualMemory",
    "GetCurrentThreadStackLimits", "GetFirmwareType", "GetOverlappedResultEx",
    "GetProcessInformation", "SetProcessInformation",
    "GetThreadInformation", "SetThreadInformation",
    "GetThreadDescription", "SetThreadDescription",
    "GetProcessMitigationPolicy", "SetProcessMitigationPolicy",
    "GetSystemCpuSetInformation", "GetProcessDefaultCpuSets", "SetProcessDefaultCpuSets",
    "GetThreadSelectedCpuSets", "SetThreadSelectedCpuSets",
    "GetSystemTimePreciseAsFileTime", "QueryUnbiasedInterruptTimePrecise",
    "GetTempPath2A", "GetTempPath2W", "GetFileInformationByName",
    "PrefetchVirtualMemory", "VirtualAlloc2", "VirtualAlloc2FromApp",
    "MapViewOfFile3", "MapViewOfFile3FromApp", "MapViewOfFileNuma2",
    "WaitOnAddress", "WakeByAddressAll", "WakeByAddressSingle",
    "GetCurrentPackageId", "GetCurrentPackageFullName", "GetPackageFamilyName",
    "SetThreadpoolTimerEx", "SetThreadpoolWaitEx", "CreateRemoteThreadEx2",
    "GetMachineTypeAttributes", "IsWow64Process2",
}

def dumpbin(args, f):
    return subprocess.run(["dumpbin", "/nologo", *args, str(f)],
                          capture_output=True, text=True, check=True).stdout

def main(carpeta, solo_runtime=False):
    errores = []
    archivos = sorted(p for p in pathlib.Path(carpeta).iterdir() if p.suffix.lower() in (".exe", ".dll"))
    if not archivos:
        sys.exit("No hay .exe/.dll en " + carpeta)
    for f in archivos:
        imp = dumpbin(["/imports"], f)
        dll_actual = None
        for linea in imp.splitlines():
            m = re.match(r"^\s{4}(\S+\.dll)\s*$", linea, re.I)
            if m:
                dll_actual = m.group(1)
                if DLL_PROHIBIDAS.match(dll_actual):
                    errores.append(f"{f.name}: depende de {dll_actual}")
                continue
            m = re.match(r"^\s+[0-9A-F]+\s+(\w+)\s*$", linea)
            if not solo_runtime and m and m.group(1) in FUNCIONES_WIN8:
                errores.append(f"{f.name}: usa {dll_actual}!{m.group(1)} (Windows 8+)")
        if solo_runtime:
            print(f"OK? {f.name}")
            continue
        hdr = dumpbin(["/headers"], f)
        for clave in ("operating system version", "subsystem version"):
            m = re.search(r"([\d.]+)\s+" + clave, hdr)
            if m and tuple(int(x) for x in m.group(1).split(".")) > (6, 1):
                errores.append(f"{f.name}: {clave} = {m.group(1)} (> 6.1)")
        print(f"OK? {f.name}")
    if errores:
        print("\n".join(["", "ERRORES de compatibilidad:", *errores]))
        sys.exit(1)
    print(f"\nTodo correcto: {len(archivos)} archivos " + ("sin dependencia del runtime de Visual C++." if solo_runtime else "compatibles con Windows 7 SP1."))

if __name__ == "__main__":
    main(sys.argv[1], "--solo-runtime" in sys.argv[2:])
