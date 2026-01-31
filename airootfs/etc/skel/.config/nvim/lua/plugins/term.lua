local term = require"buffer-term"

term.setup{}

vim.keymap.set({ "n", "t" }, "<c-t>", function() term.toggle('a') end)
