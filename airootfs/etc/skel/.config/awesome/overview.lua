-- This is used to give a specific name to icon popups,
-- to tell picom not to give them a shadow
awesome.register_xproperty("WM_NAME", "string")

local content_cache = {}
function draw(c, cache_content)
    local geo = c:geometry()
    local content = cairo.ImageSurface.create(cairo.Format.ARGB24, geo.width, geo.height)
    local cr = cairo.Context(content)
    local su

    su = content_cache[c] or gears.surface(c.content)
    if cache_content then
        content_cache[c] = su
    end

    local titlebar = c._private.titlebars.top.drawable
    if c.active_in_overview then
        titlebar:set_bg(beautiful.bg_focus)
        titlebar:set_fg(beautiful.fg_focus)
    else
        titlebar:set_bg(beautiful.bg_normal)
        titlebar:set_fg(beautiful.fg_normal)
    end
    titlebar:_do_redraw()
    local titlebarsu = gears.surface(titlebar.drawable.surface)
    local titlebarheight = titlebar.drawable:geometry().height

    cr:set_source_surface(titlebarsu, 0, 0)
    cr:paint()
    cr:set_source_surface(su, 0, titlebarheight)
    cr:paint()

    return content
end

return function()
    local s = mouse.screen
    local all_popups = {}
    local has_quitted_overview = false
    local previously_visible_clients = {}
    local filter_popup = nil
    local grabber = nil

    function free_popups()
        for i, popup in ipairs(all_popups) do
            popup.is_free = true
        end
    end
    function hide_free_popups()
        for i, popup in ipairs(all_popups) do
            if popup.is_free then
                popup.visible = false
            end
        end
    end

    local function quit_overview(clients)
        if filter_popup then
            filter_popup.visible = false
        end
        has_quitted_overview = true
        content_cache = {}
        free_popups()
        hide_free_popups()
        for _, c in ipairs(previously_visible_clients) do
            c.minimized = false
        end
        for _, c in ipairs(clients) do
            c.keybinds = nil
        end
        awful.keygrabber.stop(grabber)
        overview_shown = false
        awesome.emit_signal("overview::display", false)
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

    function draw_clients(clients, filter)
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
        local screen_diagonal = math.sqrt((s.geometry.width-beautiful.dock_width)^2+s.geometry.height^2)-100
        local total_height = 0
        local diagonal = 0
        for _, c in ipairs(clients) do
            local geo = c:geometry()
            local cdw = math.sqrt(geo.width^2+geo.height^2)
            diagonal = diagonal + cdw
        end
        local ratio = screen_diagonal/diagonal+0.05*(#lines-1)

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
                c.active_in_overview = false
                local geo = c:geometry()
                local content = draw(c, true)

                local popups = {}
                local function new_popup(args)
                    local mypopup
                    local found_popup = false
                    for _, free_popup in ipairs(all_popups) do
                        if free_popup.is_free then
                            free_popup.is_free = false
                            found_popup = true
                            for k, v in pairs(args) do
                                free_popup[k] = v
                            end
                            free_popup.visible = true
                            mypopup = free_popup
                            break
                        end
                    end
                    if not found_popup then
                        mypopup = awful.popup(args)
                        table.insert(all_popups, mypopup)
                    end
                    table.insert(popups, mypopup)
                    return mypopup
                end

                if not c.minimized then
                    table.insert(previously_visible_clients, c)
                    c.minimized = true
                end

                local popup_x = last_widths+(s.geometry.width-line_width)/(#line+1)*j
                local popup_y = (last_height+(s.geometry.height-total_height)/(#lines+1)*i)-(beautiful.wibar_height-beautiful.dock_width)/2+(biggest_client_in_line-geo.height*ratio)/2

                local content_popup = new_popup{
                    widget = wibox.widget{
                        widget = wibox.widget.imagebox,
                        image = content,
                        forced_width = geo.width*ratio,
                        forced_height = geo.height*ratio,
                    },
                    x = popup_x,
                    y = popup_y,
                }

                new_popup{
                    widget = wibox.widget{
                        widget = awful.widget.clienticon,
                        forced_width = 64,
                        forced_height = 64,
                        client = c
                    },
                    x = popup_x+(geo.width*ratio/2)-32,
                    y = popup_y+geo.height*ratio-32,
                    bg = gears.color.transparent
                }:set_xproperty("WM_NAME", "overview_client_icon")

                local titlew = wibox.widget{
                    {
                        {
                            widget = wibox.widget.textbox,
                            font = beautiful.bold_font,
                            text = c.keybinds,
                        },
                        widget = wibox.container.margin,
                        margins = 5
                    },
                    widget = wibox.container.background,
                    bg = beautiful.color4,
                    fg = beautiful.color7
                }
                local w, h = wibox.widget.base.fit_widget(titlew,
                    {dpi = xresources.get_dpi()}, titlew, 9999, 9999)
                new_popup{
                    widget = titlew,
                    x = popup_x+(geo.width*ratio/2)-w/2,
                    y = popup_y+(geo.height*ratio/2)-h/2
                }

                for _, popup in ipairs(popups) do
                    popup._signals["mouse::enter"] = nil
                    popup._signals["mouse::leave"] = nil

                    local function force_redraw()
                        content_popup.widget = wibox.widget{
                            widget = wibox.widget.imagebox,
                            image = draw(c),
                            forced_width = content_popup.widget.forced_width,
                            forced_height = content_popup.widget.forced_height
                        }
                    end
                    popup:connect_signal("mouse::enter", function()
                        c.active_in_overview = true
                        force_redraw()
                    end)
                    popup:connect_signal("mouse::leave", function()
                        if has_quitted_overview then return end
                        c.active_in_overview = false
                        force_redraw()
                    end)

                    popup:buttons(gears.table.join(
                        awful.button({ }, 1, function()
                            quit_overview(clients)
                            c.minimized = false
                            client.focus = c
                            c:raise()
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
                    margins = 10
                },
                widget = wibox.container.background,
                bg = beautiful.bg_normal,
                shape = rrect(),
                shape_border_width = 2
            }
            local w, h = wibox.widget.base.fit_widget(filterw,
                {dpi = xresources.get_dpi()}, filterw, 9999, 9999)

            local x = s.geometry.width/2-w/2
            local y = s.geometry.height*0.8
            if filter_popup then
                filter_popup.x = x
                filter_popup.y = y
                filter_popup.widget = filterw
            else
                filter_popup = awful.popup{
                    ontop = true,
                    x = x,
                    y = y,
                    widget = filterw
                }
            end
        end
        if filter_popup then
            filter_popup.visible = filter ~= ""
        end
    end

    local all_clients = s.selected_tag:clients()
    local clients = {}
    for _, c in ipairs(all_clients) do
        if not c.is_minimized_tab then
            table.insert(clients, c)
        end
    end
    if #clients <= 1 then return end
    table.sort(clients, function(a, b) return a.x < b.x end)
    s.mypanel:hide()
    draw_clients(clients)

    overview_shown = true
    awesome.emit_signal("overview::display", true)

    local filter = ""
    local is_ctrling = false
    local grabber = awful.keygrabber.run(function(mods, key, status)
        if status == "release" then return end

        local is_mod4 = false
        for _, mod in ipairs(mods) do
            if mod == "Mod4" then
                is_mod4 = true
            end
        end

        local focus_first = false
        if key == "Escape" or (is_mod4 and key == "o") then
            quit_overview(clients)
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
            if c.keybinds:lower():match("^"..filter:lower()) then
                table.insert(filtered_clients, c)
            end
        end
        free_popups()
        if #filtered_clients == 1 then
            local c = filtered_clients[1]
            quit_overview(clients)
            c.minimized = false
            client.focus = c
            c:raise()
        else
            draw_clients(filtered_clients, filter)
            hide_free_popups()
        end
    end)
end

-- vim:set et sw=4 ts=4:
