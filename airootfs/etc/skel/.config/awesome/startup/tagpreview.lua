local beautiful = require"beautiful"
local awful = require"awful"
local wibox = require"wibox"

bling.widget.tag_preview.enable {
    show_client_content = true,
    placement_fn = function(c)
        awful.placement.left(c, {
            margins = { left = 40 }
        })
    end
}

-- vim:set et sw=4 ts=4:
