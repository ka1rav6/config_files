// =============================================================================
// hypr-digitizerd — tablet-mode switch to touchscreen digitizer, in one place.
// =============================================================================
// Replaces touchscreen.lua's device discovery and switch binds,
// scripts/touchscreen-toggle.sh, scripts/touchscreen.sh and the
// /etc/sudoers.d/61-hypr-touchscreen grant with a single root service that
// reads the switch itself and writes the sysfs bind/unbind itself.
//
// EVERYTHING ABOUT WHY THE DIGITIZER IS TURNED OFF AT ALL -- the ~41,600
// interrupts/sec, the core held out of deep idle, the gentler options that do
// not work -- is unchanged and still documented at the top of
// scripts/touchscreen.sh. This file is about the mechanism, not the policy.
//
// ---------------------------------------------------------------------------
// WHAT WAS WRONG WITH THE OLD CHAIN
//
// A fold ran: Hyprland bind -> touchscreen-toggle.sh (bash) -> sudo ->
// touchscreen.sh (bash) -> one write to /sys. Four processes, and NOTHING
// SERIALISED THEM. Two quick folds, or a fold while the startup reconcile was
// still running, put two of those chains in flight at once: both read
// "unbound", both decided to bind, and the second write to `bind` hits a device
// that is already bound and fails. There was no lock anywhere in the chain.
//
// This daemon is a single process with a single epoll loop, so two events
// cannot be in flight at once -- the race is gone by construction rather than
// by adding a lockfile.
//
// ---------------------------------------------------------------------------
// WHY IT READS evdev RATHER THAN TAKING HYPRLAND'S WORD
//
// Not for speed; Hyprland's switch binds already fire on the event. It is for
// the three things the bind could not do:
//
//   * THE SWITCH DOES NOT EXIST AT LOGIN. intel_hid registers "Intel HID
//     switches" lazily, on the first fold -- see the kernel log line quoted in
//     the old touchscreen.lua. Hyprland parses its config once at startup, so
//     the first fold of a session could only ever work by pre-registering a
//     hardcoded device name. The inotify watch on /dev/input below picks the
//     device up the moment the kernel creates it, with no name hardcoded.
//
//   * THE STATE AT STARTUP WAS UNKNOWABLE. A switch emits no event for a state
//     that was already true, so a machine booted while folded came up with no
//     touch and nothing coming. The old `reconcile` could only guess, and
//     guessed START_ENABLED. EVIOCGSW asks the kernel what the switch reads
//     RIGHT NOW, so booting folded now comes up with touch on.
//
//   * ROOT CAN READ IT AND THE SESSION CANNOT. /dev/input/event* is
//     root:input 0660 and this user is not in `input`. Running as a system
//     service is what makes the direct read possible at all -- and the same
//     privilege removes the sudo hop, because writing /sys/bus/i2c/... no
//     longer needs one.
//
// A NOTE ON event17, which looks like the obvious device and is not: its
// capability bitmap is EV=13 -- SYN, KEY and MSC, with no EV_SW bit at all. It
// is intel-hid's hotkey keyboard, on the same INTC107B:00 platform device as
// the real switch but a different input node. This daemon matches on the
// SW_TABLET_MODE capability bit instead, which is why it finds the right one
// and would keep working on hardware that numbers its nodes differently.
//
// ---------------------------------------------------------------------------
// INSTALL
//     sudo ~/.config/hypr/scripts/install-touchscreen.sh
// which also removes the old sudoers drop-in if it is still there.
// =============================================================================

#define _GNU_SOURCE
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <linux/input.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/inotify.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/timerfd.h>
#include <sys/un.h>
#include <unistd.h>

// The i2c device name, which is BOTH the directory under /sys/bus/i2c/devices
// and the string written to the driver's bind/unbind files.
//
// Hardcoded deliberately, for the reason the old touchscreen.sh gave: this
// config already encodes machine specifics where it must, and a wrong guess is
// worse than no guess -- unbinding the touchpad would take the pointer out
// mid-session. Overridable for other hardware with --device.
#define DEFAULT_DEVICE "ELAN2514:00"

#define DRIVER_DIR "/sys/bus/i2c/drivers/i2c_hid_acpi"
#define INPUT_DIR "/dev/input"
#define CONTROL_SOCKET "/run/hypr-digitizerd.sock"

// A fold is one mechanical action but can bounce the switch, and a device that
// has just been created by the kernel may report its state a moment after the
// node appears. Settling first means one write to sysfs per fold.
#define DEBOUNCE_MS 150

// Up to this many switch devices watched at once. This machine has two
// candidates ("HP WMI hotkeys" and, once it exists, "Intel HID switches");
// the limit is slack, not a tuning parameter.
#define MAX_SWITCHES 16

#define BITS_PER_LONG (8 * (int)sizeof(long))
#define NLONGS(x) (((x) + BITS_PER_LONG - 1) / BITS_PER_LONG)
#define TEST_BIT(bit, array) \
    (((array)[(bit) / BITS_PER_LONG] >> ((bit) % BITS_PER_LONG)) & 1)

static const char *device = DEFAULT_DEVICE;
// Sized for the fixed /sys/bus/i2c/devices/ prefix plus an i2c name, not
// PATH_MAX: these paths are built by appending short literals, and a buffer
// that cannot plausibly overflow is one the compiler can prove safe.
static char device_dir[256];
static int start_enabled = 0;  // what to settle on when NOT folded

static int sw_fds[MAX_SWITCHES];
static int sw_count = 0;
static int epoll_fd = -1;
static int debounce_fd = -1;

static void logmsg(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fputs("hypr-digitizerd: ", stderr);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
    // Unbuffered so journalctl shows events as they happen rather than in a
    // block when the service stops.
    fflush(stderr);
}

// ---------------------------------------------------------------------------
// The one privileged action
// ---------------------------------------------------------------------------

// Bound means "a driver is attached", i.e. the touchscreen works and is
// costing interrupts. Tested by the `driver` symlink rather than by looking
// for input nodes, because the symlink appears and disappears atomically with
// the bind.
static int is_bound(void) {
    char p[PATH_MAX];
    snprintf(p, sizeof p, "%s/driver", device_dir);
    struct stat st;
    return stat(p, &st) == 0;
}

// Present means the i2c device exists at all, which is true whether or not a
// driver is bound: unbinding removes the symlink and the input nodes but
// leaves the device on the bus.
static int is_present(void) {
    struct stat st;
    return stat(device_dir, &st) == 0 && S_ISDIR(st.st_mode);
}

static int write_sysfs(const char *file, const char *value) {
    char p[PATH_MAX];
    snprintf(p, sizeof p, "%s/%s", DRIVER_DIR, file);
    int fd = open(p, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t n = write(fd, value, strlen(value));
    int saved = errno;
    close(fd);
    errno = saved;
    return n < 0 ? -1 : 0;
}

// Make the digitizer's attached state match `want`. Idempotent: the state is
// re-read first, so calling this with the state already correct does nothing
// and cannot fail.
static void set_digitizer(int want) {
    if (!is_present()) {
        logmsg("no i2c device i2c-%s, nothing to do", device);
        return;
    }
    if (is_bound() == !!want) return;

    char arg[64];
    snprintf(arg, sizeof arg, "i2c-%s", device);

    if (write_sysfs(want ? "bind" : "unbind", arg) < 0)
        logmsg("%s i2c-%s failed: %s", want ? "bind" : "unbind", device,
               strerror(errno));
    else
        logmsg("digitizer %s", want ? "on" : "off");
}

// ---------------------------------------------------------------------------
// The switch devices
// ---------------------------------------------------------------------------

// True if this fd's device both advertises EV_SW and has SW_TABLET_MODE among
// its switches. Capability bits, never a device name: an input device IS a
// tablet-mode switch if it says so, and matching "HP WMI hotkeys" or "Intel
// HID switches" by name would be circular as well as wrong on other hardware.
static int has_tablet_switch(int fd) {
    unsigned long evbits[NLONGS(EV_MAX)] = {0};
    if (ioctl(fd, EVIOCGBIT(0, sizeof evbits), evbits) < 0) return 0;
    if (!TEST_BIT(EV_SW, evbits)) return 0;

    unsigned long swbits[NLONGS(SW_MAX)] = {0};
    if (ioctl(fd, EVIOCGBIT(EV_SW, sizeof swbits), swbits) < 0) return 0;
    return TEST_BIT(SW_TABLET_MODE, swbits) != 0;
}

// What the switch reads right now, straight from the kernel, with no event
// required. This is what makes booting or restarting while folded work.
static int reads_folded(int fd) {
    unsigned long state[NLONGS(SW_MAX)] = {0};
    if (ioctl(fd, EVIOCGSW(sizeof state), state) < 0) return 0;
    return TEST_BIT(SW_TABLET_MODE, state) != 0;
}

// Folded if ANY watched switch says so.
//
// Both halves of this matter on this machine. "HP WMI hotkeys" advertises
// SW_TABLET_MODE and never reports it, so it must not be able to veto a fold
// by reading 0; "Intel HID switches" is the one that actually drives it. Since
// nothing readable from userspace distinguishes a device that declares the
// capability from one that drives it until an event arrives, every candidate
// is watched and whichever reports a fold wins.
static int any_folded(void) {
    for (int i = 0; i < sw_count; i++)
        if (sw_fds[i] >= 0 && reads_folded(sw_fds[i])) return 1;
    return 0;
}

static void arm_debounce(void) {
    struct itimerspec its = {0};
    its.it_value.tv_nsec = DEBOUNCE_MS * 1000000L;
    timerfd_settime(debounce_fd, 0, &its, NULL);
}

// Open one /dev/input/eventN and keep it if it is a tablet-mode switch.
static void try_add_device(const char *name) {
    if (strncmp(name, "event", 5) != 0) return;
    if (sw_count >= MAX_SWITCHES) return;

    char path[PATH_MAX];
    snprintf(path, sizeof path, "%s/%s", INPUT_DIR, name);

    int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) return;

    if (!has_tablet_switch(fd)) { close(fd); return; }

    char devname[256] = "?";
    ioctl(fd, EVIOCGNAME(sizeof devname), devname);

    struct epoll_event ev = {.events = EPOLLIN, .data.fd = fd};
    if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &ev) < 0) { close(fd); return; }

    sw_fds[sw_count++] = fd;
    logmsg("watching tablet switch: %s (%s), currently %s", devname, path,
           reads_folded(fd) ? "folded" : "open");

    // A device that appears mid-session may already be folded -- in fact on
    // this machine that is exactly how it appears, because intel_hid creates
    // the node in response to the first fold. Re-evaluate rather than waiting
    // for an event that has already been and gone.
    arm_debounce();
}

static void drop_device(int fd) {
    epoll_ctl(epoll_fd, EPOLL_CTL_DEL, fd, NULL);
    close(fd);
    for (int i = 0; i < sw_count; i++) {
        if (sw_fds[i] == fd) {
            sw_fds[i] = sw_fds[--sw_count];
            break;
        }
    }
    logmsg("a tablet switch went away, %d left", sw_count);
}

static void scan_devices(void) {
    DIR *d = opendir(INPUT_DIR);
    if (!d) { logmsg("cannot read %s: %s", INPUT_DIR, strerror(errno)); return; }
    struct dirent *e;
    while ((e = readdir(d))) try_add_device(e->d_name);
    closedir(d);
}

// ---------------------------------------------------------------------------
// Policy
// ---------------------------------------------------------------------------

// Manual override. SUPER + SHIFT + D turns touch on in laptop mode; that must
// survive until the form factor changes, or the keypress would be undone by
// the next thing that re-derives state. A fold or unfold clears it, because
// the fold is a newer and more explicit statement of intent than the keypress.
static int manual_override = -1;  // -1 none, 0 forced off, 1 forced on

static void apply(void) {
    int folded = any_folded();
    int want = folded ? 1 : (manual_override >= 0 ? manual_override : start_enabled);
    set_digitizer(want);
}

static int last_folded = -1;

static void on_switch_settled(void) {
    int folded = any_folded();
    // A fold or unfold is a fresh statement of intent and retires any manual
    // override; a debounce that fires without the state having changed (a
    // bounce, a device appearing) leaves the override alone.
    if (folded != last_folded) {
        last_folded = folded;
        manual_override = -1;
    }
    apply();
}

// ---------------------------------------------------------------------------
// Control socket
// ---------------------------------------------------------------------------
//
// One line in, one line out. The session uses it for SUPER + SHIFT + D and for
// the status the bar and scripts ask for; it carries no privileged argument,
// only a verb from a fixed set, so the grant it represents is "may toggle the
// touchscreen" and nothing wider. That is narrower than the sudoers drop-in it
// replaces, which permitted five command lines on a root-owned binary.
static void handle_control(int fd) {
    char buf[64];
    ssize_t n = read(fd, buf, sizeof buf - 1);
    if (n <= 0) { close(fd); return; }
    buf[n] = '\0';
    while (n > 0 && isspace((unsigned char)buf[n - 1])) buf[--n] = '\0';

    const char *reply = "error\n";

    if (strcmp(buf, "toggle") == 0) {
        if (!is_present()) {
            reply = "absent\n";
        } else {
            manual_override = !is_bound();
            apply();
            reply = is_bound() ? "on\n" : "off\n";
        }
    } else if (strcmp(buf, "on") == 0 || strcmp(buf, "off") == 0) {
        manual_override = (buf[1] == 'n');
        apply();
        reply = is_bound() ? "on\n" : "off\n";
    } else if (strcmp(buf, "status") == 0) {
        reply = !is_present() ? "absent\n" : (is_bound() ? "on\n" : "off\n");
    }

    (void)!write(fd, reply, strlen(reply));
    close(fd);
}

// ---------------------------------------------------------------------------
// Lifetime
// ---------------------------------------------------------------------------

static volatile sig_atomic_t stopping = 0;
static void on_term(int sig) { (void)sig; stopping = 1; }

int main(int argc, char **argv) {
    uid_t owner = (uid_t)-1;
    gid_t owner_gid = (gid_t)-1;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--device") == 0 && i + 1 < argc) {
            device = argv[++i];
        } else if (strcmp(argv[i], "--start-enabled") == 0) {
            start_enabled = 1;
        } else if (strcmp(argv[i], "--owner") == 0 && i + 1 < argc) {
            owner = (uid_t)strtoul(argv[++i], NULL, 10);
        } else if (strcmp(argv[i], "--owner-gid") == 0 && i + 1 < argc) {
            owner_gid = (gid_t)strtoul(argv[++i], NULL, 10);
        } else {
            fprintf(stderr,
                    "usage: %s [--device NAME] [--start-enabled]"
                    " [--owner UID] [--owner-gid GID]\n",
                    argv[0]);
            return 2;
        }
    }

    snprintf(device_dir, sizeof device_dir, "/sys/bus/i2c/devices/i2c-%s", device);

    struct sigaction sa = {.sa_handler = on_term};
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    signal(SIGPIPE, SIG_IGN);

    epoll_fd = epoll_create1(EPOLL_CLOEXEC);
    debounce_fd = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
    int ino = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (epoll_fd < 0 || debounce_fd < 0 || ino < 0) {
        logmsg("cannot set up epoll: %s", strerror(errno));
        return 1;
    }

    struct epoll_event tev = {.events = EPOLLIN, .data.fd = debounce_fd};
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, debounce_fd, &tev);

    // THE WATCH THAT MAKES THE FIRST FOLD WORK. intel_hid creates its switch
    // node only when the machine is first folded, so the device this daemon
    // most needs does not exist when it starts. IN_CREATE on /dev/input is how
    // it is picked up the instant the kernel makes it, with no polling and no
    // device name assumed in advance.
    if (inotify_add_watch(ino, INPUT_DIR, IN_CREATE | IN_DELETE) < 0)
        logmsg("cannot watch %s: %s (hotplugged switches will be missed)",
               INPUT_DIR, strerror(errno));
    struct epoll_event iev = {.events = EPOLLIN, .data.fd = ino};
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, ino, &iev);

    unlink(CONTROL_SOCKET);
    int lfd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    struct sockaddr_un addr = {.sun_family = AF_UNIX};
    memcpy(addr.sun_path, CONTROL_SOCKET, sizeof CONTROL_SOCKET);
    if (lfd < 0 || bind(lfd, (struct sockaddr *)&addr, sizeof addr) < 0 ||
        listen(lfd, 8) < 0) {
        logmsg("cannot listen on %s: %s", CONTROL_SOCKET, strerror(errno));
        return 1;
    }
    // Reachable by the desktop user and nobody else. Without this the socket
    // is root-only and SUPER + SHIFT + D cannot reach it; with 0666 any
    // account on the machine could toggle the hardware.
    if (owner != (uid_t)-1) {
        if (chown(CONTROL_SOCKET, owner, owner_gid) < 0)
            logmsg("chown %s: %s", CONTROL_SOCKET, strerror(errno));
        chmod(CONTROL_SOCKET, 0660);
    }
    struct epoll_event lev = {.events = EPOLLIN, .data.fd = lfd};
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, lfd, &lev);

    scan_devices();
    last_folded = any_folded();
    logmsg("starting: %d switch device(s), %s, digitizer currently %s",
           sw_count, last_folded ? "folded" : "open",
           is_present() ? (is_bound() ? "on" : "off") : "absent");
    apply();

    while (!stopping) {
        struct epoll_event events[16];
        int n = epoll_wait(epoll_fd, events, 16, -1);
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }

        for (int i = 0; i < n; i++) {
            int fd = events[i].data.fd;

            if (fd == debounce_fd) {
                uint64_t ticks;
                if (read(debounce_fd, &ticks, sizeof ticks) == sizeof ticks)
                    on_switch_settled();

            } else if (fd == ino) {
                char buf[4096]
                    __attribute__((aligned(__alignof__(struct inotify_event))));
                ssize_t len;
                while ((len = read(ino, buf, sizeof buf)) > 0) {
                    for (char *p = buf; p < buf + len;) {
                        const struct inotify_event *e =
                            (const struct inotify_event *)p;
                        if (e->len && (e->mask & IN_CREATE)) try_add_device(e->name);
                        p += sizeof(struct inotify_event) + e->len;
                    }
                }

            } else if (fd == lfd) {
                int c = accept4(lfd, NULL, NULL, SOCK_CLOEXEC);
                if (c >= 0) handle_control(c);

            } else {
                // A switch device. Drain it; the debounce decides what it meant.
                struct input_event ie;
                int gone = 0, relevant = 0;
                for (;;) {
                    ssize_t r = read(fd, &ie, sizeof ie);
                    if (r == (ssize_t)sizeof ie) {
                        if (ie.type == EV_SW && ie.code == SW_TABLET_MODE)
                            relevant = 1;
                        continue;
                    }
                    if (r < 0 && errno == EAGAIN) break;
                    // ENODEV: the node was removed under us (a driver unbind,
                    // a suspend/resume cycle). Stop watching it; the inotify
                    // watch will pick up its replacement.
                    gone = 1;
                    break;
                }
                if (gone) drop_device(fd);
                else if (relevant) arm_debounce();
            }
        }
    }

    // Leave the digitizer ATTACHED on the way out.
    //
    // Same reasoning as the old installer's --uninstall: stopping this service
    // while the digitizer is detached would strand touch off with nothing left
    // on the machine able to turn it back on short of a reboot. A few seconds
    // of interrupts during a shutdown or a service restart is the cheaper
    // mistake.
    logmsg("stopping, re-attaching the digitizer so it is not left off");
    set_digitizer(1);
    unlink(CONTROL_SOCKET);
    return 0;
}
