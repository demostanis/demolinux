local stopped = false
local mykeygrabber = nil
local old_client_focus = nil
local state = nil
local mypanel = nil
local panes = {}

local footerw = {
    {
        {
            image = "/usr/share/pixmaps/nyarch.png",
            widget = wibox.widget.imagebox,
            forced_width = 96,
            forced_height = 96,
        },
        {
            {
                {
                    widget = wibox.widget.textbox,
                    font = beautiful.bold_font,
                    text = "demolinux",
                },
                {
                    widget = wibox.widget.textbox,
                    text = "version ".."0.9",
                },
                layout = wibox.layout.fixed.vertical,
            },
            widget = wibox.container.margin,
            top = 13, left = -5,
        },
        layout = wibox.layout.fixed.horizontal,
    },
    widget = wibox.container.margin,
    bottom = -30, left = -10
}

local function spawn_wifi()
    awful.spawn("iwgtk", false)
end
local function spawn_vpn()
    local verb = "start"
    if state == "active" then
        verb = "stop"
    end
    awful.spawn("systemctl "..verb.." openvpn-client@riseup", false)
end

local function mkpanew(icon, text, command, opts)
    local size = 25
    if opts and opts.size then
        size = opts.size
    end

    local hide_status = opts and opts.hide_status

    local contentw = {{
        {
            widget = wibox.widget.textbox,
            font = beautiful.base_icon_font.." 25",
            halign = "center",
            text = icon,
        },
        widget = wibox.container.margin,
        bottom = 5, right = 5, left = 5,
        top = hide_status and 10 or 5
    },
    {
        widget = wibox.widget.textbox,
        font = beautiful.base_font..", ExtraBold "..size,
        halign = "center",
        text = text,
    },
    layout = wibox.layout.fixed.vertical}

    if not hide_status then
        table.insert(contentw, {
            widget = wibox.widget.textbox,
            halign = "center",
            id = ("status-"..text):lower(),
            text = "...",
        })
    end

    return {
        {
            contentw,
            widget = wibox.container.margin,
            margins = 50,
        },
        id = "pane",
        forced_width = 200,
        widget = wibox.container.background,
        bg = beautiful.bg_normal,
        shape = rrect(10),
        command = command,
        opts = opts,
    }
end

function show_panel()
    mypanel.visible = not mypanel.visible
    -- this should probably be renamed
    overview_shown = mypanel.visible
    awesome.emit_signal("overview::display", mypanel.visible)

    if mypanel.visible then
        old_client_focus = client.focus
        if old_client_focus then
            old_client_focus:connect_signal("unmanage", function()
                old_client_focus = nil
            end)
            client.focus = nil
        end

        stopped = false
        has_released_mouse_yet = false
        mousegrabber.run(function(coords)
            if stopped then return false end

            if not has_released_mouse_yet and not coords.buttons[1] then
                has_released_mouse_yet = true
            end

            if #panes == 0 then
                for _, w in pairs(mypanel:get_children_by_id("pane")) do
                    local pane = wgeometry(w, mypanel)
                    pane.widget = w
                    pane.has_hovering_in_previous_frame = false
                    table.insert(panes, pane)
                end
                for _, w in pairs(mypanel:get_children_by_id("music-player-icons")[1]:get_all_children()) do
                    local pane = wgeometry(w, mypanel)
                    pane.widget = w
                    pane.has_hovering_in_previous_frame = false
                    table.insert(panes, pane)
                end
                for _, w in pairs(mypanel:get_children_by_id("system")) do
                    local pane = wgeometry(w, mypanel)
                    pane.widget = w
                    pane.has_hovering_in_previous_frame = false
                    table.insert(panes, pane)
                end
                return true
            end
            for _, pane in pairs(panes) do
                -- when a mousegrabber is active, mouse::* events
                -- aren't dispatched. thus we emit our own.
                if coords.x > mypanel.x+pane.x and
                    coords.x < mypanel.x+pane.x+pane.width and
                    coords.y > mypanel.y+pane.y and
                    coords.y < mypanel.y+pane.y+pane.height then
                    if coords.buttons[1] then
                        pane.widget:emit_signal("mouse::click")
                    else
                        pane.widget:emit_signal("mouse::enter")
                        pane.was_hovering_in_previous_frame = true
                    end
                elseif pane.was_hovering_in_previous_frame then
                    pane.widget:emit_signal("mouse::leave")
                    pane.was_hovering_in_previous_frame = false
                end
            end

            if not coords.buttons[1] or not has_released_mouse_yet then
                return true
            end
            if coords.x > mypanel.x+mypanel.width or
                coords.x < mypanel.x or
                coords.y > mypanel.y+mypanel.height or
                coords.y < mypanel.y then
                mypanel:hide()
                return false
            end
            return true
        end, "arrow")
        mykeygrabber = awful.keygrabber{
            keybindings = {
                {{ }, "Escape", mypanel.hide},
                {{ }, "w", function()
                    spawn_wifi()
                    mypanel:hide()
                end},
                {{ }, "v", function()
                    spawn_vpn()
                end}
            }
        }
        mykeygrabber:start()
    end
end

return function(s)
    mypanel = wibox{screen = s,
        x = 5, y = beautiful.wibar_height+8,
        ontop = true, visible = false,
        width = beautiful.panel_width,
        height = beautiful.panel_height,
        bg = beautiful.bg_focus,
    }
    s.mypanel = mypanel

    function mypanel:hide()
        mypanel.visible = false
        if old_client_focus then
            client.focus = old_client_focus
        end
        overview_shown = false
        if mykeygrabber then
            mykeygrabber:stop()
        end
        mousegrabber:stop()
        awesome.emit_signal("overview::display", false)
        stopped = true
    end

    gears.timer{
        timeout = 2,
        call_now = true,
        callback = function()
            awful.spawn.easy_async("systemctl show openvpn-client@riseup", function(stdout)
                local message = "Unknown state"
                for line in (stdout.."\n"):gmatch"(.-)\n" do
                    local new_state = line:match"^ActiveState=(.*)"
                    if new_state then state = new_state end
                    if state == "failed" then
                        message = "Errored out"
                    elseif state == "active" then
                        for line in (stdout.."\n"):gmatch"(.-)\n" do
                            local potential_message = line:match"^StatusText=(.+)"
                            if potential_message then
                                if potential_message == "Pre-connection initialization successful" then
                                    message = "Connecting..."
                                elseif potential_message == "Initialization Sequence Completed" then
                                    message = "Connected"
                                else
                                    message = potential_message
                                end
                            end
                        end
                    elseif state == "inactive" then
                        message = "Not running"
                    elseif state == "deactivating" then
                        message = "Disconnecting..."
                    else
                        -- unknown state
                    end
                end
                local statusw = mypanel:get_children_by_id("status-vpn")[1]
                if statusw.markup and statusw.markup:match"span foreground" then -- is hovered
                    statusw.oldtext = message
                    statusw.markup = string.format([[<span foreground="%s">%s</span>]], beautiful.wibar_widget_hover_color, message)
                else
                    statusw.text = message
                end
            end)
        end
    }:start()

    gears.timer{
        timeout = 2,
        call_now = true,
        callback = function()
            awful.spawn.easy_async("iwctl station list", function(stdout)
                local message = nil 
                local disabled = false
                if stdout:match"No devices in Station mode available." then
                    message = "Unavailable"
                    disabled = true
                else
                    local interface, status = stdout:match"(wlan%d)%s+(%S+)"
                    if status == "disconnected" then
                        message = "Disconnected"
                    elseif status == "connected" then
                        message = "Connected"
                    else
                        message = "Connecting..."
                    end
                end

                -- maybe find a less ugly solution than [1]?
                mypanel:get_children_by_id("pane")[1].disabled = disabled
                local statusw = mypanel:get_children_by_id("status-wifi")[1]
                if statusw.markup and statusw.markup:match"span foreground" then -- is hovered
                    statusw.oldtext = message
                    statusw.markup = string.format([[<span foreground="%s">%s</span>]], beautiful.wibar_widget_hover_color, message)
                else
                    statusw.text = message
                end
            end)
        end
    }:start()

    local function update_music_player()
        awful.spawn.easy_async([[playerctl metadata xesam:artist]], function(stdout, _, _, code)
            local icon = mypanel:get_children_by_id("music-player-middle-icon")[1]
            local artist = stdout:gsub("\n", "")
            awful.spawn.easy_async([[playerctl metadata xesam:title]], function(stdout, _, _, code)
                local message = "Not playing ;("
                if code == 0 then
                    local title = stdout:gsub("\n", "")
                    message = artist .. " - " .. title
                end
                mypanel:get_children_by_id("music-player-message")[1].text = message
                awful.spawn.easy_async([[playerctl status]], function(stdout, _, _, code)
                    if stdout == "Playing\n" then
                        icon.text = "\u{f04c}"
                    else
                        icon.text = "\u{f04b}"
                    end
                end)
            end)
        end)
    end

    gears.timer{
        timeout = 1,
        call_now = true,
        callback = update_music_player
    }:start()

    mypanel:setup{
        {
            {
                {
                    {
                        mkpanew("\u{f1eb}", "WiFi", function()
                            spawn_wifi()
                        end, {hide_panel_on_click = true}),
                        mkpanew("\u{e4e2}", "VPN", function()
                            spawn_vpn()
                        end),
                        layout = wibox.layout.fixed.horizontal,
                        spacing = 5
                    },
                    {
                        mkpanew("\u{f03d}", "Record screen", function()
                            -- TODO: record screen
                        end, {hide_panel_on_click = true, size = 11}),
                        mkpanew("\u{f53f}", "Color picker", function()
                            awful.spawn("colorpicker")
                        end, {hide_panel_on_click = true, size = 13, hide_status = true}),
                        layout = wibox.layout.fixed.horizontal,
                        spacing = 5
                    },
                    layout = wibox.layout.fixed.vertical,
                    spacing = 5
                },
                {
                    {
                        {
                            {
                                {
                                    {
                                        widget = wibox.widget.textbox,
                                        font = beautiful.base_font.." 15",
                                        halign = "center",
                                        text = "...",
                                        id = "music-player-message",
                                        forced_height = 30,
                                    },
                                    widget = wibox.container.margin,
                                    top = 20, bottom = 10,
                                    left = 15, right = 15
                                },
                                {
                                    {
                                        widget = wibox.widget.textbox,
                                        font = beautiful.base_icon_font.." 35",
                                        halign = "center",
                                        text = "\u{f04a}",
                                        id = "music-player-left-icon",
                                        command = [[playerctl previous]]
                                    },
                                    {
                                        widget = wibox.widget.textbox,
                                        font = beautiful.base_icon_font.." 35",
                                        halign = "center",
                                        text = "\u{f04b}",
                                        id = "music-player-middle-icon",
                                        command = [[playerctl play-pause]]
                                    },
                                    {
                                        widget = wibox.widget.textbox,
                                        font = beautiful.base_icon_font.." 35",
                                        halign = "center",
                                        text = "\u{f04e}",
                                        id = "music-player-right-icon",
                                        command = [[playerctl next]]
                                    },
                                    layout = wibox.layout.flex.horizontal,
                                    id = "music-player-icons"
                                },
                                layout = wibox.layout.fixed.vertical
                            },
                            widget = wibox.container.margin,
                            bottom = 20
                        },
                        widget = wibox.container.background,
                        bg = beautiful.bg_normal,
                        shape = rrect(),
                    },
                    widget = wibox.container.margin,
                    top = 5, bottom = -5
                },
                layout = wibox.layout.fixed.vertical,
            },
            widget = wibox.container.margin,
            margins = 5
        },
        nil,
        {
            {
                {
                    {
                        widget = wibox.widget.textbox,
                        font = beautiful.base_icon_font .. " 25",
                        forced_width = 32,
                        text = "\u{f011}"
                    },
                    widget = wibox.container.background,
                    id = "system",
                    command = function()
                        awful.spawn("systemctl poweroff")
                    end
                },
                widget = wibox.container.margin,
                left = 270, right = 5, bottom = 11, top = 15,
            },
            {
                {
                    {
                        widget = wibox.widget.textbox,
                        font = beautiful.base_icon_font .. " 23",
                        text = "\u{f2f9}"
                    },
                    widget = wibox.container.background,
                    id = "system",
                    command = function()
                        awful.spawn("systemctl reboot")
                    end
                },
                widget = wibox.container.margin,
                left = 15, right = 7, bottom = 11, top = 15,
            },
            {
                {
                    {
                        widget = wibox.widget.textbox,
                        font = beautiful.base_icon_font .. " 25",
                        text = "\u{f880}"
                    },
                    widget = wibox.container.background,
                    id = "system",
                    command = function()
                        awful.spawn("systemctl hibernate")
                    end
                },
                widget = wibox.container.margin,
                left = 15, right = 5, bottom = 11, top = 15,
            },
            layout = wibox.layout.fixed.horizontal
        },
        --footerw,
        layout = wibox.layout.align.vertical
    }

    for _, pane in ipairs(mypanel:get_children_by_id("pane")) do
        pane:connect_signal("mouse::enter", function()
            for _, child in ipairs(pane:get_all_children()) do
                local textboxtype = "wibox.widget.textbox"
                if string.sub(tostring(child), 1, string.len(textboxtype)) == textboxtype and not pane.disabled then
                    child.oldtext = child.text
                    -- TODO: use a wrapper function in utils?
                    child.markup = string.format([[<span foreground="%s">%s</span>]], beautiful.wibar_widget_hover_color, child.text)
                end
            end
        end)
        pane:connect_signal("mouse::leave", function()
            for _, child in ipairs(pane:get_all_children()) do
                local textboxtype = "wibox.widget.textbox"
                if string.sub(tostring(child), 1, string.len(textboxtype)) == textboxtype and not pane.disabled and child.oldtext then
                    child.markup = child.oldtext
                end
            end
        end)
        pane:connect_signal("mouse::click", function()
            if not pane.disabled then
                pane.command()
                if pane.opts and pane.opts.hide_panel_on_click then
                    mypanel:hide()
                end
            end
        end)
    end

    for _, icon in pairs(mypanel:get_children_by_id("music-player-icons")[1]:get_all_children()) do
        icon:connect_signal("mouse::click", function()
            awful.spawn(icon.command)
            update_music_player()
        end)
        icon:connect_signal("mouse::enter", function()
            icon.oldtext = icon.text
            icon.markup = string.format([[<span foreground="%s">%s</span>]], beautiful.wibar_widget_hover_color, icon.text)
        end)
        icon:connect_signal("mouse::leave", function()
            icon.text = icon.oldtext
        end)
    end

    for _, system_action in ipairs(mypanel:get_children_by_id("system")) do
        system_action:connect_signal("mouse::enter", function()
            for _, child in ipairs(system_action:get_all_children()) do
                local textboxtype = "wibox.widget.textbox"
                if string.sub(tostring(child), 1, string.len(textboxtype)) == textboxtype then
                    child.oldtext = child.text
                    -- TODO: use a wrapper function in utils?
                    child.markup = string.format([[<span foreground="%s">%s</span>]], beautiful.wibar_widget_hover_color, child.text)
                end
            end
        end)
        system_action:connect_signal("mouse::leave", function()
            for _, child in ipairs(system_action:get_all_children()) do
                local textboxtype = "wibox.widget.textbox"
                if string.sub(tostring(child), 1, string.len(textboxtype)) == textboxtype and child.oldtext then
                    child.markup = child.oldtext
                end
            end
        end)
        system_action:connect_signal("mouse::click", function()
            system_action.command()
            if system_action.opts and system_action.opts.hide_system_action_on_click then
                mypanel:hide()
            end
        end)
    end

    local panel_button = wibox.widget{
        text = "\u{f078}",
        widget = wibox.widget.textbox,
        font = beautiful.base_icon_font.." 10",
        halign = "center",
    }

    panel_button:connect_signal("mouse::enter", function()
        if overview_shown then return end
        panel_button.oldtext = panel_button.text
        panel_button.markup = string.format([[<span foreground="%s">%s</span>]], beautiful.wibar_widget_hover_color, panel_button.text)
    end)
    panel_button:connect_signal("mouse::leave", function()
        if overview_shown then return end
        panel_button.markup = panel_button.oldtext
    end)

    local containerw = wibox.container.margin(
        panel_button, 10, 10, 10, 10)
    containerw:buttons(gears.table.join(
        awful.button({ }, 1, function()
            show_panel()
        end)
    ))
    return containerw
end

-- vim:set et sw=4 ts=4:
