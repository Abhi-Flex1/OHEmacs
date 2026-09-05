import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import nativeModule from 'libentry.so';
import { EMACS_BUFFERS, highlightLine, EmacsBuffer, HighlightSegment } from '../common/EmacsData';

const DOMAIN = 0x0201;

@Entry
@Component
struct Index {
  @State message: string = 'OHEmacs 30.1 (OpenHarmony port)';
  @State status: string = 'idle';
  @State logLines: string[] = ['OHEmacs boot log: waiting for NAPI...'];
  @State minibuffer: string = '';
  @State echo: string = 'Welcome to OHEmacs - type M-x <command>, Enter to run.';
  @State buffers: EmacsBuffer[] = EMACS_BUFFERS.slice();
  @State bufferName: string = 'grub.cfg';
  @State editContent: string = '';
  @State curLine: number = 11;
  private xId: string = 'ohemacs_xc';

  aboutToAppear(): void {
    this.syncEditor();
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

  private currentIndex(): number {
    let i: number = 0;
    while (i < this.buffers.length) {
      if (this.buffers[i].name === this.bufferName) {
        return i;
      }
      i = i + 1;
    }
    return 0;
  }

  private currentBuffer(): EmacsBuffer {
    return this.buffers[this.currentIndex()];
  }

  private currentMode(): string {
    return this.currentBuffer().mode;
  }

  private currentContent(): string {
    return this.currentBuffer().content;
  }

  private getLines(): string[] {
    return this.currentContent().split('\n');
  }

  private lineCount(): number {
    return this.getLines().length;
  }

  private pct(): number {
    const total: number = this.lineCount();
    if (total <= 1) {
      return 100;
    }
    let c: number = this.curLine;
    if (c < 1) {
      c = 1;
    }
    if (c > total) {
      c = total;
    }
    return Math.round((c - 1) / (total - 1) * 100);
  }

  private modeLine(): string {
    return '-:-- ' + this.bufferName + ' ' + this.pct().toString() + '% L' +
      this.curLine.toString() + ' (' + this.currentMode() + ')';
  }

  private syncEditor(): void {
    const content: string = this.currentContent();
    this.editContent = content;
    const total: number = content.split('\n').length;
    if (this.curLine > total) {
      this.curLine = total;
    }
    if (this.curLine < 1) {
      this.curLine = 1;
    }
  }

  private updateCurrentContent(value: string): void {
    const idx: number = this.currentIndex();
    const old: EmacsBuffer = this.buffers[idx];
    const copy: EmacsBuffer[] = this.buffers.slice();
    copy[idx] = { name: old.name, mode: old.mode, content: value };
    this.buffers = copy;
    this.editContent = value;
    const n: number = value.split('\n').length;
    if (n !== this.curLine) {
      this.curLine = n;
      this.appendLog('edited ' + old.name + ' (' + n.toString() + ' lines)');
    }
  }

  private menuAction(name: string): void {
    this.appendLog('menu: ' + name);
    if (name === 'Buffers') {
      let names: string = '';
      let i: number = 0;
      while (i < this.buffers.length) {
        if (i > 0) {
          names = names + ', ';
        }
        names = names + this.buffers[i].name;
        i = i + 1;
      }
      this.echo = 'Buffers: ' + names;
      return;
    }
    this.echo = name + ' menu (demo)';
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
      }
    } catch (e) {
      this.appendLog(name + ' action failed: ' + String(e));
    }
  }

  private toolbarAction(name: string): void {
    this.appendLog('toolbar: ' + name);
    if (name === 'Save') {
      this.echo = 'Wrote ' + this.bufferName + ' (' + this.lineCount().toString() + ' lines)';
      this.appendLog(this.echo);
      return;
    }
    if (name === 'Open') {
      this.echo = 'Use M-x open <name> to visit a buffer';
      return;
    }
    if (name === 'Search') {
      try {
        nativeModule.sendKey(2011, 1);
        this.appendLog('Search -> sendKey Enter down (2011,1)');
      } catch (e) {
        this.appendLog('Search failed: ' + String(e));
      }
      this.echo = 'I-search (demo): use M-x switch <name>';
      return;
    }
    if (name === 'Undo') {
      this.echo = 'Undo (demo): no changes undone';
      return;
    }
    this.echo = name + ' (demo)';
  }

  private switchBuffer(name: string): void {
    this.bufferName = name;
    this.syncEditor();
    this.appendLog('buffer -> ' + name);
    this.echo = 'Switched to ' + name;
  }

  private visitBuffer(target: string): void {
    let found: boolean = false;
    let i: number = 0;
    while (i < this.buffers.length) {
      if (this.buffers[i].name === target) {
        found = true;
      }
      i = i + 1;
    }
    if (found) {
      this.switchBuffer(target);
    } else {
      this.echo = 'No buffer named ' + target;
      this.appendLog('minibuffer: no buffer named ' + target);
    }
  }

  private splashLink(name: string): void {
    this.echo = 'Opening ' + name + ' (demo)';
    this.appendLog('splash: ' + name);
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
    if (cmd === 'save') {
      this.echo = 'Wrote ' + this.bufferName;
      this.appendLog(this.echo);
    } else if (cmd === 'tutorial') {
      this.switchBuffer('*GNU Emacs*');
      this.echo = 'Opening tutorial (demo)';
    } else if (cmd === 'version') {
      try {
        const v: string = nativeModule.getEmacsVersion() as string;
        this.status = v;
        this.echo = v;
        this.appendLog('getEmacsVersion: ' + v);
      } catch (e) {
        this.echo = 'version failed';
        this.appendLog('version failed: ' + String(e));
      }
    } else if (cmd === 'help') {
      this.echo = 'commands: save | open <name> | switch <name> | tutorial | version';
    } else if (cmd.indexOf('open ') === 0) {
      const target: string = cmd.substring(5).trim();
      this.visitBuffer(target);
    } else if (cmd.indexOf('switch ') === 0) {
      const target: string = cmd.substring(7).trim();
      this.visitBuffer(target);
    } else {
      this.echo = cmd + ' is undefined';
      this.appendLog('minibuffer: ' + cmd + ' is undefined');
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
      // Window title, GTK style: "<buffer> - GNU Emacs at OHEmacs".
      Text(this.bufferName + ' - GNU Emacs at OHEmacs')
        .fontSize(16).fontWeight(FontWeight.Bold).margin({ top: 8, bottom: 2 })
      Text(this.message).fontSize(11).fontColor('#666666').margin({ bottom: 4 })

      // Menu bar: File Edit Options Buffers Tools Help + dynamic mode + Terminal.
      Scroll() {
        Row() {
          Button('File').margin(2).fontSize(12).onClick((): void => {
            this.menuAction('File');
          })
          Button('Edit').margin(2).fontSize(12).onClick((): void => {
            this.menuAction('Edit');
          })
          Button('Options').margin(2).fontSize(12).onClick((): void => {
            this.menuAction('Options');
          })
          Button('Buffers').margin(2).fontSize(12).onClick((): void => {
            this.menuAction('Buffers');
          })
          Button('Tools').margin(2).fontSize(12).onClick((): void => {
            this.menuAction('Tools');
          })
          Button('Help').margin(2).fontSize(12).onClick((): void => {
            this.menuAction('Help');
          })
          Button(this.currentMode()).margin(2).fontSize(12).onClick((): void => {
            this.echo = this.currentMode() + ' mode';
            this.appendLog('mode: ' + this.currentMode());
          })
          Button('Terminal').margin(2).fontSize(12).onClick((): void => {
            this.goTerminal();
          })
        }
      }.scrollable(ScrollDirection.Horizontal).width('100%').backgroundColor('#E8E8E8').padding(4)

      // Toolbar: icon-text buttons.
      Scroll() {
        Row() {
          Button('+ New').margin(2).fontSize(12).onClick((): void => {
            this.toolbarAction('New');
          })
          Button('Open').margin(2).fontSize(12).onClick((): void => {
            this.toolbarAction('Open');
          })
          Button('Save').margin(2).fontSize(12).onClick((): void => {
            this.toolbarAction('Save');
          })
          Button('Close').margin(2).fontSize(12).onClick((): void => {
            this.toolbarAction('Close');
          })
          Button('Undo').margin(2).fontSize(12).onClick((): void => {
            this.toolbarAction('Undo');
          })
          Button('Cut').margin(2).fontSize(12).onClick((): void => {
            this.toolbarAction('Cut');
          })
          Button('Copy').margin(2).fontSize(12).onClick((): void => {
            this.toolbarAction('Copy');
          })
          Button('Paste').margin(2).fontSize(12).onClick((): void => {
            this.toolbarAction('Paste');
          })
          Button('Search').margin(2).fontSize(12).onClick((): void => {
            this.toolbarAction('Search');
          })
        }
      }.scrollable(ScrollDirection.Horizontal).width('100%').backgroundColor('#F4F4F4').padding(4)

      // Buffer tabs.
      Scroll() {
        Row() {
          ForEach(this.buffers, (buf: EmacsBuffer, idx: number) => {
            Button(buf.name).margin(2).fontSize(12)
              .backgroundColor(this.bufferName === buf.name ? '#4A90D9' : '#D8D8D8')
              .fontColor(this.bufferName === buf.name ? '#FFFFFF' : '#000000')
              .onClick((): void => {
                this.switchBuffer(buf.name);
              })
          }, (buf: EmacsBuffer, idx: number) => idx.toString() + ':' + buf.name)
        }
      }.scrollable(ScrollDirection.Horizontal).width('100%').margin({ top: 4 })

      // Main buffer area.
      if (this.bufferName === '*GNU Emacs*') {
        Column() {
          Text('Welcome to GNU Emacs').fontSize(20).fontColor('#CC0000')
            .fontWeight(FontWeight.Bold).margin({ top: 8, bottom: 4 })
          Text('GNU Emacs 30.1 (OpenHarmony port, OHEmacs)').fontSize(12).fontColor('#333333')
          Text('Copyright (C) 2025 Free Software Foundation, Inc.')
            .fontSize(11).fontColor('#666666').margin({ bottom: 8 })
          Button('Emacs Tutorial').fontSize(13).fontColor('#0000EE')
            .backgroundColor('#FFFFFF').onClick((): void => {
              this.splashLink('Emacs Tutorial');
            })
          Button('Emacs Guided Tour').fontSize(13).fontColor('#0000EE')
            .backgroundColor('#FFFFFF').onClick((): void => {
              this.splashLink('Emacs Guided Tour');
            })
          Button('View Emacs Manual').fontSize(13).fontColor('#0000EE')
            .backgroundColor('#FFFFFF').onClick((): void => {
              this.splashLink('Emacs Manual');
            })
          Button('Absence of Warranty').fontSize(13).fontColor('#0000EE')
            .backgroundColor('#FFFFFF').onClick((): void => {
              this.splashLink('Absence of Warranty');
            })
          Button('Copying Conditions').fontSize(13).fontColor('#0000EE')
            .backgroundColor('#FFFFFF').onClick((): void => {
              this.splashLink('Copying Conditions');
            })
          Button('Ordering Manuals').fontSize(13).fontColor('#0000EE')
            .backgroundColor('#FFFFFF').onClick((): void => {
              this.splashLink('Ordering Manuals');
            })
          Text('Type M-x tutorial, or click a link above.').fontSize(12).margin({ top: 8 })
          Button('Dismiss this splash').fontSize(12).margin({ top: 4 }).onClick((): void => {
            this.switchBuffer('grub.cfg');
          })
        }.width('100%').layoutWeight(1).backgroundColor('#FFFFFF')
        .padding(8).border({ width: 1, color: '#999999' }).margin({ top: 4 })
        .alignItems(HorizontalAlign.Start)
      } else {
        List() {
          ForEach(this.getLines(), (line: string, idx: number) => {
            ListItem() {
              Row() {
                Text((idx + 1).toString()).width(36).fontSize(12)
                  .fontFamily('monospace').fontColor('#999999')
                Row() {
                  ForEach(highlightLine(line, this.currentMode()), (seg: HighlightSegment, sidx: number) => {
                    Text(seg.text).fontSize(12).fontFamily('monospace').fontColor(seg.color)
                  }, (seg: HighlightSegment, sidx: number) => sidx.toString() + ':' + seg.text)
                }.layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Top)
            }
          }, (line: string, idx: number) => idx.toString() + ':' + line)
        }.width('100%').layoutWeight(1).backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#999999' }).margin({ top: 4 })
      }

      // Functional editing: multiline TextArea bound to current buffer.
      TextArea({ placeholder: 'Edit buffer content here (multiline)...', text: this.editContent })
        .fontFamily('monospace')
        .fontSize(12)
        .width('100%')
        .height(90)
        .margin({ top: 4 })
        .onChange((value: string): void => {
          this.updateCurrentContent(value);
        })

      // Small ohos frame surface proof.
      Text('ohos frame surface: ' + this.status).fontSize(11).fontColor('#444444').margin({ top: 4 })
      XComponent({ id: this.xId, type: XComponentType.SURFACE, libraryname: 'entry' })
        .width('100%')
        .height(120)
        .border({ width: 1, color: '#999999' })
        .onLoad((): void => {
          hilog.info(DOMAIN, 'OHEmacs', 'XComponent onLoad %{public}s', this.xId);
          try {
            nativeModule.testXComponent(this.xId);
            this.status = 'surface ready';
            this.appendLog('XComponent onLoad -> testXComponent(' + this.xId + ')');
          } catch (e) {
            this.appendLog('testXComponent failed: ' + String(e));
          }
        })
        .onDestroy((): void => {
          hilog.info(DOMAIN, 'OHEmacs', 'XComponent onDestroy');
        })

      // Mode line.
      Text(this.modeLine()).fontSize(11)
        .fontFamily('monospace').backgroundColor('#D8D8D8').width('100%').padding(4).margin({ top: 4 })
      if (this.bufferName === '*GNU Emacs*') {
        Text(' -- click a link above, or M-x tutorial').fontSize(11)
          .fontFamily('monospace').backgroundColor('#D8D8D8').width('100%').padding(4)
      }

      // Minibuffer.
      Row() {
        Text('M-x').fontSize(13).fontFamily('monospace').margin({ right: 6 })
        TextInput({ placeholder: 'save | open <name> | switch <name> | tutorial | version', text: this.minibuffer })
          .fontFamily('monospace')
          .fontSize(13)
          .layoutWeight(1)
          .onChange((value: string): void => {
            this.minibuffer = value;
          })
          .onSubmit((): void => {
            this.submitMinibuffer();
          })
        Button('Go').fontSize(13).margin({ left: 6 }).onClick((): void => {
          this.submitMinibuffer();
        })
      }.width('100%').margin({ top: 4 })
      Text(this.echo).fontSize(12).fontFamily('monospace').fontColor('#333333').width('100%').margin({ top: 2 })

      Text('Log:').fontSize(13).fontWeight(FontWeight.Bold).margin({ top: 4 })
      List() {
        ForEach(this.logLines, (line: string, idx: number) => {
          ListItem() {
            Text((idx + 1).toString() + ': ' + line).fontSize(11).fontFamily('monospace')
          }
        }, (line: string, idx: number) => idx.toString() + ':' + line)
      }.width('100%').height(80).border({ width: 1, color: '#CCCCCC' }).margin({ top: 2 })
    }.width('100%').height('100%').padding(12)
  }
}
