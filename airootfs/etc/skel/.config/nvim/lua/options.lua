vim.cmd.colorscheme"base16-demolinux"
vim.o.mousemodel = "extend"
vim.g.mapleader = " "
vim.o.number = true
vim.o.relativenumber = true
vim.o.updatetime = 100
vim.o.signcolumn = "yes"
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.undofile = true
vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "*",
    callback = function()
        vim.o.relativenumber = false
        vim.o.signcolumn = "no"
    end
})
vim.o.sol = false
