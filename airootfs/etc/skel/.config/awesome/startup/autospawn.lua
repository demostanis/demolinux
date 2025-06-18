autospawn("copyq")

-- Flameshot needs its daemon to be
-- spawned in order to be able to copy
-- screenshots to the clipboard.
autospawn("flameshot")

autospawn("kdeconnectd")

--autospawn("keepassxc")

-- We need a small timeout because
-- Picom acts weird on first start.
gears.timer{
    timeout = 0.5,
    callback = function()
        autospawn("picom-wrapper")
    end,
    single_shot = true
}:start()

--autospawn("/usr/lib/xrandr.sh")

-- vim:set et sw=4 ts=4:
