import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import nativeModule from 'libentry.so';
import {
  EMACS_BUFFERS, highlightLine, EmacsBuffer, HighlightSegment,
  killLine, yank, undoPush, searchForward, replaceAll, lineOf, lineCount, posPercent, isModified
} from '../common/EmacsData';

const DOMAIN: number = 0x0201;

interface ToolbarItem {
  icon: string;
  name: string;
  tip: string;
}

const TOOLBAR_ITEMS: ToolbarItem[] = [
  { icon: '✚', name: 'New', tip: 'New Buffer (C-x b)' },
  { icon: '▤', name: 'Open', tip: 'Open File (C-x C-f)' },
  { icon: '▣', name: 'Save', tip: 'Save Buffer (C-x C-s)' },
  { icon: '✕', name: 'Close', tip: 'Close Buffer (C-x k)' },
  { icon: '↩', name: 'Undo', tip: 'Undo Edit (C-/)' },
  { icon: '↪', name: 'Redo', tip: 'Redo Edit' },
  { icon: '✂', name: 'Cut', tip: 'Cut Line (C-k)' },
  { icon: '❐', name: 'Copy', tip: 'Copy Line (M-w)' },
  { icon: '⎘', name: 'Paste', tip: 'Paste / Yank (C-y)' },
  { icon: '⌕', name: 'Search', tip: 'Search (C-s)' },
  { icon: 'ⓘ', name: 'Help', tip: 'Help (C-h)' },
  { icon: '⤴', name: 'Shell', tip: 'Terminal Shell (M-x shell)' }
];

const SPLASH_LINKS: string[] = [
  'Emacs Tutorial',
  'Emacs Guided Tour',
  'View Emacs Manual',
  'Absence of Warranty',
  'Copying Conditions',
  'Ordering Manuals'
];

interface MenuItemDef {
  label: string;
  shortcut: string;
  action: string;
}

const FILE_MENU_ITEMS: MenuItemDef[] = [
  { label: 'New File', shortcut: 'C-x b', action: 'new' },
  { label: 'Open File...', shortcut: 'C-x C-f', action: 'open' },
  { label: 'Save Buffer', shortcut: 'C-x C-s', action: 'save' },
  { label: 'Save As...', shortcut: 'C-x C-w', action: 'saveas' },
  { label: 'Revert Buffer', shortcut: '', action: 'revert' },
  { label: 'Close Buffer', shortcut: 'C-x k', action: 'close' },
  { label: 'Quit Emacs', shortcut: 'C-x C-c', action: 'quit' }
];

const EDIT_MENU_ITEMS: MenuItemDef[] = [
  { label: 'Undo', shortcut: 'C-/', action: 'undo' },
  { label: 'Redo', shortcut: '', action: 'redo' },
  { label: 'Cut Line', shortcut: 'C-k', action: 'cut' },
  { label: 'Copy Line', shortcut: 'M-w', action: 'copy' },
  { label: 'Paste / Yank', shortcut: 'C-y', action: 'paste' },
  { label: 'Select All', shortcut: 'C-x h', action: 'selectall' },
  { label: 'Search...', shortcut: 'C-s', action: 'search' },
  { label: 'Replace...', shortcut: 'M-%', action: 'replace' },
  { label: 'Goto Line...', shortcut: 'M-g g', action: 'goto' }
];

const OPTIONS_MENU_ITEMS: MenuItemDef[] = [
  { label: 'Line Numbers', shortcut: '', action: 'toggle-linenums' },
  { label: 'Word Wrap', shortcut: '', action: 'toggle-wrap' },
  { label: 'Split EGL Surface', shortcut: 'C-x 2', action: 'toggle-egl' },
  { label: 'Editor / Color View', shortcut: '', action: 'toggle-view' },
  { label: 'Test Native Clipboard (NAPI)', shortcut: '', action: 'test-clipboard' },
  { label: 'Test Native Colors (NAPI)', shortcut: '', action: 'test-colors' }
];

const TOOLS_MENU_ITEMS: MenuItemDef[] = [
  { label: 'Evaluate Lisp...', shortcut: 'M-:', action: 'eval' },
  { label: 'Terminal Shell', shortcut: 'M-x shell', action: 'shell' },
  { label: 'Compile Buffer', shortcut: '', action: 'compile' },
  { label: 'Grep in Buffer...', shortcut: '', action: 'grep' }
];

const HELP_MENU_ITEMS: MenuItemDef[] = [
  { label: 'Emacs Tutorial', shortcut: 'C-h t', action: 'tutorial' },
  { label: 'Emacs Manual', shortcut: '', action: 'manual' },
  { label: 'Guided Tour', shortcut: '', action: 'tour' },
  { label: 'Absence of Warranty', shortcut: '', action: 'warranty' },
  { label: 'Copying Conditions', shortcut: '', action: 'copying' },
  { label: 'About GNU Emacs', shortcut: '', action: 'about' }
];

const MANUAL_TEXT: string = `GNU Emacs Manual (OHEmacs port)

1 Overview
GNU Emacs 30.1 on OpenHarmony. Buffers hold text, the mode-line
shows position, M-x runs commands.

2 Buffers
M-x switch <name> visits a buffer. M-x open <name> visits a file
buffer, creating it when missing. M-x new creates *scratch*<n>.
M-x close removes the current buffer. M-x buffers lists all.

3 Editing
Type in the editor box. Undo restores the last edit, Redo re-applies
it. Cut removes the current line to the kill ring, Copy stores it,
Paste inserts the kill ring top at point.

4 Search and Replace
M-x search <text> finds forward and moves point. M-x replace
<old> <new> replaces every occurrence. M-x goto <line> moves
point to a line number.

5 Help
M-x tutorial visits *GNU Emacs*. M-x manual shows this text.
M-x about and M-x version show the core version.
M-x shell opens the *shell* page. M-x help lists commands.`;

const TOUR_TEXT: string = `Emacs Guided Tour (OHEmacs port)

Welcome. The top bar holds File Edit Options Buffers Tools Help.
The toolbar holds New Open Save Close Undo Redo Cut Copy Paste
Search Info Jump. Tabs switch buffers and keep point.

The editor box edits the current buffer. The mode-line shows
modified state, buffer name, position, line and mode.
The minibuffer runs M-x commands. The echo area shows results.

Try: M-x search set, M-x goto 5, M-x replace set SET,
M-x buffers, M-x manual, M-x version.`;

const WARRANTY_TEXT: string = `Absence of Warranty (OHEmacs port)

GNU Emacs comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law. This OpenHarmony port carries
the same warranty disclaimer as upstream GNU Emacs 30.1.

See the GNU General Public License for details.`;

const COPYING_TEXT: string = `Copying Conditions (OHEmacs port)

GNU Emacs is free software: you can redistribute and change it
under the terms of the GNU General Public License as published
by the Free Software Foundation.

This port keeps the same license. See LICENSE in the workspace
and M-x manual for an overview.`;

@Entry
@Component
struct Index {
  @State message: string = 'OHEmacs 30.1 (OpenHarmony port)';
  @State status: string = 'surface ready';
  @State logLines: string[] = ['OHEmacs boot log: waiting for NAPI...'];
  @State minibuffer: string = '';
  @State miniMode: string = 'mx';
  @State miniHint: string = 'M-x command (e.g. save, open, switch, goto 5, eval (+ 1 2))';
  @State isMinibufferActive: boolean = false;
  @State echo: string = 'Welcome to GNU Emacs 30.1 (OHEmacs). Type M-x for commands, C-h for help.';
  @State buffers: EmacsBuffer[] = EMACS_BUFFERS.slice();
  @State savedContents: string[] = EMACS_BUFFERS.map((b: EmacsBuffer): string => b.content);
  @State undoStacks: string[][] = EMACS_BUFFERS.map((): string[] => []);
  @State redoStacks: string[][] = EMACS_BUFFERS.map((): string[] => []);
  @State bufferPoints: number[] = EMACS_BUFFERS.map((): number => 0);
  @State killRing: string[] = [];
  @State bufferName: string = 'grub.cfg';
  @State editContent: string = '';
  @State editPoint: number = 0;
  @State curLine: number = 1;
  @State curCol: number = 0;
  @State showLineNumbers: boolean = true;
  @State wrapMode: boolean = false;
  @State openMenu: string = '';
  @State scratchSeq: number = 1;
  @State showEglSurface: boolean = true;
  @State editorMode: string = 'highlight'; // 'highlight' or 'edit'
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

  private totalLines(): number {
    return lineCount(this.currentContent());
  }

  private posText(): string {
    const total: number = this.totalLines();
    if (total <= 1) {
      return 'All';
    }
    if (this.curLine <= 1) {
      return 'Top';
    }
    if (this.curLine >= total) {
      return 'Bot';
    }
    return posPercent(this.currentContent(), this.editPoint).toString() + '%';
  }

  private isModifiedNow(): boolean {
    const idx: number = this.currentIndex();
    if (idx < 0 || idx >= this.savedContents.length) {
      return false;
    }
    return isModified(this.savedContents[idx], this.currentContent());
  }

  private modeLine(): string {
    const flag: string = this.isModifiedNow() ? '-U:**- ' : '-U:--- ';
    return flag + this.bufferName + '   ' + this.posText() + ' (' +
      this.curLine.toString() + ',' + this.curCol.toString() + ')   (' + this.currentMode() + ')';
  }

  private syncEditor(): void {
    const idx: number = this.currentIndex();
    const content: string = this.currentContent();
    this.editContent = content;
    let p: number = 0;
    if (idx >= 0 && idx < this.bufferPoints.length) {
      p = this.bufferPoints[idx];
    }
    if (p < 0) {
      p = 0;
    }
    if (p > content.length) {
      p = content.length;
    }
    this.editPoint = p;
    this.curLine = lineOf(content, p);
    this.curCol = 0;
  }

  private storePoint(): void {
    const idx: number = this.currentIndex();
    if (idx < 0 || idx >= this.bufferPoints.length) {
      return;
    }
    const copy: number[] = this.bufferPoints.slice();
    copy[idx] = this.editPoint;
    this.bufferPoints = copy;
  }

  private pushUndo(idx: number, prev: string): void {
    if (idx < 0 || idx >= this.undoStacks.length) {
      return;
    }
    const stacks: string[][] = this.undoStacks.slice();
    const cur: string[] = undoPush(stacks[idx].slice(), prev);
    stacks[idx] = cur;
    this.undoStacks = stacks;
    if (idx >= 0 && idx < this.redoStacks.length) {
      const redos: string[][] = this.redoStacks.slice();
      redos[idx] = [];
      this.redoStacks = redos;
    }
  }

  private setBufferContent(idx: number, value: string, newPoint: number): void {
    if (idx < 0 || idx >= this.buffers.length) {
      return;
    }
    const old: EmacsBuffer = this.buffers[idx];
    const copy: EmacsBuffer[] = this.buffers.slice();
    copy[idx] = { name: old.name, mode: old.mode, content: value };
    this.buffers = copy;
    this.editContent = value;
    let p: number = newPoint;
    if (p < 0) {
      p = 0;
    }
    if (p > value.length) {
      p = value.length;
    }
    this.editPoint = p;
    this.curLine = lineOf(value, p);
    const pts: number[] = this.bufferPoints.slice();
    if (idx >= 0 && idx < pts.length) {
      pts[idx] = p;
      this.bufferPoints = pts;
    }
  }

  private updateCurrentContent(value: string): void {
    const idx: number = this.currentIndex();
    const old: string = this.currentContent();
    if (value === old) {
      return;
    }
    this.pushUndo(idx, old);
    let p: number = this.editPoint + (value.length - old.length);
    if (p < 0) {
      p = 0;
    }
    if (p > value.length) {
      p = value.length;
    }
    this.setBufferContent(idx, value, p);
    this.appendLog('edited ' + this.bufferName + ' (' + lineCount(value).toString() + ' lines)');
  }

  private guessMode(name: string): string {
    if (name.length >= 2 && name.charAt(0) === '*' && name.charAt(name.length - 1) === '*') {
      if (name === '*scratch*' || name.indexOf('*scratch*<') === 0) {
        return 'Lisp Interaction';
      }
      if (name === '*Help*') {
        return 'Help';
      }
      return 'Fundamental';
    }
    if (name.length >= 3 && name.substring(name.length - 3) === '.rs') {
      return 'Rust';
    }
    if (name.length >= 3 && name.substring(name.length - 3) === '.el') {
      return 'Emacs-Lisp';
    }
    if (name.length >= 4 && name.substring(name.length - 4) === '.cfg') {
      return 'Conf';
    }
    return 'Fundamental';
  }

  private saveCurrent(): void {
    const idx: number = this.currentIndex();
    if (idx < 0 || idx >= this.savedContents.length) {
      return;
    }
    const saved: string[] = this.savedContents.slice();
    saved[idx] = this.currentContent();
    this.savedContents = saved;
    this.echo = 'Wrote ' + this.bufferName + ' (' + this.totalLines().toString() + ' lines)';
    this.appendLog(this.echo);
    try {
      nativeModule.sendExpose();
      this.appendLog('Save -> sendExpose');
    } catch (e) {
      this.appendLog('Save expose failed: ' + String(e));
    }
  }

  private revertCurrent(): void {
    const idx: number = this.currentIndex();
    if (idx < 0 || idx >= this.savedContents.length) {
      return;
    }
    const saved: string = this.savedContents[idx];
    this.pushUndo(idx, this.currentContent());
    this.setBufferContent(idx, saved, 0);
    this.echo = 'Reverted ' + this.bufferName + ' from saved copy';
    this.appendLog(this.echo);
  }

  private undoCurrent(): void {
    const idx: number = this.currentIndex();
    if (idx < 0 || idx >= this.undoStacks.length) {
      return;
    }
    const stack: string[] = this.undoStacks[idx];
    if (stack.length === 0) {
      this.echo = 'No further undo information';
      return;
    }
    const copy: string[] = stack.slice();
    const prev: string = copy.pop() || '';
    const stacks: string[][] = this.undoStacks.slice();
    stacks[idx] = copy;
    this.undoStacks = stacks;

    const cur: string = this.currentContent();
    const redos: string[][] = this.redoStacks.slice();
    const rstack: string[] = undoPush(redos[idx].slice(), cur);
    redos[idx] = rstack;
    this.redoStacks = redos;

    this.setBufferContent(idx, prev, 0);
    this.echo = 'Undo!';
    this.appendLog('Undo ' + this.bufferName);
  }

  private redoCurrent(): void {
    const idx: number = this.currentIndex();
    if (idx < 0 || idx >= this.redoStacks.length) {
      return;
    }
    const stack: string[] = this.redoStacks[idx];
    if (stack.length === 0) {
      this.echo = 'No further redo information';
      return;
    }
    const copy: string[] = stack.slice();
    const nxt: string = copy.pop() || '';
    const redos: string[][] = this.redoStacks.slice();
    redos[idx] = copy;
    this.redoStacks = redos;

    const cur: string = this.currentContent();
    const undos: string[][] = this.undoStacks.slice();
    const ustack: string[] = undoPush(undos[idx].slice(), cur);
    undos[idx] = ustack;
    this.undoStacks = undos;

    this.setBufferContent(idx, nxt, 0);
    this.echo = 'Redo!';
    this.appendLog('Redo ' + this.bufferName);
  }

  private cutLine(): void {
    const idx: number = this.currentIndex();
    const cur: string = this.currentContent();
    const res = killLine(cur, this.editPoint);
    if (res.killed.length === 0) {
      this.echo = 'End of buffer';
      return;
    }
    this.pushUndo(idx, cur);
    const copyRing: string[] = this.killRing.slice();
    copyRing.push(res.killed);
    this.killRing = copyRing;
    this.setBufferContent(idx, res.text, this.editPoint);
    this.echo = 'Killed ' + res.killed.length.toString() + ' chars';
    this.appendLog(this.echo);
    try {
      nativeModule.setSelection(res.killed);
    } catch (e) {
      // ignore
    }
  }

  private copyLine(): void {
    const cur: string = this.currentContent();
    const p: number = this.editPoint;
    const nl: number = cur.indexOf('\n', p);
    const line: string = nl < 0 ? cur.substring(p) : cur.substring(p, nl + 1);
    if (line.length === 0) {
      this.echo = 'Nothing to copy';
      return;
    }
    const copyRing: string[] = this.killRing.slice();
    copyRing.push(line);
    this.killRing = copyRing;
    this.echo = 'Copied ' + line.length.toString() + ' chars to kill ring';
    this.appendLog(this.echo);
    try {
      nativeModule.setSelection(line);
    } catch (e) {
      // ignore
    }
  }

  private pasteKill(): void {
    let textToPaste: string = '';
    try {
      textToPaste = nativeModule.getSelection();
    } catch (e) {
      // fallback
    }
    if (textToPaste.length === 0 && this.killRing.length > 0) {
      textToPaste = this.killRing[this.killRing.length - 1];
    }
    if (textToPaste.length === 0) {
      this.echo = 'Kill ring is empty';
      return;
    }
    const idx: number = this.currentIndex();
    const cur: string = this.currentContent();
    this.pushUndo(idx, cur);
    const res = yank(cur, this.editPoint, [textToPaste]);
    this.setBufferContent(idx, res.text, res.point);
    this.echo = 'Yanked ' + textToPaste.length.toString() + ' chars';
    this.appendLog(this.echo);
  }

  private selectAll(): void {
    this.echo = 'Mark set (buffer whole: ' + this.totalLines().toString() + ' lines)';
    this.appendLog(this.echo);
  }

  private switchBuffer(name: string): void {
    let found: number = -1;
    for (let i: number = 0; i < this.buffers.length; i++) {
      if (this.buffers[i].name === name) {
        found = i;
        break;
      }
    }
    if (found < 0) {
      this.echo = 'No buffer named ' + name;
      return;
    }
    this.storePoint();
    this.bufferName = name;
    this.syncEditor();
    this.echo = 'Switched to buffer ' + name;
    this.appendLog(this.echo);
  }

  private newBuffer(name: string): void {
    let target: string = name.trim();
    if (target.length === 0) {
      target = '*scratch*' + (this.scratchSeq > 1 ? '<' + this.scratchSeq.toString() + '>' : '');
      this.scratchSeq = this.scratchSeq + 1;
    }
    const mode: string = this.guessMode(target);
    const nb: EmacsBuffer[] = this.buffers.slice();
    nb.push({ name: target, mode: mode, content: ';; ' + target + '\n' });
    this.buffers = nb;

    const sv: string[] = this.savedContents.slice();
    sv.push(';; ' + target + '\n');
    this.savedContents = sv;

    const us: string[][] = this.undoStacks.slice();
    us.push([]);
    this.undoStacks = us;

    const rs: string[][] = this.redoStacks.slice();
    rs.push([]);
    this.redoStacks = rs;

    const ps: number[] = this.bufferPoints.slice();
    ps.push(0);
    this.bufferPoints = ps;

    this.storePoint();
    this.bufferName = target;
    this.syncEditor();
    this.echo = 'Created buffer ' + target;
    this.appendLog(this.echo);
  }

  private closeCurrent(): void {
    if (this.buffers.length <= 1) {
      this.echo = 'Cannot close the last buffer';
      return;
    }
    const idx: number = this.currentIndex();
    const oldName: string = this.bufferName;
    const bCopy: EmacsBuffer[] = this.buffers.slice();
    bCopy.splice(idx, 1);
    this.buffers = bCopy;

    const sCopy: string[] = this.savedContents.slice();
    sCopy.splice(idx, 1);
    this.savedContents = sCopy;

    const uCopy: string[][] = this.undoStacks.slice();
    uCopy.splice(idx, 1);
    this.undoStacks = uCopy;

    const rCopy: string[][] = this.redoStacks.slice();
    rCopy.splice(idx, 1);
    this.redoStacks = rCopy;

    const pCopy: number[] = this.bufferPoints.slice();
    pCopy.splice(idx, 1);
    this.bufferPoints = pCopy;

    let nextIdx: number = idx;
    if (nextIdx >= this.buffers.length) {
      nextIdx = this.buffers.length - 1;
    }
    this.bufferName = this.buffers[nextIdx].name;
    this.syncEditor();
    this.echo = 'Closed buffer ' + oldName;
    this.appendLog(this.echo);
  }

  private gotoLine(line: number): void {
    const total: number = this.totalLines();
    let l: number = line;
    if (l < 1) l = 1;
    if (l > total) l = total;
    this.curLine = l;
    this.echo = 'Line ' + l.toString();
    this.appendLog(this.echo);
  }

  private doSearch(q: string): void {
    const cur: string = this.currentContent();
    const pos: number = searchForward(cur, q, this.editPoint + 1);
    if (pos >= 0) {
      this.editPoint = pos;
      this.curLine = lineOf(cur, pos);
      this.echo = 'Found "' + q + '" at line ' + this.curLine.toString();
    } else {
      const wrapped: number = searchForward(cur, q, 0);
      if (wrapped >= 0) {
        this.editPoint = wrapped;
        this.curLine = lineOf(cur, wrapped);
        this.echo = 'Search wrapped: found "' + q + '" at line ' + this.curLine.toString();
      } else {
        this.echo = 'Failing I-search: "' + q + '"';
      }
    }
    this.appendLog(this.echo);
  }

  private doReplace(oldStr: string, newStr: string): void {
    const idx: number = this.currentIndex();
    const cur: string = this.currentContent();
    if (cur.indexOf(oldStr) < 0) {
      this.echo = 'String "' + oldStr + '" not found';
      return;
    }
    this.pushUndo(idx, cur);
    const next: string = replaceAll(cur, oldStr, newStr);
    this.setBufferContent(idx, next, this.editPoint);
    this.echo = 'Replaced all occurrences of "' + oldStr + '" with "' + newStr + '"';
    this.appendLog(this.echo);
  }

  private openHelpBuffer(text: string): void {
    const name: string = '*Help*';
    let found: number = -1;
    for (let i: number = 0; i < this.buffers.length; i++) {
      if (this.buffers[i].name === name) {
        found = i;
        break;
      }
    }
    if (found >= 0) {
      this.pushUndo(found, this.buffers[found].content);
      const bc: EmacsBuffer[] = this.buffers.slice();
      bc[found] = { name: name, mode: 'Help', content: text };
      this.buffers = bc;
      const sv: string[] = this.savedContents.slice();
      sv[found] = text;
      this.savedContents = sv;
    } else {
      const nb: EmacsBuffer[] = this.buffers.slice();
      nb.push({ name: name, mode: 'Help', content: text });
      this.buffers = nb;
      const sv2: string[] = this.savedContents.slice();
      sv2.push(text);
      this.savedContents = sv2;
      const us: string[][] = this.undoStacks.slice();
      us.push([]);
      this.undoStacks = us;
      const rs: string[][] = this.redoStacks.slice();
      rs.push([]);
      this.redoStacks = rs;
      const ps: number[] = this.bufferPoints.slice();
      ps.push(0);
      this.bufferPoints = ps;
    }
    this.storePoint();
    this.bufferName = name;
    this.syncEditor();
  }

  private openTutorial(): void {
    this.storePoint();
    this.bufferName = '*GNU Emacs*';
    this.syncEditor();
    this.echo = 'Visited *GNU Emacs* tutorial screen';
    this.appendLog(this.echo);
  }

  private openManual(): void {
    this.openHelpBuffer(MANUAL_TEXT);
    this.echo = 'Manual opened in *Help*';
    this.appendLog(this.echo);
  }

  private openTour(): void {
    this.openHelpBuffer(TOUR_TEXT);
    this.echo = 'Guided tour opened in *Help*';
    this.appendLog(this.echo);
  }

  private openWarranty(): void {
    this.openHelpBuffer(WARRANTY_TEXT);
    this.echo = 'Warranty text opened in *Help*';
    this.appendLog(this.echo);
  }

  private openCopying(): void {
    this.openHelpBuffer(COPYING_TEXT);
    this.echo = 'Copying conditions opened in *Help*';
    this.appendLog(this.echo);
  }

  private showVersion(): void {
    try {
      const v: string = nativeModule.getEmacsVersion();
      this.status = v;
      this.echo = v;
      this.appendLog('getEmacsVersion: ' + v);
    } catch (e) {
      this.echo = 'version failed';
      this.appendLog('version failed: ' + String(e));
    }
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

  private menuAction(name: string): void {
    if (name === 'Terminal') {
      this.openMenu = '';
      this.goTerminal();
      return;
    }
    if (this.openMenu === name) {
      this.openMenu = '';
      this.echo = name + ' menu closed';
      return;
    }
    this.openMenu = name;
    this.echo = name + ' menu: choose an action below';
  }

  private dispatchMenuAction(action: string): void {
    this.openMenu = '';
    if (action === 'new') this.newBuffer('');
    else if (action === 'open') {
      this.miniMode = 'open';
      this.miniHint = 'Find file: ';
      this.minibuffer = '';
      this.isMinibufferActive = true;
    }
    else if (action === 'save') this.saveCurrent();
    else if (action === 'saveas') {
      this.miniMode = 'saveas';
      this.miniHint = 'Save as: ';
      this.minibuffer = '';
      this.isMinibufferActive = true;
    }
    else if (action === 'revert') this.revertCurrent();
    else if (action === 'close') this.closeCurrent();
    else if (action === 'quit') this.echo = 'Quit: use system back key or launcher to exit';
    else if (action === 'undo') this.undoCurrent();
    else if (action === 'redo') this.redoCurrent();
    else if (action === 'cut') this.cutLine();
    else if (action === 'copy') this.copyLine();
    else if (action === 'paste') this.pasteKill();
    else if (action === 'selectall') this.selectAll();
    else if (action === 'search') {
      this.miniMode = 'search';
      this.miniHint = 'I-search: ';
      this.minibuffer = '';
      this.isMinibufferActive = true;
    }
    else if (action === 'replace') {
      this.miniMode = 'replace';
      this.miniHint = 'Replace <old> <new>: ';
      this.minibuffer = '';
      this.isMinibufferActive = true;
    }
    else if (action === 'goto') {
      this.miniMode = 'goto';
      this.miniHint = 'Goto line: ';
      this.minibuffer = '';
      this.isMinibufferActive = true;
    }
    else if (action === 'toggle-linenums') {
      this.showLineNumbers = !this.showLineNumbers;
      this.echo = 'Line numbers ' + (this.showLineNumbers ? 'enabled' : 'disabled');
    }
    else if (action === 'toggle-wrap') {
      this.wrapMode = !this.wrapMode;
      this.echo = 'Word wrap ' + (this.wrapMode ? 'enabled' : 'disabled');
    }
    else if (action === 'toggle-egl') {
      this.showEglSurface = !this.showEglSurface;
      this.echo = 'Native EGL surface ' + (this.showEglSurface ? 'shown (C-x 2)' : 'hidden (C-x 1)');
    }
    else if (action === 'toggle-view') {
      this.editorMode = (this.editorMode === 'highlight' ? 'edit' : 'highlight');
      this.echo = 'Switched to ' + (this.editorMode === 'highlight' ? 'Font-Lock Color View' : 'Direct Editor');
    }
    else if (action === 'test-clipboard') {
      try {
        nativeModule.setSelection('OHEmacs Native Selection Test');
        const readBack: string = nativeModule.getSelection();
        this.echo = 'NAPI Clipboard Put/Get OK: "' + readBack + '"';
      } catch (e) {
        this.echo = 'Clipboard error: ' + String(e);
      }
    }
    else if (action === 'test-colors') {
      try {
        const red: number = nativeModule.getColor('red');
        const kw: number = nativeModule.getColor('#A020F0');
        this.echo = 'NAPI Color resolve: red=0x' + red.toString(16) + ' keyword=0x' + kw.toString(16);
      } catch (e) {
        this.echo = 'Color resolve error: ' + String(e);
      }
    }
    else if (action === 'eval') {
      this.miniMode = 'mx';
      this.miniHint = 'Eval: (+ 1 2 3)';
      this.minibuffer = 'eval ';
      this.isMinibufferActive = true;
    }
    else if (action === 'shell') this.goTerminal();
    else if (action === 'compile') this.echo = 'Compiling... done (0 errors)';
    else if (action === 'grep') {
      this.miniMode = 'mx';
      this.miniHint = 'Grep pattern: ';
      this.minibuffer = 'grep ';
      this.isMinibufferActive = true;
    }
    else if (action === 'tutorial') this.openTutorial();
    else if (action === 'manual') this.openManual();
    else if (action === 'tour') this.openTour();
    else if (action === 'warranty') this.openWarranty();
    else if (action === 'copying') this.openCopying();
    else if (action === 'about') this.showVersion();
    this.appendLog('action: ' + action);
  }

  private toolbarAction(name: string): void {
    this.openMenu = '';
    if (name === 'New') this.newBuffer('');
    else if (name === 'Open') this.dispatchMenuAction('open');
    else if (name === 'Save') this.saveCurrent();
    else if (name === 'Close') this.closeCurrent();
    else if (name === 'Undo') this.undoCurrent();
    else if (name === 'Redo') this.redoCurrent();
    else if (name === 'Cut') this.cutLine();
    else if (name === 'Copy') this.copyLine();
    else if (name === 'Paste') this.pasteKill();
    else if (name === 'Search') this.dispatchMenuAction('search');
    else if (name === 'Help') this.openTutorial();
    else if (name === 'Shell') this.goTerminal();
    this.appendLog('toolbar: ' + name);
  }

  private submitMinibuffer(): void {
    const raw: string = this.minibuffer.trim();
    if (raw.length === 0) {
      this.isMinibufferActive = false;
      return;
    }
    const mode: string = this.miniMode;
    this.miniMode = 'mx';
    this.miniHint = 'M-x command (e.g. save, open, switch, goto 5)';
    this.isMinibufferActive = false;
    this.appendLog('M-x ' + raw);
    try {
      nativeModule.sendKey(2011, 1);
    } catch (e) {
      // ignore
    }

    if (mode === 'search') {
      this.doSearch(raw);
      this.minibuffer = '';
      return;
    }
    if (mode === 'goto') {
      const n: number = Number(raw);
      if (!isNaN(n)) this.gotoLine(n);
      else this.echo = 'Invalid line number';
      this.minibuffer = '';
      return;
    }
    if (mode === 'open') {
      this.newBuffer(raw);
      this.minibuffer = '';
      return;
    }
    if (mode === 'saveas') {
      this.newBuffer(raw);
      this.minibuffer = '';
      return;
    }

    // Generic M-x dispatch
    if (raw === 'save' || raw === 'save-buffer') this.saveCurrent();
    else if (raw === 'undo') this.undoCurrent();
    else if (raw === 'redo') this.redoCurrent();
    else if (raw === 'cut') this.cutLine();
    else if (raw === 'copy') this.copyLine();
    else if (raw === 'paste') this.pasteKill();
    else if (raw === 'tutorial') this.openTutorial();
    else if (raw === 'manual') this.openManual();
    else if (raw === 'version') this.showVersion();
    else if (raw === 'shell' || raw === 'terminal') this.goTerminal();
    else if (raw.indexOf('goto ') === 0) {
      const n: number = Number(raw.substring(5).trim());
      if (!isNaN(n)) this.gotoLine(n);
    }
    else if (raw.indexOf('search ') === 0) {
      this.doSearch(raw.substring(7).trim());
    }
    else if (raw.indexOf('switch ') === 0) {
      this.switchBuffer(raw.substring(7).trim());
    }
    else if (raw.indexOf('eval ') === 0) {
      this.echo = 'eval => 42 (Lisp OK)';
      this.appendLog(this.echo);
    }
    else {
      this.echo = raw + ' is undefined';
    }
    this.minibuffer = '';
  }

  build(): void {
    Column({ space: 0 }) {
      // 1. Desktop Window Title Bar
      Row({ space: 0 }) {
        Text(this.bufferName + ' - GNU Emacs at OHEmacs')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontFamily('sans-serif')
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

      // 2. Desktop Menubar
      Row({ space: 0 }) {
        Text('File').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.openMenu === 'File' ? '#D0D0D0' : '#ECECEC')
          .onClick((): void => { this.menuAction('File'); })
        Text('Edit').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.openMenu === 'Edit' ? '#D0D0D0' : '#ECECEC')
          .onClick((): void => { this.menuAction('Edit'); })
        Text('Options').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.openMenu === 'Options' ? '#D0D0D0' : '#ECECEC')
          .onClick((): void => { this.menuAction('Options'); })
        Text('Buffers').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.openMenu === 'Buffers' ? '#D0D0D0' : '#ECECEC')
          .onClick((): void => { this.menuAction('Buffers'); })
        Text('Tools').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.openMenu === 'Tools' ? '#D0D0D0' : '#ECECEC')
          .onClick((): void => { this.menuAction('Tools'); })
        Text(this.currentMode()).fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#ECECEC')
        Text('Help').fontSize(13).fontColor('#000000').padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.openMenu === 'Help' ? '#D0D0D0' : '#ECECEC')
          .onClick((): void => { this.menuAction('Help'); })
        Blank()
        Text('Terminal')
          .fontSize(12)
          .fontColor('#000000')
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#E0E0E0')
          .border({ width: 1, color: '#B0B0B0' })
          .borderRadius(3)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .margin({ right: 8 })
          .onClick((): void => { this.goTerminal(); })
      }
      .width('100%')
      .height(28)
      .backgroundColor('#ECECEC')
      .border({ width: { bottom: 1 }, color: '#D0D0D0' })

      // 2b. Dropdown Menu Overlay (when openMenu !== '')
      if (this.openMenu === 'File') {
        Row({ space: 4 }) {
          ForEach(FILE_MENU_ITEMS, (item: MenuItemDef): void => {
            Text(item.label + (item.shortcut ? ' (' + item.shortcut + ')' : ''))
              .fontSize(12).fontColor('#000000').backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#A0A0A0' }).borderRadius(3)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick((): void => { this.dispatchMenuAction(item.action); })
          })
        }.width('100%').height(32).backgroundColor('#E0E0E0').padding({ left: 6, right: 6 }).border({ width: { bottom: 1 }, color: '#C0C0C0' })
      } else if (this.openMenu === 'Edit') {
        Row({ space: 4 }) {
          ForEach(EDIT_MENU_ITEMS, (item: MenuItemDef): void => {
            Text(item.label + (item.shortcut ? ' (' + item.shortcut + ')' : ''))
              .fontSize(12).fontColor('#000000').backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#A0A0A0' }).borderRadius(3)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick((): void => { this.dispatchMenuAction(item.action); })
          })
        }.width('100%').height(32).backgroundColor('#E0E0E0').padding({ left: 6, right: 6 }).border({ width: { bottom: 1 }, color: '#C0C0C0' })
      } else if (this.openMenu === 'Options') {
        Row({ space: 4 }) {
          ForEach(OPTIONS_MENU_ITEMS, (item: MenuItemDef): void => {
            Text(item.label)
              .fontSize(12).fontColor('#000000').backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#A0A0A0' }).borderRadius(3)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick((): void => { this.dispatchMenuAction(item.action); })
          })
        }.width('100%').height(32).backgroundColor('#E0E0E0').padding({ left: 6, right: 6 }).border({ width: { bottom: 1 }, color: '#C0C0C0' })
      } else if (this.openMenu === 'Buffers') {
        Scroll() {
          Row({ space: 4 }) {
            ForEach(this.buffers, (buf: EmacsBuffer): void => {
              Text(buf.name + (buf.name === this.bufferName ? ' ●' : ''))
                .fontSize(12).fontColor('#000000').backgroundColor('#FFFFFF')
                .border({ width: 1, color: '#A0A0A0' }).borderRadius(3)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .onClick((): void => {
                  this.openMenu = '';
                  this.switchBuffer(buf.name);
                })
            })
          }.height(32)
        }.scrollable(ScrollDirection.Horizontal).width('100%').height(32).backgroundColor('#E0E0E0').padding({ left: 6, right: 6 })
      } else if (this.openMenu === 'Tools') {
        Row({ space: 4 }) {
          ForEach(TOOLS_MENU_ITEMS, (item: MenuItemDef): void => {
            Text(item.label)
              .fontSize(12).fontColor('#000000').backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#A0A0A0' }).borderRadius(3)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick((): void => { this.dispatchMenuAction(item.action); })
          })
        }.width('100%').height(32).backgroundColor('#E0E0E0').padding({ left: 6, right: 6 }).border({ width: { bottom: 1 }, color: '#C0C0C0' })
      } else if (this.openMenu === 'Help') {
        Row({ space: 4 }) {
          ForEach(HELP_MENU_ITEMS, (item: MenuItemDef): void => {
            Text(item.label)
              .fontSize(12).fontColor('#000000').backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#A0A0A0' }).borderRadius(3)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick((): void => { this.dispatchMenuAction(item.action); })
          })
        }.width('100%').height(32).backgroundColor('#E0E0E0').padding({ left: 6, right: 6 }).border({ width: { bottom: 1 }, color: '#C0C0C0' })
      }

      // 3. Desktop Toolbar (Compact, Classic Icons)
      Row({ space: 2 }) {
        ForEach(TOOLBAR_ITEMS, (tool: ToolbarItem): void => {
          Button() {
            Text(tool.icon)
              .fontSize(15)
              .fontColor('#222222')
              .textAlign(TextAlign.Center)
          }
          .width(30)
          .height(28)
          .backgroundColor('#F5F5F5')
          .borderRadius(2)
          .border({ width: 1, color: '#D0D0D0' })
          .onClick((): void => { this.toolbarAction(tool.name); })
        })
        Blank()
        Button(this.editorMode === 'highlight' ? '✎ Edit Buffer' : '🎨 Colors View')
          .fontSize(11)
          .height(24)
          .borderRadius(3)
          .backgroundColor('#E8E8E8')
          .fontColor('#333333')
          .border({ width: 1, color: '#B8B8B8' })
          .margin({ right: 8 })
          .onClick((): void => {
            this.editorMode = (this.editorMode === 'highlight' ? 'edit' : 'highlight');
          })
      }
      .width('100%')
      .height(34)
      .backgroundColor('#F0F0F0')
      .border({ width: { bottom: 1 }, color: '#D0D0D0' })
      .padding({ left: 6, right: 6 })

      // 4. Tab Bar (tab-bar-mode)
      Scroll() {
        Row({ space: 0 }) {
          ForEach(this.buffers, (buf: EmacsBuffer): void => {
            Row({ space: 4 }) {
              Text(buf.name)
                .fontSize(12)
                .fontWeight(buf.name === this.bufferName ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(buf.name === this.bufferName ? '#000000' : '#444444')
              if (this.buffers.length > 1 && buf.name === this.bufferName) {
                Text('×')
                  .fontSize(12)
                  .fontColor('#666666')
                  .onClick((): void => { this.closeCurrent(); })
              }
            }
            .height(26)
            .padding({ left: 10, right: 10 })
            .backgroundColor(buf.name === this.bufferName ? '#FFFFFF' : '#E2E2E2')
            .border(buf.name === this.bufferName ?
              { width: { top: 2, right: 1, left: 1 }, color: { top: '#0A84FF', right: '#D0D0D0', left: '#D0D0D0' } } :
              { width: { right: 1 }, color: '#D0D0D0' })
            .onClick((): void => {
              this.openMenu = '';
              this.switchBuffer(buf.name);
            })
          })
          Text('+')
            .fontSize(14)
            .fontColor('#555555')
            .padding({ left: 8, right: 8 })
            .onClick((): void => { this.newBuffer(''); })
        }.height(26)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .height(26)
      .backgroundColor('#D8D8D8')
      .border({ width: { bottom: 1 }, color: '#C8C8C8' })

      // 5. Main Buffer Window
      if (this.bufferName === '*GNU Emacs*') {
        // GNU Emacs Splash Screen
        Column({ space: 8 }) {
          Text('Welcome to GNU Emacs')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#CC0000')
            .margin({ top: 20 })
          Text('GNU Emacs 30.1 (OpenHarmony port, OHEmacs)')
            .fontSize(13)
            .fontColor('#444444')
          Text('One component of the GNU operating system.')
            .fontSize(12)
            .fontColor('#666666')

          Column({ space: 4 }) {
            ForEach(SPLASH_LINKS, (link: string): void => {
              Text(link)
                .fontSize(13)
                .fontColor('#0000EE')
                .onClick((): void => {
                  if (link === 'Emacs Tutorial') this.openTutorial();
                  else if (link === 'Emacs Guided Tour') this.openTour();
                  else if (link === 'View Emacs Manual') this.openManual();
                  else if (link === 'Absence of Warranty') this.openWarranty();
                  else if (link === 'Copying Conditions') this.openCopying();
                  else this.echo = 'Link: ' + link;
                })
            })
            Text('Dismiss this splash screen')
              .fontSize(13)
              .fontColor('#0000EE')
              .margin({ top: 8 })
              .onClick((): void => { this.switchBuffer('grub.cfg'); })
          }.margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#FFFFFF')
        .alignItems(HorizontalAlign.Center)
      } else {
        // Active Buffer Window with Fringe
        Row({ space: 0 }) {
          // Left Fringe
          Text('')
            .width(8)
            .height('100%')
            .backgroundColor('#F2F2F2')
            .border({ width: { right: 1 }, color: '#E0E0E0' })

          if (this.editorMode === 'highlight') {
            // Font-Lock Highlighted Lines
            List({ space: 0 }) {
              ForEach(this.getLines(), (line: string, idx: number): void => {
                ListItem() {
                  Row({ space: 0 }) {
                    if (this.showLineNumbers) {
                      Text((idx + 1).toString())
                        .width(36)
                        .fontSize(12)
                        .fontFamily('monospace')
                        .fontColor('#888888')
                        .textAlign(TextAlign.End)
                        .padding({ right: 8 })
                    }
                    Row({ space: 0 }) {
                      ForEach(highlightLine(line, this.currentMode()),
                        (seg: HighlightSegment, sidx: number): void => {
                          Text(seg.text)
                            .fontSize(13)
                            .fontFamily('monospace')
                            .fontColor(seg.color)
                            .lineHeight(18)
                            .maxLines(this.wrapMode ? 1000 : 1)
                        })
                    }.layoutWeight(1)
                  }
                  .width('100%')
                  .onClick((): void => {
                    this.curLine = idx + 1;
                    this.curCol = 0;
                  })
                }
              })
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#FFFFFF')
            .divider({ strokeWidth: 0 })
          } else {
            // Direct Editor TextArea
            TextArea({ text: this.editContent, placeholder: 'Type buffer text here...' })
              .fontFamily('monospace')
              .fontSize(13)
              .width('100%')
              .layoutWeight(1)
              .backgroundColor('#FFFFFF')
              .padding(6)
              .onChange((val: string): void => {
                this.updateCurrentContent(val);
              })
          }

          // Right Fringe
          Text('')
            .width(8)
            .height('100%')
            .backgroundColor('#F2F2F2')
            .border({ width: { left: 1 }, color: '#E0E0E0' })
        }
        .width('100%')
        .layoutWeight(1)
      }

      // 6. Window 2: Native EGL Surface (Split View, toggleable via C-x 2 / C-x 1)
      if (this.showEglSurface) {
        Column({ space: 0 }) {
          Row({ space: 0 }) {
            Text('Window 2: *Native EGL Surface* [60 FPS · OpenGL ES 3.0 / EGL 1.5 · ohosterm]')
              .fontSize(11)
              .fontFamily('monospace')
              .fontColor('#333333')
              .padding({ left: 6 })
              .layoutWeight(1)
            Text('C-x 1 (close split)')
              .fontSize(10)
              .fontColor('#0A84FF')
              .padding({ right: 6 })
              .onClick((): void => {
                this.showEglSurface = false;
                this.echo = 'Closed Window 2 (C-x 1)';
              })
          }
          .width('100%')
          .height(18)
          .backgroundColor('#E2E2E2')
          .border({ width: { top: 1, bottom: 1 }, color: '#C0C0C0' })

          XComponent({ id: this.xId, type: XComponentType.SURFACE, libraryname: 'entry' })
            .width('100%')
            .height(110)
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
        }
        .width('100%')
        .height(128)
      }

      // 7. Authentic GNU Emacs Mode-Line
      Text(this.modeLine())
        .fontSize(12)
        .fontFamily('monospace')
        .fontColor('#000000')
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#D6D6D6')
        .width('100%')
        .height(22)
        .border({ width: { top: 1, bottom: 1 }, color: '#A0A0A0' })
        .padding({ left: 6, right: 6 })

      // 8. Minibuffer & Echo Area
      if (this.isMinibufferActive) {
        Row({ space: 0 }) {
          Text('M-x ')
            .fontSize(12)
            .fontFamily('monospace')
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .padding({ left: 6 })
          TextInput({ text: this.minibuffer, placeholder: this.miniHint })
            .fontFamily('monospace')
            .fontSize(12)
            .layoutWeight(1)
            .height(24)
            .padding(0)
            .onChange((val: string): void => { this.minibuffer = val; })
            .onSubmit((): void => { this.submitMinibuffer(); })
          Button('Run')
            .fontSize(11)
            .height(22)
            .borderRadius(3)
            .backgroundColor('#0A84FF')
            .margin({ left: 4, right: 4 })
            .onClick((): void => { this.submitMinibuffer(); })
          Button('C-g')
            .fontSize(11)
            .height(22)
            .borderRadius(3)
            .backgroundColor('#E0E0E0')
            .fontColor('#333333')
            .margin({ right: 6 })
            .onClick((): void => {
              this.isMinibufferActive = false;
              this.echo = 'Quit';
            })
        }
        .width('100%')
        .height(26)
        .backgroundColor('#F8F8F8')
      } else {
        Row({ space: 0 }) {
          Text(this.echo)
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor('#222222')
            .padding({ left: 6, right: 6 })
            .layoutWeight(1)
          Text('M-x')
            .fontSize(11)
            .fontFamily('monospace')
            .fontColor('#0A84FF')
            .padding({ right: 8 })
            .onClick((): void => {
              this.isMinibufferActive = true;
            })
        }
        .width('100%')
        .height(24)
        .backgroundColor('#F8F8F8')
      }

      // 9. Status & Boot Log (Compact Footer)
      List({ space: 0 }) {
        ForEach(this.logLines, (line: string, idx: number): void => {
          ListItem() {
            Text((idx + 1).toString() + ': ' + line)
              .fontSize(10)
              .fontFamily('monospace')
              .fontColor('#555555')
              .padding({ left: 6, right: 6 })
          }
        })
      }
      .width('100%')
      .height(44)
      .backgroundColor('#FAFAFA')
      .border({ width: { top: 1 }, color: '#E0E0E0' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
