local function maximizedbutton(c)
    local widget = awful.titlebar.widget.button(c, "maximized", function(cl)
        return cl.kinda_maximized or false
    end, function(cl, state)
        layout.maximize(cl)
    end)
    c:connect_signal("property::kinda_maximized", widget.update)
    return widget
end

return function(c)
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            if not c.floating then
                awful.mouse.client.move(c)
            end
        end),
        awful.button({ }, 2, function()
            return layout.maximize(c)
        end)
    )

    -- Same logic as in dock.lua
    local titlebar_button_with_hover_effect = function(widget)
        local button = widget:get_all_children()[1]
        local should_lighten = false
        local initial_draw = button.draw
        function button.draw(self, _, cr, ...)
            initial_draw(self, _, cr, ...)
            local color = beautiful.fg_normal
            if should_lighten and not overview_shown then
                color = beautiful.wibar_widget_hover_color
            end
            local s = self._private.image
            cr:set_source_rgba(gears.color.parse_color(color))
            cr:mask_surface(gears.surface(s), 0, 0)
            cr:fill()
        end
        widget:connect_signal("mouse::enter", function()
            should_lighten = true
            button:emit_signal(
                "widget::redraw_needed")
        end)
        widget:connect_signal("mouse::leave", function()
            should_lighten = false
            button:emit_signal(
                "widget::redraw_needed")
        end)
        return widget
    end

    awful.titlebar(c):setup{
        {
            {
                awful.titlebar.widget.iconwidget(c),
                layout  = wibox.layout.fixed.horizontal
            },
            widget = wibox.container.margin,
            margins = 4
        },
        {
            {
                widget = awful.titlebar.widget.titlewidget(c),
                font = beautiful.bold_font,
                align = "center",
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        {
            titlebar_button_with_hover_effect(wibox.widget{
                awful.titlebar.widget.minimizebutton(c),
                widget = wibox.container.margin,
            }),
            titlebar_button_with_hover_effect(wibox.widget{
                maximizedbutton(c),
                widget = wibox.container.margin,
            }),
            titlebar_button_with_hover_effect(wibox.widget{
                awful.titlebar.widget.closebutton(c),
                widget = wibox.container.margin,
            }),
            layout = wibox.layout.flex.horizontal,
            widget = wibox.container.place
        },
        layout = wibox.layout.align.horizontal
    }
end

-- vim:set et sw=4 ts=4:
