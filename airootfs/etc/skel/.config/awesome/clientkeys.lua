-- we have to do this special hack for firefox since
-- it can't correctly guess its geometry when switching
-- to fullscreen when my Xorg patches are active and that
-- we're using hardware acceleration, but i can't figure
-- out why...
function toggle_firefox_fullscreen(c)
    if c.fffakefullscreen then
        c.fffakefullscreen = false

        c.width = c.oldwidth
        c.height = c.oldheight

        c.screen.mywibar.visible = true
        c.screen.mydock.visible = true

        c.floating = falsee
        c.ontop = false

        awful.titlebar.show(c)
    else
        c.oldwidth = c.width
        c.oldheight = c.height

        c.fffakefullscreen = true

        c.screen.mywibar.visible = false
        c.screen.mydock.visible = false

        c.floating = true
        c.ontop = true

        c.x = 0
        -- hmmm where do these margins come from...
        c.y = dpi(-20)
        c.width = c.screen.geometry.width
        c.height = c.screen.geometry.height+dpi(20)

        awful.titlebar.hide(c)
    end
end

return gears.table.join(
    awful.key({ modkey }, "q", function(c) c:kill() end),
    awful.key({ modkey }, "o", function(c) c:move_to_screen() end),
    awful.key({ modkey }, "m", function(c) c.minimized = true end),
    awful.key({ modkey }, "w", function(c) layout.maximize(c) end),
    awful.key({ modkey, "Shift" }, "f", function(c)
        if c.class == "firefox" then
            toggle_firefox_fullscreen(c)
        else
            c.fullscreen = not c.fullscreen
        end
    end)
)

-- vim:set et sw=4 ts=4:
