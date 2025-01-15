pcall(require, "luarocks.loader")

beautiful = require"beautiful"
cwd = debug.getinfo(1, "S").source:match("@(.*/)")
beautiful.init(cwd.."theme/theme.lua")

gears = require"gears"
awful = require"awful"
wibox = require"wibox"
naughty = require"naughty"
menubar = require"menubar"
vicious = require"vicious"
rubato = require"rubato"
bling = require"bling"
utils = require"utils"
cairo = require"lgi".cairo
glib = require"lgi".GLib
layout = require"layout"

terminal = "urxvt"
modkey = "Mod4"

require"awful.autofocus"
require"startup"
require"globalkeys"
require"notifications"

local c = 0
awful.screen.connect_for_each_screen(function(s)
    c = c + 1

    -- I swear I used beautiful.color0 to generate beautiful.wallpaper...
    -- Why is it not the same color??? Why do I have to hardcode this one??
    gears.wallpaper.centered(beautiful.wallpaper, s, "#1E0427", 0.1)

    awful.tag({ "1", "2", "3", "4", "5" }, s, layout.scroll)

    s.mywibar = require"wibar"(s)
    s.mydock = require"dock"(s)

    if c == screen.count() then
        -- Hide the boot splash when last screen is ready
        awful.spawn("/usr/lib/boot/finishboot", false)
    end
end)

client.connect_signal("manage", function(c)
    if not c.icon and not c.transient_for then
        -- default icon
        local icon = gears.surface(beautiful.default_icon)._native
        c.icon = icon
    end

    if c.transient_for then
        awful.placement.centered(c, {parent = c.transient_for})
        awful.placement.no_offscreen(c)
    end

    if c.class == "Kodi" then
        c.screen.mywibar.visible = false
        c.screen.mydock.visible = false
    end
    c:connect_signal("property::fullscreen", function()
        c.screen.mywibar.visible = not c.fullscreen
        c.screen.mydock.visible = not c.fullscreen
    end)
    c:connect_signal("unmanage", function()
        c.screen.mywibar.visible = true
        c.screen.mydock.visible = true
    end)
end)

function grabmouse(fn)
    return function(c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        mousegrabber.run(function()
            fn()
            return false
        end, "mouse")
    end
end

awful.rules.rules = {{
    rule = { },
    properties = {
        focus = awful.client.focus.filter,
        raise = true,
        keys = require"clientkeys",
        buttons = gears.table.join(
            require"windowcontrols",
            awful.button({ modkey }, 5, grabmouse(layout.move_left)),
            awful.button({ modkey }, 4, grabmouse(layout.move_right))
        ),
        screen = awful.screen.preferred,
        placement = awful.placement.no_overlap+awful.placement.no_offscreen,
        size_hints_honor = false
    }
},
{
    rule_any = {type = {"normal", "dialog"}},
    properties = {
        titlebars_enabled = true
    }
},
{
    rule = {class = "mpv"},
    properties = {
        keys = gears.table.join(
            require"clientkeys",
            -- due to X11 sandboxing, mpv cannot get
            -- fullscreen on its own
            awful.key({ nil }, "f", function(c)
                c.fullscreen = not c.fullscreen
            end)
        )
    }
},
{
    rule_any = {name = {"GIMP Startup"}, class = {"Iwdgui"}},
    properties = {
        placement = awful.placement.centered
    }
},
{
    rule_any = {class = {"deferedinstall"}},
    properties = {
        placement = awful.placement.centered
    }
}}

client.connect_signal("request::titlebars", function(c)
    require"titlebar"(c)
    require"tabs"(c)
end)

-- vim:set et sw=4 ts=4:
