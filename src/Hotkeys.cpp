#include "Hotkeys.h"

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <process.h>
#include <map>

#define WM_REGISTER_HK		WM_USER + 0x11
#define WM_UNREGISTER_HK	WM_USER + 0x12

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);

class HotKeyManager;
static HotKeyManager* g_pHKManager;
static bool g_bVerboseMode = false;

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

class HotKeyManager
{
	HANDLE _hThread;
	HANDLE _hStartEvent;
	unsigned _uThreadId;
	HWND _hWnd;
	typedef std::map<unsigned, std::pair<Napi::ThreadSafeFunction, Napi::ThreadSafeFunction>> TCONT;
	TCONT _hotkeys;
public:
	static unsigned __stdcall winThread(void* ptr)
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

	HotKeyManager()
	{
		_hStartEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
		_hThread = reinterpret_cast<HANDLE>(_beginthreadex(NULL, 0, winThread, this, 0, &_uThreadId));
		if (_hThread && _uThreadId) {
			WaitForSingleObject(_hStartEvent, INFINITE);
		}
		CloseHandle(_hStartEvent);
		_hStartEvent = NULL;
	}

	~HotKeyManager()
	{
		if (_hThread && _uThreadId) {
			PostThreadMessage(_uThreadId, WM_QUIT, (WPARAM)NULL, (LPARAM)NULL);
			WaitForSingleObject(_hThread, 5000);
			CloseHandle(_hThread);
		}
	}

	bool Valid() const
	{
		return _uThreadId != 0 && _hWnd != NULL;
	}

	void NotifyHKEvent(unsigned uCode, bool bPressed)
	{
		TCONT::iterator cit = _hotkeys.find(uCode);
		if (cit != _hotkeys.end()) {
			Napi::ThreadSafeFunction& tsfn = bPressed ? cit->second.first : cit->second.second;
			tsfn.NonBlockingCall();
		}
	}

	void UpdateCallbacks(unsigned uCode, bool bSetInUse)
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

	DWORD registerShortcut(WORD wKeyCode, WORD wMod, const Napi::ThreadSafeFunction& tsfPress, const Napi::ThreadSafeFunction& tsfRelease)
	{
		DWORD dwId = 0;
		if (Valid()) {
			WPARAM wParam = MAKEWPARAM(wKeyCode, wMod);
			std::string s("DesktopHotkey#");
			char buf[32] = { 0 };
			s.append(itoa(wParam, buf, 16));
			ATOM atm = GlobalAddAtomA(s.c_str());
			if (atm) {
				//_hotkeys.insert(std::make_pair(atm, std::make_pair(tsfPress, tsfRelease)));
				_hotkeys[atm] = std::make_pair(tsfPress, tsfRelease);
				if (0 != SendMessage(_hWnd, WM_REGISTER_HK, wParam, atm)) {
					dwId = atm;
				} else {
					GlobalDeleteAtom(atm);
				}
			}
		}
		return dwId;
	}

	DWORD unregisterShortcut(DWORD dwId)
	{
		DWORD dwRet = 0;
		TCONT::iterator it = _hotkeys.find(dwId);
		if (it != _hotkeys.end()) {
			ATOM atm = dwId;
			GlobalDeleteAtom(atm);
			SendMessage(_hWnd, WM_UNREGISTER_HK, dwId, 0);
			_hotkeys.erase(it);
		}
		return dwRet;
	}

	DWORD unregisterAllShortcuts()
	{
		while (!_hotkeys.empty()) {
			unregisterShortcut(_hotkeys.begin()->first);
		}
		return 0;
	}
};

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
		case WM_REGISTER_HK:
		{
			SetLastError(0);
			BOOL b = ::RegisterHotKey(hWnd, lParam, HIWORD(wParam) | MOD_NOREPEAT, LOWORD(wParam));
			DWORD dw = GetLastError();
			return b ? lParam : 0;
			break;
		}
		case WM_UNREGISTER_HK:
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
					g_pHKManager->NotifyHKEvent(timerId, false);
				}
			}
			unsigned uKeyCode = wParam;
			pushedKey = HIWORD(lParam);
			pushedCode = wParam;
			g_pHKManager->NotifyHKEvent(wParam, true);
			timerId = SetTimer(hWnd, wParam, 100, NULL);
			log("(DHK): new evt%d activated\r\n", timerId);
			break;
		}
		case WM_TIMER:
		{
			SHORT keyState = GetAsyncKeyState(pushedKey);
			if (keyState >= 0) {
				KillTimer(hWnd, timerId);
				g_pHKManager->NotifyHKEvent(pushedCode, false);
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

Napi::Number HK::start(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	if (info.Length() > 0 && info[0].IsBoolean()) {
		g_bVerboseMode = info[0].As<Napi::Boolean>();
		log("(DHK): Starting module, verbose logging is on");
	}
	if (g_pHKManager == NULL) {
		g_pHKManager = new HotKeyManager();
	}
	return Napi::Number::New(env, g_pHKManager->Valid() ? 1 : 0);
}

Napi::Number HK::stop(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	unsigned uRetVal = 0;
	if (g_pHKManager) {
		delete g_pHKManager;
		g_pHKManager = NULL;
		uRetVal = 1;
	}
	return Napi::Number::New(env, uRetVal);
}

Napi::Number HK::registerShortcut(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	Napi::Array arrKeys;
	Napi::Function fnPressed;
	Napi::Function fnReleased;
	if (info.Length() >= 3 && info[0].IsArray() && info[1].IsFunction() && info[2].IsFunction()) {
		arrKeys = info[0].As<Napi::Array>();
		fnPressed = info[1].As<Napi::Function>();
		fnReleased = info[2].As<Napi::Function>();
	} else if (info.Length() == 2 && info[0].IsArray() && info[1].IsFunction()) {
		arrKeys = info[0].As<Napi::Array>();
		fnPressed = info[1].As<Napi::Function>();
	} else {
		Napi::TypeError::New(env, "invalid arguments: Array/Function/Function or Array/Function expected").ThrowAsJavaScriptException();
	}

	WORD wKeyCode = 0, wMod = 0;
	for (size_t idx = 0; idx < arrKeys.Length(); ++idx) {
		Napi::Value v = arrKeys[idx];
		DWORD dwScanCode = v.As<Napi::Number>().Uint32Value();
		DWORD dw = MapVirtualKey(dwScanCode, MAPVK_VSC_TO_VK);
		switch (dw) {
			case 0:
			{
				char szErrBuf[64];
				sprintf(szErrBuf, "Can't convert scancode %d(%X) to VKCode", dwScanCode, dwScanCode);
				Napi::Error::New(env, szErrBuf).ThrowAsJavaScriptException();
			}
			break;
			case VK_CONTROL:
			case VK_LCONTROL:
			case VK_RCONTROL:
				wMod = wMod | MOD_CONTROL;
				break;
			case VK_SHIFT:
			case VK_LSHIFT:
			case VK_RSHIFT:
				wMod = wMod | MOD_SHIFT;
				break;
			case VK_MENU:
			case VK_LMENU:
			case VK_RMENU:
				wMod = wMod | MOD_ALT;
				break;
			case VK_LWIN:
			case VK_RWIN:
				wMod = wMod | MOD_WIN;
				break;
			default:
				wKeyCode = static_cast<WORD>(dw);
		}
	}
	unsigned uRetValue = 0;
	if (g_pHKManager && g_pHKManager->Valid()) {
		uRetValue = g_pHKManager->registerShortcut(wKeyCode, wMod,
			Napi::ThreadSafeFunction::New(
				env,
				fnPressed,
				"desktop-hotkeys pressed cb",
				0,
				2),
			Napi::ThreadSafeFunction::New(
				env,
				fnReleased,
				"desktop-hotkeys released cb ",
				0,
				2)
		);
	}
	return Napi::Number::New(env, uRetValue);
}

Napi::Number HK::unregisterShortcut(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	if (info.Length() < 1 || !info[0].IsNumber()) {
		Napi::TypeError::New(env, "Invalid argument: Hotkey id expected").ThrowAsJavaScriptException();
	}
	unsigned uRetValue = static_cast<unsigned>(-1);
	if (g_pHKManager && g_pHKManager->Valid()) {
		uRetValue = g_pHKManager->unregisterShortcut(info[0].As<Napi::Number>().Uint32Value());
	}
	return Napi::Number::New(env, uRetValue);
}

Napi::Number HK::unregisterAllShortcuts(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	unsigned uRetValue = static_cast<unsigned>(-1);
	if (g_pHKManager && g_pHKManager->Valid()) {
		uRetValue = g_pHKManager->unregisterAllShortcuts();
	}
	return Napi::Number::New(env, uRetValue);
}

Napi::Object doInitHK(Napi::Env env, Napi::Object exports)
{
	exports.Set("start", Napi::Function::New(env, HK::start));
	exports.Set("stop", Napi::Function::New(env, HK::stop));
	exports.Set("registerShortcut", Napi::Function::New(env, HK::registerShortcut));
	exports.Set("unregisterShortcut", Napi::Function::New(env, HK::unregisterShortcut));
	exports.Set("unregisterAllShortcuts", Napi::Function::New(env, HK::unregisterAllShortcuts));
	return exports;
}
