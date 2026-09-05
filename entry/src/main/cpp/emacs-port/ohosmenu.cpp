// ohosmenu.cpp — popup/dialog/menu-bar stubs for OHEmacs.
//
// Stage 2. Mirrors Emacs 30.1 `src/androidmenu.c:860` (popup menus,
// context menus, dialogs, and menu-bar updates driven through JNI
// callbacks into Java).
//
// TODO(full port): route these through NAPI to ArkTS
// promptAction.showDialog / CustomDialog / menu stacks, and deliver the
// user's choice back into Emacs as OHOS_CONTEXT_MENU events via
// ohos_write_event() (ohosgui.h), like androidmenu.c posts results to
// the event queue.

#include <hilog/log.h>

#include <stddef.h>
#include <stdint.h>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

extern "C" {

void ohos_popup_menu(void *frame, int x, int y, const char **items, int nitems) {
    // TODO(androidmenu.c:860): show an ArkTS menu at (x, y); on dismiss,
    // write the selected index back as OHOS_CONTEXT_MENU.
    if (nitems < 0) {
        nitems = 0;
    }
    const char *first = (items != nullptr && nitems > 0 && items[0] != nullptr) ? items[0] : "(none)";
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_popup_menu frame=0x%{public}llx x=%{public}d y=%{public}d "
                 "nitems=%{public}d first=%{public}s (stub)",
                 (unsigned long long)(uintptr_t)frame, x, y, nitems, first);
}

void ohos_show_dialog(void *frame, const char *title, const char *message) {
    // TODO(androidmenu.c dialog path): promptAction.showDialog with
    // buttons; deliver the response via ohos_write_event().
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_show_dialog frame=0x%{public}llx title=%{public}s message=%{public}s (stub)",
                 (unsigned long long)(uintptr_t)frame, title != nullptr ? title : "(null)",
                 message != nullptr ? message : "(null)");
}

void ohos_update_menubar(void *frame) {
    // TODO(androidmenu.c menu-bar path): push the current menu-bar tree to
    // ArkTS for native rendering.
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_update_menubar frame=0x%{public}llx (stub)",
                 (unsigned long long)(uintptr_t)frame);
}

} // extern "C"
