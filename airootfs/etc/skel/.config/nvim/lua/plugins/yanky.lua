require"yanky".setup{}

local telescope = require"telescope"
telescope.load_extension"yank_history"

vim.keymap.set("n", "<leader>y", telescope.extensions.yank_history.yank_history)
