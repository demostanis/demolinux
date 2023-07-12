bling.widget.window_switcher.enable{
    type = "thumbnail",
    filterClients = function(c, s)
        if c.is_tab then return false end
        return awful.widget.tasklist.filter.currenttags(c, s)
    end
}

-- vim:set et sw=4 ts=4:
