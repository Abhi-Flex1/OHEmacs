# OHEmacs
Emacs ported and adapted for OpenHarmony and HarmonyOS based systems.

Upstream: GNU Emacs 30.1 · SDK: HarmonyOS 6.1.1.125 (API 24) · Bundle: `com.example.ohemacs`

## Status

- ✅ Stage 1 GUI shell: Stage-model HAP with `XComponent(SURFACE)` + NAPI
  (`libentry.so`) + EGL rendering + event queue. Builds, installs, launches,
  and renders on `Harmony_PC_61` emulator (2044×682, touch + resize verified
  via `hilog -T OHEmacs`).
- 🚧 Stage 2 full Lisp engine: `ohos` display backend (`ohosterm.c`, `ohosfns.c`,
  `ohosfont.c`, …) cloned from Android port, plus two-stage cross-compile
  (`--with-dumping=none` → on-device `emacs.pdmp`). Scaffolded in
  `entry/src/main/cpp/emacs-port/`; see `docs/PORTING.md`.

## Build / Install / Run

```bash
ohpm install
hvigorw assembleHap --mode module -p product=default
# -> entry/build/default/outputs/default/entry-default-unsigned.hap
hdc install entry/build/default/outputs/default/entry-default-unsigned.hap
hdc shell "aa start -b com.example.ohemacs -a EntryAbility"
hdc shell "hilog -x -T OHEmacs"
```

See `docs/PORTING.md` for architecture, test logs, and Stage 2 checklist.
See `docs/CROSS_PROBE.md` for OHOS clang `pthread`/`mmap`/`eventfd` probe.
