#pragma once

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <map>

class HotKeyManager
{
	HANDLE _hThread;
	HANDLE _hStartEvent;
	unsigned _uThreadId;
	HWND _hWnd;
	typedef std::map<unsigned, std::pair<Napi::ThreadSafeFunction, Napi::ThreadSafeFunction>> TCONT;
	TCONT _hotkeys;
	std::map<unsigned, WPARAM> _hotkeyIds;
	bool _DisabledState;
public:
	static unsigned __stdcall winThread(void* ptr);
	HotKeyManager();
	~HotKeyManager();
	bool Valid() const;
	void NotifyHotKeyEvent(unsigned uCode, bool bPressed);
	void UpdateCallbacks(unsigned uCode, bool bSetInUse);
	DWORD registerShortcut(WORD wKeyCode, WORD wMod, const Napi::ThreadSafeFunction& tsfPress, const Napi::ThreadSafeFunction& tsfRelease);
	DWORD unregisterShortcut(DWORD dwId);
	DWORD unregisterAllShortcuts();
	void DisableAllShortcuts(bool bDisable);
};
