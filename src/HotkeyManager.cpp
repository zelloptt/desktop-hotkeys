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

HotKeyManager::HotKeyManager()
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

void HotKeyManager::NotifyHotKeyEvent(unsigned uCode, bool bPressed)
{
	TCONT::iterator cit = _hotkeys.find(uCode);
	if (cit != _hotkeys.end()) {
		Napi::ThreadSafeFunction& tsfn = bPressed ? cit->second.first : cit->second.second;
		tsfn.NonBlockingCall();
	}
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

DWORD HotKeyManager::registerShortcut(WORD wKeyCode, WORD wMod, const Napi::ThreadSafeFunction& tsfPress, const Napi::ThreadSafeFunction& tsfRelease)
{
	DWORD dwId = 0;
	if (!Valid()) {
		return 0;
	}
	WPARAM wParam = MAKEWPARAM(wKeyCode, wMod);
	std::string s("DesktopHotkey#");
	char buf[32] = { 0 };
	s.append(itoa(wParam, buf, 16));
	ATOM atm = GlobalAddAtomA(s.c_str());
	if (atm) {
		_hotkeys[atm] = std::make_pair(tsfPress, tsfRelease);
		if (0 != SendMessage(_hWnd, WM_REGISTER_HOTKEY, wParam, atm)) {
			dwId = atm;
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
			g_pHotKeyManager->NotifyHotKeyEvent(wParam, true);
			timerId = SetTimer(hWnd, wParam, 100, NULL);
			log("(DHK): new evt%d activated\r\n", timerId);
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
