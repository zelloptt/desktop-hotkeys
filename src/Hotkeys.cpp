#include "Hotkeys.h"
#include "HotkeyManager.h"

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

extern HotKeyManager* g_pHotKeyManager;
extern bool g_bVerboseMode;

bool log(const char* format, ...);

Napi::Number HotKeys::start(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	if (info.Length() > 0 && info[0].IsBoolean()) {
		g_bVerboseMode = info[0].As<Napi::Boolean>();
		log("(DHK): Starting module, verbose logging is on");
	}
	if (g_pHotKeyManager == NULL) {
		g_pHotKeyManager = new HotKeyManager();
	}
	return Napi::Number::New(env, g_pHotKeyManager->Valid() ? 1 : 0);
}

Napi::Number HotKeys::stop(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	unsigned uRetVal = 0;
	if (g_pHotKeyManager) {
		delete g_pHotKeyManager;
		g_pHotKeyManager = NULL;
		uRetVal = 1;
	}
	return Napi::Number::New(env, uRetVal);
}

Napi::Boolean HotKeys::started(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Boolean::New(env, g_pHotKeyManager != NULL);
}

Napi::Number HotKeys::restart(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 0);
}

Napi::Number HotKeys::setLoggerCb(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 0);
}

Napi::Number HotKeys::registerShortcut(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	Napi::Array arrKeys;
	Napi::Function fnPressed;
	Napi::Function fnReleased;
	bool keysAreVirtualCodes = true;
	unsigned argCount = info.Length();
	while (argCount > 0) {
		if (info[argCount - 1].IsEmpty() || info[argCount - 1].IsUndefined() || info[argCount - 1].IsNull()) {
			argCount = argCount - 1;
		} else {
			break;
		}
	}

	if (argCount >= 3 && info[0].IsArray() && info[1].IsFunction() && info[2].IsFunction()) {
		arrKeys = info[0].As<Napi::Array>();
		fnPressed = info[1].As<Napi::Function>();
		fnReleased = info[2].As<Napi::Function>();
		if (argCount >= 4 && info[3].IsBoolean()) {
			keysAreVirtualCodes = info[3].As<Napi::Boolean>();
		}
	} else if (argCount == 2 && info[0].IsArray() && info[1].IsFunction()) {
		arrKeys = info[0].As<Napi::Array>();
		fnPressed = info[1].As<Napi::Function>();
	} else {
		log("(DHK): invalid registerShortcut arguments: Array/Function/Function or Array/Function expected");
		Napi::TypeError::New(env, "invalid registerShortcut arguments: Array/Function/Function or Array/Function expected").ThrowAsJavaScriptException();
		return Napi::Number::New(env, 0);
	}

	WORD wKeyCode = 0, wMod = 0;
	for (size_t idx = 0; idx < arrKeys.Length(); ++idx) {
		Napi::Value v = arrKeys[idx];
		DWORD dwCode = v.As<Napi::Number>().Uint32Value();
		DWORD dw = keysAreVirtualCodes ? dwCode : MapVirtualKey(dwCode, MAPVK_VSC_TO_VK);
		switch (dw) {
			case 0:
			{
				char szErrBuf[64];
				if (keysAreVirtualCodes) {
					sprintf(szErrBuf, "invalid arguments: virtual key code cannot be 0");
				} else {
					sprintf(szErrBuf, "Can't convert scancode %d(%X) to VKCode", dwCode, dwCode);
				}
				Napi::Error::New(env, szErrBuf).ThrowAsJavaScriptException();
				return Napi::Number::New(env, 0);
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
	if (g_pHotKeyManager && g_pHotKeyManager->Valid()) {
		uRetValue = g_pHotKeyManager->registerShortcut(wKeyCode, wMod,
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

Napi::Number HotKeys::unregisterShortcut(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	if (info.Length() < 1 || !info[0].IsNumber()) {
		Napi::TypeError::New(env, "Invalid argument: Hotkey id expected").ThrowAsJavaScriptException();
	}
	unsigned uRetValue = static_cast<unsigned>(-1);
	if (g_pHotKeyManager && g_pHotKeyManager->Valid()) {
		uRetValue = g_pHotKeyManager->unregisterShortcut(info[0].As<Napi::Number>().Uint32Value());
	}
	return Napi::Number::New(env, uRetValue);
}

Napi::Number HotKeys::unregisterAllShortcuts(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	unsigned uRetValue = static_cast<unsigned>(-1);
	if (g_pHotKeyManager && g_pHotKeyManager->Valid()) {
		uRetValue = g_pHotKeyManager->unregisterAllShortcuts();
	}
	return Napi::Number::New(env, uRetValue);
}

template<typename T, typename TPrim>
T macAccessibilityUnavailable(const Napi::CallbackInfo& info, TPrim defValue)
{
	Napi::Env env = info.Env();
	Napi::TypeError::New(env, "accessibility settings do not exist on win").ThrowAsJavaScriptException();
	return T::New(env, defValue);
}

Napi::Number HotKeys::macShowAccessibilitySettings(const Napi::CallbackInfo& info)
{
	return macAccessibilityUnavailable<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::macSubscribeAccessibilityUpdates(const Napi::CallbackInfo& info)
{
	return macAccessibilityUnavailable<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::macUnsubscribeAccessibilityUpdates(const Napi::CallbackInfo& info)
{
	return macAccessibilityUnavailable<Napi::Number, double>(info, -1);
}

Napi::Boolean HotKeys::macCheckAccessibilityGranted(const Napi::CallbackInfo& info)
{
	return macAccessibilityUnavailable<Napi::Boolean, bool>(info, true);
}

Napi::Number HotKeys::setHotkeysEnabled(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	if (info.Length() > 0 && info[0].IsBoolean()) {
		bool bEnable = info[0].As<Napi::Boolean>();
		log(bEnable ? "(DHK): Enable hotkeys" : "(DHK): Disable hotkeys");
	    if (g_pHotKeyManager) {
		    g_pHotKeyManager->DisableAllShortcuts(!bEnable);
	    }
    }
    return Napi::Number::New(env, 0);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports)
{
	exports.Set("start", Napi::Function::New(env, HotKeys::start));
	exports.Set("stop", Napi::Function::New(env, HotKeys::stop));
	exports.Set("started", Napi::Function::New(env, HotKeys::started));
	exports.Set("restart", Napi::Function::New(env, HotKeys::restart));
	exports.Set("setHotkeysEnabled", Napi::Function::New(env, HotKeys::setHotkeysEnabled));
	exports.Set("registerShortcut", Napi::Function::New(env, HotKeys::registerShortcut));
	exports.Set("unregisterShortcut", Napi::Function::New(env, HotKeys::unregisterShortcut));
	exports.Set("unregisterAllShortcuts", Napi::Function::New(env, HotKeys::unregisterAllShortcuts));
	exports.Set("macCheckAccessibilityGranted", Napi::Function::New(env, HotKeys::macCheckAccessibilityGranted));
	exports.Set("macShowAccessibilitySettings", Napi::Function::New(env, HotKeys::macShowAccessibilitySettings));
	exports.Set("macSubscribeAccessibilityUpdates", Napi::Function::New(env, HotKeys::macSubscribeAccessibilityUpdates));
	exports.Set("macUnsubscribeAccessibilityUpdates", Napi::Function::New(env, HotKeys::macUnsubscribeAccessibilityUpdates));
	return exports;
}
