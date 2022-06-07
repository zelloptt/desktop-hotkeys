#include <napi.h>

namespace HotKeys
{
	Napi::Number start(const Napi::CallbackInfo& info);
	Napi::Number stop(const Napi::CallbackInfo& info);
	Napi::Boolean started(const Napi::CallbackInfo& info);
	Napi::Number restart(const Napi::CallbackInfo& info);
	Napi::Number setLoggerCb(const Napi::CallbackInfo& info);
	Napi::Number registerShortcut(const Napi::CallbackInfo& info);
	Napi::Number unregisterShortcut(const Napi::CallbackInfo& info);
	Napi::Number unregisterAllShortcuts(const Napi::CallbackInfo& info);
	Napi::Boolean collectPressedKeyCodes(const Napi::CallbackInfo& info);
	Napi::Array pressedKeyCodes(const Napi::CallbackInfo& info);
	Napi::Boolean macCheckAccessibilityGranted(const Napi::CallbackInfo& info);
	Napi::Number macShowAccessibilitySettings(const Napi::CallbackInfo& info);
	Napi::Number macSubscribeAccessibilityUpdates(const Napi::CallbackInfo& info);
	Napi::Number macUnsubscribeAccessibilityUpdates(const Napi::CallbackInfo& info);
	Napi::Number setHotkeysEnabled(const Napi::CallbackInfo& info);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports);
