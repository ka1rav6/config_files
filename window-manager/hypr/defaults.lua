-- Shared variables, read by every other module. Loaded first.

-- Force aquamarine onto its legacy (non-atomic) DRM interface.
--
-- aquamarine 0.15.0 hangs inside the atomic DRM commit when it re-enables an
-- output that was previously disabled -- "Modesetting eDP-1" is the last line
-- it ever logs, the panel keeps its backlight but gets no scanout, and only a
-- fresh Hyprland process recovers it (aquamarine #293 / #304 / #307).
--
-- Set here rather than in autostart.lua because this file is loaded first and
-- aquamarine reads AQ_* only while the backend is coming up. Confirm it took
-- effect by grepping the Hyprland log for:
--     AQ_NO_ATOMIC enabled, using the legacy drm iface
-- Remove once aquamarine > 0.15.0 reaches the PPA.
hl.env("AQ_NO_ATOMIC", "1")

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

launcher = "wofi --show drun --conf ~/.config/wofi/config --style ~/.config/wofi/style.css"

mainMod = "SUPER"
