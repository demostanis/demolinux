local step = 500
local margin_before_window_on_focus = 50

local global_x = 0
local scroll = {name = "scroll"}
function scroll.arrange(p)
	local t = p.tag
	local wa = p.workarea
	local cls = p.clients

	local x = global_x + 0
	for i=#cls,1,-1 do
		local g = {}
		local c = cls[i]

		-- TODO: do not hardcode
		g.x = x + 5
		g.y = beautiful.wibar_height+10
		g.width = c.width
		g.height = mouse.screen.geometry.height-beautiful.dock_height-10
		p.geometries[c] = g

		x = x + c.width
	end
end

local function leftmost_window()
	local leftmost = nil
	for _, c in ipairs(mouse.screen.clients) do
		if not leftmost or leftmost.x < 0 or (c.x > 0 and c.x < leftmost.x) then
			leftmost = c
		end
	end
	return leftmost
end

local function lefthand_window()
	local lefthand = nil
	local leftmost = leftmost_window()
	for _, c in ipairs(mouse.screen.clients) do
		if not lefthand or (
			math.abs(c.x+c.width-leftmost.x) <
			math.abs(lefthand.x+lefthand.width-leftmost.x)) then
			lefthand = c
		end
	end
	return lefthand
end

local function righthand_window()
	local righthand = nil
	local leftmost = leftmost_window()
	for _, c in ipairs(mouse.screen.clients) do
		if not righthand or (
			math.abs(c.x-(leftmost.x+leftmost.width)) <
			math.abs(righthand.x-(leftmost.x+leftmost.width))) then
			righthand = c
		end
	end
	return righthand
end

local function farthest_window()
	local farthest = nil
	for _, c in ipairs(mouse.screen.clients) do
		if not farthest or c.x > farthest.x then
			farthest = c
		end
	end
	return farthest
end

local function first_window()
	local nearest = nil
	for _, c in ipairs(mouse.screen.clients) do
		if not nearest or c.x < nearest.x then
			nearest = c
		end
	end
	return nearest
end

local timed = nil
local last_new = nil
local function set_global_x(new)
	-- so we don't abort 1000 times when holding the switch key
	if new == last_new then return end
	last_new = new

	if timed and timed.started then
		timed:abort()
	end

	local ended = false
	timed = rubato.timed{
		pos = global_x,
		duration = 0.3,
		subscribed = function(w)
			-- rubato sometimes generates weird curves that go
			-- past the target value... so correct it...
			if new > global_x and w > new then
				w = new
			elseif new < global_x and w < new then
				w = new
			end
			if ended then return end
			if w == new then
				ended = true
			end
			global_x = w
			awful.layout.arrange(mouse.screen)
		end
	}
	timed.target = new
end

local function move_right()
	if client.focus then
		local farthest = farthest_window()
		if farthest.x < 0 then
			return
		end
		local new_global_x = global_x - step
		set_global_x(new_global_x)
	end
end

local function move_left()
	if client.focus then
		local new_global_x = global_x + step
		if new_global_x > 0 then
			new_global_x = 0
		end
		set_global_x(new_global_x)
	end
end

local function global_x_to_client(c)
	local new_global_x = c.x-first_window().x
	if new_global_x <= 0 then
		new_global_x = 0
	else
		new_global_x = new_global_x - margin_before_window_on_focus
	end
	return -new_global_x
end

local function move_left_window()
	local lefthand = lefthand_window()
	if not lefthand then return end
	set_global_x(global_x_to_client(lefthand))
	client.focus = lefthand
end

local function move_right_window()
	local righthand = righthand_window()
	if not righthand then return end
	set_global_x(global_x_to_client(righthand))
	client.focus = righthand
end

local function cycle_window_focus()
	local windows_in_viewport = {}
	for _, c in ipairs(mouse.screen.clients) do
		-- don't judge those magic numbers please
		if c.x+c.width > 56 and c.x < c.screen.geometry.width-56 then
			table.insert(windows_in_viewport, c)
		end
	end
	table.sort(windows_in_viewport, function(a, b)
		return a.x < b.x
	end)
	if #windows_in_viewport < 2 then
		return
	end
	for i, c in ipairs(windows_in_viewport) do
		if c == client.focus then
			if i == #windows_in_viewport then
				i = 1
			else
				i = i+1
			end
			local target = windows_in_viewport[i]
			target:activate { context = "mouse_enter", raise = false }
			return
		end
	end
end

client.connect_signal("raised", function(c)
	if c.x == 5 then
		local function callback(c)
			local new_global_x = global_x_to_client(c)
			-- not sure why that happens, but sometimes the
			-- second window changes its x property twice...
			if not (new_global_x == 0 and c ~= client.focus) then
				c:disconnect_signal("property::x", callback)
				set_global_x(new_global_x)
			end
		end
		c:connect_signal("property::x", callback)
	else
		set_global_x(global_x_to_client(c))
	end
end)

client.connect_signal("unmanage", function()
	gears.timer{
		timeout = 0.1,
		single_shot = true,
		call_once = true,
		callback = function()
			set_global_x(global_x_to_client(client.focus))
		end
	}:start()
end)

function scroll.move_handler(c, context, hints)
	-- default move handler, but we don't swap
	-- clients too early to prevent flickering.
    if context ~= "mouse.move" then return end

    if mouse.screen ~= c.screen then
        c.screen = mouse.screen
    end

    local l = c.screen.selected_tag and c.screen.selected_tag.layout or nil
    if l == awful.layout.suit.floating then return end

    local c_u_m = mouse.current_client
    if c_u_m and not c_u_m.floating then
        if c_u_m ~= c then
			local smallest = c
			local biggest = c_u_m
			if c.width > c_u_m.width then
				smallest = c_u_m
				biggest = c
			end
			local mouse_x = mouse.coords().x
			local diff = biggest.width-smallest.width
			if mouse_x > smallest.x+smallest.width
				and mouse_x < smallest.x+smallest.width+diff then
				return
			end

            c:swap(c_u_m)
        end
    end
end

-- replace default client move handler
client.disconnect_signal("request::geometry", awful.layout.move_handler)
client.connect_signal("request::geometry", scroll.move_handler)

return {
	move_left = move_left,
	move_right = move_right,
	move_left_window = move_left_window,
	move_right_window = move_right_window,
	cycle_window_focus = cycle_window_focus,
	scroll = scroll,
}
