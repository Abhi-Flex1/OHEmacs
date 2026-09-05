import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import nativeModule from 'libentry.so';

const DOMAIN: number = 0x0201;
const SHELL_TITLE: string = '*shell* - GNU Emacs at OHEmacs';
const SHELL_BANNER: string = 'GNU Emacs *shell* (M-x shell / vterm style) -- type "help".';
const SHELL_BUFFERS: string[] = ['*GNU Emacs*', '*scratch*', 'grub.cfg', 'main.rs', 'files.el.gz', '*shell*'];
const INIT_FILES_DIR: string = '/data/storage/el2/base/files';
const INIT_CACHE_DIR: string = '/data/storage/el2/base/cache';
const PWD_DIR: string = '/data/storage';
const UNAME_LINE: string = 'HarmonyOS Harmony_PC_61 aarch64';

interface ShellTool {
  icon: string;
  name: string;
}

const SHELL_TOOLS: ShellTool[] = [
  { icon: '⌧', name: 'Clear' },
  { icon: '⊗', name: 'Interrupt' },
  { icon: 'ⓘ', name: 'Version' },
  { icon: '▣', name: 'Expose' },
  { icon: '⏎', name: 'Enter' }
];

@Entry
@Component
struct Terminal {
  @State logLines: string[] = [SHELL_BANNER, 'emacs --batch terminal: NAPI libentry.so ready.'];
  @State cmdInput: string = '';
  @State status: string = 'idle';

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
    if (copy.length > 100) {
      copy.shift();
    }
    this.logLines = copy;
  }

  private clearLog(): void {
    this.logLines = [SHELL_BANNER, 'shell: log cleared. Type "help".'];
    this.status = 'cleared';
  }

  private menuAction(name: string): void {
    this.appendLog('$ M-x menu ' + name);
    hilog.info(DOMAIN, 'OHEmacs', '%{public}s', 'menu ' + name);
    if (name === 'File') {
      try {
        nativeModule.sendExpose();
        this.appendLog('File -> sendExpose delivered to ohos backend');
      } catch (e) {
        this.appendLog('sendExpose failed: ' + String(e));
      }
      return;
    }
    if (name === 'Edit') {
      try {
        nativeModule.sendKey(2017, 1);
        this.appendLog('Edit -> sendKey A down (2017,1)');
      } catch (e) {
        this.appendLog('sendKey failed: ' + String(e));
      }
      return;
    }
    if (name === 'Buffers') {
      this.runShellCommand('buffers');
      return;
    }
    if (name === 'Tools') {
      this.runShellCommand('uname');
      return;
    }
    if (name === 'Help') {
      this.runShellCommand('help');
      return;
    }
    if (name === 'Back') {
      this.goBack();
      return;
    }
    this.status = 'menu: ' + name;
  }

  private shellTool(name: string): void {
    if (name === 'Clear') {
      this.runShellCommand('clear');
      return;
    }
    if (name === 'Interrupt') {
      this.interrupt();
      return;
    }
    if (name === 'Version') {
      this.runShellCommand('version');
      return;
    }
    if (name === 'Expose') {
      try {
        nativeModule.sendExpose();
        this.appendLog('$ sendExpose');
        this.appendLog('expose delivered to ohos backend');
      } catch (e) {
        this.appendLog('sendExpose failed: ' + String(e));
      }
      return;
    }
    if (name === 'Enter') {
      try {
        nativeModule.sendKey(2011, 1);
        this.appendLog('$ sendKey Enter down (2011,1)');
      } catch (e) {
        this.appendLog('sendKey failed: ' + String(e));
      }
      return;
    }
    this.appendLog('tool: ' + name);
  }

  private interrupt(): void {
    this.appendLog('$ C-g');
    this.appendLog('Quit');
    this.status = 'Quit';
    hilog.info(DOMAIN, 'OHEmacs', 'shell interrupt C-g');
    try {
      nativeModule.sendKey(2023, 1);
      this.appendLog('sendKey G down (2023,1) for C-g');
    } catch (e) {
      this.appendLog('sendKey failed: ' + String(e));
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
      this.appendLog('commands: help | version | init | add <a> <b> | clear');
      this.appendLog('          ls | buffers | open <buf> | echo <text> | uname | pwd');
      this.appendLog('example: emacs --batch --eval "(+ 40 2)" -> use: add 40 2');
      this.status = 'help';
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
    if (cmd === 'init' || cmd === 'emacs --batch --init') {
      try {
        const r: string = nativeModule.initEmacs(INIT_FILES_DIR, INIT_CACHE_DIR);
        this.status = 'emacs: ' + r;
        this.appendLog('initEmacs: ' + r);
      } catch (e) {
        this.appendLog('initEmacs failed: ' + String(e));
      }
      return;
    }
    if (cmd === 'add' || cmd.indexOf('add ') === 0) {
      const parts: string[] = cmd.split(' ');
      let a: number = 40;
      let b: number = 2;
      if (parts.length >= 3) {
        const pa: number = Number(parts[1]);
        const pb: number = Number(parts[2]);
        if (!isNaN(pa) && !isNaN(pb)) {
          a = pa;
          b = pb;
        } else {
          this.appendLog('usage: add <a> <b>  (numbers only)');
          return;
        }
      }
      try {
        const n: number = nativeModule.add(a, b);
        this.status = 'add=' + n.toString();
        this.appendLog('emacs --batch --eval "(+ ' + a.toString() + ' ' + b.toString() + ')" => ' + n.toString());
      } catch (e) {
        this.appendLog('add failed: ' + String(e));
      }
      return;
    }
    if (cmd === 'ls' || cmd.indexOf('ls ') === 0 || cmd === 'buffers' || cmd === 'list-buffers') {
      this.appendLog('buffers and files:');
      for (let i: number = 0; i < SHELL_BUFFERS.length; i++) {
        const b: string = SHELL_BUFFERS[i];
        this.appendLog('  ' + b);
      }
      this.status = 'buffers';
      return;
    }
    if (cmd === 'open' || cmd.indexOf('open ') === 0) {
      const parts: string[] = cmd.split(' ');
      if (parts.length < 2 || parts[1].length === 0) {
        this.appendLog('usage: open <buf>  (try: buffers)');
        return;
      }
      const target: string = parts[1];
      this.appendLog('Switching to buffer ' + target + ' ...');
      this.appendLog('(actual switch happens in GUI -- use Back to GUI)');
      this.status = 'open ' + target;
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
    if (cmd === 'uname' || cmd.indexOf('uname ') === 0) {
      this.appendLog(UNAME_LINE);
      this.status = UNAME_LINE;
      return;
    }
    if (cmd === 'pwd') {
      this.appendLog(PWD_DIR);
      this.status = PWD_DIR;
      return;
    }
    const spaceIdx: number = cmd.indexOf(' ');
    let first: string = cmd;
    if (spaceIdx > 0) {
      first = cmd.substring(0, spaceIdx);
    }
    this.appendLog(cmd + ': command not found');
    this.appendLog(first + ' is undefined');
    this.status = 'unknown: ' + cmd;
  }

  private async goBackAsync(): Promise<void> {
    try {
      await router.pushUrl({ url: 'pages/Index' });
      hilog.info(DOMAIN, 'OHEmacs', 'nav Terminal -> Index ok');
    } catch (e) {
      this.appendLog('nav failed: ' + String(e));
    }
  }

  private goBack(): void {
    this.goBackAsync();
  }

  build(): void {
    Column({ space: 0 }) {
      Text(SHELL_TITLE)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(24)
        .backgroundColor('#E8E8E8')
        .fontColor('#000000')
        .padding(0)
        .margin(0)

      // Menu bar: H26 BG #F0F0F0 pad 0/2 gap 0, plain Texts.
      Scroll() {
        Row({ space: 0 }) {
          Text('File')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 }).margin(0)
            .onClick((): void => {
              this.menuAction('File');
            })
          Text('Edit')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 }).margin(0)
            .onClick((): void => {
              this.menuAction('Edit');
            })
          Text('Buffers')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 }).margin(0)
            .onClick((): void => {
              this.menuAction('Buffers');
            })
          Text('Tools')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 }).margin(0)
            .onClick((): void => {
              this.menuAction('Tools');
            })
          Text('Help')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 }).margin(0)
            .onClick((): void => {
              this.menuAction('Help');
            })
          Text('Back to GUI')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 }).margin(0)
            .onClick((): void => {
              this.goBack();
            })
        }.height(26).padding(0).margin(0)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%').height(26)
      .backgroundColor('#F0F0F0')
      .padding(0).margin(0)

      // Toolbar: H36 BG #F0F0F0 bottom border #C0C0C0 pad 2 gap 2, 28x28 cells.
      Scroll() {
        Row({ space: 2 }) {
          ForEach(SHELL_TOOLS, (tool: ShellTool, idx: number): void => {
            Text(tool.icon)
              .fontSize(16).fontColor('#000000')
              .textAlign(TextAlign.Center)
              .width(28).height(28)
              .borderRadius(3)
              .backgroundColor('#F0F0F0')
              .padding(0).margin(0)
              .onClick((): void => {
                this.shellTool(tool.name);
              })
          }, (tool: ShellTool, idx: number): string => idx.toString() + ':' + tool.name)
        }.height(32).padding(0).margin(0)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%').height(36)
      .backgroundColor('#F0F0F0')
      .border({ width: { bottom: 1 }, color: '#C0C0C0' })
      .padding(2).margin(0)

      Text('Status: ' + this.status)
        .fontSize(11).fontFamily('monospace').fontColor('#000000')
        .width('100%')
        .padding({ left: 4, right: 4 })
        .margin(0)

      // *shell* buffer: dark #0A0A0A green #33FF66 monospace 13px.
      List({ space: 0 }) {
        ForEach(this.logLines, (line: string, idx: number): void => {
          ListItem() {
            Text((idx + 1).toString() + ': ' + line)
              .fontSize(13).fontFamily('monospace').fontColor('#33FF66')
              .padding(0).margin(0)
          }.padding(0).margin(0)
        }, (line: string, idx: number): string => idx.toString() + ':' + line)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#0A0A0A')
      .border({ width: 1, color: '#333333' })
      .padding(0)
      .margin(0)
      .divider({ strokeWidth: 0 })

      // Input: H22 row.
      Row({ space: 0 }) {
        TextInput({
          placeholder: 'shell: help | version | init | add 40 2 | ls | echo hi',
          text: this.cmdInput
        })
          .fontFamily('monospace')
          .fontSize(12)
          .layoutWeight(1)
          .height(22)
          .padding(0)
          .margin(0)
          .onChange((value: string): void => {
            this.cmdInput = value;
          })
          .onSubmit((): void => {
            const c: string = this.cmdInput;
            this.cmdInput = '';
            this.runShellCommand(c);
          })
        Button('Run')
          .fontSize(12)
          .height(22)
          .borderRadius(3)
          .padding({ top: 2, bottom: 2, left: 6, right: 6 })
          .margin({ left: 4 })
          .onClick((): void => {
            const c: string = this.cmdInput;
            this.cmdInput = '';
            this.runShellCommand(c);
          })
      }.width('100%').height(22).padding(0).margin(0)

      // Mode-line: H22 BG #E5E5E5 borders #999 pad 0/4.
      Text('-:-- *shell* Bot L' + this.logLines.length.toString() + ' (Shell)')
        .fontSize(12).fontFamily('monospace').fontColor('#000000')
        .backgroundColor('#E5E5E5')
        .width('100%').height(22)
        .border({ width: { top: 1, bottom: 1 }, color: '#999999' })
        .padding({ left: 4, right: 4 })
        .margin(0)
    }
    .width('100%')
    .height('100%')
    .padding(0)
    .margin(0)
    .backgroundColor('#FFFFFF')
  }
}
