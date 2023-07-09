return function(s)
    local mywibar = wibox {
        screen = s,
        y = 4, x = 4,
        ontop = true,
        visible = true,
        bg = beautiful.bg_focus,
        width = beautiful.wibar_width-6,
        height = s.geometry.height-8,
    }
    mywibar:struts{
        top = 10, right = 10,
        bottom = beautiful.dock_width+10,
        left = beautiful.wibar_width+5,
    }

    local myvolwidget = optional"wibarwidgets/volwidget"
    local mycpuwidget = optional"wibarwidgets/cpuwidget"
    local mymemwidget = optional"wibarwidgets/memwidget"
    local mybatwidget = optional"wibarwidgets/batwidget"
    local mytimewidget = optional"wibarwidgets/timewidget"

    mywibar:setup {
        {
            nil,
            require"taglist"(s),
            {
                {
                    {
                        {
                            mymemwidget,
                            mycpuwidget,
                            mybatwidget,
                            myvolwidget,
                            widget = wibox.container.margin,
                            left = -2,
                            layout = wibox.layout.flex.vertical,
                            spacing = 5
                        },
                        bottom = 8,
                        widget = wibox.container.margin,
                    },
                    mytimewidget,
                    layout = wibox.layout.fixed.vertical
                },
                bottom = 3.5,
                widget = wibox.container.margin
            },
            layout = wibox.layout.align.vertical,
            expand = "none"
        },
        widget = wibox.container.background,
        shape = rrect(),
    }
    fade_on_overview(mywibar)

    return mywibar
end

-- vim:set et sw=4 ts=4:
