
/* src/main.cpp */
#include <napi.h>
#include "Hotkeys.h"

Napi::Object InitAll(Napi::Env env, Napi::Object exports)
{
	return doInitHK(env, exports);
}

NODE_API_MODULE(globalhotkeys, InitAll)
