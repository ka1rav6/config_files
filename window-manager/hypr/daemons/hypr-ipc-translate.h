// =============================================================================
// hypr-ipc-translate.h — the legacy-IPC-to-Lua rewrite, shared by two binaries.
// =============================================================================
// Hyprland 0.56 with a Lua config evaluates a legacy dispatch string as Lua:
// `dispatch workspace 2` arrives as `return hl.dispatch(workspace 2)` and dies
// at PARSE time, before anything can look at it. waybar's workspace buttons
// emit exactly those strings and they are hardcoded in the binary, so this
// rewrite is what makes clicking a workspace number work at all.
//
// WHY IT IS A HEADER AND NOT TWO COPIES
//   hypr-ipc-shim does the rewrite for waybar's click path, which has no
//   choice but to go through the shim. hypr-ipc-send does it only as a
//   fallback, for when the shim is not there -- which is a state this machine
//   has actually been in (see the launcher comment in waybar-ensure.sh). Two
//   separate implementations of the same four rewrites would drift, and the
//   one that drifted would be the rarely-exercised one, i.e. the one you only
//   find out about when the bar is already broken. One text, two includers.
//
// Header-only and `static`: each translation unit gets its own copy, there is
// nothing to link, and the Makefile needs no library target for ~100 lines.
// =============================================================================

#ifndef HYPR_IPC_TRANSLATE_H
#define HYPR_IPC_TRANSLATE_H

#include <ctype.h>
#include <stdio.h>
#include <string.h>

// The largest request either program will handle. waybar's longest is a
// workspace name, and a rewritten form is only a little longer than its
// input, so this is slack rather than a limit anyone meets.
#define REQ_MAX 8192

// ---------------------------------------------------------------------------

// Append `arg` as a Lua value: a bare number if it looks like one, a quoted
// and escaped string otherwise.
//
// The distinction matters. Workspace 2 and workspace "2" are not the same
// thing to Hyprland -- the first is an id, the second is a name -- so a
// numeric id must not be quoted, and "name:scratch" must be.
static int append_lua_value(char *out, size_t cap, size_t *o, const char *arg) {
    const char *p = arg;
    int numeric = (*p == '-' || *p == '+') ? (p++, 1) : 1;
    if (!*p) numeric = 0;
    for (const char *q = p; *q; q++)
        if (!isdigit((unsigned char)*q)) { numeric = 0; break; }

    if (numeric) {
        int n = snprintf(out + *o, cap - *o, "%s", arg);
        if (n < 0 || (size_t)n >= cap - *o) return -1;
        *o += (size_t)n;
        return 0;
    }

    if (*o + 2 >= cap) return -1;
    out[(*o)++] = '"';
    for (const char *q = arg; *q; q++) {
        if (*o + 3 >= cap) return -1;
        // A workspace name is user-chosen and reaches us straight from
        // waybar's config, so a quote or a backslash in it must not be able to
        // terminate the literal early -- that would turn a name into
        // attacker-chosen Lua running inside the compositor.
        if (*q == '"' || *q == '\\') out[(*o)++] = '\\';
        if ((unsigned char)*q < 0x20) continue;  // drop control characters
        out[(*o)++] = *q;
    }
    out[(*o)++] = '"';
    out[*o] = '\0';
    return 0;
}

// Rewrite one legacy request into its Lua equivalent.
//
// Returns 1 if it rewrote the request into `out`, 0 if the request should be
// forwarded unchanged. Only the four forms waybar actually emits are handled;
// anything else -- every `j/` query, and any dispatcher a future waybar might
// send -- passes through untouched rather than being guessed at.
static int translate(const char *req, size_t len, char *out, size_t cap,
                     int *changes_workspace) {
    static const char PFX[] = "dispatch ";
    const size_t plen = sizeof PFX - 1;

    if (changes_workspace) *changes_workspace = 0;
    if (len < plen || strncmp(req, PFX, plen) != 0) return 0;

    const char *cmd = req + plen;
    while (*cmd == ' ') cmd++;

    struct { const char *name; const char *lua_open; const char *lua_close; } map[] = {
        // Both focus forms become the same dispatcher. waybar only emits
        // focusworkspaceoncurrentmonitor when its `move-to-monitor` option is
        // on, and hl.dsp.focus already lands the workspace on the monitor the
        // pointer is over, which is the behaviour that option is asking for.
        {"workspace ",                       "hl.dsp.focus({ workspace = ", " })"},
        {"focusworkspaceoncurrentmonitor ",  "hl.dsp.focus({ workspace = ", " })"},
        {"togglespecialworkspace ",          "hl.dsp.workspace.toggle_special(", ")"},
    };

    for (size_t i = 0; i < sizeof map / sizeof map[0]; i++) {
        size_t nlen = strlen(map[i].name);
        if (strncmp(cmd, map[i].name, nlen) != 0) continue;

        const char *arg = cmd + nlen;
        while (*arg == ' ') arg++;

        char argbuf[512];
        snprintf(argbuf, sizeof argbuf, "%s", arg);
        // Trim anything trailing; waybar sends no newline, but a stray one
        // would end up inside the Lua string literal.
        for (char *e = argbuf + strlen(argbuf); e > argbuf; e--)
            if (isspace((unsigned char)e[-1])) e[-1] = '\0'; else break;

        size_t o = 0;
        int n = snprintf(out, cap, "%s%s", PFX, map[i].lua_open);
        if (n < 0 || (size_t)n >= cap) return 0;
        o = (size_t)n;

        if (append_lua_value(out, cap, &o, argbuf) < 0) return 0;

        n = snprintf(out + o, cap - o, "%s", map[i].lua_close);
        if (n < 0 || (size_t)n >= cap - o) return 0;
        // Only the two focus forms can land on another monitor. Toggling a
        // special workspace opens it on the monitor you are already on, so it
        // never needs the cursor to follow.
        if (changes_workspace && i < 2) *changes_workspace = 1;
        return 1;
    }

    // The no-argument special-workspace toggle, which waybar sends for the
    // unnamed special workspace.
    if (strcmp(cmd, "togglespecialworkspace") == 0) {
        snprintf(out, cap, "%shl.dsp.workspace.toggle_special()", PFX);
        return 1;
    }

    return 0;
}

#endif  // HYPR_IPC_TRANSLATE_H
