#include "Hotkeys.h"
#define TARGET_OS_MAC
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>

#include "../libuiohook/include/uiohook.h"
#include <wchar.h>
#include <map>
#include <set>
#include <thread>
#include <chrono>

// Native thread errors.
#define UIOHOOK_ERROR_THREAD_CREATE 0x10

static bool hookInstalled = false;
static bool verboseMode = false;
static bool stopOnEscape = false;
static unsigned nextHotkeyId = 1;

static bool externalLoggerSet = false;
static Napi::ThreadSafeFunction g_fnLogFunction; // invoked for every accessibility on/off

static pthread_t hook_thread;

static pthread_mutex_t hook_running_mutex;
static pthread_mutex_t hook_control_mutex;
static pthread_cond_t hook_control_cond;

bool logger_proc(unsigned int level, const char *format, ...);
void dispatch_proc(uiohook_event * const event);

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
		for (size_t idx = 0; idx < keyCount; ++idx) {
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
	{
	}

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

class Initter
{
public:
	Initter()
	{
		pthread_mutex_init(&hook_running_mutex, NULL);
		pthread_mutex_init(&hook_control_mutex, NULL);
		pthread_cond_init(&hook_control_cond, NULL);
		hook_set_logger_proc(&logger_proc);
        hook_set_dispatch_proc(&dispatch_proc);
    }
	~Initter()
	{
		pthread_mutex_destroy(&hook_running_mutex);
		pthread_mutex_destroy(&hook_control_mutex);
		pthread_cond_destroy(&hook_control_cond);
	}
} obj;

bool logger_proc(unsigned int level, const char *format, ...)
{
	va_list args;
	if (verboseMode || (LOG_LEVEL_ERROR == level)) {
	    char* buf = new char[512];
		va_start(args, format);
		vsprintf(buf, format, args);
		va_end(args);
		if (externalLoggerSet) {
		    auto callback = []( Napi::Env env, Napi::Function jsCallback, char* pszText ) {
              // Transform native data into JS data, passing it to the provided
              // `jsCallback` -- the TSFN's JavaScript function.
              jsCallback.Call( {Napi::String::New(env, pszText)} );

              // We're finished with the data.
              delete[] pszText;
            };
	        g_fnLogFunction.Acquire();
        	g_fnLogFunction.BlockingCall(buf, callback);
        	g_fnLogFunction.Release();
		} else {
		    fprintf(stderr, "%s", buf);
		    delete[] buf;
		}
	}
	return true;
}

// NOTE: The following callback executes on the same thread that hook_run() is called
// from.  This is important because hook_run() attaches to the operating systems
// event dispatcher and may delay event delivery to the target application.
// Furthermore, some operating systems may choose to disable your hook if it
// takes to long to process.  If you need to do any extended processing, please
// do so by copying the event to your own queued dispatch thread.
void dispatch_proc(uiohook_event * const event)
{

	switch (event->type) {
		case EVENT_HOOK_ENABLED:
			logger_proc(LOG_LEVEL_DEBUG, "(DHK): EVENT_HOOK_ENABLED received");
			logger_proc(LOG_LEVEL_DEBUG, "***Lock the running mutex so we know if the hook is enabled");
			// Lock the running mutex so we know if the hook is enabled.
#ifdef _WIN32
			EnterCriticalSection(&hook_running_mutex);
#else
			pthread_mutex_lock(&hook_running_mutex);
#endif
			logger_proc(LOG_LEVEL_DEBUG, "(DHK): ***Lock the running mutex so we know if the hook is enabled - OK");
			logger_proc(LOG_LEVEL_DEBUG, "(DHK): ***Unlock the control mutex so hook_enable() can continue");

			// Unlock the control mutex so hook_enable() can continue.
#ifdef _WIN32
			WakeConditionVariable(&hook_control_cond);
			LeaveCriticalSection(&hook_control_mutex);
#else
			pthread_cond_signal(&hook_control_cond);
			logger_proc(LOG_LEVEL_ERROR, "(DHK): ***Unlock the control mutex so hook_enable() can continue -- OK1");
			pthread_mutex_unlock(&hook_control_mutex);
			logger_proc(LOG_LEVEL_ERROR, "(DHK): ***Unlock the control mutex so hook_enable() can continue -- OK2");
#endif
			break;

		case EVENT_HOOK_DISABLED:
			logger_proc(LOG_LEVEL_DEBUG, "(DHK): EVENT_HOOK_ENABLED received");
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
// logger_proc(LOG_LEVEL_DEBUG, "(DHK): *** Stop the main runloop so that this program ends.\r\n");
// CFRunLoopStop(CFRunLoopGetMain());
#endif

			pthread_mutex_unlock(&hook_running_mutex);
#endif
			break;

		case EVENT_KEY_PRESSED:
		    if (stopOnEscape) {
		        if (event->data.keyboard.keycode == VC_ESCAPE) {
		            stopOnEscape = false;
                    int status = hook_stop();
                    switch (status) {
                        case UIOHOOK_SUCCESS:
                            // Everything is ok.
                            break;
                        case UIOHOOK_FAILURE:
                        default:
                            logger_proc(LOG_LEVEL_ERROR, "An unknown hook error occurred. (%#X)", status);
                            break;
                    }
                }
            }
		case EVENT_KEY_RELEASED:
			hotKeyStore.onKeyEvent(event->data.keyboard.keycode, event->type == EVENT_KEY_PRESSED);
			keyCollection.onKeyEvent(event->data.keyboard.keycode, event->type == EVENT_KEY_PRESSED);
			if (verboseMode) {
				logger_proc(LOG_LEVEL_DEBUG, "(DHK): id=%i,mask=0x%X,keycode=%u,char=(%u)rawcode=0x%X",
					event->type, event->mask,
					event->data.keyboard.keycode, event->data.keyboard.keychar, event->data.keyboard.rawcode);
			}
			break;

		case EVENT_KEY_TYPED:
			if (verboseMode) {
				logger_proc(LOG_LEVEL_DEBUG, "(DHK): id=%i,mask=0x%X,keychar=%lc,rawcode=%u",
					event->type, event->mask,
					(wint_t)event->data.keyboard.keychar,
					event->data.keyboard.rawcode);
			}
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
DWORD WINAPI hook_thread_proc(LPVOID arg)
{
#else
void *hook_thread_proc(void *arg)
{
#endif
	// Set the hook status.
	int status = hook_run();
	if (status != UIOHOOK_SUCCESS) {
#ifdef _WIN32
		*(DWORD *)arg = status;
#else
		*(int *)arg = status;
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

int hook_enable()
{
	// Lock the thread control mutex.  This will be unlocked when the
	// thread has finished starting, or when it has fully stopped.

	logger_proc(LOG_LEVEL_DEBUG, "(DHK): *** will call hook_control_mutex\r\n");

#ifdef _WIN32
	EnterCriticalSection(&hook_control_mutex);
#else
	pthread_mutex_lock(&hook_control_mutex);
#endif

	logger_proc(LOG_LEVEL_DEBUG, "(DHK): *** hook_control_mutex OK\r\n");

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
	hook_thread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)hook_thread_proc, hook_thread_status, 0, &hook_thread_id);
	if (hook_thread != INVALID_HANDLE_VALUE) {
#else
	int *hook_thread_status = (int*)malloc(sizeof(int));
	if (pthread_create(&hook_thread, &hook_thread_attr, hook_thread_proc, hook_thread_status) == 0) {
#endif
#if defined(_WIN32)
		// Attempt to set the thread priority to time critical.
		if (SetThreadPriority(hook_thread, THREAD_PRIORITY_TIME_CRITICAL) == 0) {
			logger_proc(LOG_LEVEL_WARN, "(DHK): %s [%u]: Could not set thread priority %li for thread %#p! (%#lX)\n",
				__FUNCTION__, __LINE__, (long)THREAD_PRIORITY_TIME_CRITICAL,
				hook_thread, (unsigned long)GetLastError());
		}
#elif (defined(__APPLE__) && defined(__MACH__)) || _POSIX_C_SOURCE >= 200112L
		// Some POSIX revisions do not support pthread_setschedprio so we will
		// use pthread_setschedparam instead.
		struct sched_param param = {.sched_priority = priority};
		if (pthread_setschedparam(hook_thread, SCHED_OTHER, &param) != 0) {
			logger_proc(LOG_LEVEL_WARN, "(DHK): %s [%u]: Could not set thread priority %i for thread 0x%lX!\n",
				__FUNCTION__, __LINE__, priority, (unsigned long)hook_thread);
		}
#else
		// Raise the thread priority using glibc pthread_setschedprio.
		if (pthread_setschedprio(hook_thread, priority) != 0) {
			logger_proc(LOG_LEVEL_WARN, "(DHK): %s [%u]: Could not set thread priority %i for thread 0x%lX!\n",
				__FUNCTION__, __LINE__, priority, (unsigned long)hook_thread);
		}
#endif

		logger_proc(LOG_LEVEL_DEBUG, "(DHK): *** will Wait for the thread to indicate that it has passed\r\n");

		// Wait for the thread to indicate that it has passed the
		// initialization portion by blocking until either a EVENT_HOOK_ENABLED
		// event is received or the thread terminates.
		// NOTE This unlocks the hook_control_mutex while we wait.
#ifdef _WIN32
		SleepConditionVariableCS(&hook_control_cond, &hook_control_mutex, INFINITE);
#else
		pthread_cond_wait(&hook_control_cond, &hook_control_mutex);
#endif
		logger_proc(LOG_LEVEL_DEBUG, "(DHK): *** Wait for the thread to indicate that it has passed -- OK\r\n");

#ifdef _WIN32
		if (TryEnterCriticalSection(&hook_running_mutex) != FALSE) {
#else
		if (pthread_mutex_trylock(&hook_running_mutex) == 0) {
#endif
			// Lock Successful; The hook is not running but the hook_control_cond
			// was signaled!  This indicates that there was a startup problem!

			// Get the status back from the thread.
#ifdef _WIN32
			WaitForSingleObject(hook_thread, INFINITE);
			GetExitCodeThread(hook_thread, hook_thread_status);
#else
			pthread_join(hook_thread, (void **)&hook_thread_status);
			status = *hook_thread_status;

			int unlocked = pthread_mutex_unlock(&hook_running_mutex);
			logger_proc(LOG_LEVEL_DEBUG, "(DHK): %s [%u]: unlock Result: %d\n",
				__FUNCTION__, __LINE__, unlocked);

#endif
		} else {
			// Lock Failure; The hook is currently running and wait was signaled
			// indicating that we have passed all possible start checks.  We can
			// always assume a successful startup at this point.
			status = UIOHOOK_SUCCESS;
		}

		free(hook_thread_status);

		logger_proc(LOG_LEVEL_DEBUG, "(DHK): %s [%u]: Thread Result: (%#X).\n",
			__FUNCTION__, __LINE__, status);
	} else {
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

int installHookProc()
{
	int status = UIOHOOK_SUCCESS;
	logger_proc(LOG_LEVEL_DEBUG, "(DHK): installHookProc called, hookInstalled=%s\r\n", hookInstalled ? "true" : "false" );
	if (!hookInstalled) {
		// Start the hook and block.
		// NOTE If EVENT_HOOK_ENABLED was delivered, the status will always succeed.
		logger_proc(LOG_LEVEL_DEBUG, "(DHK): *** will call hook_enable\r\n");
		status = hook_enable();
		logger_proc(LOG_LEVEL_DEBUG, "(DHK): *** hook_enable returned %d\r\n", status);
		switch (status) {
			case UIOHOOK_SUCCESS:
				hookInstalled = true;
				CFRunLoopRun();
		        logger_proc(LOG_LEVEL_DEBUG, "(DHK): *** returned from CFRunLoopRun\r\n");
				pthread_join(hook_thread, NULL);
		        logger_proc(LOG_LEVEL_DEBUG, "(DHK): *** pthread_join(hook_thread) has finished\r\n");
				break;

				// System level errors.
			case UIOHOOK_ERROR_OUT_OF_MEMORY:
				logger_proc(LOG_LEVEL_ERROR, "(DHK): Failed to allocate memory. (%#X)\n", status);
				break;

				// Darwin specific errors.
			case UIOHOOK_ERROR_AXAPI_DISABLED:
				logger_proc(LOG_LEVEL_ERROR, "(DHK): Failed to enable access for assistive devices. (%#X)\n", status);
				break;

			case UIOHOOK_ERROR_CREATE_EVENT_PORT:
				logger_proc(LOG_LEVEL_ERROR, "(DHK): Failed to create apple event port. (%#X)\n", status);
				break;

			case UIOHOOK_ERROR_CREATE_RUN_LOOP_SOURCE:
				logger_proc(LOG_LEVEL_ERROR, "(DHK): Failed to create apple run loop source. (%#X)\n", status);
				break;

			case UIOHOOK_ERROR_GET_RUNLOOP:
				logger_proc(LOG_LEVEL_ERROR, "(DHK): Failed to acquire apple run loop. (%#X)\n", status);
				break;

			case UIOHOOK_ERROR_CREATE_OBSERVER:
				logger_proc(LOG_LEVEL_ERROR, "(DHK): Failed to create apple run loop observer. (%#X)\n", status);
				break;

				// Default error.
			case UIOHOOK_FAILURE:
			default:
				logger_proc(LOG_LEVEL_ERROR, "(DHK): An unknown hook error occurred. (%#X)\n", status);
				break;
		}
	}
	return status;
}

static void* serviceHookThread(void* arg)
{
    int* p = reinterpret_cast<int*>(arg);
    bool startHook = (*p == 0 ? false : true);
    delete p;
    logger_proc(LOG_LEVEL_DEBUG, "\r\n(DHK) serviceHookThread:%s\r\n", (startHook ? "<start>" : "<stop>"));
    if (startHook) {
        installHookProc();
    } else {
        logger_proc(LOG_LEVEL_DEBUG, "(DHK): serviceHookThread(stop) called, hookInstalled=%s\r\n", hookInstalled ? "true" : "false" );
        if(false && hookInstalled) {
            stopOnEscape = true;
            uiohook_event *event = (uiohook_event *) malloc(sizeof(uiohook_event));

            event->type = EVENT_KEY_PRESSED;
            event->mask = 0x00;

            event->data.keyboard.keycode = VC_ESCAPE;
            event->data.keyboard.keychar = CHAR_UNDEFINED;

            hook_post_event(event);

            event->type = EVENT_KEY_RELEASED;

            hook_post_event(event);

            free(event);
        }
    }
    return nullptr;
}

void runStartStopThread(bool startHook)
{
	pthread_attr_t attr;
	pthread_attr_init(&attr);
	pthread_t threadCb;
	int* arg = new int;
	*arg = startHook ? 1 : 0;
	pthread_create(&threadCb, &attr, serviceHookThread, arg);
	pthread_attr_destroy(&attr);
}

Napi::Number HotKeys::start(const Napi::CallbackInfo& info)
{
	if (info.Length() > 0 && info[0].IsBoolean()) {
		verboseMode = info[0].As<Napi::Boolean>();
		if (verboseMode) {
			logger_proc(LOG_LEVEL_DEBUG, "(DHK): Starting module, verbose logging is on");
		}
	}
	runStartStopThread(true);
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 1);
}

Napi::Number HotKeys::restart(const Napi::CallbackInfo& info)
{
    runStartStopThread(false);
    usleep(1000);
    runStartStopThread(true);
    Napi::Env env = info.Env();
    return Napi::Number::New(env, 1);
}

Napi::Boolean HotKeys::started(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
    return Napi::Boolean::New(env, hookInstalled);
}

Napi::Number HotKeys::stop(const Napi::CallbackInfo& info)
{
	if (hookInstalled) {
		int status = hook_stop();
		switch (status) {
			case UIOHOOK_SUCCESS:
				break;
			case UIOHOOK_ERROR_OUT_OF_MEMORY:
				logger_proc(LOG_LEVEL_ERROR, "(DHK): Failed to allocate memory. (%#X)", status);
				break;
			case UIOHOOK_FAILURE:
			default:
				logger_proc(LOG_LEVEL_ERROR, "(DHK): An unknown hook error occurred. (%#X)", status);
				break;
		}
	}
	hookInstalled = false;
	if (externalLoggerSet) {
	    g_fnLogFunction.Release();
	    externalLoggerSet = false;
	}
	Napi::Env env = info.Env();
	return Napi::Number::New(env, 1);
}

Napi::Number HotKeys::setLoggerCb(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	Napi::Function fnLogger;
	unsigned argCount = info.Length();
	if (argCount >= 1 && info[0].IsFunction()) {
		fnLogger = info[0].As<Napi::Function>();
	} else {
		logger_proc(LOG_LEVEL_ERROR, "(DHK): invalid setLoggerCb arguments: Function expected");
		Napi::TypeError::New(env, "invalid setLoggerCb arguments: Function expected").ThrowAsJavaScriptException();
		return Napi::Number::New(env, 0);
	}
	g_fnLogFunction = Napi::ThreadSafeFunction::New(
		env,
		fnLogger,
		"logger cb",
		0,
		1);
	externalLoggerSet = true;
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
		if (info[argCount - 1].IsEmpty() || info[argCount - 1].IsUndefined() || info[argCount - 1].IsNull()) {
			argCount = argCount - 1;
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
