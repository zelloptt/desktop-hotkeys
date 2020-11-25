#include "Hotkeys.h"
#define TARGET_OS_MAC
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>
#include <thread>
#include <unistd.h>

Napi::ThreadSafeFunction g_fnAccChanged; // invoked for every accessibility on/off
bool subscribedForAccNotifications = false;

static void* cbCall(void* arg)
{
    fprintf(stderr, "\r\n*** starting cb thread\r\n");
    usleep(1000);
    if (subscribedForAccNotifications) {
	    g_fnAccChanged.Acquire();
	    g_fnAccChanged.BlockingCall();
	    g_fnAccChanged.Release();
	} else {
        fprintf(stderr, "\r\n*** skip cb, cb proc not set\r\n");
	}
	return arg;
}

void runThread()
{
	pthread_attr_t attr;
	pthread_attr_init(&attr);
	pthread_t threadCb;
	pthread_create(&threadCb, &attr, cbCall, nullptr);
	pthread_attr_destroy(&attr);
}

@interface AccObserver : NSObject {
    BOOL granted;
}
- (void)start;
- (void)stop;
- (void)refresh;
- (BOOL)status;
- (void)didToggleAccessStatus:(NSNotification *)notification;
@end

@implementation AccObserver

+ (id)get {
    static AccObserver *observer = nil;
    @synchronized(self) {
        if (observer == nil) {
            observer = [[self alloc] init];
            [observer start];
        }
    }
    return observer;
}
- (void)start {
    // Delegate method per NSApplicationDelegate formal protocol.

    // Register to observe the "com.apple.accessibility.api" distributed notification from System Preferences, to learn when the user toggles access for any application in the Privacy pane's Accessibility list in Security & Privacy preferences. The notification currently returns nil for object and userInfo, so extraordinary measures are required to determine whether it is the value for this application that has changed, instead of the value for some other application. See -didToggleAccessStatus: and -noteNewAccessStatus:, below, for details.
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(didToggleAccessStatus:) name:@"com.apple.accessibility.api" object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    //[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(didToggleAccessStatus:) name:@"com.apple.accessibility.api" object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

    // Get current accessibility status of Accessibility Testbench, and log whether access is already allowed when Accessibility Testbench is launched.
    granted = AXIsProcessTrusted();

    // Log the new and old accessibility trust functions to be sure they all return correct results.
    // NSLog(@"\n\tIn -applicationDidFinishLaunching: notification method.\n\t\tAXIsProcessTrustedWithoutAlert: %@\n\t\tAXIsProcessTrusted: %@\n\t\tAXIsAccessEnabled (deprecated): %@", (status) ? @"YES" : @"NO", (AXIsProcessTrusted()) ? @"YES" : @"NO", (AXAPIEnabled()) ? @"YES" : @"NO");

}

- (void) stop {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL) status {
    return granted;
}

- (void) refresh {
    granted = AXIsProcessTrusted();
}

-(void)didToggleAccessStatus:(NSNotification *)notification {
    // Accessibility Testbench registered to observe the System Preferences "com.apple.accessibility.api" distributed notification in -applicationDidFinishLaunching:.
    // Logs receipt of the accessibility API notification "com.apple.accessibility.api" when the user grants or denies access to any application in the Privacy pane's Accessibility list in Security & Privacy preferences in System Preferences. Logs the access status of Accessibility Testbench upon receipt of the notification, and then sends the -noteNewAccessStatus: message to capture the application's new access status after a brief delay.
    // In OS X 10.9 Mavericks and newer, System Preferences posts the notification when the user toggles any application's status in the Accessibility list in the Privacy pane of Security & Privacy preferences. In OS X 10.8 Mountain Lion and older, System Preferences posts the notification when the user toggles the global "Enable access for assistive devices" setting in the Accessibility (formerly Universal Access) preference. In any version, the change apparently usually takes effect in the next iteration of the run loop after the notification is posted, although sometimes the change is picked up at the time of the notification and sometimes as much as half a second after the time of the notification. This variability makes it difficult to recognize changes to a specific application's access status.
    // Attempting to get the "before" value here with a call to -[PFUIElement isProcessTrustedWithOptions:] when the notification is received is unreliable in that it sometimes captures the "after" value. Also, Apple might revise the notification mechanism in the future so that System Preferences always reports the "after" value when the notification is posted. We therefore capture the initial value in the global accessStatus property in -applicationDidFinishLaunching: and update it in -noteNewAccessStatus: when a change is detected.
    // Note that the distributed notification does not currently capture which application's checkbox the user selected or deselected in the Accessibility list or the application's "before" or "after" accessibility status in the notification's object or userInfo properties, forcing us to use this more convoluted technique to capture the "before" and "after" status. We log the notification's contents at the beginning of this method in order to detect whether Apple ever revises the content of the notification.

    // Log receipt of notification. Run Console.app to see these logs.
    NSString *explanation;
    if (([notification object] == nil) && ([notification userInfo] == nil)) {
        explanation = @"The notification contains no useful information.";
    } else {
        // Draw attention to any change in the content of the distributed notification's object and userInfo objects in a new version of OS X.
        // NSBeep();
        explanation = @"The notification contains important new information.";
    }
    NSLog(@"\n\tIn -didToggleAccessStatus: notification method.\n\t\tReceived notification: %@\n\t\tfrom object: %@\n\t\twith userInfo: %@.\n\t\t%@", [notification name], [notification object], [notification userInfo], explanation); // notification object and userInfo are nil in OS X 10.9.0, 10.9.1 and 10.9.2 Mavericks.

    // Get current accessibility status of application. This is solely for purpose of logging its value; the "before" status saved in the accessStatus property is what is passed to -noteNewAccessStatus:.
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8) { // AXIsProcessTrustedWithOptions function was introduced in OS X 10.9 Mavericks
        granted = AXIsProcessTrusted();
    }

    // Log the new and old accessibility trust functions to be sure they all return correct results.
    NSLog(@"\n\tIn -didToggleAccessStatus: notification method (before values).\n\t\tAXIsProcessTrustedWithoutAlert: %@\n\t\tAXIsProcessTrusted: %@\n\t\tAXIsAccessEnabled (deprecated): %@", (granted) ? @"YES" : @"NO", (AXIsProcessTrusted()) ? @"YES" : @"NO", (AXAPIEnabled()) ? @"YES" : @"NO");

    runThread();
    // Send -noteNewAccessibilityStatus: message, with the old access status saved in the accessStatus property, half a second after receipt of notification, to get "after" accessibility status. The delay is required in OS X 10.9.0 Mavericks because AXIsProcessTrustedWithOptions: and the other accessibility functions usually return the "before" value when the notification is posted. Experimentation indicates that a delay of as much as half a second after receipt of the notification is sometimes necessary to get the "after" value.
    //[self performSelector:@selector(noteNewAccessStatus:) withObject:[NSNumber numberWithBool:[self accessStatus]] afterDelay:0.5]; // 0.5 seconds
}
@end



Napi::Boolean HotKeys::macCheckAccessibilityGranted(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
    AccObserver *obj = [AccObserver get];
    bool isGranted = [obj status];
	return Napi::Boolean::New(env, isGranted);
}

Napi::Number HotKeys::macSubscribeAccessibilityUpdates(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	if (info.Length() < 1 || !info[0].IsFunction()) {
		Napi::TypeError::New(env, "accessibility check cb is required").ThrowAsJavaScriptException();
	}
	fprintf(stderr, "\r\n*** macSubscribeAccessibilityUpdates: Access %s\r\n", AXIsProcessTrusted() ? "enabled" : "disabled");
	g_fnAccChanged = Napi::ThreadSafeFunction::New(
		env,
		info[0].As<Napi::Function>(),
		"desktop-hotkeys acc changed cb",
		0,
		1);
	subscribedForAccNotifications = true;

/*	CFNotificationCenterAddObserver(
		CFNotificationCenterGetDistributedCenter(),
		&g_fnAccChanged,
		onAccChanged,
		CFSTR("com.apple.accessibility.api"),
		nil,
		CFNotificationSuspensionBehaviorDeliverImmediately);*/
	return Napi::Number::New(env, AXAPIEnabled() ? 0 : -1);
}

Napi::Number HotKeys::macUnsubscribeAccessibilityUpdates(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
/*	CFNotificationCenterRemoveObserver(
		CFNotificationCenterGetDistributedCenter(),
		&g_fnAccChanged,
		CFSTR("com.apple.accessibility.api"),
		nil);
*/
	AccObserver *obj = [AccObserver get];
    [obj stop];

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
