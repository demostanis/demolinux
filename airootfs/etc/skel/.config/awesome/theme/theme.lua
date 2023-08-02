xresources = require"beautiful.xresources"
dpi = xresources.apply_dpi

local theme = {}

local xrdb = xresources.get_current_theme()
theme.mt = {__index = xrdb}
setmetatable(theme, theme.mt)

theme.base_font = "Fira Sans"
theme.font = theme.base_font.." 10"
theme.bold_font = theme.base_font .. ", ExtraBold 10"
theme.base_icon_font = "Font Awesome 6 Pro"
theme.icon_font = theme.base_icon_font.." 8"

theme.default_icon = "/usr/share/icons/la-capitaine/status/scalable-dark/dialog-question.svg"
theme.icon_theme = "la-capitaine"

theme.wallpaper = "/usr/share/backgrounds/nyarch.jpg"

theme.bg_normal = theme.color10
theme.bg_focus = theme.color11

theme.fg_normal = theme.color15
theme.fg_focus = theme.color15

theme.useless_gap = dpi(0)
theme.border_width = dpi(0)

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
theme.app_launcher_app_name_selected_color = theme.color7
theme.app_launcher_app_selected_color = theme.color14
theme.app_launcher_app_normal_hover_color = theme.bg_focus
theme.app_launcher_background = theme.bg_normal

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
theme.panel_width = 415
theme.dock_width = 50
theme.dock_indicator_color = theme.color7
theme.border_radius = 5

return theme

-- vim:set et sw=4 ts=4:
