let hookedOpenLink = false;

const forceMcpContainer = data => {
	const window = data.vim?.window || data.event.originalTarget.ownerGlobal;
	if (hookedOpenLink || !window.Marionette.running) return;
	hookedOpenLink = true;

	const mcpContextId = 6;
	const [firstTab] = window.gBrowser.tabs;
	const newTab = window.gBrowser.addTab("about:blank", {
		userContextId: mcpContextId,
		index: 0,
		triggeringPrincipal: Services.scriptSecurityManager.getSystemPrincipal(),
	});
	window.gBrowser.selectedTab = newTab;
	window.gBrowser.removeTab(firstTab);

	const openLinkIn = window.URILoadingHelper.openLinkIn;
	// Keep remotely controlled tabs in the MCP container.
	window.URILoadingHelper.openLinkIn = function(win, url, where, params) {
		params = params || {};
		params.userContextId = mcpContextId;
		return openLinkIn.call(this, win, url, where, params);
	};
};

vimfx.on("TabSelect", forceMcpContainer);
vimfx.on("modeChange", forceMcpContainer);
