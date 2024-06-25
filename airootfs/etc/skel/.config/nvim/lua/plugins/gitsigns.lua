local gitsigns = require"gitsigns"

gitsigns.setup{
	on_attach = function()
		local stage_selected_hunk = function()
			gitsigns.stage_hunk{
				vim.fn.line("."),
				vim.fn.line("v")
			}
		end

		local reset_selected_hunk = function()
			gitsigns.reset_hunk{
				vim.fn.line("."),
				vim.fn.line("v")
			}
		end

		vim.keymap.set("n", "H", function() end)
		vim.keymap.set("n", "Hs", gitsigns.stage_hunk)
		vim.keymap.set("n", "Hr", gitsigns.reset_hunk)
		vim.keymap.set("v", "Hs", stage_selected_hunk)
		vim.keymap.set("v", "Hr", reset_selected_hunk)
		vim.keymap.set("n", "HS", gitsigns.stage_buffer)
		vim.keymap.set("n", "Hu", gitsigns.undo_stage_hunk)
		vim.keymap.set("n", "HR", gitsigns.reset_buffer)
		vim.keymap.set("n", "Hp", gitsigns.preview_hunk)
		vim.keymap.set("n", "Hb", gitsigns.blame_line)
	end
}
