local tasklist_buttons = gears.table.join(
    awful.button({ }, 1, function (c)
        if overview_shown then return end
        c = (c.master and c.master.active_slave) or c
        c:emit_signal(
            "request::activate",
            "tasklist",
            {raise = true}
        )
    end),
    awful.button({ }, 2, function (c)
        if overview_shown then return end
        c:kill()
    end)
)

local iconpath = "/usr/share/icons/"..beautiful.icon_theme.."/apps/scalable/"

local function makelauncher(app)
    local mylauncher = wibox.widget {
        {
            {
                image = iconpath .. app .. ".svg",
                widget = wibox.widget.imagebox,
                forced_width = 28,
                forced_height = 28
            },
            widget = wibox.container.margin,
            margins = 10,
        },
        bg = beautiful.bg_focus,
        widget = wibox.container.background,
        forced_width = 48,
        forced_height = 48,
    }
    mylauncher:connect_signal("button::press", function()
        if overview_shown then return end
        awful.spawn(app)
    end)
    return mylauncher
end

local mylaunchers = wibox.widget {
    makelauncher("nemo"),
    makelauncher("urxvt"),
    makelauncher("firefox"),
    layout = wibox.layout.fixed.horizontal,
}

return function(s)
    local mytasklist = awful.widget.tasklist {
        screen = s,
        filter = function(c, s)
            if c.is_tab then return false end
            return awful.widget.tasklist.filter.currenttags(c, s)
        end,
        widget_template = {
            {
                {
                    {
                        id = "icon",
                        widget = awful.widget.clienticon,
                        forced_width = 28,
                        forced_height = 28
                    },
                    widget = wibox.container.margin,
                    margins = 10,
                },
                {
                    {
                        wibox.widget.base.make_widget(),
                        {
                            wibox.widget.base.make_widget(),
                            widget = wibox.container.background,
                            bg = beautiful.color7,
                            forced_height = 1,
                            id = "indicator"
                        },
                        wibox.widget.base.make_widget(),
                        layout = wibox.layout.flex.horizontal
                    },
                    widget = wibox.container.margin,
                    left = 3 
                },
                widget = wibox.container.background,
                layout = wibox.layout.fixed.vertical,
            },
            bg = beautiful.bg_focus,
            widget = wibox.container.background,
            forced_width = 48,
            forced_height = 48,
            update_callback = function(self, c)
                local indicator = self:get_children_by_id("indicator")[1]

                pos = 6
                target = 2
                if c == client.focus or (c.master and c.master.active_slave == client.focus) then
                    pos = 2
                    target = 6
                end

                if indicator.lastpos == pos then return end
                indicator.lastpos = pos

                rubato.timed{
                    duration = 0.3,
                    easing = rubato.easing.zero,
                    pos = pos,
                    subscribed = function(w)
                        indicator.shape = function(cr)
                            cr:rectangle(6-w, 0, w*2, indicator.forced_height)
                        end
                    end
                }.target = target
            end,
            create_callback = function(self, c)
                self:get_children_by_id("icon")[1].client = c
                self:update_callback(c)
            end
        },
        buttons = tasklist_buttons,
        update_function = function(w, b, l, d, clients, a)
            local n = #clients+#mylaunchers:get_children()
            local bs = 48
            s.mydock.width = bs*n
            s.mydock.x = s.geometry.width/2-bs*n/2

            awful.widget.common.list_update(w, b, l, d, clients, a)
        end,
    }

    local mydock = wibox {
        y = s.geometry.height-beautiful.dock_width-4,
        ontop = true, visible = true,
        height = beautiful.dock_width,
        screen = s,
    }
    mydock:setup{
        mylaunchers,
        mytasklist,
        layout = wibox.layout.fixed.horizontal,
        widget = wibox.container.background,
        shape = rrect(),
    }
    fade_on_overview(mydock)

    return mydock
end
 
-- vim:set et sw=4 ts=4:
