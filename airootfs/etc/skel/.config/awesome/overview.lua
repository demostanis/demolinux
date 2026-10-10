awesome.register_xproperty("WM_NAME", "string")
awesome.register_xproperty("OVERVIEW_SHADOW_SUPPRESSED", "number")
awesome.register_xproperty("OVERVIEW_REAL_HIDDEN", "number")
awesome.register_xproperty("OVERVIEW_PARTICIPANT", "number")

local schedule_image_gc = require("imagegc")
local lgi = require("lgi")
local Gdk = lgi.require("Gdk", "3.0")
Gdk.init({})
local content_cache = {}
local active_quit
local closing = false
local reopen_requested = false
local request_overview
local last_visible_content = setmetatable({}, { __mode = "k" })

local function snapshot_visible_content(c)
    if not c.valid or c.minimized or c.hidden or c.is_minimized_tab
        or not c:isvisible() then
        return nil
    end

    local ok, snapshot = pcall(function()
        local su = gears.surface(c.content)
        local width, height = gears.surface.get_size(su)
        if width <= 0 or height <= 0 then return nil end

        local image = last_visible_content[c]
        if image then
            local old_width, old_height = gears.surface.get_size(image)
            if old_width ~= width or old_height ~= height then
                image = nil
            end
        end
        if not image then
            image = cairo.ImageSurface.create(cairo.Format.ARGB32, width, height)
            last_visible_content[c] = image
        end
        local cr = cairo.Context(image)
        cr:set_operator(cairo.Operator.SOURCE)
        cr:set_source_surface(su, 0, 0)
        cr:paint()
        image:flush()
        schedule_image_gc()
        return image
    end)
    if ok then return snapshot end
end

client.connect_signal("focus", snapshot_visible_content)
gears.timer.delayed_call(function()
    for _, c in ipairs(client.get()) do
        snapshot_visible_content(c)
    end
end)

local function draw(c, cache_content, active)
    local geo = c:geometry()
    local content = cairo.ImageSurface.create(cairo.Format.ARGB32, geo.width, geo.height)
    local cr = cairo.Context(content)
    local su

    su = content_cache[c] or snapshot_visible_content(c) or last_visible_content[c]
    if not su then
        local ok, current = pcall(function() return gears.surface(c.content) end)
        if ok then su = current end
    end
    if cache_content then
        content_cache[c] = su
    end

    local titlebarheight = 0
    if c._private.titlebars then
        local titlebar = c._private.titlebars.top.drawable
        titlebar:_do_redraw()
        local titlebarsu = gears.surface(titlebar.drawable.surface)
        titlebarheight = titlebar.drawable:geometry().height

        cr:set_source_surface(titlebarsu, 0, 0)
        cr:paint()
    end
    if su then
        cr:set_source_surface(su, 0, titlebarheight)
        cr:paint()
    end

    for side, bar in pairs(c._private.titlebars or {}) do
        if side ~= "top" then
            local drawable = bar.drawable
            local native = drawable.drawable
            local bar_geometry = native:geometry()
            if bar_geometry.width > 0 and bar_geometry.height > 0 then
                drawable:_do_redraw()
                cr:set_source_surface(gears.surface(native.surface),
                    bar_geometry.x - geo.x, bar_geometry.y - geo.y)
                cr:paint()
            end
        end
    end

    if not active then
        cr:set_source_rgba(0, 0, 0, 0.3)
        cr:paint()
    end

    schedule_image_gc()
    return content
end

local function show_overview()
    local s = mouse.screen
    if active_quit or (overview_shown and not s.mypanel.visible) then return end
    local all_popups = {}
    local has_quitted_overview = false
    local previous_client_focus = client.focus
    local overview_clients = {}
    local filter_popup = nil
    local grabber = nil
    local entering = true
    local previews = {}
    local original_geometries = {}
    local pending_focus = nil
    local transition_duration = 0.3
    local chrome_snapshots = {}
    local chrome_layers = {}
    local preview_images = {}
    local thaw_dock
    local input_shield

    local function raise_chrome()
        local command = {"xdotool"}
        for _, saved in ipairs(chrome_layers) do
            saved.bar.ontop = true
            command[#command+1] = "windowraise"
            command[#command+1] = string.format("%.0f", saved.bar.window)
        end
        for _, frozen in ipairs(chrome_snapshots) do
            frozen.ontop = true
            command[#command+1] = "windowraise"
            command[#command+1] = string.format("%.0f", frozen.window)
        end
        if #command > 1 then awful.spawn(command) end
    end

    local function freeze_dock_updates()
        s.mydock:set_overview_frozen(true)
        thaw_dock = function()
            s.mydock:set_overview_frozen(false)
            thaw_dock = nil
        end
    end

    local function freeze_chrome()
        freeze_dock_updates()
        local root_window = Gdk.get_default_root_window()
        for _, name in ipairs({"mywibar", "mydock"}) do
            local bar = s[name]
            if bar and bar.visible then
                table.insert(chrome_layers, {bar = bar, ontop = bar.ontop})
                local geometry = bar:geometry()
                local image = cairo.ImageSurface.create(cairo.Format.ARGB32,
                    geometry.width, geometry.height)
                local cr = cairo.Context(image)
                cr:set_operator(cairo.Operator.SOURCE)
                local pixbuf = root_window and Gdk.pixbuf_get_from_window(root_window,
                    geometry.x, geometry.y, geometry.width, geometry.height)
                if pixbuf then
                    Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0)
                else
                    cr:set_source_surface(gears.surface(bar.drawable.surface), 0, 0)
                end
                cr:paint()
                image:flush()
                local frozen = wibox{
                    screen = s,
                    x = geometry.x, y = geometry.y,
                    width = geometry.width, height = geometry.height,
                    ontop = true, visible = false,
                    input_passthrough = false,
                    bg = gears.color.transparent,
                    widget = wibox.widget{
                        image = image,
                        widget = wibox.widget.imagebox,
                    },
                }
                frozen:set_xproperty("WM_NAME", "overview_chrome_snapshot")
                frozen.visible = true
                table.insert(chrome_snapshots, frozen)
            end
        end
        schedule_image_gc()
    end

    local function resize_preview(popup, geometry)
        popup:geometry(geometry)
    end

    local function free_popups()
        for i, popup in ipairs(all_popups) do
            popup.is_free = true
        end
    end
    local function hide_free_popups()
        for i, popup in ipairs(all_popups) do
            if popup.is_free then
                popup.visible = false
            end
        end
    end

    local function quit_overview()
        if has_quitted_overview then return end
        has_quitted_overview = true
        closing = true
        if grabber then awful.keygrabber.stop(grabber) end
        if filter_popup then filter_popup.visible = false end
        for _, popup in ipairs(all_popups) do
            if not popup.overview_preview then popup.visible = false end
        end
        for c, popup in pairs(previews) do
            if c.valid and popup.visible and popup.overview_client == c
                and original_geometries[c] then
                resize_preview(popup, original_geometries[c])
            end
        end
        gears.timer.start_new(transition_duration + 0.06, function()
            local target = pending_focus or previous_client_focus
            if target and target.valid then
                if pending_focus then target.minimized = false end
                client.focus = target
                target:raise()
            end
            awful.layout.arrange(s)
            for c in pairs(original_geometries) do
                if c.valid then c:set_xproperty("OVERVIEW_REAL_HIDDEN", 0) end
            end
            awesome.emit_signal("overview::display", false)
            gears.timer.start_new(0.12, function()
                for _, popup in ipairs(all_popups) do popup.visible = false end
                for c in pairs(original_geometries) do
                    if c.valid then
                        c:set_xproperty("OVERVIEW_SHADOW_SUPPRESSED", 0)
                    end
                end
                for _, saved in ipairs(chrome_layers) do saved.bar.ontop = saved.ontop end
                if thaw_dock then thaw_dock() end
                for _, c in ipairs(overview_clients) do
                    if c.valid then c.keybinds = nil end
                end
                content_cache = {}
                gears.timer.start_new(0.08, function()
                    for _, frozen in ipairs(chrome_snapshots) do frozen.visible = false end
                    if input_shield then input_shield.visible = false end
                    for c in pairs(original_geometries) do
                        if c.valid then c:set_xproperty("OVERVIEW_PARTICIPANT", 0) end
                    end
                    overview_shown = false
                    active_quit = nil
                    closing = false
                    for _, popup in ipairs(all_popups) do
                        popup:buttons({})
                        popup.widget = nil
                    end
                    preview_images = {}
                    if reopen_requested then
                        reopen_requested = false
                        gears.timer.delayed_call(request_overview)
                    end
                    return false
                end)
                return false
            end)
            return false
        end)
    end

    local keys = "fjdksla"
    local comb_1 = {}
    local comb_2 = {}

    for i=1,#keys do
        comb_1[i] = keys:sub(i, i)
    end
    for i=1,#keys do
        for j=1,#keys do
            table.insert(comb_2,
                string.char(keys:byte(i))
                    ..
                string.char(keys:byte(j))
                )
        end
    end

    local function focus_client(c)
        pending_focus = c
        quit_overview()
    end

    local function draw_clients(clients, filter)
        for _, c in ipairs(clients) do
            if not c.keybinds then
                local comb = comb_1
                if #clients > #keys then
                    comb = comb_2
                end
                c.keybinds = table.remove(comb, 1)
            end
        end

        -- Map each line to a table of clients
        -- 3 clients for uneven lines, 2 for even ones
        local window_count_in_line = 3
        local index_in_line = 0
        local line_index = 1
        local lines = {}
        for _, c in ipairs(clients) do
            index_in_line = index_in_line + 1
            if index_in_line > window_count_in_line then
                index_in_line = 0
                if window_count_in_line == 2 then
                    window_count_in_line = 3
                else
                    window_count_in_line = 2
                end
                line_index = line_index + 1
            end
            if not lines[line_index] then
                table.insert(lines, {})
            end
            table.insert(lines[line_index], c)
        end

        -- Calculate a global aspect ratio for
        -- each window to be able to fit without overlap
        -- in the whole screen
        local screen_diagonal = math.sqrt((s.geometry.width-beautiful.dock_width)^2+s.geometry.height^2)-dpi(100)
        local total_height = 0
        local diagonal = 0
        for _, c in ipairs(clients) do
            local geo = c:geometry()
            local cdw = math.sqrt(geo.width^2+geo.height^2)
            diagonal = diagonal + cdw
        end
        local ratio = diagonal > 0 and (screen_diagonal/diagonal+0.05*(#lines-1)) or 1
        local widest_row, unscaled_height = 0, 0
        for _, line in ipairs(lines) do
            local row_width, row_height = 0, 0
            for _, c in ipairs(line) do
                row_width = row_width + c.width
                row_height = math.max(row_height, c.height)
            end
            widest_row = math.max(widest_row, row_width)
            unscaled_height = unscaled_height + row_height
        end
        if widest_row > 0 and unscaled_height > 0 then
            ratio = math.min(ratio, 1,
                (s.geometry.width - dpi(100)) / widest_row,
                (s.geometry.height - beautiful.wibar_height - beautiful.dock_width - dpi(100)) / unscaled_height)
        end

        -- Calculate the height of all lines by
        -- summing the biggest clients of each line
        local total_height = 0
        for i, line in ipairs(lines) do
            local biggest_client = 0
            for _, c in ipairs(line) do
                if c:geometry().height > biggest_client then
                    biggest_client = c:geometry().height*ratio
                end
            end
            total_height = total_height + biggest_client
        end

        local last_height = 0
        for i, line in ipairs(lines) do
            local line_width = 0
            local last_widths = 0
            local biggest_client_in_line = 0

            for _, c in ipairs(line) do
                if c:geometry().height > biggest_client_in_line then
                    biggest_client_in_line = c:geometry().height*ratio
                end
            end
            for _, c in ipairs(line) do
                line_width = line_width + c:geometry().width*ratio
            end

            for j, c in ipairs(line) do
                local geo = c:geometry()
                if not original_geometries[c] then
                    original_geometries[c] = {x=geo.x, y=geo.y, width=geo.width, height=geo.height}
                end
                local content = preview_images[c]
                if not content then
                    content = draw(c, true, c == previous_client_focus)
                    preview_images[c] = content
                end
                c:set_xproperty("OVERVIEW_SHADOW_SUPPRESSED", 1)
                c:set_xproperty("OVERVIEW_PARTICIPANT", 1)

                local popups = {}
                local function new_popup(args)
                    local mypopup
                    local found_popup = false
                    for _, free_popup in ipairs(all_popups) do
                        if free_popup.is_free
                            and (free_popup.overview_preview == true) == (args.overview_preview == true) then
                            free_popup.is_free = false
                            found_popup = true
                            for k, v in pairs(args) do
                                free_popup[k] = v
                            end
                            free_popup.visible = args.visible ~= false
                            mypopup = free_popup
                            break
                        end
                    end
                    if not found_popup then
                        if args.overview_preview then
                            args.overview_preview = nil
                            mypopup = wibox(args)
                        else
                            mypopup = awful.popup(args)
                        end
                        table.insert(all_popups, mypopup)
                    end
                    table.insert(popups, mypopup)
                    return mypopup
                end

                if not c.minimized then
                    original_geometries[c].was_visible = true
                    if not entering then c:set_xproperty("OVERVIEW_REAL_HIDDEN", 1) end
                end

                local popup_x = s.geometry.x+last_widths+(s.geometry.width-line_width)/(#line+1)*j
                local popup_y = s.geometry.y+(last_height+(s.geometry.height-total_height)/(#lines+1)*i)-(beautiful.wibar_height-beautiful.dock_width)/2+(biggest_client_in_line-geo.height*ratio)/2

                local target_geometry = {
                    x = math.floor(popup_x), y = math.floor(popup_y),
                    width = math.max(1, math.floor(geo.width*ratio)),
                    height = math.max(1, math.floor(geo.height*ratio)),
                }
                local animate = entering and original_geometries[c].was_visible
                local initial_geometry = animate and original_geometries[c] or target_geometry
                local content_popup = new_popup{
                    overview_preview = true,
                    visible = false,
                    widget = wibox.widget{
                        widget = wibox.widget.imagebox,
                        image = content,
                    },
                    x = initial_geometry.x,
                    y = initial_geometry.y,
                    width = initial_geometry.width,
                    height = initial_geometry.height,
                    ontop = true,
                }
                content_popup.overview_preview = true
                content_popup.overview_client = c
                content_popup:set_xproperty("WM_NAME", "overview_client_preview")
                content_popup.visible = true
                previews[c] = content_popup
                if animate then
                    gears.timer.start_new(0.06, function()
                        if has_quitted_overview then return false end
                        if c.valid then c:set_xproperty("OVERVIEW_REAL_HIDDEN", 1) end
                        resize_preview(content_popup, target_geometry)
                        return false
                    end)
                end

                local icon_popup = new_popup{
                    widget = wibox.widget{
                        widget = awful.widget.clienticon,
                        forced_width = dpi(64),
                        forced_height = dpi(64),
                        client = c
                    },
                    x = popup_x+(geo.width*ratio/2)-dpi(32),
                    y = popup_y+geo.height*ratio-dpi(32),
                    bg = gears.color.transparent,
                    visible = false,
                    ontop = true,
                }
                icon_popup:set_xproperty("WM_NAME", "overview_client_icon")
                icon_popup.visible = not animate

                local titlew = wibox.widget{
                    {
                        {
                            widget = wibox.widget.textbox,
                            font = beautiful.bold_font,
                            text = c.keybinds,
                        },
                        widget = wibox.container.margin,
                        margins = dpi(5)
                    },
                    widget = wibox.container.background,
                    bg = beautiful.color4,
                    fg = beautiful.color7
                }
                local w, h = wibox.widget.base.fit_widget(titlew,
                    {dpi = xresources.get_dpi()}, titlew, 9999, 9999)
                local label_popup = new_popup{
                    widget = titlew,
                    x = popup_x+(geo.width*ratio/2)-w/2,
                    y = popup_y+(geo.height*ratio/2)-h/2,
                    visible = false,
                    ontop = true,
                }
                label_popup:set_xproperty("WM_NAME", "overview_client_label")
                label_popup.visible = not animate

                if animate then
                    gears.timer.start_new(transition_duration + 0.08, function()
                        if not has_quitted_overview then
                            for _, popup in ipairs(popups) do popup.visible = true end
                            raise_chrome()
                        end
                        return false
                    end)
                end

                for _, popup in ipairs(popups) do
                    popup._signals["mouse::enter"] = nil
                    popup._signals["mouse::leave"] = nil

                    popup:buttons(gears.table.join(
                        awful.button({ }, 1, function()
                            focus_client(c)
                        end)
                    ))
                end

                last_widths = last_widths + geo.width*ratio
            end

            last_height = last_height + biggest_client_in_line
        end

        if filter then
            local filterw = wibox.widget{
                {
                    {
                        widget = wibox.widget.textbox,
                        text = filter
                    },
                    widget = wibox.container.margin,
                    margins = dpi(10)
                },
                widget = wibox.container.background,
                bg = beautiful.bg_normal,
                shape = rrect(),
                shape_border_width = dpi(2)
            }
            local w, h = wibox.widget.base.fit_widget(filterw,
                {dpi = xresources.get_dpi()}, filterw, 9999, 9999)

            local x = s.geometry.x+s.geometry.width/2-w/2
            local y = s.geometry.y+s.geometry.height*0.8
            if filter_popup then
                filter_popup.x = x
                filter_popup.y = y
                filter_popup.widget = filterw
            else
                filter_popup = awful.popup{
                    ontop = true,
                    visible = false,
                    x = x,
                    y = y,
                    widget = filterw
                }
                filter_popup:set_xproperty("WM_NAME", "overview_filter")
            end
        end
        if filter_popup then
            filter_popup.visible = filter ~= ""
        end
        raise_chrome()
    end

    local all_clients = s.selected_tag:clients()
    local clients = {}
    for _, c in ipairs(all_clients) do
        if not c.is_minimized_tab and not c.opencode_sidecar_hosted then
            table.insert(clients, c)
        end
    end
    if #clients == 0 then return end
    table.sort(clients, function(a, b) return a.x < b.x end)
    overview_clients = clients
    active_quit = quit_overview
    if s.mypanel.visible then
        s.mypanel:hide()
        previous_client_focus = client.focus
    end
    freeze_chrome()
    input_shield = wibox{
        screen = s,
        x = s.geometry.x, y = s.geometry.y,
        width = s.geometry.width, height = s.geometry.height,
        ontop = true, visible = false,
        input_passthrough = false,
        bg = gears.color.transparent,
    }
    input_shield:set_xproperty("WM_NAME", "overview_input_shield")
    input_shield.visible = true
    overview_shown = true
    draw_clients(clients)
    entering = false
    awesome.emit_signal("overview::display", true)

    local filter = ""
    local is_ctrling = false
    grabber = awful.keygrabber.run(function(mods, key, status)
        if status == "release" then return end

        local is_mod4 = false
        for _, mod in ipairs(mods) do
            if mod == "Mod4" then
                is_mod4 = true
            end
        end

        if key == "Escape" or (is_mod4 and key == "o") then
            quit_overview()
            return
        elseif key == "Shift_L" then
            -- ignore key
        elseif key == "Shift_R" then
            -- ignore key
        elseif key == "BackSpace" then
            filter = filter:sub(1, -2)
        elseif key == "u" and is_ctrling then
            filter = ""
        elseif #key == 1 and #mods == 0 then
            filter = filter .. key
        end

        is_ctrling = key == "Control_R" or key == "Control_L"

        local filtered_clients = {}
        for _, c in ipairs(clients) do
            if c.valid and c.keybinds and c.keybinds:lower():sub(1, #filter) == filter:lower() then
                table.insert(filtered_clients, c)
            end
        end
        free_popups()
        if #filtered_clients == 1 then
            local c = filtered_clients[1]
            focus_client(c)
        else
            draw_clients(filtered_clients, filter)
            hide_free_popups()
        end
    end)
end

awesome.connect_signal("overview::hide", function()
    if active_quit then active_quit() end
end)

request_overview = function()
    if closing then
        reopen_requested = true
        return
    end
    if active_quit then
        active_quit()
        return
    end
    local ok, err = xpcall(show_overview, debug.traceback)
    if not ok then
        if active_quit then active_quit() end
        gears.debug.print_error(err)
    end
end

return request_overview

-- vim:set et sw=4 ts=4:
