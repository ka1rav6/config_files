// =============================================================================
// hypr-ipc-shim — makes waybar's workspace clicks work under a Lua config.
// =============================================================================
// THE BUG THIS EXISTS FOR
//
// Clicking a workspace number in the bar does nothing on this machine, and has
// done nothing since hyprland.lua replaced hyprland.conf. It is not a
// configuration mistake; it cannot be fixed in config.jsonc.
//
// waybar's hyprland/workspaces module hardcodes the legacy IPC strings. They
// are in the binary:
//
//     $ strings /usr/bin/waybar | grep 'dispatch workspace'
//     dispatch workspace
//     dispatch workspace name:
//
// Under a Lua config, Hyprland 0.56 wraps whatever follows `dispatch` as a Lua
// expression and evaluates it:
//
//     $ printf 'dispatch workspace 2' | socat - UNIX-CONNECT:.../.socket.sock
//     error: [string "return hl.dispatch(workspace 2)"]:1: ')' expected near '2'
//
// `workspace 2` is not valid Lua and never can be -- `f 2` is not call syntax,
// so this fails at PARSE time. No global, no metatable and no override of
// hl.dispatch can rescue it, because nothing in the config runs before the
// parser rejects the string. Quoting does not help either: hl.dispatch takes a
// dispatcher object, not a legacy string, and answers `hl.dispatch: expected a
// dispatcher (e.g. hl.dsp.window.close())`.
//
// So either waybar learns Lua or something translates between them. This is the
// something.
//
// ---------------------------------------------------------------------------
// HOW
//
// Hyprland's IPC is two unix sockets in $XDG_RUNTIME_DIR/hypr/$HIS/, and the
// only thing that tells a client where to find them is
// HYPRLAND_INSTANCE_SIGNATURE. So this process builds a second directory that
// looks exactly like an instance:
//
//     .socket.sock    a listener of ours -- requests are translated, forwarded
//                     to the real socket, and the reply passed straight back
//     .socket2.sock   a symlink to the real one -- the event stream needs no
//                     translation, so it is not worth proxying
//
// then runs waybar as its child with HYPRLAND_INSTANCE_SIGNATURE pointing at
// that directory. Everything else waybar asks for -- `j/workspaces`,
// `j/monitors`, `j/activewindow` -- is forwarded byte for byte.
//
// WHY IT SUPERVISES WAYBAR RATHER THAN RUNNING ALONGSIDE IT
//   If waybar can start before the shim is listening, its first clicks go
//   nowhere and its workspace list comes up empty -- a startup race with a
//   confusing symptom. Making waybar a child removes the race by construction:
//   the sockets exist before waybar is executed. It also means one process to
//   start and one to stop. `pgrep -x waybar` still finds the child, so the
//   guard in autostart.lua is unaffected, and the shim exits when waybar does,
//   so `pkill -x waybar` still takes the whole thing down for waybar-ensure.sh
//   to restart.
//
// WHY NOT PATCH WAYBAR
//   A local waybar build would have to be rebuilt and re-patched at every
//   distribution upgrade, and silently reverts to broken if that is ever
//   forgotten. This is ~50 lines of translation that fails loudly instead.
//
// Usage: hypr-ipc-shim -- waybar -c <config> -s <style>
// Build: make -C ~/.config/hypr/daemons
// =============================================================================

#define _GNU_SOURCE
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>

#define REQ_MAX 8192
#define REPLY_MAX 262144

// How long to wait on the real Hyprland socket before giving up on one
// request. A compositor that is not answering must not be able to wedge the
// bar: dropping the reply loses one click, hanging here loses the module.
#define UPSTREAM_TIMEOUT_SEC 2

// Unix socket paths are capped by the kernel at sizeof(sun_path) -- 108 bytes
// including the terminator -- and bind() TRUNCATES rather than failing. These
// buffers are that size on purpose, so the truncation check in must_fmt()
// below is checking the limit that actually applies.
//
// It is not a comfortable margin here. The real path works out at 100 bytes:
//     /run/user/1000/hypr/<62-char instance signature>.shim/.socket.sock
// so a longer XDG_RUNTIME_DIR would overflow it. Hence a hard error with the
// offending path rather than a socket quietly bound to a shortened name that
// waybar would then fail to find.
#define SUNPATH_MAX ((size_t)sizeof(((struct sockaddr_un *)0)->sun_path))

static char real_socket[SUNPATH_MAX];
// Also bounded by SUNPATH_MAX: every socket this directory holds has to fit,
// so a directory that is already too long can never produce a usable one.
static char shim_dir[SUNPATH_MAX];
static pid_t child_pid = -1;

// snprintf that refuses to truncate.
static int must_fmt(char *buf, size_t cap, const char *what, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(buf, cap, fmt, ap);
    va_end(ap);
    if (n < 0 || (size_t)n >= cap) {
        fprintf(stderr,
                "hypr-ipc-shim: %s is %d bytes, over the %zu-byte limit\n",
                what, n, cap - 1);
        return -1;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Translation
// ---------------------------------------------------------------------------

// Append `arg` as a Lua value: a bare number if it looks like one, a quoted
// and escaped string otherwise.
//
// The distinction matters. Workspace 2 and workspace "2" are not the same
// thing to Hyprland -- the first is an id, the second is a name -- so a
// numeric id must not be quoted, and "name:scratch" must be.
static int append_lua_value(char *out, size_t cap, size_t *o, const char *arg) {
    const char *p = arg;
    int numeric = (*p == '-' || *p == '+') ? (p++, 1) : 1;
    if (!*p) numeric = 0;
    for (const char *q = p; *q; q++)
        if (!isdigit((unsigned char)*q)) { numeric = 0; break; }

    if (numeric) {
        int n = snprintf(out + *o, cap - *o, "%s", arg);
        if (n < 0 || (size_t)n >= cap - *o) return -1;
        *o += (size_t)n;
        return 0;
    }

    if (*o + 2 >= cap) return -1;
    out[(*o)++] = '"';
    for (const char *q = arg; *q; q++) {
        if (*o + 3 >= cap) return -1;
        // A workspace name is user-chosen and reaches us straight from
        // waybar's config, so a quote or a backslash in it must not be able to
        // terminate the literal early -- that would turn a name into
        // attacker-chosen Lua running inside the compositor.
        if (*q == '"' || *q == '\\') out[(*o)++] = '\\';
        if ((unsigned char)*q < 0x20) continue;  // drop control characters
        out[(*o)++] = *q;
    }
    out[(*o)++] = '"';
    out[*o] = '\0';
    return 0;
}

// Rewrite one legacy request into its Lua equivalent.
//
// Returns 1 if it rewrote the request into `out`, 0 if the request should be
// forwarded unchanged. Only the four forms waybar actually emits are handled;
// anything else -- every `j/` query, and any dispatcher a future waybar might
// send -- passes through untouched rather than being guessed at.
static int translate(const char *req, size_t len, char *out, size_t cap,
                     int *changes_workspace) {
    static const char PFX[] = "dispatch ";
    const size_t plen = sizeof PFX - 1;

    if (changes_workspace) *changes_workspace = 0;
    if (len < plen || strncmp(req, PFX, plen) != 0) return 0;

    const char *cmd = req + plen;
    while (*cmd == ' ') cmd++;

    struct { const char *name; const char *lua_open; const char *lua_close; } map[] = {
        // Both focus forms become the same dispatcher. waybar only emits
        // focusworkspaceoncurrentmonitor when its `move-to-monitor` option is
        // on, and hl.dsp.focus already lands the workspace on the monitor the
        // pointer is over, which is the behaviour that option is asking for.
        {"workspace ",                       "hl.dsp.focus({ workspace = ", " })"},
        {"focusworkspaceoncurrentmonitor ",  "hl.dsp.focus({ workspace = ", " })"},
        {"togglespecialworkspace ",          "hl.dsp.workspace.toggle_special(", ")"},
    };

    for (size_t i = 0; i < sizeof map / sizeof map[0]; i++) {
        size_t nlen = strlen(map[i].name);
        if (strncmp(cmd, map[i].name, nlen) != 0) continue;

        const char *arg = cmd + nlen;
        while (*arg == ' ') arg++;

        char argbuf[512];
        snprintf(argbuf, sizeof argbuf, "%s", arg);
        // Trim anything trailing; waybar sends no newline, but a stray one
        // would end up inside the Lua string literal.
        for (char *e = argbuf + strlen(argbuf); e > argbuf; e--)
            if (isspace((unsigned char)e[-1])) e[-1] = '\0'; else break;

        size_t o = 0;
        int n = snprintf(out, cap, "%s%s", PFX, map[i].lua_open);
        if (n < 0 || (size_t)n >= cap) return 0;
        o = (size_t)n;

        if (append_lua_value(out, cap, &o, argbuf) < 0) return 0;

        n = snprintf(out + o, cap - o, "%s", map[i].lua_close);
        if (n < 0 || (size_t)n >= cap - o) return 0;
        // Only the two focus forms can land on another monitor. Toggling a
        // special workspace opens it on the monitor you are already on, so it
        // never needs the cursor to follow.
        if (changes_workspace && i < 2) *changes_workspace = 1;
        return 1;
    }

    // The no-argument special-workspace toggle, which waybar sends for the
    // unnamed special workspace.
    if (strcmp(cmd, "togglespecialworkspace") == 0) {
        snprintf(out, cap, "%shl.dsp.workspace.toggle_special()", PFX);
        return 1;
    }

    return 0;
}

// ---------------------------------------------------------------------------
// Forwarding
// ---------------------------------------------------------------------------

static int connect_upstream(void) {
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return -1;

    struct sockaddr_un addr = {.sun_family = AF_UNIX};
    memcpy(addr.sun_path, real_socket, strlen(real_socket) + 1);

    struct timeval tv = {.tv_sec = UPSTREAM_TIMEOUT_SEC};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);

    if (connect(fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

// ---------------------------------------------------------------------------
// Following the cursor across monitors
// ---------------------------------------------------------------------------
//
// WHY THIS IS HERE AND NOT A HYPRLAND OPTION
//
// cursor:no_warps = true (looknfeel.lua) stops Hyprland dragging the pointer
// into the middle of whatever window it just focused. That is what we want
// for the dock -- click an app, the pointer stays on the dock. But workspace
// 10 lives on eDP-1, so clicking or scrolling to it on the bar left the
// pointer behind on HDMI-A-1 while the other screen became active: the
// workspace switched on a monitor the pointer could not reach, and the
// gesture could not be continued because the following scroll ticks landed
// on the wrong bar.
//
// Hyprland has no option for "follow to the new monitor but do not dive into
// the window" -- warp_on_change_workspace only offers the window centre. So
// the bar's own path does it: when a workspace switch moves focus to a
// different monitor, put the pointer at the SAME OFFSET on the new monitor
// that it had on the old one.
//
// That offset is the point. Both monitors run the same bar with the same
// modules in the same order from the left, so the same x offset is the same
// widget -- land on the workspace numbers on HDMI-A-1 and you land on the
// workspace numbers on eDP-1, with the gesture still live under the pointer.
// Keeping y unchanged keeps it at the same height in the bar.
//
// Only this path does it. SUPER + scroll (bindings.lua) still leaves the
// pointer alone, because there the pointer is wherever you are working rather
// than on a widget you are aiming at.

#define MAX_MONITORS 8

struct mon {
    double x, y, w, h, scale;
    int focused;
};

// Enough of a JSON reader for `j/monitors`, and no more.
//
// Depth tracking is the whole trick: a monitor object sits at depth 2 (inside
// the top-level array), and its nested activeWorkspace and specialWorkspace
// objects sit at depth 3. A naive scan for "name" or "id" would read those
// instead -- every monitor carries three of each. Taking keys only at depth 2
// makes the nested objects invisible without having to understand them.
static int parse_monitors(const char *j, struct mon *out, int max) {
    int depth = 0, count = -1;
    char key[32];

    for (const char *p = j; *p; p++) {
        if (*p == '"') {
            // Read a string token. If it is a key at depth 2, remember it and
            // let the value branch below pick up what follows.
            const char *start = ++p;
            while (*p && *p != '"') p += (*p == '\\' && p[1]) ? 1 : 0, p++;
            size_t len = (size_t)(p - start);
            const char *after = p + 1;
            while (*after == ' ' || *after == '\n' || *after == '\t') after++;
            if (*after == ':' && depth == 2 && len < sizeof key) {
                memcpy(key, start, len);
                key[len] = '\0';
            } else if (*after != ':') {
                key[0] = '\0';  // a string VALUE, not a key
            }
            continue;
        }
        if (*p == '{' || *p == '[') {
            depth++;
            if (depth == 2 && *p == '{') {
                if (++count >= max) return max;
                out[count] = (struct mon){.scale = 1.0};
            }
            continue;
        }
        if (*p == '}' || *p == ']') { depth--; continue; }

        if (depth != 2 || count < 0 || !key[0]) continue;

        if (*p == '-' || (*p >= '0' && *p <= '9')) {
            double v = strtod(p, (char **)&p);
            p--;  // the for-loop will advance past the last consumed character
            if      (!strcmp(key, "x"))      out[count].x = v;
            else if (!strcmp(key, "y"))      out[count].y = v;
            else if (!strcmp(key, "width"))  out[count].w = v;
            else if (!strcmp(key, "height")) out[count].h = v;
            else if (!strcmp(key, "scale"))  out[count].scale = v;
            key[0] = '\0';
        } else if (!strncmp(p, "true", 4) || !strncmp(p, "false", 5)) {
            if (!strcmp(key, "focused")) out[count].focused = (*p == 't');
            p += (*p == 't') ? 3 : 4;
            key[0] = '\0';
        }
    }
    return count + 1;
}

// Send a request to the real Hyprland socket and return its reply length.
static ssize_t ask_hyprland(const char *req, char *buf, size_t cap) {
    int fd = connect_upstream();
    if (fd < 0) return -1;
    if (write(fd, req, strlen(req)) < 0) { close(fd); return -1; }
    shutdown(fd, SHUT_WR);

    size_t len = 0;
    for (;;) {
        ssize_t r = read(fd, buf + len, cap - 1 - len);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) break;
        len += (size_t)r;
        if (len >= cap - 1) break;
    }
    buf[len] = '\0';
    close(fd);
    return (ssize_t)len;
}

static int focused_monitor(struct mon *mons, int n) {
    for (int i = 0; i < n; i++)
        if (mons[i].focused) return i;
    return -1;
}

// Which monitor contains this point, in LOGICAL coordinates. A monitor's
// reported width/height are its mode in physical pixels, so eDP-1 at scale
// 1.5 is 2880x1800 of hardware but 1920x1200 of desk space -- and cursorpos
// speaks the latter. Dividing by scale is what makes the two agree.
static int monitor_at(struct mon *mons, int n, double x, double y) {
    for (int i = 0; i < n; i++) {
        double w = mons[i].w / mons[i].scale, h = mons[i].h / mons[i].scale;
        if (x >= mons[i].x && x < mons[i].x + w &&
            y >= mons[i].y && y < mons[i].y + h)
            return i;
    }
    return -1;
}

// Called after a workspace dispatch has been forwarded. `before` is the index
// of the monitor that had focus beforehand, and `nbefore` how many there were.
//
// Geometry is taken from the fresh listing rather than the snapshot: indices
// are positional and stay put, but a monitor's scale or position can have
// changed, and the count check below is what catches a hotplug between the
// two reads.
static void follow_cursor_to_focus(int nbefore, int before) {
    char buf[REPLY_MAX];

    if (before < 0) return;
    if (ask_hyprland("j/monitors", buf, sizeof buf) <= 0) return;

    struct mon after_mons[MAX_MONITORS];
    int nafter = parse_monitors(buf, after_mons, MAX_MONITORS);
    int after = focused_monitor(after_mons, nafter);
    if (after < 0 || after == before || nafter != nbefore) return;

    // cursorpos answers "x, y" as plain text.
    if (ask_hyprland("cursorpos", buf, sizeof buf) <= 0) return;
    double cx = 0, cy = 0;
    if (sscanf(buf, "%lf, %lf", &cx, &cy) != 2) return;

    // If the pointer is already on the newly focused monitor there is nothing
    // to do -- the user got there by hand, or something else moved it.
    int at = monitor_at(after_mons, nafter, cx, cy);
    if (at == after) return;
    if (at < 0) at = before;

    const struct mon *from = &after_mons[at], *to = &after_mons[after];
    double tw = to->w / to->scale, th = to->h / to->scale;

    double nx = to->x + (cx - from->x);
    double ny = to->y + (cy - from->y);

    // Clamp into the destination. The monitors are different logical sizes
    // (2560x1440 against 1920x1200 here), so an offset that was comfortably
    // inside the wide screen can fall off the narrow one -- and a cursor
    // placed outside a monitor is a cursor Hyprland puts somewhere else.
    if (nx > to->x + tw - 2) nx = to->x + tw - 2;
    if (nx < to->x) nx = to->x;
    if (ny > to->y + th - 2) ny = to->y + th - 2;
    if (ny < to->y) ny = to->y;

    char req[160];
    snprintf(req, sizeof req,
             "dispatch hl.dsp.cursor.move({ x = %d, y = %d })", (int)nx, (int)ny);
    ask_hyprland(req, buf, sizeof buf);
}

// One client exchange, start to finish.
//
// Handled inline rather than with a state machine: a Hyprland IPC request is
// one small write and one small reply over a local socket, and the only client
// is waybar, which issues them one at a time. The upstream timeouts above are
// what keep "inline" from meaning "blockable".
static void serve(int client) {
    char req[REQ_MAX];
    ssize_t n = read(client, req, sizeof req - 1);
    if (n <= 0) { close(client); return; }
    req[n] = '\0';

    char translated[REQ_MAX];
    const char *send_buf = req;
    size_t send_len = (size_t)n;
    int changes_workspace = 0;

    if (translate(req, (size_t)n, translated, sizeof translated, &changes_workspace)) {
        send_buf = translated;
        send_len = strlen(translated);
    }

    // Snapshot which monitor has focus BEFORE the switch. It has to be read
    // first -- afterwards there is no way to tell which monitor we came from.
    int nbefore = 0, before = -1;
    if (changes_workspace) {
        char snap[REPLY_MAX];
        struct mon snap_mons[MAX_MONITORS];
        if (ask_hyprland("j/monitors", snap, sizeof snap) > 0) {
            nbefore = parse_monitors(snap, snap_mons, MAX_MONITORS);
            before = focused_monitor(snap_mons, nbefore);
        }
    }

    int up = connect_upstream();
    if (up < 0) { close(client); return; }

    if (write(up, send_buf, send_len) < 0) {
        close(up);
        close(client);
        return;
    }
    // Hyprland answers a request and closes. Half-closing tells it we are done
    // writing, which is what makes it treat a short request as complete rather
    // than waiting for more.
    shutdown(up, SHUT_WR);

    char reply[REPLY_MAX];
    for (;;) {
        ssize_t r = read(up, reply, sizeof reply);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) break;
        ssize_t off = 0;
        while (off < r) {
            ssize_t w = write(client, reply + off, (size_t)(r - off));
            if (w <= 0) { if (errno == EINTR) continue; goto done; }
            off += w;
        }
    }
done:
    close(up);
    close(client);

    // After the reply has gone back to waybar, so the bar is never kept
    // waiting on the extra round trips this costs.
    if (changes_workspace && before >= 0)
        follow_cursor_to_focus(nbefore, before);
}

// ---------------------------------------------------------------------------
// Setup and lifetime
// ---------------------------------------------------------------------------

static void cleanup(void) {
    char p[PATH_MAX];
    snprintf(p, sizeof p, "%s/.socket.sock", shim_dir);  unlink(p);
    snprintf(p, sizeof p, "%s/.socket2.sock", shim_dir); unlink(p);
    rmdir(shim_dir);
}

static void on_term(int sig) {
    // Take waybar with us, then clean up the socket directory. Without the
    // kill, a terminated shim would leave waybar alive and pointed at sockets
    // that no longer exist.
    if (child_pid > 0) kill(child_pid, SIGTERM);
    cleanup();
    _exit(128 + sig);
}

int main(int argc, char **argv) {
    char **child_argv = NULL;
    for (int i = 1; i < argc; i++)
        if (strcmp(argv[i], "--") == 0 && i + 1 < argc) { child_argv = &argv[i + 1]; break; }

    if (!child_argv) {
        fprintf(stderr, "usage: %s -- <command> [args...]\n", argv[0]);
        return 2;
    }

    const char *his = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    const char *xrd = getenv("XDG_RUNTIME_DIR");
    if (!his || !xrd) {
        // No Hyprland to proxy. Running the child unproxied is strictly better
        // than refusing to start -- the bar comes up and only clicking is
        // affected, which is exactly the state this machine is in today.
        fprintf(stderr, "hypr-ipc-shim: no Hyprland instance, running %s directly\n",
                child_argv[0]);
        execvp(child_argv[0], child_argv);
        return 127;
    }

    char listen_path[SUNPATH_MAX], ev_path[PATH_MAX], real_ev[PATH_MAX];

    if (must_fmt(real_socket, sizeof real_socket, "the Hyprland socket path",
                 "%s/hypr/%s/.socket.sock", xrd, his) < 0 ||
        must_fmt(shim_dir, sizeof shim_dir, "the shim directory",
                 "%s/hypr/%s.shim", xrd, his) < 0 ||
        must_fmt(listen_path, sizeof listen_path, "the shim socket path",
                 "%s/.socket.sock", shim_dir) < 0 ||
        must_fmt(ev_path, sizeof ev_path, "the shim event socket path",
                 "%s/.socket2.sock", shim_dir) < 0 ||
        must_fmt(real_ev, sizeof real_ev, "the Hyprland event socket path",
                 "%s/hypr/%s/.socket2.sock", xrd, his) < 0) {
        // Nothing has been created yet, so running waybar unproxied is still
        // the better failure: the bar comes up, only clicking stays broken.
        fprintf(stderr, "hypr-ipc-shim: running %s unproxied\n", child_argv[0]);
        execvp(child_argv[0], child_argv);
        return 127;
    }

    mkdir(shim_dir, 0700);

    // A previous run that was killed rather than asked to stop leaves these
    // behind, and bind() refuses an existing path.
    unlink(listen_path);
    unlink(ev_path);

    if (symlink(real_ev, ev_path) < 0 && errno != EEXIST) {
        fprintf(stderr, "hypr-ipc-shim: symlink %s: %s\n", ev_path, strerror(errno));
        return 1;
    }

    int lfd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    struct sockaddr_un addr = {.sun_family = AF_UNIX};
    memcpy(addr.sun_path, listen_path, strlen(listen_path) + 1);
    if (lfd < 0 || bind(lfd, (struct sockaddr *)&addr, sizeof addr) < 0 ||
        listen(lfd, 16) < 0) {
        fprintf(stderr, "hypr-ipc-shim: cannot listen on %s: %s\n", listen_path,
                strerror(errno));
        return 1;
    }

    signal(SIGINT, on_term);
    signal(SIGTERM, on_term);
    signal(SIGHUP, on_term);
    signal(SIGPIPE, SIG_IGN);  // a client that leaves mid-reply is routine

    char shim_his[PATH_MAX];
    snprintf(shim_his, sizeof shim_his, "%s.shim", his);

    child_pid = fork();
    if (child_pid < 0) { cleanup(); return 1; }
    if (child_pid == 0) {
        setenv("HYPRLAND_INSTANCE_SIGNATURE", shim_his, 1);
        execvp(child_argv[0], child_argv);
        fprintf(stderr, "hypr-ipc-shim: exec %s: %s\n", child_argv[0], strerror(errno));
        _exit(127);
    }

    int ep = epoll_create1(EPOLL_CLOEXEC);
    struct epoll_event ev = {.events = EPOLLIN, .data.fd = lfd};
    epoll_ctl(ep, EPOLL_CTL_ADD, lfd, &ev);

    for (;;) {
        struct epoll_event events[8];
        int n = epoll_wait(ep, events, 8, 1000);
        if (n < 0 && errno != EINTR) break;

        for (int i = 0; i < n; i++) {
            int c = accept4(lfd, NULL, NULL, SOCK_CLOEXEC);
            if (c >= 0) serve(c);
        }

        // The child is the reason this process exists; when waybar is gone
        // there is nothing left to proxy for.
        int status;
        pid_t done = waitpid(child_pid, &status, WNOHANG);
        if (done == child_pid) {
            cleanup();
            return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
        }
    }

    cleanup();
    return 1;
}
