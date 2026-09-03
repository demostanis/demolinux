local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")
local cairo = require("lgi").cairo

local base = wibox.widget.base
local dpi = beautiful.xresources.apply_dpi

local function client_is_valid(c)
    return c and c.valid
end

local function client_is_shown(c, s)
    if not client_is_valid(c) or c.screen ~= s then
        return false
    end
    if c.hidden or c.minimized or c.skip_taskbar or c.is_minimized_tab then
        return false
    end

    local ok, visible = pcall(function()
        return c:isvisible()
    end)
    return ok and visible
end

local function client_surface(c)
    local ok, surface = pcall(function()
        local content = c.content
        if not content then
            return nil
        end
        return gears.surface(content)
    end)
    return ok and surface or nil
end

local function draw_surface(cr, surface, width, height, cover, alpha)
    if not surface then
        return false
    end

    local ok, surface_width, surface_height = pcall(
        gears.surface.get_size, surface
    )
    if not ok or surface_width <= 0 or surface_height <= 0 then
        return false
    end

    local scale_x = width / surface_width
    local scale_y = height / surface_height
    local scale = cover and math.max(scale_x, scale_y)
        or math.min(scale_x, scale_y)
    local drawn_width = surface_width * scale
    local drawn_height = surface_height * scale

    cr:save()
    cr:rectangle(0, 0, width, height)
    cr:clip()
    cr:translate(
        math.floor((width - drawn_width) / 2),
        math.floor((height - drawn_height) / 2)
    )
    cr:scale(scale, scale)
    cr:set_source_surface(surface, 0, 0)
    cr:paint_with_alpha(alpha)
    cr:restore()
    return true
end

local function titlebar_surface(c)
    local ok, surface = pcall(function()
        local bars = c._private and c._private.titlebars
        local titlebar = bars and bars.top
        local drawable = titlebar and titlebar.drawable
        local native = drawable and drawable.drawable
        if not native or not native.surface
            or native:geometry().height <= 0 then
            return nil
        end
        return gears.surface(native.surface)
    end)
    return ok and surface or nil
end

local function surface_size(surface)
    if not surface then
        return 0, 0
    end
    local ok, width, height = pcall(gears.surface.get_size, surface)
    if not ok then
        return 0, 0
    end
    return width, height
end

local function client_snapshot(c, height, max_width)
    local content = client_surface(c)
    local titlebar = titlebar_surface(c)
    local content_width, content_height = surface_size(content)
    local titlebar_width, titlebar_height = surface_size(titlebar)
    local full_width = math.max(content_width, titlebar_width, c.width or 1)
    local full_height = content_height + titlebar_height
    if full_height <= 0 then
        full_height = math.max(1, c.height or 1)
    end

    height = math.max(1, math.floor(height))
    local width = math.max(1, math.floor(
        height * full_width / full_height + 0.5
    ))
    if max_width and width > max_width then
        local scale = max_width / width
        width = math.max(1, math.floor(max_width))
        height = math.max(1, math.floor(height * scale + 0.5))
    end
    if not content and not titlebar then
        return nil, width, height
    end

    local snapshot = cairo.ImageSurface.create(cairo.Format.ARGB32, width, height)
    local cr = cairo.Context(snapshot)
    local scale = math.min(width / full_width, height / full_height)
    local offset_x = (width - full_width * scale) / 2
    local offset_y = (height - full_height * scale) / 2

    cr:save()
    cr:rectangle(0, 0, width, height)
    cr:clip()
    cr:translate(offset_x, offset_y)
    cr:scale(scale, scale)
    if titlebar then
        cr:set_source_surface(titlebar, (full_width - titlebar_width) / 2, 0)
        cr:paint()
    end
    if content then
        cr:set_source_surface(
            content,
            (full_width - content_width) / 2,
            titlebar_height
        )
        cr:paint()
    end
    cr:restore()
    snapshot:flush()
    return snapshot, width, height
end

local function make_thumbnail(c, height)
    local thumbnail = base.make_widget(nil, nil, { enable_properties = true })
    thumbnail.client = c
    local width
    thumbnail.content, width = client_snapshot(c, height)
    thumbnail.alpha = 0.72

    function thumbnail:fit(_, width, height)
        return width, height
    end

    function thumbnail:draw(_, cr, width, height)
        draw_surface(
            cr,
            self.content,
            width,
            height,
            true,
            self.alpha
        )
    end

    return thumbnail, width
end

return function(s)
    local preview_height = beautiful.window_preview_height or dpi(30)
    local alive = true

    local strip = base.make_widget(nil, nil, { enable_properties = true })
    strip._private.items = {}

    local item_by_client = {}
    local zoom_client
    local zoom_timer
    local zoom_image = wibox.widget {
        resize = true,
        widget = wibox.widget.imagebox,
    }
    local zoom_popup = awful.popup {
        widget = zoom_image,
        screen = s,
        visible = false,
        ontop = true,
        type = "tooltip",
        input_passthrough = true,
        bg = beautiful.window_preview_bg or beautiful.bg_normal,
    }

    local function hide_zoom(c)
        if c and zoom_client ~= c then
            return
        end
        zoom_client = nil
        if zoom_timer then
            zoom_timer:stop()
            zoom_timer = nil
        end
        zoom_popup.visible = false
    end

    local function update_zoom(c)
        if not alive or overview_shown or not client_is_valid(c)
            or not s.mywibar or not s.mywibar.visible then
            hide_zoom(c)
            return
        end

        local zoom_height = beautiful.window_preview_zoom_height or dpi(260)
        local max_width = beautiful.window_preview_zoom_max_width or dpi(520)
        zoom_height = math.min(zoom_height, math.floor(s.geometry.height * 0.4))
        max_width = math.min(max_width, math.max(1, s.geometry.width - dpi(16)))
        local snapshot, snapshot_width, snapshot_height = client_snapshot(
            c,
            zoom_height,
            max_width
        )
        if not snapshot then
            hide_zoom(c)
            return
        end

        local display_width = snapshot_width
        local display_height = snapshot_height
        display_width = math.max(1, math.floor(display_width + 0.5))
        display_height = math.max(1, math.floor(display_height + 0.5))

        zoom_image.image = snapshot
        zoom_image.forced_width = display_width
        zoom_image.forced_height = display_height
        zoom_popup.width = display_width
        zoom_popup.height = display_height

        local screen_geometry = s.geometry
        local popup_x = mouse.coords().x - display_width / 2
        popup_x = math.max(
            screen_geometry.x + dpi(8),
            math.min(
                popup_x,
                screen_geometry.x + screen_geometry.width
                    - display_width - dpi(8)
            )
        )
        zoom_popup.x = math.floor(popup_x + 0.5)
        zoom_popup.y = s.mywibar.y + s.mywibar.height + dpi(6)
        zoom_popup.visible = true
    end

    local function schedule_zoom(c)
        zoom_client = c
        if zoom_timer then
            zoom_timer:stop()
        end
        zoom_timer = gears.timer.start_new(0.12, function()
            zoom_timer = nil
            if zoom_client == c then
                update_zoom(c)
            end
            return false
        end)
    end

    local function focused_preview_client()
        local focused = client.focus
        if not client_is_valid(focused) then
            return nil
        end
        if item_by_client[focused] then
            return focused
        end
        if focused.opencode_sidecar_owner
            and item_by_client[focused.opencode_sidecar_owner] then
            return focused.opencode_sidecar_owner
        end
        for c in pairs(item_by_client) do
            if client_is_valid(c)
                and c.master and c.master.active_slave == focused then
                return c
            end
        end
        return nil
    end

    local function item_is_active(item)
        return focused_preview_client() == item.client
    end

    local function update_item_state(item)
        local active = item_is_active(item)
        if active then
            item.widget.bg = beautiful.window_preview_focus_bg
                or beautiful.bg_normal
            item.widget.border_color = beautiful.window_preview_focus_color
                or beautiful.color1
            item.widget.border_width = dpi(2)
            item.thumbnail.alpha = 1
        elseif item.hovered then
            item.widget.bg = beautiful.window_preview_hover_bg
                or beautiful.bg_normal
            item.widget.border_width = 0
            item.thumbnail.alpha = 0.94
        else
            item.widget.bg = beautiful.window_preview_bg
                or beautiful.bg_normal
            item.widget.border_width = 0
            item.thumbnail.alpha = 0.72
        end
        item.thumbnail:emit_signal("widget::redraw_needed")
    end

    local function update_states()
        if not alive then
            return
        end
        for _, item in ipairs(strip._private.items) do
            update_item_state(item)
        end
    end

    local function activate_client(c)
        if overview_shown or not client_is_valid(c) then
            return
        end
        local target = c.master and c.master.active_slave or c
        if not client_is_valid(target) then
            return
        end
        target.minimized = false
        target:emit_signal(
            "request::activate",
            "wibar_preview",
            { raise = true }
        )
    end

    local function make_item(c)
        local thumbnail, preview_width = make_thumbnail(c, preview_height)
        local card = wibox.widget {
            thumbnail,
            bg = beautiful.window_preview_bg or beautiful.bg_normal,
            border_width = 0,
            widget = wibox.container.background,
        }
        local item = {
            client = c,
            hovered = false,
            visible = false,
            preview_width = preview_width,
            thumbnail = thumbnail,
            widget = card,
        }

        card:connect_signal("mouse::enter", function()
            item.hovered = true
            update_item_state(item)
            schedule_zoom(c)
        end)
        card:connect_signal("mouse::leave", function()
            item.hovered = false
            update_item_state(item)
            hide_zoom(c)
        end)
        card:buttons(gears.table.join(
            awful.button({}, 1, function()
                activate_client(c)
            end)
        ))
        return item
    end

    local function refresh_item(item)
        if not item or not client_is_valid(item.client) then
            return
        end
        local snapshot, new_width = client_snapshot(
            item.client,
            preview_height
        )
        if item.preview_width ~= new_width then
            item.preview_width = new_width
            strip:emit_signal("widget::layout_changed")
        end
        item.thumbnail.content = snapshot
        item.thumbnail:emit_signal("widget::redraw_needed")
    end

    function strip:get_children()
        local children = {}
        for _, item in ipairs(self._private.items) do
            table.insert(children, item.widget)
        end
        return children
    end

    function strip:fit(_, width, height)
        if #self._private.items == 0 then
            return 0, 0
        end
        local wanted = 0
        for _, item in ipairs(self._private.items) do
            wanted = wanted + item.preview_width
        end
        return math.min(width, wanted), math.min(height, preview_height)
    end

    function strip:layout(_, width, height)
        local items = self._private.items
        if #items == 0 or width <= 0 or height <= 0 then
            hide_zoom()
            for _, item in ipairs(items) do
                item.visible = false
            end
            return {}
        end

        local natural_height = math.min(height, preview_height)
        local natural_scale = natural_height / preview_height
        local widths = {}
        local natural_total = 0
        for index, item in ipairs(items) do
            local item_width = item.preview_width * natural_scale
            widths[index] = item_width
            natural_total = natural_total + item_width
        end

        local overflow_scale = 1
        if natural_total > width then
            overflow_scale = width / natural_total
        end
        local card_height = natural_height * overflow_scale
        local total_width = natural_total * overflow_scale
        local start_x = math.max(0, (width - total_width) / 2)
        local y = math.max(0, math.floor((height - card_height) / 2))
        local result = {}
        local cumulative_width = 0
        for index, item in ipairs(items) do
            local left = math.floor(start_x + cumulative_width + 0.5)
            cumulative_width = cumulative_width
                + widths[index] * overflow_scale
            local right = math.floor(start_x + cumulative_width + 0.5)
            local item_width = right - left
            item.visible = item_width > 0
            if item.visible then
                table.insert(result, base.place_widget_at(
                    item.widget,
                    left,
                    y,
                    item_width,
                    card_height
                ))
            elseif zoom_client == item.client then
                hide_zoom(item.client)
            end
        end
        return result
    end

    local function collect_clients()
        local clients = {}
        for _, c in ipairs(s.clients) do
            if client_is_shown(c, s) then
                table.insert(clients, c)
            end
        end
        table.sort(clients, function(a, b)
            if a.x == b.x then
                if a.y == b.y then
                    return (a.window or 0) < (b.window or 0)
                end
                return a.y < b.y
            end
            return a.x < b.x
        end)
        return clients
    end

    local function same_clients(clients)
        if #clients ~= #strip._private.items then
            return false
        end
        for index, c in ipairs(clients) do
            if strip._private.items[index].client ~= c then
                return false
            end
        end
        return true
    end

    local function rebuild()
        if not alive then
            return
        end
        local clients = collect_clients()
        if same_clients(clients) then
            update_states()
            return
        end

        local items = {}
        hide_zoom()
        item_by_client = {}
        for _, c in ipairs(clients) do
            local item = make_item(c)
            table.insert(items, item)
            item_by_client[c] = item
        end
        strip._private.items = items
        update_states()
        strip:emit_signal("widget::layout_changed")
        strip:emit_signal("widget::redraw_needed")
    end

    local rebuild_timer
    local function schedule_rebuild()
        if not alive or rebuild_timer then
            return
        end
        rebuild_timer = gears.timer.start_new(0.06, function()
            rebuild_timer = nil
            rebuild()
            return false
        end)
    end

    local dirty_clients = {}
    local content_timer
    local function schedule_content_update(c)
        if not alive then
            return
        end
        if item_by_client[c] then
            dirty_clients[c] = true
        end
        if content_timer or not next(dirty_clients) then
            return
        end
        content_timer = gears.timer.start_new(0.12, function()
            content_timer = nil
            for dirty in pairs(dirty_clients) do
                local item = item_by_client[dirty]
                if item and client_is_valid(dirty) then
                    refresh_item(item)
                end
                dirty_clients[dirty] = nil
            end
            return false
        end)
    end

    local rebuild_signals = {
        "list",
        "manage",
        "unmanage",
        "tagged",
        "untagged",
        "swapped",
        "property::hidden",
        "property::minimized",
        "property::screen",
        "property::skip_taskbar",
    }
    local content_signals = {
        "property::content",
        "property::width",
        "property::height",
    }
    local function update_name(c)
        if zoom_client == c and zoom_popup.visible then
            gears.timer.delayed_call(function()
                if alive and zoom_client == c then
                    update_zoom(c)
                end
            end)
        end
    end
    local function focus_changed(c)
        update_states()
        gears.timer.delayed_call(function()
            if alive then
                refresh_item(item_by_client[c])
            end
        end)
    end
    local function focus_cleared(c)
        gears.timer.delayed_call(function()
            update_states()
            refresh_item(item_by_client[c])
        end)
    end
    local function selected_tag_changed(t)
        if t.screen == s then
            schedule_rebuild()
        end
    end

    local order_timer = gears.timer {
        timeout = 0.25,
        single_shot = true,
        callback = rebuild,
    }
    local function schedule_order_rebuild()
        if alive then
            order_timer:again()
        end
    end

    for _, signal in ipairs(rebuild_signals) do
        client.connect_signal(signal, schedule_rebuild)
    end
    for _, signal in ipairs(content_signals) do
        client.connect_signal(signal, schedule_content_update)
    end
    client.connect_signal("property::name", update_name)
    client.connect_signal("focus", focus_changed)
    client.connect_signal("unfocus", focus_cleared)
    client.connect_signal("property::x", schedule_order_rebuild)
    client.connect_signal("property::y", schedule_order_rebuild)
    tag.connect_signal("property::selected", selected_tag_changed)

    local refresh_index = 0
    local zoom_refresh_due = false
    local refresh_timer = gears.timer {
        timeout = beautiful.window_preview_refresh_interval or 0.5,
        autostart = true,
        callback = function()
            if not alive or not s.mywibar or not s.mywibar.visible then
                hide_zoom()
                return
            end
            if #strip._private.items > 0 then
                local refreshed = {}
                local focused = focused_preview_client()
                local focused_item = focused and item_by_client[focused]
                if focused_item and focused_item.visible
                    and client_is_valid(focused_item.client) then
                    refresh_item(focused_item)
                    refreshed[focused_item] = true
                end

                local count = #strip._private.items
                for offset = 1, count do
                    local index = ((refresh_index + offset - 1) % count) + 1
                    local item = strip._private.items[index]
                    if item.visible and not refreshed[item]
                        and client_is_valid(item.client) then
                        refresh_item(item)
                        refresh_index = index
                        break
                    end
                end
                strip:emit_signal("widget::redraw_needed")
            end
            if zoom_client and zoom_popup.visible then
                zoom_refresh_due = not zoom_refresh_due
                if zoom_refresh_due then
                    update_zoom(zoom_client)
                end
            else
                zoom_refresh_due = false
            end
        end,
    }

    local function cleanup(removed)
        if removed ~= s or not alive then
            return
        end
        alive = false
        if rebuild_timer then
            rebuild_timer:stop()
        end
        if content_timer then
            content_timer:stop()
        end
        order_timer:stop()
        refresh_timer:stop()
        hide_zoom()
        for _, signal in ipairs(rebuild_signals) do
            client.disconnect_signal(signal, schedule_rebuild)
        end
        for _, signal in ipairs(content_signals) do
            client.disconnect_signal(signal, schedule_content_update)
        end
        client.disconnect_signal("property::name", update_name)
        client.disconnect_signal("focus", focus_changed)
        client.disconnect_signal("unfocus", focus_cleared)
        client.disconnect_signal("property::x", schedule_order_rebuild)
        client.disconnect_signal("property::y", schedule_order_rebuild)
        tag.disconnect_signal("property::selected", selected_tag_changed)
        screen.disconnect_signal("removed", cleanup)
    end
    screen.connect_signal("removed", cleanup)

    rebuild()
    return strip
end

-- vim:set et sw=4 ts=4:
