return gears.table.join(
    awful.key({ modkey }, "q", function(c) c:kill() end),
    awful.key({ modkey }, "o", function(c) c:move_to_screen() end),
    awful.key({ modkey }, "m", function(c) c.minimized = true end),
    awful.key({ modkey }, "f", function(c)
        c.maximized = not c.maximized
        c:raise()
    end)
)
