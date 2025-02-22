require"aerial".setup{
	autojump = true,
	highlight_on_hover = true,
	keymaps = {
		["<esc>"] = { callback = function()
			vim.cmd"AerialClose"
			vim.cmd"norm `O"
		end },
		["<CR>"] = { callback = function()
			require"aerial.actions".jump.callback()
			vim.cmd"norm mO"
		end }
	}
}
vim.keymap.set("n", "Lo", function()
	vim.cmd"norm mO" -- mark
	vim.cmd"AerialOpen"
end)
