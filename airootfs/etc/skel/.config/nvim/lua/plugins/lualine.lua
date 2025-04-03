require"lualine".setup{
    -- remove useless information
    sections = {lualine_b = {}, lualine_x = {}},
    winbar = {
        lualine_c = {
            {
                "navic",
                color_correction = nil,
                navic_opts = nil
            },
            { "filename" }
        }
    },
    inactive_winbar = {
        lualine_c = {
            { "filename" }
        }
    },
    options = {
        disabled_filetypes = {
            winbar = {
                "fugitiveblame"
            }
        },
        always_show_tabline = true
    }
}
