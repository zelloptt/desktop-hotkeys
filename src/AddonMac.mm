#include "Hotkeys.h"

Napi::Object InitAll(Napi::Env env, Napi::Object exports)
{
	exports.Set("start", Napi::Function::New(env, HotKeys::start));
	exports.Set("stop", Napi::Function::New(env, HotKeys::stop));
	exports.Set("restart", Napi::Function::New(env, HotKeys::restart));
	exports.Set("setLoggerCb", Napi::Function::New(env, HotKeys::setLoggerCb));
	exports.Set("collectPressedKeyCodes", Napi::Function::New(env, HotKeys::collectPressedKeyCodes));
	exports.Set("pressedKeyCodes", Napi::Function::New(env, HotKeys::pressedKeyCodes));
	exports.Set("registerShortcut", Napi::Function::New(env, HotKeys::registerShortcut));
	exports.Set("unregisterShortcut", Napi::Function::New(env, HotKeys::unregisterShortcut));
	exports.Set("unregisterAllShortcuts", Napi::Function::New(env, HotKeys::unregisterAllShortcuts));
	exports.Set("macCheckAccessibilityGranted", Napi::Function::New(env, HotKeys::macCheckAccessibilityGranted));
	exports.Set("macShowAccessibilitySettings", Napi::Function::New(env, HotKeys::macShowAccessibilitySettings));
	exports.Set("macSubscribeAccessibilityUpdates", Napi::Function::New(env, HotKeys::macSubscribeAccessibilityUpdates));
	exports.Set("macUnsubscribeAccessibilityUpdates", Napi::Function::New(env, HotKeys::macUnsubscribeAccessibilityUpdates));
	return exports;
}
