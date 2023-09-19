vimfx.addCommand({
	name: 'bookmarks',
	description: 'Open bookmarks side bar'
}, ({ vim }) =>
	vim.window.SidebarUI.toggle('viewBookmarksSidebar'))
vimfx.set('custom.mode.normal.bookmarks', 'B')

vimfx.addCommand({
	name: 'search_bookmarks',
	description: 'Focuses the search bar to search bookmarks'
}, ({ vim }) => vim.window.PlacesCommandHook.searchBookmarks())
vimfx.set('custom.mode.normal.search_bookmarks', '*')

vimfx.addCommand({
	name: 'search_tabs',
	description: 'Focuses the search bar to search tabs'
}, ({ vim }) => vim.window.gTabsPanel.searchTabs())
vimfx.set('custom.mode.normal.search_tabs', '%')

vimfx.addCommand({
	name: 'refresh',
	description: 'Refresh the current tab'
}, ({ vim }) => vim.window.BrowserReload())
vimfx.set('custom.mode.normal.refresh', 'R')

vimfx.addKeyOverrides(
	[ () => true, // is that the right way of doing it..?
		['<space>', 'r']]
)
