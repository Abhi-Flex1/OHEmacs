import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import nativeModule from 'libentry.so';

const DOMAIN = 0x0201;

@Entry
@Component
struct Terminal {
  @State logLines: string[] = ['emacs --batch terminal: type "help" and press Enter.'];
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
    this.logLines = ['emacs --batch terminal: log cleared. Type "help".'];
    this.status = 'cleared';
  }

  private runBatchCommand(raw: string): void {
    const cmd: string = raw.trim();
    if (cmd.length === 0) {
      return;
    }
    this.appendLog('$ ' + cmd);
    if (cmd === 'help') {
      this.appendLog('commands: version | init | add <a> <b> | clear | help');
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
        const r: string =
          nativeModule.initEmacs('/data/storage/el2/base/files', '/data/storage/el2/base/cache') as string;
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
        this.status = 'add=' + n;
        this.appendLog('emacs --batch --eval "(+ ' + a + ' ' + b + ')" => ' + n);
      } catch (e) {
        this.appendLog('add failed: ' + String(e));
      }
      return;
    }
    this.appendLog('emacs --batch: unknown command "' + cmd + '" (try "help")');
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
      Row() {
        Button('Back to GUI').margin(4).onClick((): void => {
          this.goBack();
        })
        Text('OHEmacs Terminal').fontSize(18).fontWeight(FontWeight.Bold).margin({ left: 8 })
      }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 8, bottom: 4 })

      Text('GNU Emacs 30.1 --batch mode (NAPI libentry.so)').fontSize(12).fontColor('#888').margin({ bottom: 4 })
      Text('Status: ' + this.status).fontSize(13).margin({ bottom: 6 })

      List() {
        ForEach(this.logLines, (line: string, idx: number) => {
          ListItem() {
            Text((idx + 1) + ': ' + line).fontSize(11).fontFamily('monospace').fontColor('#00FF88')
          }
        }, (line: string, idx: number) => idx + ':' + line)
      }
      .width('100%')
      .height(380)
      .backgroundColor('#111111')
      .border({ width: 1, color: '#333' })
      .margin({ bottom: 8 })

      Row() {
        TextInput({ placeholder: 'type: help | version | init | add 40 2', text: this.cmdInput })
          .fontFamily('monospace')
          .fontSize(13)
          .layoutWeight(1)
          .onChange((value: string): void => {
            this.cmdInput = value;
          })
          .onSubmit((): void => {
            const c: string = this.cmdInput;
            this.cmdInput = '';
            this.runBatchCommand(c);
          })
        Button('Run').margin({ left: 8 }).onClick((): void => {
          const c: string = this.cmdInput;
          this.cmdInput = '';
          this.runBatchCommand(c);
        })
      }.width('100%').margin({ bottom: 8 })

      Row() {
        Button('Version').margin(4).onClick((): void => {
          this.runBatchCommand('version');
        })
        Button('Init').margin(4).onClick((): void => {
          this.runBatchCommand('init');
        })
        Button('add').margin(4).onClick((): void => {
          this.runBatchCommand('add 40 2');
        })
        Button('Clear').margin(4).onClick((): void => {
          this.clearLog();
        })
      }

      Row() {
        Button('Expose').margin(4).onClick((): void => {
          try {
            nativeModule.sendExpose();
            this.appendLog('$ sendExpose');
            this.appendLog('expose delivered to ohos backend');
          } catch (e) {
            this.appendLog('sendExpose failed: ' + String(e));
          }
        })
        Button('Key Enter').margin(4).onClick((): void => {
          try {
            nativeModule.sendKey(2011, 1);
            this.appendLog('$ sendKey Enter down (2011,1)');
          } catch (e) {
            this.appendLog('sendKey failed: ' + String(e));
          }
        })
      }.margin({ top: 4 })
    }.width('100%').height('100%').padding(12)
  }
}
