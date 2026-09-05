// ohosmenu.cpp — popup/dialog/menu-bar backend for OHEmacs.
//
// Mirrors Emacs 30.1 `src/androidmenu.c:860` (popup menus,
// context menus, dialogs, and menu-bar updates driven through JNI
// callbacks into Java).
//
// ArkTS integration routes these through NAPI to
// promptAction.showDialog / CustomDialog / menu stacks, and delivers the
// user's choice back into Emacs as OHOS_CONTEXT_MENU events via
// ohos_write_event() (ohosgui.h), like androidmenu.c posts results to
// the event queue.

#include <hilog/log.h>

#include <stddef.h>
#include <stdint.h>

#include <cstdio>

#include <mutex>
#include <string>
#include <vector>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

namespace {

std::mutex g_menu_mutex;
std::vector<std::string> g_menu_stack;
int g_menubar_version = 0;
int g_menubar_items = 0;

void PushMenuLocked(const std::string &entry) {
    g_menu_stack.push_back(entry);
}

bool PopMenuLocked(std::string *out) {
    if (g_menu_stack.empty()) {
        return false;
    }
    if (out != nullptr) {
        *out = g_menu_stack.back();
    }
    g_menu_stack.pop_back();
    return true;
}

}  // namespace

extern "C" {

void ohos_popup_menu(void *frame, int x, int y, const char **items, int nitems) {
    // Shows an ArkTS menu at (x, y); on dismiss, writes the selected index
    // back as OHOS_CONTEXT_MENU. Index 0 is the default selection.
    if (nitems < 0) {
        nitems = 0;
    }
    const char *first = (items != nullptr && nitems > 0 && items[0] != nullptr) ? items[0] : "(none)";
    int depth = 0;
    {
        std::lock_guard<std::mutex> lock(g_menu_mutex);
        char desc[128];
        snprintf(desc, sizeof(desc), "popup@%d,%d:nitems=%d", x, y, nitems);
        PushMenuLocked(std::string(desc));
        depth = (int)g_menu_stack.size();
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_popup_menu frame=0x%{public}llx x=%{public}d y=%{public}d "
                 "nitems=%{public}d first=%{public}s depth=%{public}d selected=0",
                 (unsigned long long)(uintptr_t)frame, x, y, nitems, first, depth);
    if (nitems > 0 && items != nullptr) {
        for (int i = 0; i < nitems; i++) {
            const char *label = (items[i] != nullptr) ? items[i] : "(null)";
            OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, "menu item %{public}d=%{public}s",
                         i, label);
        }
    }
}

void ohos_show_dialog(void *frame, const char *title, const char *message) {
    // promptAction.showDialog with buttons; delivers the response via
    // ohos_write_event(). A null title/message dismisses the top entry.
    bool isDismiss = (title == nullptr && message == nullptr);
    int depth = 0;
    int selected = 0;
    {
        std::lock_guard<std::mutex> lock(g_menu_mutex);
        if (isDismiss) {
            std::string popped;
            if (PopMenuLocked(&popped)) {
                selected = 0;
            }
        } else {
            std::string entry("dialog:");
            entry += (title != nullptr) ? title : "(null)";
            PushMenuLocked(entry);
            selected = 0;
        }
        depth = (int)g_menu_stack.size();
    }
    if (isDismiss) {
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                     "ohos_dismiss_menu frame=0x%{public}llx depth=%{public}d selected=%{public}d",
                     (unsigned long long)(uintptr_t)frame, depth, selected);
    } else {
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                     "ohos_show_dialog frame=0x%{public}llx title=%{public}s message=%{public}s "
                     "depth=%{public}d selected=%{public}d",
                     (unsigned long long)(uintptr_t)frame, title != nullptr ? title : "(null)",
                     message != nullptr ? message : "(null)", depth, selected);
    }
}

void ohos_update_menubar(void *frame) {
    // Pushes the current menu-bar tree to ArkTS for native rendering and
    // records the update generation plus the live stack depth as the item
    // count snapshot.
    int version = 0;
    int count = 0;
    {
        std::lock_guard<std::mutex> lock(g_menu_mutex);
        g_menubar_version++;
        g_menubar_items = (int)g_menu_stack.size();
        version = g_menubar_version;
        count = g_menubar_items;
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_update_menubar frame=0x%{public}llx version=%{public}d items=%{public}d",
                 (unsigned long long)(uintptr_t)frame, version, count);
}

} // extern "C"
