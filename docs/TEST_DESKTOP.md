# Desktop Emacs Verification (screenshots match reference)

Build 922aea9 · HAP 2.8 MB · pid 8030 · XComponent 2044x226 EGL ok

## Reference mapping

- Menu `File Edit Options Buffers Tools Help + Conf/Rust/Emacs-Lisp/Fundamental + Terminal`
  matches `File Edit Options Buffers Tools Conf Help` / `Emacs-Lisp` / dark theme shots.
- Toolbar `+ New Open Save Close Undo Cut Copy Paste Search`
  matches `Save Undo` scissors/clipboard/search icons (text buttons, same order/function).
- Tabs `*GNU Emacs* grub.cfg main.rs files.el.gz *scratch*`
  matches multi-buffer (`grub.cfg`, `main.rs`, `files.el.gz`, `*GNU Emacs*`, `*Help*`).
- Buffers:
  - `*GNU Emacs*` splash: red `Welcome to GNU Emacs`, blue links
    (Tutorial/Guided Tour/Manual/Warranty/Copying/Ordering), version 30.1,
    Copyright, Dismiss — matches splash + annotated Frame/Menu/Toolbar/Window/Buffer/Status/Mini-Buffer diagram.
  - `grub.cfg` Conf: `set/if/then/save_env`, mode-line `-:-- grub.cfg 100% L24 (Conf)`.
  - `main.rs` Rust: `fn main/println!/allow(deprecated)`, `-:-- main.rs 100% L22 (Rust)`
    matches dark Rust shot (`diary.org/main.rs`, Flymake/eglot mode-line style).
  - `files.el.gz` Emacs-Lisp: `defcustom trusted-content`, `-:-- files.el.gz ... (Emacs-Lisp)`
    matches elisp Help shot.
- Mode-line grey `-:-- <buf> <pct>% L<n> (<mode>)` + echo (`Switched to …`, `Wrote …`, `… is undefined`)
  matches `-:-- grub.cfg 3% L11`, `U:%%- *GNU Emacs* All L3`, `u is undefined`.
- Minibuffer `M-x save|open|switch|tutorial|version` + Go, NAPI Enter key.
- `*shell*` Terminal: `ls/buffers/open/echo/uname/pwd/version/init/add/clear/C-g`,
  mode-line `-:-- *shell* Bot L<n> (Shell)` — desktop `M-x shell` equivalent.
- ohos surface retained (height 120, `surface ready`, CONFIGURE/EGL/first frame).

## Clicks (uitest, all PASS)

- Tabs: *GNU Emacs* 1250,698 → splash Welcome/Tutorial; main.rs 1580,698 → fn main;
  files.el.gz 1733,698 → defcustom; grub.cfg 1432,698 → back.
- Toolbar Save 1322,602 → `Wrote grub.cfg (24 lines)`; Undo 1566,602 → demo echo.
- M-x `version` → NAPI version echo + KEY 2011 hilog; `switch main.rs` → buffer + mode-line
  (incl. IME full-width `。` error path → English keyboard fix).
- Terminal 1988,506 → pages/Terminal; Version 1361,1432 → `GNU Emacs 30.1…`;
  `ls` → 6 buffers listed; Back 657,433 → Index + OnSurfaceCreated/CONFIGURE/first frame.
- File 597,585 / Edit 706,585 / G-Version 1345,1448 → hello/version + EXPOSE/KEY, no crash.

PNGs /tmp 1.5-1.6 MB 3120x2080: desk_splash, desk_rust, desk_elisp, desk_term,
desk_term_ls, desktop_check, shot_gui_clicked. Layout JSON 135-174 KB with
Welcome/fn main/defcustom/*shell* hits. Hilog stage2 ready/CONFIGURE/EGL/EXPOSE/KEY/nav ok.
