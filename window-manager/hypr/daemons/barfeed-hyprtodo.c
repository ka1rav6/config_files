// =============================================================================
// barfeed-hyprtodo — the custom/hyprtodo module, driven by the database.
// =============================================================================
// THE NAME IS LOAD-BEARING. It must not contain "waybar", and that was found
// the hard way: the first version was called waybar-hyprtodo and died every
// time a task changed.
//
// hyprtodo-cli nudges the bar after every write by running
//     pkill -SIGRTMIN+8 waybar
// (its config.lua calls the setting `waybar_signal`). pkill matches a
// SUBSTRING of the process name unless given -x, so "waybar" matched
// waybar-hyprtodo and waybar-kdeconnect as well as waybar itself -- and the
// default disposition of SIGRTMIN+8 is to TERMINATE. The old shell modules
// were immune by accident: they ran as `bash`, which does not contain
// "waybar".
//
// The rename is the real fix. The signalfd below is the belt to its braces:
// if some other caller's pattern ever does match, the signal now means
// "refresh", which is what every sender intends, instead of death.
// =============================================================================
// Replaces scripts/waybar-hyprtodo.sh, which waybar re-ran every 30 s. That
// script forked a shell, a `command -v`, a hyprtodo-cli and four `sed`s --
// 2,880 shells a day -- to discover, almost every time, that nothing had
// changed. This process starts once, blocks in epoll_wait(), and writes a line
// only when the answer is actually different.
//
// WHY THE BAR IS NOW CORRECT AS WELL AS CHEAPER
//   The shell version parsed `hyprtodo-cli counts --json` with
//       sed -n 's/.*"critical_pending":\([0-9]*\).*/\1/p'
//   and the CLI emits "critical", not "critical_pending". That capture never
//   matched, so $critical was always empty, always defaulted to 0, and the
//   `urgent` class could only ever be set by the overdue count. A critical task
//   has never once turned this module red. This program asks the CLI for its
//   own ready-made waybar payload instead of re-deriving one, so there is no
//   second place for the field names to drift.
//
// WHAT WAKES IT
//   inotify on ~/.local/share/hyprtodo   a task was added, completed or edited
//   a midnight timerfd                   "due today" and "overdue" change at
//                                        00:00 with no database write at all,
//                                        so nothing else would ever notice
//
// WHY IT STILL EXECS hyprtodo-cli
//   The alternative is linking sqlite3 and writing the count query here, which
//   would make this the second place that decides what "overdue" and "critical"
//   mean. They would drift, and the bar would quietly disagree with the app.
//   So the CLI stays authoritative and is spawned -- directly, never through a
//   shell -- only when the database has actually changed. That is a handful of
//   execs a day against the old 2,880, and none of them is a shell.
//
// waybar config.jsonc: no `interval` and no `signal`, which is what puts the
// module in continuous mode (waybar-custom(5): "If no interval or signal is
// defined, it is assumed that the out script loops itself"). `restart-interval`
// is the supervision.
//
// Build: make -C ~/.config/hypr/daemons
// =============================================================================

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/inotify.h>
#include <sys/signalfd.h>
#include <sys/timerfd.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern char **environ;

// SQLite does not write a database once per change. A single "add a task" is an
// open, a journal create, several writes and a journal delete -- five or more
// inotify events inside a few milliseconds. Re-running the CLI for each would
// make the bar flicker through intermediate states. Instead every event (re)arms
// this one-shot timer, so the CLI runs once, after the writes have stopped.
#define DEBOUNCE_MS 120

// Enough for the CLI's payload several times over; it is one short JSON object.
#define OUT_MAX 4096

static const char *DB_PREFIX = "hyprtodo.db";

// What the bar shows when the CLI cannot be run at all. A module that silently
// vanishes is indistinguishable from one that is working and has nothing to
// say, so failure gets a visible class of its own rather than an empty string.
static const char *FALLBACK =
    "{\"text\":\"TODO ?\",\"class\":\"hyprtodo error\","
    "\"tooltip\":\"hyprtodo-cli is not answering\"}";

static void emit(const char *line) {
    // One line, unbuffered-ish: waybar reads this pipe line by line, so a
    // payload that sits in stdio's buffer is a bar that does not update.
    fputs(line, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

// Run argv[], capture its stdout into buf. Returns 0 on a clean exit with
// output, -1 otherwise.
//
// posix_spawn rather than popen(): popen runs the command through /bin/sh,
// which is the fork this whole program exists to remove. There is nothing to
// expand here -- the argument vector is fixed -- so the shell buys nothing.
static int run_capture(char *const argv[], char *buf, size_t cap) {
    int fds[2];
    if (pipe2(fds, O_CLOEXEC) < 0) return -1;

    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_adddup2(&fa, fds[1], STDOUT_FILENO);
    // The CLI writes diagnostics to stderr; let them through to ours so a
    // failure is visible in the waybar log rather than silently swallowed.

    pid_t pid;
    int rc = posix_spawnp(&pid, argv[0], &fa, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&fa);
    close(fds[1]);

    if (rc != 0) {
        close(fds[0]);
        errno = rc;
        return -1;
    }

    size_t len = 0;
    for (;;) {
        ssize_t n = read(fds[0], buf + len, cap - 1 - len);
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (n == 0) break;
        len += (size_t)n;
        if (len >= cap - 1) break;
    }
    buf[len] = '\0';
    close(fds[0]);

    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {}

    if (len == 0) return -1;
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) return -1;

    // The payload must be exactly one line. Truncate at the first newline
    // rather than passing an embedded one through, which waybar would read as
    // the start of a second, malformed update.
    char *nl = strchr(buf, '\n');
    if (nl) *nl = '\0';
    return buf[0] ? 0 : -1;
}

// Ask the CLI for the current payload and print it, but only if it differs from
// what the bar is already showing. waybar re-renders on every line it reads, so
// suppressing identical updates is what keeps an unrelated write to the
// database (a backup, a snooze that changes nothing visible) from costing a
// redraw.
static void refresh(void) {
    static char last[OUT_MAX];
    char out[OUT_MAX];

    char *const argv[] = {(char *)"hyprtodo-cli", (char *)"waybar", NULL};
    const char *line = (run_capture(argv, out, sizeof out) == 0) ? out : FALLBACK;

    if (strcmp(line, last) == 0) return;
    snprintf(last, sizeof last, "%s", line);
    emit(line);
}

// Arm an absolute, one-shot timer for the next local midnight.
//
// TFD_TIMER_CANCEL_ON_SET is the part that matters on a laptop: it makes read()
// fail with ECANCELED if the realtime clock is stepped -- a resume from
// suspend, an NTP correction, a timezone change -- so the caller re-arms
// against the new clock instead of waiting out a midnight that already passed
// while the machine was asleep.
static void arm_midnight(int fd) {
    time_t now = time(NULL);
    struct tm tm;
    localtime_r(&now, &tm);
    tm.tm_mday += 1;
    tm.tm_hour = 0;
    tm.tm_min = 0;
    tm.tm_sec = 1;  // a second past, so a slow clock cannot land on yesterday
    tm.tm_isdst = -1;

    struct itimerspec its = {0};
    its.it_value.tv_sec = mktime(&tm);

    timerfd_settime(fd, TFD_TIMER_ABSTIME | TFD_TIMER_CANCEL_ON_SET, &its, NULL);
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

static void arm_debounce(int fd) {
    struct itimerspec its = {0};
    its.it_value.tv_nsec = DEBOUNCE_MS * 1000000L;
    timerfd_settime(fd, 0, &its, NULL);
}

int main(void) {
    // waybar closing the pipe must kill this process, not leave it writing into
    // a broken pipe forever. Default SIGPIPE does exactly that, so the only
    // thing to do here is make sure nothing has turned it off.
    signal(SIGPIPE, SIG_DFL);

    const char *home = getenv("HOME");
    if (!home) { emit(FALLBACK); return 1; }

    char dir[PATH_MAX];
    snprintf(dir, sizeof dir, "%s/.local/share/hyprtodo", home);

    int ep = epoll_create1(EPOLL_CLOEXEC);
    int ino = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    int debounce = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
    int midnight = timerfd_create(CLOCK_REALTIME, TFD_NONBLOCK | TFD_CLOEXEC);
    int sigfd = make_signalfd();
    if (ep < 0 || ino < 0 || debounce < 0 || midnight < 0 || sigfd < 0) {
        emit(FALLBACK);
        return 1;
    }

    // Watch the DIRECTORY, not the database file.
    //
    // SQLite in rollback-journal mode (which this database uses -- there is no
    // -wal alongside it) creates and deletes hyprtodo.db-journal around every
    // transaction, and a backup or an import can replace the database file
    // outright. A watch on the inode would survive neither: it would follow the
    // old file after a rename and see nothing after a replace. The directory
    // watch sees all of it, and the name filter below keeps the backups/
    // subdirectory and anything else out.
    if (inotify_add_watch(ino, dir,
                          IN_CLOSE_WRITE | IN_CREATE | IN_DELETE | IN_MOVED_TO |
                              IN_MODIFY) < 0) {
        // Not fatal. Without the watch this degrades to "correct at startup and
        // at every midnight", which is still a working bar, and the directory
        // may simply not exist yet on a machine where hyprtodo has never run.
        fprintf(stderr, "waybar-hyprtodo: cannot watch %s: %s\n", dir,
                strerror(errno));
    }

    struct epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.fd = ino;       epoll_ctl(ep, EPOLL_CTL_ADD, ino, &ev);
    ev.data.fd = debounce;  epoll_ctl(ep, EPOLL_CTL_ADD, debounce, &ev);
    ev.data.fd = midnight;  epoll_ctl(ep, EPOLL_CTL_ADD, midnight, &ev);
    ev.data.fd = sigfd;     epoll_ctl(ep, EPOLL_CTL_ADD, sigfd, &ev);
    watch_stdout(ep);

    arm_midnight(midnight);
    refresh();  // the bar must be right before anything has changed

    for (;;) {
        struct epoll_event events[8];
        int n = epoll_wait(ep, events, 8, -1);
        if (n < 0) {
            if (errno == EINTR) continue;
            return 1;
        }

        for (int i = 0; i < n; i++) {
            int fd = events[i].data.fd;

            if (fd == STDOUT_FILENO) {
                // waybar is gone. Nothing left to report to.
                return 0;

            } else if (fd == ino) {
                // inotify delivers a packed, variable-length stream; it must be
                // walked record by record rather than read as a struct.
                char buf[4096]
                    __attribute__((aligned(__alignof__(struct inotify_event))));
                ssize_t len;
                int interesting = 0;
                while ((len = read(ino, buf, sizeof buf)) > 0) {
                    for (char *p = buf; p < buf + len;) {
                        const struct inotify_event *e =
                            (const struct inotify_event *)p;
                        if (e->len &&
                            strncmp(e->name, DB_PREFIX, strlen(DB_PREFIX)) == 0)
                            interesting = 1;
                        p += sizeof(struct inotify_event) + e->len;
                    }
                }
                if (interesting) arm_debounce(debounce);

            } else if (fd == sigfd) {
                // Someone asked for an immediate refresh. Redundant now that
                // the inotify watch sees the write that prompted it, but
                // harmless and cheap, and refresh() suppresses the update if
                // nothing actually changed.
                struct signalfd_siginfo si;
                while (read(sigfd, &si, sizeof si) == sizeof si) {}
                arm_debounce(debounce);

            } else if (fd == debounce) {
                uint64_t ticks;
                if (read(debounce, &ticks, sizeof ticks) == sizeof ticks)
                    refresh();

            } else if (fd == midnight) {
                uint64_t ticks;
                ssize_t r = read(midnight, &ticks, sizeof ticks);
                // ECANCELED means the realtime clock was stepped. The day may
                // well have changed underneath us, so refresh and re-arm
                // against the clock as it now reads.
                if (r == sizeof ticks || errno == ECANCELED) {
                    arm_midnight(midnight);
                    refresh();
                }
            }
        }
    }
}
