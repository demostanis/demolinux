return function(s)
    local mywibar = wibox {
        screen = s,
        y = 4, x = 4,
        ontop = false,
        visible = false,
        bg = beautiful.bg_focus,
        width = s.geometry.width-8,
        height = beautiful.wibar_height,
    }
    mywibar:struts{
        top = beautiful.wibar_height+10, right = 5,
        bottom = beautiful.dock_width+10,
        left = 5
    }
    mywibar:set_xproperty("WM_NAME", "picom_fade_in")

    local mycpuwidget = optional"wibarwidgets/cpuwidget"
    local mymemwidget = optional"wibarwidgets/memwidget"
    local mybrightnesswidget = optional"wibarwidgets/brightnesswidget"
    local myvolwidget = optional"wibarwidgets/volwidget"
    local mybatwidget = optional"wibarwidgets/batwidget"
    local mytimewidget = optional"wibarwidgets/timewidget"

    local function marginify(w)
        if w == nil then return nil end
        return wibox.widget{
            w,
            margins = -8,
            widget = wibox.container.margin
        }
    end
    mywibar:setup {
        {
            require"panel"(s),
            nil,
            {
                {
                    {
                        {
                            marginify(mymemwidget),
                            marginify(mycpuwidget),
                            marginify(mybrightnesswidget),
                            marginify(myvolwidget),
                            marginify(mybatwidget),
                            spacing = 18,
                            layout = wibox.layout.flex.horizontal,
                        },
                        widget = wibox.container.margin,
                        right = 20
                    },
                    mytimewidget,
                    layout = wibox.layout.fixed.horizontal
                },
                right = 10,
                widget = wibox.container.margin
            },
            layout = wibox.layout.align.horizontal,
            expand = "none"
        },
        widget = wibox.container.background,
        shape = rrect(),
    }

    return mywibar
end

-- vim:set et sw=4 ts=4:
