return function(s)
    local mywibar = wibox {
        screen = s,
        y = dpi(4), x = dpi(4),
        ontop = false,
        visible = false,
        bg = beautiful.bg_focus,
        width = s.geometry.width-dpi(8),
        height = beautiful.wibar_height,
    }
    mywibar:struts{
        top = beautiful.wibar_height+dpi(10), right = dpi(5),
        bottom = beautiful.dock_width+dpi(10),
        left = dpi(5)
    }
    mywibar:set_xproperty("WM_NAME", "picom_fade_in")

    local mycpuwidget = optional"wibarwidgets/cpuwidget"
    local mymemwidget = optional"wibarwidgets/memwidget"
    local mybrightnesswidget = optional"wibarwidgets/brightnesswidget"
    local myvolwidget = optional"wibarwidgets/volwidget"
    local mybatwidget = optional"wibarwidgets/batwidget"
    local mytimewidget = optional"wibarwidgets/timewidget"
    local mywindowpreviews = require"windowpreviews"(s)

    local function marginify(w)
        if w == nil then return nil end
        return wibox.widget{
            w,
            margins = dpi(-8),
            widget = wibox.container.margin
        }
    end
    mywibar:setup {
        {
            require"panel"(s),
            {
                mywindowpreviews,
                top = 4,
                bottom = 4,
                left = 10,
                right = 10,
                widget = wibox.container.margin,
            },
            {
                {
                    {
                        {
                            marginify(mymemwidget),
                            marginify(mycpuwidget),
                            marginify(mybrightnesswidget),
                            marginify(myvolwidget),
                            marginify(mybatwidget),
                            spacing = dpi(18),
                            layout = wibox.layout.flex.horizontal,
                        },
                        widget = wibox.container.margin,
                        right = dpi(20)
                    },
                    mytimewidget,
                    layout = wibox.layout.fixed.horizontal
                },
                right = dpi(10),
                widget = wibox.container.margin
            },
            layout = wibox.layout.align.horizontal,
            expand = "inside"
        },
        widget = wibox.container.background,
        shape = rrect(),
    }

    return mywibar
end

-- vim:set et sw=4 ts=4:
