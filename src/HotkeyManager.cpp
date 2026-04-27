#include "Hotkeys.h"
#include "HotkeyManager.h"
#include <process.h>

#define WM_REGISTER_HOTKEY	WM_USER + 0x11
#define WM_UNREGISTER_HOTKEY	WM_USER + 0x12

HotKeyManager* g_pHotKeyManager = NULL;
bool g_bVerboseMode = false;

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);

bool log(const char* format, ...)
{
	if (!g_bVerboseMode) {
		return false;
	}
	va_list args;
	va_start(args, format);
	bool status = vfprintf(stdout, format, args) >= 0;
	va_end(args);
	return status;
}

unsigned __stdcall HotKeyManager::winThread(void* ptr)
{
	HotKeyManager* pThis = reinterpret_cast<HotKeyManager*>(ptr);
	static const char* class_name = "HotKeyManager_class";
	WNDCLASSEX wx = {};
	wx.cbSize = sizeof(WNDCLASSEX);
	wx.lpfnWndProc = WndProc;
	wx.hInstance = ::GetModuleHandle(NULL);
	wx.lpszClassName = class_name;
	if (RegisterClassEx(&wx)) {
		pThis->_hWnd = CreateWindowEx(0, class_name, "no title", 0, 0, 0, 0, 0, HWND_MESSAGE, NULL, NULL, NULL);
	}
	SetEvent(pThis->_hStartEvent);
	MSG msg;
	while (GetMessage(&msg, NULL, 0, 0)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
	return 0;
}

HotKeyManager::HotKeyManager() : _DisabledState(false)
{
	_hStartEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
	_hThread = reinterpret_cast<HANDLE>(_beginthreadex(NULL, 0, winThread, this, 0, &_uThreadId));
	if (_hThread && _uThreadId) {
		WaitForSingleObject(_hStartEvent, INFINITE);
	}
	CloseHandle(_hStartEvent);
	_hStartEvent = NULL;
}

HotKeyManager::~HotKeyManager()
{
	if (_hThread && _uThreadId) {
		PostThreadMessage(_uThreadId, WM_QUIT, (WPARAM)NULL, (LPARAM)NULL);
		WaitForSingleObject(_hThread, 5000);
		CloseHandle(_hThread);
	}
}

bool HotKeyManager::Valid() const
{
	return _uThreadId != 0 && _hWnd != NULL;
}

bool HotKeyManager::NotifyHotKeyEvent(unsigned uCode, bool bPressed)
{
    auto callback = []( Napi::Env env, Napi::Function jsCallback, int* value ) {
      // Transform native data into JS data, passing it to the provided
      // `jsCallback` -- the TSFN's JavaScript function.
      jsCallback.Call( {Napi::Number::New( env, *value )} );
      delete value;
    };

    if (this->_DisabledState) {
        return false;
    }
	TCONT::iterator cit = _hotkeys.find(uCode);
	if (cit != _hotkeys.end()) {
		const Napi::ThreadSafeFunction& tsfn = bPressed ? cit->second.first : cit->second.second;
		int* pCode = new int;
		*pCode = uCode;
		tsfn.NonBlockingCall(pCode, callback);
		return true;
	}
	return false;
}

void HotKeyManager::UpdateCallbacks(unsigned uCode, bool bSetInUse)
{
	TCONT::iterator cit = _hotkeys.find(uCode);
	if (cit != _hotkeys.end()) {
		if (bSetInUse) {
			cit->second.first.Acquire();
			cit->second.second.Acquire();
		} else {
			cit->second.first.Release();
			cit->second.second.Release();
		}
	}
}

std::string HotKeyManager::GenerateAtomName(WPARAM wKeys)
{
	std::string sAtomName("DesktopHotkey#");
	char buf[32] = {0};
	sAtomName.append(itoa(wKeys, buf, 16));
	return sAtomName;
}

DWORD HotKeyManager::checkShortcut(DWORD dwExcludeShortcutId, WORD wKeyCode, WORD wMod, bool fullCheck)
{
	if (!Valid()) {
		return 0; // unable to verify!
	}
    WPARAM wParam = MAKEWPARAM(wKeyCode, wMod);
    // check if hotkey already registered
    for (std::map<unsigned, WPARAM>::const_iterator it = _hotkeyIds.begin(); it != _hotkeyIds.end(); it ++) {
        if (it->second == wParam) {
            return it->first == dwExcludeShortcutId ? 0 : it->first;
        }
    }
    if (!fullCheck) {
        return 0;
    }
    // existing hotkey not found, try to register new hotkey in order to check for other conflicts
    std::string sName = HotKeyManager::GenerateAtomName(wParam);
    ATOM atm = GlobalFindAtomA(sName.c_str());
    if (atm != 0) {
        return 0xFFFFFFFF; // conflict!
    }
    atm = GlobalAddAtomA(sName.c_str());
    if (atm == 0) {
        return 0xFFFFFFFF; // unable to generate unique key id
    }
    bool hotKeyRegistered = 0 != SendMessage(_hWnd, WM_REGISTER_HOTKEY, wParam, atm);
    GlobalDeleteAtom(atm);
    if (!hotKeyRegistered) {
        return 0xFFFFFFFF; // unable to register such a hotkey
    }
    SendMessage(_hWnd, WM_UNREGISTER_HOTKEY, atm, 0);
    return 0;
}

DWORD HotKeyManager::registerShortcut(WORD wKeyCode, WORD wMod, const Napi::ThreadSafeFunction& tsfPress, const Napi::ThreadSafeFunction& tsfRelease)
{
	DWORD dwId = 0;
	if (!Valid()) {
		return 0;
	}
	if (0 != this->checkShortcut(0, wKeyCode, wMod, false)) {
	    return 0;
    }
	WPARAM wParam = MAKEWPARAM(wKeyCode, wMod);
	ATOM atm = GlobalAddAtomA(HotKeyManager::GenerateAtomName(wParam).c_str());
	if (atm) {
		_hotkeys[atm] = std::make_pair(tsfPress, tsfRelease);
		if (0 != SendMessage(_hWnd, WM_REGISTER_HOTKEY, wParam, atm)) {
			dwId = atm;
			_hotkeyIds[atm] = wParam;
		} else {
			GlobalDeleteAtom(atm);
		}
	}
	return dwId;
}

DWORD HotKeyManager::unregisterShortcut(DWORD dwId)
{
	DWORD dwRet = 0;
	TCONT::iterator it = _hotkeys.find(dwId);
	if (it != _hotkeys.end()) {
		ATOM atm = dwId;
		GlobalDeleteAtom(atm);
		SendMessage(_hWnd, WM_UNREGISTER_HOTKEY, dwId, 0);
		_hotkeys.erase(it);
		_hotkeyIds.erase(dwId);
		dwRet = 1;
	}
	return dwRet;
}

DWORD HotKeyManager::unregisterAllShortcuts()
{
	while (!_hotkeys.empty()) {
		unregisterShortcut(_hotkeys.begin()->first);
	}
	return 0;
}

void HotKeyManager::DisableAllShortcuts(bool bDisable)
{
    if (_DisabledState == bDisable) {
        log("(DHK): shortcuts already in %s state\r\n", bDisable ? "disabled" : "enabled");
        return;
    }
    _DisabledState = bDisable;
    for (std::map<unsigned, WPARAM>::const_iterator it = _hotkeyIds.begin(); it != _hotkeyIds.end(); it ++) {
        DWORD dwId = it->first;
        if (bDisable) {
            SendMessage(_hWnd, WM_UNREGISTER_HOTKEY, dwId, 0);
        } else {
		    SendMessage(_hWnd, WM_REGISTER_HOTKEY, it->second, dwId);
        }
    }
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	static DWORD pushedKey = 0;
	static unsigned pushedCode = 0;
	static UINT_PTR timerId = 0;
	switch (message) {
		case WM_DESTROY:
			PostQuitMessage(0);
			break;
		case WM_CREATE:
		{
			SetLastError(0);
			break;
		}
		case WM_REGISTER_HOTKEY:
		{
			SetLastError(0);
			BOOL b = ::RegisterHotKey(hWnd, lParam, HIWORD(wParam) | MOD_NOREPEAT, LOWORD(wParam));
			DWORD dw = GetLastError();
			return b ? lParam : 0;
			break;
		}
		case WM_UNREGISTER_HOTKEY:
		{
			SetLastError(0);
			BOOL b = ::UnregisterHotKey(hWnd, wParam);
			return b ? 0 : GetLastError();
			break;
		}
		case WM_HOTKEY:
		{
			if (timerId != 0) {
				if (timerId == wParam) {
					log("(DHK): skip evt%d: already active\r\n", timerId);
					return 0;
				} else {
					log("(DHK): force evt%d cancel: switch\r\n", timerId);
					KillTimer(hWnd, timerId);
					g_pHotKeyManager->NotifyHotKeyEvent(timerId, false);
				}
			}
			unsigned uKeyCode = wParam;
			pushedKey = HIWORD(lParam);
			pushedCode = wParam;
			if (g_pHotKeyManager->NotifyHotKeyEvent(wParam, true)) {
			    timerId = SetTimer(hWnd, wParam, 100, NULL);
			    log("(DHK): new evt%d activated\r\n", timerId);
			}
			break;
		}
		case WM_TIMER:
		{
			SHORT keyState = GetAsyncKeyState(pushedKey);
			if (keyState >= 0) {
				KillTimer(hWnd, timerId);
				g_pHotKeyManager->NotifyHotKeyEvent(pushedCode, false);
				timerId = 0;
				log("(DHK): evt%d deactivated\r\n", pushedCode);

			} else {
				log("(DHK): evt%d cont(%d) \r\n", pushedCode, keyState);
			}
			break;
		}
		default:
			return DefWindowProc(hWnd, message, wParam, lParam);
	}
	return 0;
}
