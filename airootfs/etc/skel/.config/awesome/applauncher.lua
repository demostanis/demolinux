local app_whitelist = {
    "Firefox Web Browser",
    "urxvt", "Nemo", "Neovim",
    "scrcpy", "GNU Image Manipulation Program",
    "Stremio", "Transmission", "Tor Browser",
    "Ghidra",
}

return function()
    bling.widget.app_launcher{
        terminal = terminal.." -e",
        icon_theme = beautiful.icon_theme,
        whitelist = app_whitelist,
        app_shape = rrect(),
        apps_per_row = 2,
    }:toggle()
end

-- vim:set et sw=4 ts=4:
