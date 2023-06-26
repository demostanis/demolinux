local naughty = require"naughty"

local in_error = false
awesome.connect_signal("debug::error", function (err)
    if in_error then return end
    in_error = true

    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "O no! There was an error!!!!!!!!",
                     text = tostring(err) })
    in_error = false
end)
 
-- vim:set et sw=4 ts=4:
