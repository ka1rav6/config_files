import QtQuick
import qs

// =============================================================================
// Icon — one glyph, named rather than pasted.
// =============================================================================
// Call sites say `Icon { name: "volume-high" }`, never a literal glyph. Three
// reasons that matters:
//
//   1. A bare Nerd Font glyph in source is unreadable and uneditable -- the
//      existing ~/.config/waybar/config.jsonc is full of them and you cannot
//      tell 󰕾 from 󰖀 while reading a diff.
//   2. The whole icon set can be swapped (to Material Symbols, say, if it is
//      ever installed) by editing this one map.
//   3. A typo'd name renders a visible placeholder instead of tofu, so a
//      missing icon is obvious at a glance rather than a blank space.
//
// WHY NERD FONT AND NOT AN ICON PACK
//   JetBrainsMono Nerd Font is already installed, already what waybar and
//   hyprlock use, and needs no new dependency. Using the same glyph set as the
//   bar is what stops the shell and the bar looking like two products.
//
// RENDERING
//   Nerd Font glyphs are monospaced and optically centred on their own metrics,
//   not on the text box, so a naive Text element puts them slightly high.
//   verticalAlignment plus the fixed line height below corrects that -- without
//   it, an icon next to a label never quite sits on the same baseline.
// =============================================================================

Text {
    id: root

    // Semantic name from the map below.
    required property string name

    // Size in logical px. Defaults to the design system's icon size so most
    // call sites say nothing.
    property int size: Appearance.iconSize

    // Generated and verified against the installed font. Every entry below was
    // resolved by looking up the Material Design glyph NAME in
    // ~/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf, not by typing a
    // codepoint from memory -- a first pass done by hand had a third of them
    // wrong (a `settings` that rendered a thermostat, a `folder` that rendered
    // a bank). The trailing comment on each line is the font's own glyph name,
    // so the mapping can be re-checked without a font editor.
    readonly property var glyphs: ({
        // --- audio ---------------------------------------------------
        "volume-high": "\udb81\udd7e",   // md-volume_high  U+F057E
        "volume-mid":  "\udb81\udd80",   // md-volume_medium  U+F0580
        "volume-low":  "\udb81\udd7f",   // md-volume_low  U+F057F
        "volume-mute": "\udb81\udf5f",   // md-volume_mute  U+F075F
        "volume-off":  "\udb81\udd81",   // md-volume_off  U+F0581
        "mic":         "\udb80\udf6c",   // md-microphone  U+F036C
        "mic-mute":    "\udb80\udf6d",   // md-microphone_off  U+F036D
        "headphones":  "\udb80\udecb",   // md-headphones  U+F02CB
        "music":       "\udb81\udf5a",   // md-music  U+F075A
        "music-note":  "\udb80\udf87",   // md-music_note  U+F0387
        // --- display -------------------------------------------------
        "brightness-high":  "\udb80\udce0",   // md-brightness_7  U+F00E0
        "brightness-low":   "\udb80\udcde",   // md-brightness_5  U+F00DE
        "monitor":          "\udb80\udf79",   // md-monitor  U+F0379
        "monitor-multiple": "\udb80\udf7a",   // md-monitor_multiple  U+F037A
        "night-light":      "\udb81\udd94",   // md-weather_night  U+F0594
        "sun":              "\udb81\udda8",   // md-white_balance_sunny  U+F05A8
        "wallpaper":        "\udb80\udee9",   // md-image  U+F02E9
        "desktop":          "\udb82\udeab",   // md-desktop_tower_monitor  U+F0AAB
        // --- network -------------------------------------------------
        "wifi-4":    "\udb82\udd28",   // md-wifi_strength_4  U+F0928
        "wifi-3":    "\udb82\udd25",   // md-wifi_strength_3  U+F0925
        "wifi-2":    "\udb82\udd22",   // md-wifi_strength_2  U+F0922
        "wifi-1":    "\udb82\udd1f",   // md-wifi_strength_1  U+F091F
        "wifi-0":    "\udb82\udd2f",   // md-wifi_strength_outline  U+F092F
        "wifi-off":  "\udb81\uddaa",   // md-wifi_off  U+F05AA
        "wifi-lock": "\udb82\udd2a",   // md-wifi_strength_4_lock  U+F092A
        "ethernet":  "\udb80\ude00",   // md-ethernet  U+F0200
        "router":    "\udb81\udc69",   // md-router_wireless  U+F0469
        "radar":     "\udb81\udc37",   // md-radar  U+F0437
        "web":       "\udb81\udd9f",   // md-web  U+F059F
        "ip":        "\udb82\ude60",   // md-ip_network  U+F0A60
        "calculator": "\udb80\udcec",  // md-calculator  U+F00EC
        "timer":     "\udb81\udd1b",   // md-timer_outline  U+F051B
        "home":      "\udb80\udedc",   // md-home  U+F02DC
        "backspace": "\udb80\udc6e",   // md-backspace  U+F006E
        "stop":      "\udb81\udcdb",   // md-stop  U+F04DB
        "camera":    "\udb80\udd00",   // md-camera  U+F0100
        "record":    "\udb81\udc4a",   // md-record_rec  U+F044A
        "eyedropper": "\udb80\ude0a",  // md-eyedropper  U+F020A
        "emoticon":  "\udb80\uddf2",   // md-emoticon_outline  U+F01F2
        "clipboard": "\udb80\udd47",   // md-clipboard_text  U+F0147
        "equalizer": "\udb83\udea2",   // md-equalizer  U+F0EA2
        "image-multiple": "\udb80\udef9", // md-image_multiple  U+F02F9
        "arrow-down": "\udb80\udc45",  // md-arrow_down  U+F0045
        "arrow-up":  "\udb80\udc5d",   // md-arrow_up  U+F005D
        "airplane":  "\udb80\udc1d",   // md-airplane  U+F001D
        // --- bluetooth -----------------------------------------------
        "bluetooth":           "\udb80\udcaf",   // md-bluetooth  U+F00AF
        "bluetooth-off":       "\udb80\udcb2",   // md-bluetooth_off  U+F00B2
        "bluetooth-connected": "\udb80\udcb1",   // md-bluetooth_connect  U+F00B1
        // --- power ---------------------------------------------------
        "battery-full":     "\udb80\udc79",   // md-battery  U+F0079
        "battery-high":     "\udb80\udc80",   // md-battery_70  U+F0080
        "battery-mid":      "\udb80\udc7e",   // md-battery_50  U+F007E
        "battery-low":      "\udb80\udc7c",   // md-battery_30  U+F007C
        "battery-empty":    "\udb80\udc8e",   // md-battery_outline  U+F008E
        "battery-charging": "\udb80\udc84",   // md-battery_charging  U+F0084
        "power":            "\udb81\udc25",   // md-power  U+F0425
        "lock":             "\udb80\udf3e",   // md-lock  U+F033E
        "key":              "\udb80\udf06",   // md-key  U+F0306
        "logout":           "\udb80\udf43",   // md-logout  U+F0343
        "restart":          "\udb81\udf09",   // md-restart  U+F0709
        "suspend":          "\udb82\udd04",   // md-power_sleep  U+F0904
        "performance":      "\udb81\udcc5",   // md-speedometer  U+F04C5
        "balanced":         "\udb83\udf85",   // md-speedometer_medium  U+F0F85
        "saver":            "\udb80\udf2a",   // md-leaf  U+F032A
        // --- media ---------------------------------------------------
        "play":     "\udb81\udc0a",   // md-play  U+F040A
        "pause":    "\udb80\udfe4",   // md-pause  U+F03E4
        "next":     "\udb81\udcad",   // md-skip_next  U+F04AD
        "previous": "\udb81\udcae",   // md-skip_previous  U+F04AE
        // --- navigation ----------------------------------------------
        "chevron-right": "\udb80\udd42",   // md-chevron_right  U+F0142
        "chevron-left":  "\udb80\udd41",   // md-chevron_left  U+F0141
        "chevron-down":  "\udb80\udd40",   // md-chevron_down  U+F0140
        "chevron-up":    "\udb80\udd43",   // md-chevron_up  U+F0143
        "close":         "\udb80\udd56",   // md-close  U+F0156
        "check":         "\udb80\udd2c",   // md-check  U+F012C
        "plus":          "\udb81\udc15",   // md-plus  U+F0415
        "minus":         "\udb80\udf74",   // md-minus  U+F0374
        "search":        "\udb80\udf49",   // md-magnify  U+F0349
        "refresh":       "\udb81\udc50",   // md-refresh  U+F0450
        // --- system --------------------------------------------------
        "settings":    "\udb81\udc93",   // md-cog  U+F0493
        "calendar":    "\udb83\ude17",   // md-calendar_month  U+F0E17
        "clock":       "\udb80\udd50",   // md-clock_outline  U+F0150
        "bell":        "\udb80\udc9a",   // md-bell  U+F009A
        "bell-off":    "\udb80\udc9b",   // md-bell_off  U+F009B
        "dnd":         "\udb80\udf76",   // md-minus_circle  U+F0376
        "palette":     "\udb80\udfd8",   // md-palette  U+F03D8
        "widgets":     "\udb81\udf2c",   // md-widgets  U+F072C
        "dock":        "\udb84\udca9",   // md-dock_bottom  U+F10A9
        "apps":        "\udb80\udc3b",   // md-apps  U+F003B
        "folder":      "\udb80\ude4b",   // md-folder  U+F024B
        "terminal":    "\udb80\udd8d",   // md-console  U+F018D
        "cpu":         "\udb83\udee0",   // md-cpu_64_bit  U+F0EE0
        "ram":         "\udb80\udf5b",   // md-memory  U+F035B
        "temperature": "\udb81\udd0f",   // md-thermometer  U+F050F
        "info":        "\udb80\udefd",   // md-information_outline  U+F02FD
        "visualizer":  "\udb80\udd28",   // md-chart_bar  U+F0128
        "cursor":      "\udb80\uddbf",   // md-cursor_default  U+F01BF
        "user":        "\udb80\udc04",   // md-account  U+F0004
        "shield":      "\udb81\udd65",   // md-shield_check  U+F0565
        "download":    "\udb80\uddda",   // md-download  U+F01DA
        "trash":       "\udb80\uddb4",   // md-delete  U+F01B4
        "pin":         "\udb81\udc03",   // md-pin  U+F0403
        // Added for the Command Center's KDE Connect commands. Resolved the
        // same way as everything above -- by looking the Material Design glyph
        // NAME up in the installed font, not by typing a codepoint.
        "send":        "\udb81\udc8a",   // md-send  U+F048A
        "file-send":   "\udb80\ude2a",   // md-file_send  U+F022A
        "link":        "\udb80\udf39",   // md-link_variant  U+F0339
        "keyboard":    "\udb80\udf0c",   // md-keyboard  U+F030C
        "share":       "\udb81\udc97",   // md-share_variant  U+F0497
        "paste":       "\udb80\udd92",   // md-content_paste  U+F0192
        "drag":        "\udb80\udddb",   // md-drag  U+F01DB
        "eye":         "\udb80\ude08",   // md-eye  U+F0208
        "eye-off":     "\udb80\ude09"   // md-eye_off  U+F0209
    })

    // A visible placeholder beats invisible tofu: a missing icon should look
    // wrong, not look like nothing.
    text: root.glyphs[root.name] !== undefined ? root.glyphs[root.name] : "\udb80\udd51"

    font.family: Appearance.fontMono
    font.pixelSize: root.size

    color: Theme.text

    // Nerd Font glyphs sit high in their box without this.
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 1.0

    // Fixed box so icons in a row align regardless of glyph width -- several
    // Nerd Font glyphs are double-width and would otherwise shift their labels.
    width: root.size * 1.25
    height: root.size * 1.25

    renderType: Text.NativeRendering
}
