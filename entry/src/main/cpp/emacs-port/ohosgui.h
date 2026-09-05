// ohosgui.h — OpenHarmony display backend types for OHEmacs.
//
// Stage 2 scaffold. Clones the structure of Emacs 30.1 `src/androidgui.h`
// (885 lines) with JNI replaced by NAPI/XComponent + OH_NativeWindow.
//
// Full implementation will:
//  - define `struct ohos_display_info`, `struct ohos_output`, `struct ohos_frame`
//  - define `union ohos_event` (key_press/release, touch_down/up/move,
//    motion, button, wheel, expose, configureNotify, focus_in/out, ime via
//    textconv.c, dnd, context_menu) mirroring android_event
//  - define software GC ops over OH_Drawing_Canvas (fill_rectangle, draw_line,
//    draw_text via sfntfont) mirroring android_fill_rectangle etc.
//  - declare ohos_write_event / ohos_pending / ohos_wait_event / ohos_next_event
//    (cloned from android.c:544-732) and ohos_select (cloned from android.c:761)
//    with eventfd wake instead of SIGUSR1.

#ifndef OHEMACS_OHOSGUI_H
#define OHEMACS_OHOSGUI_H

#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <sys/select.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Event types — parallel to android_event in androidgui.h. */
enum ohos_event_type {
    OHOS_KEY_PRESS,
    OHOS_KEY_RELEASE,
    OHOS_TOUCH_DOWN,
    OHOS_TOUCH_UP,
    OHOS_TOUCH_MOVE,
    OHOS_BUTTON_PRESS,
    OHOS_BUTTON_RELEASE,
    OHOS_WHEEL,
    OHOS_EXPOSE,
    OHOS_CONFIGURE_NOTIFY,
    OHOS_FOCUS_IN,
    OHOS_FOCUS_OUT,
    OHOS_IME_TEXT,
    OHOS_DND,
    OHOS_CONTEXT_MENU
};

struct ohos_key_event {
    int keycode; /* OH XComponent KEY_* numbering */
    int action;  /* 0 = up, 1 = down */
    int64_t timestamp;
};

struct ohos_touch_event {
    int x;
    int y;
    int64_t timestamp;
};

struct ohos_configure_event {
    uint64_t width;
    uint64_t height;
};

struct ohos_event {
    enum ohos_event_type type;
    union {
        struct ohos_key_event key;
        struct ohos_touch_event touch;
        struct ohos_configure_event configure;
    } u;
};

/* Bounded queue — mirrors struct android_event_queue (android.c:244). */
#define OHOS_EVENT_QUEUE_CAP 1024

struct ohos_event_queue {
    pthread_mutex_t mutex;
    pthread_mutex_t select_mutex;
    pthread_t select_thread;
    pthread_cond_t read_var;
    int num_events;
    /* circular doubly-linked containers in full port; vector in scaffold */
};

void ohos_init_events(void);
void ohos_write_event(struct ohos_event event);
int ohos_pending(void);

/* Blocking / non-blocking dequeue — mirrors the android.c:544-732 wait
   paths. Returns 1 with *EVENT filled, 0 if empty (next only). */
int ohos_wait_event(struct ohos_event *event);
int ohos_next_event(struct ohos_event *event);

/* pselect() wrapper folding the internal eventfd wake source into READFDS
   (mirrors android_select in android.c:761). Returns the ready-fd count
   with the internal fd discounted, 0 if only Emacs events are pending. */
int ohos_select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds,
                const struct timespec *timeout, const sigset_t *sigmask);

/* Raw level-triggered wake fd for custom poll loops. */
int ohos_event_fd(void);
void ohos_shutdown_events(void);

#ifdef __cplusplus
}
#endif

#endif /* OHEMACS_OHOSGUI_H */
