#include "Hotkeys.h"
#define TARGET_OS_MAC
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>

#include <uiohook.h>
#include <wchar.h>
#include <map>
#include <set>

// Native thread errors.
#define UIOHOOK_ERROR_THREAD_CREATE 0x10

Napi::ThreadSafeFunction g_fnAccChanged; // invoked for every accessibility on/off

bool subscribedForAccNotifications = false;
bool hookInstalled = false;
static unsigned nextHotkeyId = 1;

class HotKey
{
    Napi::ThreadSafeFunction _pressedCb;
    Napi::ThreadSafeFunction _releasedCb;
    std::map<unsigned, bool> _keyPressedState;
    unsigned _keysPressed;
    const unsigned _keysCount;
public:
    HotKey(Napi::ThreadSafeFunction pressedCb, Napi::ThreadSafeFunction releasedCb, unsigned* keyCodes, unsigned keyCount) :
        _pressedCb(pressedCb), _releasedCb(releasedCb), _keysPressed(0), _keysCount(keyCount)
    {
        for(size_t idx = 0; idx < keyCount; ++idx) {
            _keyPressedState[keyCodes[idx]] = false;
        }
    }
    void onKeyEvent(unsigned keyCode, bool pressed)
    {
        std::map<unsigned, bool>::iterator cit = _keyPressedState.find(keyCode);
        if (cit != _keyPressedState.end()) {
            if (cit->second != pressed) {
                cit->second = pressed;
                if (!pressed && _keysPressed == _keysCount) {
                    _releasedCb.NonBlockingCall();
                }
                _keysPressed += (pressed ? 1 : -1);
                if (pressed && _keysPressed == _keysCount) {
                    _pressedCb.NonBlockingCall();
                }
            }
        }
    }
};

class HotKeyStore
{
	typedef std::map<unsigned, std::unique_ptr<HotKey>> TCONT;
	TCONT _hotkeys;
public:
	unsigned create(const Napi::ThreadSafeFunction& pressed, const Napi::ThreadSafeFunction& released, unsigned* keyCodes, unsigned keyCount)
	{
	    unsigned id = ++nextHotkeyId;
	    _hotkeys[id] = std::unique_ptr<HotKey>(new HotKey(pressed, released, keyCodes, keyCount));
	    return id;
	}
	unsigned remove(unsigned id)
	{
	    _hotkeys.erase(id);
	    return 0;
	}
	unsigned removeAll()
	{
	    _hotkeys.clear();
	    return 0;
	}
	void onKeyEvent(unsigned keyCode, bool pressed)
	{
	    for (TCONT::const_iterator cit = _hotkeys.begin(); cit != _hotkeys.end(); ++cit) {
	        cit->second->onKeyEvent(keyCode, pressed);
	    }
	}
} hotKeyStore;

class PressedKeysCollection
{
    std::set<unsigned> _keys;
    unsigned _lastActiveKey;
    bool _active;
public:
    PressedKeysCollection() : _lastActiveKey(0), _active(false)
    {}
    void onKeyEvent(unsigned key, bool pressed)
    {
        if (pressed) {
            _keys.insert(key);
            _lastActiveKey = key;
        } else {
            _keys.erase(key);
            if (_lastActiveKey == key) {
                _lastActiveKey = 0;
            }
        }
    }
    void reset()
    {
        _keys.clear();
        _lastActiveKey = 0;
    }
    void get(std::back_insert_iterator<std::vector<unsigned>> it)
    {
        std::copy(_keys.begin(), _keys.end(), it);
        _keys.erase(_lastActiveKey);
    }
    bool setActive(bool active)
    {
        if (active) {
            reset();
        }
        if (_active != active) {
            _active = active;
            return true;
        }
        return false;
    }
} keyCollection;

static pthread_t hook_thread;

static pthread_mutex_t hook_running_mutex;
static pthread_mutex_t hook_control_mutex;
static pthread_cond_t hook_control_cond;

class Initter
{
public:
    Initter()
    {
        pthread_mutex_init(&hook_running_mutex, NULL);
        pthread_mutex_init(&hook_control_mutex, NULL);
        pthread_cond_init(&hook_control_cond, NULL);
    }
    ~Initter()
    {
        pthread_mutex_destroy(&hook_running_mutex);
        pthread_mutex_destroy(&hook_control_mutex);
        pthread_cond_destroy(&hook_control_cond);
    }
} obj;

bool logger_proc(unsigned int level, const char *format, ...) {
    bool status = false;

    va_list args;
    switch (level) {
        case LOG_LEVEL_INFO:
        case LOG_LEVEL_DEBUG:
        case LOG_LEVEL_WARN:
            //va_start(args, format);
            //status = vfprintf(stderr, format, args) >= 0;
            //va_end(args);
            break;

        case LOG_LEVEL_ERROR:
            va_start(args, format);
            status = vfprintf(stderr, format, args) >= 0;
            va_end(args);
            break;
    }

    return status;
}

// NOTE: The following callback executes on the same thread that hook_run() is called
// from.  This is important because hook_run() attaches to the operating systems
// event dispatcher and may delay event delivery to the target application.
// Furthermore, some operating systems may choose to disable your hook if it
// takes to long to process.  If you need to do any extended processing, please
// do so by copying the event to your own queued dispatch thread.
void dispatch_proc(uiohook_event * const event) {
    char buffer[256] = { 0 };
    size_t length = snprintf(buffer, sizeof(buffer),
            "id=%i,mask=0x%X",
            event->type, event->mask);

    switch (event->type) {
        case EVENT_HOOK_ENABLED:
            logger_proc(LOG_LEVEL_ERROR, "***Lock the running mutex so we know if the hook is enabled");
            // Lock the running mutex so we know if the hook is enabled.
            #ifdef _WIN32
            EnterCriticalSection(&hook_running_mutex);
            #else
            pthread_mutex_lock(&hook_running_mutex);
            #endif
            logger_proc(LOG_LEVEL_ERROR, "***Lock the running mutex so we know if the hook is enabled - OK");
            logger_proc(LOG_LEVEL_ERROR, "***Unlock the control mutex so hook_enable() can continue");

            // Unlock the control mutex so hook_enable() can continue.
            #ifdef _WIN32
            WakeConditionVariable(&hook_control_cond);
            LeaveCriticalSection(&hook_control_mutex);
            #else
            pthread_cond_signal(&hook_control_cond);
            logger_proc(LOG_LEVEL_ERROR, "***Unlock the control mutex so hook_enable() can continue -- OK1");
            pthread_mutex_unlock(&hook_control_mutex);
            logger_proc(LOG_LEVEL_ERROR, "***Unlock the control mutex so hook_enable() can continue -- OK2");
            #endif
            break;

        case EVENT_HOOK_DISABLED:
            // Lock the control mutex until we exit.
            #ifdef _WIN32
            EnterCriticalSection(&hook_control_mutex);
            #else
            pthread_mutex_lock(&hook_control_mutex);
            #endif

            // Unlock the running mutex so we know if the hook is disabled.
            #ifdef _WIN32
            LeaveCriticalSection(&hook_running_mutex);
            #else
            #if defined(__APPLE__) && defined(__MACH__)
            // Stop the main runloop so that this program ends.
            logger_proc(LOG_LEVEL_ERROR, "*** Stop the main runloop so that this program ends.\r\n");
            CFRunLoopStop(CFRunLoopGetMain());
            #endif

            pthread_mutex_unlock(&hook_running_mutex);
            #endif
            break;

        case EVENT_KEY_PRESSED:
        case EVENT_KEY_RELEASED:
            hotKeyStore.onKeyEvent(event->data.keyboard.keycode, event->type == EVENT_KEY_PRESSED);
            keyCollection.onKeyEvent(event->data.keyboard.keycode, event->type == EVENT_KEY_PRESSED);
            snprintf(buffer + length, sizeof(buffer) - length,
                ",keycode=%u,char=(%u)rawcode=0x%X",
                event->data.keyboard.keycode, event->data.keyboard.keychar,event->data.keyboard.rawcode);
            break;

        case EVENT_KEY_TYPED:
            snprintf(buffer + length, sizeof(buffer) - length,
                ",keychar=%lc,rawcode=%u",
                (wint_t) event->data.keyboard.keychar,
                event->data.keyboard.rawcode);
            break;

        case EVENT_MOUSE_PRESSED:
        case EVENT_MOUSE_RELEASED:
        case EVENT_MOUSE_CLICKED:
        case EVENT_MOUSE_MOVED:
        case EVENT_MOUSE_DRAGGED:
        case EVENT_MOUSE_WHEEL:
        default:
            return;
    }

    //fprintf(stderr, "%s\n", buffer);
}

#ifdef _WIN32
DWORD WINAPI hook_thread_proc(LPVOID arg) {
#else
void *hook_thread_proc(void *arg) {
#endif
    // Set the hook status.
    int status = hook_run();
    if (status != UIOHOOK_SUCCESS) {
        #ifdef _WIN32
        *(DWORD *) arg = status;
        #else
        *(int *) arg = status;
        #endif
    }

    // Make sure we signal that we have passed any exception throwing code for
    // the waiting hook_enable().
    #ifdef _WIN32
    WakeConditionVariable(&hook_control_cond);
    LeaveCriticalSection(&hook_control_mutex);

    return status;
    #else
    // Make sure we signal that we have passed any exception throwing code for
    // the waiting hook_enable().
    pthread_cond_signal(&hook_control_cond);
    pthread_mutex_unlock(&hook_control_mutex);

    return arg;
    #endif
}

int hook_enable() {
    // Lock the thread control mutex.  This will be unlocked when the
    // thread has finished starting, or when it has fully stopped.

                logger_proc(LOG_LEVEL_ERROR, "*** will call hook_control_mutex\r\n");

    #ifdef _WIN32
    EnterCriticalSection(&hook_control_mutex);
    #else
    pthread_mutex_lock(&hook_control_mutex);
    #endif
                logger_proc(LOG_LEVEL_ERROR, "*** hook_control_mutex OK\r\n");

    // Set the initial status.
    int status = UIOHOOK_FAILURE;

    #ifndef _WIN32
    // Create the thread attribute.
    pthread_attr_t hook_thread_attr;
    pthread_attr_init(&hook_thread_attr);

    // Get the policy and priority for the thread attr.
    int policy;
    pthread_attr_getschedpolicy(&hook_thread_attr, &policy);
    int priority = sched_get_priority_max(policy);
    #endif

    #if defined(_WIN32)
    DWORD hook_thread_id;
    DWORD *hook_thread_status = malloc(sizeof(DWORD));
    hook_thread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE) hook_thread_proc, hook_thread_status, 0, &hook_thread_id);
    if (hook_thread != INVALID_HANDLE_VALUE) {
    #else
    int *hook_thread_status = (int*)malloc(sizeof(int));
    if (pthread_create(&hook_thread, &hook_thread_attr, hook_thread_proc, hook_thread_status) == 0) {
    #endif
        #if defined(_WIN32)
        // Attempt to set the thread priority to time critical.
        if (SetThreadPriority(hook_thread, THREAD_PRIORITY_TIME_CRITICAL) == 0) {
            logger_proc(LOG_LEVEL_WARN, "%s [%u]: Could not set thread priority %li for thread %#p! (%#lX)\n",
                    __FUNCTION__, __LINE__, (long) THREAD_PRIORITY_TIME_CRITICAL,
                    hook_thread    , (unsigned long) GetLastError());
        }
        #elif (defined(__APPLE__) && defined(__MACH__)) || _POSIX_C_SOURCE >= 200112L
        // Some POSIX revisions do not support pthread_setschedprio so we will
        // use pthread_setschedparam instead.
        struct sched_param param = { .sched_priority = priority };
        if (pthread_setschedparam(hook_thread, SCHED_OTHER, &param) != 0) {
            logger_proc(LOG_LEVEL_WARN, "%s [%u]: Could not set thread priority %i for thread 0x%lX!\n",
                    __FUNCTION__, __LINE__, priority, (unsigned long) hook_thread);
        }
        #else
        // Raise the thread priority using glibc pthread_setschedprio.
        if (pthread_setschedprio(hook_thread, priority) != 0) {
            logger_proc(LOG_LEVEL_WARN, "%s [%u]: Could not set thread priority %i for thread 0x%lX!\n",
                    __FUNCTION__, __LINE__, priority, (unsigned long) hook_thread);
        }
        #endif

                logger_proc(LOG_LEVEL_ERROR, "*** will Wait for the thread to indicate that it has passed\r\n");

        // Wait for the thread to indicate that it has passed the
        // initialization portion by blocking until either a EVENT_HOOK_ENABLED
        // event is received or the thread terminates.
        // NOTE This unlocks the hook_control_mutex while we wait.
        #ifdef _WIN32
        SleepConditionVariableCS(&hook_control_cond, &hook_control_mutex, INFINITE);
        #else
        pthread_cond_wait(&hook_control_cond, &hook_control_mutex);
        #endif
        logger_proc(LOG_LEVEL_ERROR, "*** Wait for the thread to indicate that it has passed -- OK\r\n");

        #ifdef _WIN32
        if (TryEnterCriticalSection(&hook_running_mutex) != FALSE) {
        #else
        if (pthread_mutex_trylock(&hook_running_mutex) == 0) {
        #endif
            // Lock Successful; The hook is not running but the hook_control_cond
            // was signaled!  This indicates that there was a startup problem!

            // Get the status back from the thread.
            #ifdef _WIN32
            WaitForSingleObject(hook_thread,  INFINITE);
            GetExitCodeThread(hook_thread, hook_thread_status);
            #else
            pthread_join(hook_thread, (void **) &hook_thread_status);
            status = *hook_thread_status;

            int unlocked = pthread_mutex_unlock(&hook_running_mutex);
            logger_proc(LOG_LEVEL_DEBUG, "%s [%u]: unlock Result: %d\n",
                __FUNCTION__, __LINE__, unlocked);

            #endif
        } else {
            // Lock Failure; The hook is currently running and wait was signaled
            // indicating that we have passed all possible start checks.  We can
            // always assume a successful startup at this point.
            status = UIOHOOK_SUCCESS;
        }

        free(hook_thread_status);

        logger_proc(LOG_LEVEL_DEBUG, "%s [%u]: Thread Result: (%#X).\n",
                __FUNCTION__, __LINE__, status);
    }
    else {
        status = UIOHOOK_ERROR_THREAD_CREATE;
    }

    // Make sure the control mutex is unlocked.
    #ifdef _WIN32
    LeaveCriticalSection(&hook_control_mutex);
    #else
    pthread_mutex_unlock(&hook_control_mutex);
    #endif

    return status;
}

static void onAccChanged(CFNotificationCenterRef center, void *observer, CFStringRef name_cf,
					 const void *object, CFDictionaryRef userInfo)
{
    fprintf(stderr, "\r\n\r\nAccessibility has changed, current %d\r\n\r\n", (AXIsProcessTrusted() ? 1 : 0));
    g_fnAccChanged.NonBlockingCall();
    return;
}

Napi::Number HotKeys::start(const Napi::CallbackInfo& info)
{
    logger_proc(LOG_LEVEL_INFO, "INFO // Set the logger callback for library output.\r\n");
    logger_proc(LOG_LEVEL_ERROR, "ERROR // Set the logger callback for library output.\r\n");

    hook_set_logger_proc(&logger_proc);
   // Retrieves the keyboard auto repeat rate.
    long int repeat_rate = hook_get_auto_repeat_rate();
    if (repeat_rate >= 0) {
        logger_proc(LOG_LEVEL_INFO, "Auto Repeat Rate:\t%ld\r\n", repeat_rate);
    } else {
        logger_proc(LOG_LEVEL_ERROR, "Failed to acquire keyboard auto repeat rate!\r\n");
    }

    // Retrieves the keyboard auto repeat delay.
    long int repeat_delay = hook_get_auto_repeat_delay();
    if (repeat_delay >= 0) {
        logger_proc(LOG_LEVEL_INFO, "Auto Repeat Delay:\t%ld\n", repeat_delay);
    } else {
        logger_proc(LOG_LEVEL_ERROR, "Failed to acquire keyboard auto repeat delay!\n");
    }

    // Retrieves the mouse acceleration multiplier.
    long int acceleration_multiplier = hook_get_pointer_acceleration_multiplier();
    if (acceleration_multiplier >= 0) {
        logger_proc(LOG_LEVEL_INFO, "Mouse Acceleration Multiplier:\t%ld\n", acceleration_multiplier);
    } else {
        logger_proc(LOG_LEVEL_ERROR, "Failed to acquire mouse acceleration multiplier!\n");
    }

    // Retrieves the mouse acceleration threshold.
    long int acceleration_threshold = hook_get_pointer_acceleration_threshold();
    if (acceleration_threshold >= 0) {
        logger_proc(LOG_LEVEL_INFO, "Mouse Acceleration Threshold:\t%ld\n", acceleration_threshold);
    } else {
        logger_proc(LOG_LEVEL_ERROR, "Failed to acquire mouse acceleration threshold!\n");
    }

    // Retrieves the mouse sensitivity.
    long int sensitivity = hook_get_pointer_sensitivity();
    if (sensitivity >= 0) {
        logger_proc(LOG_LEVEL_INFO, "Mouse Sensitivity:\t%ld\n", sensitivity);
    } else {
        logger_proc(LOG_LEVEL_ERROR, "Failed to acquire mouse sensitivity value!\n");
    }

    // Retrieves the double/triple click interval.
    long int click_time = hook_get_multi_click_time();
    if (click_time >= 0) {
        logger_proc(LOG_LEVEL_INFO, "Multi-Click Time:\t%ld\n", click_time);
    } else {
        logger_proc(LOG_LEVEL_ERROR, "Failed to acquire mouse multi-click time!\n");
    }

    if (!hookInstalled) {

        hook_set_dispatch_proc(&dispatch_proc);
            // Start the hook and block.
            // NOTE If EVENT_HOOK_ENABLED was delivered, the status will always succeed.
            logger_proc(LOG_LEVEL_ERROR, "*** will call hook_enable\r\n");
            int status = hook_enable();
            switch (status) {
                case UIOHOOK_SUCCESS:
                    hookInstalled = true;
                    CFRunLoopRun();
                    break;

                // System level errors.
                case UIOHOOK_ERROR_OUT_OF_MEMORY:
                    logger_proc(LOG_LEVEL_ERROR, "Failed to allocate memory. (%#X)\n", status);
                    break;

                // Darwin specific errors.
                case UIOHOOK_ERROR_AXAPI_DISABLED:
                    logger_proc(LOG_LEVEL_ERROR, "Failed to enable access for assistive devices. (%#X)\n", status);
                    break;

                case UIOHOOK_ERROR_CREATE_EVENT_PORT:
                    logger_proc(LOG_LEVEL_ERROR, "Failed to create apple event port. (%#X)\n", status);
                    break;

                case UIOHOOK_ERROR_CREATE_RUN_LOOP_SOURCE:
                    logger_proc(LOG_LEVEL_ERROR, "Failed to create apple run loop source. (%#X)\n", status);
                    break;

                case UIOHOOK_ERROR_GET_RUNLOOP:
                    logger_proc(LOG_LEVEL_ERROR, "Failed to acquire apple run loop. (%#X)\n", status);
                    break;

                case UIOHOOK_ERROR_CREATE_OBSERVER:
                    logger_proc(LOG_LEVEL_ERROR, "Failed to create apple run loop observer. (%#X)\n", status);
                    break;

                // Default error.
                case UIOHOOK_FAILURE:
                default:
                    logger_proc(LOG_LEVEL_ERROR, "An unknown hook error occurred. (%#X)\n", status);
                    break;
            }
    }
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 0);
}

Napi::Number HotKeys::stop(const Napi::CallbackInfo& info)
{
    if (hookInstalled) {
                int status = hook_stop();
                switch (status) {
                    case UIOHOOK_SUCCESS:
                        // Everything is ok.
                        break;

                    // System level errors.
                    case UIOHOOK_ERROR_OUT_OF_MEMORY:
                        logger_proc(LOG_LEVEL_ERROR, "Failed to allocate memory. (%#X)", status);
                        break;

                    case UIOHOOK_ERROR_X_RECORD_GET_CONTEXT:
                        // NOTE This is the only platform specific error that occurs on hook_stop().
                        logger_proc(LOG_LEVEL_ERROR, "Failed to get XRecord context. (%#X)", status);
                        break;

                    // Default error.
                    case UIOHOOK_FAILURE:
                    default:
                        logger_proc(LOG_LEVEL_ERROR, "An unknown hook error occurred. (%#X)", status);
                        break;
                }

                    // We no longer block, so we need to explicitly wait for the thread to die.
                    #ifdef _WIN32
                    WaitForSingleObject(hook_thread,  INFINITE);
                    #else
                    #if defined(__APPLE__) && defined(__MACH__)
                    // NOTE Darwin requires that you start your own runloop from main.
                    // CFRunLoopRun();
                    #endif

                    pthread_join(hook_thread, NULL);
                    #endif
            #ifdef _WIN32
            // Create event handles for the thread hook.
            CloseHandle(hook_thread);
            DeleteCriticalSection(&hook_running_mutex);
            DeleteCriticalSection(&hook_control_mutex);
            #else
            //pthread_mutex_destroy(&hook_running_mutex);
            //pthread_mutex_destroy(&hook_control_mutex);
            //pthread_cond_destroy(&hook_control_cond);
            #endif
    }
    hookInstalled = false;
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 1);
}

Napi::Number HotKeys::registerShortcut(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	Napi::Array arrKeys;
	Napi::Function fnPressed;
	Napi::Function fnReleased;
	bool keysAreVirtualCodes = false;
	unsigned argCount = info.Length();
	while (argCount > 0) {
	    if (info[argCount - 1].IsEmpty() || info[argCount -1].IsUndefined() || info[argCount -1].IsNull()) {
	        argCount = argCount -1;
	    } else {
	        break;
	    }
	}

	if (argCount >= 3 && info[0].IsArray() && info[1].IsFunction() && info[2].IsFunction()) {
		arrKeys = info[0].As<Napi::Array>();
		fnPressed = info[1].As<Napi::Function>();
		fnReleased = info[2].As<Napi::Function>();
		if (argCount >= 4 && info[3].IsBoolean()) {
			keysAreVirtualCodes = info[3].As<Napi::Boolean>();
		}
	} else if (argCount == 2 && info[0].IsArray() && info[1].IsFunction()) {
		arrKeys = info[0].As<Napi::Array>();
		fnPressed = info[1].As<Napi::Function>();
	} else {
	    logger_proc(LOG_LEVEL_ERROR, "(DHK): invalid registerShortcut arguments: Array/Function/Function or Array/Function expected");
		Napi::TypeError::New(env, "invalid registerShortcut arguments: Array/Function/Function or Array/Function expected").ThrowAsJavaScriptException();
		return Napi::Number::New(env, 0);
	}
    unsigned* keyCodes = new unsigned[arrKeys.Length()];
	for (size_t idx = 0; idx < arrKeys.Length(); ++idx) {
		Napi::Value key = arrKeys[idx];
		keyCodes[idx] = key.As<Napi::Number>().Uint32Value();
	}
    unsigned keyId = hotKeyStore.create(
        Napi::ThreadSafeFunction::New(
            env,
            fnPressed,
            "desktop-hotkeys pressed cb",
            0,
            1),
        Napi::ThreadSafeFunction::New(
            env,
            fnReleased,
            "desktop-hotkeys released cb ",
            0,
            1),
        keyCodes,
        arrKeys.Length()
    );
	return Napi::Number::New(env, keyId);
}

Napi::Number HotKeys::unregisterShortcut(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	if (info.Length() < 1 || !info[0].IsNumber()) {
		Napi::TypeError::New(env, "Invalid argument: Hotkey id expected").ThrowAsJavaScriptException();
	} else {
        hotKeyStore.remove(info[0].As<Napi::Number>().Uint32Value());
	}
	return Napi::Number::New(env, 0);
}

Napi::Number HotKeys::unregisterAllShortcuts(const Napi::CallbackInfo& info)
{
	hotKeyStore.removeAll();
	Napi::Env env = info.Env();
	unsigned uRetValue = static_cast<unsigned>(-1);
	return Napi::Number::New(env, uRetValue);
}

Napi::Boolean HotKeys::collectPressedKeyCodes(const Napi::CallbackInfo& info)
{
    bool changed = false;
	Napi::Env env = info.Env();
	if (info.Length() > 0 && info[0].IsBoolean()) {
	    changed = keyCollection.setActive(info[0].As<Napi::Boolean>());
	}
	return Napi::Boolean::New(env, changed);
}

Napi::Array HotKeys::pressedKeyCodes(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	std::vector<unsigned> keys;
	keyCollection.get(std::back_inserter(keys));
	Napi::Array arr = Napi::Array::New(env, keys.size());
	for (size_t idx = 0; idx < keys.size(); ++idx) {
	    arr[idx] = Napi::Number::New(env, keys[idx]);
	}
	return arr;
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
