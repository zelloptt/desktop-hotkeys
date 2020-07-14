#include "Hotkeys.h"

Napi::Number HotKeys::start(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 0);
}

Napi::Number HotKeys::stop(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 1);
}

Napi::Number HotKeys::registerShortcut(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 0);
}

Napi::Number HotKeys::unregisterShortcut(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 0);
}

Napi::Number HotKeys::unregisterAllShortcuts(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	unsigned uRetValue = static_cast<unsigned>(-1);
	return Napi::Number::New(env, uRetValue);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports)
{
	exports.Set("start", Napi::Function::New(env, HotKeys::start));
	exports.Set("stop", Napi::Function::New(env, HotKeys::stop));
	exports.Set("registerShortcut", Napi::Function::New(env, HotKeys::registerShortcut));
	exports.Set("unregisterShortcut", Napi::Function::New(env, HotKeys::unregisterShortcut));
	exports.Set("unregisterAllShortcuts", Napi::Function::New(env, HotKeys::unregisterAllShortcuts));
	return exports;
}
