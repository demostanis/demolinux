local function read(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local function command(pid)
    local content = read("/proc/"..pid.."/cmdline")
    if not content then return nil end
    local args = {}
    for arg in content:gmatch("(.-)%z") do
        table.insert(args, arg)
    end
    return args
end

local function ssh_arguments(args)
    if not args[1] or args[1]:match("([^/]+)$") ~= "ssh" then return nil end
    local result = {}
    local value_options = "BbcDEeFIiJLlmOopQRSWw"
    local flags = "46AaCgKkqtvXxYy"
    local i = 2
    while i <= #args do
        local arg = args[i]
        if arg == "--" then
            i = i + 1
            break
        end
        if arg:sub(1, 1) ~= "-" then break end
        if #arg == 1 then return nil end
        local j = 2
        while j <= #arg do
            local option = arg:sub(j, j)
            if value_options:find(option, 1, true) then
                local value = arg:sub(j + 1)
                if value == "" then
                    i = i + 1
                    value = args[i]
                end
                if not value then return nil end
                if ("OQWw"):find(option, 1, true) then return nil end
                local keep = not ("DLR"):find(option, 1, true)
                if option == "o" then
                    local name = value:match("^%s*([^=%s]+)")
                    name = name and name:lower()
                    if name == "remotecommand" or name == "sessiontype"
                        or name == "forkafterauthentication" or name == "stdinnull" then
                        return nil
                    end
                    if name == "localforward" or name == "remoteforward"
                        or name == "dynamicforward" or name == "requesttty" then keep = false end
                end
                if keep then
                    table.insert(result, "-"..option)
                    table.insert(result, value)
                end
                break
            elseif option == "M" then
                -- Do not create another multiplexing master or forwarding listener.
            elseif flags:find(option, 1, true) then
                table.insert(result, "-"..option)
            else
                return nil
            end
            j = j + 1
        end
        i = i + 1
    end
    if not args[i] or args[i] == "" or args[i]:sub(1, 1) == "-" then return nil end
    table.insert(result, args[i])
    i = i + 1
    if i <= #args then
        -- Recognize the login command used by tabs we spawned ourselves.
        if i ~= #args or not args[i]:match("^cd %-%- '.+' && exec \"%$SHELL\" %-l$") then
            return nil
        end
    end
    return result
end

local function foreground_ssh(pid, window)
    local queue = {{pid = pid, belongs = false}}
    local seen = {}
    local index = 1
    while index <= #queue and index <= 256 do
        local entry = queue[index]
        index = index + 1
        local current = entry.pid
        if not seen[current] then
            seen[current] = true
            local base = "/proc/"..current
            local environment = read(base.."/environ") or ""
            local window_id = ("\0"..environment):match("%zWINDOWID=([^%z]+)%z")
            local belongs = entry.belongs
            if current ~= pid and window_id then
                belongs = tonumber(window_id) == window
            end
            local stat = read(base.."/stat") or ""
            local fields = stat:match("^%d+ %(.+%) (.*)$") or ""
            local state, _, group, _, tty, foreground = fields:match(
                "^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+)"
            )
            if belongs and state ~= "Z" and tty and tty ~= "0"
                and tonumber(foreground) and tonumber(foreground) > 0 and group == foreground then
                local args = ssh_arguments(command(current) or {})
                if args then return args end
            end
            local children = read(base.."/task/"..current.."/children") or ""
            for child in children:gmatch("%d+") do
                if #queue < 256 then
                    table.insert(queue, {pid = tonumber(child), belongs = belongs})
                end
            end
        end
    end
end

return {command = command, foreground_ssh = foreground_ssh}
