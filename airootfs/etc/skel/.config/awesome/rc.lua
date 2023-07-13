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

require"awful.autofocus"
require"startup"

terminal = "urxvt"
modkey = "Mod4"

require"globalkeys"

local c = 0
awful.screen.connect_for_each_screen(function(s)
    c = c + 1

    gears.wallpaper.centered(beautiful.wallpaper, s, beautiful.color0, 0.1)

    awful.tag({ "1", "2", "3", "4", "5" }, s, awful.layout.suit.floating)

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

    c:connect_signal("property::fullscreen", function()
        c.screen.mywibar.visible = not c.fullscreen
        c.screen.mydock.visible = not c.fullscreen
    end)
end)

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { focus = awful.client.focus.filter,
                     raise = true,
                     keys = require"clientkeys",
                     buttons = require"windowcontrols",
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen,
                     size_hints_honor = false
     }
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
          "pinentry",
        },
        class = {
          "Arandr",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
          "Wpa_gui",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here.
        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "ConfigManager",  -- Thunderbird's about:config.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

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

client.connect_signal("request::titlebars", function(c)
    require"titlebar"(c)
    require"tabs"(c)
end)

-- vim:set et sw=4 ts=4:
