// ohosselect.cpp — clipboard/selection backend for OHEmacs.
//
// Mirrors Emacs 30.1 `src/androidselect.c:1220` (CLIPBOARD and
// PRIMARY ownership, get/setClipboardText through JNI).
//
// Primary selection lives in-process here (owner + timestamp + bytes with
// round-trip get). Multi-app interop via the NDK pasteboard C API
// (OH_Pasteboard, system pasteboard with text/plain MIME) is the future
// step for kills and yanks shared with other apps.

#include <hilog/log.h>

#include <stdint.h>
#include <string.h>
#include <time.h>

#include <cstring>
#include <mutex>
#include <string>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

namespace {

std::mutex g_sel_mutex;
std::string g_clipboard;
std::string g_owner;
uint64_t g_timestamp = 0;

uint64_t NowSeconds() {
    struct timespec ts;
    memset(&ts, 0, sizeof ts);
    if (clock_gettime(CLOCK_REALTIME, &ts) == 0) {
        return (uint64_t)ts.tv_sec;
    }
    return 0;
}

} // namespace

extern "C" {

int ohos_selection_own(void *frame, const char *selection_name) {
    // Claims ownership for CLIPBOARD/PRIMARY.
    const char *name = (selection_name != nullptr) ? selection_name : "PRIMARY";
    {
        std::lock_guard<std::mutex> lock(g_sel_mutex);
        g_owner.assign(name);
        g_timestamp = NowSeconds();
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_selection_own frame=0x%{public}llx owner=%{public}s",
                 (unsigned long long)(uintptr_t)frame, name);
    return 0;
}

int ohos_selection_disown(void *frame, const char *selection_name) {
    // Releases ownership; clears the owner only if it matches.
    const char *name = (selection_name != nullptr) ? selection_name : "PRIMARY";
    {
        std::lock_guard<std::mutex> lock(g_sel_mutex);
        if (g_owner == name) {
            g_owner.clear();
        }
        g_timestamp = NowSeconds();
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_selection_disown frame=0x%{public}llx name=%{public}s",
                 (unsigned long long)(uintptr_t)frame, name);
    return 0;
}

int ohos_selection_put(const char *selection_name, const char *data, unsigned long len) {
    const char *name = (selection_name != nullptr) ? selection_name : "PRIMARY";
    std::string owner;
    {
        std::lock_guard<std::mutex> lock(g_sel_mutex);
        if (data == nullptr || len == 0) {
            g_clipboard.clear();
        } else {
            g_clipboard.assign(data, (size_t)len);
        }
        if (g_owner.empty()) {
            g_owner.assign(name);
        }
        g_timestamp = NowSeconds();
        owner = g_owner;
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "selection %{public}luB owner=%{public}s",
                 len, owner.c_str());
    return 0;
}

unsigned long ohos_selection_get(const char *selection_name, char *buf, unsigned long bufsize) {
    // Query mode (buf null/empty) returns the total length, like
    // XGetWindowProperty remainder handling.
    const char *name = (selection_name != nullptr) ? selection_name : "PRIMARY";
    std::lock_guard<std::mutex> lock(g_sel_mutex);
    unsigned long total = (unsigned long)g_clipboard.size();
    if (buf != nullptr && bufsize > 0) {
        unsigned long n = total < bufsize ? total : bufsize;
        if (n > 0) {
            std::memcpy(buf, g_clipboard.c_str(), (size_t)n);
        }
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                     "ohos_selection_get name=%{public}s copied=%{public}lu of %{public}lu "
                     "owner=%{public}s",
                     name, n, total, g_owner.empty() ? "(none)" : g_owner.c_str());
        return n;
    }
    return total;
}

} // extern "C"
