import { hilog } from '@kit.PerformanceAnalysisKit';
import nativeModule from 'libentry.so';

const DOMAIN = 0x0201;

@Entry
@Component
struct Index {
  @State message: string = 'OHEmacs 30.1 (OpenHarmony port)';
  @State status: string = 'idle';
  @State logLines: string[] = ['OHEmacs boot log: waiting for NAPI...'];
  private xId: string = 'ohemacs_xc';

  aboutToAppear(): void {
    try {
      const hello: string = nativeModule.hello() as string;
      this.message = hello;
      this.appendLog('NAPI hello: ' + hello);
      const ver: string = nativeModule.getEmacsVersion() as string;
      this.appendLog('Emacs core: ' + ver);
    } catch (e) {
      const msg = 'native init failed: ' + String(e);
      hilog.warn(DOMAIN, 'OHEmacs', '%{public}s', msg);
      this.appendLog(msg);
    }
  }

  private appendLog(line: string): void {
    const copy = this.logLines.slice();
    copy.push(line);
    if (copy.length > 30) {
      copy.shift();
    }
    this.logLines = copy;
  }

  build(): void {
    Column() {
      Text(this.message).fontSize(20).fontWeight(FontWeight.Bold).margin({ top: 12, bottom: 4 })
      Text('GNU Emacs 30.1 — OpenHarmony GUI port (XComponent + NAPI)').fontSize(13).fontColor('#666').margin({ bottom: 8 })
      Text('Status: ' + this.status).fontSize(14).margin({ bottom: 8 })

      // Emacs frame surface. Native side renders via OH_NativeWindow + OH_Drawing.
      XComponent({ id: this.xId, type: XComponentType.SURFACE, libraryname: 'entry' })
        .width('100%')
        .height(360)
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
      }.width('100%').height(180).border({ width: 1, color: '#ccc' }).margin({ top: 4 })
    }.width('100%').height('100%').padding(12)
  }
}
