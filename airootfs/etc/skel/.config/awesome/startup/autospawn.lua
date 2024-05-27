autospawn("clipster -d")
-- Flameshot needs its daemon to be
-- spawned in order to be able to copy
-- screenshots to the clipboard.
autospawn("flameshot")

autospawn("/usr/lib/kdeconnectd")

-- We need a small timeout because
-- Picom acts weird on first start.
gears.timer{
    timeout = 2,
    callback = function()
        autospawn("picom-wrapper")
    end,
    single_shot = true
}:start()

autospawn("pgrep notifitor || notifitor")

--autospawn("/usr/lib/xrandr.sh")

-- vim:set et sw=4 ts=4:
