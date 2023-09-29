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
        offset = { y = 5 }
    }
    return {popup, textwidget}
end

function autospawn(command)
    awful.spawn.easy_async(command, function(out, err, reason, code)
        if code ~= 0 then
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
