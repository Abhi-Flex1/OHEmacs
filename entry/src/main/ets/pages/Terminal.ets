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

@Entry
@Component
struct Terminal {
  @State logLines: string[] = [SHELL_BANNER, 'emacs --batch terminal: NAPI libentry.so ready.'];
  @State cmdInput: string = '';
  @State status: string = 'idle';

  aboutToAppear(): void {
    try {
      const hello: string = nativeModule.hello() as string;
      this.appendLog('$ emacs --batch --eval "(message \\"hello\\")"');
      this.appendLog(hello);
      const ver: string = nativeModule.getEmacsVersion() as string;
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
    this.status = 'menu: ' + name;
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
        const v: string = nativeModule.getEmacsVersion() as string;
        this.status = v;
        this.appendLog(v);
      } catch (e) {
        this.appendLog('version failed: ' + String(e));
      }
      return;
    }
    if (cmd === 'init' || cmd === 'emacs --batch --init') {
      try {
        const r: string = nativeModule.initEmacs(INIT_FILES_DIR, INIT_CACHE_DIR) as string;
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
        const n: number = nativeModule.add(a, b) as number;
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

  private goBack(): void {
    try {
      router.pushUrl({ url: 'pages/Index' }).then((): void => {
        hilog.info(DOMAIN, 'OHEmacs', 'nav Terminal -> Index ok');
      }).catch((e: Error): void => {
        this.appendLog('nav failed: ' + String(e));
      });
    } catch (e) {
      this.appendLog('nav failed: ' + String(e));
    }
  }

  build(): void {
    Column() {
      Text(SHELL_TITLE).fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 8, bottom: 2 })
      Text('GNU Emacs 30.1 M-x shell / vterm emulation (NAPI libentry.so)')
        .fontSize(11).fontColor('#666666').margin({ bottom: 4 })
      Row() {
        Button('File').fontSize(12).margin(2).onClick((): void => {
          this.menuAction('File');
        })
        Button('Edit').fontSize(12).margin(2).onClick((): void => {
          this.menuAction('Edit');
        })
        Button('Buffers').fontSize(12).margin(2).onClick((): void => {
          this.menuAction('Buffers');
        })
        Button('Tools').fontSize(12).margin(2).onClick((): void => {
          this.menuAction('Tools');
        })
        Button('Help').fontSize(12).margin(2).onClick((): void => {
          this.menuAction('Help');
        })
        Button('Back to GUI').fontSize(12).margin(2).onClick((): void => {
          this.goBack();
        })
      }.width('100%').backgroundColor('#E8E8E8').padding(4).margin({ bottom: 4 })

      Row() {
        Button('Clear').fontSize(12).margin(4).onClick((): void => {
          this.runShellCommand('clear');
        })
        Button('Interrupt C-g').fontSize(12).margin(4).onClick((): void => {
          this.interrupt();
        })
        Button('Version').fontSize(12).margin(4).onClick((): void => {
          this.runShellCommand('version');
        })
      }.width('100%').margin({ bottom: 4 })

      Text('Status: ' + this.status).fontSize(12).margin({ bottom: 4 })

      List() {
        ForEach(this.logLines, (line: string, idx: number): void => {
          ListItem() {
            Text((idx + 1).toString() + ': ' + line).fontSize(11).fontFamily('monospace').fontColor('#33FF66')
          }
        }, (line: string, idx: number): string => idx.toString() + ':' + line)
      }
      .width('100%')
      .height(380)
      .backgroundColor('#0A0A0A')
      .border({ width: 1, color: '#333333' })
      .margin({ bottom: 8 })

      Row() {
        TextInput({ placeholder: 'shell: help | version | init | add 40 2 | ls | echo hi', text: this.cmdInput })
          .fontFamily('monospace')
          .fontSize(13)
          .layoutWeight(1)
          .onChange((value: string): void => {
            this.cmdInput = value;
          })
          .onSubmit((): void => {
            const c: string = this.cmdInput;
            this.cmdInput = '';
            this.runShellCommand(c);
          })
        Button('Run').fontSize(13).margin({ left: 8 }).onClick((): void => {
          const c: string = this.cmdInput;
          this.cmdInput = '';
          this.runShellCommand(c);
        })
      }.width('100%').margin({ bottom: 8 })

      Row() {
        Button('C-g').fontSize(12).margin(4).onClick((): void => {
          this.interrupt();
        })
        Button('Expose').fontSize(12).margin(4).onClick((): void => {
          try {
            nativeModule.sendExpose();
            this.appendLog('$ sendExpose');
            this.appendLog('expose delivered to ohos backend');
          } catch (e) {
            this.appendLog('sendExpose failed: ' + String(e));
          }
        })
        Button('Key Enter').fontSize(12).margin(4).onClick((): void => {
          try {
            nativeModule.sendKey(2011, 1);
            this.appendLog('$ sendKey Enter down (2011,1)');
          } catch (e) {
            this.appendLog('sendKey failed: ' + String(e));
          }
        })
      }.width('100%').margin({ bottom: 4 })

      Text('-:-- *shell*      Bot L' + this.logLines.length.toString() + '  (Shell)')
        .fontSize(11).fontFamily('monospace').backgroundColor('#D8D8D8')
        .width('100%').padding(4)
    }.width('100%').height('100%').padding(12)
  }
}
