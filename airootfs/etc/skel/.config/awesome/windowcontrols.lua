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

local corner_handler_table = {
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

-- TODO: move to theme.lua
local margin_before_window_on_focus = 56
local margin_window_move_on_click = 200

function activate(c)
    local raise = c.x > c.screen.geometry.width-margin_window_move_on_click
        or c.x+c.width < margin_window_move_on_click

    client.focus = c
    c:activate{raise = raise}
end

return gears.table.join(
    awful.button({ }, 1, activate),
    awful.button({ modkey }, 1, function (c)
        if not c.floating then
            awful.mouse.client.move(c)
        end
    end),
    awful.button({ modkey }, 3, function (c)
        local coords = mouse.coords()
        initial = {
            width = c.width,
            height = c.height,
            x = c.x, y = c.y,
            mouse = coords
        }
        local _, corner = awful.placement.closest_corner(
            {coords = function() return coords end},
            {parent = c, include_sides = true})

        mousegrabber.run(function(coords)
            if not coords.buttons[3] then
                return false
            end

            mx, my = coords.x, coords.y
            dx = initial.mouse.x - mx
            dy = initial.mouse.y - my

            local geo = corner_handler_table[corner](c)
            if (geo.width and geo.width < 1)
                or (geo.height and geo.height < 1) then
                return true
            end

            -- with scroll layout
            c.width = geo.width
            -- with floating layout
            c:emit_signal(
                "request::geometry", "mouse.resize",
                geo)
            return true
        end, cursors[corner])
    end),

    awful.key({ modkey }, "h", layout.move_left_window),
    awful.key({ modkey }, "l", layout.move_right_window),

    awful.key({ modkey }, "-", layout.maximize_two_windows),

    awful.key({ modkey }, "Tab", layout.cycle_window_focus)
)

-- vim:set et sw=4 ts=4:
