local awful = require"awful"
local beautiful = require"beautiful"
local gears = require"gears"
local wibox = require"wibox"

local taglist_buttons = gears.table.join(
    awful.button({ }, 1, function(t)
        if overview_shown then return end
        t:view_only()
    end),
    awful.button({ modkey }, 1, function(t)
        if overview_shown then return end
        if client.focus then
            client.focus:move_to_tag(t)
        end
    end)
)

function update_shape(background, i)
    local circle = background:get_children_by_id("circle")[1]
    if i == awful.screen.focused().selected_tag.index then
        circle.shape = function(cr)
            gears.shape.circle(cr, 15, 15, 7.5)
        end
    else
        circle.shape = function(cr)
            gears.shape.arc(cr, 15, 15, 3.5, 0, math.pi*2)
        end
    end
    background.bg = gears.color.transparent
end

return function(s)
    local taglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        layout  = wibox.layout.fixed.vertical,
        buttons = taglist_buttons,
        widget_template = {
            {
                {
                    {
                        margins = 10,
                        widget = wibox.container.margin
                    },
                    bg     = beautiful.fg_normal,
                    widget = wibox.container.background,
                    id = "circle"
                },
                left = 7,
                top = 4,
                widget = wibox.container.margin,
            },
            widget = wibox.container.background,
            shape = gears.shape.circle,
            create_callback = function(self, t, i)
                local circle = self:get_children_by_id("circle")[1]
                self:connect_signal("mouse::enter", function()
                    if overview_shown then return end
                    circle.bg = beautiful.wibar_widget_hover_color
                    awesome.emit_signal("bling::tag_preview::update", t)
                end)
                self:connect_signal("mouse::leave", function()
                    if overview_shown then return end
                    circle.bg = beautiful.fg_normal
                end)
                update_shape(self, i)
            end,
            update_callback = function(self, t, i)
                update_shape(self, i)
            end
        }
    }
    taglist:connect_signal("mouse::enter", function()
        if overview_shown then return end
        awesome.emit_signal("bling::tag_preview::visibility", s, true)
    end)
    taglist:connect_signal("mouse::leave", function()
        if overview_shown then return end
        awesome.emit_signal("bling::tag_preview::visibility", s, false)
    end)
    return taglist
end

-- vim:set et sw=4 ts=4:
