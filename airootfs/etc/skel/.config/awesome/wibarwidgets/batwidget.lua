
local popup, textw = table.unpack(tpopup())
local mybatwidget = wibox.widget{
    text = "\u{f240}",
    widget = wibox.widget.textbox,
    font = beautiful.icon_font,
    halign = "center"
}

mybatwidget:connect_signal("mouse::enter", function()
    local geo = mouse.current_widget_geometry
    if overview_shown or not geo then return end
    geo.x = geo.x + 3
    geo.y = geo.y + 7

    popup:move_next_to(geo)
    popup.visible = true

    mybatwidget.oldtext = mybatwidget.text
    mybatwidget.markup = "<span foreground='" .. beautiful.wibar_widget_hover_color .. "'>" .. mybatwidget.text .. "</span>"
end)
mybatwidget:connect_signal("mouse::leave", function()
    if not popup then return end
    popup.visible = false

    mybatwidget.markup = mybatwidget.oldtext
end)

local icons = {
    "\u{f244}", -- empty
    "\u{e0b1}", -- low
    "\u{f243}", -- quarter
    "\u{f242}", -- half
    "\u{f241}", -- three quarters
    "\u{f240}"  -- full
}
vicious.register(textw, vicious.widgets.bat, function(widget, args)
    if args[1] == "+" then -- charging
        mybatwidget.text = "\u{f376}"
    else
        local ratio = 100 / #icons
        local icon = icons[math.ceil(args[2] / ratio)]
        if not icon then icon = icons[1] end
        mybatwidget.text = icon
    end
    return "Battery: " .. args[2] .. "%"
end, 1, "BAT0")

if vicious.call(vicious.widgets.bat, "$1", "BAT0") ~= "⌁" then -- unknown state
    return wibox.container.margin(mybatwidget, 0, 0, -2, 0)
end
return {_absent = true}

-- vim:set et sw=4 ts=4:
