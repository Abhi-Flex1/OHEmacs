// ohosterm.cpp — OpenHarmony terminal/redisplay stub for OHEmacs.
//
// Stage 2. Structure mirrors Emacs 30.1 `src/androidterm.c` (6934 lines):
// create_terminal + redisplay_interface (update_begin/end,
// frame_up_to_date, glyph-string fns ohos_draw_glyph_string_* via
// OH_Drawing_Canvas), read_socket (android_read_socket analogue at
// androidterm.c:1853), cursor/divider handling.
//
// No Emacs src/ headers are required yet: `struct terminal` and
// `struct frame` stay opaque (see TODOs below). The full port replaces
// the void* parameters with the real types from src/termhooks.h,
// src/frame.h and src/dispextern.h.

#include "ohosterm.h"
#include "ohosgui.h"

#include <hilog/log.h>

#include <stddef.h>
#include <stdint.h>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

namespace {

ohos_redraw_fn g_redraw = nullptr;

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
    // TODO(full port, androidterm.c create_terminal): allocate
    // `struct terminal` (src/termhooks.h), install a
    // `struct redisplay_interface` with update_begin_hook =
    // ohos_update_begin, update_end_hook = ohos_update_end,
    // frame_up_to_date_hook = ohos_frame_up_to_date,
    // draw_glyph_string_hook = ohos_draw_glyph_string, read_socket_hook =
    // ohos_read_socket, plus cursor/divider hooks.
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_create_terminal: stub, redisplay_interface not installed yet");
    return nullptr;
}

int ohos_read_socket(struct terminal *terminal, int *hold_quit) {
    // Mirrors android_read_socket (androidterm.c:1853): drain the GUI event
    // queue and dispatch into Emacs input.
    // TODO(full port): feed each event to keyboard.c via
    // kbd_buffer_store_event_hold() instead of logging; map OHOS_KEY_*
    // keycodes through ohos_keycode_to_emacs() like android_to_emacs_key().
    (void)terminal;
    int count = 0;
    struct ohos_event ev;
    while (ohos_next_event(&ev)) {
        count++;
        switch (ev.type) {
        case OHOS_KEY_PRESS:
        case OHOS_KEY_RELEASE:
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                         "read_socket %{public}s keycode=%{public}d action=%{public}d",
                         EventName(ev.type), ev.u.key.keycode, ev.u.key.action);
            break;
        case OHOS_TOUCH_DOWN:
        case OHOS_TOUCH_UP:
        case OHOS_TOUCH_MOVE:
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                         "read_socket %{public}s x=%{public}d y=%{public}d",
                         EventName(ev.type), ev.u.touch.x, ev.u.touch.y);
            break;
        case OHOS_CONFIGURE_NOTIFY:
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                         "read_socket CONFIGURE_NOTIFY %{public}llu x %{public}llu",
                         (unsigned long long)ev.u.configure.width,
                         (unsigned long long)ev.u.configure.height);
            break;
        default:
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "read_socket %{public}s",
                         EventName(ev.type));
            break;
        }
    }
    if (hold_quit != nullptr) {
        *hold_quit = 0;
    }
    if (count > 0 && g_redraw != nullptr) {
        // Wired to the DrawFrame path (bridge registers its EGL repaint).
        g_redraw();
    }
    return count;
}

void ohos_update_begin(struct frame *f) {
    // TODO(full port): block input, set up OH_Drawing_Canvas clip for
    // f->output_data (struct ohos_output in ohosgui.h), like
    // android_update_begin.
    (void)f;
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "ohos_update_begin");
}

void ohos_update_end(struct frame *f) {
    // TODO(full port): flush OH_Drawing_Canvas, eglSwapBuffers, unblock
    // input, like android_update_end.
    (void)f;
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "ohos_update_end");
    if (g_redraw != nullptr) {
        g_redraw();
    }
}

void ohos_frame_up_to_date(struct frame *f) {
    // TODO(full port): mark desired/user state current (f->updated_p),
    // like android_frame_up_to_date.
    (void)f;
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "ohos_frame_up_to_date");
}

void ohos_clear_frame(void *frame) {
    // TODO(full port): fill background over visible_bell/clip rects, like
    // android_clear_frame.
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_clear_frame frame=0x%{public}llx", (unsigned long long)(uintptr_t)frame);
}

void ohos_draw_glyph_string(void *glyph_string) {
    // TODO(full port): implement ohos_draw_glyph_string_foreground /
    // _background / _box over OH_Drawing_Canvas via ohosfont font backend,
    // taking `struct glyph_string *` (src/dispextern.h) like
    // android_draw_glyph_string_*.
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_draw_glyph_string gs=0x%{public}llx (stub)",
                 (unsigned long long)(uintptr_t)glyph_string);
}

void ohos_draw_cursor(void *frame, int x, int y, int width, int height) {
    // TODO(full port): hollow/box/bar cursor via fill_rectangle, like
    // android_draw_window_cursor.
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_draw_cursor frame=0x%{public}llx x=%{public}d y=%{public}d w=%{public}d "
                 "h=%{public}d",
                 (unsigned long long)(uintptr_t)frame, x, y, width, height);
}
