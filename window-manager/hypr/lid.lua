-- Laptop lid handling.
--
-- Loaded from hyprland.lua. Registers ONE pair of binds and gets out of the way;
-- every decision about what a lid event means lives in scripts/lid.sh, which
-- reads it out of ~/.config/quickshell/settings.json at the moment it runs.
--
-- ---------------------------------------------------------------------------
-- WHY A SWITCH BIND AND NOT A WATCHER
--
-- Hyprland already reads the lid switch through libinput -- it appears under
-- `hyprctl devices` as a Switch Device -- and exposes it to the config as a
-- bind key. So this needs no polling loop, no udev rule, no evdev reader and no
-- second process: the compositor calls the script exactly when the lid moves.
--
-- Verified on 0.56.2 that the Lua config accepts switch keys (they show up in
-- `hyprctl binds` with `key: switch:on:Lid Switch`). There is no
-- lid event in hl.on's event list -- checked /usr/share/hypr/stubs/hl.meta.lua,
-- HL.EventName has monitor.*, window.*, workspace.* and nothing for switches --
-- so a bind is the mechanism, not a workaround.
--
--   switch:on:<device>   the switch CLOSED (lid shut)
--   switch:off:<device>  the switch OPENED (lid raised)
--
-- ---------------------------------------------------------------------------
-- WHY `locked`
--
-- Without it the bind does not fire while the session is locked, which is
-- precisely when a lid close matters most: shut the laptop on a locked session
-- with a monitor attached and the internal panel would keep rendering hyprlock
-- at nobody.
--
-- ---------------------------------------------------------------------------
-- WHY THE DEVICE NAME IS DISCOVERED
--
-- "Lid Switch" is what the kernel's PNP0C0D driver calls it and what this
-- machine reports, but it is a device name and device names are not a contract.
-- Reading it out of sysfs means a machine whose lid is called something else
-- still works, and -- the case that actually matters -- a machine with NO lid
-- switch at all registers no bind instead of registering one that can never
-- fire. Safe if the hardware is absent, which is the rule for everything here.
-- ---------------------------------------------------------------------------

local home = os.getenv("HOME")

--- The libinput name of this machine's lid switch, or nil if it has none.
---
--- An input device is the lid switch if its capability bitmap advertises
--- SW_LID (bit 0 of EV_SW). Reading `capabilities/sw` and checking the low bit
--- is exact; matching on the name would be circular. The name is then taken
--- from the same directory, because the NAME is what Hyprland matches binds on.
local function find_lid_switch()
    -- io.popen rather than a directory walk: Lua has no readdir, and this runs
    -- exactly once, at config parse, so a single shell is affordable.
    --
    -- `-print -quit` stops at the first match. The `sw` file is a hex bitmap;
    -- SW_LID is bit 0, so a lid switch has an odd last nibble.
    local command = [[
        for dir in /sys/class/input/input*; do
            [ -r "$dir/capabilities/sw" ] || continue
            sw=$(cat "$dir/capabilities/sw" 2>/dev/null)
            case "$sw" in
                *[13579bdfBDF]) ;;
                *) continue ;;
            esac
            [ -r "$dir/name" ] || continue
            cat "$dir/name"
            break
        done
    ]]

    local ok, pipe = pcall(io.popen, command)
    if not ok or pipe == nil then
        return nil
    end

    local name = pipe:read("*l")
    pipe:close()

    if name == nil then
        return nil
    end

    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return nil
    end

    return name
end

local lid_switch = find_lid_switch()
local script = home .. "/.config/hypr/scripts/lid.sh"

if lid_switch == nil then
    -- Not a warning worth a notification: a desktop has no lid, and saying so
    -- at every login would be noise. The line is in the log if it is ever asked.
    print("[lid] no lid switch found, lid handling not registered")
else
    print("[lid] using switch device: " .. lid_switch)

    hl.bind("switch:on:" .. lid_switch, hl.dsp.exec_cmd(script .. " close"), { locked = true })
    hl.bind("switch:off:" .. lid_switch, hl.dsp.exec_cmd(script .. " open"), { locked = true })
end

-- Reconcile at startup, unconditionally -- even on a machine with no lid switch,
-- because the camera half of this has to be undone after a crash.
--
-- TWO THINGS THIS FIXES, both of which are states the session can be started IN
-- rather than reach:
--
--   * The lid was shut when Hyprland came up (a login over SSH, a resume with
--     the laptop still closed, a compositor restart). No switch event will ever
--     arrive for a state that was already true, so without this the internal
--     panel would render at a closed lid until the lid was opened AND shut again.
--
--   * The camera was left deauthorized by a session that died with the lid down.
--     `lid.sh open` re-authorizes it, so a crash cannot leave the camera off
--     across a reboot.
hl.on("hyprland.start", function()
    hl.exec_cmd(script .. " reconcile")
end)
