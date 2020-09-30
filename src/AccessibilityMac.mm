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
