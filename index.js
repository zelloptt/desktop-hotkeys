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
		this.keyCodePressed = 0;
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
		this.impl.on('keydown', this.fnKeyDown);
		this.impl.on('keyup', this.fnKeyUp);
		console.log('KeydownCB list');
		this.impl.rawListeners('keydown').forEach((value) => {
			console.log('KeydownCB' + value.toString());
		});

		return true;
	}
	pressedKeyCodes() {
		if(process.platform === 'win32') {
			throw new TypeError('win32 impl does not track the keys');
		}
		this.impl.off('keydown', this.fnKeyDown);
		this.impl.off('keyup', this.fnKeyUp);
		console.log('KeydownCB list');
		this.impl.rawListeners('keydown').forEach((value) => {
			console.log('KeydownCB' + value.toString())
		});
		if(this.keyCodePressed !== 0) {
			if (-1 == this.keyCodes.indexOf(this.keyCodePressed)) {
				this.keyCodes.push(this.keyCodePressed);
			}
		}
		console.log('\r\nkey codes array' + this.keyCodes + ' and ' + this.keyCodePressed);
		return this.keyCodes;
	}
	onKeyDown(evt) {
		this.keyCodePressed = 0;
		if (-1 == this.keyCodes.indexOf(evt.keycode)) {
			this.keyCodes.push(evt.keycode);
		}
	}
	onKeyUp(evt) {
		this.keyCodePressed = evt.keycode;
		const idx = this.keyCodes.indexOf(evt.keycode);
		if (-1 != idx) {
			this.keyCodes.splice(idx, 1);
		}
	}
}

const shortcutHelper = new ShortcutHelper();
module.exports = shortcutHelper;

