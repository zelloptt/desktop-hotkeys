
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
	console.log('unregisterShortcut returned ' + dh.unregisterShortcut(hk1));
}

console.log("desktop-hotkeys module started: " + dh.start(true));

// module accepts scancodes, you may find the examples at
// https://www.win.tue.nl/~aeb/linux/kbd/scancodes-1.html
const CTRL = 29;
const ALT = 56;
const F1 = 59;
const F7 = 65;

hk1 = dh.registerShortcut([ CTRL, ALT, F1 ], fnPressed, fnReleased)
console.log('registerShortcut returned ' + hk1);

const hk2 = dh.registerShortcut([ CTRL, ALT, F7 ], fnPressed2, fnReleased2)
console.log('2nd registerShortcut returned ' + hk2);

dh.registerShortcut([ CTRL, ALT, 64 ], fnPressed2)

console.log('waiting for hotkeys...');

