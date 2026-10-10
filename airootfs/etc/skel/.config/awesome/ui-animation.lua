awesome.register_xproperty("WM_NAME", "string")

return function(popup, name)
    popup:set_xproperty("WM_NAME", "awesome_ui_"..name)
    return popup
end
