// ohos.cpp — OpenHarmony event queue for OHEmacs.
//
// Stage 2. Mirrors the structure of Emacs 30.1 `src/android.c:244-732`
// (struct android_event_queue, android_init_events, android_write_event,
// the android_pending_p / wait-event paths, android_select:761) with the
// wake mechanism replaced by a single Linux eventfd (musl supports
// eventfd(2)). ohos_select() folds that eventfd into the caller's fd_set
// so the Emacs event loop can sleep in pselect() without SIGUSR1.
//
// No Emacs upstream headers are required yet; the queue transports
// `struct ohos_event` from ohosgui.h. The full port feeds these events
// into keyboard.c via ohosterm.cpp:ohos_read_socket().

#include "ohosgui.h"

#include <hilog/log.h>

#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/select.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

namespace {

// Bounded ring buffer. android.c uses a linked queue capped at 1024
// events; a ring gives the same bound with static storage.
pthread_mutex_t g_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t g_has_event = PTHREAD_COND_INITIALIZER;
pthread_mutex_t g_init_mutex = PTHREAD_MUTEX_INITIALIZER;
struct ohos_event g_events[OHOS_EVENT_QUEUE_CAP];
int g_head = 0;
int g_tail = 0;
int g_count = 0;
unsigned long g_dropped = 0;
int g_wake_fd = -1;
bool g_initialized = false;

// Must be called with g_mutex held.
void WakeLocked() {
    if (g_wake_fd < 0) {
        return;
    }
    uint64_t one = 1;
    ssize_t n = write(g_wake_fd, &one, sizeof one);
    // EAGAIN just means the level-triggered counter is already nonzero.
    (void)n;
}

// Must be called with g_mutex held, only when the queue is empty, so a
// concurrent ohos_write_event (same lock) cannot lose a wakeup.
void DrainWakeLocked() {
    if (g_wake_fd < 0) {
        return;
    }
    uint64_t value = 0;
    ssize_t n = read(g_wake_fd, &value, sizeof value);
    (void)n;
    (void)value;
}

// Must be called with g_mutex held. Returns 1 with *OUT filled, 0 empty.
int NextEventLocked(struct ohos_event *out) {
    if (g_count <= 0) {
        return 0;
    }
    if (out != nullptr) {
        *out = g_events[g_head];
    }
    g_head = (g_head + 1) % OHOS_EVENT_QUEUE_CAP;
    g_count--;
    if (g_count == 0) {
        DrainWakeLocked();
    }
    return 1;
}

} // namespace

void ohos_init_events(void) {
    pthread_mutex_lock(&g_init_mutex);
    if (g_initialized) {
        pthread_mutex_unlock(&g_init_mutex);
        return;
    }
    int fd = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    if (fd < 0) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                     "ohos_init_events: eventfd failed %{public}d", errno);
    } else {
        g_wake_fd = fd;
    }
    g_head = 0;
    g_tail = 0;
    g_count = 0;
    g_dropped = 0;
    g_initialized = true;
    pthread_mutex_unlock(&g_init_mutex);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_init_events: cap=%{public}d wakefd=%{public}d", OHOS_EVENT_QUEUE_CAP,
                 fd);
}

void ohos_shutdown_events(void) {
    pthread_mutex_lock(&g_init_mutex);
    if (!g_initialized) {
        pthread_mutex_unlock(&g_init_mutex);
        return;
    }
    pthread_mutex_lock(&g_mutex);
    g_head = 0;
    g_tail = 0;
    g_count = 0;
    if (g_wake_fd >= 0) {
        close(g_wake_fd);
        g_wake_fd = -1;
    }
    pthread_mutex_unlock(&g_mutex);
    g_initialized = false;
    pthread_mutex_unlock(&g_init_mutex);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "ohos_shutdown_events");
}

void ohos_write_event(struct ohos_event event) {
    ohos_init_events();
    pthread_mutex_lock(&g_mutex);
    if (g_count >= OHOS_EVENT_QUEUE_CAP) {
        // Bounded queue: drop the oldest event, like android.c overflow.
        g_head = (g_head + 1) % OHOS_EVENT_QUEUE_CAP;
        g_count--;
        g_dropped++;
        OH_LOG_Print(LOG_APP, LOG_WARN, LOG_DOMAIN, LOG_TAG,
                     "ohos_write_event: queue full, dropped oldest (total %{public}lu)",
                     g_dropped);
    }
    g_events[g_tail] = event;
    g_tail = (g_tail + 1) % OHOS_EVENT_QUEUE_CAP;
    g_count++;
    pthread_cond_signal(&g_has_event);
    WakeLocked();
    pthread_mutex_unlock(&g_mutex);
}

int ohos_pending(void) {
    ohos_init_events();
    pthread_mutex_lock(&g_mutex);
    int n = g_count;
    pthread_mutex_unlock(&g_mutex);
    return n;
}

int ohos_next_event(struct ohos_event *event) {
    ohos_init_events();
    pthread_mutex_lock(&g_mutex);
    int rc = NextEventLocked(event);
    pthread_mutex_unlock(&g_mutex);
    return rc;
}

int ohos_wait_event(struct ohos_event *event) {
    ohos_init_events();
    pthread_mutex_lock(&g_mutex);
    while (g_count <= 0) {
        pthread_cond_wait(&g_has_event, &g_mutex);
    }
    int rc = NextEventLocked(event);
    pthread_mutex_unlock(&g_mutex);
    return rc;
}

int ohos_event_fd(void) {
    ohos_init_events();
    return g_wake_fd;
}

int ohos_select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds,
                const struct timespec *timeout, const sigset_t *sigmask) {
    ohos_init_events();
    int wake = g_wake_fd;

    // Fold the wake fd into a local copy of the read set.
    fd_set local_read;
    fd_set *rp = readfds;
    int local_nfds = nfds;
    bool folded = false;
    if (wake >= 0 && wake < FD_SETSIZE) {
        if (readfds != nullptr) {
            local_read = *readfds;
        } else {
            FD_ZERO(&local_read);
        }
        FD_SET(wake, &local_read);
        if (wake + 1 > local_nfds) {
            local_nfds = wake + 1;
        }
        rp = &local_read;
        folded = true;
    } else if (wake >= FD_SETSIZE) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                     "ohos_select: wake fd %{public}d exceeds FD_SETSIZE", wake);
    }

    int n = pselect(local_nfds, rp, writefds, exceptfds, timeout, sigmask);
    if (n < 0) {
        return n;
    }
    if (folded && FD_ISSET(wake, &local_read)) {
        pthread_mutex_lock(&g_mutex);
        DrainWakeLocked();
        pthread_mutex_unlock(&g_mutex);
        FD_CLR(wake, &local_read);
        if (readfds != nullptr) {
            *readfds = local_read;
        }
        // Discount the internal fd. Zero with events pending tells the
        // Emacs loop to pump ohos_read_socket(), like android_select.
        n -= 1;
        if (n < 0) {
            n = 0;
        }
    } else if (folded && readfds != nullptr) {
        *readfds = local_read;
    }
    return n;
}
