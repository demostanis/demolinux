const disableCtrlW = data => {
	const window = data.vim?.window || data.event.originalTarget.ownerGlobal;

	// Replace closing the tab with readline-style backward word deletion.
	window.BrowserCommands.closeTabOrWindow = function() {
		window.goDoCommand('cmd_deleteWordBackward')
	}
};

vimfx.on("TabSelect", disableCtrlW);
vimfx.on("modeChange", disableCtrlW);
