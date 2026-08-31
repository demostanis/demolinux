local battery_icon = "\u{f240}"
local hovering_widget = false
local hovering_popup = false
local current_profile = nil
local profile_rows = {}
local menu_width = 148

local function with_opacity(color, alpha)
    if color and color:match("^#%x%x%x%x%x%x") then
        return color:sub(1, 7) .. alpha
    end
    return color
end

local mybatwidget = wibox.widget{
    text = battery_icon,
    widget = wibox.widget.textbox,
    font = beautiful.icon_font,
    halign = "center"
}

local function fmt(text)
    if hovering_widget then
        return "<span foreground='" .. beautiful.wibar_widget_hover_color .. "'>" .. text .. "</span>"
    end
    return text
end

local function set_battery_icon(icon)
    battery_icon = icon
    mybatwidget.markup = fmt(battery_icon)
end

local statusw = wibox.widget{
    text = "Battery: --%",
    widget = wibox.widget.textbox,
    font = beautiful.base_font .. " 9"
}

local titlew = wibox.widget{
    text = "Power profile",
    widget = wibox.widget.textbox,
    font = beautiful.base_font .. ", ExtraBold 9"
}

local separatorw = wibox.widget{
    orientation = "horizontal",
    forced_width = menu_width - 10,
    forced_height = 1,
    thickness = 0.5,
    color = with_opacity(beautiful.fg_normal, "80"),
    widget = wibox.widget.separator
}

local profiles = {
    {id = "performance", icon = "\u{f625}", label = "Performance", dpm_option = "--disable"},
    {id = "balanced", icon = "\u{f24e}", label = "Balanced", dpm_option = "--enable"},
    {id = "power-saver", icon = "\u{f06c}", label = "Power saver", dpm_option = "--enable"}
}

local function update_profile_rows()
    for _, profile in ipairs(profiles) do
        local row = profile_rows[profile.id]
        if row then
            local active = current_profile == profile.id
            row.check.text = active and "\u{f00c}" or ""
            row.bg.fg = active and beautiful.wibar_widget_hover_color or beautiful.fg_normal
            if row.hovering then
                row.bg.bg = beautiful.bg_normal
            elseif active then
                row.bg.bg = beautiful.color4
            else
                row.bg.bg = beautiful.bg_focus
            end
        end
    end
end

local function refresh_power_profile()
    awful.spawn.easy_async_with_shell("powerprofilesctl get 2>/dev/null", function(stdout, _, _, code)
        if code == 0 then
            current_profile = stdout:match("^%s*(.-)%s*$")
        else
            current_profile = nil
        end
        update_profile_rows()
    end)
end

local function set_power_profile(profile)
    current_profile = profile.id
    update_profile_rows()
    local command = "powerprofilesctl set " .. profile.id
        .. " && powerprofilesctl configure-action amdgpu_dpm " .. profile.dpm_option
    awful.spawn.easy_async_with_shell(command, function(_, stderr, _, code)
        if code ~= 0 then
            local message = stderr or "unknown error"
            naughty.notify({
                title = "Power profile",
                text = "Could not switch to " .. profile.label
                    .. " or configure AMD GPU power management: " .. message,
                preset = naughty.config.presets.critical
            })
        end
        refresh_power_profile()
    end)
end

local function make_profile_row(profile)
    local right = 0
    local width = 22
    if profile.id == "balanced" then
        -- the icon is shit
        right = 4
        width = 18
    end

    local iconw = wibox.widget{
        {
            text = profile.icon,
            widget = wibox.widget.textbox,
            font = beautiful.base_icon_font .. " 8",
            forced_width = width,
            halign = "center"
        },
        widget = wibox.container.margin,
        right = right,
    }
    local labelw = wibox.widget{
        text = profile.label,
        widget = wibox.widget.textbox,
        font = beautiful.base_font .. " 9"
    }
    local checkw = wibox.widget{
        text = "",
        widget = wibox.widget.textbox,
        font = beautiful.base_icon_font .. " 8",
        forced_width = 12,
        halign = "center"
    }
    local bg = wibox.widget{
        {
            {
                iconw,
                labelw,
                checkw,
                spacing = 5,
                layout = wibox.layout.fixed.horizontal
            },
            margins = 3,
            widget = wibox.container.margin
        },
        bg = beautiful.bg_focus,
        shape = rrect(),
        widget = wibox.container.background
    }
    profile_rows[profile.id] = {bg = bg, check = checkw, hovering = false}

    bg:buttons(gears.table.join(
        awful.button({ }, 1, function()
            set_power_profile(profile)
        end)
    ))
    bg:connect_signal("mouse::enter", function()
        profile_rows[profile.id].hovering = true
        update_profile_rows()
    end)
    bg:connect_signal("mouse::leave", function()
        profile_rows[profile.id].hovering = false
        update_profile_rows()
    end)

    return bg
end

local profile_widgets = {spacing = 1, layout = wibox.layout.fixed.vertical}
for _, profile in ipairs(profiles) do
    table.insert(profile_widgets, make_profile_row(profile))
end

local popup = awful.popup {
    visible = false,
    widget = wibox.widget{
        {
            {
                statusw,
                separatorw,
                titlew,
                wibox.widget(profile_widgets),
                spacing = 4,
                layout = wibox.layout.fixed.vertical
            },
            margins = 5,
            widget = wibox.container.margin
        },
        strategy = "exact",
        width = menu_width,
        widget = wibox.container.constraint
    },
    ontop = true,
    bg = beautiful.bg_focus,
    shape = rrect(),
    preferred_positions = {"bottom", "left", "right", "top"},
    preferred_anchors = {"middle", "front", "back"},
    offset = {y = 5}
}

local function hide_popup_delayed()
    delayed(function()
        if not hovering_widget and not hovering_popup then
            popup.visible = false
        end
    end, 0.15)
end

popup:connect_signal("mouse::enter", function()
    hovering_popup = true
end)
popup:connect_signal("mouse::leave", function()
    hovering_popup = false
    hide_popup_delayed()
end)

mybatwidget:connect_signal("mouse::enter", function()
    local geo = mouse.current_widget_geometry
    if overview_shown or not geo then return end
    geo.x = geo.x + 3
    geo.y = geo.y + 7

    popup:move_next_to(geo)
    popup.visible = true
    refresh_power_profile()

    hovering_widget = true
    mybatwidget.markup = fmt(battery_icon)
end)
mybatwidget:connect_signal("mouse::leave", function()
    if not popup then return end

    hovering_widget = false
    hide_popup_delayed()
    mybatwidget.markup = fmt(battery_icon)
end)

local icons = {
    "\u{f244}", -- empty
    "\u{e0b1}", -- low
    "\u{f243}", -- quarter
    "\u{f242}", -- half
    "\u{f241}", -- three quarters
    "\u{f240}"  -- full
}
vicious.register(statusw, vicious.widgets.bat, function(widget, args)
    if args[1] == "+" then -- charging
        set_battery_icon("\u{f376}")
    else
        local ratio = 100 / #icons
        local icon = icons[math.ceil(args[2] / ratio)]
        if not icon then icon = icons[1] end
        set_battery_icon(icon)
    end
    return "Battery: " .. args[2] .. "%"
end, 1, "BAT0")

if vicious.call(vicious.widgets.bat, "$1", "BAT0") ~= "⌁" then -- unknown state
    return mybatwidget
end
return {_absent = true}

-- vim:set et sw=4 ts=4:
