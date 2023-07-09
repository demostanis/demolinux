local beautiful = require"beautiful"
local vicious = require"vicious"
local gears = require"gears"
local utils = require"utils"
local wibox = require"wibox"
local awful = require"awful"

local icons = {
    low = "\u{e0ca}",
    high = "\u{e0c9}",
}

local popup, textw = table.unpack(tpopup())
local mybrightnesswidget = wibox.widget{
    widget = wibox.widget.textbox,
    font = beautiful.iconfont,
    text = icons.high,
    halign = "center"
}

mybrightnesswidget:connect_signal("mouse::enter", function()
    local geo = mouse.current_widget_geometry
    if overview_shown or not geo then return end
    geo.x = geo.x + 3
    geo.y = geo.y + 7

    popup:move_next_to(geo)
    popup.visible = true

    mybrightnesswidget.oldtext = mybrightnesswidget.text
    mybrightnesswidget.markup = "<span foreground='" .. beautiful.wibar_widget_hover_color .. "'>" .. mybrightnesswidget.text .. "</span>"
end)
mybrightnesswidget:connect_signal("mouse::leave", function()
    if not popup then return end
    popup.visible = false

    mybrightnesswidget.markup = mybrightnesswidget.oldtext
end)

function handle(command)
    awful.spawn(command, false)
    vicious.force({mybrightnesswidget})
end

mybrightnesswidget:buttons(gears.table.join(
    awful.button({ }, 4, function()
        handle("brightnessctl s 5%+")
    end),
    awful.button({ }, 5, function()
        handle("brightnessctl s 5%-")
    end)
)) 

local brightness = { async = function(format, warg, callback)
    awful.spawn.easy_async("brightnessctl -P g", function(stdout, _, _, code)
        callback{ tonumber(stdout) }
    end)
end }

vicious.register(textw, brightness, function(widget, args)
    if args[1] >= 50 then
        mybrightnesswidget.text = icons.high
    else
        mybrightnesswidget.text = icons.low
    end
    return "Brightness: " .. args[1] .. "%"
end, 1)

-- check if there are any backlight devices
if os.execute("ls /sys/class/backlight/* >/dev/null 2>&1") then
    return mybrightnesswidget
end
return {_absent = true}

-- vim:set et sw=4 ts=4:
