-- Rounded panes, matching Hyprland's decoration.rounding = 8 in looknfeel.lua.
require("full-border"):setup({
    type = ui.Border.ROUNDED,
})

-- Git status signs in the linemode. `order` decides where the sign sits
-- relative to other linemode contributors; 1500 puts it after the size.
require("git"):setup({
    order = 1500,
})
