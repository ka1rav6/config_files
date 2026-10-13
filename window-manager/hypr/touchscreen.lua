-- Touchscreen digitizer power policy.
--
-- The compositor side of the toggle. Like lid.lua, this file registers binds
-- and decides nothing: every decision about what a tablet-mode event means
-- lives in scripts/touchscreen-toggle.sh, and the one privileged action lives
-- in scripts/touchscreen.sh. Read touchscreen.sh first -- it carries the
-- interrupt measurements that are the entire reason this feature exists.
--
-- THE SHORT VERSION
--   The ELAN2514 digitizer costs ~41,600 interrupts/sec whenever its driver is
--   attached, with nothing touching the panel, and that holds cpu2 out of deep
--   idle (C3 entries drop from 226/sec to 2/sec). Detaching it takes the rate to
--   0. Nothing makes it cheap while attached, so the policy is about WHEN it is
--   attached rather than how much it costs.
--
-- THE POLICY
--   Folded into tablet or tent mode, touch is the only input there is, so the
--   digitizer comes on. Open as a laptop, it stays off and SUPER + SHIFT + D
--   turns it on for as long as it is wanted. See the header of
--   touchscreen-toggle.sh for why that is the right trade on a convertible.
--
-- REQUIRES the one-time root install, which is NOT done by this file:
--   sudo ~/.config/hypr/scripts/install-touchscreen.sh
-- Without it the binds still register and simply report that the helper is
-- missing, which is the same "safe if the hardware or the install is absent"
-- rule the rest of this config follows.

local home = os.getenv("HOME")
local script = home .. "/.config/hypr/scripts/touchscreen-toggle.sh"

-- Whether the digitizer should be ON when the session starts.
--
-- false means a login costs nothing and touch is a keypress away. Set it to
-- true to have touch always available from login, at the cost documented above
-- -- it is a one-word change here and nothing else needs editing, because
-- touchscreen-toggle.sh reads it out of the environment.
local START_ENABLED = false

hl.env("HYPR_TOUCHSCREEN_START", START_ENABLED and "true" or "false")

--- Every libinput device on this machine that advertises SW_TABLET_MODE.
---
--- Found by capability bitmap rather than by name, for the same reason
--- find_lid_switch() in lid.lua does: an input device IS a tablet-mode switch
--- if it advertises SW_TABLET_MODE, and matching on a vendor string like
--- "HP WMI hotkeys" would be circular as well as wrong on the next machine. The
--- names are then read from the same directories, because the NAME is what
--- Hyprland matches binds on.
---
--- RETURNS A LIST, AND BINDS ALL OF THEM. This started as "find the switch",
--- singular, breaking at the first match -- and that was a bug waiting on this
--- exact machine.
---
--- `hp_wmi` registers "HP WMI hotkeys" (sw = 2) and it ADVERTISES
--- SW_TABLET_MODE without ever reporting it: the binds registered fine,
--- `hyprctl binds` showed them, and folding the screen did nothing. The driver
--- that actually reports it here is `intel_vbtn`, on ACPI device INT33D6, which
--- gates switch support on DMI chassis type (31 = Convertible on this machine).
---
--- Declaring a capability is not the same as driving it, and nothing readable
--- from userspace distinguishes the two before an event arrives. So rather than
--- rank them -- and get the order wrong on the next machine -- bind every
--- candidate and let whichever one actually fires win. The actions are
--- idempotent (touchscreen-toggle.sh returns early when the state already
--- matches), so two switches reporting the same fold is harmless.
local function find_tablet_switches()
    -- io.popen rather than a directory walk: Lua has no readdir, and this runs
    -- exactly once, at config parse, so a single shell is affordable.
    --
    -- SW_TABLET_MODE is bit 1 of EV_SW, so the hex bitmap's last nibble has the
    -- 2 bit set -- 2, 3, 6, 7, a, b, e or f. (lid.lua tests the 1 bit for
    -- SW_LID, which is why its pattern is the odd digits instead.) Verified
    -- against every switch device here: it matches HP WMI hotkeys (sw = 2) and
    -- correctly rejects Lid Switch (1), Headphone (4), Mic (10) and HDMI (140).
    local command = [[
        for dir in /sys/class/input/input*; do
            [ -r "$dir/capabilities/sw" ] || continue
            sw=$(cat "$dir/capabilities/sw" 2>/dev/null)
            case "$sw" in
                *[2367abefABEF]) ;;
                *) continue ;;
            esac
            [ -r "$dir/name" ] || continue
            cat "$dir/name"
        done
    ]]

    local ok, pipe = pcall(io.popen, command)
    if not ok or pipe == nil then
        return {}
    end

    local names, seen = {}, {}
    for line in pipe:lines() do
        local name = line:gsub("^%s+", ""):gsub("%s+$", "")
        -- Deduplicate: a driver can register more than one input node under the
        -- same name, and binding the same key twice is a config error.
        if name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    pipe:close()

    return names
end

--- Tablet switches that have to be bound BEFORE they exist.
---
--- Capability scanning alone cannot work on this machine, and the kernel log
--- says exactly why:
---
---   intel-hid INTC107B:00: switch event received, enable switches supports
---   input: Intel HID switches as /devices/platform/INTC107B:00/input/input62
---
--- `intel_hid` registers its switch device LAZILY -- on the first fold, not at
--- boot. So at login the only device advertising SW_TABLET_MODE is
--- "HP WMI hotkeys", which advertises it and never reports it. The first fold
--- then creates "Intel HID switches", which does report it, long after Hyprland
--- finished parsing this file. The binds were correct and the hardware worked;
--- the device simply did not exist yet to be found.
---
--- Binding a name that is not present is inert in Hyprland -- the bind sits
--- there and never fires -- so pre-registering costs nothing and is the only
--- thing that makes the FIRST fold of a session work.
---
--- This is the one place a device name is hardcoded instead of derived, and the
--- reason is that no capability is readable before the device exists. lid.lua's
--- rule ("a machine with no lid switch registers no bind rather than one that
--- can never fire") deliberately does not apply here: this bind can fire, just
--- not yet.
local KNOWN_LATE_SWITCHES = { "Intel HID switches" }

local tablet_switches = find_tablet_switches()

do
    -- Union, deduped. Discovery still runs and still wins on unknown hardware;
    -- this only guarantees the late-registering names are never missed.
    local seen = {}
    for _, name in ipairs(tablet_switches) do seen[name] = true end
    for _, name in ipairs(KNOWN_LATE_SWITCHES) do
        if not seen[name] then
            seen[name] = true
            tablet_switches[#tablet_switches + 1] = name
        end
    end
end

if #tablet_switches == 0 then
    -- Not worth a notification: a non-convertible has no tablet switch, and the
    -- manual toggle below still works. The line is in the log if it is ever
    -- asked about.
    print("[touchscreen] no tablet-mode switch found, automatic handling not registered")
else
    for _, name in ipairs(tablet_switches) do
        print("[touchscreen] binding tablet switch: " .. name)

        -- locked = true on both, because folding the machine into tablet mode on
        -- a locked session is exactly when touch is needed and cannot be asked
        -- for -- there is no keyboard reachable to press the manual toggle with.
        hl.bind("switch:on:" .. name,
            hl.dsp.exec_cmd(script .. " on"), { locked = true })
        hl.bind("switch:off:" .. name,
            hl.dsp.exec_cmd(script .. " off"), { locked = true })
    end
end

-- The manual escape hatch, and the only way to get touch in laptop mode.
--
-- SUPER + SHIFT + D for "digitizer". SUPER + SHIFT + T would have read better
-- for "touch" but is already the theme toggle (bindings.lua:432), and the
-- plain SUPER + T is windows.tile.
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd(script .. " toggle"))

-- Reconcile at startup, so the session settles on START_ENABLED rather than on
-- whatever the last session happened to leave behind.
--
-- This matters more than it looks. A switch event never arrives for a state
-- that was already true, so a machine booted while folded into tablet mode
-- would otherwise come up with no touch and no event coming. And a session that
-- died with the digitizer attached would leave it attached and storming across
-- the restart.
hl.on("hyprland.start", function()
    hl.exec_cmd(script .. " reconcile")
end)
