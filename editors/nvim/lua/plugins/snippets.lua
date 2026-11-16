return {
    {
        "saghen/blink.cmp",
        opts = function()
            -- blink resolves `$NAME` in a snippet body from this table, so one
            -- entry here keeps the include-guard snippet plain JSON. VSCode-style
            -- transforms (`${TM_FILENAME/.../upcase}`) are not supported by
            -- blink's expander, which is why the uppercasing happens in Lua.
            require("blink.cmp.sources.snippets.default.builtin").lazy.HEADER_GUARD = function()
                return (vim.fn.expand("%:t"):upper():gsub("[^%w]", "_"))
            end
        end,
    },
}
