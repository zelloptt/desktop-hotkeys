class ShortcutHelper {
	constructor() {
		console.log('\r\n(DHK) init ShortcutHelper');
		const binary = require('@mapbox/node-pre-gyp');
		const path = require('path');
		const binding_path = binary.find(path.resolve(path.join(__dirname, './package.json')));
		this.impl = require(binding_path);
	}

	start(enableLogger) {
		return this.impl.start(enableLogger);
	}

	stop() {
		return this.impl.stop();
	}

	started() {
		return this.impl.started();
	}

	reload() {
		this.impl.unregisterAllShortcuts();
		if (process.platform === 'darwin') {
			this.impl.restart();
		} else {
			this.impl.stop();
			this.impl.start(false);
		}
	}

	setLoggerCb(callback) {
		if (process.platform === 'darwin') {
			this.impl.setLoggerCb(callback);
		}
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
				return this.impl.macSubscribeAccessibilityUpdates(cb);
			} else {
				return this.impl.macUnsubscribeAccessibilityUpdates();
			}
		}
	}

	showAccessibilitySettings() {
		if (process.platform === 'darwin') {
			this.impl.macShowAccessibilitySettings();
		}
	}

	checkAccessibility() {
		if (process.platform === 'darwin') {
			return this.impl.macCheckAccessibilityGranted();
		}
		return true;
	}

	setHotkeysEnabled(enable) {
		this.impl.setHotkeysEnabled(enable);
	}

	convertHotkeysCodes(keyCodes, keysAreVKC) {
		return this.impl.convertHotkeysCodes(keyCodes, keysAreVKC);
	}

	checkHotkeyConflicts(keyCodes) {
		return this.impl.checkHotkeyConflicts(keyCodes);
	}
}

var shortcutHelper = new ShortcutHelper();
module.exports = shortcutHelper;

