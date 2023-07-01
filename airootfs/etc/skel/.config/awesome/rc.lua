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

awful.layout.layouts = { awful.layout.suit.floating }

awful.screen.connect_for_each_screen(function(s)
    gears.wallpaper.set(beautiful.wallpaper)

    awful.tag({ "1", "2", "3", "4", "5" }, s, awful.layout.suit.floating)

    s.mywibar = require"wibar"(s)
    s.mydock = require"dock"(s)
end)

function moveclient(direction)
    local c = client.focus
    if not c then return end
    local s = c.screen
    local index = s.selected_tag.index
    local wanted_index = index - 1
    if direction == "down" then
        wanted_index = index + 1
    end
    local tag = s.tags[gears.math.cycle(#s.tags, wanted_index)]
    c:move_to_tag(tag)
    if direction == "down" then
        awful.tag.viewnext()
    else
        awful.tag.viewprev()
    end
    client.focus = c
end

globalkeys = gears.table.join(
    awful.key({ modkey,           }, "j",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "k",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),

    awful.key({ modkey, "Shift"   }, "j",  function() moveclient("down") end,
              {description = "view next", group = "tag"}),
    awful.key({ modkey, "Shift"   }, "k", function() moveclient("up") end,
              {description = "view previous", group = "tag"}),

    awful.key({ modkey,           }, "Return", function () spawn_with_selection(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),

    awful.key({ modkey, }, "space", function()
        bling.widget.app_launcher{
            terminal = "urxvt -e",
            whitelist = {
                "Firefox Web Browser",
                "urxvt", "Nemo", "Neovim",
                "scrcpy"
            },
            icon_theme = beautiful.icon_theme,
            apps_per_row = 2,
        }:toggle()
    end),

    awful.key({ modkey }, "s", require"overview")
)

clientkeys = gears.table.join(
    awful.key({ modkey,  }, "q",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "f",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"})
)

-- Set keys
root.keys(globalkeys)

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
end)

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
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

client.connect_signal("request::titlebars", function(c)
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 2, function()
            c.maximized = not c.maximized
        end)
    )

    awful.titlebar(c):setup{
        {
            {
                awful.titlebar.widget.iconwidget(c),
                layout  = wibox.layout.fixed.horizontal
            },
            widget = wibox.container.margin,
            margins = 4
        },
        {
            {
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        {
            {
                -- a bunch of random margins because these images' size suck...
                {
                    awful.titlebar.widget.ontopbutton(c),
                    widget = wibox.container.margin,
                    right = 8,
                    top = 2
                },
                {
                    awful.titlebar.widget.maximizedbutton(c),
                    widget = wibox.container.margin,
                    top = 1,
                    bottom = 4,
                },
                {
                    awful.titlebar.widget.closebutton(c),
                    widget = wibox.container.margin,
                    bottom = 2.5
                },
                layout = wibox.layout.flex.horizontal,
            },
            widget = wibox.container.margin,
            top = 6,
        },
        layout = wibox.layout.align.horizontal
    }

    require"tabs"(c)
end)

-- vim:set et sw=4 ts=4:
