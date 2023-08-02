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

local capabilities = require"cmp_nvim_lsp".default_capabilities()
require"lspconfig".clangd.setup{
    capabilities = capabilities
}
-- vim:set et sw=4 ts=4:
