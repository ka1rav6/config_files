-- Main Hyprland entry point. Feature groups live in separate modules:
--   defaults.lua   - shared variables (terminal, launcher, mainMod)
--   monitors.lua   - monitor setup
--   looknfeel.lua  - gaps, borders, animations
--   input.lua      - keyboard / touchpad
--   rules.lua      - window rules
--   bindings.lua   - all keybindings
--   autostart.lua  - apps started once at compositor launch
--
-- Requires Hyprland >= 0.55 (Lua config support). This file is loaded
-- INSTEAD of hyprland.conf when present (checked once at compositor
-- startup), so log out & back in after changing between them.
-- Reload manually any time with:  hyprctl reload
--
-- API reference: https://wiki.hypr.land/Configuring/
-- LSP stubs for autocompletion: /usr/share/hypr/stubs/

dofile(os.getenv("HOME") .. "/.config/hypr/defaults.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/monitors.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/looknfeel.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/input.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/rules.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/bindings.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/autostart.lua")
