hl.window_rule({
    name = "floating-audio-controls",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "floating-network-editor",
    match = { class = "^nm-connection-editor$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "floating-blueman",
    match = { class = "^(Blueman-manager|blueman-manager)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "floating-swaync",
    match = { class = "^swaync-control-center$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "floating-calculator",
    match = { class = "^(org.gnome.Calculator|galculator|qalculate-gtk)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "skip-focus-applets",
    match = { class = "^(nm-applet|blueman-applet)$" },
    no_focus = true,
})

hl.window_rule({
    name = "floating-dialogs",
    match = { title = "^(Open|Save|Select|Choose)" },
    float = true,
    center = true,
})

-- Scratchpads (the SUPER+` terminal, SUPER+E yazi, SUPER+Y music, SUPER+SHIFT+H
-- todo) pin themselves to a special workspace and float at a fixed size. All of
-- that is derived from the single registry in scratchpads.lua rather than
-- written out per app here, so a class can never drift between the rule that
-- catches the window and the lookup that decides whether to respawn it.
scratchpads.register_rules()

-- Blur scoping.
--
-- Blur is the compositor's most expensive effect, and it is only ever *visible*
-- through a translucent window. The only translucent windows here are Ghostty
-- (background-opacity 0.65 in ~/.config/ghostty/config), so everything else is
-- opted out and the GPU stops blurring behind surfaces you cannot see through.
--
-- This is done as catch-all + exception rather than one clever regex because
-- Hyprland's regex engine does NOT support negative lookahead -- a
-- "^(?!...ghostty$).*$" pattern silently matches nothing. A later rule DOES
-- override an earlier one for the same property, so the order of these two
-- matters: the exception has to come second.
hl.window_rule({
    name = "no-blur-by-default",
    match = { class = ".*" },
    no_blur = true,
})

hl.window_rule({
    name = "blur-translucent-terminals",
    -- All three Ghostty flavours: the ordinary one, plus the two scratchpads.
    match = { class = "^com\\.(mitchellh|scratchpad|yazi)\\.ghostty$" },
    no_blur = false,
})

-- Don't let hypridle lock the session while anything is fullscreen.
hl.window_rule({
    name = "no-idle-when-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- wlogout draws on the overlay layer. Blurring it and dimming what's behind
-- separates the menu from the desktop, so a keypress that powers the machine
-- off never reads as part of the window you were just working in.
--
-- The namespace is "gtk-layer-shell", not "wlogout" -- wlogout 1.1.1 never
-- sets one of its own, so it inherits gtk-layer-shell's default. Checked
-- against `hyprctl layers`; nwg-drawer registers under its own name, so this
-- does not catch the launcher.
-- Blur the desktop shell surfaces, so the bar, the launcher and notifications
-- sit on the wallpaper the same way Ghostty does instead of reading as flat
-- rectangles pasted on top of it.
--
-- Worth knowing: blurring a *fully opaque* layer is invisible and pure wasted
-- work. waybar was already rgba(18,20,24,0.94) and mako is now #121418f0, so
-- both show it; wofi was solid #111719 and had to be given an alpha channel in
-- its stylesheet before this rule meant anything.
--
-- These are small, mostly-static surfaces, and blur.new_optimizations caches
-- them between frames, so the cost is nothing like blurring a live window.
for _, namespace in ipairs({ "waybar", "wofi", "notifications" }) do
    hl.layer_rule({
        name = "blur-" .. namespace,
        match = { namespace = "^" .. namespace .. "$" },
        blur = true,
        -- Only blur behind the actually-translucent pixels; without this the
        -- rounded corners pick up a blurred square halo.
        ignore_alpha = 0.1,
    })
end

hl.layer_rule({
    name = "wlogout-overlay",
    match = { namespace = "^gtk-layer-shell$" },
    blur = true,
    dim_around = true,
})
