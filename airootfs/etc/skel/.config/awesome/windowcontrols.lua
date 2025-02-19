local cursors = {
    ["left"] = "sb_h_double_arrow",
    ["right"] = "sb_h_double_arrow",
    ["top"] = "sb_v_double_arrow",
    ["bottom"] = "sb_v_double_arrow",
    ["top_left"] = "top_left_corner",
    ["top_right"] = "top_right_corner",
    ["bottom_left"] = "bottom_left_corner",
    ["bottom_right"] = "bottom_right_corner"
}

local floating_corner_handler_table = {
    left = function(c)
        return {
            x = initial.x - dx,
            width = initial.width + dx,
            height = height, y = c.y
        }
    end,
    bottom = function(c)
        return {
            x = c.x, width = c.width, y = c.y,
            height = initial.height - dy
        }
    end,
    top = function(c)
        return {
            x = c.x, width = c.width,
            height = initial.height + dy,
            y = initial.y - dy
        }
    end,
    right = function(c)
        return {
            x = c.x, y = c.y, height = c.height,
            width = initial.width - dx
        }
    end,
    bottom_left = function(c)
        return {
            x = initial.x - dx, y = c.y,
            height = initial.height - dy,
            width = initial.width + dx
        }
    end,
    bottom_right = function(c)
        return {
            x = c.x, y = c.y,
            width = initial.width - dx,
            height = initial.height - dy
        }
    end,
    top_left = function(c)
        return {
            x = initial.x - dx,
            width = initial.width + dx,
            height = initial.height + dy,
            y = initial.y - dy
        }
    end,
    top_right = function(c)
        return {
            width = initial.width - dx,
            height = initial.height + dy,
            y = initial.y - dy, x = c.x
        }
    end
}

local scrolling_corner_handler_table = {
    left = function(c, lefthand)
        if lefthand and initial.lefthand then
            lefthand.width = initial.lefthand.width - dx
        end
    end,
    right = function(c)
        c.width = initial.width - dx
    end,
}

-- TODO: move to theme.lua
local margin_before_window_on_focus = 56
local margin_window_move_on_click = 200

function activate(c)
    local raise = c.x > c.screen.geometry.width-margin_window_move_on_click
        or c.x+c.width < margin_window_move_on_click

    client.focus = c
    c:activate{raise = raise}
end

function grabmouse(fn)
    return function(c)
        c:emit_signal("request::activate", "mouse_click", {raise = false})
        mousegrabber.run(function()
            fn()
            return false
        end, "mouse")
    end
end

return gears.table.join(
    awful.button({ }, 1, activate),
    awful.button({ modkey }, 1, function (c)
        if not c.floating then
            awful.mouse.client.move(c)
        end
    end),
    awful.button({ modkey }, 3, function (c)
        local floating = c.floating

        local coords = mouse.coords()
        initial = {
            width = c.width,
            height = c.height,
            x = c.x, y = c.y,
            mouse = coords
        }

        local _, corner = awful.placement.closest_corner(
            {coords = function() return coords end},
            {parent = c, include_sides = floating})
        if not floating then
            if corner == "top_left" or corner == "bottom_left" then
                corner = "left"
            end
            if corner == "top_right" or corner == "bottom_right" then
                corner = "right"
            end
        end

        local lefthand
        local resizing_off_view = false
        if not floating then
            lefthand = layout.lefthand_window(c)
            if lefthand and lefthand ~= c then
                initial.lefthand = {}
                initial.lefthand.width = lefthand.width
                resizing_off_view = c == layout.leftmost_window() and corner == "left"
            end
        end

        mousegrabber.run(function(coords)
            if not coords.buttons[3] then
                if not floating and resizing_off_view then
                    client.focus = lefthand
                    lefthand:raise()
                    layout.on_window_appearance_change(lefthand)
                end

                return false
            end

            mx, my = coords.x, coords.y
            dx = initial.mouse.x - mx
            dy = initial.mouse.y - my

            local handlers = scrolling_corner_handler_table
            if floating then
                handlers = floating_corner_handler_table
            end

            local geo = handlers[corner](c, lefthand)
            -- scrolling directly modifies the clients
            if floating then
                if (geo.width and geo.width < 1)
                    or (geo.height and geo.height < 1) then
                    return true
                end

                c:emit_signal(
                    "request::geometry", "mouse.resize",
                    geo)
            end
            return true
        end, cursors[corner])
    end),
    -- scroll
    awful.button({ modkey }, 5, grabmouse(layout.move_left)),
    awful.button({ modkey }, 4, grabmouse(layout.move_right))
)

-- vim:set et sw=4 ts=4:
