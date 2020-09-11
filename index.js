class ShortcutHelper {
	constructor() {
		if (process.platform !== 'win32') {
			this.impl = require('iohook');
			if (process.platform === 'darwin') {
				this.macImpl = require('node-gyp-build')(__dirname);
			}
		} else {
			this.impl = require('node-gyp-build')(__dirname);
		}
		this.keyCodes = [];
		this.fnKeyDown = this.onKeyDown.bind(this);
		this.fnKeyUp = this.onKeyUp.bind(this);
		this.collectingKeys = false;
		this.lastPressedKeyCode = 0;
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
		this.keyCodes = [];
		this.lastPressedKeyCode = 0;
		if (this.collectingKeys === true) {
			console.log('\r\n(DHK) do not start twice!');
			return true;
		}
		this.collectingKeys = true;
		this.impl.on('keydown', this.fnKeyDown);
		this.impl.on('keyup', this.fnKeyUp);
		return true;
	}

	stopCollectingKeys() {
		if (this.collectingKeys === true) {
			console.log('\r\n(DHK) Stop looking for pressed keys');
			this.collectingKeys = false;
			this.impl.off('keydown', this.fnKeyDown);
			this.impl.off('keyup', this.fnKeyUp);
		}
	}

	pressedKeyCodes() {
		if (process.platform === 'win32') {
			throw new TypeError('win32 impl does not track the keys');
		}
		// this.stopCollectingKeys();
		console.log('\r\n(DHK) Fetching the key codes [' + this.keyCodes + ']');
		const keyCodesCopy = this.keyCodes.slice();
		const idx = this.keyCodes.indexOf(this.lastPressedKeyCode);
		if (-1 !== idx) {
			this.lastPressedKeyCode = 0;
			this.keyCodes.splice(idx, 1);
			console.log('\r\n(DHK) shortened key codes [' + this.keyCodes + ']');
		}
		return keyCodesCopy;
	}

	onKeyDown(evt) {
		if (-1 === this.keyCodes.indexOf(evt.keycode)) {
			this.keyCodes.push(evt.keycode);
			this.lastPressedKeyCode = evt.keycode;
		}
	}

	onKeyUp(evt) {
		const idx = this.keyCodes.indexOf(evt.keycode);
		if (-1 !== idx) {
			this.keyCodes.splice(idx, 1);
			if (this.lastPressedKeyCode === evt.keycode) {
				this.lastPressedKeyCode = 0;
			}
		}
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

