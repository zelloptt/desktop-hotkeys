#include "Hotkeys.h"
#define TARGET_OS_MAC
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>

Napi::ThreadSafeFunction g_fnAccChanged; // invoked for every accessibility on/off

bool subscribedForAccNotifications = false;

static void onAccChanged(CFNotificationCenterRef center, void *observer, CFStringRef name_cf,
					 const void *object, CFDictionaryRef userInfo)
{
    fprintf(stderr, "\r\n\r\nAccessibility has changed, current %d\r\n\r\n", (AXIsProcessTrusted() ? 1 : 0));
    g_fnAccChanged.NonBlockingCall();
    return;
}

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

Napi::Boolean HotKeys::macCheckAccessibilityGranted(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Boolean::New(env, AXIsProcessTrusted());
}

Napi::Number HotKeys::macSubscribeAccessibilityUpdates(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	if (info.Length() < 1 || !info[0].IsFunction()) {
    	Napi::TypeError::New(env, "accessibility check cb is required").ThrowAsJavaScriptException();
    }
    if (subscribedForAccNotifications) {
        macUnsubscribeAccessibilityUpdates(info);
    }
    fprintf(stderr, "\r\n*** macSubscribeAccessibilityUpdates: Access %s\r\n", AXIsProcessTrusted() ? "enabled":"disabled");
	g_fnAccChanged = Napi::ThreadSafeFunction::New(
        env,
        info[0].As<Napi::Function>(),
        "desktop-hotkeys acc changed cb",
        0,
        1);
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDistributedCenter(),
        &g_fnAccChanged,
        onAccChanged,
        CFSTR("com.apple.accessibility.api"),
        nil,
        CFNotificationSuspensionBehaviorDeliverImmediately);
    return Napi::Number::New(env, 0);
}

Napi::Number HotKeys::macUnsubscribeAccessibilityUpdates(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	CFNotificationCenterRemoveObserver(
	    CFNotificationCenterGetDistributedCenter(),
	    &g_fnAccChanged,
	    CFSTR("com.apple.accessibility.api"),
	    nil);
    g_fnAccChanged.Release();
    subscribedForAccNotifications = false;
	return Napi::Number::New(env, 0);
}

Napi::Number HotKeys::macShowAccessibilitySettings(const Napi::CallbackInfo& info)
{
    NSString *urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 0);
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
	return exports;
}
