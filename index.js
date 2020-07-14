class ShortcutHelper {
	constructor() {
		if(process.platform != 'win32') {
			this.impl = require('iohook');
		} else {
			this.impl = require('node-gyp-build')(__dirname);
		}
		this.keyCodes = [];
	}
	start(enableLogger) {
		return this.impl.start(enableLogger);
	}
	stop() {
		return this.impl.stop();
	}
	registerShortcut(keys, callback, releaseCallback, keysAreVKC) {
		return this.impl.registerShortcut(keys, callback, releaseCallback, keysAreVKC);
	}
	unregisterShortcut(shortcutId) {
		return this.impl.unregisterShortcut(shortcutId);
	}
	collectPressedKeyCodes() {
		if(process.platform === 'win32') {
			throw new TypeError('win32 impl does not track the keys');
		}
		this.keyCodes = [];
		this.impl.on('keydown', this.onKeyDown);
		this.impl.on('keyup', this.onKeyUp);
		return true;
	}
	pressedKeyCodes() {
		if(process.platform === 'win32') {
			throw new TypeError('win32 impl does not track the keys');
		}
		this.impl.off('keydown', this.onKeyDown);
		this.impl.off('keyup', this.onKeyUp);
		return this.keyCodes;
	}
	onKeyDown(evt) {
		if (-1 == keyCodes.indexOf(evt.keycode)) {
			keyCodes.push(evt.keycode);
		}
	}
	onKeyUp(evt) {
		const idx = keyCodes.indexOf(evt.keycode);
		if (-1 != idx) {
			keyCodes.splice(idx, 1);
		}
	}
}

const shortcutHelper = new ShortcutHelper();
module.exports = shortcutHelper;

