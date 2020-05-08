#include "Hotkeys.h"

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <process.h>
#include <map>

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);

class CHotKeyManager;
static CHotKeyManager* g_pHKManager;
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



class CHotKeyManager
{
	HANDLE m_hThread;
	HANDLE m_hStartEvent;
	unsigned m_uThreadId;
	HWND m_hWnd;
	typedef std::map<unsigned, std::pair<Napi::ThreadSafeFunction, Napi::ThreadSafeFunction>> TCONT;
	TCONT m_mp;
public:
	static unsigned __stdcall winThread(void* ptr)
	{
		CHotKeyManager* pThis = reinterpret_cast<CHotKeyManager*>(ptr);
		static const char* class_name = "ZelloHotKeyManager_class";
		WNDCLASSEX wx = {};
		wx.cbSize = sizeof(WNDCLASSEX);
		wx.lpfnWndProc = WndProc;
		wx.hInstance = ::GetModuleHandle(NULL);
		wx.lpszClassName = class_name;
		if (RegisterClassEx(&wx)) {
			pThis->m_hWnd = CreateWindowEx(0, class_name, "no title", 0, 0, 0, 0, 0, HWND_MESSAGE, NULL, NULL, NULL);
		}
		SetEvent(pThis->m_hStartEvent);
		MSG msg;
		while (GetMessage(&msg, NULL, 0, 0)) {
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}
		return 0;
	}

	CHotKeyManager()
	{
		m_hStartEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
		m_hThread = reinterpret_cast<HANDLE>(_beginthreadex(NULL, 0, winThread, this, 0, &m_uThreadId));
		if (m_hThread && m_uThreadId) {
			WaitForSingleObject(m_hStartEvent, INFINITE);
		}
		CloseHandle(m_hStartEvent);
		m_hStartEvent = NULL;
	}
	~CHotKeyManager()
	{
		if (m_hThread && m_uThreadId) {
			PostThreadMessage(m_uThreadId, WM_QUIT, (WPARAM)NULL, (LPARAM)NULL);
			WaitForSingleObject(m_hThread, 5000);
			CloseHandle(m_hThread);
		}
	}

	bool Valid() const
	{
		return m_uThreadId != 0 && m_hWnd != NULL;
	}
	void NotifyHKEvent(unsigned uCode, bool bPressed)
	{
		TCONT::iterator cit = m_mp.find(uCode);
		if (cit != m_mp.end()) {
			Napi::ThreadSafeFunction& tsfn = bPressed ? cit->second.first : cit->second.second;
			tsfn.NonBlockingCall();
		}
	}
	void UpdateCallbacks(unsigned uCode, bool bSetInUse)
	{
		TCONT::iterator cit = m_mp.find(uCode);
		if (cit != m_mp.end()) {
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
			std::string s("Zello Desktop hk#");
			char buf[32] = { 0 };
			s.append(itoa(wParam, buf, 16));
			ATOM atm = GlobalAddAtomA(s.c_str());
			if (atm) {
				m_mp.insert(std::make_pair(atm, std::make_pair(tsfPress, tsfRelease)));
				//m_mp[atm] = std::make_pair(tsfPress, tsfRelease);
				if (0 != SendMessage(m_hWnd, WM_USER + 0x11, wParam, atm)) {
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
		TCONT::iterator it = m_mp.find(dwId);
		if (it != m_mp.end()) {
			ATOM atm = dwId;
			GlobalDeleteAtom(atm);
			SendMessage(m_hWnd, WM_USER + 0x12, dwId, 0);
			m_mp.erase(it);
		}
		return dwRet;
	}
	DWORD unregisterAllShortcuts()
	{
		while (!m_mp.empty()) {
			unregisterShortcut(m_mp.begin()->first);
		}
		return 0;
	}
};

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	static DWORD uPushedKey = 0;
	static unsigned uPushedCode = 0;
	static UINT_PTR g_TimerId = 0;
	switch (message) {
		case WM_DESTROY:
			PostQuitMessage(0);
			break;
		case WM_CREATE:
		{
			SetLastError(0);

			break;
		}
		case WM_USER + 0x11:
		{
			SetLastError(0);
			BOOL b = ::RegisterHotKey(hWnd, lParam, HIWORD(wParam) | MOD_NOREPEAT, LOWORD(wParam));
			DWORD dw = GetLastError();
			return b ? lParam : 0;
			break;
		}
		case WM_USER + 0x12:
		{
			SetLastError(0);
			BOOL b = ::UnregisterHotKey(hWnd, wParam);
			return b ? 0 : GetLastError();
			break;
		}
		case WM_HOTKEY:
		{
			if (g_TimerId != 0) {
				if (g_TimerId == wParam) {
					log("HK: skip evt%d: already active\r\n", g_TimerId);
					return 0;
				} else {
					log("HK: force evt%d cancel: switch\r\n", g_TimerId);
					KillTimer(hWnd, g_TimerId);
					g_pHKManager->NotifyHKEvent(g_TimerId, false);
				}
			}
			unsigned uKeyCode = wParam;
			uPushedKey = HIWORD(lParam);
			uPushedCode = wParam;
			g_pHKManager->NotifyHKEvent(wParam, true);
			g_TimerId = SetTimer(hWnd, wParam, 100, NULL);
			log("HK: new evt%d activated\r\n", g_TimerId);
			break;
		}
		case WM_TIMER:
		{
			SHORT keyState = GetAsyncKeyState(uPushedKey);
			if (keyState >= 0) {
				KillTimer(hWnd, g_TimerId);
				g_pHKManager->NotifyHKEvent(uPushedCode, false);
				g_TimerId = 0;
				log("HK: evt%d deactivated\r\n", uPushedCode);

			} else {
				log("HK: evt%d cont(%d) \r\n", uPushedCode, keyState);
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
		log("HK: Starting verbose module");
	}
	if (g_pHKManager == NULL) {
		g_pHKManager = new CHotKeyManager();
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
	if (info.Length() < 3 || !info[0].IsArray() || !info[1].IsFunction() || !info[2].IsFunction()) {
		Napi::TypeError::New(env, "Array/Function/Function expected").ThrowAsJavaScriptException();
	}
	Napi::Array arrKeys = info[0].As<Napi::Array>();
	Napi::Function fnPressed = info[1].As<Napi::Function>();
	Napi::Function fnReleased = info[2].As<Napi::Function>();

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
				fnPressed,  // JavaScript function called asynchronously
				"ZelloDesktop hotkey pressed cb",         // Name
				0,                       // Unlimited queue
				2),
			Napi::ThreadSafeFunction::New(
				env,
				fnReleased,  // JavaScript function called asynchronously
				"ZelloDesktop hotkey released cb ",         // Name
				0,                       // Unlimited queue
				2)
		);
	}

	return Napi::Number::New(env, uRetValue);
}

Napi::Number HK::unregisterShortcut(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	if (info.Length() < 1 || !info[0].IsNumber()) {
		Napi::TypeError::New(env, "Hotkey id expected").ThrowAsJavaScriptException();
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
