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

vimfx.addCommand({
	name: 'pip',
	description: 'Watch the current video in Picture-in-Picture mode'
}, ({ vim }) =>
	vim.window.document.getElementById("key_togglePictureInPicture").doCommand())
vimfx.set('custom.mode.normal.pip', 'V')

vimfx.addKeyOverrides(
	[ () => true, // is that the right way of doing it..?
		['<space>', 'r']]
)

const disableCtrlW = data => {
	const window = data.vim?.window || data.event.originalTarget.ownerGlobal;

	// this disables Ctrl-W to close a tab and replaces
	// it with readline-like behavior, deleting the word
	// behind the cursor.
	window.BrowserCommands.closeTabOrWindow = function() {
		window.goDoCommand('cmd_deleteWordBackward')
	}
};

vimfx.on("TabSelect", disableCtrlW);
vimfx.on("modeChange", disableCtrlW);
