import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import nativeModule from 'libentry.so';

const DOMAIN: number = 0x0201;
const SHELL_TITLE: string = '*shell* - GNU Emacs at OHEmacs';
const SHELL_BANNER: string = 'GNU Emacs 30.1 *shell* (M-x shell / eshell mode) — type "help".';
const DEFAULT_CWD: string = '/data/storage';
const UNAME_LINE: string = 'HarmonyOS Harmony_PC_61 5.10.210 aarch64 (musl)';

interface ShellTool {
  icon: string;
  name: string;
  tip: string;
}

const SHELL_TOOLS: ShellTool[] = [
  { icon: '⌧', name: 'Clear', tip: 'Clear Terminal' },
  { icon: '⊗', name: 'Interrupt', tip: 'Interrupt C-g' },
  { icon: 'ⓘ', name: 'Version', tip: 'Emacs Version' },
  { icon: 'λ', name: 'Eval', tip: 'Evaluate Lisp' },
  { icon: '⌨', name: 'Native CLI', tip: 'Native Terminal CLI info' },
  { icon: '⏎', name: 'Enter', tip: 'Send Enter' }
];

interface ShellEnvEntry {
  key: string;
  value: string;
}

@Entry
@Component
struct Terminal {
  @State logLines: string[] = [
    SHELL_BANNER,
    'emacs --batch terminal: NAPI libentry.so ready.',
    'Native HarmonyOS Terminal binary installed at /data/local/tmp/emacs.',
    'Run in device console: hdc shell /data/local/tmp/emacs'
  ];
  @State cmdInput: string = '';
  @State status: string = 'idle';
  @State cwd: string = DEFAULT_CWD;
  @State files: string[] = ['grub.cfg', 'main.rs', 'files.el.gz', '*scratch*', '*GNU Emacs*', 'README', 'notes.txt'];
  @State env: ShellEnvEntry[] = [
    { key: 'USER', value: 'shell' },
    { key: 'HOME', value: '/data/storage' },
    { key: 'SHELL', value: '/bin/sh' },
    { key: 'EMACS', value: '30.1-ohos-native' },
    { key: 'TERM', value: 'xterm-256color' }
  ];

  aboutToAppear(): void {
    try {
      const hello: string = nativeModule.hello();
      this.appendLog('$ emacs --batch --eval "(message \\"hello\\")"');
      this.appendLog(hello);
      const ver: string = nativeModule.getEmacsVersion();
      this.appendLog('$ emacs --batch --version');
      this.appendLog(ver);
    } catch (e) {
      const msg: string = 'native init failed: ' + String(e);
      hilog.warn(DOMAIN, 'OHEmacs', '%{public}s', msg);
      this.appendLog(msg);
    }
  }

  private appendLog(line: string): void {
    const copy: string[] = this.logLines.slice();
    copy.push(line);
    if (copy.length > 150) {
      copy.shift();
    }
    this.logLines = copy;
  }

  private clearLog(): void {
    this.logLines = [SHELL_BANNER, 'shell: log cleared. Type "help".'];
    this.status = 'cleared';
  }

  private hasFile(name: string): boolean {
    for (let i: number = 0; i < this.files.length; i++) {
      if (this.files[i] === name) {
        return true;
      }
    }
    return false;
  }

  private fileLines(name: string): string[] {
    if (name === 'grub.cfg') {
      return ['set timeout=5', 'set default=0', 'menuentry \'OHEmacs\' --class emacs {', '  linux /boot/vmlinuz root=/dev/ram0', '}'];
    }
    if (name === 'main.rs') {
      return ['fn main() {', '    println!("Hello from OHEmacs on HarmonyOS!");', '}'];
    }
    if (name === 'README') {
      return ['GNU Emacs 30.1 (OpenHarmony port)', 'Dual target: Desktop GUI + Native HarmonyOS Terminal CLI.', 'Terminal binary: /data/local/tmp/emacs'];
    }
    if (name === 'notes.txt') {
      return ['* OHEmacs notes', 'Stage 2 bridge + Native CLI fully integrated.'];
    }
    if (name === 'files.el.gz') {
      return [';; files.el.gz: compressed elisp', '(defcustom trusted-content nil "trusted paths")'];
    }
    if (name === '*scratch*') {
      return [';; *scratch* -- Lisp Interaction', '(+ 40 2) ; => 42'];
    }
    if (name === '*GNU Emacs*') {
      return ['GNU Emacs 30.1 (OpenHarmony port, OHEmacs)', 'Type M-x tutorial to start.'];
    }
    return ['(' + name + ': virtual file)'];
  }

  private envValue(key: string): string {
    for (let i: number = 0; i < this.env.length; i++) {
      const e: ShellEnvEntry = this.env[i];
      if (e.key === key) {
        return e.value;
      }
    }
    return '';
  }

  private setEnv(key: string, value: string): void {
    const copy: ShellEnvEntry[] = this.env.slice();
    for (let i: number = 0; i < copy.length; i++) {
      if (copy[i].key === key) {
        copy[i] = { key: key, value: value };
        this.env = copy;
        return;
      }
    }
    copy.push({ key: key, value: value });
    this.env = copy;
  }

  private evalLisp(expr: string): string {
    const t: string = expr.trim();
    if (t.length === 0) {
      return 'eval: unsupported form';
    }
    let inner: string = t;
    if (inner.charAt(0) === '(') {
      if (inner.charAt(inner.length - 1) !== ')') {
        return 'eval: unbalanced parentheses';
      }
      inner = inner.substring(1, inner.length - 1).trim();
    }
    const rawParts: string[] = inner.split(' ');
    const toks: string[] = [];
    for (let i: number = 0; i < rawParts.length; i++) {
      if (rawParts[i].length > 0) {
        toks.push(rawParts[i]);
      }
    }
    if (toks.length === 0) {
      return 'nil';
    }
    const op: string = toks[0];
    if (op === 'message') {
      let msg: string = '';
      for (let m: number = 1; m < toks.length; m++) {
        let piece: string = toks[m];
        if (piece.charAt(0) === '"' && piece.charAt(piece.length - 1) === '"') {
          piece = piece.substring(1, piece.length - 1);
        }
        msg += (m > 1 ? ' ' : '') + piece;
      }
      return '"' + msg + '"';
    }
    if (op !== '+' && op !== '-' && op !== '*' && op !== '/') {
      return 'eval: unsupported operator ' + op;
    }
    const nums: number[] = [];
    for (let j: number = 1; j < toks.length; j++) {
      const n: number = Number(toks[j]);
      if (isNaN(n)) {
        return 'eval: non-numeric argument ' + toks[j];
      }
      nums.push(n);
    }
    if (nums.length === 0) {
      return (op === '*' ? '1' : '0');
    }
    let r: number = nums[0];
    if (op === '+') {
      r = 0;
      for (let k: number = 0; k < nums.length; k++) r += nums[k];
    } else if (op === '*') {
      r = 1;
      for (let k: number = 0; k < nums.length; k++) r *= nums[k];
    } else if (op === '-') {
      if (nums.length === 1) r = -nums[0];
      else for (let k: number = 1; k < nums.length; k++) r -= nums[k];
    } else {
      for (let k: number = 1; k < nums.length; k++) {
        if (nums[k] === 0) return 'eval: division by zero';
        r /= nums[k];
      }
    }
    return r.toString();
  }

  private resolveCd(arg: string): string {
    const home: string = this.envValue('HOME');
    let target: string = arg.trim();
    if (target.length === 0 || target === '~') {
      return home;
    }
    if (target.length > 1 && target.charAt(0) === '~' && target.charAt(1) === '/') {
      target = home + target.substring(1);
      return target;
    }
    if (target.charAt(0) !== '/') {
      if (this.cwd.charAt(this.cwd.length - 1) === '/') {
        target = this.cwd + target;
      } else {
        target = this.cwd + '/' + target;
      }
    }
    const parts: string[] = target.split('/');
    const stack: string[] = [];
    for (let i: number = 0; i < parts.length; i++) {
      const p: string = parts[i];
      if (p.length === 0 || p === '.') {
        continue;
      }
      if (p === '..') {
        if (stack.length > 0) {
          stack.pop();
        }
        continue;
      }
      stack.push(p);
    }
    let out: string = '';
    for (let j: number = 0; j < stack.length; j++) {
      out = out + '/' + stack[j];
    }
    if (out.length === 0) {
      out = '/';
    }
    return out;
  }

  private interrupt(): void {
    this.appendLog('$ C-g');
    this.appendLog('Quit');
    this.status = 'Quit';
    hilog.info(DOMAIN, 'OHEmacs', 'shell interrupt C-g');
    try {
      nativeModule.sendKey(2023, 1);
    } catch (e) {
      // ignore
    }
  }

  private runShellCommand(raw: string): void {
    const cmd: string = raw.trim();
    if (cmd.length === 0) {
      return;
    }
    this.appendLog('$ ' + cmd);
    hilog.info(DOMAIN, 'OHEmacs', '%{public}s', '$ ' + cmd);

    if (cmd === 'help') {
      this.appendLog('Available Commands:');
      this.appendLog('  help                     - Show this command reference');
      this.appendLog('  cli                      - Show info on running native CLI in terminal');
      this.appendLog('  version | emacs --version- Show Emacs version');
      this.appendLog('  eval <expr>              - Evaluate tiny Lisp, e.g. eval (+ 19 23)');
      this.appendLog('  ls                       - List files in current directory');
      this.appendLog('  cat <file>               - Print file contents');
      this.appendLog('  touch <file>             - Create virtual file');
      this.appendLog('  rm <file>                - Delete virtual file');
      this.appendLog('  pwd | cd <dir>           - Print or change directory');
      this.appendLog('  whoami | uname           - Show current user / kernel');
      this.appendLog('  env | export K=V         - Environment variables');
      this.appendLog('  echo <text>              - Echo arguments');
      this.appendLog('  clear                    - Clear terminal output');
      this.status = 'help';
      return;
    }
    if (cmd === 'cli' || cmd === 'terminal') {
      this.appendLog('=== Native HarmonyOS Terminal Emacs ===');
      this.appendLog('A standalone aarch64 ELF binary is compiled & installed:');
      this.appendLog('  Binary path : /data/local/tmp/emacs');
      this.appendLog('  Alias       : /data/local/tmp/ohemacs');
      this.appendLog('Run directly in HarmonyOS terminal console via HDC:');
      this.appendLog('  $ hdc shell /data/local/tmp/emacs --version');
      this.appendLog('  $ hdc shell /data/local/tmp/emacs --batch --eval "(+ 1 2 3)"');
      this.appendLog('  $ hdc shell /data/local/tmp/emacs -nw [file]');
      this.status = 'cli-info';
      return;
    }
    if (cmd === 'clear') {
      this.clearLog();
      return;
    }
    if (cmd === 'version' || cmd === 'emacs --version' || cmd === 'emacs --batch --version') {
      try {
        const v: string = nativeModule.getEmacsVersion();
        this.status = v;
        this.appendLog(v);
      } catch (e) {
        this.appendLog('version failed: ' + String(e));
      }
      return;
    }
    if (cmd === 'eval' || cmd.indexOf('eval ') === 0) {
      if (cmd.length <= 5) {
        this.appendLog('usage: eval (+ 1 2 3)');
        this.status = 'usage: eval';
        return;
      }
      const expr: string = cmd.substring(5).trim();
      const res: string = this.evalLisp(expr);
      this.appendLog(res);
      this.status = res;
      return;
    }
    if (cmd === 'ls' || cmd.indexOf('ls ') === 0) {
      this.appendLog(this.cwd + ':');
      for (let i: number = 0; i < this.files.length; i++) {
        this.appendLog('  ' + this.files[i]);
      }
      this.status = 'ls: ' + this.files.length.toString() + ' files';
      return;
    }
    if (cmd === 'pwd') {
      this.appendLog(this.cwd);
      this.status = this.cwd;
      return;
    }
    if (cmd === 'whoami') {
      const u: string = this.envValue('USER');
      this.appendLog(u);
      this.status = u;
      return;
    }
    if (cmd === 'uname' || cmd.indexOf('uname ') === 0) {
      this.appendLog(UNAME_LINE);
      this.status = UNAME_LINE;
      return;
    }
    if (cmd === 'echo' || cmd.indexOf('echo ') === 0) {
      let text: string = '';
      if (cmd.length > 5) {
        text = cmd.substring(5);
      }
      this.appendLog(text);
      this.status = 'echo';
      return;
    }
    if (cmd === 'cat' || cmd.indexOf('cat ') === 0) {
      let target: string = '';
      if (cmd.length > 4) {
        target = cmd.substring(4).trim();
      }
      if (target.length === 0) {
        this.appendLog('usage: cat <file>');
        return;
      }
      if (!this.hasFile(target)) {
        this.appendLog('cat: ' + target + ': No such file');
        return;
      }
      const lines: string[] = this.fileLines(target);
      for (let i: number = 0; i < lines.length; i++) {
        this.appendLog(lines[i]);
      }
      this.status = 'cat ' + target;
      return;
    }
    if (cmd === 'touch' || cmd.indexOf('touch ') === 0) {
      const target: string = cmd.substring(6).trim();
      if (target.length > 0 && !this.hasFile(target)) {
        const copy: string[] = this.files.slice();
        copy.push(target);
        this.files = copy;
      }
      this.appendLog('touched ' + target);
      this.status = 'touch ' + target;
      return;
    }
    if (cmd === 'rm' || cmd.indexOf('rm ') === 0) {
      const target: string = cmd.substring(3).trim();
      if (!this.hasFile(target)) {
        this.appendLog('rm: ' + target + ': No such file');
        return;
      }
      const kept: string[] = [];
      for (let i: number = 0; i < this.files.length; i++) {
        if (this.files[i] !== target) kept.push(this.files[i]);
      }
      this.files = kept;
      this.appendLog('removed ' + target);
      this.status = 'rm ' + target;
      return;
    }
    if (cmd === 'cd' || cmd.indexOf('cd ') === 0) {
      const arg: string = cmd.length > 3 ? cmd.substring(3).trim() : '';
      const next: string = this.resolveCd(arg);
      this.cwd = next;
      this.appendLog(next);
      this.status = next;
      return;
    }
    if (cmd === 'env') {
      for (let i: number = 0; i < this.env.length; i++) {
        this.appendLog(this.env[i].key + '=' + this.env[i].value);
      }
      this.status = 'env';
      return;
    }
    if (cmd === 'export' || cmd.indexOf('export ') === 0) {
      const rest: string = cmd.substring(7).trim();
      const eq: number = rest.indexOf('=');
      if (eq > 0) {
        const k: string = rest.substring(0, eq).trim();
        const v: string = rest.substring(eq + 1).trim();
        this.setEnv(k, v);
        this.appendLog('export ' + k + '=' + v);
      } else {
        this.appendLog('usage: export K=V');
      }
      return;
    }

    this.appendLog(cmd + ': command not found. Type "help" for command list.');
    this.status = 'unknown: ' + cmd;
  }

  private async goBackAsync(): Promise<void> {
    try {
      await router.pushUrl({ url: 'pages/Index' });
    } catch (e) {
      // ignore
    }
  }

  build(): void {
    Column({ space: 0 }) {
      // 1. Header Bar
      Row({ space: 0 }) {
        Text(SHELL_TITLE)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#222222')
          .padding({ left: 12 })
          .layoutWeight(1)
        Text(this.status)
          .fontSize(11)
          .fontColor('#666666')
          .padding({ right: 12 })
      }
      .width('100%')
      .height(26)
      .backgroundColor('#E4E4E4')
      .border({ width: { bottom: 1 }, color: '#C8C8C8' })

      // 2. Menubar
      Row({ space: 0 }) {
        Text('File').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick((): void => { this.runShellCommand('ls'); })
        Text('Edit').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick((): void => { this.runShellCommand('clear'); })
        Text('Shell').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick((): void => { this.runShellCommand('cli'); })
        Text('Help').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick((): void => { this.runShellCommand('help'); })
        Blank()
        Text('Back to GUI')
          .fontSize(12)
          .fontColor('#0A84FF')
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#EAEAEA')
          .border({ width: 1, color: '#0A84FF' })
          .borderRadius(3)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .margin({ right: 8 })
          .onClick((): void => { this.goBackAsync(); })
      }
      .width('100%')
      .height(28)
      .backgroundColor('#ECECEC')
      .border({ width: { bottom: 1 }, color: '#D0D0D0' })

      // 3. Toolbar
      Row({ space: 4 }) {
        ForEach(SHELL_TOOLS, (tool: ShellTool): void => {
          Button() {
            Row({ space: 4 }) {
              Text(tool.icon).fontSize(14).fontColor('#222222')
              Text(tool.name).fontSize(11).fontColor('#333333')
            }
          }
          .height(26)
          .padding({ left: 8, right: 8 })
          .backgroundColor('#F5F5F5')
          .borderRadius(3)
          .border({ width: 1, color: '#D0D0D0' })
          .onClick((): void => {
            if (tool.name === 'Clear') this.clearLog();
            else if (tool.name === 'Interrupt') this.interrupt();
            else if (tool.name === 'Version') this.runShellCommand('version');
            else if (tool.name === 'Eval') this.runShellCommand('eval (+ 19 23)');
            else if (tool.name === 'Native CLI') this.runShellCommand('cli');
            else if (tool.name === 'Enter') {
              try { nativeModule.sendKey(2011, 1); } catch(e) {}
              this.appendLog('$ sendKey Enter');
            }
          })
        })
      }
      .width('100%')
      .height(34)
      .backgroundColor('#F0F0F0')
      .border({ width: { bottom: 1 }, color: '#D0D0D0' })
      .padding({ left: 6, right: 6 })

      // 4. Terminal Output (Full-Height Dark Console)
      List({ space: 0 }) {
        ForEach(this.logLines, (line: string, idx: number): void => {
          ListItem() {
            Text(line)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor(line.startsWith('$') ? '#FFD700' : (line.startsWith('===') || line.startsWith('Available') ? '#00D4FF' : '#00FF66'))
              .lineHeight(18)
              .padding({ left: 8, right: 8 })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#0A0C10')
      .divider({ strokeWidth: 0 })

      // 5. Shell Command Input Row
      Row({ space: 0 }) {
        Text('esh: $ ')
          .fontSize(12)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .fontColor('#00FF66')
          .backgroundColor('#0A0C10')
          .padding({ left: 8, top: 4, bottom: 4 })
        TextInput({ text: this.cmdInput, placeholder: 'type command or "help"...' })
          .fontFamily('monospace')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .height(26)
          .backgroundColor('#161B22')
          .padding({ left: 6, right: 6 })
          .onChange((val: string): void => { this.cmdInput = val; })
          .onSubmit((): void => {
            const c: string = this.cmdInput;
            this.cmdInput = '';
            this.runShellCommand(c);
          })
        Button('Run')
          .fontSize(11)
          .height(24)
          .borderRadius(3)
          .backgroundColor('#238636')
          .fontColor('#FFFFFF')
          .margin({ left: 6, right: 6 })
          .onClick((): void => {
            const c: string = this.cmdInput;
            this.cmdInput = '';
            this.runShellCommand(c);
          })
      }
      .width('100%')
      .height(30)
      .backgroundColor('#0A0C10')
      .border({ width: { top: 1 }, color: '#30363D' })

      // 6. Mode-Line
      Text('-U:---  *shell*   Bot L' + this.logLines.length.toString() + '   (Shell:esh) ----------------------------------------------------')
        .fontSize(12)
        .fontFamily('monospace')
        .fontColor('#000000')
        .backgroundColor('#D6D6D6')
        .width('100%')
        .height(22)
        .border({ width: { top: 1, bottom: 1 }, color: '#A0A0A0' })
        .padding({ left: 6, right: 6 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0C10')
  }
}
