local snippy = require"snippy"
local cmp = require"cmp"

cmp.setup{
    snippet = {
        expand = function(args)
            snippy.expand_snippet(args.body)
        end
    },

    mapping = cmp.mapping.preset.insert{
        ["<Tab>"] = cmp.mapping{
            i = function(fallback)
                if cmp.visible() then
                    cmp.select_next_item{behavior = cmp.SelectBehavior.Insert}
                elseif snippy.can_expand_or_advance() then
                    snippy.expand_or_advance()
                else
                    fallback()
                end
            end
        },
        ["<S-Tab>"] = cmp.mapping{
            i = function(fallback)
                if cmp.visible() then
                    cmp.select_prev_item{behavior = cmp.SelectBehavior.Insert}
                elseif snippy.can_jump(-1) then
                    snippy.previous()
                else
                    fallback()
                end
            end
        },
        ["<CR>"] = cmp.mapping{
            i = cmp.mapping.confirm()
        }
    },
    sources = cmp.config.sources{
        {name = "nvim_lsp"},
        {name = "nvim_lsp_signature_help"},
        {name = "snippy"}
    }
}

vim.diagnostic.disable()

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local c = vim.lsp.get_client_by_id(args.data.client_id)
        c.server_capabilities.semanticTokensProvider = nil
    end
})

local function enable_ls(name, settings)
    local capabilities = require"cmp_nvim_lsp".default_capabilities()
    require"lspconfig"[name].setup{
        capabilities = capabilities,
        settings = settings
    }
end
enable_ls("clangd")
enable_ls("lua_ls", {Lua = {
    completion = {callSnippet = "Replace"},
    workspace = {checkThirdParty = false}}})

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("LspConfig", {}),
    callback = function(event)
        local opts = { buffer = event.buf }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "Lr", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "La", vim.lsp.buf.code_action, opts)
    end
})

-- vim:set et sw=4 ts=4:
