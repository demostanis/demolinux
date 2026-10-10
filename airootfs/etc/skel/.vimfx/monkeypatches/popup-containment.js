// XUL popups are clamped to the screen even when their browser scrolls off it.
const dismissPopupsOnMove = window => {
	window.demolinuxPopupMoveCleanup?.();
	const notifications = window.PopupNotifications;
	const panel = notifications.panel;
	const oldFlip = panel.getAttribute("flip");
	panel.setAttribute("flip", "slide");
	let panelWidth = panel.getBoundingClientRect().width;
	const visibleBounds = () => {
		const rect = window.document.documentElement.getBoundingClientRect();
		const screen = window.screen;
		const left = Math.ceil(Math.max(window.mozInnerScreenX + rect.left, screen.availLeft));
		const top = Math.ceil(Math.max(window.mozInnerScreenY + rect.top, screen.availTop));
		const right = Math.floor(Math.min(window.mozInnerScreenX + rect.right, screen.availLeft + screen.availWidth));
		const bottom = Math.floor(Math.min(window.mozInnerScreenY + rect.bottom, screen.availTop + screen.availHeight));
		return new window.DOMRect(left, top, Math.max(0, right - left), Math.max(0, bottom - top));
	};
	const constrainPanel = () => {
		const bounds = visibleBounds();
		if (bounds.width && bounds.height) panel.setConstraintRect(bounds);
	};
	const shouldSuppress = notifications._shouldSuppress;
	const suppressOffscreen = () => {
		if (shouldSuppress.call(notifications)) return true;
		const bounds = visibleBounds();
		if (!bounds.height || bounds.width < panelWidth || !bounds.width) return true;
		const anchors = notifications._currentNotifications
			.map(notification => notification.anchorElement)
			.filter(anchor => anchor?.checkVisibility());
		if (!anchors.length) return false;
		const screen = window.screen;
		return !anchors.some(anchor => {
			const rect = anchor.getBoundingClientRect();
			const x = window.mozInnerScreenX + rect.x;
			const y = window.mozInnerScreenY + rect.y;
			return x + rect.width > screen.availLeft
				&& x < screen.availLeft + screen.availWidth
				&& y + rect.height > screen.availTop
				&& y < screen.availTop + screen.availHeight;
		});
	};
	notifications._shouldSuppress = suppressOffscreen;
	const onPopupShowing = event => {
		if (event.target !== panel) return;
		if (suppressOffscreen()) {
			notifications._suppress = true;
			event.preventDefault();
		} else {
			constrainPanel();
		}
	};
	const onPopupShown = () => {
		panelWidth = Math.max(panelWidth, panel.getBoundingClientRect().width);
		notifications.anchorVisibilityChange();
	};
	panel.addEventListener("popupshowing", onPopupShowing, true);
	panel.addEventListener("popupshown", onPopupShown);
	let x = window.screenX;
	let y = window.screenY;
	let width = window.innerWidth;
	let height = window.innerHeight;
	let timer;
	const update = () => {
		timer = undefined;
		if (window.screenX === x && window.screenY === y
			&& window.innerWidth === width && window.innerHeight === height) return;
		x = window.screenX;
		y = window.screenY;
		width = window.innerWidth;
		height = window.innerHeight;
		// Persistent permissions reopen after hidePopup(); suppress without answering them.
		if (notifications._currentNotifications.length) {
			notifications._hidePanel().then(() => {
				if (window.closed) return;
				// Recreate the native surface; moving it in place leaves stale X11 pixels.
				const display = panel.style.getPropertyValue("display");
				const priority = panel.style.getPropertyPriority("display");
				panel.style.setProperty("display", "none", "important");
				panel.getBoundingClientRect();
				if (display) panel.style.setProperty("display", display, priority);
				else panel.style.removeProperty("display");
				panel.getBoundingClientRect();
				constrainPanel();
				notifications.anchorVisibilityChange();
			}).catch(error => window.console.error(error));
		}
		for (const popup of window.document.querySelectorAll("panel, menupopup, tooltip")) {
			if (popup !== notifications.panel
				&& (popup.state === "open" || popup.state === "showing")) {
				popup.hidePopup();
			}
		}
	};
	// Native coordinates are updated after MozUpdateWindowPos is dispatched.
	const onMove = () => {
		window.clearTimeout(timer);
		timer = window.setTimeout(update, 0);
	};
	window.windowRoot.addEventListener("MozUpdateWindowPos", onMove);
	window.addEventListener("resize", onMove);
	window.demolinuxPopupMoveCleanup = () => {
		window.clearTimeout(timer);
		window.windowRoot.removeEventListener("MozUpdateWindowPos", onMove);
		window.removeEventListener("resize", onMove);
		panel.removeEventListener("popupshowing", onPopupShowing, true);
		panel.removeEventListener("popupshown", onPopupShown);
		panel.setConstraintRect(new window.DOMRect());
		if (oldFlip === null) panel.removeAttribute("flip");
		else panel.setAttribute("flip", oldFlip);
		window.removeEventListener("unload", window.demolinuxPopupMoveCleanup);
		if (notifications._shouldSuppress === suppressOffscreen) {
			notifications._shouldSuppress = shouldSuppress;
		}
	};
	window.addEventListener("unload", window.demolinuxPopupMoveCleanup);
	notifications.anchorVisibilityChange();
};
Services.obs.addObserver(dismissPopupsOnMove, "browser-delayed-startup-finished");
for (const window of Services.wm.getEnumerator("navigator:browser")) {
	dismissPopupsOnMove(window);
}
