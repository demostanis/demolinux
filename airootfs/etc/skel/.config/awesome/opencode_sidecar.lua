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
local hosted_terminal_instance = "opencode-sidewindow-urxvt"

local animation_frames = 11
local animation_interval = 1 / 60
local titlebar_height = gears.math.round(
    beautiful.get_font_height() * 1.5)
local titlebar_navigation_width = dpi(82)

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

function sidecar.is_hosted(c)
    return is_valid(c) and (c.opencode_sidecar_hosted
        or c.instance == hosted_terminal_instance)
end

function sidecar.is_firefox(c)
    return is_valid(c) and type(c.class) == "string"
        and c.class:lower() == "firefox"
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

local function client_is_visible(c)
    if not is_valid(c) or c.minimized or c.hidden then
        return false
    end

    local ok, visible = pcall(function()
        return c:isvisible()
    end)
    return ok and visible
end

local function owner_is_visible(c)
    if not client_is_visible(c) or c.fullscreen then
        return false
    end
    for _, candidate in ipairs(c.screen.clients) do
        if candidate ~= c and not sidecar.is_hosted(candidate)
            and candidate.fullscreen then
            local ok, visible = pcall(function()
                return candidate:isvisible()
            end)
            if ok and visible then
                return false
            end
        end
    end
    return true
end

local function active_tab(state)
    return state.tabs[state.active_index]
end

local function redraw_button(state)
    if state.button then
        state.button:emit_signal("widget::layout_changed")
        state.button:emit_signal("widget::redraw_needed")
    end
end

local function update_titlebar(state)
    local tab = active_tab(state)
    local name = tab and tab.name or ""
    state.title_widget:set_text("SideWindow | "..name)
    state.count_widget:set_text(string.format("%d / %d",
        state.active_index, #state.tabs))
    state.previous_widget:emit_signal("widget::redraw_needed")
    state.next_widget:emit_signal("widget::redraw_needed")
end

local function update_titlebar_style(state)
    local tab = active_tab(state)
    local hosted_is_active = tab and is_valid(tab.hosted_client)
        and tab.hosted_client.active
    local focused = state.client.active or hosted_is_active
    if focused then
        state.titlebar.bg = beautiful.titlebar_bg_focus
            or beautiful.titlebar_bg or beautiful.bg_focus
        state.titlebar.fg = beautiful.titlebar_fg_focus
            or beautiful.titlebar_fg or beautiful.fg_focus
    else
        state.titlebar.bg = beautiful.titlebar_bg_normal
            or beautiful.titlebar_bg or beautiful.bg_normal
        state.titlebar.fg = beautiful.titlebar_fg_normal
            or beautiful.titlebar_fg or beautiful.fg_normal
    end
end

local function chrome_height(state)
    return math.min(titlebar_height, math.max(1, state.client.height))
end

local function place_chrome(state)
    local c = state.client
    local width = math.max(1, math.floor(state.current_width))
    local x = c.x + c.width
    local header_height = chrome_height(state)

    state.titlebar.screen = c.screen
    state.titlebar:geometry({
        x = x,
        y = c.y,
        width = width,
        height = header_height,
    })
    state.panel.screen = c.screen
    state.panel:geometry({
        x = x,
        y = c.y + header_height,
        width = width,
        height = math.max(1, c.height - header_height),
    })
end

local function place_hosted(state, tab)
    local hosted = tab.hosted_client
    if not is_valid(hosted) then
        tab.hosted_client = nil
        return false
    end

    local owner = state.client
    local visible = active_tab(state) == tab
        and (state.expanded or state.animating)
        and owner_is_visible(owner)
    if not visible then
        hosted.hidden = true
        return true
    end

    local header_height = chrome_height(state)
    hosted.screen = owner.screen
    hosted:tags(owner:tags())
    hosted.hidden = false
    hosted.minimized = false

    local geometry = {
        x = owner.x + owner.width,
        y = owner.y + header_height,
        width = math.max(1, math.floor(state.current_width)),
        height = math.max(1, owner.height - header_height),
    }
    if hosted.x ~= geometry.x or hosted.y ~= geometry.y
        or hosted.width ~= geometry.width or hosted.height ~= geometry.height then
        hosted:geometry(geometry)
    end
    hosted:raise()
    return true
end

local function refresh(state)
    if not is_valid(state.client) then
        state.titlebar.visible = false
        state.panel.visible = false
        return
    end

    place_chrome(state)
    local selected = active_tab(state)
    local has_hosted = false
    for _, tab in ipairs(state.tabs) do
        local tab_has_hosted = place_hosted(state, tab)
        if tab == selected then
            has_hosted = tab_has_hosted
        end
    end

    if selected then
        state.content_container:set_widget(selected.imagebox)
    end
    local visible = selected ~= nil and (state.expanded or state.animating)
        and owner_is_visible(state.client)
    state.titlebar.visible = visible
    state.panel.visible = visible and not has_hosted
    update_titlebar(state)
    update_titlebar_style(state)
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

local function reclamp_state(state)
    stop_animation(state)
    state.current_width = state.expanded and #state.tabs > 0
        and expanded_width(state) or 0
    update_layout_reservation(state)
    refresh(state)
end

local function set_expanded(state, expanded, immediate)
    if expanded and #state.tabs == 0 then
        expanded = false
        immediate = true
    end
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
            state.titlebar.visible = false
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
            state.titlebar.visible = false
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

local function begin_resize(state)
    if not state.expanded then
        return
    end

    stop_animation(state)
    local initial_x = mouse.coords().x
    local initial_width = state.current_width
    mousegrabber.run(function(coords)
        resize_state(state, initial_width + coords.x - initial_x)
        return coords.buttons[3]
    end, "sb_h_double_arrow")
end

local function bind_resize_controls(state)
    local buttons = gears.table.join(
        awful.button({modkey}, 3, function()
            begin_resize(state)
        end)
    )
    state.titlebar:buttons(buttons)
    state.panel:buttons(buttons)
end

local function hosted_buttons(state)
    return gears.table.join(
        awful.button({}, 1, function(c)
            client.focus = c
            c:activate({context = "mouse_click", raise = false})
        end),
        awful.button({modkey}, 3, function()
            begin_resize(state)
        end)
    )
end

local activate_index

local function make_arrow_button(state, direction)
    local button = wibox.widget.base.make_widget()
    button.forced_width = dpi(21)
    button.hovered = false

    function button:fit(_, _, height)
        return self.forced_width, height
    end

    function button:draw(_, cr, width, height)
        local enabled = #state.tabs > 1
        local color = state.titlebar.fg or beautiful.fg_normal
        if not enabled then
            color = beautiful.color8 or beautiful.bg_normal
        elseif self.hovered then
            color = beautiful.wibar_widget_hover_color
                or beautiful.fg_focus
        end
        local icon = arrow_icons[direction]
        local icon_width, icon_height = gears.surface.get_size(icon)
        local target_size = math.min(dpi(14), width - dpi(4), height - dpi(6))
        if target_size <= 0 then
            return
        end
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
            local count = #state.tabs
            if count < 2 then
                return
            end
            local delta = direction == "left" and -1 or 1
            local index = ((state.active_index - 1 + delta) % count) + 1
            activate_index(state, index)
        end)
    ))
    return button
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
            if #state.tabs == 0 then
                return
            end
            set_expanded(state, not state.expanded)
        end)
    ))
    return button
end

local function clear_launch_watch(tab)
    if tab.launch_handler then
        client.disconnect_signal("manage", tab.launch_handler)
        tab.launch_handler = nil
    end
    if tab.launch_timer then
        tab.launch_timer:stop()
        tab.launch_timer = nil
    end
end

local function normalize_name(name)
    if type(name) ~= "string" then
        return nil, "sidewindow name must be a string"
    end
    name = name:match("^%s*(.-)%s*$")
    if name == "" then
        return nil, "sidewindow name is empty"
    end
    if name:find("%c") then
        return nil, "sidewindow name contains a control character"
    end
    if name:match("^%d+$") then
        return nil, "sidewindow name cannot contain only digits"
    end
    return name
end

local function find_tab_by_name(state, name)
    for index, tab in ipairs(state.tabs) do
        if tab.name == name then
            return tab, index
        end
    end
    return nil, nil
end

local function find_tab_by_role(state, role)
    for index, tab in ipairs(state.tabs) do
        if tab.role == role then
            return tab, index
        end
    end
    return nil, nil
end

local function unique_name(state, preferred)
    if not find_tab_by_name(state, preferred) then
        return preferred
    end
    local suffix = 2
    while find_tab_by_name(state, preferred.." "..suffix) do
        suffix = suffix + 1
    end
    return preferred.." "..suffix
end

local function generated_name(state)
    return unique_name(state, "Tab "..(#state.tabs + 1))
end

local function make_tab(state, name, role)
    return {
        owner = state,
        name = name,
        role = role,
        imagebox = wibox.widget({
            resize = true,
            halign = "center",
            valign = "center",
            widget = wibox.widget.imagebox,
        }),
        image_path = nil,
        hosted_client = nil,
        hosted_kind = nil,
        hosted_pid = nil,
        launching = false,
        focus_before_launch = nil,
        restore_focus_pending = false,
        focus_restore_generation = 0,
        launch_handler = nil,
        launch_timer = nil,
        removed = false,
    }
end

local function append_tab(state, name, role)
    local tab = make_tab(state, name, role)
    table.insert(state.tabs, tab)
    if #state.tabs == 1 then
        state.active_index = 1
        state.client:emit_signal("opencode_sidecar::availability")
    end
    update_titlebar(state)
    redraw_button(state)
    return tab, #state.tabs
end

local function ensure_active_tab(state, preferred_name)
    local tab = active_tab(state)
    if tab then
        return tab, false
    end
    tab = append_tab(state, unique_name(state, preferred_name))
    return tab, true
end

activate_index = function(state, index)
    if type(index) ~= "number" or index ~= math.floor(index)
        or index < 1 or index > #state.tabs then
        return false
    end
    if state.active_index == index then
        refresh(state)
        return true
    end

    local previous = active_tab(state)
    local focused = client.focus
    state.active_index = index
    refresh(state)
    if previous and is_valid(previous.hosted_client)
        and focused == previous.hosted_client and is_valid(state.client) then
        client.focus = state.client
    end
    return true
end

local function resolve_tab(state, selector)
    if selector == nil then
        return active_tab(state), state.active_index
    end
    if type(selector) == "string" then
        local named, named_index = find_tab_by_name(state, selector)
        if named then
            return named, named_index
        end
        selector = tonumber(selector)
    end
    if type(selector) == "number" and selector == math.floor(selector)
        and selector >= 1 and selector <= #state.tabs then
        return state.tabs[selector], selector
    end
    return nil, nil
end

local function restore_launch_focus(tab, hosted)
    if not tab.restore_focus_pending then
        return
    end
    local previous = tab.focus_before_launch
    tab.focus_restore_generation = tab.focus_restore_generation + 1
    local generation = tab.focus_restore_generation
    gears.timer.start_new(0.15, function()
        if tab.removed or generation ~= tab.focus_restore_generation
            or not tab.restore_focus_pending then
            return false
        end

        local current = client.focus
        if is_valid(current) and current ~= hosted then
            tab.focus_before_launch = nil
            tab.restore_focus_pending = false
            return false
        end

        local target
        if client_is_visible(previous) then
            target = previous
        elseif client_is_visible(tab.owner.client) then
            target = tab.owner.client
        end
        if target then
            client.focus = target
        end
        tab.focus_before_launch = nil
        tab.restore_focus_pending = false
        return false
    end)
end

local function prepare_launch_focus(tab, previous)
    tab.focus_restore_generation = tab.focus_restore_generation + 1
    tab.focus_before_launch = previous
    tab.restore_focus_pending = true
end

local function close_hosted(tab, restore_focus)
    local hosted = tab.hosted_client
    local hosted_was_focused = is_valid(hosted) and client.focus == hosted
    clear_launch_watch(tab)
    tab.hosted_client = nil
    tab.hosted_kind = nil
    tab.hosted_pid = nil
    tab.launching = false
    if hosted_was_focused and client_is_visible(tab.owner.client) then
        client.focus = tab.owner.client
    end
    if is_valid(hosted) then
        hosted:kill()
    end
    if restore_focus == false then
        tab.focus_restore_generation = tab.focus_restore_generation + 1
        tab.focus_before_launch = nil
        tab.restore_focus_pending = false
    else
        restore_launch_focus(tab, hosted)
    end
end

local function destroy_tab(tab)
    tab.removed = true
    close_hosted(tab, false)
    tab.imagebox:set_image(nil)
    tab.image_path = nil
end

local function remove_tab_from_state(state, tab)
    local removed_index
    for index, candidate in ipairs(state.tabs) do
        if candidate == tab then
            removed_index = index
            break
        end
    end
    if not removed_index then
        return false
    end

    local was_active = removed_index == state.active_index
    destroy_tab(tab)
    table.remove(state.tabs, removed_index)
    if #state.tabs == 0 then
        state.active_index = 0
        set_expanded(state, false, true)
        state.client:emit_signal("opencode_sidecar::availability")
        return true
    end
    if removed_index < state.active_index then
        state.active_index = state.active_index - 1
    elseif was_active then
        state.active_index = math.min(removed_index, #state.tabs)
    end
    refresh(state)
    return true
end

local function discard_created_tab(state, tab)
    remove_tab_from_state(state, tab)
end

local function attach_hosted(tab, hosted, kind, expand_on_attach)
    local state = tab.owner
    if tab.removed or not is_valid(state.client) then
        hosted:kill()
        return
    end

    if is_valid(tab.hosted_client) and tab.hosted_client ~= hosted then
        tab.hosted_client:kill()
    end

    clear_launch_watch(tab)
    tab.hosted_client = hosted
    tab.hosted_kind = kind
    tab.hosted_pid = hosted.pid
    tab.launching = false
    hosted.opencode_sidecar_hosted = true
    hosted.opencode_sidecar_owner = state.client
    hosted.floating = true
    hosted.skip_taskbar = true
    hosted.size_hints_honor = false
    hosted.maximized = false
    hosted.fullscreen = false
    hosted.buttons = hosted_buttons(state)

    for _, position in ipairs({"top", "bottom", "left", "right"}) do
        awful.titlebar.hide(hosted, position)
    end

    hosted:connect_signal("property::fullscreen", function(c)
        if tab.hosted_client == c and c.fullscreen then
            c.fullscreen = false
        end
    end)
    hosted:connect_signal("request::activate", function(c)
        if tab.hosted_client ~= c or (active_tab(state) == tab
            and state.expanded and owner_is_visible(state.client)) then
            return
        end
        local previous = client.focus
        gears.timer.delayed_call(function()
            if tab.hosted_client ~= c or not is_valid(c) then
                return
            end
            c.hidden = true
            if client.focus == c then
                if client_is_visible(previous) and previous ~= c then
                    client.focus = previous
                elseif client_is_visible(state.client) then
                    client.focus = state.client
                end
            end
        end)
    end)
    hosted:connect_signal("unmanage", function(c)
        if tab.hosted_client == c then
            local browser_closed = tab.hosted_kind == "firefox"
                or tab.hosted_kind == "firefox-mcp"
            local was_focused = client.focus == c
            tab.hosted_client = nil
            tab.hosted_kind = nil
            tab.hosted_pid = nil
            tab.launching = false
            if browser_closed then
                remove_tab_from_state(state, tab)
                if was_focused and client_is_visible(state.client) then
                    client.focus = state.client
                end
            else
                refresh(state)
            end
        end
    end)
    for _, signal in ipairs({
        "property::x", "property::y", "property::width", "property::height",
        "property::screen", "property::minimized", "property::hidden",
        "property::active", "tagged", "untagged",
    }) do
        hosted:connect_signal(signal, function(c)
            if tab.hosted_client == c then
                gears.timer.delayed_call(function()
                    if tab.hosted_client == c then
                        refresh(state)
                    end
                end)
            end
        end)
    end

    if expand_on_attach then
        set_expanded(state, true)
    end
    refresh(state)
    restore_launch_focus(tab, hosted)
end

local function watch_for_hosted(tab, matcher, kind, expand_on_attach,
    discard_on_timeout)
    local state = tab.owner
    local known = {}
    for _, candidate in ipairs(client.get()) do
        known[candidate] = true
    end

    local function consider(candidate)
        if tab.removed or not tab.launching or tab.hosted_kind ~= kind
            or known[candidate] or sidecar.is_hosted(candidate)
            or not matcher(candidate) then
            return false
        end
        attach_hosted(tab, candidate, kind, expand_on_attach)
        return true
    end

    tab.launch_handler = function(candidate)
        if not consider(candidate) then
            gears.timer.delayed_call(function()
                consider(candidate)
            end)
        end
    end
    client.connect_signal("manage", tab.launch_handler)
    tab.launch_timer = gears.timer.start_new(45, function()
        clear_launch_watch(tab)
        if not tab.removed and tab.launching and tab.hosted_kind == kind then
            tab.launching = false
            tab.hosted_kind = nil
            tab.hosted_pid = nil
            restore_launch_focus(tab)
            if discard_on_timeout then
                discard_created_tab(state, tab)
            else
                refresh(state)
            end
        end
        return false
    end)
end

local function make_state(c)
    local border_width = 0
    local titlebar = wibox({
        screen = c.screen,
        ontop = true,
        visible = false,
        type = "utility",
        bg = beautiful.opencode_sidecar_titlebar_bg
            or beautiful.bg_focus,
        fg = beautiful.fg_focus,
        border_width = border_width,
        border_color = beautiful.opencode_sidecar_border_color
            or beautiful.color3 or beautiful.bg_focus,
    })
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
    local content_container = wibox.widget({
        margins = dpi(12),
        widget = wibox.container.margin,
    })
    local state = {
        client = c,
        titlebar = titlebar,
        panel = panel,
        content_container = content_container,
        tabs = {},
        active_index = 0,
        side = "right",
        border_width = border_width,
        expanded = false,
        animating = false,
        current_width = 0,
        preferred_width = default_panel_width(c),
    }

    state.title_widget = wibox.widget({
        align = "center",
        valign = "center",
        font = beautiful.bold_font,
        widget = wibox.widget.textbox,
    })
    state.icon_widget = awful.titlebar.widget.iconwidget(c)
    state.count_widget = wibox.widget({
        align = "center",
        valign = "center",
        forced_width = dpi(40),
        font = beautiful.font,
        widget = wibox.widget.textbox,
    })
    state.previous_widget = make_arrow_button(state, "left")
    state.next_widget = make_arrow_button(state, "right")
    titlebar.widget = wibox.widget({
        {
            {
                state.icon_widget,
                layout = wibox.layout.fixed.horizontal,
            },
            margins = dpi(4),
            forced_width = titlebar_navigation_width,
            widget = wibox.container.margin,
        },
        {
            state.title_widget,
            layout = wibox.layout.flex.horizontal,
        },
        {
            state.previous_widget,
            state.count_widget,
            state.next_widget,
            layout = wibox.layout.fixed.horizontal,
        },
        layout = wibox.layout.align.horizontal,
    })
    panel.widget = content_container
    bind_resize_controls(state)

    states[c] = state
    c.opencode_sidecar_width = 0

    local geometry_signals = {
        "property::x",
        "property::y",
        "property::width",
        "property::height",
        "property::screen",
        "property::minimized",
        "property::hidden",
        "property::fullscreen",
        "property::active",
        "property::sticky",
        "tagged",
        "untagged",
    }
    for _, signal in ipairs(geometry_signals) do
        local watched_signal = signal
        c:connect_signal(signal, function()
            if watched_signal == "property::screen" then
                reclamp_state(state)
            else
                refresh(state)
            end
        end)
    end
    c:connect_signal("unmanage", function()
        stop_animation(state)
        state.expanded = false
        state.titlebar.visible = false
        state.panel.visible = false
        for _, tab in ipairs(state.tabs) do
            destroy_tab(tab)
        end
        if active_state == state then
            active_state = nil
        end
        states[c] = nil
    end)

    refresh(state)
    return state
end

local function get_state(c)
    return states[c] or make_state(c)
end

function sidecar.button(c)
    local state = states[c]
    if not state or #state.tabs == 0 then
        return nil
    end
    if not state.button then
        state.button = make_button(state)
    end
    return state.button
end

function sidecar.has_sidewindows(c)
    local state = states[c]
    return state ~= nil and #state.tabs > 0
end

function sidecar.toggle(c)
    if not sidecar.is_opencode(c) then
        return false
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return false
    end
    set_expanded(state, not state.expanded)
    return state.expanded
end

function sidecar.show(c)
    if not sidecar.is_opencode(c) then
        return false
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return false
    end
    set_expanded(state, true)
    return true
end

function sidecar.hide(c)
    if not sidecar.is_opencode(c) then
        return false
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return false
    end
    set_expanded(state, false, true)
    return true
end

function sidecar.resize(c, width)
    if not sidecar.is_opencode(c) then
        return false
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return false
    end
    return resize_state(state, width)
end

function sidecar.new(c, name)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    local state = get_state(c)
    if name == nil then
        name = generated_name(state)
    else
        local normalized, err = normalize_name(name)
        if not normalized then
            return "error: "..err
        end
        name = normalized
    end
    if find_tab_by_name(state, name) then
        return "error: sidewindow already exists: "..name
    end
    local _, index = append_tab(state, name)
    activate_index(state, index)
    return sidecar.status(c)
end

function sidecar.rename(c, name)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    local normalized, err = normalize_name(name)
    if not normalized then
        return "error: "..err
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return "error: no sidewindow exists"
    end
    local existing = find_tab_by_name(state, normalized)
    local tab = active_tab(state)
    if existing and existing ~= tab then
        return "error: sidewindow already exists: "..normalized
    end
    tab.name = normalized
    update_titlebar(state)
    return sidecar.status(c)
end

function sidecar.select(c, selector)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return "error: no sidewindow exists"
    end
    local _, index = resolve_tab(state, selector)
    if not index then
        return "error: sidewindow not found: "..tostring(selector)
    end
    activate_index(state, index)
    return sidecar.status(c)
end

function sidecar.next(c)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return "error: no sidewindow exists"
    end
    local index = (state.active_index % #state.tabs) + 1
    activate_index(state, index)
    return sidecar.status(c)
end

function sidecar.previous(c)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return "error: no sidewindow exists"
    end
    local index = ((state.active_index - 2) % #state.tabs) + 1
    activate_index(state, index)
    return sidecar.status(c)
end

function sidecar.remove(c, selector)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return "error: no sidewindow exists"
    end
    local tab = resolve_tab(state, selector)
    if not tab then
        return "error: sidewindow not found: "..tostring(selector)
    end

    remove_tab_from_state(state, tab)
    return sidecar.status(c)
end

function sidecar.list(c)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    local state = states[c]
    if not state or #state.tabs == 0 then
        return "none"
    end
    local result = {}
    for index, tab in ipairs(state.tabs) do
        local marker = index == state.active_index and "*" or ""
        table.insert(result, string.format("%s%d:%q", marker, index, tab.name))
    end
    return table.concat(result, " ")
end

function sidecar.open_terminal(c)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end

    local state = get_state(c)
    local tab, created = ensure_active_tab(state, "Terminal")
    local focus_before_launch = client.focus
    if is_valid(tab.hosted_client) then
        if tab.hosted_kind == "terminal" then
            set_expanded(state, true)
            return sidecar.status(c)
        end
        close_hosted(tab)
    end
    if tab.launching then
        if tab.hosted_kind == "terminal" then
            return sidecar.status(c)
        end
        close_hosted(tab)
    end

    tab.imagebox:set_image(nil)
    tab.image_path = nil
    tab.launching = true
    tab.hosted_kind = "terminal"
    prepare_launch_focus(tab, focus_before_launch)
    set_expanded(state, true)

    local pid = awful.spawn({
        "urxvt",
        "-name", hosted_terminal_instance,
        "-title", "SideWindow terminal: "..tab.name,
    }, {
        floating = true,
        skip_taskbar = true,
        titlebars_enabled = false,
        size_hints_honor = false,
        screen = c.screen,
        tag = c.first_tag,
    }, function(hosted)
        if not tab.removed and tab.launching
            and tab.hosted_kind == "terminal" then
            attach_hosted(tab, hosted, "terminal", true)
        else
            hosted:kill()
        end
    end)
    if not pid then
        tab.launching = false
        tab.hosted_kind = nil
        restore_launch_focus(tab)
        if created then
            discard_created_tab(state, tab)
        end
        return "error: unable to launch urxvt"
    end
    tab.hosted_pid = pid
    tab.launch_timer = gears.timer.start_new(45, function()
        if tab.removed or not tab.launching
            or tab.hosted_kind ~= "terminal" then
            return false
        end
        tab.launching = false
        tab.hosted_kind = nil
        tab.hosted_pid = nil
        restore_launch_focus(tab)
        if created then
            discard_created_tab(state, tab)
        else
            refresh(state)
        end
        return false
    end)
    return sidecar.status(c)
end

function sidecar.capture_firefox(c)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end

    local state = get_state(c)
    local tab, index = find_tab_by_role(state, "firefox-mcp")
    if not tab then
        tab, index = append_tab(state,
            unique_name(state, "Firefox MCP"), "firefox-mcp")
    end
    activate_index(state, index)

    local focus_before_launch = client.focus
    close_hosted(tab)
    tab.imagebox:set_image(nil)
    tab.image_path = nil
    tab.launching = true
    tab.hosted_kind = "firefox-mcp"
    prepare_launch_focus(tab, focus_before_launch)
    set_expanded(state, false, true)
    watch_for_hosted(tab, sidecar.is_firefox, "firefox-mcp", false, false)
    return sidecar.status(c)
end

function sidecar.open_firefox(c, url)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    if url == nil or url == "" then
        url = "about:blank"
    elseif type(url) ~= "string" then
        return "error: Firefox URL must be a string"
    end

    local state = get_state(c)
    local tab, created = ensure_active_tab(state, "Firefox")
    local focus_before_launch = client.focus
    if is_valid(tab.hosted_client) then
        if tab.hosted_kind == "firefox" then
            set_expanded(state, true)
            return sidecar.status(c)
        end
        close_hosted(tab)
    end
    if tab.launching then
        if tab.hosted_kind == "firefox" then
            return sidecar.status(c)
        end
        close_hosted(tab)
    end

    tab.imagebox:set_image(nil)
    tab.image_path = nil
    tab.launching = true
    tab.hosted_kind = "firefox"
    prepare_launch_focus(tab, focus_before_launch)
    set_expanded(state, true)
    watch_for_hosted(tab, sidecar.is_firefox, "firefox", true, created)

    local pid = awful.spawn({
        "/usr/local/bin/firefox-hardened",
        "--new-window", url,
    })
    if not pid then
        clear_launch_watch(tab)
        tab.launching = false
        tab.hosted_kind = nil
        restore_launch_focus(tab)
        if created then
            discard_created_tab(state, tab)
        end
        return "error: unable to launch firefox-hardened"
    end
    tab.hosted_pid = pid
    return sidecar.status(c)
end

function sidecar.close_terminal(c)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end

    local state = states[c]
    if not state or #state.tabs == 0 then
        return "error: no sidewindow exists"
    end
    local tab = active_tab(state)
    if tab.hosted_kind == "terminal" then
        close_hosted(tab)
    end
    refresh(state)
    return sidecar.status(c)
end

function sidecar.close_firefox(c)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end

    local state = states[c]
    if not state or #state.tabs == 0 then
        return "error: no sidewindow exists"
    end
    local tab = active_tab(state)
    if tab.hosted_kind == "firefox" or tab.hosted_kind == "firefox-mcp" then
        remove_tab_from_state(state, tab)
        return sidecar.status(c)
    end
    refresh(state)
    return sidecar.status(c)
end

function sidecar.set_image(c, path)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end
    if type(path) ~= "string" or path == "" then
        return "error: image path is empty"
    end

    local probe = wibox.widget.imagebox()
    if not probe:set_image(path) then
        return "error: unable to load image "..path
    end
    local state = get_state(c)
    local tab = ensure_active_tab(state, "Image")
    close_hosted(tab)
    tab.imagebox:set_image(path)
    tab.image_path = path
    set_expanded(state, true)
    return sidecar.status(c)
end

function sidecar.clear_image(c)
    if not sidecar.is_opencode(c) then
        return "error: target is not an OpenCode window"
    end

    local state = states[c]
    if not state or #state.tabs == 0 then
        return "error: no sidewindow exists"
    end
    local tab = active_tab(state)
    tab.imagebox:set_image(nil)
    tab.image_path = nil
    refresh(state)
    return sidecar.status(c)
end

function sidecar.status(c)
    local state = states[c]
    if not state or #state.tabs == 0 then
        return "empty right reserved=0 tab=0/0 name=none image=none app=none"
    end
    local geometry = state.titlebar:geometry()
    local tab = active_tab(state)
    local image = tab.image_path and " image="..tab.image_path
        or " image=none"
    local app = "none"
    if is_valid(tab.hosted_client) then
        app = string.format("%s:0x%x",
            tab.hosted_client.class or "unknown",
            tab.hosted_client.window or 0)
    elseif tab.launching then
        app = "launching:"..(tab.hosted_kind or "unknown")
    end
    return string.format(
        "%s %s %d,%d %dx%d reserved=%d tab=%d/%d name=%q",
        state.expanded and "expanded" or "collapsed",
        state.side, geometry.x, geometry.y,
        geometry.width, math.max(1, state.client.height),
        state.client.opencode_sidecar_width or 0,
        state.active_index, #state.tabs, tab.name)..image.." app="..app
end

tag.connect_signal("property::selected", function()
    for _, state in pairs(states) do
        refresh(state)
    end
end)

screen.connect_signal("property::geometry", function()
    for _, state in pairs(states) do
        reclamp_state(state)
    end
end)

screen.connect_signal("property::workarea", function()
    for _, state in pairs(states) do
        reclamp_state(state)
    end
end)

client.connect_signal("property::fullscreen", function()
    for _, state in pairs(states) do
        refresh(state)
    end
end)

return sidecar

-- vim:set et sw=4 ts=4:
