#include "Hotkeys.h"

template<typename T, typename TPrim>
T emptyImpl(const Napi::CallbackInfo& info, TPrim defValue)
{
	Napi::Env env = info.Env();
	Napi::TypeError::New(env, "procedure not implemented on linux").ThrowAsJavaScriptException();
	return T::New(env, defValue);
}

Napi::Number HotKeys::start(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::stop(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Boolean HotKeys::started(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Boolean, bool>(info, false);
}

Napi::Number HotKeys::restart(const Napi::CallbackInfo& info)
{
    return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::setLoggerCb(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::registerShortcut(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::unregisterShortcut(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::unregisterAllShortcuts(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::macShowAccessibilitySettings(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::macSubscribeAccessibilityUpdates(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Number HotKeys::macUnsubscribeAccessibilityUpdates(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Number, double>(info, -1);
}

Napi::Boolean HotKeys::macCheckAccessibilityGranted(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Boolean, bool>(info, true);
}

Napi::Array HotKeys::convertHotkeysCodes(const Napi::CallbackInfo& info)
{
	return return emptyImpl<Napi::Array, size_t>(env, 0);
}

Napi::Number checkHotkeyConflicts(const Napi::CallbackInfo& info);
{
	return emptyImpl<Napi::Number, unsigned>(info, 0);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports)
{
	exports.Set("start", Napi::Function::New(env, HotKeys::start));
	exports.Set("stop", Napi::Function::New(env, HotKeys::stop));
	exports.Set("registerShortcut", Napi::Function::New(env, HotKeys::registerShortcut));
	exports.Set("unregisterShortcut", Napi::Function::New(env, HotKeys::unregisterShortcut));
	exports.Set("unregisterAllShortcuts", Napi::Function::New(env, HotKeys::unregisterAllShortcuts));
	exports.Set("macCheckAccessibilityGranted", Napi::Function::New(env, HotKeys::macCheckAccessibilityGranted));
	exports.Set("macShowAccessibilitySettings", Napi::Function::New(env, HotKeys::macShowAccessibilitySettings));
	exports.Set("macSubscribeAccessibilityUpdates", Napi::Function::New(env, HotKeys::macSubscribeAccessibilityUpdates));
	exports.Set("macUnsubscribeAccessibilityUpdates", Napi::Function::New(env, HotKeys::macUnsubscribeAccessibilityUpdates));
	exports.Set("convertHotkeysCodes", Napi::Function::New(env, HotKeys::convertHotkeysCodes));
	exports.Set("checkHotkeyConflicts", Napi::Function::New(env, HotKeys::checkHotkeyConflicts));
	return exports;
}
