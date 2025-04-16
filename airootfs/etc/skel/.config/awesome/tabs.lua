tab_masters = {}
local tabbed_clients = {"URxvt"}
local is_launching_tab = false

local titlebar_args = {
    position = "bottom",
    bg_focus = beautiful.tabs_bg or 
        beautiful.bg_normal
}

local function wants_tabs(c)
    for _, class in ipairs(tabbed_clients) do
        if class == c.class then
           return true
        end
    end
    return false
end

local function deactivate(tabs)
    for _, tab in ipairs(tabs) do
        tab.active = false
    end
end

local function mktabw(text, active)
    local bg_color = beautiful.bg_focus
    if active then bg_color = beautiful.color3 end

    local tabw = wibox.widget{
        {
            {
                {
                    widget = wibox.widget.textbox,
                    markup = text,
                    id = "text",
                },
                widget = wibox.container.margin,
                margins = 4,
            },
            bg = bg_color,
            shape = rrect(),
            widget = wibox.container.background,
            id = "background",
        },
        widget = wibox.container.margin,
        margins = 2,
    }
    local textw = tabw:get_children_by_id("text")[1]
    tabw:connect_signal("mouse::enter", function()
        controlling_tabs = true
        textw.old_markup = textw.markup
        textw.markup = string.format(
            [[<span foreground="%s">%s</span>]],
            beautiful.color13, glib.markup_escape_text(textw.text, #textw.text)
        )
    end)
    tabw:connect_signal("mouse::leave", function()
        controlling_tabs = false
        textw.markup = textw.old_markup
    end)
    return tabw
end

local function switch_to_tab(master, tab)
    if tab.active then return end

    controlling_tabs = true

    local previous_active_slave = master.active_slave
    deactivate(master.tabs)
    tab.active = true

    delayed(function()
        tab.client.x = previous_active_slave.x
        tab.client.y = previous_active_slave.y
        tab.client.width = previous_active_slave.width
        tab.client.height = previous_active_slave.height
        tab.client.minimized = false
        tab.client.is_minimized_tab = false

        tab.client:raise()
        client.focus = tab.client
        previous_active_slave.minimized = true
        previous_active_slave.is_minimized_tab = true
        master.active_slave = tab.client

        controlling_tabs = false
    end)
end

local function update_tabs(master)
    local tabs = master.tabs
    local tabsl = master.tabsl

    local drawn_tabs_count = 0
    local to_delete = {}
    for i, child in ipairs(tabsl:get_children()) do
        if child.is_plus_button then break end

        if tabs[i].to_delete then
            table.insert(to_delete, i)
        else
            local child_background = child
                :get_children_by_id("background")[1]
            if tabs[i].active then
                child_background:set_bg(beautiful.color3)
            else
                child_background:set_bg(beautiful.bg_focus)
            end
            local textw = child
                :get_children_by_id("text")[1]
            textw.markup = glib.markup_escape_text(tabs[i].name, #tabs[i].name)
        end

        drawn_tabs_count = drawn_tabs_count + 1
    end
    for _, i in ipairs(to_delete) do
        table.remove(tabs, i)
        tabsl:remove(i)
    end
    for i = 1,#tabs-drawn_tabs_count do
        local tab_index = drawn_tabs_count+i
        local tab = tabs[tab_index]
        local tabw = mktabw(tab.name, tab.active)

        tabsl:insert(tab_index, tabw)
        tabw:buttons(gears.table.join(
            awful.button({ }, 1, function()
                switch_to_tab(master, tab)
                update_tabs(master)
            end)
        ))
    end
end

local function delete_tab_in(master, tab_to_delete)
    local tabs = master.tabs
    local tabsl = master.tabsl
    local last = master.last

    local tab_index = 0
    for i, tab in ipairs(tabs) do
        if tab == tab_to_delete then
            tab.to_delete = true
            tab_index = i
            break
        end
    end
    if #tabs > 1 then
        controlling_tabs = true

        local previous_tab = tabs[tab_index-1] or tabs[tab_index+1]
        master.active_slave = previous_tab.client
        previous_tab.active = true

        delayed(function()
            previous_tab.client.x = last.x
            previous_tab.client.y = last.y
            previous_tab.client.width = last.width
            previous_tab.client.height = last.height
            previous_tab.client.minimized = false
            previous_tab.client.is_minimized_tab = false
            client.focus = previous_tab.client
            previous_tab.client:raise()

            controlling_tabs = false
        end)
    else
        master.active_slave = nil
    end

    update_tabs(master)
end

local function spawn_new_tab_in(master)
    if is_launching_tab then return end
    is_launching_tab = true

    controlling_tabs = true

    local tabs = master.tabs
    local c = master.active_slave
    local command = io.open("/proc/"..c.pid.."/cmdline"):read()
    local shell_command = command
    local pwd = nil
    for _, tab in ipairs(tabs) do
        if tab.active and tab.pwd then
            pwd = tab.pwd
        end
    end
    if pwd then
        pwd = pwd:gsub("'", "'\"'\"'") -- escapes single quotes
        shell_command = {"/bin/sh", "-c", "NEWPWD='"..pwd.."' "..command}
    end

    deactivate(tabs)
    local tab =  {
        name = "Untitled",
        active = true,
    }
    table.insert(tabs, tab)
    update_tabs(master)

    local new_client = awful.spawn(shell_command, {
        x = c.x, y = c.y,
        width = c.width,
        height = c.height,
    }, function(new_client)
        is_launching_tab = false
        tab.client = new_client
        new_client.is_tab = true
        master.active_slave = new_client
        new_client.master = master
        tab.pwd = pwd

        delayed(function()
            c.minimized = true
            c.is_minimized_tab = true
            new_client:raise()
            controlling_tabs = false
        end)

        local last = master.last
        new_client:emit_signal("render_tabs", master)
        new_client:connect_signal("property::x", function() last.x = new_client.x end)
        new_client:connect_signal("property::y", function() last.y = new_client.y end)
        new_client:connect_signal("property::width", function() last.width = new_client.width end)
        new_client:connect_signal("property::height", function() last.height = new_client.height end)
        new_client:connect_signal("property::name", function()
            tab.name = new_client.name
            update_tabs(master)
        end)
        new_client:connect_signal("unmanage", function()
            delete_tab_in(master, tab)
            if #tabs > 0 then
                master.tabs[1].client.is_tab = false
            end
        end)
    end)
end

local function new_tab(c)
    c = c or client.focus
    if c.master then
        spawn_new_tab_in(c.master)
    end
end

local function switch_to_next_tab(c)
    c = c or client.focus

    local master = c.master
    if not master then return end
    local tabs = master.tabs
    for i, tab in ipairs(tabs) do
        if tab.active then
            local new_tab = tabs[i+1]
            if not new_tab then
                new_tab = tabs[1]
            end
            switch_to_tab(master, new_tab)
            update_tabs(master)
            break
        end
    end
end

local function show_tabs_on_client(c)
    if wants_tabs(c) then
        local tabsl

        if not is_launching_tab then
            tabsl = wibox.layout.fixed.horizontal()
            local tabs = {{
                name = c.name,
                active = true,
                client = c,
            }}
            tab_masters[c] = {
                tabsl = tabsl,
                tabs = tabs,
                last = {}
            }
            local master = tab_masters[c]
            master.active_slave = c
            c.master = master

            local plus_button = mktabw("+")
            plus_button.is_plus_button = true
            plus_button:buttons(gears.table.join(
                awful.button({ }, 1, function()
                    spawn_new_tab_in(master)
                end)
            ))
            tabsl:add(plus_button)

            c:connect_signal("unmanage", function()
                delete_tab_in(master, tabs[1])
                if #tabs > 0 then
                    tabs[1].client.is_tab = false
                end
            end)
            c:connect_signal("property::name", function()
                tabs[1].name = c.name
                update_tabs(master)
            end)

            update_tabs(master)
            awful.titlebar(c, titlebar_args):setup{ tabsl,
                layout = wibox.layout.align.horizontal
            }
        else
            c:connect_signal("render_tabs", function(_, master)
                awful.titlebar(c, titlebar_args):setup{ master.tabsl,
                    layout = wibox.layout.align.horizontal
                }
                -- Since we render our tab bar after request::titlebars,
                -- the client's height is improperly calculated, so we
                -- need to adjust it
                local height = c._private.titlebars.top.drawable.drawable:geometry().height
                c.height = c.height - height
            end)
        end
    end
end

return {
    new_tab = new_tab,
    show_tabs_on_client = show_tabs_on_client,
    switch_to_next_tab = switch_to_next_tab,
    wants_tabs = wants_tabs
}

-- vim:set et sw=4 ts=4:
