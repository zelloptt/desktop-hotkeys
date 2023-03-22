#include "windows_vkc.h"
#include "../libuiohook/include/uiohook.h"
static const uint16_t table[][2] = {
{VK_LBUTTON, MOUSE_BUTTON1},  //	Left mouse button
{VK_RBUTTON, MOUSE_BUTTON2},  // 	Right mouse button
{VK_CANCEL, 0}, //		Control-break processing
{VK_MBUTTON, MOUSE_BUTTON3}, //		Middle mouse button (three-button mouse)
{VK_XBUTTON1, MOUSE_BUTTON4}, //    X1 mouse button
{VK_XBUTTON2, MOUSE_BUTTON5}, //    X2 mouse button
{VK_BACK, VC_BACKSPACE}, //	BACKSPACE key
{VK_TAB, VC_TAB}, //	TAB key
{VK_CLEAR, 0}, // CLEAR key
{VK_RETURN, VC_ENTER}, //	ENTER key

{VK_SHIFT, VC_SHIFT_L}, //	SHIFT key
{VK_CONTROL, VC_CONTROL_L}, //	CTRL key
{VK_MENU, VC_ALT_L}, //	ALT key
{VK_PAUSE, VC_PAUSE}, //	PAUSE key
{VK_CAPITAL, VC_CAPS_LOCK}, //	CAPS LOCK key
{VK_KANA, VC_KATAKANA}, //	IME Kana mode
//{VK_IME_ON, 0}, //	0x16	IME On
{VK_JUNJA, 0}, //	0x17	IME Junja mode
{VK_FINAL, 0}, //	0x18	IME final mode
{VK_HANJA, 0}, //	0x19	IME Hanja mode
{VK_KANJI, VC_KANJI}, //	0x19	IME Kanji mode
//{VK_IME_OFF, 0}, //	0x1A	IME Off
{VK_ESCAPE, VC_ESCAPE}, //	0x1B	ESC key
{VK_CONVERT, 0}, //	0x1C	IME convert
{VK_NONCONVERT, 0}, //	0x1D	IME nonconvert
{VK_ACCEPT, 0}, //	0x1E	IME accept
{VK_MODECHANGE, 0}, //	0x1F	IME mode change request
{VK_SPACE, VC_SPACE}, //	0x20	SPACEBAR
{VK_PRIOR, VC_PAGE_UP}, //	0x21	PAGE UP key
{VK_NEXT, VC_PAGE_DOWN}, //	0x22	PAGE DOWN key
{VK_END, VC_END}, //	0x23	END key
{VK_HOME, VC_HOME}, //	0x24	HOME key
{VK_LEFT, VC_LEFT}, //	0x25	LEFT ARROW key
{VK_UP, VC_UP}, //	0x26	UP ARROW key
{VK_RIGHT, VC_RIGHT}, //	0x27	RIGHT ARROW key
{VK_DOWN, VC_DOWN}, //	0x28	DOWN ARROW key
{VK_SELECT, 0}, //	0x29	SELECT key
{VK_PRINT, 0}, //	0x2A	PRINT key
{VK_EXECUTE, 0}, //	0x2B	EXECUTE key
{VK_SNAPSHOT, VC_PRINTSCREEN}, //	0x2C	PRINT SCREEN key
{VK_INSERT, VC_INSERT}, //	0x2D	INS key
{VK_DELETE, VC_DELETE}, //	0x2E	DEL key
{VK_HELP, 0}, //	0x2F	HELP key
{0x30, VC_0}, //	0 key
{0x31, VC_1}, //	1 key
{0x32, VC_2}, //	2 key
{0x33, VC_3}, //3 key
{0x34, VC_4}, //4 key
{0x35, VC_5}, //	5 key
{0x36, VC_6}, //	6 key
{0x37, VC_7}, //	7 key
{0x38, VC_8}, //	8 key
{0x39, VC_9}, //	9 key
//-	0x3A-40	Undefined
{0x41, VC_A	}, //A key
{0x42, VC_B	}, //key
{0x43, VC_C	}, //key
{0x44, VC_D	}, // key
{0x45, VC_E	}, // key
{0x46, VC_F	}, // key
{0x47, VC_G	}, // key
{0x48, VC_H	}, // key
{0x49, VC_I	}, // key
{0x4A, VC_J	}, // key
{0x4B, VC_K	}, // key
{0x4C, VC_L	}, // key
{0x4D, VC_M	}, // key
{0x4E, VC_N	}, // key
{0x4F, VC_O	}, // key
{0x50, VC_P	}, // key
{0x51, VC_Q	}, // key
{0x52, VC_R	}, // key
{0x53, VC_S	}, // key
{0x54, VC_T	}, // key
{0x55, VC_U	}, // key
{0x56, VC_V	}, // key
{0x57, VC_W	}, // key
{0x58, VC_X	}, // key
{0x59, VC_Y	}, // key
{0x5A, VC_Z}, // key
{VK_LWIN, VC_META_L}, //	0x5B	Left Windows key (Natural keyboard)
{VK_RWIN, VC_META_R}, //	0x5C	Right Windows key (Natural keyboard)
{VK_APPS, VC_CONTEXT_MENU}, //	0x5D	Applications key (Natural keyboard)
//-	0x5E	Reserved
{VK_SLEEP, VC_SLEEP}, //	0x5F	Computer Sleep key
{VK_NUMPAD0, VC_KP_0}, //	0x60	Numeric keypad 0 key
{VK_NUMPAD1, VC_KP_1}, //	0x61	Numeric keypad 1 key
{VK_NUMPAD2, VC_KP_2}, //	0x62	Numeric keypad 2 key
{VK_NUMPAD3, VC_KP_3}, //	0x63	Numeric keypad 3 key
{VK_NUMPAD4, VC_KP_4}, //	0x64	Numeric keypad 4 key
{VK_NUMPAD5, VC_KP_5}, //	0x65	Numeric keypad 5 key
{VK_NUMPAD6, VC_KP_6}, //	0x66	Numeric keypad 6 key
{VK_NUMPAD7, VC_KP_7}, //	0x67	Numeric keypad 7 key
{VK_NUMPAD8, VC_KP_8}, //	0x68	Numeric keypad 8 key
{VK_NUMPAD9, VC_KP_9}, //	0x69	Numeric keypad 9 key
{VK_MULTIPLY, VC_KP_MULTIPLY}, //	0x6A	Multiply key
{VK_ADD, VC_KP_ADD}, //	0x6B	Add key
{VK_SEPARATOR, 0}, //	0x6C	Separator key
{VK_SUBTRACT, VC_KP_SUBTRACT}, //	0x6D	Subtract key
{VK_DECIMAL, VC_KP_SEPARATOR}, //	0x6E	Decimal key
{VK_DIVIDE, VC_KP_DIVIDE}, //	0x6F	Divide key
{VK_F1, VC_F1},	//0x70	F1 key
{VK_F2, VC_F2},	//	0x71	F2 key
{VK_F3, VC_F3},	//	0x72	F3 key
{VK_F4, VC_F4},	//	0x73	F4 key
{VK_F5, VC_F5},	//	0x74	F5 key
{VK_F6, VC_F6},	//	0x75	F6 key
{VK_F7, VC_F7},	//	0x76	F7 key
{VK_F8, VC_F8},	//	0x77	F8 key
{VK_F9, VC_F9},	//	0x78	F9 key
{VK_F10, VC_F10},	//	0x79	F10 key
{VK_F11, VC_F11},	//	0x7A	F11 key
{VK_F12, VC_F12},	//	0x7B	F12 key
{VK_F13, VC_F13},	//	0x7C	F13 key
{VK_F14, VC_F14},	//	0x7D	F14 key
{VK_F15, VC_F15},	//	0x7E	F15 key
{VK_F16, VC_F16},	//	0x7F	F16 key
{VK_F17, VC_F17},	//	0x80	F17 key
{VK_F18, VC_F18},	//	0x81	F18 key
{VK_F19, VC_F19},	//	0x82	F19 key
{VK_F20, VC_F20},	//	0x83	F20 key
{VK_F21, VC_F21},	//	0x84	F21 key
{VK_F22, VC_F22},	//	0x85	F22 key
{VK_F23, VC_F23},	//	0x86	F23 key
{VK_F24, VC_F24},	//	0x87	F24 key
//-	0x88-8F	Unassigned
{VK_NUMLOCK, VC_NUM_LOCK}, //	0x90	NUM LOCK key
{VK_SCROLL, VC_SCROLL_LOCK}, //	0x91	SCROLL LOCK key
//0x92-96	OEM specific
//-	0x97-9F	Unassigned
{VK_LSHIFT, VC_SHIFT_L}, //	0xA0	Left SHIFT key
{VK_RSHIFT, VC_SHIFT_R}, //	0xA1	Right SHIFT key
{VK_LCONTROL, VC_CONTROL_L}, //	0xA2	Left CONTROL key
{VK_RCONTROL, VC_CONTROL_L}, //	0xA3	Right CONTROL key
{VK_LMENU, VC_ALT_L}, //	0xA4	Left ALT key
{VK_RMENU, VC_ALT_R}, //	0xA5	Right ALT key
{VK_BROWSER_BACK, VC_BROWSER_BACK}, //	0xA6	Browser Back key
{VK_BROWSER_FORWARD, VC_BROWSER_FORWARD}, //	0xA7	Browser Forward key
{VK_BROWSER_REFRESH, VC_BROWSER_REFRESH}, //	0xA8	Browser Refresh key
{VK_BROWSER_STOP, VC_BROWSER_STOP}, //	0xA9	Browser Stop key
{VK_BROWSER_SEARCH, VC_BROWSER_SEARCH}, //	0xAA	Browser Search key
{VK_BROWSER_FAVORITES, VC_BROWSER_FAVORITES}, //	0xAB	Browser Favorites key
{VK_BROWSER_HOME, VC_BROWSER_HOME}, //	0xAC	Browser Start and Home key
{VK_VOLUME_MUTE, VC_VOLUME_MUTE}, //	0xAD	Volume Mute key
{VK_VOLUME_DOWN, VC_VOLUME_DOWN}, //	0xAE	Volume Down key
{VK_VOLUME_UP, VC_VOLUME_UP}, //	0xAF	Volume Up key
{VK_MEDIA_NEXT_TRACK, VC_MEDIA_NEXT}, //		0xB0	Next Track key
{VK_MEDIA_PREV_TRACK, VC_MEDIA_PREVIOUS}, //		0xB1	Previous Track key
{VK_MEDIA_STOP, VC_MEDIA_STOP}, //		0xB2	Stop Media key
{VK_MEDIA_PLAY_PAUSE, VC_MEDIA_PLAY}, //		0xB3	Play/Pause Media key
{VK_LAUNCH_MAIL, 0}, //		0xB4	Start Mail key
{VK_LAUNCH_MEDIA_SELECT, VC_MEDIA_SELECT}, //		0xB5	Select Media key
{VK_LAUNCH_APP1, VC_APP_MAIL}, //		0xB6	Start Application 1 key
{VK_LAUNCH_APP2, VC_APP_CALCULATOR}, //	0xB7	Start Application 2 key
//-	0xB8-B9	Reserved
{VK_OEM_1, VC_SEMICOLON}, //	0xBA	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the ';:' key
{VK_OEM_PLUS, VC_EQUALS}, //	0xBB	For any country/region, the '+' key
{VK_OEM_COMMA, VC_COMMA}, //	0xBC	For any country/region, the ',' key
{VK_OEM_MINUS, VC_MINUS}, //	0xBD	For any country/region, the '-' key
{VK_OEM_PERIOD, VC_PERIOD}, //	0xBE	For any country/region, the '.' key
{VK_OEM_2, VC_SLASH}, //	0xBF	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '/?' key
{VK_OEM_3, VC_BACKQUOTE}, //	0xC0	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '`~' key
//-	0xC1-D7	Reserved
//-	0xD8-DA	Unassigned
{VK_OEM_4, VC_OPEN_BRACKET}, //	0xDB	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '[{' key
{VK_OEM_5, VC_BACK_SLASH}, //	0xDC	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '\|' key
{VK_OEM_6, VC_CLOSE_BRACKET}, //	0xDD	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the ']}' key
{VK_OEM_7, VC_QUOTE}, //	0xDE	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the 'single-quote/double-quote' key
{VK_OEM_8, VC_YEN}, //	0xDF	Used for miscellaneous characters; it can vary by keyboard.
//-	0xE0	Reserved
//0xE1	OEM specific
{VK_OEM_102, VC_LESSER_GREATER}, //	0xE2	The <> keys on the US standard keyboard, or the \\| key on the non-US 102-key keyboard
//0xE3-E4	OEM specific
{VK_PROCESSKEY, VC_APP_PICTURES}, //	0xE5	IME PROCESS key
{0xE6, VC_APP_MUSIC}, //	OEM specific
{VK_PACKET, 0}, //	0xE7	Used to pass Unicode characters as if they were keystrokes. The VK_PACKET key is the low word of a 32-bit Virtual Key value used for non-keyboard input methods. For more information, see Remark in KEYBDINPUT, SendInput, WM_KEYDOWN, and WM_KEYUP
//-	0xE8	Unassigned
//0xE9-F5	OEM specific
{VK_ATTN, 0}, //	0xF6	Attn key
{VK_CRSEL, 0}, //	0xF7	CrSel key
{VK_EXSEL, 0}, //	0xF8	ExSel key
{VK_EREOF, 0}, //	0xF9	Erase EOF key
{VK_PLAY, 0}, //	0xFA	Play key
{VK_ZOOM, 0}, //	0xFB	Zoom key
{VK_NONAME, 0}, //	0xFC	Reserved
{VK_PA1, 0}, //	0xFD	PA1 key
{VK_OEM_CLEAR, VC_CLEAR} //	0xFE	Clear key
};

static const uint16_t totalKeyCount = sizeof(table) / sizeof(table[0]);

unsigned keycode_convert(unsigned code, bool toWinVK) {
    for (uint16_t idx = 0; idx <totalKeyCount; ++idx) {
        if (toWinVK && table[idx][1] == code) {
            return table[idx][0];
        } else if (!toWinVK && table[idx][0] == code) {
            return table[idx][1];
        }
    }
    return 0;
}