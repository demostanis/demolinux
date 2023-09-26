local br = beautiful.border_radius

function rrect(radius)
    radius = radius or br
    return function(cr, w, h)
        return gears.shape.rounded_rect(cr, w, h, radius)
    end
end

function tpopup(text)
    local textwidget = wibox.widget.textbox(text)
    local popup = awful.popup {
        widget = wibox.container.margin(textwidget,
            br, br, br, br),
        ontop = true, bg = beautiful.bg_focus,
        shape = rrect(), visible = false,
        offset = { x = 5 }
    }
    return {popup, textwidget}
end

function autospawn(command, has_zero_as_its_exit_code_although_it_unexpectedly_quitted)
    awful.spawn.easy_async(command, function(out, err, reason, code)
        if has_zero_as_its_exit_code_although_it_unexpectedly_quitted or code ~= 0 then
            gears.timer{
                timeout = 1,
                single_shot = true,
                callback = function()
                    autospawn(command)
                end
            }:start()
        end
    end)
end

-- Stolen from
-- https://www.reddit.com/r/awesomewm/comments/8yxrj2/is_there_a_way_to_get_a_geometry_table_of_a_widget/
function find_widget_in_wibox(wb, wdg)
    local function traverse(hi)
        if hi:get_widget() == wdg then
            return hi
        end
        for _, child in ipairs(hi:get_children()) do
            p = traverse(child)
            if p then return p end
        end
    end
    return traverse(wb._drawable._widget_hierarchy)
end

function wgeometry(wdg, wb)
    wb = wb or awful.screen.focused().mywibar
    local hi = find_widget_in_wibox(wb, wdg)
    local x, y, w, h = gears.matrix.transform_rectangle(
        hi:get_matrix_to_device(), 0, 0, hi:get_size())
    return {width = w, height = h, x = x, y = y}
end

function spawn_with_selection(command)
    awful.spawn.easy_async("slop --tolerance=0", function(out)
        local w, h, x, y = string.match(out, "(%d+)x(%d+)+(%d+)+(%d+)")
        awful.spawn(command, {x = x, y = y, width = w, height = h})
    end)
end

function fade_on_overview(wb)
    awesome.connect_signal("overview::display", function(shown)
        if shown then
            rubato.timed{
                pos = 1,
                duration = 0.1,
                subscribed = function(pos)
                    wb.opacity = pos
                end
            }.target = 0.7
        else
            rubato.timed{
                pos = 0.7,
                duration = 0.1,
                subscribed = function(pos)
                    wb.opacity = pos
                end
            }.target = 1
        end
    end)
end

function delayed(fn, timeout)
    gears.timer{
        single_shot = true,
        timeout = timeout or 0,
        callback = fn
    }:start()
end

function optional(module)
    local m = require(module)
    if m._absent then
        return nil
    else
        return m
    end
end

-- vim:set et sw=4 ts=4:
