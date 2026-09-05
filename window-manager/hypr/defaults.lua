terminal = "ghostty"
fileManager = "nautilus"

-- yazi, the TUI file manager, in its own Ghostty window. Absolute path
-- because the compositor's PATH is not the shell's and does not necessarily
-- carry ~/.local/bin. fileBrowserFloat gets its own class so rules.lua can
-- float it without catching every other terminal.
local yazi = os.getenv("HOME") .. "/.local/bin/yazi"
fileBrowser = "ghostty --title=yazi -e " .. yazi
fileBrowserFloat = "ghostty --class=com.yazi.ghostty --title=yazi -e " .. yazi
launcher = "wofi --show drun --conf ~/.config/wofi/config --style ~/.config/wofi/style.css"

mainMod = "SUPER"
