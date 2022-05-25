const dh = require('desktop-hotkeys');
var hk1;

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

console.log("desktop-hotkeys module started: " + dh.start(true));

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
try {
	// dh.setLoggerCb(logCb);
	dh.setupAccessibilityCallback(true, (granted) => {
		// it has been reported that actual permission status might be applied
		// only after a short period of time
		log.info('(PTT) Accessibility permission has changed to ' + granted);
	});

	dh.start(true);
	hk1 = dh.registerShortcut([CTRL, ALT, F1], fnPressed, fnReleased, true);
	console.log('registerShortcut returned ' + hk1);

	const hk2 = dh.registerShortcut([CTRL, ALT, F7], fnPressed2, fnReleased2, true);
	console.log('2nd registerShortcut returned ' + hk2);

	dh.registerShortcut([CTRL, ALT, F6], fnPressed2)
} catch (ex) {
	console.log('exception ' + ex);
}
console.log('waiting for hotkeys...');
