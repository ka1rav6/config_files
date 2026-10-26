// =============================================================================
// barfeed-kdeconnect — the custom/kdeconnect module, driven by D-Bus signals.
// =============================================================================
// THE NAME IS LOAD-BEARING and must not contain "waybar". The full story is at
// the top of barfeed-hyprtodo.c: hyprtodo-cli runs `pkill -SIGRTMIN+8 waybar`
// after every write, pkill matches substrings, and SIGRTMIN+8 terminates by
// default -- so a module called waybar-kdeconnect was collateral damage every
// time an unrelated todo changed.
// =============================================================================
// Replaces scripts/waybar-kdeconnect.sh, which waybar re-ran every 30 s. That
// script forked a shell and one or two `kdeconnect-cli` processes each time;
// each kdeconnect-cli is a Qt/KDE binary that builds a QCoreApplication and
// opens its own D-Bus connection just to ask one question. 2,880 of those a
// day, to learn almost every time that the phone is exactly as reachable as it
// was 30 seconds ago.
//
// kdeconnectd already announces every change on the session bus. This process
// holds ONE bus connection open for the life of the bar, blocks in
// epoll_wait() on its fd, and writes a line only when something it cares about
// actually fires:
//
//   org.kde.kdeconnect.daemon.deviceVisibilityChanged   phone came or went
//   org.kde.kdeconnect.daemon.deviceAdded / Removed     pairing changed
//   org.kde.kdeconnect.daemon.deviceListChanged         catch-all
//   PropertiesChanged under /modules/kdeconnect/devices isReachable, isPaired,
//                                                       a rename
//   org.freedesktop.DBus.NameOwnerChanged               kdeconnectd itself
//                                                       restarted or has not
//                                                       started yet
//
// THE LAST ONE IS WHY THIS IS NOT JUST CHEAPER BUT MORE CORRECT. The polling
// version could show a stale state for up to 30 s after the phone connected,
// and -- worse -- if kdeconnectd was not running when the bar started, nothing
// told the bar when it came up. Watching NameOwnerChanged means the module
// re-reads the world the instant the daemon appears, and survives it being
// restarted underneath.
//
// waybar config.jsonc: no `interval` and no `signal`, which is what puts the
// module in continuous mode (waybar-custom(5): "If no interval or signal is
// defined, it is assumed that the out script loops itself"). `restart-interval`
// is the supervision.
//
// Build: make -C ~/.config/hypr/daemons   (links libsystemd for sd-bus)
// =============================================================================

#define _GNU_SOURCE
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/signalfd.h>
#include <sys/timerfd.h>
#include <systemd/sd-bus.h>
#include <time.h>
#include <unistd.h>

// A single connect or disconnect makes kdeconnectd emit several of the signals
// above within a few milliseconds -- deviceVisibilityChanged and
// deviceListChanged and a PropertiesChanged, all describing the same event.
// Every one of them (re)arms this one-shot timer, so the state is read once,
// after the burst, instead of three times through intermediate values.
#define DEBOUNCE_MS 80

#define OUT_MAX 1024

// md-monitor_cellphone (a laptop and a phone together) when the device is
// reachable, md-cellphone_link_off when it is not -- so the shape itself says
// the state, not only the colour. Both verified present in
// ~/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf.
//
// Written as universal character names rather than pasted glyphs: the bytes
// are then legible in a diff and in a terminal with no Nerd Font, and the
// compiler does the UTF-8 encoding.
#define ICON_LINKED "\U000F0989"
#define ICON_AWAY "\U000F0122"

static const char *KC_SERVICE = "org.kde.kdeconnect";
static const char *KC_PATH = "/modules/kdeconnect";
static const char *KC_IFACE = "org.kde.kdeconnect.daemon";

static void emit(const char *line) {
    fputs(line, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

// Escape a device name for embedding in a JSON string.
//
// Not paranoia: a phone's name is user-supplied and syncs from the device, so
// `Kairav's "spare" phone` is a thing someone can type into Android and have
// land in this bar. The shell version interpolated it raw and would have
// emitted invalid JSON, which waybar drops silently -- the module would just
// stop updating with no error anywhere.
// A name longer than this is truncated. The limit exists so the finished JSON
// object always fits in OUT_MAX -- a tooltip cut off halfway would lose its
// closing quote and brace, and waybar drops malformed JSON silently, so the
// module would simply stop updating with nothing in any log to say why.
#define NAME_MAX_BYTES 192

static void json_escape(const char *in, char *out, size_t cap) {
    size_t o = 0;
    if (cap > NAME_MAX_BYTES) cap = NAME_MAX_BYTES;

    const unsigned char *p = (const unsigned char *)in;
    for (; *p && o + 7 < cap; p++) {
        switch (*p) {
            case '"':  out[o++] = '\\'; out[o++] = '"';  break;
            case '\\': out[o++] = '\\'; out[o++] = '\\'; break;
            case '\n': out[o++] = '\\'; out[o++] = 'n';  break;
            case '\r': out[o++] = '\\'; out[o++] = 'r';  break;
            case '\t': out[o++] = '\\'; out[o++] = 't';  break;
            default:
                if (*p < 0x20) {
                    o += (size_t)snprintf(out + o, cap - o, "\\u%04x", *p);
                } else {
                    out[o++] = (char)*p;
                }
        }
    }

    // Only when the loop ran out of room (*p is still set) can it have stopped
    // inside a multi-byte UTF-8 sequence, and half a character is not valid
    // UTF-8 -- GTK would refuse to render the tooltip. Drop the continuation
    // bytes (10xxxxxx) and the lead byte they belong to, so the result ends on
    // a whole character. Guarded by *p because a name that ENDED in an emoji
    // is complete and must be left alone.
    if (*p) {
        while (o > 0 && ((unsigned char)out[o - 1] & 0xC0) == 0x80) o--;
        if (o > 0 && ((unsigned char)out[o - 1] & 0xC0) == 0xC0) o--;
    }

    out[o] = '\0';
}

// Ask the daemon for reachable AND paired devices, in one call.
//
// deviceNames(onlyReachable, onlyPaired) -> a{ss} gives ids and names
// together, so this is a single round trip rather than the shell version's
// "count them, then ask again for the first one's name".
//
// Returns the number of devices; writes the first device's name into `name`.
// A negative return means the daemon could not be reached at all, which is a
// different state from "zero devices" and is reported differently.
static int reachable_devices(sd_bus *bus, char *name, size_t cap) {
    sd_bus_error err = SD_BUS_ERROR_NULL;
    sd_bus_message *reply = NULL;
    int count = 0;

    name[0] = '\0';

    int r = sd_bus_call_method(bus, KC_SERVICE, KC_PATH, KC_IFACE, "deviceNames",
                               &err, &reply, "bb", 1, 1);
    if (r < 0) {
        sd_bus_error_free(&err);
        sd_bus_message_unref(reply);
        return -1;
    }

    r = sd_bus_message_enter_container(reply, SD_BUS_TYPE_ARRAY, "{ss}");
    if (r >= 0) {
        const char *id, *dev;
        while (sd_bus_message_read(reply, "{ss}", &id, &dev) > 0) {
            if (count == 0 && dev) snprintf(name, cap, "%s", dev);
            count++;
        }
        sd_bus_message_exit_container(reply);
    }

    sd_bus_error_free(&err);
    sd_bus_message_unref(reply);
    return count;
}

static void refresh(sd_bus *bus) {
    static char last[OUT_MAX];
    char name[256], escaped[NAME_MAX_BYTES], out[OUT_MAX];

    int count = reachable_devices(bus, name, sizeof name);

    if (count > 0) {
        json_escape(name[0] ? name : "Phone", escaped, sizeof escaped);
        snprintf(out, sizeof out,
                 "{\"text\":\"" ICON_LINKED "\",\"class\":\"connected\","
                 "\"tooltip\":\"%s — connected\\rLeft-click: Command Center"
                 "\\rRight-click: KDE Connect app\"}",
                 escaped);
    } else if (count == 0) {
        snprintf(out, sizeof out,
                 "{\"text\":\"" ICON_AWAY "\",\"class\":\"away\","
                 "\"tooltip\":\"No device reachable\\rLeft-click: Command Center"
                 "\\rRight-click: KDE Connect app\"}");
    } else {
        // The daemon is not on the bus. Distinct from "no device reachable":
        // nothing is wrong with the phone, the service is simply down, and
        // saying so is the difference between a user power-cycling their
        // phone and restarting kdeconnectd.
        snprintf(out, sizeof out,
                 "{\"text\":\"" ICON_AWAY "\",\"class\":\"away offline\","
                 "\"tooltip\":\"kdeconnectd is not running"
                 "\\rLeft-click: Command Center\"}");
    }

    if (strcmp(out, last) == 0) return;
    snprintf(last, sizeof last, "%s", out);
    emit(out);
}


// A signalfd for the "refresh now" real-time signals, so they are handled in
// the epoll loop like every other source rather than in an async handler.
//
// SIGRTMIN+8 and +9 are what this config's `pkill -SIGRTMIN+N waybar` callers
// send. Blocking them first is what stops the DEFAULT disposition -- terminate
// -- from running; see the note at the top of this file for the bug that
// taught us to do this.
static int make_signalfd(void) {
    sigset_t mask;
    sigemptyset(&mask);
    sigaddset(&mask, SIGRTMIN + 8);
    sigaddset(&mask, SIGRTMIN + 9);
    if (sigprocmask(SIG_BLOCK, &mask, NULL) < 0) return -1;
    return signalfd(-1, &mask, SFD_NONBLOCK | SFD_CLOEXEC);
}


// Watch our own stdout for the read end closing.
//
// SIGPIPE is not enough on its own. These programs write only when something
// changes, so a module that has settled can sit in epoll_wait() for hours
// with nothing to say -- and if waybar dies in that window there is no write
// to raise SIGPIPE on. The process is reparented to init and lives forever.
// That is not hypothetical: waybar-ensure.sh restarts the bar on every
// monitor hotplug and theme change, and each restart stranded one of these
// per bar.
//
// Registering stdout with an EMPTY event mask is the trick: epoll always
// reports EPOLLERR and EPOLLHUP whether or not they were asked for, so this
// costs no wakeups while the pipe is healthy and fires the moment waybar lets
// go. Asking for EPOLLOUT instead would spin, because a writable pipe is
// always ready.
static void watch_stdout(int ep) {
    struct epoll_event ev = {.events = 0, .data.fd = STDOUT_FILENO};
    epoll_ctl(ep, EPOLL_CTL_ADD, STDOUT_FILENO, &ev);
}

static int debounce_fd = -1;

static void arm_debounce(void) {
    struct itimerspec its = {0};
    its.it_value.tv_nsec = DEBOUNCE_MS * 1000000L;
    timerfd_settime(debounce_fd, 0, &its, NULL);
}

// Every match lands here. The handler deliberately does not look at the
// signal's arguments: whatever changed, the answer is to re-read the whole
// state once the burst settles. That is what makes this correct under signals
// arriving in any order, and under signals this program has never heard of.
static int on_signal(sd_bus_message *m, void *userdata, sd_bus_error *err) {
    (void)m; (void)userdata; (void)err;
    arm_debounce();
    return 0;
}

int main(void) {
    signal(SIGPIPE, SIG_DFL);

    sd_bus *bus = NULL;
    if (sd_bus_open_user(&bus) < 0) {
        emit("{\"text\":\"" ICON_AWAY "\",\"class\":\"away offline\","
             "\"tooltip\":\"No session D-Bus\"}");
        return 1;
    }

    // Everything kdeconnectd says about devices on its own interface. A NULL
    // member matches every signal, so a new one added by a future KDE Connect
    // is picked up without a change here.
    sd_bus_match_signal(bus, NULL, KC_SERVICE, KC_PATH, KC_IFACE, NULL,
                        on_signal, NULL);

    // Per-device property changes (isReachable, isPaired, name). path_namespace
    // covers every current and future device object under devices/ without
    // having to track their object paths as they come and go.
    sd_bus_add_match(bus, NULL,
                     "type='signal',"
                     "interface='org.freedesktop.DBus.Properties',"
                     "member='PropertiesChanged',"
                     "path_namespace='/modules/kdeconnect/devices'",
                     on_signal, NULL);

    // kdeconnectd appearing on or leaving the bus. Without this the module is
    // blind to the daemon restarting -- see the header.
    sd_bus_add_match(bus, NULL,
                     "type='signal',"
                     "sender='org.freedesktop.DBus',"
                     "path='/org/freedesktop/DBus',"
                     "interface='org.freedesktop.DBus',"
                     "member='NameOwnerChanged',"
                     "arg0='org.kde.kdeconnect'",
                     on_signal, NULL);

    int ep = epoll_create1(EPOLL_CLOEXEC);
    debounce_fd = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
    int busfd = sd_bus_get_fd(bus);
    int sigfd = make_signalfd();
    if (ep < 0 || debounce_fd < 0 || busfd < 0 || sigfd < 0) return 1;

    struct epoll_event sev = {.events = EPOLLIN, .data.fd = sigfd};
    epoll_ctl(ep, EPOLL_CTL_ADD, sigfd, &sev);

    struct epoll_event tev = {.events = EPOLLIN, .data.fd = debounce_fd};
    epoll_ctl(ep, EPOLL_CTL_ADD, debounce_fd, &tev);

    struct epoll_event bev = {.events = EPOLLIN, .data.fd = busfd};
    epoll_ctl(ep, EPOLL_CTL_ADD, busfd, &bev);

    watch_stdout(ep);

    refresh(bus);

    for (;;) {
        // Drain everything sd-bus already has buffered before blocking. A
        // non-zero return means it did work and may have more, so this must
        // loop rather than process once per wakeup.
        int r;
        while ((r = sd_bus_process(bus, NULL)) > 0) {}
        if (r < 0) {
            // The connection is gone (dbus-daemon restarted, or the session is
            // ending). Exiting is correct: waybar's restart-interval brings
            // this back with a fresh connection, which is far simpler than
            // reconnect logic that has to re-add every match.
            fprintf(stderr, "waybar-kdeconnect: bus error: %s\n", strerror(-r));
            return 1;
        }

        // sd-bus decides both which events it wants on its fd and how long it
        // may sleep -- it has its own timeouts for pending method calls, and
        // ignoring them would hang a call that is never going to be answered.
        int want = sd_bus_get_events(bus);
        if (want >= 0 && want != (int)bev.events) {
            bev.events = (uint32_t)want;
            epoll_ctl(ep, EPOLL_CTL_MOD, busfd, &bev);
        }

        // sd_bus_get_timeout reports an ABSOLUTE deadline on CLOCK_MONOTONIC,
        // not a duration, so it has to be compared against the monotonic clock
        // -- using time() here would produce a timeout decades in the future
        // and the bus's own deadlines would never fire.
        uint64_t usec = 0;
        int timeout = -1;
        if (sd_bus_get_timeout(bus, &usec) >= 0 && usec != UINT64_MAX) {
            struct timespec ts;
            clock_gettime(CLOCK_MONOTONIC, &ts);
            uint64_t now = (uint64_t)ts.tv_sec * 1000000ULL + ts.tv_nsec / 1000;
            timeout = (usec > now) ? (int)((usec - now) / 1000) : 0;
        }

        struct epoll_event events[8];
        int n = epoll_wait(ep, events, 8, timeout);
        if (n < 0) {
            if (errno == EINTR) continue;
            return 1;
        }

        for (int i = 0; i < n; i++) {
            if (events[i].data.fd == STDOUT_FILENO) {
                // waybar is gone. Nothing left to report to.
                return 0;

            } else if (events[i].data.fd == debounce_fd) {
                uint64_t ticks;
                if (read(debounce_fd, &ticks, sizeof ticks) == sizeof ticks)
                    refresh(bus);
            } else if (events[i].data.fd == sigfd) {
                // An explicit "refresh now" nudge. Redundant now that the bus
                // matches catch every change, but harmless -- and refresh()
                // prints nothing if the state is unchanged.
                struct signalfd_siginfo si;
                while (read(sigfd, &si, sizeof si) == sizeof si) {}
                arm_debounce();
            }
        }
    }
}
