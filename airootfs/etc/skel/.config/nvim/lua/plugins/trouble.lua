require"trouble".setup{
	auto_close = true
}
vim.keymap.set("n", "<leader>T", ":Trouble diagnostics<CR>")
