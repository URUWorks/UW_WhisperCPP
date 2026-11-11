/* clock_gettime() para macOS 10.11.
 * libSystem solo lo trae desde macOS 10.12, pero ggml (ggml_time_us) y libc++ (std::chrono)
 * lo llaman. Con una versión mínima de 10.11 el compilador lo enlaza como "weak" y en 10.11
 * queda en NULL: el programa se cae en cuanto mide el tiempo.
 * Este objeto se enlaza dentro de cada binario como símbolo oculto, así que las llamadas se
 * resuelven aquí y no en libSystem (también en macOS nuevos, con el mismo resultado). */
#include <errno.h>
#include <stdint.h>
#include <sys/time.h>
#include <mach/mach_time.h>

/* Valores de clockid_t de <time.h> */
#define UW_CLOCK_REALTIME 0
#define UW_CLOCK_MONOTONIC_RAW 4
#define UW_CLOCK_MONOTONIC_RAW_APPROX 5
#define UW_CLOCK_MONOTONIC 6
#define UW_CLOCK_UPTIME_RAW 8
#define UW_CLOCK_UPTIME_RAW_APPROX 9

int uw_clock_gettime(int clk, struct timespec *ts) __asm__("_clock_gettime")
    __attribute__((visibility("hidden")));

int uw_clock_gettime(int clk, struct timespec *ts) {
    if (clk == UW_CLOCK_REALTIME) {
        struct timeval tv;
        gettimeofday(&tv, NULL);
        ts->tv_sec = tv.tv_sec;
        ts->tv_nsec = (long)tv.tv_usec * 1000;
        return 0;
    }
    if (clk == UW_CLOCK_MONOTONIC || clk == UW_CLOCK_MONOTONIC_RAW || clk == UW_CLOCK_MONOTONIC_RAW_APPROX ||
        clk == UW_CLOCK_UPTIME_RAW || clk == UW_CLOCK_UPTIME_RAW_APPROX) {
        static mach_timebase_info_data_t tb;
        if (tb.denom == 0) mach_timebase_info(&tb);
        uint64_t t = mach_absolute_time();
        uint64_t ns = (t / tb.denom) * tb.numer + (t % tb.denom) * tb.numer / tb.denom;
        ts->tv_sec = (time_t)(ns / 1000000000u);
        ts->tv_nsec = (long)(ns % 1000000000u);
        return 0;
    }
    errno = EINVAL;
    return -1;
}
