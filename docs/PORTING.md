# OHEmacs — GNU Emacs 30.1 port to OpenHarmony

Bundle: `com.example.ohemacs` · SDK: HarmonyOS 6.1.1.125 (API 24) · Upstream: Emacs 30.1
Emulator: `Harmony_PC_61` (aarch64, Toybox) · Toolchain: OHOS clang 15.0.4 (musl 1.2.0)

## What "full port" means here

Emacs has no OpenHarmony display backend upstream. Like the Android port
(`src/android*.c` + `java/org/gnu/emacs/*`, ~31k C + ~15k Java), a full
OpenHarmony GUI port needs a new `ohos` backend:

```
ArkTS UIAbility + XComponent(SURFACE)
  -> NAPI (libentry.so) + OH_NativeXComponent callbacks
  -> OH_NativeWindow (EGL or OH_Drawing software path)
  -> ohosterm.c redisplay_interface (cloned from androidterm.c)
  -> Lisp core (frame.c, xdisp.c, keyboard.c, font.c via sfntfont, textconv.c IME)
```

This repo implements that in stages. Stage 1 (landed) proves the full
ArkTS→native→surface path on the emulator with rigorous logs. Stage 2
(full Lisp engine) is scaffolded and tracked below.

## Stage 1 — DONE (this HAP)

- Stage-model HAP with `EntryAbility`, `XComponent{id:ohemacs_xc,type:SURFACE,libraryname:entry}`
- Native `libentry.so` via CMake + `ohos.toolchain.cmake`:
  - `napi_init.cpp`: NAPI module `entry` (`hello`, `add`, `getEmacsVersion`,
    `initEmacs`, `sendKey`, `sendExpose`, `testXComponent`)
  - `ohemacs_bridge.{h,cpp}`: pthread event queue (mirrors `android.c`
    `android_init_events`/`android_write_event`, cap 1024), EGL rendering
    (`eglGetDisplay` → `eglCreateWindowSurface(NativeWindow)` → `glClear` +
    mode-line/header strips → `eglSwapBuffers`), XComponent callbacks
    (`OnSurfaceCreated/Changed/Destroyed`, `DispatchTouchEvent`),
    `SetNeedSoftKeyboard(true)` for IME Stage 2.
- UI (`Index.ets`): Emacs version/status, 2044×682 surface on 2in1 emulator,
  buttons for Version / Init Emacs / add / Key A / Enter / Expose, scrolling log.
- Build: `ohpm install` + `hvigorw assembleHap --mode module -p product=default`
  → `entry/build/default/outputs/default/entry-default-unsigned.hap` (2.6 MB)
- Verified on emulator (see Testing below):
  - `OnSurfaceCreated`, `CONFIGURE 2044x682`, `EGL init ok 1.5`, `first frame drawn`

## Stage 2 — Full Lisp engine (in progress, scaffolded)

Upstream: `/tmp/ohemacs-src/emacs-30.1` (tarball `emacs-30.1.tar.xz`, 52 MB).
Reference: `src/android.c:7377`, `androidterm.c:6934`, `androidgui.h:885`,
`androidfns.c:3788`, `androidfont.c:1102`, `androidmenu.c:860`,
`androidselect.c:1220`, `androidvfs.c:7950`, `sfntfont-android.c:821`.

### Files to create (mirroring Android, JNI→NAPI)

```
entry/src/main/cpp/emacs-port/
  ohosgui.h      # event union, GC, window structs (clone androidgui.h)
  ohosterm.h/c   # redisplay_interface, glyph drawing via OH_Drawing (clone androidterm.c)
  ohosfns.c      # x-* Lisp fns, frame parms (clone androidfns.c subset)
  ohosmenu.c     # popup/dialog (clone androidmenu.c)
  ohosselect.c   # clipboard/pasteboard (clone androidselect.c)
  ohosfont.c     # sfntfont wrapper + OH_Drawing fonts, HarfBuzz off (clone androidfont.c)
  ohos.c         # event queue + ohos_select + NAPI entry (clone android.c:244-761,1933,3662)
  ohosvfs.c      # deferred; stub with app sandbox HOME/TMPDIR
```

Estimate: ~14–18k C + ~2k ArkTS/C++ glue (vs 31k+15k Android).

### Build plan (two-stage, like Android XCONFIGURE)

1. Host: native `--without-all --with-dumping=pdumper` → `bootstrap-emacs` for `.elc`.
2. Target: `aarch64-linux-ohos-clang --sysroot=.../sysroot`
   `--without-x --without-toolkit --without-xml2 --without-gnutls --without-pop
   --without-sound --without-dbus --without-gconf --without-selinux
   --without-imagemagick --without-xpm --without-jpeg --without-png
   --without-gif --without-tiff --without-rsvg --without-webp --without-cairo
   --without-harfbuzz --without-libotf --without-m17n-flt --without-lcms2
   --without-sqlite3 --without-tree-sitter --without-native-compilation
   --without-threads --without-modules --with-dumping=none`
   → `libemacs.so` (TTY only first), then enable `pdumper` on-device
   (`temacs --temacs=pbootstrap` via `hdc shell`, ship `emacs.pdmp` in HAP assets).
3. HAP packaging replaces Android `aapt/d8/zipalign` with `hvigor`
   (`abiFilters:[arm64-v8a]`, `libs/arm64-v8a/libemacs.so` + `emacs.pdmp` assets).
4. Re-enable libs one-by-one via `lycium`/vendored NDK prebuilts
   (`jansson → png → xml2 → sqlite3 → gnutls`).

### OHOS constraints (verified in sysroot)

- libc musl 1.2.0: `pthread`, `mmap`, `epoll/timerfd/eventfd`, `dlopen` (own .so) OK.
- `fork/exec/system/popen`, raw ptys, cross-pid signals: headers exist but
  sandbox/seccomp blocks at runtime. Use single-process + `NativeChildProcess`
  (`libchild_process.so`) + `libuv` loop; stub `call-process`, async subprocs,
  `pty.c`, `SIGWINCH`.
- Fonts: no FreeType/HarfBuzz initially; use `sfntfont.c` + `OH_Drawing_*`
  (`libnative_drawing.so`) + `RegisterFontBuffer` for bundled TTF.
- IME: `libohinputmethod.so` `TextEditorProxy` → same `textconv.c` handlers as
  `android_handle_ime_event`.
- Drawing: `OHNativeWindow_RequestBuffer/FlushBuffer` + `OH_Drawing_Canvas*`
  or EGL (this scaffold uses EGL). `XComponent SURFACE` = separate plane;
  `TEXTURE` if compositing needed.

## Testing

### Automated (Stage 1, all passing on Harmony_PC_61)

1. `hvigorw assembleHap` → BUILD SUCCESSFUL (native + ArkTS).
2. `hdc install entry-...-unsigned.hap` → `install bundle successfully`.
3. `hdc shell "aa start -b com.example.ohemacs -a EntryAbility"` → `start ability successfully`.
4. `hdc shell "hilog -x -T OHEmacs"` shows:
   ```
   EntryAbility onCreate
   onWindowStageCreate / loadContent ok / onForeground
   callbacks registered, softkeyboard on
   Init: XComponent auto-registered
   OnSurfaceCreated
   drain CONFIGURE 2044 x 682
   EGL init ok 1.5
   first frame drawn 2044 x 682
   XComponent onLoad ohemacs_xc
   ```
5. `hdc shell "ps -ef | grep ohemacs"` → `com.example.ohemacs` running.
6. Native libs in HAP: `libentry.so` for `arm64-v8a` + `x86_64` (see
   `entry/.cxx`, `entry/build/default/intermediates`).
7. Cross-compile probe: OHOS clang compiles `pthread`/`mmap`/`dlfcn` TU for
   both ABIs (see `docs/CROSS_PROBE.md`).

### Manual (emulator UI)

- Launch OHEmacs from launcher → dark Emacs frame with grey mode-line +
  header, version text, log list.
- Tap Version / Init Emacs / add(40,2) / Key A / Enter / Expose → status +
  log update, `hilog` shows `drain KEY/EXPOSE`, frame counter increments,
  surface tint shifts on touch (input→render proof).

### Stage 2 acceptance (TODO)

- [ ] `libemacs.so` links for `arm64-v8a` with `--with-dumping=none`.
- [ ] Synthetic `KEY/EXPOSE/CONFIGURE` injection drives `ohos_read_socket`.
- [ ] Software glyph rects → `FlushBuffer`, resize via `OnSurfaceChanged`.
- [ ] Touch/mouse/key → `ohos_write_event`, IME round-trip via `textconv`.
- [ ] `FRAME_OHOS_P` in `frame.h/dispextern.h/termhooks.h`, frame parms/colors.
- [ ] On-device `emacs.pdmp` generation + fingerprint check.
- [ ] Startup time `none` vs `pdump`, `malloc`/`eventfd` sanity under release.

## Layout

```
hvigorfile.ts  build-profile.json5  oh-package.json5  hvigor/
AppScope/app.json5  entry/  docs/PORTING.md (this file)
entry/src/main/ets/{entryability/EntryAbility.ets,pages/Index.ets}
entry/src/main/cpp/{CMakeLists.txt,napi_init.cpp,ohemacs_bridge.{h,cpp}}
entry/src/main/cpp/emacs-port/  # Stage 2 stubs (ohosgui.h, ohosterm stub)
```

Upstream Emacs source is NOT vendored (52 MB); fetch with:
`curl -L -o /tmp/emacs-30.1.tar.xz https://ftp.gnu.org/gnu/emacs/emacs-30.1.tar.xz`
