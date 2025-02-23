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
tabs = require"tabs"

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

    s:connect_signal("arrange", function(s)
        for _, client in ipairs(s.clients) do
            if client.floating then
                awful.placement.centered(client, {parent = client.transient_for})
            end
        end
    end)

    if c == screen.count() then
        -- Hide the boot splash when last screen is ready
        awful.spawn("/usr/lib/boot/finishboot", false)
        print("awesomeWM started!")
    end
end)

client.connect_signal("manage", function(c)
    if not c.icon and not c.transient_for then
        -- default icon
        local icon = gears.surface(beautiful.default_icon)._native
        c.icon = icon
    end

    if c.transient_for or awful.rules.match_any(c, beautiful.standalone_floating_windows) then
        awful.placement.centered(c, {parent = c.transient_for})
        awful.placement.no_offscreen(c)
        c.ontop = true
    else
        c.floating = false
    end

    c:connect_signal("property::fullscreen", function()
        c.screen.mywibar.visible = not c.fullscreen
        c.screen.mydock.visible = not c.fullscreen
    end)
    c:connect_signal("unmanage", function()
        c.screen.mywibar.visible = true
        c.screen.mydock.visible = true
    end)

    if tabs.wants_tabs(c) then
        c.keys = gears.table.join(
            require"clientkeys",
            awful.key({ "Control" }, "Tab", function()
                tabs.switch_to_next_tab(c)
            end)
        )
    end
end)

awful.rules.rules = {{
    rule = { },
    properties = {
        focus = awful.client.focus.filter,
        raise = true,
        keys = require"clientkeys",
        buttons = require"windowcontrols",
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
    rule_any = {class = {"mpv"}, name = {"Picture-in-Picture"}},
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
    rule_any = beautiful.standalone_floating_windows,
    properties = {
        placement = awful.placement.centered,
        floating = true
     }
}}

client.connect_signal("request::titlebars", function(c)
    require"titlebar"(c)
    tabs.show_tabs_on_client(c)
end)

-- vim:set et sw=4 ts=4:
