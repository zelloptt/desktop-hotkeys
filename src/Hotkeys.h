#include <napi.h>

namespace HK
{
	Napi::Number start(const Napi::CallbackInfo& info);
	Napi::Number stop(const Napi::CallbackInfo& info);
	Napi::Number registerShortcut(const Napi::CallbackInfo& info);
	Napi::Number unregisterShortcut(const Napi::CallbackInfo& info);
	Napi::Number unregisterAllShortcuts(const Napi::CallbackInfo& info);
}

Napi::Object doInitHK(Napi::Env env, Napi::Object exports);
