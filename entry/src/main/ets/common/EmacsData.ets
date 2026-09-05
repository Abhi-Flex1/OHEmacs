export interface EmacsBuffer {
  name: string;
  mode: string;
  content: string;
}

export interface HighlightSegment {
  text: string;
  color: string;
}

// True GNU Emacs light-bg font-lock defaults.
const DEFAULT_COLOR: string = '#000000';
const COMMENT_COLOR: string = '#B22222';
const STRING_COLOR: string = '#8B2252';
const DOC_COLOR: string = '#8B2252';
const KEYWORD_COLOR: string = '#A020F0';
const BUILTIN_COLOR: string = '#483D8B';
const FUNCTION_COLOR: string = '#0000FF';
const VARIABLE_COLOR: string = '#A0522D';
const TYPE_COLOR: string = '#228B22';
const CONSTANT_COLOR: string = '#008B8B';
const WARNING_COLOR: string = '#FF0000';

const KEYWORDS: string[] = [
  'if', 'then', 'else', 'elif', 'fi', 'set', 'for', 'in', 'do', 'done',
  'fn', 'let', 'mut', 'return', 'struct', 'use',
  'defcustom', 'defun', 'put', 'setq', 'while', 'unless', 'when', 'cond',
  'and', 'or', 'not', 'in'
];

const BUILTINS: string[] = [
  'insmod', 'save_env', 'load_env', 'menuentry',
  'member', 'expand-file-name', 'message', 'format', 'println',
  'flush', 'unwrap', 'allow', 'trusted-content-p', 'echo'
];

const TYPES: string[] = [
  'String', 'str', 'u32', 'i32', 'u64', 'bool', 'char',
  'void', 'int', 'repeat', 'string', 'Self'
];

const CONSTANTS: string[] = [
  't', 'nil', 'true', 'false', 'None'
];

const WARNINGS: string[] = [
  'TODO', 'FIXME', 'WARNING', 'ERROR', 'Error'
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

function isInList(word: string, list: string[]): boolean {
  let i: number = 0;
  while (i < list.length) {
    if (list[i] === word) {
      return true;
    }
    i = i + 1;
  }
  return false;
}

function isKeyword(word: string): boolean {
  return isInList(word, KEYWORDS);
}

function isBuiltin(word: string): boolean {
  return isInList(word, BUILTINS);
}

function isType(word: string): boolean {
  return isInList(word, TYPES);
}

function isConstant(word: string): boolean {
  if (isInList(word, CONSTANTS)) {
    return true;
  }
  // Numeric literal => constant face.
  if (word.length > 0) {
    let j: number = 0;
    let allDigit: boolean = true;
    while (j < word.length) {
      const c: string = word.charAt(j);
      const code: number = c.charCodeAt(0);
      if (code < 48 || code > 57) {
        allDigit = false;
        break;
      }
      j = j + 1;
    }
    if (allDigit) {
      return true;
    }
  }
  return false;
}

function isWarning(word: string): boolean {
  return isInList(word, WARNINGS);
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

function classifyWord(word: string, followedByParen: boolean): string {
  if (word.length === 0) {
    return DEFAULT_COLOR;
  }
  if (word.charAt(0) === '$') {
    return VARIABLE_COLOR;
  }
  if (isWarning(word)) {
    return WARNING_COLOR;
  }
  if (isKeyword(word)) {
    return KEYWORD_COLOR;
  }
  if (isBuiltin(word)) {
    return BUILTIN_COLOR;
  }
  if (isType(word)) {
    return TYPE_COLOR;
  }
  if (isConstant(word)) {
    return CONSTANT_COLOR;
  }
  if (followedByParen) {
    return FUNCTION_COLOR;
  }
  return DEFAULT_COLOR;
}

function findCommentStart(line: string): number {
  // Earliest #, ;, // outside a "..." string. mode is unused: all three
  // markers are recognised for Conf/Rust/Elisp fidelity.
  let inStr: boolean = false;
  let k: number = 0;
  while (k < line.length) {
    const ch: string = line.charAt(k);
    if (ch === '"') {
      inStr = !inStr;
      k = k + 1;
      continue;
    }
    if (!inStr) {
      if (ch === '#' || ch === ';') {
        return k;
      }
      if (ch === '/' && k + 1 < line.length && line.charAt(k + 1) === '/') {
        return k;
      }
    }
    k = k + 1;
  }
  return -1;
}

function highlightCode(code: string, out: HighlightSegment[]): void {
  let i: number = 0;
  let pending: string = '';
  while (i < code.length) {
    const ch: string = code.charAt(i);
    // $var variables: $ + word chars.
    if (ch === '$') {
      if (pending.length > 0) {
        out.push({ text: pending, color: classifyWord(pending, false) });
        pending = '';
      }
      let v: string = '$';
      let j: number = i + 1;
      while (j < code.length && isWordChar(code.charAt(j))) {
        v = v + code.charAt(j);
        j = j + 1;
      }
      // ${var} form: consume closing brace when present.
      if (i + 1 < code.length && code.charAt(i + 1) === '{') {
        let m: number = i + 2;
        let inner: string = '';
        while (m < code.length && code.charAt(m) !== '}') {
          inner = inner + code.charAt(m);
          m = m + 1;
        }
        v = '${' + inner;
        if (m < code.length && code.charAt(m) === '}') {
          v = v + '}';
          j = m + 1;
        } else {
          j = m;
        }
      }
      out.push({ text: v, color: VARIABLE_COLOR });
      i = j;
      continue;
    }
    if (isWordChar(ch)) {
      pending = pending + ch;
      i = i + 1;
      continue;
    }
    // Delimiter ends a word: look ahead for '(' to spot function names.
    if (pending.length > 0) {
      let m: number = i;
      // Skip trailing '!' already in word; check immediate '('.
      let followed: boolean = false;
      if (m < code.length && code.charAt(m) === '(') {
        followed = true;
      }
      out.push({ text: pending, color: classifyWord(pending, followed) });
      pending = '';
    }
    out.push({ text: ch, color: DEFAULT_COLOR });
    i = i + 1;
  }
  if (pending.length > 0) {
    out.push({ text: pending, color: classifyWord(pending, false) });
  }
}

export function highlightLine(line: string, mode: string): HighlightSegment[] {
  const out: HighlightSegment[] = [];
  if (line.length === 0) {
    out.push({ text: ' ', color: DEFAULT_COLOR });
    return out;
  }
  // Reference mode so per-mode callers stay meaningful; markers are universal.
  const modeName: string = mode;
  if (modeName.length === 0) {
    out.push({ text: '', color: DEFAULT_COLOR });
    out.pop();
  }
  const cidx: number = findCommentStart(line);
  let code: string = line;
  let comment: string = '';
  if (cidx >= 0) {
    code = line.substring(0, cidx);
    comment = line.substring(cidx);
  }
  // Split code into string runs vs plain code.
  let cur: string = '';
  let inStr: boolean = false;
  let k: number = 0;
  while (k < code.length) {
    const ch: string = code.charAt(k);
    if (ch === '"') {
      if (inStr) {
        cur = cur + ch;
        out.push({ text: cur, color: DOC_COLOR });
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
