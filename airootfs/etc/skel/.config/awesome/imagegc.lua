local gears = require("gears")

local timer = gears.timer {
    timeout = 2,
    single_shot = true,
    callback = function()
        collectgarbage("collect")
    end,
}

return function()
    -- Cairo image buffers are allocated outside the Lua heap.
    if not timer.started then
        timer:start()
    end
end
