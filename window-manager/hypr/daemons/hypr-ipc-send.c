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
// The request is passed through verbatim; the shim decides what, if anything,
// needs translating. Prints the reply, exits non-zero if it cannot connect.
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

    struct sockaddr_un addr = {.sun_family = AF_UNIX};
    int n = snprintf(addr.sun_path, sizeof addr.sun_path,
                     "%s/hypr/%s/.socket.sock", xrd, his);
    if (n < 0 || (size_t)n >= sizeof addr.sun_path) {
        fprintf(stderr, "%s: socket path too long\n", argv[0]);
        return 1;
    }

    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0 || connect(fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
        fprintf(stderr, "%s: cannot reach %s\n", argv[0], addr.sun_path);
        return 1;
    }

    if (write(fd, argv[1], strlen(argv[1])) < 0) return 1;
    shutdown(fd, SHUT_WR);

    char reply[4096];
    ssize_t r;
    while ((r = read(fd, reply, sizeof reply)) > 0)
        (void)!write(STDOUT_FILENO, reply, (size_t)r);
    close(fd);
    return 0;
}
