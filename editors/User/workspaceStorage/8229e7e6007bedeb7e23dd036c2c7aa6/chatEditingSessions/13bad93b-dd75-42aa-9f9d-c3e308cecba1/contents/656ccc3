-- HyprTodo user configuration
-- This file is loaded on every launch. It is safe to edit while HyprTodo is closed.
-- The Lua environment is sandboxed: filesystem, process, and module APIs are unavailable.

-- Each category becomes a dashboard panel.
-- The id is stable and is used when tasks refer to the category.
-- name is the visible label; icon and color are optional panel decorations.
category("college", { name = "College", icon = "󰂺", color = "#d29922" })
category("clubs", { name = "Clubs", icon = "󰋽", color = "#a371f7" })
category("today", { name = "Today", icon = "󰃭", color = "#58a6ff" })
category("general", { name = "General", icon = "󰇰", color = "#8b949e" })

-- Number of category columns shown in the dashboard. Allowed range: 1-6.
columns(2)

preferences({
    -- Hyprland workspace name used when associating new tasks with a workspace.
    workspace = "todo",

    -- Colors are CSS values. These preserve the built-in GitHub-style theme
    -- while making every control dark and low-contrast until it is focused.
    theme = {
        background = "#0d1117",
        panel_bg = "#161b22",
        foreground = "#c9d1d9",
        muted = "#8b949e",
        accent = "#58a6ff",
        border = "#30363d",
        control_bg = "#18212d",
        control_hover = "#253449",
        control_border = "#344b67",
        control_primary = "#245078"
    },

    -- These are the configurable keybinding values currently exposed by the app.
    keybindings = {
        complete = "c",
        edit = "e",
        undo = "u",
        help = "H"
    }
})
