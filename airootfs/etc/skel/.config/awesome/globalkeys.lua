local should_spawn_with_selection = false
local function spawn_with_selection_if_needed(...)
    if should_spawn_with_selection then
        should_spawn_with_selection = false
        spawn_with_selection(...)
    else
        awful.spawn(...)
    end
end

local function moveclient(direction)
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

local function app_shortcut(app, key)
    return awful.key({ modkey }, key, function()
        spawn_with_selection_if_needed(app)
    end)
end

local globalkeys = gears.table.join(
    awful.key({ modkey }, "l",  awful.tag.viewnext),
    awful.key({ modkey }, "h",   awful.tag.viewprev),

    awful.key({ modkey, "Shift" }, "l",  function() moveclient("down") end),
    awful.key({ modkey, "Shift" }, "h", function() moveclient("up") end),

    awful.key({ modkey }, "s", function() awful.spawn("flameshot gui") end),

    app_shortcut(terminal, "Return"),
    app_shortcut("firefox-hardened", "f"),

    awful.key({ modkey }, "r", awesome.restart),

    awful.key({ modkey }, "Tab", function()
        switcher.switch(1, modkey, "Super_L", "Shift", "Tab")
    end),
    awful.key({ modkey, "Shift" }, "Tab", function()
        switcher.switch(-1, modkey, "Super_L", "Shift", "Tab")
    end),

    awful.key({ modkey }, "p", function() show_panel() end, nil),
    awful.key({ modkey }, "k", require"screenlock", nil),
    awful.key({ modkey }, "o", require"overview", nil),
    awful.key({ modkey }, "space", require"applauncher", nil),
    -- God, why is it trying to call some on_release when I don't specify nil??
    awful.key({ modkey }, "e", require"emojipicker", nil),

    awful.key({ modkey }, "x", function()
        should_spawn_with_selection = true
        gears.timer{
            timeout = 2,
            single_shot = true,
            callback = function()
                should_spawn_with_selection = false
            end
        }:start()
    end)
)

root.keys(globalkeys)

-- vim:set et sw=4 ts=4:
