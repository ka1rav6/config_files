-- ~/.config/hyprtodo/config.lua
-- Copy this file there and edit it; HyprTodo reads it on every launch.
-- Configuration is additive: category(...) upserts by id and never removes
-- database categories. The file is evaluated on every launch.
--
--   category(id, { name = "...", icon = "...", color = "#hex" })
--     Defines or updates a category/panel. icon/color are optional.
--     NOTE: categories defined here are re-created on every launch, so
--     deleting one in-app won't stick until you remove its line here.
--
--   columns(n)
--     How many panels wide the dashboard grid is (1-6). Also changeable
--     live in the app with the - and = keys.

category("college", { name = "College", icon = "󰂺", color = "#d29922" })
category("clubs",   { name = "Clubs",   icon = "󰋽", color = "#a371f7" })
category("today",   { name = "Today",   icon = "󰃭", color = "#58a6ff" })
category("general", { name = "General", icon = "󰇰", color = "#8b949e" })

columns(2)

preferences({
	workspace = "todo",
	theme = {
		background = "#0d1117", panel_bg = "#161b22", foreground = "#c9d1d9",
		muted = "#8b949e", accent = "#58a6ff", border = "#30363d"
	},
	keybindings = { complete = "c", edit = "e", undo = "u", help = "H" }
})
