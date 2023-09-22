require"lualine".setup{
    -- remove useless information
    sections = {lualine_x = {"filetype"}},
    options = {
	disabled_filetypes = {"NvimTree"}
    }
}
