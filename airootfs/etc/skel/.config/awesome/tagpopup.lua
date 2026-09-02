-- copied mostly from taglist.lua (which is not used anymore)
function update_shape(background, i)
    local circle = background:get_children_by_id("circle")[1]
    if i == awful.screen.focused().selected_tag.index then
        circle.shape = function(cr)
            gears.shape.circle(cr, dpi(15), dpi(15), dpi(15)/2)
        end
    else
        circle.shape = function(cr)
            gears.shape.arc(cr, dpi(15), dpi(15), dpi(7)/2, 0, math.pi*2)
        end
    end
    background.bg = gears.color.transparent
end

local taglist = awful.widget.taglist {
    screen  = mouse.screen,
    filter  = awful.widget.taglist.filter.all,
    layout  = wibox.layout.fixed.vertical,
    widget_template = {
        {
            {
                {
                    margins = dpi(9),
                    widget = wibox.container.margin
                },
                bg     = beautiful.fg_normal,
                widget = wibox.container.background,
                id = "circle"
            },
            top = dpi(8),
            bottom = dpi(5),
            left = dpi(8),
            right = dpi(4),
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

local popup = awful.popup{
    ontop = true, visible = false,
    placement = awful.placement.centered + awful.placement.right,
    bg = beautiful.color8,
    widget = taglist,
}

local timer = nil
awesome.connect_signal("tag::switched", function()
    if not popup.visible then popup.visible = true end

    if timer then timer:stop() end
    timer = gears.timer{
        single_shot = true,
        timeout = 1,
        callback = function()
            popup.visible = false
        end
    }
    timer:start()
end)
