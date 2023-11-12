require"telescope".setup{
    defaults = {
        mappings = {
            i = {
		-- enable CTRL-U to clear input
                ["<C-u>"] = false
            }
        }
    }
}

local telescope = require"telescope.builtin"
vim.keymap.set("n", "<leader>f", telescope.find_files)
vim.keymap.set("n", "<leader>g", telescope.live_grep)
vim.keymap.set("n", "<leader>b", telescope.buffers)
