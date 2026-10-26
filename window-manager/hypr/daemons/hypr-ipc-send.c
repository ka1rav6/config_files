// =============================================================================
// hypr-ipc-send — send one request to whichever Hyprland socket $HIS names.
// =============================================================================
// A three-line hyprctl, and the point is WHICH socket it reaches.
//
// waybar runs as a child of hypr-ipc-shim, so its HYPRLAND_INSTANCE_SIGNATURE
// points at the shim's instance directory rather than Hyprland's. Anything
// waybar spawns inherits that. So the bar's scroll commands, by doing nothing
// cleverer than resolving $HIS the way every Hyprland client does, go through
// the shim -- and pick up the shim's cursor-follow for free.
//
// THAT IS THE WHOLE REASON THIS EXISTS. The bar's click path has no choice
// but to go through the shim (waybar hardcodes the legacy strings), and
// having the scroll path go somewhere else would mean two implementations of
// "move the pointer to the other monitor's bar" that could drift apart. One
// of them would eventually be wrong. This way there is one.
//
// It also replaces `hyprctl dispatch '...'` on those two config lines, which
// was a shell plus a much larger binary doing argument parsing, per tick.
//
//     hypr-ipc-send 'dispatch workspace e+1'
//
// WHEN THERE IS NO SHIM
//   An earlier version passed the request through verbatim and trusted $HIS
//   to be the shim's. That turned one bug into two. relayer.sh launched
//   waybar directly on a monitor hotplug, so $HIS was Hyprland's own
//   signature, `dispatch workspace e+1` went to the compositor untranslated,
//   and the Lua config rejected it at parse time:
//
//       error: [string "return hl.dispatch(workspace e+1)"]:1: ')' expected
//
//   Clicking was already broken in that state -- that is the shim's job and
//   nothing can stand in for it -- but scrolling had worked before this
//   program existed, because the config called `hyprctl dispatch` with a Lua
//   string. Routing scroll through here made the shim-less state strictly
//   worse than the one it replaced.
//
//   So: when the socket we are about to reach is NOT a shim, do the rewrite
//   here, with the same code the shim uses (hypr-ipc-translate.h -- one text,
//   so the two can't drift). Scroll then degrades to "works, but the pointer
//   stays behind on a cross-monitor switch" instead of to "does nothing".
//
//   Two ways to end up there, both handled: $HIS never had the .shim suffix,
//   or it has one but the shim has since died and left a stale environment
//   behind -- in which case we strip the suffix and talk to Hyprland direct.
//
// The reply is printed; exits non-zero if no socket can be reached.
//
// Build: make -C ~/.config/hypr/daemons
// =============================================================================

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include "hypr-ipc-translate.h"

#define SHIM_SUFFIX ".shim"

// Fill addr for instance signature `his`. Returns -1 if the path would not
// fit in sun_path, which is a hard error rather than a shortened name that
// would connect to nothing (or, worse, to something else).
static int sock_addr(struct sockaddr_un *addr, const char *xrd, const char *his) {
    int n = snprintf(addr->sun_path, sizeof addr->sun_path,
                     "%s/hypr/%s/.socket.sock", xrd, his);
    return (n < 0 || (size_t)n >= sizeof addr->sun_path) ? -1 : 0;
}

static int try_connect(const struct sockaddr_un *addr) {
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return -1;
    if (connect(fd, (const struct sockaddr *)addr, sizeof *addr) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <request>\n", argv[0]);
        return 2;
    }

    const char *his = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    const char *xrd = getenv("XDG_RUNTIME_DIR");
    if (!his || !xrd) {
        fprintf(stderr, "%s: no Hyprland instance in the environment\n", argv[0]);
        return 1;
    }

    size_t hlen = strlen(his), slen = strlen(SHIM_SUFFIX);
    int via_shim = hlen > slen && strcmp(his + hlen - slen, SHIM_SUFFIX) == 0;

    struct sockaddr_un addr = {.sun_family = AF_UNIX};
    if (sock_addr(&addr, xrd, his) < 0) {
        fprintf(stderr, "%s: socket path too long\n", argv[0]);
        return 1;
    }

    int fd = try_connect(&addr);

    // A .shim signature that will not connect means the shim died but waybar
    // outlived it. Hyprland itself is still there under the base signature.
    if (fd < 0 && via_shim) {
        char base[256];
        if (hlen - slen < sizeof base) {
            memcpy(base, his, hlen - slen);
            base[hlen - slen] = '\0';
            struct sockaddr_un real = {.sun_family = AF_UNIX};
            if (sock_addr(&real, xrd, base) == 0 && (fd = try_connect(&real)) >= 0) {
                addr = real;
                via_shim = 0;
            }
        }
    }

    if (fd < 0) {
        fprintf(stderr, "%s: cannot reach %s\n", argv[0], addr.sun_path);
        return 1;
    }

    // Only rewrite when nothing downstream will. translate() leaves anything
    // it does not recognise alone and returns 0, so the fallback is still a
    // pass-through for every request that is not one of the four legacy forms.
    const char *req = argv[1];
    char rewritten[REQ_MAX];
    if (!via_shim && translate(req, strlen(req), rewritten, sizeof rewritten, NULL))
        req = rewritten;

    if (write(fd, req, strlen(req)) < 0) return 1;
    shutdown(fd, SHUT_WR);

    char reply[4096];
    ssize_t r;
    while ((r = read(fd, reply, sizeof reply)) > 0)
        (void)!write(STDOUT_FILENO, reply, (size_t)r);
    close(fd);
    return 0;
}
