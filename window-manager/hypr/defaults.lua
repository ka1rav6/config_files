-- Shared variables, read by every other module. Loaded first.

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
