// Reverse native history direction without changing document layout or scrolling.
const reverseHistorySwipes = window => {
	const animation = window.gHistorySwipeAnimation;
	if (!animation) return;
	Object.defineProperty(animation, "isLTR", {
		configurable: true,
		get() {
			const ltr = window.document.documentElement.matches(":-moz-locale-dir(ltr)");
			return Services.prefs.getBoolPref("demolinux.reverseHistorySwipes", false) ? !ltr : ltr;
		},
		// Firefox writes this during init/uninit; the getter remains authoritative.
		set() {},
	});
};
Services.obs.addObserver(reverseHistorySwipes, "browser-delayed-startup-finished");
for (const window of Services.wm.getEnumerator("navigator:browser")) {
	reverseHistorySwipes(window);
}
