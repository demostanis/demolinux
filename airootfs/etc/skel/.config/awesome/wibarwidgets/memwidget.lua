local beautiful = require"beautiful"
local vicious = require"vicious"
local gears = require"gears"
local utils = require"utils"
local wibox = require"wibox"
local awful = require"awful"

local popup, textw = table.unpack(tpopup())
local mymemwidget = wibox.widget{
    text = "\u{f538}",
    widget = wibox.widget.textbox,
    font = beautiful.iconfont
}

mymemwidget:connect_signal("mouse::enter", function()
    local geo = mouse.current_widget_geometry
    if overview_shown or not geo then return end
    geo.y = geo.y + 7

    popup:move_next_to(geo)
    popup.visible = true

    mymemwidget.oldtext = mymemwidget.text
    mymemwidget.markup = "<span foreground='" .. beautiful.wibar_widget_hover_color .. "'>" .. mymemwidget.text .. "</span>"
end)
mymemwidget:connect_signal("mouse::leave", function()
    if not popup then return end
    popup.visible = false

    mymemwidget.markup = mymemwidget.oldtext
end)

vicious.register(textw, vicious.widgets.mem, "RAM: $2/$3MiB", 1)

return wibox.container.margin(mymemwidget, 2)

-- vim:set et sw=4 ts=4:
