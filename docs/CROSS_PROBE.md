// Stage 2 cross-compile probe results (2026-09-05, HarmonyOS 6.1.1.125, API 24).
//
// Toolchain: native/llvm/bin/{aarch64,x86_64}-unknown-linux-ohos-clang (clang 15.0.4)
// Sysroot: native/sysroot/usr/include (musl 1.2.0), libs per-ABI.
//
// Probe TU (pthread + mmap + dlfcn + eventfd + epoll, the primitives Emacs
// needs for threads, pdumper mmap, event-queue wake, module loading):
//
//   #include <pthread.h>
//   #include <sys/mman.h>
//   #include <dlfcn.h>
//   #include <sys/eventfd.h>
//   #include <sys/epoll.h>
//   int main() { pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER; ... }
//
// Results:
//   $ aarch64-unknown-linux-ohos-clang --sysroot=... -c probe.c -o probe-arm64.o  -> OK
//   $ x86_64-unknown-linux-ohos-clang --sysroot=... -c probe.c -o probe-x64.o    -> OK
//   $ file probe-*.o -> ELF 64-bit LSB relocatable, ARM aarch64 / x86-64
//
// Also verified: signal.h exposes SIGWINCH/SIGCHLD/SIGPIPE/SIGUSR1 via
// arch bits/signal.h when compiling through the OHOS toolchain driver
// (direct top-level signal.h read without target triple misses them).
// Runtime caveat: fork/exec/system/popen headers exist but app sandbox blocks
// them; Stage 2 uses NativeChildProcess + libuv (see docs/PORTING.md).
//
// Full Emacs configure probe (next step, not yet run to completion):
//   cd /tmp/ohemacs-src/emacs-30.1
//   ./configure --without-all --with-dumping=none \
//     CC="aarch64-unknown-linux-ohos-clang --sysroot=..." \
//     CFLAGS="-DOHOS_PLATFORM -D__MUSL__"
// Reproduce with: `hdc shell "uname -m"` == aarch64 on Harmony_PC_61.
