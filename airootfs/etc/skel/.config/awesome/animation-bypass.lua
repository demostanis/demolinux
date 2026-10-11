local gears = require"gears"

awesome.register_xproperty("DEMOLINUX_ANIMATION_BYPASS", "number")

local timers = setmetatable({}, {__mode = "k"})

return function(c)
    if not c or not c.valid then return end

    c:set_xproperty("DEMOLINUX_ANIMATION_BYPASS", 1)
    if timers[c] then
        timers[c]:again()
        return
    end

    -- Keep the flag through deferred layout updates and Picom's next frame.
    timers[c] = gears.timer.start_new(0.15, function()
        timers[c] = nil
        if c.valid then
            c:set_xproperty("DEMOLINUX_ANIMATION_BYPASS", 0)
        end
        return false
    end)
end
