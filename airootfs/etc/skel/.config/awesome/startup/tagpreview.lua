
bling.widget.tag_preview.enable {
    show_client_content = true,
    placement_fn = function(c)
        awful.placement.top(c, {
            margins = { top = 50 }
        })
    end
}

-- vim:set et sw=4 ts=4:
