
local popup, textw = table.unpack(tpopup())
local mycpuwidget = wibox.widget{
    text = "\u{f2db}",
    widget = wibox.widget.textbox,
    font = beautiful.base_icon_font .. " 9",
    halign = "center"
}

mycpuwidget:connect_signal("mouse::enter", function()
    local geo = mouse.current_widget_geometry
    if overview_shown or not geo then return end
    geo.y = geo.y + 7

    popup:move_next_to(geo)
    popup.visible = true

    mycpuwidget.oldtext = mycpuwidget.text
    mycpuwidget.markup = "<span foreground='" .. beautiful.wibar_widget_hover_color .. "'>" .. mycpuwidget.text .. "</span>"
end)
mycpuwidget:connect_signal("mouse::leave", function()
    if not popup then return end
    popup.visible = false

    mycpuwidget.markup = mycpuwidget.oldtext
end)

vicious.register(textw, vicious.widgets.cpu, "CPU: $1%", 1)

return mycpuwidget

-- vim:set et sw=4 ts=4:
