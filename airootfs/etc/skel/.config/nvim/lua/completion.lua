local snippy = require"snippy"
local cmp = require"cmp"

cmp.setup{
    snippet = {
        expand = function(args)
            snippy.expand_snippet(args.body)
        end
    },

    mapping = {
        ["<Tab>"] = cmp.mapping(function(fallback)
            i = 0
            while true do
                if vim.fn.col('.')-i == 1 then break end
                local hi = vim.fn.synstack(vim.fn.line('.'), vim.fn.col('.')-i)
                if #hi ~= 0 then
                    local found = false
                    for j=1,#hi do
                        if vim.fn.synIDattr(hi[j], "name") == "cType" then
                            found = true
                        end
                    end
                    if found then
                        fallback()
                        return
                    end
                end
                i = i + 1
            end

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

vim.diagnostic.disable()

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
enable_ls("gopls")

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("LspConfig", {}),
    callback = function(event)
        local opts = { buffer = event.buf }
        vim.keymap.set("n", "gd", function(args)
            vim.g.is_going_to_definition = 1
            vim.lsp.buf.definition(args)
            vim.g.is_going_to_definition = 0
        end, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gr", function(args)
            vim.lsp.buf.references(args, {
                on_list = function(options)
                    vim.fn.setqflist({}, " ", options)
                    vim.cmd.Trouble"quickfix"
                end
            })
        end, opts)
        vim.keymap.set("n", "Lr", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "La", vim.lsp.buf.code_action, opts)

        local c = vim.lsp.get_client_by_id(event.data.client_id)
        c.server_capabilities.semanticTokensProvider = nil
    end
})

-- vim:set et sw=4 ts=4:
