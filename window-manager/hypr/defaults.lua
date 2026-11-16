-- Shared variables, read by every other module. Loaded first.

-- No AQ_NO_ATOMIC here any more -- aquamarine is back on the atomic DRM iface.
--
-- It used to pin aquamarine to the legacy (non-atomic) iface, to dodge an
-- atomic-commit hang in aquamarine 0.15.0 when re-enabling a previously
-- disabled output (aquamarine #293 / #304 / #307). libaquamarine is 0.16.0
-- now, which is the condition that note set for taking the pin back out.
--
-- The legacy iface turned out to have a worse failure of its own: on
-- 2026-11-15 plugging in HDMI-A-1 modeset the new CRTC, logged two
--     ERR from aquamarine ]: drm: Cannot commit when a page-flip is awaiting
-- and the compositor exited not-cleanly a moment later -- start-hyprland
-- restarted it with --safe-mode. Legacy also has no gamma (no night light)
-- and cannot keep a hardware cursor armed across repaints.
--
-- If the OLD bug returns -- lid open or `dpms on` leaves a lit panel with no
-- picture, "Modesetting eDP-1" the last line in the log -- put this back:
--     hl.env("AQ_NO_ATOMIC", "1")

terminal = "ghostty"
fileManager = "nautilus"

-- yazi, the TUI file manager. Absolute path because the compositor's PATH is
-- not the shell's and does not necessarily carry ~/.local/bin.
yazi = os.getenv("HOME") .. "/.local/bin/yazi"

-- Tiled yazi (SUPER + ALT + E): an ordinary Ghostty window that takes a tile in
-- the layout like any other.
--
-- The *scratchpad* yazi (SUPER + E) is a different thing entirely -- it is
-- declared alongside the other scratchpads in scratchpads.lua, because it needs
-- a class, a window rule and a special workspace to go with it.
fileBrowser = terminal .. " --title=yazi -e " .. yazi

-- The launcher goes through a guard script rather than invoking wofi directly.
--
-- SUPER + S used to run this command unconditionally on every press, so holding
-- the key -- or pressing it twice while the first wofi was still mapping -- got
-- you two overlapping layer surfaces both holding a keyboard grab. The wofi
-- flags and the clipboard pipeline now live in scripts/wofi-launch.sh, which
-- serialises the decision behind an flock and keeps exactly one instance per
-- mode. See that file for why the obvious `pgrep wofi || wofi` is both racy and
-- self-matching.
launcher = os.getenv("HOME") .. "/.config/hypr/scripts/wofi-launch.sh drun"

mainMod = "SUPER"
