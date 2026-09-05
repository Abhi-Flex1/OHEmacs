# emacs-port — Stage 3 full-engine roadmap (Emacs 30.1 → OHOS)

Upstream: `/tmp/ohemacs-src/emacs-30.1` (not vendored).
Baseline: `config-ohos.h` in this directory (copy of `/tmp/ohos-config-probe3.h`,
3483-line `src/config.h` for `--host=aarch64-unknown-linux-musl --without-all
--with-dumping=none`). Header-only; **not** in `../CMakeLists.txt` so the
Stage 1/2 HAP build stays intact.

## 1. Two-stage host/target build (mirrors Android `XCONFIGURE`)

Emacs cannot cross-compile in one shot: Elisp must be byte-compiled by a
working `bootstrap-emacs`, then the target `temacs` is dumped.

1. **Host build** (macOS/Linux x86_64/arm64, native cc):
   ```sh
   cd /tmp/ohemacs-src/emacs-30.1
   ./configure --without-all --with-dumping=pdumper
   make -j$(nproc) bootstrap-emacs   # produces src/bootstrap-emacs + *.elc
   ```
2. **Target build** (OHOS clang 15.0.4, musl 1.2.0 sysroot), minimal first:
   ```sh
   cd /tmp/ohemacs-src/emacs-30.1
   PATH=/usr/bin:/bin:$PATH \
   ./configure --host=aarch64-unknown-linux-musl --without-all \
     --with-dumping=none --without-threads --without-modules \
     'CFLAGS=-DOHOS_PLATFORM -D__MUSL__' LDFLAGS=-L/tmp/ohemacs-stub
   # → src/config.h should match config-ohos.h baseline
   make -j$(nproc) libemacs.so   # TTY-only first; no pdumper yet
   ```
   `--host=aarch64-unknown-linux-musl` is an alias: `config.sub` in 30.1 has
   no `ohos` triplet (see §2). `LDFLAGS=-L/tmp/ohemacs-stub` + `CFLAGS`
   above are the probe settings recorded in `EMACS_CONFIG_OPTIONS`.

## 2. `XCONFIGURE=ohos` plan + `HAVE_OHOS` `configure.ac` patch points

Android builds with `XCONFIGURE=android CC=... ./configure ...`; we add the
same for `ohos`. Until then the musl alias (§1) stands in.

Patch points in upstream `configure.ac` + `src/` (model on `HAVE_ANDROID`):

- `build-aux/config.sub` + `config.guess`: accept
  `aarch64-*-ohos*` / `x86_64-*-ohos*` (else `configure: error: ... not recognised`).
- `configure.ac`: add `*-ohos* | *-openharmony*)` OS case next to
  `*-android*)` — set `opsys=ohos`, `HAVE_OHOS`, `OHOS_TRUE`, sysroot/lib
  defaults, disable `fork/exec/pty/sound/dbus` probes that the sandbox blocks.
- `src/config.in` (via `autoheader`): new `HAVE_OHOS` witness; regenerate
  `config-ohos.h` with the true `--host=aarch64-linux-ohos` once patched.
- `src/frame.h` / `src/dispextern.h` / `src/termhooks.h`: add `FRAME_OHOS_P`,
  `output_method == output_ohos`, redisplay-interface slots (clone the
  `HAVE_ANDROID` blocks).
- `src/keyboard.c` / `src/term.c` / `src/xdisp.c`: wire `ohos_read_socket`
  (see `ohosterm.cpp`) into the event loop where `android_read_socket` sits.
- `src/Makefile.in` / `lib/Makefile.in`: add `ohos.o ohosterm.o ohosfns.o
  ohosfont.o ohosmenu.o ohosselect.o` objects conditioned on `HAVE_OHOS`,
  plus `libemacs.so` + `emacs.pdmp` install rules that `hvigor` (not
  `aapt/d8/zipalign`) packages (`abiFilters:[arm64-v8a]`).

Acceptance: `./configure --host=aarch64-linux-ohos` succeeds with no musl
alias and defines `HAVE_OHOS` in the regenerated `config-ohos.h`.

## 3. Termcap strategy

SDK musl 1.2.0 ships no ncurses/tinfo. Today:

- `/tmp/ohemacs-stub/termcap-stub.c` defines `BC/UP/PC/ospeed` +
  `tputs/tgetent/tgetflag/tgetnum/tgetstr/tgoto`, archived as `libtermcap.a`
  plus aliases `libcurses.a libncurses.a libterminfo.a libtinfo.a`. Only the
  configure link probes pass (`TERMINFO=1`, `TERMINFO_DEFINES_BC=1` in
  `config-ohos.h`). Nothing actually draws via termcap.
- Keep the stub until the GUI backend (`ohosterm`) owns all drawing; TTY
  support stays link-only.

Next: port (or vendor a minimal) ncurses/terminfo, or write a fuller terminfo
stub + `--without-gpm`; then re-run configure and confirm `TERMINFO` still 1
without `LDFLAGS=-L/tmp/ohemacs-stub`. Do not ship the stub in the HAP.

## 4. pdumper on-device steps (`--with-dumping=none` → `pdumper`)

Baseline has `HAVE_PDUMPER` / `HAVE_UNEXEC` `#undef` (`--with-dumping=none`,
`--without-threads`). Re-enable in order:

1. Link TTY-only `libemacs.so` with dumping off; verify it loads via NAPI.
2. Re-run target configure with `--without-all --with-dumping=pdumper`
   (keep `--without-threads` first), rebuild `temacs`.
3. On host: `make bootstrap-emacs` already produced `*.elc`. Copy `temacs` +
   `lisp/` to device (or HAP assets staging dir).
4. On device/emulator via `hdc shell`: run the pbootstrap dump, e.g.
   `temacs --temacs=pbootstrap --batch -l loadup bootstrap` (exact loadup
   line follows `src/Makefile.in`; see `docs/PORTING.md`), producing
   `emacs.pdmp`. Check fingerprint matches the `temacs` that dumped it.
5. Ship `emacs.pdmp` in HAP assets; at startup `libemacs.so` maps it with
   `mmap` (musl OK, verified in `docs/CROSS_PROBE.md`). Compare startup
   `none` vs `pdump`, then re-enable threads (`--with-threads`) and repeat.

Sandbox notes: `mmap`/`eventfd`/`epoll`/`timerfd` are fine; `fork/exec/pty`
are blocked — keep `call-process`/async-subproc/`pty.c` stubbed and use
`NativeChildProcess` + `libuv` (see `docs/PORTING.md` § constraints).

## 5. Library re-enable order

`--without-all` leaves `HAVE_JANSSON/GMP/ZLIB/GNUTLS/SQLITE3/LIBXML2/
FREETYPE/HARFBUZZ/CAIRO/X11/MODULES/NATIVE_COMP/TREE_SITTER` all `#undef`.
Re-enable one at a time via `lycium`/vendored NDK prebuilts, re-running
configure + checking the corresponding `HAVE_*` flips to 1:

```
jansson → gmp → zlib → libxml2 → sqlite3 → png/jpeg/gif/tiff/webp → freetype
→ harfbuzz → cairo → gnutls → tree-sitter → (modules, native-comp last)
```

Fonts Shortcut: before FreeType/HarfBuzz land, use `sfntfont.c` +
`OH_Drawing_*` (`libnative_drawing.so`) + `RegisterFontBuffer` (see
`ohosfont.cpp`). IME via `libohinputmethod.so` → `textconv.c` handlers.

Also: musl 1.2.0 lacks `<stdbit.h>` / `<stdckdint.h>` (`HAVE_STDBIT_H` /
`HAVE_STDCKDINT_H` `#undef` in baseline) — backport gnulib `stdbit`/
`stdckdint` modules or move to a sysroot that provides them before enabling
code paths needing C23 bit ops.

## 6. File map

```
entry/src/main/cpp/emacs-port/
  config-ohos.h  # THIS BASELINE (generated src/config.h copy + OHOS header
                 # comment: musl alias, termcap stub, PATH diff fix, TODOs).
                 # Reference only — not compiled, not in CMakeLists.txt.
  ohos.cpp       # Stage 2 event queue (mirrors android.c:244-761 event-queue +
                 # android_select; eventfd wake + ohos_select/pselect fold-in).
                 # Full port → ohos.c (NAPI entry + select + signal handling).
  ohosterm.cpp/.h# Stage 2 redisplay stub (mirrors androidterm.c:6934:
                 # create_terminal + redisplay_interface + read_socket +
                 # glyph-string/cursor fns via OH_Drawing/EGL). Biggest clone.
  ohosfns.cpp    # Stage 2 frame-parm/color stubs (mirrors androidfns.c:3788
                 # x-create-frame, x-set-frame-parameters, display-color-p).
  ohosfont.cpp   # Stage 2 font stub (mirrors androidfont.c:1102 +
                 # sfntfont-android.c:821; sfntfont + OH_Drawing, no HarfBuzz).
  ohosmenu.cpp   # Stage 2 popup/dialog stubs (mirrors androidmenu.c:860).
  ohosselect.cpp # Stage 2 clipboard stubs (mirrors androidselect.c:1220).
  ohosgui.h      # Shared structs (mirrors androidgui.h:885: events, GC,
                 # window/frame handles used by all of the above).
  README.md      # This file.
```

Deferred (clone later, see `docs/PORTING.md`): `ohosvfs.c` (from
`androidvfs.c:7950`, app-sandbox HOME/TMPDIR), full IME `textconv` wiring,
`FRAME_OHOS_P` plumbing.

## 7. Build-safety contract

- New files here are headers/docs only unless explicitly wired into
  `../CMakeLists.txt`. `config-ohos.h` + `README.md` change no build inputs.
- Stage 1/2 build stays: `hvigorw assembleHap --mode module -p product=default`
  → `BUILD SUCCESSFUL`, HAP installs/launches on `Harmony_PC_61`.
- When the full engine lands, its `libemacs.so` build consumes `config-ohos.h`
  as `src/config.h` out-of-tree; never `#include` it from Stage 1/2 NAPI
  sources.
