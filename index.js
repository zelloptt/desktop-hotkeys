class ShortcutHelper {
	constructor() {
		if(process.platform != 'win32') {
			this.impl = require('iohook');
		} else {
			this.impl = require('node-gyp-build')(__dirname);
		}
		this.keyCodes = [];
		this.fnKeyDown = this.onKeyDown.bind(this);
		this.fnKeyUp = this.onKeyUp.bind(this);
		this.collectingKeys = false;
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
		if (this.collectingKeys === true) {
			return true;
		}
		this.collectingKeys = true;
		this.impl.on('keydown', this.fnKeyDown);
		this.impl.on('keyup', this.fnKeyUp);
		this.logListeners();
		return true;
	}

	logListeners() {
		const listeners = this.impl.rawListeners('keydown');
		if (listeners.length > 0) {
			console.log('(DHK) KeydownCB list:');
			listeners.forEach((value) => {
				console.log('\tKeydownCB ' + value.toString());
			});
		} else {
			console.log('(DHK) KeydownCB list is empty');
		}
	}

	stopCollectingKeys() {
		if (this.collectingKeys === true) {
			this.collectingKeys = false;
			this.impl.off('keydown', this.fnKeyDown);
			this.impl.off('keyup', this.fnKeyUp);
			this.logListeners();
		}
	}

	pressedKeyCodes() {
		if(process.platform === 'win32') {
			throw new TypeError('win32 impl does not track the keys');
		}
		this.stopCollectingKeys();
		console.log('\r\nkey codes array' + this.keyCodes);
		return this.keyCodes;
	}

	onKeyDown(evt) {
		if (-1 == this.keyCodes.indexOf(evt.keycode)) {
			this.keyCodes.push(evt.keycode);
		}
	}

	onKeyUp(evt) {
		const idx = this.keyCodes.indexOf(evt.keycode);
		if (-1 != idx) {
			this.keyCodes.splice(idx, 1);
		}
	}
}

const shortcutHelper = new ShortcutHelper();
module.exports = shortcutHelper;

