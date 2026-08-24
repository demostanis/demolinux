local awful = require"awful"
local beautiful = require"beautiful"
local gears = require"gears"
local wibox = require"wibox"
local dpi = require"beautiful.xresources".apply_dpi
local source_dir = debug.getinfo(1, "S").source:match("@(.*/)")

local arrow_icons = {
    left = gears.surface.load_uncached(
        source_dir.."theme/caret-left-bold.png"),
    right = gears.surface.load_uncached(
        source_dir.."theme/caret-right-bold.png"),
}

local sidecar = {}
local states = setmetatable({}, {__mode = "k"})
local active_state

local animation_frames = 11
local animation_interval = 1 / 60

local function is_valid(c)
    if not c then
        return false
    end
    local ok, valid = pcall(function()
        return c.valid
    end)
    return ok and valid
end

function sidecar.is_opencode(c)
    local name = c and c.name or ""
    return c and c.class == "URxvt" and name:match("^OC%s*|") ~= nil
end

local function clamp_panel_width(c, width)
    local minimum = dpi(240)
    local maximum = math.max(minimum,
        math.floor(c.screen.workarea.width * 0.75))
    return math.max(minimum, math.min(width, maximum))
end

local function default_panel_width(c)
    local preferred = beautiful.opencode_sidecar_width
        or beautiful.panel_width or dpi(415)
    return clamp_panel_width(c, preferred)
end

local function expanded_width(state)
    return clamp_panel_width(state.client,
        state.preferred_width or default_panel_width(state.client))
end

local function owner_is_visible(c)
    if not is_valid(c) or c.minimized or c.hidden or c.fullscreen then
        return false
    end

    local ok, visible = pcall(function()
        return c:isvisible()
    end)
    return ok and visible
end

local function redraw_button(state)
    if state.button then
        state.button:emit_signal("widget::redraw_needed")
    end
end

local function place_panel(state)
    local c = state.client
    local width = math.max(1, math.floor(state.current_width))
    local x = c.x + c.width

    state.panel.screen = c.screen
    state.panel:geometry({
        x = x,
        y = c.y,
        width = width,
        height = math.max(1, c.height),
    })
end

local function refresh(state)
    if not is_valid(state.client) then
        state.panel.visible = false
        return
    end

    place_panel(state)
    state.panel.visible = (state.expanded or state.animating)
        and owner_is_visible(state.client)
    redraw_button(state)
end

local function update_layout_reservation(state)
    local c = state.client
    if not is_valid(c) then
        return
    end

    local reserved_width = 0
    if state.current_width > 0 then
        reserved_width = math.floor(state.current_width + 0.5)
            + state.border_width * 2
    end
    if c.opencode_sidecar_width == reserved_width then
        return
    end

    c.opencode_sidecar_width = reserved_width
    awful.layout.arrange(c.screen)
end

local function stop_animation(state)
    if state.animation then
        state.animation:stop()
        state.animation = nil
    end
    state.animating = false
end

local function set_expanded(state, expanded, immediate)
    if state.expanded == expanded and not state.animating then
        refresh(state)
        return
    end

    stop_animation(state)
    state.expanded = expanded

    if expanded and active_state and active_state ~= state then
        set_expanded(active_state, false)
    end
    if expanded then
        active_state = state
    elseif active_state == state then
        active_state = nil
    end

    local from = state.current_width
    local target = expanded and expanded_width(state) or 0
    if immediate then
        state.current_width = target
        update_layout_reservation(state)
        refresh(state)
        if not expanded then
            state.panel.visible = false
        end
        return
    end

    state.animating = true
    refresh(state)

    local frame = 0
    state.animation = gears.timer.start_new(animation_interval, function()
        if not is_valid(state.client) then
            state.animation = nil
            state.animating = false
            state.panel.visible = false
            return false
        end

        frame = frame + 1
        local progress = math.min(1, frame / animation_frames)
        local eased = progress * progress * (3 - 2 * progress)
        state.current_width = from + (target - from) * eased
        update_layout_reservation(state)
        refresh(state)

        if progress == 1 then
            state.current_width = target
            state.animation = nil
            state.animating = false
            update_layout_reservation(state)
            refresh(state)
            return false
        end
        return true
    end)
end


local function resize_state(state, width)
    width = clamp_panel_width(state.client, width)
    state.preferred_width = width
    if state.expanded then
        stop_animation(state)
        state.current_width = width
        update_layout_reservation(state)
        refresh(state)
    end
    return width
end

local function bind_resize_controls(state)
    state.panel:buttons(gears.table.join(
        awful.button({modkey}, 3, function()
            if not state.expanded then
                return
            end

            stop_animation(state)
            local initial_x = mouse.coords().x
            local initial_width = state.current_width
            mousegrabber.run(function(coords)
                resize_state(state,
                    initial_width + coords.x - initial_x)
                return coords.buttons[3]
            end, "sb_h_double_arrow")
        end)
    ))
end

local function make_button(state)
    local button = wibox.widget.base.make_widget()
    button.forced_width = dpi(29)
    button.hovered = false

    function button:fit(_, _, height)
        return self.forced_width, height
    end

    function button:draw(_, cr, width, height)
        local color = beautiful.fg_normal
        if self.hovered then
            color = beautiful.wibar_widget_hover_color
                or beautiful.fg_focus
        end
        local icon = state.expanded and arrow_icons.left or arrow_icons.right
        local icon_width, icon_height = gears.surface.get_size(icon)
        local target_size = math.min(dpi(16), width - dpi(8), height - dpi(8))
        local scale = math.min(target_size / icon_width,
            target_size / icon_height)
        local rendered_width = icon_width * scale
        local rendered_height = icon_height * scale

        cr:save()
        cr:translate((width - rendered_width) / 2,
            (height - rendered_height) / 2)
        cr:scale(scale, scale)
        cr:set_source_rgba(gears.color.parse_color(color))
        cr:mask_surface(icon, 0, 0)
        cr:restore()
    end

    button:connect_signal("mouse::enter", function()
        button.hovered = true
        button:emit_signal("widget::redraw_needed")
    end)
    button:connect_signal("mouse::leave", function()
        button.hovered = false
        button:emit_signal("widget::redraw_needed")
    end)
    button:buttons(gears.table.join(
        awful.button({}, 1, function()
            set_expanded(state, not state.expanded)
        end)
    ))
    return button
end

local function make_state(c)
    local border_width = 0
    local panel = wibox({
        screen = c.screen,
        ontop = true,
        visible = false,
        type = "utility",
        bg = beautiful.opencode_sidecar_bg
            or beautiful.color0 or beautiful.bg_normal,
        border_width = border_width,
        border_color = beautiful.opencode_sidecar_border_color
            or beautiful.color3 or beautiful.bg_focus,
    })
    local imagebox = wibox.widget({
        resize = true,
        halign = "center",
        valign = "center",
        widget = wibox.widget.imagebox,
    })
    local state = {
        client = c,
        panel = panel,
        imagebox = imagebox,
        side = "right",
        border_width = border_width,
        expanded = false,
        animating = false,
        current_width = 0,
        preferred_width = default_panel_width(c),
    }
    states[c] = state
    c.opencode_sidecar_width = 0
    panel.widget = wibox.widget({
        imagebox,
        margins = dpi(12),
        widget = wibox.container.margin,
    })
    bind_resize_controls(state)

    local geometry_signals = {
        "property::x",
        "property::y",
        "property::width",
        "property::height",
        "property::screen",
        "property::minimized",
        "property::hidden",
        "property::fullscreen",
        "property::sticky",
        "tagged",
        "untagged",
    }
    for _, signal in ipairs(geometry_signals) do
        c:connect_signal(signal, function()
            refresh(state)
        end)
    end
    c:connect_signal("unmanage", function()
        stop_animation(state)
        state.expanded = false
        state.panel.visible = false
        if active_state == state then
            active_state = nil
        end
    end)

    refresh(state)
    return state
end

local function get_state(c)
    return states[c] or make_state(c)
end

function sidecar.button(c)
    local state = get_state(c)
    if not state.button then
        state.button = make_button(state)
    end
    return state.button
end

function sidecar.toggle(c)
    if not sidecar.is_opencode(c) then
        return false
    end
    local state = get_state(c)
    set_expanded(state, not state.expanded)
    return state.expanded
end

function sidecar.show(c)
    if not sidecar.is_opencode(c) then
        return false
    end
    set_expanded(get_state(c), true)
    return true
end

function sidecar.hide(c)
    if not sidecar.is_opencode(c) then
        return false
    end
    set_expanded(get_state(c), false, true)
    return true
end

function sidecar.resize(c, width)
    if not sidecar.is_opencode(c) then
        return false
    end
    return resize_state(get_state(c), width)
end

function sidecar.set_image(c, path)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    if type(path) ~= "string" or path == "" then
        return "error: image path is empty"
    end

    local state = get_state(c)
    if not state.imagebox:set_image(path) then
        return "error: unable to load image "..path
    end
    state.image_path = path
    set_expanded(state, true)
    return sidecar.status(c)
end

function sidecar.clear_image(c)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end

    local state = get_state(c)
    state.imagebox:set_image(nil)
    state.image_path = nil
    refresh(state)
    return sidecar.status(c)
end

function sidecar.status(c)
    local state = states[c]
    if not state then
        return "unattached"
    end
    local geometry = state.panel:geometry()
    local image = state.image_path and " image="..state.image_path
        or " image=none"
    return string.format("%s %s %d,%d %dx%d reserved=%d",
        state.expanded and "expanded" or "collapsed",
        state.side, geometry.x, geometry.y,
        geometry.width, geometry.height,
        state.client.opencode_sidecar_width or 0)..image
end

tag.connect_signal("property::selected", function()
    for _, state in pairs(states) do
        refresh(state)
    end
end)

screen.connect_signal("property::geometry", function()
    for _, state in pairs(states) do
        refresh(state)
    end
end)

screen.connect_signal("property::workarea", function()
    for _, state in pairs(states) do
        refresh(state)
    end
end)

return sidecar

-- vim:set et sw=4 ts=4:
