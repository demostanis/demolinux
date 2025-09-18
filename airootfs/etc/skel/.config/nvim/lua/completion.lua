local snippy = require"snippy"
local cmp = require"cmp"

cmp.setup{
    -- workaround for gopls: https://github.com/hrsh7th/nvim-cmp/issues/1809
    preselect = cmp.PreselectMode.None,

    snippet = {
        expand = function(args)
            snippy.expand_snippet(args.body)
        end
    },

    mapping = {
        ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_next_item{behavior = cmp.SelectBehavior.Insert}
            elseif snippy.can_expand_or_advance() then
                snippy.expand_or_advance()
            else
                fallback()
            end
        end, {"i", "s"}),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_prev_item{behavior = cmp.SelectBehavior.Insert}
            elseif snippy.can_jump(-1) then
                snippy.previous()
            else
                fallback()
            end
        end, {"i", "s"}),
        ["<CR>"] = cmp.mapping(cmp.mapping.confirm(), {"i", "s"})
    },
    sources = cmp.config.sources{
        {name = "nvim_lsp"},
        {name = "nvim_lsp_signature_help"},
        {name = "snippy"}
    }
}

vim.diagnostic.enable(false)

local function enable_ls(name, settings)
    local capabilities = require"cmp_nvim_lsp".default_capabilities()
    vim.lsp.config[name] = {
        capabilities = capabilities,
        settings = settings,
    }
    vim.lsp.enable(name)
end
enable_ls("clangd")
enable_ls("lua_ls", {Lua = {
    completion = {callSnippet = "Replace"},
    workspace = {checkThirdParty = false}}})
enable_ls("gopls")
enable_ls("denols")

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("LspConfig", {}),
    callback = function(event)
        local opts = { buffer = event.buf }

        local function definition(args)
            vim.g.is_going_to_definition = 1
            vim.lsp.buf.definition(args)
            vim.g.is_going_to_definition = 0
        end
        vim.keymap.set("n", "gd", definition, opts)
        vim.keymap.set("n", "gD", function(args)
            vim.cmd"tab split"
            definition(args)
        end, opts)

        vim.keymap.set("n", "gr", function(args)
            vim.lsp.buf.references(args, {
                on_list = function(options)
                    vim.fn.setqflist({}, " ", options)
                    vim.cmd.Trouble"quickfix"
                end
            })
        end, opts)

        vim.keymap.set("n", "K", function()
            if vim.o.ft ~= "c" then
                vim.lsp.buf.hover()
            else
                -- C should open man pages
                local _, err = pcall(function() vim.cmd "norm! K" end)
                if err then vim.lsp.buf.hover() end
            end
        end, opts)

        vim.keymap.set("n", "L", function() end)
        vim.keymap.set("n", "Lr", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "La", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "Lf", vim.lsp.buf.format, opts)

        local c = vim.lsp.get_client_by_id(event.data.client_id)
        c.server_capabilities.semanticTokensProvider = nil
    end
})

-- vim:set et sw=4 ts=4:
