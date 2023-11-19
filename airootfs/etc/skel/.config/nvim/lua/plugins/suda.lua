vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("my_suda_smart_edit", {}),
	pattern = "*",
	nested = true,
	callback = function()
		if not vim.g.is_going_to_definition then
			vim.fn["suda#BufEnter"]()
		end
	end
})
