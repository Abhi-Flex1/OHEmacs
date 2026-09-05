# Compact Desktop Remake Verification

Build 1a2dfcf · HAP 2.8 MB · pid 10338 · XComponent 2088x188 EGL ok

## Fixes vs old pill UI

- Root Column padding 12 → 0, Row margins 4-12 → 0-2.
- Menu: blue Buttons 32-40px → plain Text h26 #F0F0F0 fs13 pad 2/6, gap 0.
- Toolbar: blue pills → 28x28 Text icons fs16 radius3 gap2 h36 #F0F0F0 bottom 1px #C0C0C0:
  ✚ ▤ ▣ ✕ ↩ ↪ ✂ ❐ ⎘ ⌕ ⓘ ⤴ (New/Open/Save/Close/Undo/Redo/Cut/Copy/Paste/Search/Info/Jump).
- Tabs h24 #D6D6D6, active #FFF bold top 2px #0A84FF, inactive #DEDEDE fs12.
- Fringe 8px #E8E8E8 both sides, line numbers 36px #999 12px right.
- Buffer List padding 0 divider 0 fs13 mono lh16, true faces:
  default #000/#FFF, comment #B22222, string #8B2252, keyword #A020F0,
  builtin #483D8B, function #0000FF, variable #A0522D, type #228B22,
  constant #008B8B, warning #FF0000.
- Mode-line h22 fs12 #E5E5E5 top/bottom 1px #999 pad 0-4 margin 0.
- Minibuffer h22, echo h22, log h60 fs10, editor TextArea h100 fs13 pad2.
- Splash centered w600: Welcome 18px #CC0000, version 12px #333, links 13px #0000EE Text.

## Tests (all PASS)

- Launch pid 10338 cold-start 67 hilog lines: onCreate/loadContent/ohos_init/callbacks/OnSurfaceCreated/CONFIGURE 2088x188/EGL ok/first frame.
- Layout 266 KB pages/Index: 8 menu Texts (no pills, 4 Buttons total incl Go + chrome),
  12 toolbar unicodes 53px phys, 5 tabs, fringe w15 phys, XComponent 2090x190,
  mode-line h42 phys (=22 logical), M-x + Go.
- Tabs: main.rs → fn main/println + Rust mode-line + splash PNG 1.6 MB;
  *GNU Emacs* → Welcome/Tutorial + Fundamental + splash PNG 1.5 MB; back grub.cfg.
- Save toolbar → `Wrote grub.cfg (24 lines)`; M-x version → NAPI version + KEY 2011 hilog.
- Terminal nav + ls + back intact (prior suite).
- PNGs /tmp 1.5-1.6 MB 3120x2080: compact_gui/rust/splash/final. No FATAL.
