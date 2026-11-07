/* Constantes del kernel de Linux (ABI estable) que faltan en las cabeceras de glibc 2.17 /
 * kernel 3.10 de manylinux2014 para aarch64. ggml las usa para detectar en tiempo de
 * ejecución DOTPROD, SVE, SVE2, I8MM y SME. En un kernel viejo getauxval(AT_HWCAP2)
 * devuelve 0, así que simplemente no se detectan y se usa una variante más básica. */
#ifndef AT_HWCAP2
#define AT_HWCAP2 26
#endif
#ifndef HWCAP_ASIMDDP
#define HWCAP_ASIMDDP (1 << 20)
#endif
#ifndef HWCAP_SVE
#define HWCAP_SVE (1 << 22)
#endif
#ifndef HWCAP2_SVE2
#define HWCAP2_SVE2 (1 << 1)
#endif
#ifndef HWCAP2_I8MM
#define HWCAP2_I8MM (1 << 13)
#endif
#ifndef HWCAP2_SME
#define HWCAP2_SME (1 << 23)
#endif
#ifndef HWCAP2_SME2
#define HWCAP2_SME2 (1UL << 37)
#endif
#ifndef PR_SVE_GET_VL
#define PR_SVE_GET_VL 51
#endif
#ifndef PR_SVE_VL_LEN_MASK
#define PR_SVE_VL_LEN_MASK 0xffff
#endif
