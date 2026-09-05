export interface EmacsBuffer {
  name: string;
  mode: string;
  content: string;
}

export interface HighlightSegment {
  text: string;
  color: string;
}

const COMMENT_COLOR: string = '#5A7D5A';
const STRING_COLOR: string = '#C4622A';
const KEYWORD_COLOR: string = '#7F007F';
const DEFAULT_COLOR: string = '#000000';

const KEYWORDS: string[] = [
  'if', 'then', 'else', 'elif', 'fi', 'set', 'for', 'in', 'do', 'done',
  'fn', 'let', 'mut', 'return', 'struct', 'use',
  'defcustom', 'defun', 'put', 'setq', 'member',
  'menuentry', 'insmod', 'save_env', 'load_env'
];

export const EMACS_BUFFERS: EmacsBuffer[] = [
  {
    name: '*GNU Emacs*',
    mode: 'Fundamental',
    content: `Welcome to GNU Emacs

GNU Emacs 30.1 (OpenHarmony port, OHEmacs)
Copyright (C) 2025 Free Software Foundation, Inc.

Emacs Tutorial        Learn basic keystroke commands
Emacs Guided Tour     Overview of Emacs features
View Emacs Manual     The Emacs manual as Info
Absence of Warranty   GNU Emacs comes with ABSOLUTELY NO WARRANTY
Copying Conditions    Conditions for redistributing and changing Emacs
Ordering Manuals      Purchasing printed copies of manuals

This is GNU Emacs, one component of the GNU operating system.
To start using Emacs, click one of the links above,
or type M-x tutorial and press Enter below.

Type M-x version to see the Emacs core version.
Type M-x switch <name> to visit another buffer.

Dismiss this splash to open grub.cfg.
GNU Emacs at OHEmacs - GTK look, ohos backend.`
  },
  {
    name: 'grub.cfg',
    mode: 'Conf',
    content: `# grub.cfg - sample GRUB configuration shown in Emacs
set default=0
set timeout=5
set timeout_style=menu

insmod part_gpt
insmod ext2
insmod gfxterm

if [ -s $prefix/grubenv ]; then
  load_env
fi

menuentry 'OpenHarmony' --class ohos {
  set root='hd0,gpt2'
  linux /EFI/BOOT/boot.efi root=/dev/sda2
  initrd /EFI/BOOT/initrd.img
}

if [ "\${grub_platform}" == "efi" ]; then
  save_env -f $prefix/grubenv recordfail
fi

# End of grub.cfg - edit me in the box below`
  },
  {
    name: 'main.rs',
    mode: 'Rust',
    content: `// main.rs - sample Rust buffer shown in Emacs
use std::io::Write;

#[allow(deprecated)]
fn legacy_greeting(name: &str) -> String {
    format!("Hello, {}!", name)
}

fn fib(n: u32) -> u32 {
    if n < 2 {
        return n;
    }
    let a: u32 = fib(n - 1);
    let b: u32 = fib(n - 2);
    a + b
}

fn main() {
    let greeting: String = legacy_greeting("OpenHarmony");
    println!("{} Emacs meets Rust: fib(10) = {}", greeting, fib(10));
    std::io::stdout().flush().unwrap();
}`
  },
  {
    name: 'files.el.gz',
    mode: 'Emacs-Lisp',
    content: `; files.el - trusted-content snippet shown in Emacs
; Copyright (C) 2025 Free Software Foundation, Inc.

(defcustom trusted-content nil
  "List of trusted file paths for local evaluation."
  :type '(repeat string)
  :group 'files
  :version "30.1")

(defun trusted-content-p (path)
  "Return non-nil if PATH is trusted."
  (let ((entry (expand-file-name path)))
    (if (member entry trusted-content)
        t
      (put 'trusted-content 'safe t))))

(put 'trusted-content 'risky-local-variable t)

; Local Variables:
; mode: emacs-lisp
; End:`
  },
  {
    name: '*scratch*',
    mode: 'Lisp Interaction',
    content: `; *scratch* - Lisp Interaction buffer
; Type M-x help below for commands.

(+ 40 2)
; => 42

(message "Hello, OHEmacs!")
; => "Hello, OHEmacs!"

(setq foo 41)
(+ foo 1)
; => 42

;; This buffer is for notes and Lisp evaluation.
;; Use the editor box below to change me.
;; Mode-line shows (Lisp Interaction).`
  }
];

function isKeyword(word: string): boolean {
  let i: number = 0;
  while (i < KEYWORDS.length) {
    if (KEYWORDS[i] === word) {
      return true;
    }
    i = i + 1;
  }
  return false;
}

function isWordChar(ch: string): boolean {
  if (ch.length !== 1) {
    return false;
  }
  const code: number = ch.charCodeAt(0);
  if (code >= 48 && code <= 57) {
    return true;
  }
  if (code >= 65 && code <= 90) {
    return true;
  }
  if (code >= 97 && code <= 122) {
    return true;
  }
  if (ch === '_' || ch === '-' || ch === '?' || ch === '!') {
    return true;
  }
  return false;
}

function commentMarker(mode: string): string {
  if (mode === 'Rust') {
    return '//';
  }
  if (mode === 'Conf') {
    return '#';
  }
  return ';';
}

function highlightCode(code: string, out: HighlightSegment[]): void {
  let buf: string = '';
  let bufIsWord: boolean = false;
  let hasBuf: boolean = false;
  let i: number = 0;
  while (i < code.length) {
    const ch: string = code.charAt(i);
    const w: boolean = isWordChar(ch);
    if (!hasBuf) {
      buf = ch;
      bufIsWord = w;
      hasBuf = true;
    } else if (w === bufIsWord) {
      buf = buf + ch;
    } else {
      if (bufIsWord && isKeyword(buf)) {
        out.push({ text: buf, color: KEYWORD_COLOR });
      } else {
        out.push({ text: buf, color: DEFAULT_COLOR });
      }
      buf = ch;
      bufIsWord = w;
    }
    i = i + 1;
  }
  if (hasBuf) {
    if (bufIsWord && isKeyword(buf)) {
      out.push({ text: buf, color: KEYWORD_COLOR });
    } else {
      out.push({ text: buf, color: DEFAULT_COLOR });
    }
  }
}

export function highlightLine(line: string, mode: string): Array<HighlightSegment> {
  const out: Array<HighlightSegment> = [];
  if (line.length === 0) {
    out.push({ text: ' ', color: DEFAULT_COLOR });
    return out;
  }
  const marker: string = commentMarker(mode);
  const cidx: number = line.indexOf(marker);
  let code: string = line;
  let comment: string = '';
  if (cidx >= 0) {
    code = line.substring(0, cidx);
    comment = line.substring(cidx);
  }
  let cur: string = '';
  let inStr: boolean = false;
  let k: number = 0;
  while (k < code.length) {
    const ch: string = code.charAt(k);
    if (ch === '"') {
      if (inStr) {
        cur = cur + ch;
        out.push({ text: cur, color: STRING_COLOR });
        cur = '';
        inStr = false;
      } else {
        if (cur.length > 0) {
          highlightCode(cur, out);
          cur = '';
        }
        cur = ch;
        inStr = true;
      }
    } else {
      cur = cur + ch;
    }
    k = k + 1;
  }
  if (cur.length > 0) {
    if (inStr) {
      out.push({ text: cur, color: STRING_COLOR });
    } else {
      highlightCode(cur, out);
    }
  }
  if (comment.length > 0) {
    out.push({ text: comment, color: COMMENT_COLOR });
  }
  if (out.length === 0) {
    out.push({ text: ' ', color: DEFAULT_COLOR });
  }
  return out;
}
