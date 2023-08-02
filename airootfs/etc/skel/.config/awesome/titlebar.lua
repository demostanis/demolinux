return function(c)
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 2, function()
            c.maximized = not c.maximized
        end)
    )

    -- Same logic as in dock.lua
    local titlebar_button_with_hover_effect = function(button)
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
        button:connect_signal("mouse::enter", function()
            should_lighten = true
            button:emit_signal(
                "widget::redraw_needed")
        end)
        button:connect_signal("mouse::leave", function()
            should_lighten = false
            button:emit_signal(
                "widget::redraw_needed")
        end)
        return button
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
            {
                -- a bunch of random margins because these images' size suck...
                {
                    titlebar_button_with_hover_effect(awful.titlebar.widget.ontopbutton(c)),
                    widget = wibox.container.margin,
                    right = 7,
                    top = 2
                },
                {
                    titlebar_button_with_hover_effect(awful.titlebar.widget.maximizedbutton(c)),
                    widget = wibox.container.margin,
                    top = 1,
                    bottom = 4,
                },
                {
                    titlebar_button_with_hover_effect(awful.titlebar.widget.closebutton(c)),
                    widget = wibox.container.margin,
                    bottom = 2.5
                },
                layout = wibox.layout.flex.horizontal,
            },
            widget = wibox.container.margin,
            top = 6,
        },
        layout = wibox.layout.align.horizontal
    }
end

-- vim:set et sw=4 ts=4:
