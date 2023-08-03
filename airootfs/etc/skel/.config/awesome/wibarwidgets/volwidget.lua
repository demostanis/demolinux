local mixer = "Master"
local mutedicon = "\u{f6a9}"
local unmutedicon = "\u{f6a8}"

local hovering = false

function widgettext()
    if muted then
        return "Muted"
    else
        return "Volume: " .. percentage .. "%"
    end
end

local popup, textw = table.unpack(tpopup())
local myvolwidget = wibox.widget{
    text = mutedicon,
    widget = wibox.widget.textbox,
    font = beautiful.base_icon_font .. " 7",
    halign = "center"
}

function fmt(text)
    if hovering then
        return "<span foreground='" .. beautiful.wibar_widget_hover_color .. "'>" .. text .. "</span>"
    else
        return text
    end
end

function handle(command)
    awful.spawn(command, false)
    vicious.force({myvolwidget})
end

myvolwidget:buttons(gears.table.join(
    awful.button({ }, 3, function()
        handle("amixer -q sset " .. mixer .. " toggle", false)
    end),
    awful.button({ }, 4, function()
        handle("amixer -q sset " .. mixer .. " 3%+", false)
    end),
    awful.button({ }, 5, function()
        handle("amixer -q sset " .. mixer .. " 3%-", false)
    end)
)) 

myvolwidget:connect_signal("mouse::enter", function()
    local geo = mouse.current_widget_geometry
    if overview_shown or not percentage or not geo then return end
    geo.y = geo.y + 7

    popup:move_next_to(geo)
    popup.visible = true

    hovering = true
    myvolwidget.markup = fmt(myvolwidget.text)
end)
myvolwidget:connect_signal("mouse::leave", function()
    if not popup then return end
    popup.visible = false

    hovering = false
    myvolwidget.markup = fmt(myvolwidget.text)
end)

local mycontainer = wibox.container.margin(myvolwidget, 1)

vicious.cache(vicious.widgets.volume)
vicious.register(myvolwidget,
    vicious.widgets.volume,
    function(widget, args)
        percentage = args[1]
        muted = args[2] == "🔈" or percentage == 0
        if textw then textw.text = widgettext() end
        if muted then
            mycontainer.left = 1
            return fmt(mutedicon)
        else
            mycontainer.left = -0.5
            return fmt(unmutedicon)
        end
    end, 1, {mixer, "-D", "pulse"})

return mycontainer

-- vim:set et sw=4 ts=4:
