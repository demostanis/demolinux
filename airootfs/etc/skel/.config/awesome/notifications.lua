naughty.connect_signal("request::display", function(n)
    naughty.layout.box {
        notification = n,
        widget_template = {
            require"naughty.widget._default",
            widget = wibox.container.place,
            valign = "center",
            halign = "center",
        }
    }
end)

-- TODO: if path := ... in pluto
local function lookup_icon(icon)
    return menubar.utils.lookup_icon(icon) or
        menubar.utils.lookup_icon(icon:lower())
end
naughty.connect_signal("request::icon", function(n, context, hints)
    local icon = hints.app_icon or n.app_name
    local path = menubar.utils.lookup_icon(icon) or
        menubar.utils.lookup_icon(icon:lower())
    if path then
        n.icon = path
    end
end)

-- vim:set et sw=4 ts=4:
