local password = ""
local password_set = false
local invalid_password = false
local first_try_input = ""
local second_try = false

local function update_text()
    local text = "Please set your temporary password:"
    if invalid_password then
        if not password_set then
            text = "Password don't match. Try again:"
        else
            text = "Invalid password. Try again:"
        end
    else
        if password_set then
            text = "Please type your password:"
        else
            if second_try then
                text = "Please confirm your temporary password:"
            end
        end
    end
    return text
end

local popup = nil
local text = update_text()

return function(s)
    -- TODO: maybe we should spawn the popup on every screen?
    s = s or mouse.screen
    if not popup then
        popup = awful.popup{
            x = 0, y = 0, ontop = true,
            width = s.geometry.width,
            height = s.geometry.height,
            bg = beautiful.bg_focus,
            visible = true,
            widget = {
                {
                    {
                        {
                            widget = wibox.widget.textbox,
                            text = text,
                            font = beautiful.base_font .. " 32",
                            id = "prompt-text"
                        },
                        widget = wibox.container.place
                    },
                    {
                        {
                            widget = wibox.widget.textbox,
                            text = " ",
                            font = beautiful.base_font .. " 32",
                            id = "hidden-password"
                        },
                        widget = wibox.container.place
                    },
                    layout = wibox.layout.fixed.vertical,
                    widget = wibox.container.background
                },
                widget = wibox.container.place,
                forced_width = s.geometry.width,
                forced_height = s.geometry.height,
                fill_vertical = true, fill_horizontal = true
            }
        }
    else
        popup.visible = true
        invalid_password = false
        popup.widget:get_children_by_id("prompt-text")[1].text =
            update_text()
    end

    function read_input()
        local input = ""
        local grabber
        grabber = awful.keygrabber.run(function(mods, key, status)
            if status == "release" then return end

            if key == "BackSpace" then
                input = input:sub(1, -2)
            elseif key == "Return" then
                if password_set then
                    if input == password then
                        popup.visible = false
                        awful.keygrabber.stop(grabber)
                    else
                        invalid_password = true
                    end
                else
                    if not second_try then
                        first_try_input = input
                        second_try = true
                    else
                        if input == first_try_input then
                            password = input
                            password_set = true
                            invalid_password = false
                        else
                            invalid_password = true
                        end
                        second_try = false
                    end
                end

                input = ""
                popup.widget:get_children_by_id("prompt-text")[1].text =
                    update_text()
            elseif key == "u" and mods[1] == "Control" then
                input = ""
            elseif #key == 1 then
                if mods[1] == "Shift" or mods[1] == "Lock" then
                    input = input .. (key:upper())
                elseif #mods == 0 then
                    input = input .. key
                end
            end

            local hidden_password = input:gsub(".", "*")
            if #hidden_password == 0 then
                hidden_password = " "
            end
            popup.widget:get_children_by_id("hidden-password")[1].text =
                hidden_password
        end)
    end
    read_input()
end
