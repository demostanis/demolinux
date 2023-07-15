local DateTime = glib.DateTime
local TimeZone = glib.TimeZone

local popup, textw = table.unpack(tpopup())
local timewidget = wibox.widget {
    {
        wibox.widget.textclock"%H",
        wibox.widget.textclock"%M",
        layout = wibox.layout.fixed.vertical
    },
    widget = wibox.container.background,
    id = "background"
}
timewidget:connect_signal("mouse::enter", function()
    local geo = wgeometry(timewidget)
    if overview_shown or not geo then return end

    textw:set_markup(DateTime.new_now(TimeZone.new_local()):format"%c")
    popup.x = geo.x + geo.width + 15
    popup.y = geo.y + geo.height / 4
    popup.visible = true

    timewidget:get_children_by_id("background")[1].fg = beautiful.wibar_widget_hover_color
end)
timewidget:connect_signal("mouse::leave", function()
    if not popup then return end
    popup.visible = false

    timewidget:get_children_by_id("background")[1].fg = beautiful.fg_focus
end)

return wibox.container.margin(timewidget, 6.5, 6.5)

-- vim:set et sw=4 ts=4:
