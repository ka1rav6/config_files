# =============================================================================
# Event-driven replacements for the polling and fork-per-event parts of this
# desktop. Each program blocks in epoll_wait() and does work only when
# something actually happened.
#
#   waybar-hyprtodo    custom/hyprtodo   <- inotify on the hyprtodo database
#   waybar-kdeconnect  custom/kdeconnect <- D-Bus signals from kdeconnectd
#   hypr-ipc-shim      waybar's parent   <- translates waybar's legacy Hyprland
#                                          IPC into Lua so clicking a workspace
#                                          works again
#   hypr-digitizerd    a root service    <- evdev tablet-mode switch, drives the
#                                          i2c bind/unbind directly
#
# Build and install the three user programs into ~/.local/bin:
#     make && make install
#
# The root daemon is installed separately, because it needs to be:
#     sudo ~/.config/hypr/scripts/install-touchscreen.sh
# =============================================================================

CC      ?= cc
CFLAGS  ?= -O2 -g -std=c11 -Wall -Wextra -Wpedantic -Wshadow -fno-common
LDFLAGS ?=

PREFIX  ?= $(HOME)/.local
BINDIR  := $(PREFIX)/bin

USER_BINS := waybar-hyprtodo waybar-kdeconnect hypr-ipc-shim
ROOT_BINS := hypr-digitizerd

all: $(USER_BINS) $(ROOT_BINS)

# sd-bus lives in libsystemd. pkg-config rather than a bare -lsystemd so this
# still builds if the library ever moves.
waybar-kdeconnect: waybar-kdeconnect.c
	$(CC) $(CFLAGS) -o $@ $< $(shell pkg-config --cflags --libs libsystemd) $(LDFLAGS)

%: %.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

install: $(USER_BINS)
	install -d $(BINDIR)
	install -m 0755 $(USER_BINS) $(BINDIR)
	@echo "Installed $(USER_BINS) into $(BINDIR)"

clean:
	rm -f $(USER_BINS) $(ROOT_BINS)

.PHONY: all install clean
