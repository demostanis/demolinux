local emoji_file = "/usr/share/unicode/emoji-test.txt"

local filter = ""
local grabber, popup
local old_client_focus = nil
local no_results = false
local no_resultsw = wibox.widget{
    widget = wibox.widget.textbox,
    text = ""
}

local currentx = 1
local currenty = 1

local cursor = 1
local emojis = {}
local lines = {{}}

local grid_cols = 10
local grid_rows = 10
local grid = wibox.widget{
    layout = wibox.layout.grid,
    forced_num_cols = grid_cols,
    forced_num_rows = grid_rows,
    spacing = 5,
}

local input_command = "xdotool type %s"
local function input(text)
    if old_client_focus then
        client.focus = old_client_focus
        client.focus:raise()
    end
    gears.timer{
        single_shot = true,
        timeout = 0.5,
        callback = function()
            awful.spawn(string.format(
                input_command, text
            ), false)
        end
    }:start()
end

local function deactivate()
    for _, emoji in ipairs(emojis) do
        emoji.widget.active = false
    end
end

local function close()
    deactivate()
    popup.visible = false
    awful.keygrabber.stop(grabber)
end

local max_emoji_name_size = 50
local function print_emoji(emoji)
    local emojiw = popup.widget:get_children_by_id("emoji")[1]
    local name = popup.widget:get_children_by_id("name")[1]
    local emoji_name = emoji.name
    if #emoji_name > max_emoji_name_size then
        emoji_name = string.sub(emoji_name, 1, max_emoji_name_size-3).."..."
    end
    emojiw.text = emoji.symbol
    name.text = emoji_name
end

local function print_active_emoji()
    for _, emoji in ipairs(emojis) do
        if emoji.widget.active then
            print_emoji(emoji)
            break
        end
    end
end

local function mkemojiw(emoji, name)
    local emojiw = wibox.widget{
        {
            widget = wibox.widget.textbox,
            font = "Noto Color Emoji 20",
            text = emoji
        },
        shape = rrect(),
        widget = wibox.container.background
    }
    if name ~= "placeholder" then
        emojiw:connect_signal("mouse::enter", function()
            if not emojiw.active then
                emojiw.bg = beautiful.bg_normal
            end
            print_emoji({symbol = emoji, name = name})
        end)
        emojiw:connect_signal("mouse::leave", function()
            if not emojiw.active then
                emojiw.bg = beautiful.bg_focus
            end
            print_active_emoji()
        end)
        emojiw:buttons(gears.table.join(
            awful.button({ }, 1, function()
                close()
                input(emoji)
            end)
        ))
    end
    return emojiw
end

for line in io.lines(emoji_file) do
    if string.sub(line, 1, 1) ~= "#" and line ~= "" then
        local oftype, emoji, name = string.match(line, ".*; (%S+)%s+# (%S+) %S+ (.*)")

        if oftype == "fully-qualified" and not string.find(name, "tone") then
            table.insert(emojis, {
                widget = mkemojiw(emoji, name),
                symbol = emoji,
                name = name,
            })
        end
    end
end

local placeholder_symbol = ""
local placeholder = {
    widget = mkemojiw(placeholder_symbol, "placeholder"),
    symbol = placeholder_symbol,
    name = "placeholder",
}

local function compute_grid()
    lines = {{}}
    no_results = false
    currentx = 1
    currenty = 1
    cursor = 1

    local count = -1
    local current_line = 1
    for _, emoji in ipairs(emojis) do
        if string.find(emoji.name, filter) then
            count = count + 1
            if count == grid_cols then
                current_line = current_line + 1
                lines[current_line] = {}
                count = 0
            end
            -- Highlight the first emoji when redrawing the grid
            if current_line == 1 and count == 0 then
                emoji.widget.active = true
            end
            table.insert(lines[current_line], emoji)
        end
    end
    -- Fill empty rows and columns with placeholders (invisible emojis)
    if #lines[1] > 0 then
        for i=1,#lines do
            for j=#lines[i]+1,grid_cols do
                lines[i][j] = placeholder
            end
        end
        for i=#lines+1,grid_cols do
            local line = {}
            for j=1,grid_rows do
                line[j] = placeholder
            end
            lines[i] = line
        end
    else
        no_results = true
    end
end
compute_grid()

popup = awful.popup{
    ontop = true, visible = false,
    placement = awful.placement.centered,
    bg = beautiful.color8,
    widget = wibox.widget{
        {
            {
                text = "Search:",
                id = "search",
                widget = wibox.widget.textbox
            },
            widget = wibox.container.margin,
            top = 10, left = 10, right = 10,
            bottom = 5,
        },
        {
            wibox.container.margin(grid, 5, 5, 5, 5),
            -- who didn't miss random margins?
            wibox.container.margin(no_resultsw, 161.5, 161.5, 179.5, 178),
            layout = wibox.layout.stack,
        },
        {
            {
                {
                    text = "",
                    id = "emoji",
                    widget = wibox.widget.textbox
                },
                {
                    {
                        text = "",
                        id = "name",
                        widget = wibox.widget.textbox,
                    },
                    widget = wibox.container.margin,
                    bottom = 1, left = 5
                },
                layout = wibox.layout.align.horizontal,
            },
            widget = wibox.container.margin,
            margins = 8
        },
        layout = wibox.layout.align.vertical
    }
}
print_active_emoji()

local function redraw_grid()
    grid:reset()
    if no_results then
        no_resultsw.text = "No results"
        return
    else
        no_resultsw.text = ""
    end

    for i = cursor,cursor+9 do
        local line = lines[i]
        for j, emoji in ipairs(line) do
            if emoji.widget.active then
                emoji.widget.bg = beautiful.color14
            else
                emoji.widget.bg = beautiful.color8
            end

            table.insert(grid._private.widgets, {
                widget = emoji.widget,
                row = i-cursor+1,
                col = j,
                row_span = 1,
                col_span = 1,
            })
        end
    end
    grid._private.num_rows = grid_rows
    grid._private.num_cols = grid_cols
    grid:emit_signal("widget::layout_changed")
    grid:emit_signal("widget::redraw_needed")
end

popup:buttons(gears.table.join(
    awful.button({ }, 4, function()
        if cursor > 1 then
            cursor = cursor - 1
            redraw_grid()
        end
    end),
    awful.button({ }, 5, function()
        if cursor <= #lines-10 then
            cursor = cursor + 1
            redraw_grid()
        end
    end)
))

local function next_emoji()
    local x, y
    if currentx == grid_cols then
        x = 1
        y = currenty + 1
    else
        x = currentx + 1
        y = currenty
    end
    return lines[y][x] or {name = "placeholder"} -- so we don't crash lol
end

local function print_filter()
    local search = popup.widget:get_children_by_id("search")[1]
    search.text = "Search: "..filter
end

return function()
    filter = ""
    cursor = 1

    print_filter()
    compute_grid()
    print_active_emoji()
    redraw_grid()
    popup.visible = true

    old_client_focus = client.focus
    mouse.screen.mypanel:hide()

    local timer, grabber
    grabber = awful.keygrabber.run(function(mod, key, status)
        if status == "release" then return end
        local should_redraw = false
        local function update_filter()
            should_redraw = true
            if timer then
                timer:stop()
            end
        end

        if key == "Escape" then
            close()
            return
        elseif key == "Shift_L" then
            -- ignore key
        elseif key == "Shift_R" then
            -- ignore key
        elseif key == "BackSpace" then
            filter = filter:sub(1, -2)
            update_filter()
        elseif key == "Left" then
            if not (currenty == 1 and currentx == 1) then
                local previously_active_emoji = lines[currenty][currentx].widget
                previously_active_emoji:set_bg(beautiful.bg_focus)
                previously_active_emoji.active = false

                if currentx == 1 then
                    currentx = 10
                    currenty = currenty - 1
                    if currenty == cursor - 1 then
                        cursor = cursor - 1
                        redraw_grid()
                    end
                else
                    currentx = currentx - 1
                end

                local newly_active_emoji = lines[currenty][currentx].widget
                newly_active_emoji:set_bg(beautiful.color14)
                newly_active_emoji.active = true
                print_active_emoji()
            end
        elseif key == "Right" then
            if not (currenty == #lines and currentx == grid_cols)
                and next_emoji().name ~= "placeholder" then
                local previously_active_emoji = lines[currenty][currentx].widget
                previously_active_emoji:set_bg(beautiful.bg_focus)
                previously_active_emoji.active = false

                if currentx == grid_cols then
                    currentx = 1
                    currenty = currenty + 1
                    if currenty == cursor + grid_rows - 1 then
                        cursor = cursor + 1
                        redraw_grid()
                    end
                else
                    currentx = currentx + 1
                end

                local newly_active_emoji = lines[currenty][currentx].widget
                newly_active_emoji:set_bg(beautiful.color14)
                newly_active_emoji.active = true
                print_active_emoji()
            end
        elseif key == "Up" then
            if currenty ~= 1 then
                local previously_active_emoji = lines[currenty][currentx].widget
                previously_active_emoji:set_bg(beautiful.bg_focus)
                previously_active_emoji.active = false

                currenty = currenty - 1
                if currenty == cursor - 1 then
                    cursor = cursor - 1
                    redraw_grid()
                end

                local newly_active_emoji = lines[currenty][currentx].widget
                newly_active_emoji:set_bg(beautiful.color14)
                newly_active_emoji.active = true
                print_active_emoji()
            end
        elseif key == "Down" then
            local last_emoji, last_line
            for i, line in ipairs(lines) do
                local line_has_any_emoji = false
                for j, emoji in ipairs(line) do
                    if emoji.name ~= "placeholder" then
                        last_emoji = {i,j}
                        line_has_any_emoji = true
                    end
                end
                if line_has_any_emoji then
                    last_line = i
                end
            end
            if currenty ~= last_line then
                local previously_active_emoji = lines[currenty][currentx].widget
                previously_active_emoji:set_bg(beautiful.bg_focus)
                previously_active_emoji.active = false

                currenty = currenty + 1
                if currenty == cursor + grid_rows then
                    cursor = cursor + 1
                    redraw_grid()
                end

                if lines[currenty][currentx].name == "placeholder" then
                    currenty, currentx = table.unpack(last_emoji)
                end
                local newly_active_emoji = lines[currenty][currentx].widget
                newly_active_emoji:set_bg(beautiful.color14)
                newly_active_emoji.active = true
                print_active_emoji()
            end
        elseif key == "Return" then
            for _, emoji in ipairs(emojis) do
                if emoji.widget.active then
                    close()
                    input(emoji.symbol)
                    return
                end
            end
        elseif key == "u" and is_ctrling then
            filter = ""
            update_filter()
        elseif #key == 1 then
            filter = filter .. key
            update_filter()
        end

        is_ctrling = key == "Control_R" or key == "Control_L"

        print_filter()
        -- Only update the grid if no key has been
        -- pressed in the last third of a second
        timer = gears.timer{
            timeout = 0.3,
            single_shot = true,
            callback = function()
                if should_redraw then
                    deactivate()
                    compute_grid()
                    print_active_emoji()
                    redraw_grid()
                end
            end
        }
        timer:start()
    end)
end

-- vim:set et sw=4 ts=4:
