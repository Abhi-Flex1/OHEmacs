// ohosfns.cpp — frame parameter / color backend for OHEmacs.
//
// Mirrors the Lisp-facing side of Emacs 30.1 `src/androidfns.c`
// (around line 3788: the `x-*` frame primitives such as x-create-frame,
// x-set-frame-parameters, x-get-resource, display-color-p, color support).
//
// No Emacs src/ headers are required yet: frames are opaque void* and
// colors are 0xRRGGBB pixels. The full port turns these into Fx_*
// defuns operating on `struct frame *` (src/frame.h) and f->param_alist.

#include <hilog/log.h>

#include <ctype.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include <mutex>
#include <string>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

namespace {

std::mutex g_parm_mutex;
std::string g_lastParm;
std::string g_lastValue;

struct NamedColor {
    const char *name;
    unsigned long rgb;  // 0xRRGGBB
};

const NamedColor kNamedColors[] = {
    {"black", 0x000000},
    {"white", 0xFFFFFF},
    {"red", 0xFF0000},
    {"green", 0x00FF00},
    {"blue", 0x0000FF},
    {"yellow", 0xFFFF00},
    {"magenta", 0xFF00FF},
    {"cyan", 0x00FFFF},
};

bool EqualsIgnoreCase(const char *a, const char *b) {
    if (a == nullptr || b == nullptr) {
        return false;
    }
    while (*a != '\0' && *b != '\0') {
        if (tolower((unsigned char)*a) != tolower((unsigned char)*b)) {
            return false;
        }
        a++;
        b++;
    }
    return *a == '\0' && *b == '\0';
}

int HexNibble(char c, unsigned *out) {
    if (c >= '0' && c <= '9') {
        *out = (unsigned)(c - '0');
        return 0;
    }
    if (c >= 'a' && c <= 'f') {
        *out = (unsigned)(c - 'a' + 10);
        return 0;
    }
    if (c >= 'A' && c <= 'F') {
        *out = (unsigned)(c - 'A' + 10);
        return 0;
    }
    return -1;
}

// Parses #RRGGBB into 0xRRGGBB. Returns 0 on success.
int ParseHexColor(const char *name, unsigned long *rgb_out) {
    if (name == nullptr || rgb_out == nullptr) {
        return -1;
    }
    if (name[0] != '#' || strlen(name) != 7) {
        return -1;
    }
    unsigned long rgb = 0;
    for (int i = 1; i < 7; i++) {
        unsigned nib = 0;
        if (HexNibble(name[i], &nib) != 0) {
            return -1;
        }
        rgb = (rgb << 4) | nib;
    }
    *rgb_out = rgb;
    return 0;
}

}  // namespace

extern "C" {

void ohos_set_frame_parm(void *frame, const char *parm, const char *value) {
    // Stores into f->param_alist via gui_set_frame_parameters(); handles
    // foreground-color / background-color / font / fullscreen / z-group
    // specially and queues a redisplay (redisplay_preserve_echo_area).
    // In-process state: keeps the last parm/value pair.
    const char *p = (parm != nullptr) ? parm : "(null)";
    const char *v = (value != nullptr) ? value : "(null)";
    {
        std::lock_guard<std::mutex> lock(g_parm_mutex);
        g_lastParm.assign(p);
        g_lastValue.assign(v);
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_set_frame_parm frame=0x%{public}llx parm=%{public}s value=%{public}s",
                 (unsigned long long)(uintptr_t)frame, p, v);
}

int ohos_get_color(const char *color_name, unsigned long *color_out) {
    // Resolves #RRGGBB and named colors (Emacs rgb.txt subset) into 0xRRGGBB
    // pixels; returns 0 on success.
    if (color_out != nullptr) {
        *color_out = 0;
    }
    if (color_name == nullptr || color_out == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                     "ohos_get_color name=%{public}s -> invalid argument",
                     color_name != nullptr ? color_name : "(null)");
        return -1;
    }
    unsigned long rgb = 0;
    bool found = false;
    if (ParseHexColor(color_name, &rgb) == 0) {
        found = true;
    } else {
        size_t n = sizeof(kNamedColors) / sizeof(kNamedColors[0]);
        for (size_t i = 0; i < n; i++) {
            if (EqualsIgnoreCase(color_name, kNamedColors[i].name)) {
                rgb = kNamedColors[i].rgb;
                found = true;
                break;
            }
        }
    }
    if (!found) {
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                     "ohos_get_color name=%{public}s -> unknown", color_name);
        return -1;
    }
    *color_out = rgb;
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_get_color name=%{public}s -> 0x%{public}06lX", color_name, rgb);
    return 0;
}

} // extern "C"
