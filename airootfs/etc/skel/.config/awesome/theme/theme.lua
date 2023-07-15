theme_assets = require"beautiful.theme_assets"
xresources = require"beautiful.xresources"

dpi = xresources.apply_dpi

local theme = {}

local xrdb = xresources.get_current_theme()
theme.mt = {__index = xrdb}
setmetatable(theme, theme.mt)

theme.basefont = "CaskaydiaCove Nerd Font Mono"
theme.font = theme.basefont .. " 10"
theme.baseiconfont =  "Font Awesome 6 Pro"
theme.iconfont = theme.baseiconfont .. " 8"

theme.default_icon = "/usr/share/icons/la-capitaine/status/scalable-dark/dialog-question.svg"
theme.icon_theme = "la-capitaine"

theme.wallpaper = "/usr/share/backgrounds/nyarch.jpg"

theme.bg_normal = theme.color10
theme.bg_focus = theme.color11
-- TODO: change those
theme.bg_urgent = "#ff0000"
theme.bg_minimize = "#444444"

theme.fg_normal = theme.color15
theme.fg_focus = theme.color15
theme.fg_urgent = theme.color15
theme.fg_minimize = theme.color15

theme.useless_gap = dpi(0)
theme.border_width = dpi(0)

-- required by bling's app_launcher
theme.prompt_bg_cursor = theme.color11
theme.prompt_fg_cursor = theme.color15

-- titlebar icons
theme.titlebar_close_button_normal = cwd.."theme/window-close.png"
theme.titlebar_close_button_focus  = cwd.."theme/window-close.png"

theme.titlebar_ontop_button_normal_inactive = cwd.."theme/window-ontop.png"
theme.titlebar_ontop_button_focus_inactive = theme.titlebar_ontop_button_normal_inactive
theme.titlebar_ontop_button_normal_active = cwd.."theme/window-ontopped.png"
theme.titlebar_ontop_button_focus_active = theme.titlebar_ontop_button_normal_active

theme.titlebar_maximized_button_normal_inactive = cwd.."theme/window-maximize.png"
theme.titlebar_maximized_button_focus_inactive = theme.titlebar_maximized_button_normal_inactive
theme.titlebar_maximized_button_normal_active = cwd.."theme/window-maximized.png"
theme.titlebar_maximized_button_focus_active = theme.titlebar_maximized_button_normal_active

theme.tag_preview_client_border_color = theme.color0
theme.tag_preview_widget_border_color = theme.color0

theme.app_launcher_prompt_color = theme.bg_focus
theme.app_launcher_prompt_text_color = theme.color7
theme.app_launcher_prompt_icon_color = theme.color7
theme.app_launcher_app_name_selected_color = theme.color7
theme.app_launcher_app_selected_color = theme.color8

theme.window_switcher_widget_bg = theme.bg_focus
theme.window_switcher_widget_border_width = 0
theme.window_switcher_widget_border_radius = 5
theme.window_switcher_client_width = 250
theme.window_switcher_client_height = 300
theme.window_switcher_name_normal_color = theme.color15
theme.window_switcher_name_focus_color = theme.color7

theme.notification_spacing = 5
theme.notification_width = 400
theme.notification_offset_y = 55
theme.notification_border_color = theme.color11
theme.notification_bg = theme.color11

theme.wibar_width = 35
theme.wibar_widget_hover_color = theme.color13
theme.dock_width = 50
theme.dock_indicator_color = theme.color7
theme.border_radius = 5

return theme

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
