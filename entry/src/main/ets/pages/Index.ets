import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import nativeModule from 'libentry.so';
import { EMACS_BUFFERS, highlightLine, EmacsBuffer, HighlightSegment } from '../common/EmacsData';

const DOMAIN: number = 0x0201;

interface ToolbarItem {
  icon: string;
  name: string;
}

const TOOLBAR_ITEMS: ToolbarItem[] = [
  { icon: '✚', name: 'New' },
  { icon: '▤', name: 'Open' },
  { icon: '▣', name: 'Save' },
  { icon: '✕', name: 'Close' },
  { icon: '↩', name: 'Undo' },
  { icon: '↪', name: 'Redo' },
  { icon: '✂', name: 'Cut' },
  { icon: '❐', name: 'Copy' },
  { icon: '⎘', name: 'Paste' },
  { icon: '⌕', name: 'Search' },
  { icon: 'ⓘ', name: 'Info' },
  { icon: '⤴', name: 'Jump' }
];

const SPLASH_LINKS: string[] = [
  'Emacs Tutorial',
  'Emacs Guided Tour',
  'View Emacs Manual',
  'Absence of Warranty',
  'Copying Conditions',
  'Ordering Manuals'
];

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
      const hello: string = nativeModule.hello();
      this.message = hello;
      this.appendLog('NAPI hello: ' + hello);
      const ver: string = nativeModule.getEmacsVersion();
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
    if (name === 'Terminal') {
      this.goTerminal();
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
      } else if (name === 'Help') {
        this.echo = 'commands: save | open <name> | switch <name> | tutorial | version';
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
    if (name === 'New') {
      try {
        nativeModule.sendExpose();
        this.appendLog('New -> sendExpose');
      } catch (e) {
        this.appendLog('New failed: ' + String(e));
      }
      this.echo = 'New (demo): use M-x switch <name>';
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
    if (name === 'Jump') {
      try {
        nativeModule.sendKey(2011, 1);
        this.appendLog('Jump -> sendKey Enter down (2011,1)');
      } catch (e) {
        this.appendLog('Jump failed: ' + String(e));
      }
      this.echo = 'Goto line (demo): M-x switch <name>';
      return;
    }
    if (name === 'Cut' || name === 'Copy' || name === 'Paste') {
      try {
        nativeModule.sendKey(2017, 1);
        this.appendLog(name + ' -> sendKey A down (2017,1)');
      } catch (e) {
        this.appendLog(name + ' failed: ' + String(e));
      }
      this.echo = name + ' (demo)';
      return;
    }
    if (name === 'Info') {
      try {
        const v: string = nativeModule.getEmacsVersion();
        this.echo = v;
        this.appendLog('Info -> ' + v);
      } catch (e) {
        this.appendLog('Info failed: ' + String(e));
      }
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
        const v: string = nativeModule.getEmacsVersion();
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

  private async goTerminalAsync(): Promise<void> {
    try {
      await router.pushUrl({ url: 'pages/Terminal' });
      this.appendLog('nav -> Terminal');
    } catch (e) {
      this.appendLog('nav failed: ' + String(e));
    }
  }

  private goTerminal(): void {
    this.goTerminalAsync();
  }

  build(): void {
    Column({ space: 0 }) {
      // Title: tight 24px GTK caption.
      Text(this.bufferName + ' - GNU Emacs at OHEmacs')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(24)
        .backgroundColor('#E8E8E8')
        .fontColor('#000000')
        .padding(0)
        .margin(0)

      // Menu bar: plain Texts, no Button chrome. H26 BG #F0F0F0 pad 0/2 gap 0.
      Scroll() {
        Row({ space: 0 }) {
          Text('File')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 })
            .margin(0)
            .onClick((): void => {
              this.menuAction('File');
            })
          Text('Edit')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 })
            .margin(0)
            .onClick((): void => {
              this.menuAction('Edit');
            })
          Text('Options')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 })
            .margin(0)
            .onClick((): void => {
              this.menuAction('Options');
            })
          Text('Buffers')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 })
            .margin(0)
            .onClick((): void => {
              this.menuAction('Buffers');
            })
          Text('Tools')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 })
            .margin(0)
            .onClick((): void => {
              this.menuAction('Tools');
            })
          Text(this.currentMode())
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 })
            .margin(0)
            .onClick((): void => {
              this.echo = this.currentMode() + ' mode';
              this.appendLog('mode: ' + this.currentMode());
            })
          Text('Help')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 })
            .margin(0)
            .onClick((): void => {
              this.menuAction('Help');
            })
          Text('Terminal')
            .fontSize(13).fontColor('#000000')
            .padding({ top: 2, bottom: 2, left: 6, right: 6 })
            .margin(0)
            .onClick((): void => {
              this.goTerminal();
            })
        }.height(26).padding(0).margin(0)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .height(26)
      .backgroundColor('#F0F0F0')
      .padding(0)
      .margin(0)

      // Toolbar: 28x28 Text cells, H36 BG #F0F0F0 bottom border #C0C0C0 pad 2 gap 2.
      Scroll() {
        Row({ space: 2 }) {
          ForEach(TOOLBAR_ITEMS, (item: ToolbarItem, idx: number): void => {
            Text(item.icon)
              .fontSize(16)
              .fontColor('#000000')
              .textAlign(TextAlign.Center)
              .width(28)
              .height(28)
              .borderRadius(3)
              .backgroundColor('#F0F0F0')
              .padding(0)
              .margin(0)
              .onClick((): void => {
                this.toolbarAction(item.name);
              })
          }, (item: ToolbarItem, idx: number): string => idx.toString() + ':' + item.name)
        }.height(32).padding(0).margin(0)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .height(36)
      .backgroundColor('#F0F0F0')
      .border({ width: { bottom: 1 }, color: '#C0C0C0' })
      .padding(2)
      .margin(0)

      // Tab bar: H24 BG #D6D6D6 gap 0.
      Scroll() {
        Row({ space: 0 }) {
          ForEach(this.buffers, (buf: EmacsBuffer, idx: number): void => {
            Text(buf.name)
              .fontSize(12)
              .fontColor('#000000')
              .fontWeight(this.bufferName === buf.name ? FontWeight.Bold : FontWeight.Normal)
              .backgroundColor(this.bufferName === buf.name ? '#FFFFFF' : '#DEDEDE')
              .border(this.bufferName === buf.name ?
                { width: { top: 2 }, color: '#0A84FF' } :
                { width: 0, color: '#DEDEDE' })
              .padding({ top: 2, bottom: 2, left: 8, right: 8 })
              .margin(0)
              .height(24)
              .onClick((): void => {
                this.switchBuffer(buf.name);
              })
          }, (buf: EmacsBuffer, idx: number): string => idx.toString() + ':' + buf.name)
        }.height(24).padding(0).margin(0)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .height(24)
      .backgroundColor('#D6D6D6')
      .padding(0)
      .margin(0)

      // Buffer with fringes: 8px #E8E8E8 gutters.
      Row({ space: 0 }) {
        Text('')
          .width(8).height('100%')
          .backgroundColor('#E8E8E8')
          .padding(0).margin(0)
        if (this.bufferName === '*GNU Emacs*') {
          Row({ space: 0 }) {
            Column({ space: 0 }) {
              Text('*GNU Emacs*')
                .fontSize(18).fontColor('#CC0000').fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center).width('100%')
                .padding(0).margin(0)
              Text('GNU Emacs 30.1 (OpenHarmony port, OHEmacs)')
                .fontSize(12).fontColor('#333333')
                .textAlign(TextAlign.Center).width('100%')
                .padding(0).margin(0)
              ForEach(SPLASH_LINKS, (link: string, idx: number): void => {
                Text(link)
                  .fontSize(13).fontColor('#0000EE')
                  .textAlign(TextAlign.Center).width('100%')
                  .padding(0).margin(0)
                  .onClick((): void => {
                    this.splashLink(link);
                  })
              }, (link: string, idx: number): string => idx.toString() + ':' + link)
              Text('Dismiss this splash')
                .fontSize(12).fontColor('#0000EE')
                .textAlign(TextAlign.Center).width('100%')
                .padding(0).margin(0)
                .onClick((): void => {
                  this.switchBuffer('grub.cfg');
                })
            }
            .width(600)
            .backgroundColor('#FFFFFF')
            .padding(0)
            .margin(0)
            .alignItems(HorizontalAlign.Center)
          }
          .layoutWeight(1)
          .height('100%')
          .backgroundColor('#FFFFFF')
          .justifyContent(FlexAlign.Center)
          .padding(0)
          .margin(0)
        } else {
          List({ space: 0 }) {
            ForEach(this.getLines(), (line: string, idx: number): void => {
              ListItem() {
                Row({ space: 0 }) {
                  Text((idx + 1).toString())
                    .width(36)
                    .fontSize(12)
                    .fontFamily('monospace')
                    .fontColor('#999999')
                    .textAlign(TextAlign.End)
                    .padding(0)
                    .margin(0)
                  Row({ space: 0 }) {
                    ForEach(highlightLine(line, this.currentMode()),
                      (seg: HighlightSegment, sidx: number): void => {
                        Text(seg.text)
                          .fontSize(13)
                          .fontFamily('monospace')
                          .fontColor(seg.color)
                          .lineHeight(16)
                          .padding(0)
                          .margin(0)
                      },
                      (seg: HighlightSegment, sidx: number): string =>
                        sidx.toString() + ':' + seg.text)
                  }.layoutWeight(1).padding(0).margin(0)
                }.width('100%').padding(0).margin(0)
              }.padding(0).margin(0)
            }, (line: string, idx: number): string => idx.toString() + ':' + line)
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#FFFFFF')
          .padding(0)
          .margin(0)
          .divider({ strokeWidth: 0 })
        }
        Text('')
          .width(8).height('100%')
          .backgroundColor('#E8E8E8')
          .padding(0).margin(0)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#FFFFFF')
      .padding(0)
      .margin(0)

      // Single editor TextArea, H100.
      TextArea({ placeholder: 'Edit buffer content here...', text: this.editContent })
        .fontFamily('monospace')
        .fontSize(13)
        .width('100%')
        .height(100)
        .padding(2)
        .margin(0)
        .onChange((value: string): void => {
          this.updateCurrentContent(value);
        })

      // XComponent surface proof, H100 + 11px status.
      Text('ohos frame surface: ' + this.status)
        .fontSize(11).fontColor('#444444')
        .width('100%')
        .padding({ left: 4, right: 4 })
        .margin(0)
      XComponent({ id: this.xId, type: XComponentType.SURFACE, libraryname: 'entry' })
        .width('100%')
        .height(100)
        .border({ width: 1, color: '#999999' })
        .padding(0)
        .margin(0)
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

      // Mode-line: H22 BG #E5E5E5 borders #999 pad 0/4.
      Text(this.modeLine())
        .fontSize(12)
        .fontFamily('monospace')
        .fontColor('#000000')
        .backgroundColor('#E5E5E5')
        .width('100%')
        .height(22)
        .border({ width: { top: 1, bottom: 1 }, color: '#999999' })
        .padding({ left: 4, right: 4 })
        .margin(0)

      // Minibuffer: H22 row.
      Row({ space: 0 }) {
        Text('M-x')
          .fontSize(12).fontFamily('monospace').fontColor('#000000')
          .height(22)
          .padding(0)
          .margin(0)
        TextInput({
          placeholder: 'save | open <name> | switch <name> | tutorial | version',
          text: this.minibuffer
        })
          .fontFamily('monospace')
          .fontSize(12)
          .layoutWeight(1)
          .height(22)
          .padding(0)
          .margin(0)
          .onChange((value: string): void => {
            this.minibuffer = value;
          })
          .onSubmit((): void => {
            this.submitMinibuffer();
          })
        Button('Go')
          .fontSize(12)
          .height(22)
          .borderRadius(3)
          .padding({ top: 2, bottom: 2, left: 6, right: 6 })
          .margin({ left: 4 })
          .onClick((): void => {
            this.submitMinibuffer();
          })
      }.width('100%').height(22).padding(0).margin(0)
      Text(this.echo)
        .fontSize(12).fontFamily('monospace').fontColor('#333333')
        .width('100%').height(22)
        .padding({ left: 4, right: 4 })
        .margin(0)

      // Log: H60 10px.
      List({ space: 0 }) {
        ForEach(this.logLines, (line: string, idx: number): void => {
          ListItem() {
            Text((idx + 1).toString() + ': ' + line)
              .fontSize(10).fontFamily('monospace').fontColor('#000000')
              .padding(0).margin(0)
          }.padding(0).margin(0)
        }, (line: string, idx: number): string => idx.toString() + ':' + line)
      }
      .width('100%')
      .height(60)
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 1 }, color: '#999999' })
      .padding(0)
      .margin(0)
      .divider({ strokeWidth: 0 })
    }
    .width('100%')
    .height('100%')
    .padding(0)
    .margin(0)
    .backgroundColor('#FFFFFF')
  }
}
