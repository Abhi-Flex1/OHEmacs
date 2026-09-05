# OHEmacs (GNU Emacs for OpenHarmony & HarmonyOS)

> **GNU Emacs 30.1 ported and adapted for OpenHarmony and HarmonyOS devices.**  
> Delivering both a native aarch64 terminal CLI (`emacs` / `ohemacs`) for the HarmonyOS shell and a desktop-grade GUI application matching GNU Emacs on Linux (GTK/Lucid) and Windows.

---

## 📸 Screenshots

### Desktop GUI Experience
| Main Window (`*scratch*`) | Dropdown Menus & Accelerators |
| :---: | :---: |
| ![GUI Main Window](screenshots/gui_main_scratch.png) | ![GUI File Menu](screenshots/gui_file_menu.png) |

| Multi-Buffer & Syntax Highlighting (`main.rs`) | Dual Window Split with Native EGL Surface |
| :---: | :---: |
| ![GUI Rust Mode](screenshots/gui_rust_mode.png) | ![Native Surface Split](screenshots/gui_main_scratch.png) |

### Terminal Experiences
| Native HarmonyOS Terminal CLI (`hdc shell /data/local/tmp/emacs`) | In-App Dedicated Terminal Console (`*shell*`) |
| :---: | :---: |
| ![Native CLI Terminal](screenshots/terminal_native_cli.png) | ![In-App Terminal Console](screenshots/terminal_inapp.png) |

---

## ✨ Features

### 1. Standalone Native Terminal CLI (`emacs` / `ohemacs`)
- **Native aarch64 ELF executable** compiled using the OpenHarmony LLVM NDK toolchain (`musl libc`).
- Runs directly inside the device or emulator terminal shell (`hdc shell /data/local/tmp/emacs`).
- **Batch mode (`--batch`, `--eval`, `-l`, `--version`)**:
  - Evaluate Lisp expressions non-interactively with embedded evaluation:
    ```bash
    /data/local/tmp/emacs --batch --eval '(+ 19 23)'
    # -> 42
    /data/local/tmp/emacs --batch --eval '(message "Hello from HarmonyOS!")'
    # -> "Hello from HarmonyOS!"
    ```
  - Run Elisp source files with `-l <file.el>`.
- **Interactive TUI Mode (`emacs -nw` or `emacs <filename>`)**:
  - Raw `termios` terminal handling with alternate screen buffer support.
  - ANSI status mode-line: `-U:--- <buffer> Top (L,C) (<mode>)`.
  - Classic Emacs keybindings: `C-x C-s` (save), `C-x C-f` (open), `C-x C-c` (quit), `C-g` (cancel), `M-x` (command).

### 2. Desktop-Faithful GUI Application
- **Desktop Window Chrome**: Clean window title bar indicating active buffer and EGL graphics engine status.
- **Classic Emacs Menu Bar**: Full drop-down menus (`File`, `Edit`, `Options`, `Buffers`, `Tools`, `<Major-Mode>`, `Help`) with keyboard accelerator annotations.
- **Compact 28px Desktop Toolbar**: Vector icons (`✚` New, `▤` Open, `▣` Save, `✕` Close, `↩` Undo, `↪` Redo, `✂` Cut, `❐` Copy, `⎘` Paste, `⌕` Search, `ⓘ` Info, `⤴` Split Toggle).
- **Tab Bar (`tab-bar-mode`)**: Tabbed browsing across buffers (`*scratch*`, `main.rs`, `main.c`, `notes.md`) with close buttons.
- **Full-Height Buffer Canvas**: 8px fringe, right-aligned line numbers, and Font-Lock syntax highlighting across Elisp, Rust, C, Python, and Markdown.
- **Window Splitting (`C-x 2` / `C-x 1`)**: Integrated dual-window split containing the native EGL Surface (`*Native EGL Surface*`), keeping the native C++ rendering pipeline alive while maximizing editing space.
- **Status Mode-Line & Minibuffer**: Authentic GNU Emacs mode-line with buffer status, row/column indicators, and interactive minibuffer / echo area (`M-x`).

### 3. Native C++ & NAPI Bridge
- Cloned and adapted `ohos` display backend (`ohosterm.cpp`, `ohosfns.cpp`, `ohosfont.cpp`, `ohosselect.cpp`, `ohosmenu.cpp`).
- Stage 2 dual-write event queue connecting ArkTS touch, key, and window lifecycle events with native POSIX `wakefd` sockets.
- NAPI bridge exposing: `ohosInit`, `ohosShutdown`, `ohosSendEvent`, `getColor`, `setSelection`, `getSelection`, `popupMenu`.

---

## 🚀 Quick Start

### 1. Running the Native Terminal CLI in HarmonyOS Shell
```bash
# Enter device shell
/Users/abhi/Developer/command-line-tools/sdk/default/openharmony/toolchains/hdc shell

# Print version
/data/local/tmp/emacs --version

# Run batch evaluation
/data/local/tmp/emacs --batch --eval "(+ 123 456)"

# Run interactive terminal editor
/data/local/tmp/emacs /data/local/tmp/test.el
```

### 2. Launching the GUI App
```bash
# Launch the application EntryAbility
/Users/abhi/Developer/command-line-tools/sdk/default/openharmony/toolchains/hdc shell aa start -a EntryAbility -b com.example.ohemacs
```

---

## 🛠 Building from Source

### Prerequisites
- OpenHarmony Command-Line Tools / DevEco Studio SDK (API 24+ / HarmonyOS 6.1+)
- `ohpm` package manager
- `hvigorw` build tool
- `hdc` device toolchain

### Build Steps

1. **Install Dependencies**:
   ```bash
   ohpm install
   ```

2. **Assemble HAP & APP Packages**:
   ```bash
   # Assemble standalone HAP
   hvigorw assembleHap --mode module -p product=default

   # Assemble full APP package
   hvigorw assembleApp -p product=default
   ```
   Built packages:
   - HAP: `entry/build/default/outputs/default/entry-default-unsigned.hap`
   - APP: `build/outputs/default/OHEmacs-default-unsigned.app`

3. **Compile Native Terminal CLI Binary**:
   ```bash
   bash scripts/build_cli.sh
   # -> entry/src/main/resources/rawfile/emacs
   ```

4. **Install & Run on Device/Emulator**:
   ```bash
   hdc install entry/build/default/outputs/default/entry-default-unsigned.hap
   hdc shell aa start -a EntryAbility -b com.example.ohemacs
   ```

---

## 🧪 Verification & Automated Tests

Run the full Stage 2 automated test suite:
```bash
bash docs/TEST_STAGE2.sh
```

**Test Summary**:
```text
[PASS] hvigorw assembleHap BUILD SUCCESSFUL
[PASS] HAP contains libs/arm64-v8a/libentry.so
[PASS] HAP contains libs/x86_64/libentry.so
[PASS] hdc install bundle successfully
[PASS] aa start ability successfully
[PASS] hilog shows 'stage2 bridge ready' (ohos_init_events + redraw cb)
[PASS] hilog shows 'bridge->ohos' dual-write (Stage2 queue)
[PASS] hilog shows legacy 'drain ' (internal queue intact)
[PASS] ps shows com.example.ohemacs running
[PASS] nm finds ohos_write_event
[PASS] nm finds ohos_pending
[PASS] nm finds ohos_next_event
[PASS] nm finds ohos_init_events
[PASS] nm finds ohos_read_socket
[PASS] nm finds ohos_set_redraw_callback
==============================================
STAGE2 TEST SUMMARY: PASS=15 FAIL=0
RESULT: PASS
```

---

## 📜 License
GNU Emacs is free software licensed under the **GNU General Public License version 3** (GPLv3).
Portions of the OpenHarmony scaffolding and ArkTS bindings are available under Apache 2.0.
