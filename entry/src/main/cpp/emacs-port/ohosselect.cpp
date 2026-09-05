// ohosselect.cpp — clipboard/selection stubs for OHEmacs.
//
// Stage 2. Mirrors Emacs 30.1 `src/androidselect.c:1220` (CLIPBOARD and
// PRIMARY ownership, get/setClipboardText through JNI).
//
// TODO(full port): back this with the NDK pasteboard C API (OH_Pasteboard,
// system pasteboard with text/plain MIME) so kills and yanks interoperate
// with other apps. The in-process buffer below is scaffold-only so
// put/get round-trips work before the pasteboard is wired.

#include <hilog/log.h>

#include <cstring>
#include <mutex>
#include <stdint.h>
#include <string>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

namespace {

std::mutex g_sel_mutex;
std::string g_clipboard;

} // namespace

extern "C" {

int ohos_selection_own(void *frame, const char *selection_name) {
    // TODO(androidselect.c:1220): claim the OH_Pasteboard owner for
    // CLIPBOARD/PRIMARY.
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_selection_own frame=0x%{public}llx name=%{public}s (stub)",
                 (unsigned long long)(uintptr_t)frame,
                 selection_name != nullptr ? selection_name : "(null)");
    return 0;
}

int ohos_selection_disown(void *frame, const char *selection_name) {
    // TODO: release the OH_Pasteboard ownership.
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_selection_disown frame=0x%{public}llx name=%{public}s (stub)",
                 (unsigned long long)(uintptr_t)frame,
                 selection_name != nullptr ? selection_name : "(null)");
    return 0;
}

int ohos_selection_put(const char *selection_name, const char *data, unsigned long len) {
    // TODO: OH_Pasteboard_SetPasteData with text/plain.
    std::lock_guard<std::mutex> lock(g_sel_mutex);
    if (data == nullptr || len == 0) {
        g_clipboard.clear();
    } else {
        g_clipboard.assign(data, (size_t)len);
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_selection_put name=%{public}s bytes=%{public}lu (stub buffer)",
                 selection_name != nullptr ? selection_name : "(null)", len);
    return 0;
}

unsigned long ohos_selection_get(const char *selection_name, char *buf, unsigned long bufsize) {
    // TODO: OH_Pasteboard_GetPasteData; query mode (buf null/empty) returns
    // the total length, like XGetWindowProperty remainder handling.
    std::lock_guard<std::mutex> lock(g_sel_mutex);
    unsigned long total = (unsigned long)g_clipboard.size();
    if (buf != nullptr && bufsize > 0) {
        unsigned long n = total < bufsize ? total : bufsize;
        std::memcpy(buf, g_clipboard.data(), (size_t)n);
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                     "ohos_selection_get name=%{public}s copied=%{public}lu of %{public}lu",
                     selection_name != nullptr ? selection_name : "(null)", n, total);
        return n;
    }
    return total;
}

} // extern "C"
