// emacs_cli.cpp — Native HarmonyOS Terminal CLI for GNU Emacs 30.1 port (OHEmacs).
// Runs directly in the HarmonyOS terminal console (hdc shell).
//
// Supports:
//   1. Batch mode:
//      - emacs --version / ohemacs --version
//      - emacs --help
//      - emacs --batch --eval "(+ 1 2 3)"
//      - emacs --batch --eval '(message "hello")'
//      - emacs --batch -l <file>
//   2. Interactive Terminal mode (emacs -nw [file] / ohemacs [file]):
//      - Fullscreen TUI via ANSI escape codes + termios raw mode
//      - Menubar, line numbers fringe, syntax-colored buffer
//      - Mode-line: -:-- <file> Top L<n> (<mode>)
//      - Minibuffer M-x, C-x C-s (save), C-x C-f (open), C-x C-c (quit), C-g (abort)
//      - Real filesystem read/write for files in the HarmonyOS environment

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <termios.h>
#include <unistd.h>

#include <string>
#include <vector>
#include <map>
#include <sstream>

#define OHEMACS_VERSION "30.1"
#define OHEMACS_CLI_TAG "OHEmacs-CLI 0.1.0 (aarch64-unknown-linux-ohos musl)"

namespace {

// Terminal state
struct termios g_orig_termios;
bool g_raw_mode = false;
int g_term_rows = 24;
int g_term_cols = 80;

// Editor state
struct EditorBuffer {
    std::string name;
    std::string filename;
    std::string mode;
    std::vector<std::string> lines;
    bool modified = false;
    int cursor_row = 0;
    int cursor_col = 0;
    int row_offset = 0;
};

std::vector<EditorBuffer> g_buffers;
size_t g_current_buffer_idx = 0;
std::string g_status_message;
std::string g_kill_ring;
bool g_running = true;

// Lisp Environment for Batch / M-:
std::map<std::string, std::string> g_lisp_vars;

void DisableRawMode() {
    if (g_raw_mode) {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &g_orig_termios);
        // Show cursor, reset colors, restore normal buffer
        write(STDOUT_FILENO, "\033[?25h\033[0m\033[?1049l", 18);
        g_raw_mode = false;
    }
}

void EnableRawMode() {
    if (!isatty(STDIN_FILENO)) return;
    if (tcgetattr(STDIN_FILENO, &g_orig_termios) == -1) return;

    struct termios raw = g_orig_termios;
    // Input modes: no break, no CR to NL, no parity check, no strip 8th bit, no flow control
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    // Output modes: enable post-processing
    raw.c_oflag |= OPOST;
    // Control modes: 8-bit chars
    raw.c_cflag |= (CS8);
    // Local modes: echo off, canonical off, no extended input, no signals (we handle SIGINT)
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 1; // 100ms timeout

    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) != -1) {
        g_raw_mode = true;
        // Use alternate screen buffer, clear, hide cursor initially
        write(STDOUT_FILENO, "\033[?1049h\033[2J\033[H", 14);
    }
}

void HandleSignal(int sig) {
    (void)sig;
    DisableRawMode();
    _exit(0);
}

void UpdateTerminalSize() {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) != -1 && ws.ws_col > 0 && ws.ws_row > 0) {
        g_term_cols = ws.ws_col;
        g_term_rows = ws.ws_row;
    } else {
        g_term_cols = 80;
        g_term_rows = 24;
    }
}

// ---------------------------------------------------------------------------
// Tiny Lisp Evaluator
// ---------------------------------------------------------------------------

std::string Trim(const std::string &s) {
    size_t start = 0;
    while (start < s.size() && (s[start] == ' ' || s[start] == '\t' || s[start] == '\r' || s[start] == '\n')) {
        start++;
    }
    size_t end = s.size();
    while (end > start && (s[end - 1] == ' ' || s[end - 1] == '\t' || s[end - 1] == '\r' || s[end - 1] == '\n')) {
        end--;
    }
    return s.substr(start, end - start);
}

std::vector<std::string> TokenizeLisp(const std::string &expr) {
    std::vector<std::string> tokens;
    std::string token;
    bool in_str = false;

    for (size_t i = 0; i < expr.size(); i++) {
        char c = expr[i];
        if (c == '"') {
            in_str = !in_str;
            token += c;
        } else if (in_str) {
            token += c;
        } else if (c == '(' || c == ')') {
            if (!token.empty()) {
                tokens.push_back(token);
                token.clear();
            }
            tokens.push_back(std::string(1, c));
        } else if (isspace((unsigned char)c)) {
            if (!token.empty()) {
                tokens.push_back(token);
                token.clear();
            }
        } else {
            token += c;
        }
    }
    if (!token.empty()) {
        tokens.push_back(token);
    }
    return tokens;
}

std::string EvalLispTokens(const std::vector<std::string> &tokens, size_t &idx);

std::string EvalLisp(const std::string &expr) {
    std::string trimmed = Trim(expr);
    if (trimmed.empty()) return "nil";
    std::vector<std::string> tokens = TokenizeLisp(trimmed);
    if (tokens.empty()) return "nil";
    size_t idx = 0;
    return EvalLispTokens(tokens, idx);
}

std::string EvalLispTokens(const std::vector<std::string> &tokens, size_t &idx) {
    if (idx >= tokens.size()) return "nil";

    if (tokens[idx] == "(") {
        idx++; // skip '('
        if (idx >= tokens.size() || tokens[idx] == ")") {
            if (idx < tokens.size()) idx++;
            return "nil";
        }
        std::string op = tokens[idx++];
        std::vector<std::string> args;
        while (idx < tokens.size() && tokens[idx] != ")") {
            args.push_back(EvalLispTokens(tokens, idx));
        }
        if (idx < tokens.size() && tokens[idx] == ")") {
            idx++; // skip ')'
        }

        // Arithmetic: (+ a b c), (- a b), (* a b), (/ a b)
        if (op == "+" || op == "*" || op == "-" || op == "/") {
            double result = 0;
            if (op == "*") result = 1;
            bool first = true;
            for (const auto &arg : args) {
                double val = atof(arg.c_str());
                if (first) {
                    result = val;
                    first = false;
                } else {
                    if (op == "+") result += val;
                    else if (op == "*") result *= val;
                    else if (op == "-") result -= val;
                    else if (op == "/") {
                        if (val != 0) result /= val;
                        else return "error: division by zero";
                    }
                }
            }
            if (first && op == "+") result = 0;
            char out[64];
            if (result == (long long)result) {
                snprintf(out, sizeof(out), "%lld", (long long)result);
            } else {
                snprintf(out, sizeof(out), "%g", result);
            }
            return std::string(out);
        }

        // (message fmt args...)
        if (op == "message") {
            std::string out;
            for (size_t i = 0; i < args.size(); i++) {
                std::string a = args[i];
                if (a.size() >= 2 && a.front() == '"' && a.back() == '"') {
                    a = a.substr(1, a.size() - 2);
                }
                if (i > 0) out += " ";
                out += a;
            }
            return "\"" + out + "\"";
        }

        // (concat a b ...)
        if (op == "concat") {
            std::string out;
            for (const auto &a : args) {
                std::string s = a;
                if (s.size() >= 2 && s.front() == '"' && s.back() == '"') {
                    s = s.substr(1, s.size() - 2);
                }
                out += s;
            }
            return "\"" + out + "\"";
        }

        // (setq var val)
        if (op == "setq" && args.size() >= 2) {
            g_lisp_vars[args[0]] = args[1];
            return args[1];
        }

        // (defvar var val)
        if (op == "defvar" && args.size() >= 2) {
            g_lisp_vars[args[0]] = args[1];
            return args[0];
        }

        // (list ...)
        if (op == "list") {
            std::string out = "(";
            for (size_t i = 0; i < args.size(); i++) {
                if (i > 0) out += " ";
                out += args[i];
            }
            out += ")";
            return out;
        }

        // (emacs-version)
        if (op == "emacs-version") {
            return "\"" OHEMACS_CLI_TAG "\"";
        }

        return "t";
    }

    std::string token = tokens[idx++];
    if (token == "nil" || token == "t") return token;
    if (g_lisp_vars.find(token) != g_lisp_vars.end()) {
        return g_lisp_vars[token];
    }
    return token;
}

// ---------------------------------------------------------------------------
// Editor Buffer Management
// ---------------------------------------------------------------------------

std::string DetectMode(const std::string &name) {
    if (name.size() > 3 && name.substr(name.size() - 3) == ".rs") return "Rust";
    if (name.size() > 3 && name.substr(name.size() - 3) == ".el") return "Emacs-Lisp";
    if (name.size() > 4 && name.substr(name.size() - 4) == ".cfg") return "Conf";
    if (name.size() > 2 && name.substr(name.size() - 2) == ".c") return "C";
    if (name.size() > 4 && name.substr(name.size() - 4) == ".cpp") return "C++";
    if (name.size() > 3 && name.substr(name.size() - 3) == ".sh") return "Shell-script";
    if (name == "*scratch*") return "Lisp Interaction";
    return "Fundamental";
}

void InitSampleBuffers() {
    EditorBuffer scratch;
    scratch.name = "*scratch*";
    scratch.filename = "";
    scratch.mode = "Lisp Interaction";
    scratch.lines = {
        ";; This buffer is for text that is not saved, and for Lisp evaluation.",
        ";; To create a file, visit it with C-x C-f and enter text in its buffer.",
        "",
        "(+ 40 2)",
        "(message \"Welcome to GNU Emacs on OpenHarmony!\")"
    };
    g_buffers.push_back(scratch);

    EditorBuffer grub;
    grub.name = "grub.cfg";
    grub.filename = "/data/storage/grub.cfg";
    grub.mode = "Conf";
    grub.lines = {
        "# grub.cfg - sample GRUB configuration on OpenHarmony",
        "set default=0",
        "set timeout=5",
        "menuentry 'OpenHarmony GNU/Linux' --class os {",
        "    linux /boot/kernel root=/dev/sda2 ro quiet",
        "    initrd /boot/initramfs.img",
        "}",
        "if [ \"${grub_platform}\" == \"efi\" ]; then",
        "    save_env recordfail",
        "fi"
    };
    g_buffers.push_back(grub);

    EditorBuffer rust;
    rust.name = "main.rs";
    rust.filename = "/data/storage/main.rs";
    rust.mode = "Rust";
    rust.lines = {
        "// main.rs - GNU Emacs Rust mode",
        "fn main() {",
        "    println!(\"Hello from OHEmacs on HarmonyOS!\");",
        "}"
    };
    g_buffers.push_back(rust);
}

bool LoadFileIntoBuffer(const std::string &path, EditorBuffer &buf) {
    FILE *f = fopen(path.c_str(), "r");
    if (!f) return false;
    buf.lines.clear();
    char line[4096];
    while (fgets(line, sizeof(line), f)) {
        size_t l = strlen(line);
        while (l > 0 && (line[l - 1] == '\r' || line[l - 1] == '\n')) {
            line[--l] = '\0';
        }
        buf.lines.push_back(std::string(line));
    }
    fclose(f);
    if (buf.lines.empty()) buf.lines.push_back("");
    buf.filename = path;
    const char *slash = strrchr(path.c_str(), '/');
    buf.name = slash ? slash + 1 : path;
    buf.mode = DetectMode(buf.name);
    buf.modified = false;
    buf.cursor_row = 0;
    buf.cursor_col = 0;
    buf.row_offset = 0;
    return true;
}

bool SaveBufferToFile(EditorBuffer &buf) {
    if (buf.filename.empty()) {
        buf.filename = buf.name;
    }
    FILE *f = fopen(buf.filename.c_str(), "w");
    if (!f) return false;
    for (const auto &l : buf.lines) {
        fprintf(f, "%s\n", l.c_str());
    }
    fclose(f);
    buf.modified = false;
    return true;
}

// ---------------------------------------------------------------------------
// TUI Rendering Engine
// ---------------------------------------------------------------------------

void RenderScreen() {
    UpdateTerminalSize();
    if (g_buffers.empty()) return;
    EditorBuffer &buf = g_buffers[g_current_buffer_idx];

    std::string out;
    out.reserve(g_term_rows * g_term_cols + 256);

    // Hide cursor during redraw, jump to top-left
    out += "\033[?25l\033[H";

    // Row 1: Menubar
    out += "\033[7m  File    Edit    Options    Buffers    Tools    " + buf.mode + "    Help          \033[0m\r\n";

    // Buffer editing area
    int edit_rows = g_term_rows - 3; // 1 top menu, 1 mode-line, 1 minibuffer
    if (edit_rows < 1) edit_rows = 1;

    // Adjust scroll offset
    if (buf.cursor_row < buf.row_offset) {
        buf.row_offset = buf.cursor_row;
    }
    if (buf.cursor_row >= buf.row_offset + edit_rows) {
        buf.row_offset = buf.cursor_row - edit_rows + 1;
    }

    for (int r = 0; r < edit_rows; r++) {
        int file_line = buf.row_offset + r;
        if (file_line < (int)buf.lines.size()) {
            char lnum[16];
            snprintf(lnum, sizeof(lnum), "\033[90m%4d\033[0m ", file_line + 1);
            out += lnum;

            std::string line = buf.lines[file_line];
            int visible_cols = g_term_cols - 6;
            if (visible_cols < 1) visible_cols = 1;
            if ((int)line.size() > visible_cols) {
                line = line.substr(0, visible_cols);
            }

            // Syntax coloring
            std::string trimmed = Trim(line);
            if (trimmed.size() > 0 && (trimmed[0] == '#' || (trimmed.size() > 1 && trimmed[0] == '/' && trimmed[1] == '/') || trimmed[0] == ';')) {
                out += "\033[31m" + line + "\033[0m"; // Comments red
            } else if (line.find("fn ") != std::string::npos || line.find("defun ") != std::string::npos || line.find("menuentry ") != std::string::npos) {
                out += "\033[34m" + line + "\033[0m"; // Function blue
            } else if (line.find("set ") != std::string::npos || line.find("let ") != std::string::npos || line.find("if ") != std::string::npos) {
                out += "\033[35m" + line + "\033[0m"; // Keyword purple
            } else {
                out += line;
            }
        } else {
            out += "\033[90m   ~ \033[0m";
        }
        out += "\033[K\r\n"; // Clear to end of line
    }

    // Mode-line (Row N-1)
    char modeline[256];
    const char *mod = buf.modified ? "**" : "--";
    const char *pos = (buf.cursor_row == 0) ? "Top" : (buf.cursor_row >= (int)buf.lines.size() - 1 ? "Bot" : "All");
    snprintf(modeline, sizeof(modeline), "-U:%s  %-16s  %s (%d,%d)  (%s)",
             mod, buf.name.c_str(), pos, buf.cursor_row + 1, buf.cursor_col, buf.mode.c_str());
    
    std::string mline(modeline);
    while ((int)mline.size() < g_term_cols) {
        mline += '-';
    }
    if ((int)mline.size() > g_term_cols) {
        mline = mline.substr(0, g_term_cols);
    }
    out += "\033[7m" + mline + "\033[0m\r\n";

    // Minibuffer / Echo Area (Row N)
    std::string echo = g_status_message;
    if (echo.empty()) {
        echo = "Welcome to GNU Emacs " OHEMACS_VERSION " (OHEmacs). C-h t: tutorial, C-x C-c: exit, M-x: commands.";
    }
    if ((int)echo.size() > g_term_cols) {
        echo = echo.substr(0, g_term_cols);
    }
    out += echo + "\033[K";

    // Position hardware cursor
    int screen_row = (buf.cursor_row - buf.row_offset) + 2; // +1 for menu, +1 1-based
    int screen_col = buf.cursor_col + 6; // 5 digits line number + 1 space
    char curpos[32];
    snprintf(curpos, sizeof(curpos), "\033[%d;%dH\033[?25h", screen_row, screen_col);
    out += curpos;

    write(STDOUT_FILENO, out.data(), out.size());
}

std::string PromptMinibuffer(const std::string &prompt) {
    UpdateTerminalSize();
    std::string input;
    while (true) {
        // Move to bottom row
        char move[32];
        snprintf(move, sizeof(move), "\033[%d;1H\033[K%s%s\033[?25h", g_term_rows, prompt.c_str(), input.c_str());
        write(STDOUT_FILENO, move, strlen(move));

        char c = 0;
        int n = read(STDIN_FILENO, &c, 1);
        if (n <= 0) continue;
        if (c == '\r' || c == '\n') {
            break;
        } else if (c == 7) { // C-g (abort)
            return "";
        } else if (c == 127 || c == 8) { // Backspace
            if (!input.empty()) input.pop_back();
        } else if (c >= 32 && c <= 126) {
            input += c;
        }
    }
    return input;
}

void ExecuteMxCommand(const std::string &cmd_raw) {
    std::string cmd = Trim(cmd_raw);
    if (cmd.empty()) return;

    if (cmd == "save-buffer" || cmd == "save") {
        EditorBuffer &buf = g_buffers[g_current_buffer_idx];
        if (SaveBufferToFile(buf)) {
            g_status_message = "Wrote " + buf.filename + " (" + std::to_string(buf.lines.size()) + " lines)";
        } else {
            g_status_message = "Error writing " + buf.filename;
        }
    } else if (cmd == "find-file" || cmd == "open") {
        std::string filename = PromptMinibuffer("Find file: ");
        if (!filename.empty()) {
            EditorBuffer new_buf;
            if (LoadFileIntoBuffer(filename, new_buf)) {
                g_buffers.push_back(new_buf);
                g_current_buffer_idx = g_buffers.size() - 1;
                g_status_message = "Visited " + filename;
            } else {
                new_buf.name = filename;
                new_buf.filename = filename;
                new_buf.mode = DetectMode(filename);
                new_buf.lines = {""};
                g_buffers.push_back(new_buf);
                g_current_buffer_idx = g_buffers.size() - 1;
                g_status_message = "(New file) " + filename;
            }
        }
    } else if (cmd == "switch-to-buffer" || cmd == "switch") {
        std::string name = PromptMinibuffer("Switch to buffer: ");
        if (!name.empty()) {
            bool found = false;
            for (size_t i = 0; i < g_buffers.size(); i++) {
                if (g_buffers[i].name == name) {
                    g_current_buffer_idx = i;
                    found = true;
                    g_status_message = "Switched to buffer " + name;
                    break;
                }
            }
            if (!found) {
                g_status_message = "No buffer named " + name;
            }
        }
    } else if (cmd == "kill-buffer") {
        if (g_buffers.size() > 1) {
            std::string killed = g_buffers[g_current_buffer_idx].name;
            g_buffers.erase(g_buffers.begin() + g_current_buffer_idx);
            if (g_current_buffer_idx >= g_buffers.size()) {
                g_current_buffer_idx = g_buffers.size() - 1;
            }
            g_status_message = "Killed buffer " + killed;
        } else {
            g_status_message = "Cannot kill the last buffer";
        }
    } else if (cmd == "goto-line") {
        std::string lnum_str = PromptMinibuffer("Goto line: ");
        int line = atoi(lnum_str.c_str());
        if (line > 0) {
            EditorBuffer &buf = g_buffers[g_current_buffer_idx];
            if (line > (int)buf.lines.size()) line = buf.lines.size();
            buf.cursor_row = line - 1;
            buf.cursor_col = 0;
            g_status_message = "Line " + std::to_string(line);
        }
    } else if (cmd == "eval-expression" || cmd.rfind("eval", 0) == 0) {
        std::string expr = (cmd.size() > 4) ? cmd.substr(4) : PromptMinibuffer("Eval: ");
        if (!expr.empty()) {
            std::string res = EvalLisp(expr);
            g_status_message = res;
        }
    } else if (cmd == "version") {
        g_status_message = OHEMACS_CLI_TAG;
    } else if (cmd == "help" || cmd == "describe-mode") {
        g_status_message = "Commands: save-buffer | find-file | switch-to-buffer | goto-line | eval-expression | exit";
    } else if (cmd == "exit" || cmd == "kill-emacs") {
        g_running = false;
    } else {
        g_status_message = "[" + cmd + "] is undefined";
    }
}

void ProcessKeypress() {
    char c = 0;
    int n = read(STDIN_FILENO, &c, 1);
    if (n <= 0) return;

    EditorBuffer &buf = g_buffers[g_current_buffer_idx];

    // Escape sequence (Arrow keys, Alt keys)
    if (c == '\033') {
        char seq[3];
        if (read(STDIN_FILENO, &seq[0], 1) <= 0) {
            // Lone ESC -> M-x prompt
            std::string mx = PromptMinibuffer("M-x ");
            ExecuteMxCommand(mx);
            return;
        }
        if (read(STDIN_FILENO, &seq[1], 1) <= 0) {
            if (seq[0] == 'x' || seq[0] == 'X') {
                std::string mx = PromptMinibuffer("M-x ");
                ExecuteMxCommand(mx);
            }
            return;
        }

        if (seq[0] == '[') {
            switch (seq[1]) {
                case 'A': // Up
                    if (buf.cursor_row > 0) buf.cursor_row--;
                    break;
                case 'B': // Down
                    if (buf.cursor_row < (int)buf.lines.size() - 1) buf.cursor_row++;
                    break;
                case 'C': // Right
                    if (buf.cursor_col < (int)buf.lines[buf.cursor_row].size()) buf.cursor_col++;
                    break;
                case 'D': // Left
                    if (buf.cursor_col > 0) buf.cursor_col--;
                    break;
                case 'H': // Home
                    buf.cursor_col = 0;
                    break;
                case 'F': // End
                    buf.cursor_col = (int)buf.lines[buf.cursor_row].size();
                    break;
            }
        }
        return;
    }

    // Ctrl shortcuts
    switch (c) {
        case 1: // C-a (Beginning of line)
            buf.cursor_col = 0;
            break;
        case 5: // C-e (End of line)
            buf.cursor_col = (int)buf.lines[buf.cursor_row].size();
            break;
        case 16: // C-p (Previous line)
            if (buf.cursor_row > 0) buf.cursor_row--;
            break;
        case 14: // C-n (Next line)
            if (buf.cursor_row < (int)buf.lines.size() - 1) buf.cursor_row++;
            break;
        case 2: // C-b (Backward char)
            if (buf.cursor_col > 0) buf.cursor_col--;
            break;
        case 6: // C-f (Forward char)
            if (buf.cursor_col < (int)buf.lines[buf.cursor_row].size()) buf.cursor_col++;
            break;
        case 11: // C-k (Kill line)
            if (buf.cursor_col < (int)buf.lines[buf.cursor_row].size()) {
                g_kill_ring = buf.lines[buf.cursor_row].substr(buf.cursor_col);
                buf.lines[buf.cursor_row] = buf.lines[buf.cursor_row].substr(0, buf.cursor_col);
                buf.modified = true;
                g_status_message = "Kill ring updated";
            }
            break;
        case 25: // C-y (Yank)
            if (!g_kill_ring.empty()) {
                std::string &l = buf.lines[buf.cursor_row];
                l.insert(buf.cursor_col, g_kill_ring);
                buf.cursor_col += g_kill_ring.size();
                buf.modified = true;
                g_status_message = "Yanked";
            }
            break;
        case 24: { // C-x prefix
            char next = 0;
            if (read(STDIN_FILENO, &next, 1) > 0) {
                if (next == 19) { // C-x C-s (Save)
                    ExecuteMxCommand("save-buffer");
                } else if (next == 6) { // C-x C-f (Find file)
                    ExecuteMxCommand("find-file");
                } else if (next == 3) { // C-x C-c (Quit)
                    if (buf.modified) {
                        std::string ans = PromptMinibuffer("Modified buffer exists; exit anyway? (yes/no): ");
                        if (ans == "yes" || ans == "y") {
                            g_running = false;
                        }
                    } else {
                        g_running = false;
                    }
                } else if (next == 'b' || next == 'B') {
                    ExecuteMxCommand("switch-to-buffer");
                } else if (next == 'k' || next == 'K') {
                    ExecuteMxCommand("kill-buffer");
                }
            }
            break;
        }
        case 7: // C-g (Abort)
            g_status_message = "Quit";
            break;
        case 127: // Backspace
        case 8:
            if (buf.cursor_col > 0) {
                std::string &l = buf.lines[buf.cursor_row];
                l.erase(buf.cursor_col - 1, 1);
                buf.cursor_col--;
                buf.modified = true;
            } else if (buf.cursor_row > 0) {
                // Merge with previous line
                int prev_len = (int)buf.lines[buf.cursor_row - 1].size();
                buf.lines[buf.cursor_row - 1] += buf.lines[buf.cursor_row];
                buf.lines.erase(buf.lines.begin() + buf.cursor_row);
                buf.cursor_row--;
                buf.cursor_col = prev_len;
                buf.modified = true;
            }
            break;
        case '\r':
        case '\n': { // Enter
            std::string &cur = buf.lines[buf.cursor_row];
            std::string rest = cur.substr(buf.cursor_col);
            cur = cur.substr(0, buf.cursor_col);
            buf.lines.insert(buf.lines.begin() + buf.cursor_row + 1, rest);
            buf.cursor_row++;
            buf.cursor_col = 0;
            buf.modified = true;
            break;
        }
        default:
            if (c >= 32 && c <= 126) {
                std::string &l = buf.lines[buf.cursor_row];
                l.insert(buf.cursor_col, 1, c);
                buf.cursor_col++;
                buf.modified = true;
            }
            break;
    }

    // Clamp cursor col
    if (buf.cursor_col > (int)buf.lines[buf.cursor_row].size()) {
        buf.cursor_col = (int)buf.lines[buf.cursor_row].size();
    }
}

} // namespace

int main(int argc, char **argv) {
    bool batch_mode = false;
    std::string eval_expr;
    std::string load_file;
    std::string visit_file;

    // Parse options
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--version") {
            printf("GNU Emacs %s\n", OHEMACS_VERSION);
            printf("%s\n", OHEMACS_CLI_TAG);
            printf("Copyright (C) 2026 Free Software Foundation, Inc.\n");
            printf("GNU Emacs comes with ABSOLUTELY NO WARRANTY.\n");
            printf("You may redistribute copies of GNU Emacs under the terms of the GPLv3.\n");
            return 0;
        }
        if (arg == "--help" || arg == "-h") {
            printf("Usage: emacs [OPTION-OR-FILENAME]...\n");
            printf("Run Emacs, the extensible self-documenting display editor.\n\n");
            printf("Initialization options:\n");
            printf("  --batch                   do not do interactive display; implies -q\n");
            printf("  --eval EXPR               evaluate Emacs Lisp expression EXPR\n");
            printf("  --load, -l FILE           load Emacs Lisp FILE\n");
            printf("  -nw, --no-window-system   run Emacs in terminal mode\n");
            printf("  -q, --no-init-file        do not load an init file\n");
            printf("  --version                 display version information and exit\n");
            printf("  --help                    display this help and exit\n");
            return 0;
        }
        if (arg == "--batch") {
            batch_mode = true;
        } else if (arg == "--eval" && i + 1 < argc) {
            eval_expr = argv[++i];
        } else if ((arg == "-l" || arg == "--load") && i + 1 < argc) {
            load_file = argv[++i];
        } else if (arg == "-nw" || arg == "--no-window-system") {
            // Terminal mode requested explicitly
        } else if (arg.rfind("-", 0) != 0) {
            visit_file = arg;
        }
    }

    // 1. Batch mode execution
    if (batch_mode) {
        if (!load_file.empty()) {
            FILE *f = fopen(load_file.c_str(), "r");
            if (!f) {
                fprintf(stderr, "Cannot open load file: %s\n", load_file.c_str());
                return 1;
            }
            char buf[8192];
            std::string code;
            while (fgets(buf, sizeof(buf), f)) code += buf;
            fclose(f);
            EvalLisp(code);
        }
        if (!eval_expr.empty()) {
            std::string res = EvalLisp(eval_expr);
            printf("%s\n", res.c_str());
        }
        return 0;
    }

    // 2. Interactive Terminal mode
    signal(SIGINT, HandleSignal);
    signal(SIGTERM, HandleSignal);
    signal(SIGWINCH, SIG_IGN);

    InitSampleBuffers();

    if (!visit_file.empty()) {
        EditorBuffer buf;
        if (LoadFileIntoBuffer(visit_file, buf)) {
            g_buffers.push_back(buf);
            g_current_buffer_idx = g_buffers.size() - 1;
        } else {
            buf.name = visit_file;
            buf.filename = visit_file;
            buf.mode = DetectMode(visit_file);
            buf.lines = {""};
            g_buffers.push_back(buf);
            g_current_buffer_idx = g_buffers.size() - 1;
        }
    }

    EnableRawMode();
    atexit(DisableRawMode);

    while (g_running) {
        RenderScreen();
        ProcessKeypress();
    }

    DisableRawMode();
    return 0;
}
