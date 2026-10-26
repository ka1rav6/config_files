# =============================================================================
# Event-driven replacements for the polling and fork-per-event parts of this
# desktop. Each program blocks in epoll_wait() and does work only when
# something actually happened.
#
#   barfeed-hyprtodo   custom/hyprtodo   <- inotify on the hyprtodo database
#   barfeed-kdeconnect custom/kdeconnect <- D-Bus signals from kdeconnectd
#   hypr-ipc-shim      waybar's parent   <- translates waybar's legacy Hyprland
#                                          IPC into Lua so clicking a workspace
#                                          works again
#   hypr-digitizerd    a root service    <- evdev tablet-mode switch, drives the
#                                          i2c bind/unbind directly
#
# Build (into build/) and install the user programs into ~/.local/bin:
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

# Build artefacts go in build/, NOT next to the sources, and the directory
# name is deliberate.
#
# ~/.config/hypr is a built-in path in the nightly config backup
# (~/.local/share/config-backup/config_backup.py), which copies it RECURSIVELY
# into ~/dotfiles and commits. Binaries sitting beside the .c files were
# therefore committed to a config repository on every run -- ~190 KB of ELF
# per commit, forever, and stale copies that a restore would drop on top of
# freshly built ones. "build" is already in that script's EXCLUDE_NAMES, so
# putting the output there makes the backup skip it with no change to the
# backup tooling.
OBJDIR  := build

USER_NAMES := barfeed-hyprtodo barfeed-kdeconnect hypr-ipc-shim hypr-ipc-send hypr-digitizer-ctl
ROOT_NAMES := hypr-digitizerd

USER_BINS := $(addprefix $(OBJDIR)/,$(USER_NAMES))
ROOT_BINS := $(addprefix $(OBJDIR)/,$(ROOT_NAMES))

all: $(USER_BINS) $(ROOT_BINS)

$(OBJDIR):
	@mkdir -p $(OBJDIR)

# sd-bus lives in libsystemd. pkg-config rather than a bare -lsystemd so this
# still builds if the library ever moves.
# hypr-ipc-shim and hypr-ipc-send share the legacy-IPC rewrite through a
# header, so a change to it has to rebuild both -- otherwise the two halves
# of one translation table go out of sync silently, which is exactly what
# putting it in a header was meant to prevent.
$(OBJDIR)/hypr-ipc-shim $(OBJDIR)/hypr-ipc-send: hypr-ipc-translate.h

$(OBJDIR)/barfeed-kdeconnect: barfeed-kdeconnect.c | $(OBJDIR)
	$(CC) $(CFLAGS) -o $@ $< $(shell pkg-config --cflags --libs libsystemd) $(LDFLAGS)

$(OBJDIR)/%: %.c | $(OBJDIR)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

install: $(USER_BINS)
	install -d $(BINDIR)
	install -m 0755 $(USER_BINS) $(BINDIR)
	@echo "Installed $(USER_NAMES) into $(BINDIR)"

clean:
	rm -rf $(OBJDIR)

.PHONY: all install clean
