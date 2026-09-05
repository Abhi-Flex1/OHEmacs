# OHEmacs GUI + Terminal — Emulator Test Report

Date: 2026-09-05 · Emulator: Harmony_PC_61 (3120x2080) · Bundle: com.example.ohemacs
HAP: entry-default-unsigned.hap 2.7 MB (arm64-v8a + x86_64 libentry.so, 31 ohos_* symbols)
Upstream: GNU Emacs 30.1 · SDK: HarmonyOS 6.1.1.125 API 24

## Pages

- `pages/Index` — GUI: menu File/Edit/Search/M-x/Terminal, buffer *scratch* (ohos backend),
  XComponent SURFACE 2044x568 EGL dark + mode-line/header, M-x minibuffer + Run,
  mode-line `-UUU:---- *scratch*`, Version/Init/add/Key/Expose, log list.
- `pages/Terminal` — batch terminal: black/green log (`emacs --batch` style),
  TextInput + Run, Version/Init/add/Clear/Expose/Key Enter, Back to GUI.
- Router: `@ohos.router` pushUrl Index<->Terminal, main_pages.json both.

## Automated

- `docs/TEST_STAGE2.sh`: 15/15 PASS (build, libs, install, start, hilog bridge ready,
  dual-write, drain, ps, 6 nm symbols).
- `bash docs/TEST_STAGE2.sh` → STAGE2 TEST SUMMARY: PASS=15 FAIL=0.

## Click + Screenshot (uitest)

Tools: `uitest screenCap/dumpLayout/uiInput click/inputText`, `snapshot_display` (jpeg only),
`hilog -x -T OHEmacs`, `ps`, `hdc file recv`.

Layout anchors:
- XComponent [22,256][3098,940] center 1560,598
- Terminal btn [1021,547][1178,623] -> 1099,585
- Back to GUI [544,395][771,471] -> 657,433
- T-Version [1279,1394][1444,1470] -> 1361,1432, T-Run [2468,1296][2584,1372] -> 2526,1334
- File 597,585 Edit 706,585 G-Version 1345,1448

Sequence (all PASS):
1. `aa start` → pid 6827, hilog onCreate/loadContent ok/stage2 ready/callbacks/OnSurfaceCreated/CONFIGURE 2044x568/EGL ok/first frame.
2. `screenCap` gui 1.4 MB PNG 3120x2080 — menu + XComponent + M-x + mode-line visible.
3. `click 1099,585` → layout pages/Terminal, screenCap terminal 1.4 MB — batch log + input + buttons.
4. `click 1361,1432` (Version) → log `GNU Emacs 30.1 (OHEmacs port ...)` + Status update, screenCap version 1.4 MB.
5. `click 657,433` → layout pages/Index, screenCap back 1.4 MB, hilog `nav Terminal -> Index ok` + OnSurfaceCreated/CONFIGURE/first frame.
6. `click File 597,585 / Edit 706,585 / Version 1345,1448` → log `NAPI hello...`, Status version, screenCap clicked 1.4 MB, hilog `bridge->ohos EXPOSE/KEY + drain`, touch `TOUCH 1538,342 points=1 frames=3..6` (XComponent input path, menu buttons correctly EXPOSE/KEY only).

PNGs in /tmp (not committed, 1.4 MB each 3120x2080 RGBA):
- shot_gui_20260905_141453.png, shot_terminal_20260905_141458.png,
  shot_terminal_version_20260905_141506.png, shot_gui_back_20260905_141535.png,
  shot_gui_clicked_20260905_141546.png, gui_check.png
JSON 124-164 KB with ohemacs/Index/XComponent/Terminal/M-x hits.
Hilog 59 lines, no FATAL/crash (only emulator EglWrapper/DGLES warnings).

## Conclusion

GUI + terminal both launch, render, navigate, handle NAPI (version/init/add),
menu/M-x/mode-line, XComponent touch/resize/EGL, all verified by layout + PNG + hilog.
