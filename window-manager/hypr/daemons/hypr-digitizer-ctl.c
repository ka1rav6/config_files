// =============================================================================
// hypr-digitizer-ctl — the session's one line of conversation with the daemon.
// =============================================================================
// Replaces scripts/touchscreen-toggle.sh. That script existed to decide what a
// tablet-mode event meant and then ask a root helper to act on it; the daemon
// now does both, so all that is left on the session side is the manual
// override -- SUPER + SHIFT + D -- and a way to ask what the state is.
//
//     hypr-digitizer-ctl toggle    flip it, and keep that until the next fold
//     hypr-digitizer-ctl on|off    force it, same lifetime
//     hypr-digitizer-ctl status    on | off | absent
//
// Prints the daemon's answer and exits non-zero if it cannot be reached, so a
// keybind that does nothing says why in the Hyprland log instead of failing
// silently the way `sudo -n` did when its drop-in was missing.
//
// Notifications are deliberately NOT sent from here. The old script notified
// on the manual toggle, and that is still wanted -- it is in the Hyprland bind
// in touchscreen.lua, where it is one visible line rather than buried in a
// helper.
//
// Build: make -C ~/.config/hypr/daemons
// =============================================================================

#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define CONTROL_SOCKET "/run/hypr-digitizerd.sock"

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s toggle|on|off|status\n", argv[0]);
        return 2;
    }
    const char *verb = argv[1];
    if (strcmp(verb, "toggle") && strcmp(verb, "on") && strcmp(verb, "off") &&
        strcmp(verb, "status")) {
        fprintf(stderr, "%s: unknown command '%s'\n", argv[0], verb);
        return 2;
    }

    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    struct sockaddr_un addr = {.sun_family = AF_UNIX};
    memcpy(addr.sun_path, CONTROL_SOCKET, sizeof CONTROL_SOCKET);

    if (fd < 0 || connect(fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
        fprintf(stderr,
                "%s: cannot reach hypr-digitizerd. Is it installed and running?\n"
                "  sudo ~/.config/hypr/scripts/install-touchscreen.sh\n"
                "  systemctl status hypr-digitizerd\n",
                argv[0]);
        return 1;
    }

    if (write(fd, verb, strlen(verb)) < 0) return 1;
    shutdown(fd, SHUT_WR);

    char reply[64];
    ssize_t n = read(fd, reply, sizeof reply - 1);
    close(fd);
    if (n <= 0) return 1;
    reply[n] = '\0';

    fputs(reply, stdout);
    return strncmp(reply, "error", 5) == 0 ? 1 : 0;
}
