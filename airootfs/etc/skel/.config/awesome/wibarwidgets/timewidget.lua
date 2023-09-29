local DateTime = glib.DateTime
local TimeZone = glib.TimeZone

local popup, textw = table.unpack(tpopup())
local timewidget = wibox.widget {
    {
        {
            widget = wibox.widget.textclock"%H:%M",
            font = beautiful.bold_font,
        },
        widget = wibox.container.place,
    },
    widget = wibox.container.background,
    id = "background"
}
timewidget:connect_signal("mouse::enter", function()
    local geo = mouse.current_widget_geometry
    if overview_shown or not geo then return end
    geo.x = geo.x + 8.5

    textw:set_markup(DateTime.new_now(TimeZone.new_local()):format"%c")
    popup:move_next_to(geo)
    popup.visible = true

    timewidget:get_children_by_id("background")[1].fg = beautiful.wibar_widget_hover_color
end)
timewidget:connect_signal("mouse::leave", function()
    if not popup then return end
    popup.visible = false

    timewidget:get_children_by_id("background")[1].fg = beautiful.fg_focus
end)

return timewidget

-- vim:set et sw=4 ts=4:
