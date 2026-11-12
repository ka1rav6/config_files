-- Java. lazyvim.plugins.extras.lang.java (enabled in lazyvim.json) already gives
-- jdtls, the extract refactors under <leader>cx* and a DAP-based test runner.
-- This file only adds what it leaves out: the codegen actions, <leader>j* keys
-- and the IntelliJ-style `_get`/`_tos`/... insert-mode triggers.

-- jdtls ships codegen as code actions. Getters and setters share one kind
-- (source.generate.accessors), so the title is the only discriminator; match on
-- titles throughout and let `apply` fire straight away when exactly one hits.
local function action(filter)
    return function()
        vim.lsp.buf.code_action({ apply = true, filter = filter })
    end
end

local gen = {
    getters = action(function(a)
        return a.title:find("^Generate Getters") and not a.title:find("Setters")
    end),
    setters = action(function(a)
        return a.title:find("^Generate Setters") ~= nil
    end),
    tostring = action(function(a)
        return a.title:find("^Generate toString") ~= nil
    end),
    constructors = action(function(a)
        return a.title:find("^Generate Constructors") ~= nil
    end),
    -- "Add unimplemented methods" stubs every missing method in one go, but it
    -- is the quickfix on the "must implement the inherited abstract method"
    -- diagnostic, so it only exists while the cursor is on the class line.
    -- Elsewhere this lands on the pick-what-to-override prompt instead.
    implement = action(function(a)
        return a.title:find("^Add unimplemented methods") or a.title:find("^Override/Implement Methods")
    end),
}

local triggers = {
    _get = gen.getters,
    _set = gen.setters,
    _tos = gen.tostring,
    _cons = gen.constructors,
    _test = function()
        require("jdtls.tests").generate()
    end,
}

-- Abbreviations fire on the character typed *after* the word, and the callback
-- runs under textlock, so defer: by then the line holds only the leftover
-- whitespace and we are free to open a prompt.
local function on_trigger(fn)
    return function()
        vim.schedule(function()
            if vim.api.nvim_get_current_line():match("^%s*$") then
                vim.api.nvim_set_current_line("")
            end
            vim.cmd.stopinsert()
            fn()
        end)
    end
end

-- <CR> is the natural key here, but Neovim does not expand abbreviations for
-- keys that arrive through a mapping and blink owns <CR>, so the abbreviation
-- never fires on Enter. Do the expansion by hand instead.
local function expand_trigger()
    if vim.bo.filetype ~= "java" then
        return
    end
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local line = vim.api.nvim_get_current_line()
    local word = line:sub(1, col):match("[%w_]+$")
    local fn = word and triggers[word]
    if not fn then
        return
    end
    vim.api.nvim_set_current_line(line:sub(1, col - #word) .. line:sub(col + 1))
    on_trigger(fn)()
    return true
end

-- nvim-jdtls' test runner and test generation both come from the java-test
-- bundles, which the java extra only loads when nvim-dap is installed; the
-- dap.core extra is enabled in lazyvim.json, which is where LazyVim wants its
-- imports to happen (before this file, not from inside it).
return {
    {
        "saghen/blink.cmp",
        opts = {
            -- LazyVim's "enter" preset already binds <CR>; this replaces that
            -- entry, so it has to carry accept/fallback itself.
            keymap = { ["<CR>"] = { expand_trigger, "accept", "fallback" } },
            completion = {
                menu = {
                    -- The triggers above are abbreviations, not completions.
                    -- Left alone blink fuzzy-matches them (`_tos` reaches
                    -- `try_resources`) and <CR> then accepts that item instead
                    -- of letting the abbreviation expand. Hide the menu only
                    -- while the word under the cursor is exactly a trigger.
                    auto_show = function(ctx)
                        if vim.bo.filetype ~= "java" then
                            return true
                        end
                        local word = ctx.line:sub(1, ctx.cursor[2]):match("[%w_]+$")
                        return not (word and triggers[word])
                    end,
                },
            },
        },
    },

    {
        "mfussenegger/nvim-jdtls",
        opts = function(_, opts)
            -- DSA/scratch files sit in a plain directory with no pom.xml. Without
            -- a fallback root_dir is nil and jdtls spins up a throwaway workspace
            -- for every single file.
            local root_dir = opts.root_dir
            opts.root_dir = function(path)
                return root_dir(path) or vim.fs.dirname(path)
            end

            opts.jdtls = function(config)
                -- Required for the generate-constructors / toString / override
                -- prompts; without it the server does not offer them.
                config.init_options.extendedClientCapabilities = require("jdtls").extendedClientCapabilities
                return config
            end

            opts.settings = vim.tbl_deep_extend("force", opts.settings or {}, {
                java = {
                    -- The "autoimport" half that completion does not cover: pasted
                    -- or hand-typed code gets its imports added (and unused ones
                    -- dropped) on every write.
                    saveActions = { organizeImports = true },
                    sources = {
                        organizeImports = {
                            -- Low thresholds so a hand-written `import java.util.*;`
                            -- survives the save action instead of being expanded.
                            starThreshold = 5,
                            staticStarThreshold = 3,
                        },
                    },
                    completion = {
                        importOrder = { "java", "javax", "jakarta", "org", "com" },
                        -- Otherwise `List` offers java.awt.List and Spring code
                        -- drowns in shaded/internal classes.
                        filteredTypes = {
                            "java.awt.*",
                            "javax.swing.*",
                            "com.sun.*",
                            "sun.*",
                            "jdk.*",
                            "io.micrometer.shaded.*",
                        },
                        favoriteStaticMembers = {
                            "org.junit.jupiter.api.Assertions.*",
                            "org.junit.jupiter.api.Assumptions.*",
                            "org.mockito.Mockito.*",
                            "org.mockito.ArgumentMatchers.*",
                            "org.assertj.core.api.Assertions.*",
                            "java.util.Objects.requireNonNull",
                            "java.util.Comparator.*",
                            "java.util.stream.Collectors.*",
                            "java.util.Arrays.*",
                        },
                    },
                    -- Picks up pom.xml / build.gradle edits without a prompt, which
                    -- is most of Spring Boot work.
                    configuration = { updateBuildConfiguration = "automatic" },
                },
            })

            opts.on_attach = function(args)
                local buf = args.buf
                local jdtls = require("jdtls")
                local function map(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
                end

                require("which-key").add({ { "<leader>j", group = "java", buffer = buf } })

                map("n", "<leader>jo", jdtls.organize_imports, "Organize Imports")
                map("n", "<leader>jv", jdtls.extract_variable_all, "Extract Variable")
                map("n", "<leader>jc", jdtls.extract_constant, "Extract Constant")
                map("n", "<leader>jm", jdtls.extract_method, "Extract Method")
                map("x", "<leader>jv", function()
                    jdtls.extract_variable_all(true)
                end, "Extract Variable")
                map("x", "<leader>jc", function()
                    jdtls.extract_constant(true)
                end, "Extract Constant")
                map("x", "<leader>jm", function()
                    jdtls.extract_method(true)
                end, "Extract Method")
                map("n", "<leader>jt", function()
                    require("jdtls.dap").test_nearest_method()
                end, "Test Nearest Method")
                map("n", "<leader>jT", function()
                    require("jdtls.dap").test_class()
                end, "Test Class")
                map("n", "<leader>ji", gen.implement, "Implement Inherited Methods")

                for lhs, fn in pairs(triggers) do
                    vim.keymap.set("ia", lhs, "", { buffer = buf, callback = on_trigger(fn) })
                end
            end
        end,
    },
}
