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
	name: 'mpv',
	description: 'Watch the current video in MPV'
}, ({ vim }) => vim.window.document.querySelector("#ff2mpv_yossarian_net-BAP").firstChild.click())
vimfx.set('custom.mode.normal.mpv', 'V')

vimfx.addKeyOverrides(
	[ () => true, // is that the right way of doing it..?
		['<space>', 'r']]
)

// copied from https://superuser.com/a/1747680
try {
  let { classes: Cc, interfaces: Ci, manager: Cm  } = Components;
  const Services = globalThis.Services;
  const {SessionStore} = Components.utils.import('resource:///modules/sessionstore/SessionStore.jsm');
  function ConfigJS() { Services.obs.addObserver(this, 'chrome-document-global-created', false); }
  ConfigJS.prototype = {
    observe: function (aSubject) { aSubject.addEventListener('DOMContentLoaded', this, {once: true}); },
    handleEvent: function (aEvent) {
      let document = aEvent.originalTarget; let window = document.defaultView; let location = window.location;
      if (/^(chrome:(?!\/\/(global\/content\/commonDialog|browser\/content\/webext-panels)\.x?html)|about:(?!blank))/i.test(location.href)) {
        if (window._gBrowser) {

		// this is not really VimFx related
		// but i didn't know where to put it...
		// 
		// this disables Ctrl-W to close a tab and replaces
		// it with readline-like behavior, deleting the word
		// behind the cursor.
		window.hijackCtrlW = () => window.goDoCommand('cmd_deleteWordBackward')
		document.querySelector('#cmd_close').setAttribute('oncommand', 'hijackCtrlW()')

		// in recent firefox versions, overriding oncommand
		// still calls closeTabOrWindow()...
		BrowserCommands.closeTabOrWindow = function() {}
        }
      }
    }
  };
  if (!Services.appinfo.inSafeMode) { new ConfigJS(); }
} catch(ex) {};
