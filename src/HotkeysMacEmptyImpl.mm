#include "Hotkeys.h"

template<typename T, typename TPrim>
T emptyImpl(const Napi::CallbackInfo& info, TPrim defValue)
{
	Napi::Env env = info.Env();
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

Napi::Boolean HotKeys::collectPressedKeyCodes(const Napi::CallbackInfo& info)
{
	return emptyImpl<Napi::Boolean, bool>(info, false);
}

Napi::Array HotKeys::pressedKeyCodes(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Array::New(env, 0);
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

