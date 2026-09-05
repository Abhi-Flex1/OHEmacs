// OHEmacs native bridge: XComponent + EGL rendering + Emacs event-queue scaffold.
//
// This file is the first stage of the full OpenHarmony GUI port of GNU Emacs 30.1.
// It mirrors the structure of Emacs' Android port (src/android.c / androidterm.c)
// but replaces JNI/Bitmap with NAPI/XComponent + OH_NativeWindow + EGL.
//
// Stage 1 (this file): working HAP surface, EGL frame rendering, input event
// queue, hilog instrumentation. Proves the ArkTS <-> native path on emulator.
// Stage 2 (next): full ohosterm.c backend vendoring Emacs src/ with
//   redisplay_interface, glyph drawing via OH_Drawing, font via sfntfont,
//   IME via inputmethod C-API. See docs/PORTING.md.

#include "ohemacs_bridge.h"
#include "emacs-port/ohosgui.h"
#include "emacs-port/ohosterm.h"

#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <ace/xcomponent/native_interface_xcomponent.h>
#include <hilog/log.h>
#include <native_window/external_window.h>

#include <cstring>
#include <mutex>
#include <queue>
#include <string>

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------
#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

// ---------------------------------------------------------------------------
// Global state (single Emacs frame for scaffold; multi-frame in full port)
// ---------------------------------------------------------------------------
namespace {

struct OhemacsEvent {
    enum class Type { KEY, EXPOSE, TOUCH, CONFIGURE } type;
    int32_t keyCode = 0;
    int32_t action = 0;
    int32_t x = 0;
    int32_t y = 0;
    uint64_t width = 0;
    uint64_t height = 0;
};

std::string g_filesDir;
std::string g_cacheDir;
std::mutex g_mutex;
std::queue<OhemacsEvent> g_eventQueue;
uint64_t g_eventCounter = 0;
uint64_t g_frameCounter = 0;

OHNativeWindow *g_window = nullptr;
OH_NativeXComponent *g_component = nullptr;
uint64_t g_width = 0;
uint64_t g_height = 0;

EGLDisplay g_eglDisplay = EGL_NO_DISPLAY;
EGLSurface g_eglSurface = EGL_NO_SURFACE;
EGLContext g_eglContext = EGL_NO_CONTEXT;
EGLConfig g_eglConfig = nullptr;
float g_clearColor[4] = {0.16f, 0.16f, 0.28f, 1.0f}; // Emacs-like dark

void LogInfo(const char *fmt, const std::string &extra = "") {
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "%{public}s %{public}s", fmt,
                 extra.c_str());
}

bool InitEgl(OHNativeWindow *window) {
    if (g_eglDisplay != EGL_NO_DISPLAY) {
        return true;
    }
    g_eglDisplay = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_eglDisplay == EGL_NO_DISPLAY) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglGetDisplay failed");
        return false;
    }
    EGLint major = 0, minor = 0;
    if (eglInitialize(g_eglDisplay, &major, &minor) != EGL_TRUE) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglInitialize failed");
        g_eglDisplay = EGL_NO_DISPLAY;
        return false;
    }
    const EGLint attribs[] = {EGL_SURFACE_TYPE,
                              EGL_WINDOW_BIT,
                              EGL_RENDERABLE_TYPE,
                              EGL_OPENGL_ES2_BIT,
                              EGL_RED_SIZE,
                              8,
                              EGL_GREEN_SIZE,
                              8,
                              EGL_BLUE_SIZE,
                              8,
                              EGL_ALPHA_SIZE,
                              8,
                              EGL_DEPTH_SIZE,
                              16,
                              EGL_NONE};
    EGLint numConfigs = 0;
    if (eglChooseConfig(g_eglDisplay, attribs, &g_eglConfig, 1, &numConfigs) != EGL_TRUE ||
        numConfigs < 1) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglChooseConfig failed");
        return false;
    }
    const EGLint ctxAttribs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
    g_eglContext = eglCreateContext(g_eglDisplay, g_eglConfig, EGL_NO_CONTEXT, ctxAttribs);
    if (g_eglContext == EGL_NO_CONTEXT) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglCreateContext failed");
        return false;
    }
    g_eglSurface = eglCreateWindowSurface(g_eglDisplay, g_eglConfig,
                                          (EGLNativeWindowType)window, nullptr);
    if (g_eglSurface == EGL_NO_SURFACE) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglCreateWindowSurface failed %{public}x",
                     eglGetError());
        return false;
    }
    if (eglMakeCurrent(g_eglDisplay, g_eglSurface, g_eglSurface, g_eglContext) != EGL_TRUE) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglMakeCurrent failed");
        return false;
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "EGL init ok %{public}d.%{public}d", (int)major, (int)minor);
    return true;
}

void DestroyEgl() {
    if (g_eglDisplay == EGL_NO_DISPLAY) {
        return;
    }
    eglMakeCurrent(g_eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (g_eglSurface != EGL_NO_SURFACE) {
        eglDestroySurface(g_eglDisplay, g_eglSurface);
        g_eglSurface = EGL_NO_SURFACE;
    }
    if (g_eglContext != EGL_NO_CONTEXT) {
        eglDestroyContext(g_eglDisplay, g_eglContext);
        g_eglContext = EGL_NO_CONTEXT;
    }
    eglTerminate(g_eglDisplay);
    g_eglDisplay = EGL_NO_DISPLAY;
}

// Draw one Emacs-frame placeholder: dark background + lighter "mode-line" bar
// + header line. Full port replaces this with OH_Drawing glyph strings from
// ohosterm.c (cloned from androidterm.c glyph path).
void DrawFrame() {
    if (g_eglDisplay == EGL_NO_DISPLAY || g_eglSurface == EGL_NO_SURFACE) {
        return;
    }
    eglMakeCurrent(g_eglDisplay, g_eglSurface, g_eglSurface, g_eglContext);
    EGLint w = (EGLint)g_width, h = (EGLint)g_height;
    if (w > 0 && h > 0) {
        glViewport(0, 0, w, h);
    }
    glClearColor(g_clearColor[0], g_clearColor[1], g_clearColor[2], g_clearColor[3]);
    glClear(GL_COLOR_BUFFER_BIT);

    // Mode-line strip at bottom (10% height): classic Emacs grey.
    // Done with scissor to avoid shaders for scaffold.
    if (w > 0 && h > 0) {
        GLint lineH = h / 12;
        glEnable(GL_SCISSOR_TEST);
        glScissor(0, 0, w, lineH);
        glClearColor(0.75f, 0.75f, 0.75f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        // Header line at top (6%): slightly lighter than background.
        glScissor(0, h - h / 16, w, h / 16);
        glClearColor(0.25f, 0.25f, 0.38f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glDisable(GL_SCISSOR_TEST);
    }

    eglSwapBuffers(g_eglDisplay, g_eglSurface);
    g_frameCounter++;
}

// ---------------------------------------------------------------------------
// Stage 1 -> Stage 2 bridge: dual-write scaffold events into the ohos_event
// queue (emacs-port/ohos.cpp) while keeping the legacy internal queue.
// ohos_write_event() is thread-safe; callers hold g_mutex for the legacy
// queue, which is safe (no reverse lock order: redraw path takes no locks).
// C++14-safe: only std::call_once + memset + plain structs.
// ---------------------------------------------------------------------------
std::once_flag g_stage2Once;

void RedrawFromOhos() { DrawFrame(); }

void EnsureStage2Bridge() {
    std::call_once(g_stage2Once, [] {
        ohos_init_events();
        ohos_set_redraw_callback(RedrawFromOhos);
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                     "stage2 bridge ready: ohos queue + redraw callback installed");
    });
}

void ForwardKeyToOhos(int32_t keyCode, int32_t action) {
    struct ohos_event ev;
    memset(&ev, 0, sizeof ev);
    ev.type = (action == 0 ? OHOS_KEY_RELEASE : OHOS_KEY_PRESS);
    ev.u.key.keycode = (int)keyCode;
    ev.u.key.action = (int)action;
    ev.u.key.timestamp = 0;
    ohos_write_event(ev);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "bridge->ohos KEY code=%{public}d action=%{public}d pending=%{public}d", (int)keyCode,
                 (int)action, ohos_pending());
}

void ForwardExposeToOhos() {
    struct ohos_event ev;
    memset(&ev, 0, sizeof ev);
    ev.type = OHOS_EXPOSE;
    ohos_write_event(ev);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "bridge->ohos EXPOSE pending=%{public}d",
                 ohos_pending());
}

void ForwardTouchToOhos(int32_t x, int32_t y) {
    struct ohos_event ev;
    memset(&ev, 0, sizeof ev);
    ev.type = OHOS_TOUCH_DOWN;
    ev.u.touch.x = (int)x;
    ev.u.touch.y = (int)y;
    ev.u.touch.timestamp = 0;
    ohos_write_event(ev);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "bridge->ohos TOUCH %{public}d,%{public}d pending=%{public}d", (int)x, (int)y,
                 ohos_pending());
}

void ForwardConfigureToOhos(uint64_t w, uint64_t h) {
    struct ohos_event ev;
    memset(&ev, 0, sizeof ev);
    ev.type = OHOS_CONFIGURE_NOTIFY;
    ev.u.configure.width = w;
    ev.u.configure.height = h;
    ohos_write_event(ev);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "bridge->ohos CONFIGURE %{public}llu x %{public}llu pending=%{public}d",
                 (unsigned long long)w, (unsigned long long)h, ohos_pending());
}

void PushEventLocked(const OhemacsEvent &ev) {
    // Cap like android.c (1024) to avoid unbounded growth.
    if (g_eventQueue.size() >= 1024) {
        g_eventQueue.pop();
    }
    g_eventQueue.push(ev);
    g_eventCounter++;
}

// Must be called with g_mutex held.
void DrainEventsForLog() {
    while (!g_eventQueue.empty()) {
        OhemacsEvent ev = g_eventQueue.front();
        g_eventQueue.pop();
        switch (ev.type) {
        case OhemacsEvent::Type::KEY:
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                         "drain KEY code=%{public}d action=%{public}d", ev.keyCode, ev.action);
            break;
        case OhemacsEvent::Type::EXPOSE:
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "drain EXPOSE");
            break;
        case OhemacsEvent::Type::TOUCH:
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "drain TOUCH %{public}d,%{public}d",
                         ev.x, ev.y);
            break;
        case OhemacsEvent::Type::CONFIGURE:
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                         "drain CONFIGURE %{public}llu x %{public}llu",
                         (unsigned long long)ev.width, (unsigned long long)ev.height);
            break;
        }
    }
}

// ---------------------------------------------------------------------------
// XComponent callbacks (run on ArkUI render thread; keep short, like Android
// UI thread -> android_write_event path)
// ---------------------------------------------------------------------------
void OnSurfaceCreated(OH_NativeXComponent *component, void *window) {
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "OnSurfaceCreated");
    if (component == nullptr || window == nullptr) {
        return;
    }
    EnsureStage2Bridge();
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_component = component;
        g_window = (OHNativeWindow *)window;
        OH_NativeWindow_NativeObjectReference(g_window);
        uint64_t w = 0, h = 0;
        if (OH_NativeXComponent_GetXComponentSize(component, window, &w, &h) == 0) {
            g_width = w;
            g_height = h;
            OhemacsEvent ev;
            ev.type = OhemacsEvent::Type::CONFIGURE;
            ev.width = w;
            ev.height = h;
            PushEventLocked(ev);
            ForwardConfigureToOhos(w, h);
        }
        DrainEventsForLog();
    }
    if (!InitEgl((OHNativeWindow *)window)) {
        return;
    }
    DrawFrame();
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "first frame drawn %{public}llu x %{public}llu",
                 (unsigned long long)g_width, (unsigned long long)g_height);
}

void OnSurfaceChanged(OH_NativeXComponent *component, void *window) {
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "OnSurfaceChanged");
    if (component == nullptr || window == nullptr) {
        return;
    }
    EnsureStage2Bridge();
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        uint64_t w = 0, h = 0;
        if (OH_NativeXComponent_GetXComponentSize(component, window, &w, &h) == 0) {
            g_width = w;
            g_height = h;
            OhemacsEvent ev;
            ev.type = OhemacsEvent::Type::CONFIGURE;
            ev.width = w;
            ev.height = h;
            PushEventLocked(ev);
            ForwardConfigureToOhos(w, h);
            DrainEventsForLog();
        }
    }
    DrawFrame();
}

void OnSurfaceDestroyed(OH_NativeXComponent *component, void *window) {
    (void)component;
    (void)window;
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "OnSurfaceDestroyed");
    DestroyEgl();
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_window != nullptr) {
        OH_NativeWindow_NativeObjectUnreference(g_window);
        g_window = nullptr;
    }
    g_component = nullptr;
}

void DispatchTouchEvent(OH_NativeXComponent *component, void *window) {
    (void)window;
    if (component == nullptr) {
        return;
    }
    OH_NativeXComponent_TouchEvent touch{};
    if (OH_NativeXComponent_GetTouchEvent(component, window, &touch) != 0) {
        return;
    }
    EnsureStage2Bridge();
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        for (uint32_t i = 0; i < touch.numPoints; ++i) {
            OhemacsEvent ev;
            ev.type = OhemacsEvent::Type::TOUCH;
            ev.x = (int32_t)touch.touchPoints[i].x;
            ev.y = (int32_t)touch.touchPoints[i].y;
            PushEventLocked(ev);
            ForwardTouchToOhos(ev.x, ev.y);
        }
        // Toggle tint slightly to prove input -> render path.
        g_clearColor[0] = 0.16f + (float)(g_eventCounter % 5) * 0.03f;
        DrainEventsForLog();
    }
    DrawFrame();
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "touch points=%{public}u frames=%{public}llu",
                 touch.numPoints, (unsigned long long)g_frameCounter);
}

} // namespace

// ---------------------------------------------------------------------------
// Public API used by napi_init.cpp
// ---------------------------------------------------------------------------
std::string OhemacsInit(const std::string &filesDir, const std::string &cacheDir) {
    EnsureStage2Bridge();
    std::lock_guard<std::mutex> lock(g_mutex);
    g_filesDir = filesDir;
    g_cacheDir = cacheDir;
    OhemacsEvent ev;
    ev.type = OhemacsEvent::Type::EXPOSE;
    PushEventLocked(ev);
    ForwardExposeToOhos();
    DrainEventsForLog();
    char buf[512];
    snprintf(buf, sizeof(buf), "emacs-30.1-ohos files=%s cache=%s events=%llu", filesDir.c_str(),
             cacheDir.c_str(), (unsigned long long)g_eventCounter);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "OhemacsInit %{public}s", buf);
    return std::string(buf);
}

void OhemacsSendKey(int32_t keyCode, int32_t action) {
    EnsureStage2Bridge();
    std::lock_guard<std::mutex> lock(g_mutex);
    OhemacsEvent ev;
    ev.type = OhemacsEvent::Type::KEY;
    ev.keyCode = keyCode;
    ev.action = action;
    PushEventLocked(ev);
    ForwardKeyToOhos(keyCode, action);
    DrainEventsForLog();
}

void OhemacsSendExpose() {
    EnsureStage2Bridge();
    bool shouldDraw = false;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        OhemacsEvent ev;
        ev.type = OhemacsEvent::Type::EXPOSE;
        PushEventLocked(ev);
        ForwardExposeToOhos();
        DrainEventsForLog();
        shouldDraw = (g_eglDisplay != EGL_NO_DISPLAY);
    }
    if (shouldDraw) {
        DrawFrame();
    }
}

int OhemacsSurfaceWidth() {
    std::lock_guard<std::mutex> lock(g_mutex);
    return (int)g_width;
}

int OhemacsSurfaceHeight() {
    std::lock_guard<std::mutex> lock(g_mutex);
    return (int)g_height;
}

uint64_t OhemacsFrameCounter() {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_frameCounter;
}

// ---------------------------------------------------------------------------
// XComponent registration helper called from NAPI testXComponent(id)
// ---------------------------------------------------------------------------
extern "C" void OhemacsRegisterCallbacks(OH_NativeXComponent *component) {
    if (component == nullptr) {
        return;
    }
    EnsureStage2Bridge();
    static OH_NativeXComponent_Callback cb = {OnSurfaceCreated, OnSurfaceChanged, OnSurfaceDestroyed,
                                              DispatchTouchEvent};
    OH_NativeXComponent_RegisterCallback(component, &cb);
    // Ask for soft keyboard so IME path (Stage 2 textconv) can attach.
    OH_NativeXComponent_SetNeedSoftKeyboard(component, true);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "callbacks registered, softkeyboard on");
}
