return function(c)
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 2, function()
            c.maximized = not c.maximized
        end)
    )

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
                    awful.titlebar.widget.ontopbutton(c),
                    widget = wibox.container.margin,
                    right = 8,
                    top = 2
                },
                {
                    awful.titlebar.widget.maximizedbutton(c),
                    widget = wibox.container.margin,
                    top = 1,
                    bottom = 4,
                },
                {
                    awful.titlebar.widget.closebutton(c),
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
