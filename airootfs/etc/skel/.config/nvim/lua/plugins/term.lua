local term = require"buffer-term"

term.setup{}

vim.keymap.set({ "n", "t" }, "<c-t>", function()
	if vim.api.nvim_buf_get_name(0) == "" and
		not vim.api.nvim_buf_get_option(0, "modified") then
		-- buffer-term has a bug when the current buffer's name is empty,
		-- we have to toggle it twice...
		term.toggle('a')
	end
	term.toggle('a')
end)
