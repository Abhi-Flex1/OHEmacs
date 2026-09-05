// ohosfns.cpp — frame parameter / color stubs for OHEmacs.
//
// Stage 2. Mirrors the Lisp-facing side of Emacs 30.1 `src/androidfns.c`
// (around line 3788: the `x-*` frame primitives such as x-create-frame,
// x-set-frame-parameters, x-get-resource, display-color-p, color support).
//
// No Emacs src/ headers are required yet: frames are opaque void* and
// colors are 0xAARRGGBB pixels. The full port turns these into Fx_*
// defuns operating on `struct frame *` (src/frame.h) and f->param_alist.

#include <hilog/log.h>

#include <stddef.h>
#include <stdint.h>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

extern "C" {

void ohos_set_frame_parm(void *frame, const char *parm, const char *value) {
    // TODO(full port, androidfns.c:3788): store into f->param_alist via
    // gui_set_frame_parameters(); handle foreground-color /
    // background-color / font / fullscreen / z-group specially and queue
    // a redisplay (redisplay_preserve_echo_area).
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_set_frame_parm frame=0x%{public}llx parm=%{public}s value=%{public}s",
                 (unsigned long long)(uintptr_t)frame, parm != nullptr ? parm : "(null)",
                 value != nullptr ? value : "(null)");
}

int ohos_get_color(const char *color_name, unsigned long *color_out) {
    // TODO(full port, androidfns.c color path): resolve #RRGGBB and named
    // colors (Emacs rgb.txt) into 0xAARRGGBB pixels; return 0 on success.
    if (color_out != nullptr) {
        *color_out = 0;
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_get_color name=%{public}s -> unsupported (stub)",
                 color_name != nullptr ? color_name : "(null)");
    return -1;
}

} // extern "C"
