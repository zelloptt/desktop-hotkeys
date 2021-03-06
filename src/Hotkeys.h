#include <napi.h>

namespace HotKeys
{
	Napi::Number start(const Napi::CallbackInfo& info);
	Napi::Number stop(const Napi::CallbackInfo& info);
	Napi::Number registerShortcut(const Napi::CallbackInfo& info);
	Napi::Number unregisterShortcut(const Napi::CallbackInfo& info);
	Napi::Number unregisterAllShortcuts(const Napi::CallbackInfo& info);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports);
