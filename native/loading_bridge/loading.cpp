// Draws furigana only on the destination loading view of a verified PBZ build.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <intrin.h>
#include <MinHook.h>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <cstddef>
#include <iterator>
#include <algorithm>
#include <array>
#include "loading_wrap.h"
#include "bridge.cpp"

namespace {
using Address = uintptr_t;
using Construct = void(__fastcall*)(void*, const void*);
using Paint = int(__fastcall*)(const void*, const void*, const void*, const void*, void*, int, const void*, bool);
struct NativeString { const wchar_t* data; int count, capacity; };
struct Geometry {
    float width, height, padding[5], xx, xy, yx, yy, x, y, tail;
};
struct NativeLine {
    double x, y, width, height;
    float textHeight, justificationWidth;
    int begin, end;
    unsigned char direction, padding[3];
    int model;
};
static_assert(sizeof(Geometry) == 0x38 && offsetof(Geometry, xx) == 0x1c);
static_assert(sizeof(NativeLine) == 0x38 && sizeof(NativeString) == 0x10);
constexpr Address kConstruct = 0x6a5a3f0;
constexpr Address kPaint = 0x1a4c500;
constexpr Address kRichVtable = 0xa7fe4b8;
constexpr Address kTextString = 0x131e1e0;
constexpr Address kFirstCaller = 0x68e6866;
constexpr Address kSecondCaller = 0x6a710c4;
constexpr Address kImageSize = 0x1e0bb000;
constexpr DWORD kTimestamp = 0x6ae7ae3f;
Address base;
Construct originalConstruct;
Paint originalPaint;
std::atomic<bool> enabledForLoading;

bool copy(void* out, Address address, size_t size) {
    if (!address || !size || address + size < address) return false;
    MEMORY_BASIC_INFORMATION page{};
    if (!VirtualQuery(reinterpret_cast<void*>(address), &page, sizeof(page))
        || page.State != MEM_COMMIT || (page.Protect & (PAGE_NOACCESS | PAGE_GUARD))
        || address + size > reinterpret_cast<Address>(page.BaseAddress) + page.RegionSize) return false;
    __try {
        std::memcpy(out, reinterpret_cast<void*>(address), size);
        return true;
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        return false;
    }
}

template<class T>
bool read(Address address, T& out) {
    return copy(&out, address, sizeof(out));
}

template<size_t N>
bool verify(Address rva, const unsigned char (&expected)[N]) {
    unsigned char actual[N]{};
    return copy(actual, base + rva, N) && !std::memcmp(actual, expected, N);
}

bool verifiedImage() {
    IMAGE_DOS_HEADER dos{};
    IMAGE_NT_HEADERS64 nt{};
    if (!read(base, dos) || dos.e_magic != IMAGE_DOS_SIGNATURE || dos.e_lfanew < 0x40 || dos.e_lfanew > 0x2000
        || !read(base + dos.e_lfanew, nt) || nt.Signature != IMAGE_NT_SIGNATURE
        || nt.FileHeader.TimeDateStamp != kTimestamp || nt.OptionalHeader.SizeOfImage != kImageSize) return false;
    const unsigned char construct[] = {0x48,0x8b,0xc4,0x48,0x89,0x58,0x18,0x55,0x56,0x57,0x41,0x54,0x41,0x55,0x41,0x56};
    const unsigned char paint[] = {0x40,0x53,0x55,0x56,0x57,0x41,0x56,0x41,0x57,0x48,0x81,0xec,0xd8,0,0,0};
    const unsigned char text[] = {0x40,0x53,0x48,0x83,0xec,0x20,0x48,0x8b,0xd9,0xe8,0x92,0xc1,0,0,0x48,0x8b};
    const unsigned char first[] = {0xe8,0x8a,0x3b,0x17,0,0xf6,0x43,0x30,0x10,0x75,0x10};
    const unsigned char second[] = {0xe8,0x2c,0x93,0xfe,0xff,0xf6,0x43,0x30,0x10,0x75,0x10};
    Address slot{};
    return verify(kConstruct, construct) && verify(kPaint, paint) && verify(kTextString, text)
        && verify(kFirstCaller-5, first) && verify(kSecondCaller-5, second)
        && read(base + kRichVtable + 0x230, slot) && slot == base + kPaint;
}

bool toText(Address text, wchar_t (&buffer)[1024]) {
    Address storage{}, vtable{};
    if (!read(text, storage) || !read(storage, vtable) || vtable < base || vtable > base + kImageSize - 0x30) return false;
    NativeString string{};
    __try {
        using DisplayString = const NativeString*(__fastcall*)(const void*);
        const auto display = reinterpret_cast<DisplayString>(base + kTextString);
        if (!read(reinterpret_cast<Address>(display(reinterpret_cast<void*>(text))), string)) return false;
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        return false;
    }
    if (string.count == 0) return true;
    return string.count > 0 && string.count <= 1024 && string.capacity >= string.count && string.capacity <= 65536
        && copy(buffer, reinterpret_cast<Address>(string.data), string.count * sizeof(wchar_t))
        && buffer[string.count-1] == L'\0';
}

#include "loading_render.h"
#include "startup_warning.h"

__declspec(noinline) void __fastcall inspectConstruction(void* view, const void* args) {
    const Address caller = reinterpret_cast<Address>(_ReturnAddress()) - base;
    originalConstruct(view, args);
    if (!enabledForLoading.load(std::memory_order_acquire) || (caller != kFirstCaller && caller != kSecondCaller)) return;
    Address tip{}, vtable{};
    const Address nativeArgs = reinterpret_cast<Address>(args);
    if (!read(reinterpret_cast<Address>(view) + 0x840, tip) || !read(tip, vtable) || vtable != base + kRichVtable) return;
    wchar_t raw[1024]{};
    if (!toText(nativeArgs + 0x5d8, raw)) raw[0] = 0;
    identifyLoadingWidget(tip, raw);
}

__declspec(noinline) int __fastcall inspectPaint(const void* self, const void* args, const void* geometry,
    const void* clip, void* elements, int layer, const void* style, bool enabled) {
    const int result = originalPaint(self, args, geometry, clip, elements, layer, style, enabled);
    if (!enabled || result <= layer || !enabledForLoading.load(std::memory_order_acquire)) return result;
    const Address tip = reinterpret_cast<Address>(self);
    const auto match = std::find_if(loadingAddresses.begin(), loadingAddresses.end(), [tip](const auto& address) {
        return address.load(std::memory_order_acquire) == tip;
    });
    if (match == loadingAddresses.end()) return result;
    const LoadingLock lock;
    auto& matched = loadingWidgets[static_cast<size_t>(match - loadingAddresses.begin())];
    if (!enabledForLoading.load(std::memory_order_relaxed) || matched.widget != tip) return result;
    if (GetTickCount64() - matched.created > 90000) {
        match->store(0, std::memory_order_release);
        matched = {};
        return result;
    }
    Address vtable{}, cache{}, layout{}, lines{};
    Geometry transform{};
    float layoutScale{};
    int count{};
    if (!read(tip, vtable) || vtable != base + kRichVtable
        || !read(reinterpret_cast<Address>(geometry), transform)
        || !std::isfinite(transform.width) || transform.width <= 0
        || !std::isfinite(transform.height) || transform.height <= 0
        || !read(tip + 0x208, cache) || cache != matched.cache || !read(cache, layout)
        || !read(layout + 0x30, lines) || !read(layout + 0x38, count) || count < 1 || count > 12
        || !read(layout + 0x94, layoutScale) || !std::isfinite(layoutScale) || layoutScale <= 0) return result;
    NativeLine captured[12]{};
    for (int index = 0; index < count; ++index) {
        auto& line = captured[index];
        if (!read(lines + index * 0x68 + 0x30, line)
            || line.begin < 0 || line.end <= line.begin || line.end > 2048
            || !std::isfinite(line.width) || line.width <= 0
            || !std::isfinite(line.height) || line.height <= 0) return result;
    }
    return renderLoading(matched, layout, lines, captured, count, layoutScale, transform, elements, result, style);
}

bool initializeHost() {
    static const bool initialized = [] {
        base = reinterpret_cast<Address>(GetModuleHandleW(nullptr));
        if (!verifiedImage() || !verifiedRender()) return false;
        HMODULE module{};
        // A loading-thread callback can outlive Lua during normal shutdown.
        return GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
            reinterpret_cast<const wchar_t*>(&initializeHost), &module) && MH_Initialize() == MH_OK;
    }();
    return initialized;
}

bool installLoading() {
    auto* construct = reinterpret_cast<void*>(base + kConstruct);
    auto* paint = reinterpret_cast<void*>(base + kPaint);
    const auto createConstruct = MH_CreateHook(construct, reinterpret_cast<void*>(&inspectConstruction),
        reinterpret_cast<void**>(&originalConstruct));
    const auto createPaint = MH_CreateHook(paint, reinterpret_cast<void*>(&inspectPaint),
        reinterpret_cast<void**>(&originalPaint));
    if (createConstruct != MH_OK || createPaint != MH_OK
        || MH_QueueEnableHook(construct) != MH_OK || MH_QueueEnableHook(paint) != MH_OK
        || MH_ApplyQueued() != MH_OK) {
        return false;
    }
    return true;
}

int luaResult(void* state, bool (*action)()) {
    if (!state) return 0;
    static LuaAPI lua;
    static const bool luaReady = lua.bind();
    if (!luaReady) return 0;
    alignas(16) unsigned char wrapper[256]{};
    lua.ctor(wrapper, state);
    if (lua.state(wrapper) != state) return 0;
    if (!action()) return 0;
    lua.number(wrapper, 1);
    return 1;
}
}

extern "C" __declspec(dllexport) int luaopen_pbz_loading_enable(void* state) {
    return luaResult(state, [] {
        static const bool installed = initializeHost() && installLoading();
        if (installed) enabledForLoading.store(true, std::memory_order_release);
        return installed;
    });
}

extern "C" __declspec(dllexport) int luaopen_pbz_loading_disable(void*) {
    enabledForLoading.store(false, std::memory_order_release);
    const LoadingLock lock;
    for (auto& address : loadingAddresses) address.store(0, std::memory_order_release);
    loadingWidgets = {};
    replacementIndex = 0;
    return 0;
}

extern "C" __declspec(dllexport) int luaopen_pbz_startup_warning_enable(void* state) {
    return luaResult(state, [] {
        static const bool installed = initializeHost() && installWarning();
        if (!installed || warningStatus.load(std::memory_order_acquire) != 1) return false;
        warningActive.store(true, std::memory_order_release);
        return true;
    });
}

extern "C" __declspec(dllexport) int luaopen_pbz_startup_warning_retire(void* state) {
    return luaResult(state, &retireWarning);
}

#ifdef PBZ_STARTUP_WARNING_QA
extern "C" __declspec(dllexport) int luaopen_pbz_startup_warning_title(void* state) {
    return exportWarningSample(state, 0);
}
extern "C" __declspec(dllexport) int luaopen_pbz_startup_warning_body(void* state) {
    return exportWarningSample(state, 1);
}
extern "C" __declspec(dllexport) int luaopen_pbz_startup_warning_hint(void* state) {
    return exportWarningSample(state, 2);
}
#endif

#ifdef PBZ_LOADING_QA
extern "C" __declspec(dllexport) int luaopen_pbz_loading_qa_sample(void* state) {
    if (!state) return 0;
    static LuaAPI lua;
    static const bool luaReady = lua.bind();
    if (!luaReady) return 0;
    alignas(16) unsigned char wrapper[256]{};
    lua.ctor(wrapper, state);
    if (lua.state(wrapper) != state) return 0;
    LoadingQASample sample;
    {
        const LoadingLock lock;
        sample = loadingQA;
    }
    lua.number(wrapper, sample.serial);
    lua.number(wrapper, sample.entry);
    lua.number(wrapper, sample.ready ? 1 : 0);
    lua.number(wrapper, sample.words);
    lua.number(wrapper, sample.painted);
    lua.number(wrapper, sample.lines);
    for (int index = 0; index < sample.lines; ++index) {
        const auto& line = sample.native[index];
        // One value per line keeps the return below Lua's 20 guaranteed stack slots.
        constexpr int range = 2049;
        lua.number(wrapper, (line.model * range + line.begin) * range + line.end);
    }
    return 6 + sample.lines;
}
#endif
