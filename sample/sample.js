const dh = require('desktop-hotkeys');

function fnPressed() {
	console.log('Hotkey pressed');
}

function fnReleased() {
	console.log('Hotkey released');
}

function fnPressed2() {
	console.log('Hotkey#2 pressed');
}

function fnReleased2() {
	console.log('Hotkey#2 released');
}

console.log('desktop-hotkeys module started: ' + dh.start(true));

function logCb(text) {
	console.log('(PTT) Callback: ' + text);
}
// module accepts scancodes, you may find the examples at
// https://www.win.tue.nl/~aeb/linux/kbd/scancodes-1.html
const isWindows = (process.platform === 'win32');
const CTRL = isWindows ? 17 : 29;
const ALT = isWindows ? 18 : 56;
const F1 = isWindows ? 112 : 59;
const F6 = F1 + 5;
const F7 = F6 + 1;
const useVKC = isWindows;
try {
	dh.setLoggerCb(logCb);
	dh.setupAccessibilityCallback(true, (granted) => {
		// it has been reported that actual permission status might be applied
		// only after a short period of time
		console.log('(PTT) Accessibility permission has changed to ' + granted);
	});

	const hk1 = dh.registerShortcut([CTRL, ALT, F1], fnPressed, fnReleased, useVKC);
	console.log('registerShortcut returned ' + hk1);

	const hk2 = dh.registerShortcut([CTRL, ALT, F7], fnPressed2, fnReleased2, useVKC);
	console.log('2nd registerShortcut returned ' + hk2);

	const hk3 = dh.registerShortcut([CTRL, ALT, F6], fnPressed2);
	console.log('3rd registerShortcut returned ' + hk3);

	const hk4 = dh.registerShortcut([CTRL, ALT, F6], fnPressed2);
	console.log('4th registerShortcut returned ' + hk4);

	const hk5 = dh.registerShortcut([ALT, F6], fnPressed2);
	console.log('5th registerShortcut returned ' + hk5);

} catch (ex) {
	console.log('exception ' + ex);
}

const keyCodes = [17, 18, 112];
console.log('Test codes are: ' + keyCodes.toString());
const macCodes = dh.convertHotkeysCodes(keyCodes, true);
console.log('Mac codes are: ' + macCodes.toString());
const winCodes = dh.convertHotkeysCodes(macCodes, false);
console.log('Mac codes are: ' + winCodes.toString());

console.log('waiting for hotkeys...');
/*setTimeout(() => {
	console.log("Disable hotkeys.");
	dh.setHotkeysEnabled(false);
	setTimeout(() => {
		console.log("Enable hotkeys back");
		dh.setHotkeysEnabled(true);

	}, "10000");
}, "10000");*/
