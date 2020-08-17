class ShortcutHelper {
	constructor() {
		if(process.platform !== 'win32') {
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
		console.log('\r\n(DHK) looking for pressed keys');
		if(process.platform === 'win32') {
			throw new TypeError('win32 impl does not track the keys');
		}
		this.keyCodes = [];
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
		if(process.platform === 'win32') {
			throw new TypeError('win32 impl does not track the keys');
		}
		this.stopCollectingKeys();
		console.log('\r\n(DHK) Fetching the key codes array [' + this.keyCodes + ']');
		return this.keyCodes;
	}

	onKeyDown(evt) {
		console.log('\r\n(DHK) key down: ' + evt.keycode);
		if (-1 === this.keyCodes.indexOf(evt.keycode)) {
			console.log('\r\n(DHK) add code ' + evt.keycode);
			this.keyCodes.push(evt.keycode);
		}
	}

	onKeyUp(evt) {
		const idx = this.keyCodes.indexOf(evt.keycode);
		if (-1 !== idx) {
			console.log('(DHK) drop code ' + evt.keycode);
			this.keyCodes.splice(idx, 1);
		}
	}
}

const shortcutHelper = new ShortcutHelper();
module.exports = shortcutHelper;

