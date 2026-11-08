#include "bridge.cpp"

// Only these three keys are sampled, and only while PBZ owns the foreground.
// Sampling from the engine timer keeps all Lua calls on the game thread.
extern "C" __declspec(dllexport) int luaopen_pbz_hotkeys(void* L) {
    static LuaAPI api;
    static DWORD thread{};
    static unsigned previous{};
    static bool focused{};
    if (!L) return 0;
    if (!thread) {
        if (!api.bind()) return 0;
        thread = GetCurrentThreadId();
    }
    if (GetCurrentThreadId() != thread) return 0;
    unsigned pressed{};
    DWORD pid{};
    const HWND foreground = GetForegroundWindow();
    if (foreground) GetWindowThreadProcessId(foreground, &pid);
    if (pid == GetCurrentProcessId()) {
        const int keys[]{VK_F6, VK_PRIOR, VK_NEXT};
        unsigned held{};
        for (unsigned i = 0; i < 3; ++i) {
            const unsigned bit = 1u << i;
            const auto state = static_cast<unsigned short>(GetAsyncKeyState(keys[i]));
            if (state & 0x8000) held |= bit;
            // The short-press flag also catches a tap between two engine ticks.
            if (focused && !(previous & bit) && ((held & bit) || (state & 1))) pressed |= bit;
        }
        previous = held;
        focused = true;
    } else {
        previous = 0;
        focused = false;
    }
    alignas(16) unsigned char wrapper[256]{};
    api.ctor(wrapper, L);
    if (api.state(wrapper) != L) return 0;
    api.number(wrapper, static_cast<double>(pressed));
    return 1;
}
