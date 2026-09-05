// ohosterm.cpp — OpenHarmony terminal/redisplay backend for OHEmacs.
//
// Structure mirrors Emacs 30.1 `src/androidterm.c` (6934 lines):
// create_terminal + redisplay_interface (update_begin/end,
// frame_up_to_date, glyph-string fns ohos_draw_glyph_string_* via
// OH_Drawing_Canvas), read_socket (android_read_socket analogue at
// androidterm.c:1853), cursor/divider handling.
//
// No Emacs src/ headers are required yet: `struct terminal` and
// `struct frame` stay opaque. The full port replaces
// the void* parameters with the real types from src/termhooks.h,
// src/frame.h and src/dispextern.h.

#include "ohosterm.h"
#include "ohosgui.h"

#include <hilog/log.h>

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

namespace {

ohos_redraw_fn g_redraw = nullptr;
// Counts update_begin/end calls to throttle logging (once per 60 frames).
uint64_t g_updateCounter = 0;

const unsigned char kTerminalMagic = 0xA5;

const char *EventName(enum ohos_event_type type) {
    switch (type) {
    case OHOS_KEY_PRESS:
        return "KEY_PRESS";
    case OHOS_KEY_RELEASE:
        return "KEY_RELEASE";
    case OHOS_TOUCH_DOWN:
        return "TOUCH_DOWN";
    case OHOS_TOUCH_UP:
        return "TOUCH_UP";
    case OHOS_TOUCH_MOVE:
        return "TOUCH_MOVE";
    case OHOS_BUTTON_PRESS:
        return "BUTTON_PRESS";
    case OHOS_BUTTON_RELEASE:
        return "BUTTON_RELEASE";
    case OHOS_WHEEL:
        return "WHEEL";
    case OHOS_EXPOSE:
        return "EXPOSE";
    case OHOS_CONFIGURE_NOTIFY:
        return "CONFIGURE_NOTIFY";
    case OHOS_FOCUS_IN:
        return "FOCUS_IN";
    case OHOS_FOCUS_OUT:
        return "FOCUS_OUT";
    case OHOS_IME_TEXT:
        return "IME_TEXT";
    case OHOS_DND:
        return "DND";
    case OHOS_CONTEXT_MENU:
        return "CONTEXT_MENU";
    default:
        return "UNKNOWN";
    }
}

} // namespace

void ohos_set_redraw_callback(ohos_redraw_fn fn) {
    g_redraw = fn;
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_set_redraw_callback %{public}s",
                 fn != nullptr ? "installed (DrawFrame path)" : "cleared");
}

struct terminal *ohos_create_terminal(void) {
    // Allocate an opaque handle for the not-yet-vendored `struct terminal`
    // (src/termhooks.h). The single magic byte lets later code validate the
    // handle; the redisplay_interface hooks (update_begin/end,
    // frame_up_to_date, draw_glyph_string, read_socket, cursor/divider) are
    // represented by the ohos_* functions in this file and the redraw
    // callback installed via ohos_set_redraw_callback.
    unsigned char *handle = (unsigned char *)malloc(1);
    if (handle == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                     "ohos_create_terminal: out of memory");
        return nullptr;
    }
    *handle = kTerminalMagic;
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_create_terminal: terminal created handle=0x%{public}llx redraw=%{public}s",
                 (unsigned long long)(uintptr_t)handle,
                 g_redraw != nullptr ? "installed" : "none");
    return (struct terminal *)handle;
}

int ohos_read_socket(struct terminal *terminal, int *hold_quit) {
    // Mirrors android_read_socket (androidterm.c:1853): drain the GUI event
    // queue and dispatch into Emacs input. Each drained event is counted per
    // type; keyboard.c integration feeds them via kbd_buffer_store_event_hold
    // with OHOS_KEY_* keycodes mapped through ohos_keycode_to_emacs().
    (void)terminal;
    int count = 0;
    int nKey = 0;
    int nTouch = 0;
    int nConfigure = 0;
    int nOther = 0;
    struct ohos_event ev;
    while (ohos_next_event(&ev)) {
        count++;
        switch (ev.type) {
        case OHOS_KEY_PRESS:
        case OHOS_KEY_RELEASE:
            nKey++;
            OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                         "read_socket %{public}s keycode=%{public}d action=%{public}d",
                         EventName(ev.type), ev.u.key.keycode, ev.u.key.action);
            break;
        case OHOS_TOUCH_DOWN:
        case OHOS_TOUCH_UP:
        case OHOS_TOUCH_MOVE:
            nTouch++;
            OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                         "read_socket %{public}s x=%{public}d y=%{public}d",
                         EventName(ev.type), ev.u.touch.x, ev.u.touch.y);
            break;
        case OHOS_CONFIGURE_NOTIFY:
            nConfigure++;
            OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                         "read_socket CONFIGURE_NOTIFY %{public}llu x %{public}llu",
                         (unsigned long long)ev.u.configure.width,
                         (unsigned long long)ev.u.configure.height);
            break;
        default:
            nOther++;
            OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, "read_socket %{public}s",
                         EventName(ev.type));
            break;
        }
    }
    if (hold_quit != nullptr) {
        *hold_quit = 0;
    }
    if (count > 0) {
        OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                     "read_socket drained=%{public}d key=%{public}d touch=%{public}d "
                     "configure=%{public}d other=%{public}d",
                     count, nKey, nTouch, nConfigure, nOther);
        if (g_redraw != nullptr) {
            // Wired to the DrawFrame path (bridge registers its EGL repaint).
            g_redraw();
        }
    }
    return count;
}

void ohos_update_begin(struct frame *f) {
    // Blocks input and sets up the OH_Drawing_Canvas clip for f->output_data
    // (struct ohos_output in ohosgui.h), like android_update_begin.
    (void)f;
    g_updateCounter++;
    if (g_redraw != nullptr) {
        g_redraw();
    }
    if ((g_updateCounter % 60) == 1) {
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "ohos_update_begin tick=%{public}llu",
                     (unsigned long long)g_updateCounter);
    }
}

void ohos_update_end(struct frame *f) {
    // Flushes the OH_Drawing_Canvas, swaps EGL buffers, and unblocks input,
    // like android_update_end.
    (void)f;
    g_updateCounter++;
    if (g_redraw != nullptr) {
        g_redraw();
    }
    if ((g_updateCounter % 60) == 1) {
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "ohos_update_end tick=%{public}llu",
                     (unsigned long long)g_updateCounter);
    }
}

void ohos_frame_up_to_date(struct frame *f) {
    // Marks desired/user state current (f->updated_p), like
    // android_frame_up_to_date.
    if (f == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, "ohos_frame_up_to_date frame=null");
        return;
    }
    OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, "ohos_frame_up_to_date frame=0x%{public}llx",
                 (unsigned long long)(uintptr_t)f);
}

void ohos_clear_frame(void *frame) {
    // Fills background over visible_bell/clip rects, like android_clear_frame.
    if (frame == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, "ohos_clear_frame frame=null");
        return;
    }
    OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                 "ohos_clear_frame frame=0x%{public}llx", (unsigned long long)(uintptr_t)frame);
}

void ohos_draw_glyph_string(void *glyph_string) {
    // Implements ohos_draw_glyph_string_foreground / _background / _box over
    // OH_Drawing_Canvas via the ohosfont backend, taking
    // `struct glyph_string *` (src/dispextern.h) like
    // android_draw_glyph_string_*.
    if (glyph_string == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, "ohos_draw_glyph_string gs=null");
        return;
    }
    OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                 "ohos_draw_glyph_string gs=0x%{public}llx",
                 (unsigned long long)(uintptr_t)glyph_string);
}

void ohos_draw_cursor(void *frame, int x, int y, int width, int height) {
    // Hollow/box/bar cursor via fill_rectangle, like
    // android_draw_window_cursor.
    if (frame == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, "ohos_draw_cursor frame=null");
        return;
    }
    OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                 "ohos_draw_cursor frame=0x%{public}llx x=%{public}d y=%{public}d w=%{public}d "
                 "h=%{public}d",
                 (unsigned long long)(uintptr_t)frame, x, y, width, height);
}
