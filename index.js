class ShortcutHelper {
	constructor() {
		this.impl = require('bindings')('binding.node');
		if (process.platform === 'darwin') {
			this.macImpl = require('bindings')('binding.node');
		}
	}

	start(enableLogger) {
		return this.impl.start(enableLogger);
	}

	stop() {
		return this.impl.stop();
	}

	reload() {
		this.impl.unregisterAllShortcuts();
		this.impl.stop();
		this.impl.start(false);
	}

	registerShortcut(keys, callback, releaseCallback, keysAreVKC) {
		return this.impl.registerShortcut(keys, callback, releaseCallback, keysAreVKC);
	}

	unregisterShortcut(shortcutId) {
		return this.impl.unregisterShortcut(shortcutId);
	}

	collectPressedKeyCodes() {
		console.log('\r\n(DHK) looking for pressed keys');
		if (process.platform === 'win32') {
			throw new TypeError('win32 impl does not track the keys');
		}
		this.impl.collectPressedKeyCodes(true);
	}

	stopCollectingKeys() {
		this.impl.collectPressedKeyCodes(false);
	}

	pressedKeyCodes() {
		if (process.platform === 'win32') {
			throw new TypeError('win32 impl does not track the keys');
		}
		const keyCodes = this.impl.pressedKeyCodes();
		console.log('\r\n(DHK) Fetching the key codes [' + keyCodes + ']');
		return keyCodes;
	}

	setupAccessibilityCallback(enable, cb) {
		if (process.platform === 'darwin') {
			if (enable) {
				return this.macImpl.macSubscribeAccessibilityUpdates(cb);
			} else {
				return this.macImpl.macUnsubscribeAccessibilityUpdates();
			}
		}
	}

	showAccessibilitySettings() {
		if (process.platform === 'darwin') {
			this.macImpl.macShowAccessibilitySettings();
		}
	}

	checkAccessibility() {
		if (process.platform === 'darwin') {
			return this.macImpl.macCheckAccessibilityGranted();
		}
		return true;
	}
}

var shortcutHelper = new ShortcutHelper();
module.exports = shortcutHelper;

