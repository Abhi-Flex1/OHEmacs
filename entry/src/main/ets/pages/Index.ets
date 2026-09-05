import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import nativeModule from 'libentry.so';

const DOMAIN = 0x0201;

@Entry
@Component
struct Index {
  @State message: string = 'OHEmacs 30.1 (OpenHarmony port)';
  @State status: string = 'idle';
  @State logLines: string[] = ['OHEmacs boot log: waiting for NAPI...'];
  @State minibuffer: string = '';
  @State bufferName: string = '*scratch*';
  private xId: string = 'ohemacs_xc';

  aboutToAppear(): void {
    try {
      const hello: string = nativeModule.hello() as string;
      this.message = hello;
      this.appendLog('NAPI hello: ' + hello);
      const ver: string = nativeModule.getEmacsVersion() as string;
      this.appendLog('Emacs core: ' + ver);
    } catch (e) {
      const msg: string = 'native init failed: ' + String(e);
      hilog.warn(DOMAIN, 'OHEmacs', '%{public}s', msg);
      this.appendLog(msg);
    }
  }

  private appendLog(line: string): void {
    const copy: string[] = this.logLines.slice();
    copy.push(line);
    if (copy.length > 30) {
      copy.shift();
    }
    this.logLines = copy;
  }

  private menuAction(name: string): void {
    this.appendLog('menu: ' + name);
    try {
      if (name === 'File') {
        nativeModule.sendExpose();
        this.appendLog('File -> sendExpose');
      } else if (name === 'Edit') {
        nativeModule.sendKey(2017, 1);
        this.appendLog('Edit -> sendKey A down (2017,1)');
      } else if (name === 'Search') {
        nativeModule.sendKey(2011, 1);
        this.appendLog('Search -> sendKey Enter down (2011,1)');
      } else if (name === 'M-x') {
        this.appendLog('M-x: type command in minibuffer below');
      }
    } catch (e) {
      this.appendLog(name + ' action failed: ' + String(e));
    }
  }

  private submitMinibuffer(): void {
    const cmd: string = this.minibuffer.trim();
    if (cmd.length === 0) {
      return;
    }
    this.appendLog('M-x ' + cmd);
    try {
      nativeModule.sendKey(2011, 1);
      this.appendLog('minibuffer "' + cmd + '" -> sendKey Enter down');
    } catch (e) {
      this.appendLog('sendKey failed: ' + String(e));
    }
    this.minibuffer = '';
  }

  private goTerminal(): void {
    try {
      router.pushUrl({ url: 'pages/Terminal' }).then((): void => {
        this.appendLog('nav -> Terminal');
      }).catch((e: Error): void => {
        this.appendLog('nav failed: ' + String(e));
      });
    } catch (e) {
      this.appendLog('nav failed: ' + String(e));
    }
  }

  build(): void {
    Column() {
      Text(this.message).fontSize(20).fontWeight(FontWeight.Bold).margin({ top: 12, bottom: 4 })
      Text('GNU Emacs 30.1 — OpenHarmony GUI port (XComponent + NAPI)').fontSize(13).fontColor('#666').margin({ bottom: 8 })
      Text('Status: ' + this.status).fontSize(14).margin({ bottom: 8 })

      // Emacs GUI chrome: top menu bar.
      Row() {
        Button('File').margin(2).fontSize(13).onClick((): void => {
          this.menuAction('File');
        })
        Button('Edit').margin(2).fontSize(13).onClick((): void => {
          this.menuAction('Edit');
        })
        Button('Search').margin(2).fontSize(13).onClick((): void => {
          this.menuAction('Search');
        })
        Button('M-x').margin(2).fontSize(13).onClick((): void => {
          this.menuAction('M-x');
        })
        Button('Terminal').margin(2).fontSize(13).onClick((): void => {
          this.goTerminal();
        })
      }.width('100%').backgroundColor('#E8E8E8').padding(4).margin({ bottom: 6 })

      Text('Buffer: ' + this.bufferName + '  (ohos backend)').fontSize(12).fontColor('#444').margin({ bottom: 4 })

      // Emacs frame surface. Native side renders via OH_NativeWindow + OH_Drawing.
      XComponent({ id: this.xId, type: XComponentType.SURFACE, libraryname: 'entry' })
        .width('100%')
        .height(300)
        .border({ width: 1, color: '#999' })
        .onLoad(() => {
          hilog.info(DOMAIN, 'OHEmacs', 'XComponent onLoad %{public}s', this.xId);
          try {
            nativeModule.testXComponent(this.xId);
            this.status = 'surface ready';
            this.appendLog('XComponent onLoad -> testXComponent(' + this.xId + ')');
          } catch (e) {
            this.appendLog('testXComponent failed: ' + String(e));
          }
        })
        .onDestroy(() => {
          hilog.info(DOMAIN, 'OHEmacs', 'XComponent onDestroy');
        })

      // Minibuffer: M-x command line.
      Row() {
        Text('M-x').fontSize(13).fontFamily('monospace').margin({ right: 6 })
        TextInput({ placeholder: 'type command, Enter to run (M-x ...)', text: this.minibuffer })
          .fontFamily('monospace')
          .fontSize(13)
          .layoutWeight(1)
          .onChange((value: string): void => {
            this.minibuffer = value;
          })
          .onSubmit((): void => {
            this.submitMinibuffer();
          })
        Button('Run').fontSize(13).margin({ left: 6 }).onClick((): void => {
          this.submitMinibuffer();
        })
      }.width('100%').margin({ top: 6 })

      // Mode line.
      Text('-UUU:---- ' + this.bufferName + '  All L1  (Emacs 30.1 ohos)').fontSize(11)
        .fontFamily('monospace').backgroundColor('#D8D8D8').width('100%').padding(4).margin({ top: 6 })

      Row() {
        Button('Version').margin(4).onClick(() => {
          try {
            const v: string = nativeModule.getEmacsVersion() as string;
            this.status = v;
            this.appendLog('getEmacsVersion: ' + v);
          } catch (e) {
            this.appendLog('version failed: ' + String(e));
          }
        })
        Button('Init Emacs').margin(4).onClick(() => {
          try {
            const r: string = nativeModule.initEmacs('/data/storage/el2/base/files', '/data/storage/el2/base/cache') as string;
            this.status = 'emacs: ' + r;
            this.appendLog('initEmacs: ' + r);
          } catch (e) {
            this.appendLog('initEmacs failed: ' + String(e));
          }
        })
        Button('add(40,2)').margin(4).onClick(() => {
          try {
            const n: number = nativeModule.add(40, 2) as number;
            this.status = 'add=' + n;
            this.appendLog('add(40,2)=' + n);
          } catch (e) {
            this.appendLog('add failed: ' + String(e));
          }
        })
      }.margin({ top: 8 })

      Row() {
        Button('Key A').margin(4).onClick(() => {
          try {
            nativeModule.sendKey(2017, 1);
            this.appendLog('sendKey A down');
          } catch (e) {
            this.appendLog('sendKey failed: ' + String(e));
          }
        })
        Button('Key Enter').margin(4).onClick(() => {
          try {
            nativeModule.sendKey(2011, 1);
            this.appendLog('sendKey Enter down');
          } catch (e) {
            this.appendLog('sendKey failed: ' + String(e));
          }
        })
        Button('Expose').margin(4).onClick(() => {
          try {
            nativeModule.sendExpose();
            this.appendLog('sendExpose');
          } catch (e) {
            this.appendLog('sendExpose failed: ' + String(e));
          }
        })
      }

      Text('Log:').fontSize(14).fontWeight(FontWeight.Bold).margin({ top: 8 })
      List() {
        ForEach(this.logLines, (line: string, idx: number) => {
          ListItem() {
            Text((idx + 1) + ': ' + line).fontSize(11).fontFamily('monospace')
          }
        }, (line: string, idx: number) => idx + ':' + line)
      }.width('100%').height(140).border({ width: 1, color: '#ccc' }).margin({ top: 4 })
    }.width('100%').height('100%').padding(12)
  }
}
