// Adds ruby to the native subtitle and title-card image paints.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <intrin.h>
#include <MinHook.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <utility>
#include <vector>
#include "video_readings.h"
#include "bridge.cpp"

namespace {
using Address = uintptr_t;
struct Geometry { float width, height, scale, layoutX, layoutY, reserved[2], xx, xy, yx, yy, x, y, tail; };
struct Vec { double x, y; };
struct Shared { Address object, control; };
struct NativeLine {
    double x, y, width, height;
    float textHeight, justificationWidth;
    int begin, end;
    unsigned char direction, padding[3];
    int model;
};
static_assert(sizeof(Geometry) == 0x38 && sizeof(NativeLine) == 0x38);
using Raster = bool(__fastcall*)(void*);
using Draw = void(__fastcall*)(void*, void*, const Shared*, float, const Vec*, float, bool);
using Paint = int(__fastcall*)(const void*, const void*, const void*, const void*, void*, int, const void*, bool);
constexpr Address kRaster = 0x691fb20, kDraw = 0x39227a0, kPaint = 0x18051f0;
constexpr Address kUiRaster = 0x6920680, kImageVtable = 0xa7d4150;
constexpr Address kUiTemplateVtable = 0xa7e24f8, kPlainTextVtable = 0xa7fe6f8;
constexpr Address kImageSize = 0x1e0bb000;
constexpr unsigned kTimestamp = 0x6ae7ae3f;
Address base;
Raster originalRaster;
Raster originalUiRaster;
Draw originalDraw;
Paint originalPaint;
enum class VideoMode : unsigned { Off, All, Names };
std::atomic<VideoMode> videoMode{VideoMode::Off};
#ifdef PBZ_VIDEO_QA
struct VideoCounters {
    std::atomic<unsigned> raster{}, plans{}, paired{}, paint{}, drawn{};
};
std::array<VideoCounters, 2> videoCounters{};
#endif
struct Channel {
    unsigned group;
    Address vtable, rasterReturn, drawReturn, widgets, records, active, widgetStride, textStride, bodyFont, speakerFont;
};
constexpr Channel dialogue{0, 0xc2329e8, 0x691196e, 0x691fe2a, 0x2d0, 0x2e0,
    0x8f4, 0x50, 0x28, 0x318, 0x5f8};
constexpr Channel dateText{1, 0xc233528, 0x691254a, 0x692099e, 0x330, 0x340,
    0x370, 0x10, 0x18, 0x278, 0};
struct Placement {
    const wchar_t* kana;
    int length;
    float x, y, width, height, size;
};
struct Cue {
    Address overlay, texture, image, brush;
    int index;
    float rasterScale;
    Vec rasterSize;
    const Channel* channel;
    std::vector<Placement> body, speaker, bodyNames;
};
struct RasterScope {
    const Channel& channel;
    Address overlay, widgets, source;
    int count;
    std::array<Cue, 128> cues;
};
thread_local RasterScope* activeRaster;
struct DisplayGroup {
    std::array<Cue, 128> cues;
    int count;
};
std::array<DisplayGroup, 2> displayed{};
std::array<std::atomic<uint64_t>, 4> imageMask{};
SRWLOCK lock = SRWLOCK_INIT;
struct ExclusiveLock {
    ExclusiveLock() { AcquireSRWLockExclusive(&lock); }
    ~ExclusiveLock() { ReleaseSRWLockExclusive(&lock); }
};

unsigned imageHash(Address image) {
    return static_cast<unsigned>((image >> 4) ^ (image >> 12) ^ (image >> 20)) & 255;
}

void updateImageMask() {
    std::array<uint64_t, 4> mask{};
    for (const auto& group : displayed) {
        for (int i = 0; i < group.count; ++i) {
            if (const Address image = group.cues[i].image) {
                const unsigned hash = imageHash(image);
                mask[hash / 64] |= uint64_t{1} << (hash % 64);
            }
        }
    }
    for (size_t index = 0; index < mask.size(); ++index) {
        imageMask[index].store(mask[index], std::memory_order_release);
    }
}

bool copy(void* target, Address source, size_t bytes) {
    MEMORY_BASIC_INFORMATION page{};
    if (!source || source + bytes < source || !VirtualQuery(reinterpret_cast<void*>(source), &page, sizeof(page))
        || page.State != MEM_COMMIT || (page.Protect & (PAGE_NOACCESS | PAGE_GUARD))
        || source + bytes > reinterpret_cast<Address>(page.BaseAddress) + page.RegionSize) return false;
    __try {
        std::memcpy(target, reinterpret_cast<const void*>(source), bytes);
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

#include "video_draw.h"

bool verifiedImage() {
    IMAGE_DOS_HEADER dos{};
    IMAGE_NT_HEADERS64 nt{};
    Address slot{};
    if (!read(base, dos) || dos.e_magic != IMAGE_DOS_SIGNATURE || dos.e_lfanew < 0x40 || dos.e_lfanew > 0x2000
        || !read(base + dos.e_lfanew, nt) || nt.Signature != IMAGE_NT_SIGNATURE
        || nt.FileHeader.TimeDateStamp != kTimestamp || nt.OptionalHeader.SizeOfImage != kImageSize
        || !read(base + kImageVtable + 0x230, slot) || slot != base + kPaint) return false;
    const unsigned char raster[]{0x40,0x55,0x56,0x41,0x56,0x48,0x8d,0xac,0x24,0x60,0xfc,0xff,0xff,0x48,0x81,0xec};
    const unsigned char uiRaster[]{0x40,0x55,0x56,0x41,0x56,0x48,0x8d,0xac,0x24,0x50,0xfc,0xff,0xff,0x48,0x81,0xec};
    const unsigned char uiRasterCall[]{0xe8,0x36,0xe1,0x00,0x00,0x84,0xc0,0x75,0x53};
    const unsigned char uiDrawCall[]{0xe8,0x02,0x1e,0x00,0xfd,0x48,0x8b,0x4d,0xd8};
    const unsigned char draw[]{0x48,0x89,0x5c,0x24,0x08,0x57,0x48,0x83,0xec,0x60,0x48,0x8b,0xf9,0x0f,0x29,0x74};
    const unsigned char paint[]{0x4c,0x8b,0xdc,0x55,0x56,0x57,0x41,0x54,0x41,0x56,0x49,0x8d,0x6b,0x88,0x48,0x81};
    return verify(kRaster, raster) && verify(kUiRaster, uiRaster) && verify(dateText.rasterReturn-5, uiRasterCall)
        && verify(dateText.drawReturn-5, uiDrawCall) && verify(kDraw, draw) && verify(kPaint, paint)
        && read(base + kPlainTextVtable + 0x230, slot) && slot == base + 0x1a4caf0 && verifiedDraw();
}

bool dateTemplateChild(Address root, Address& child) {
    Address vtable{}, array{}, slot{};
    int count{};
    return read(root, vtable) && vtable == base + kUiTemplateVtable
        && read(root + 0x1f8, array) && read(root + 0x200, count) && count == 1 && read(array, slot)
        && read(slot + 0x10, child) && read(child, vtable) && vtable == base + kPlainTextVtable;
}

__declspec(noinline) void __fastcall observeDraw(void* renderer, void* texture, const Shared* root,
    float scale, const Vec* size, float delta, bool defer) {
    const auto caller = reinterpret_cast<Address>(_ReturnAddress()) - base;
    originalDraw(renderer, texture, root, scale, size, delta, defer);
    auto* scope = activeRaster;
    if (!scope || caller != scope->channel.drawReturn || defer || delta != 0 || !std::isfinite(scale) || scale < .1f || scale > 8) return;
    Shared rootWidget{};
    Vec dimensions{};
    if (!read(reinterpret_cast<Address>(root), rootWidget) || !read(reinterpret_cast<Address>(size), dimensions)
        || dimensions.x <= 0 || dimensions.y <= 0 || dimensions.x > 8192 || dimensions.y > 8192) return;
    const auto& channel = scope->channel;
    const bool plain = channel.group == dateText.group;
    for (int i = 0; i < scope->count; ++i) {
        const Address entry = scope->widgets + static_cast<Address>(i) * channel.widgetStride;
        Address widget{}, body{}, speaker{};
        Geometry rootGeometry{};
        if (!read(entry, widget) || widget != rootWidget.object || !read(widget + 0x98, rootGeometry)) continue;
        if (plain ? !dateTemplateChild(widget, body) : (!read(entry + 0x10, body) || !read(entry + 0x20, speaker))) continue;
        auto& cue = scope->cues[i];
        if (cue.texture) return;
        cue.overlay = scope->overlay;
        cue.texture = reinterpret_cast<Address>(texture);
        cue.index = i;
        cue.rasterScale = scale;
        cue.rasterSize = dimensions;
        cue.channel = &channel;
        const Address source = scope->source + static_cast<Address>(i) * channel.textStride;
        try {
            buildPlan(cue, body, scope->overlay + channel.bodyFont, source + 8, rootGeometry, false, plain);
            if (!plain) buildPlan(cue, body, scope->overlay + channel.bodyFont, source + 8, rootGeometry, false, false, true);
            if (speaker) buildPlan(cue, speaker, scope->overlay + channel.speakerFont, source + 0x18, rootGeometry, true, false);
        } catch (...) {
            cue.body.clear();
            cue.speaker.clear();
            cue.bodyNames.clear();
        }
        return;
    }
}

bool observeRasterFor(void* self, Address caller, const Channel& channel, Raster original) {
    const auto overlay = reinterpret_cast<Address>(self);
#ifdef PBZ_VIDEO_QA
    auto& counters = videoCounters[channel.group];
    if (caller == channel.rasterReturn) counters.raster.fetch_add(1, std::memory_order_relaxed);
#endif
    Address vtable{}, widgets{}, source{};
    int count{}, sourceCount{};
    if (activeRaster || caller != channel.rasterReturn || !read(overlay, vtable) || vtable != base + channel.vtable
        || !read(overlay + channel.widgets, widgets) || !read(overlay + channel.widgets + 8, count) || count <= 0 || count > 128
        || !read(overlay + 0x268, source) || !read(overlay + 0x270, sourceCount) || sourceCount != count) {
        return original(self);
    }
    RasterScope scope{channel, overlay, widgets, source, count, {}};
    activeRaster = &scope;
    const bool result = original(self);
    activeRaster = nullptr;
    Address records{};
    int recordCount{};
    if (!result || !read(overlay + channel.records, records) || !read(overlay + channel.records + 8, recordCount) || recordCount != count) return result;
    for (int i = 0; i < count; ++i) {
        auto& cue = scope.cues[i];
#ifdef PBZ_VIDEO_QA
        if (!cue.body.empty() || !cue.speaker.empty() || !cue.bodyNames.empty()) counters.plans.fetch_add(1, std::memory_order_relaxed);
#endif
        const Address entry = records + static_cast<Address>(i) * 0xd0;
        Address image{}, texture{}, brush{};
        if ((cue.body.empty() && cue.speaker.empty() && cue.bodyNames.empty()) || !cue.texture || !read(entry, texture) || texture != cue.texture
            || !read(entry + 0xc0, image) || !read(image, vtable) || vtable != base + kImageVtable
            || !read(image + 0x1e0, brush) || brush != entry + 0x10) continue;
        cue.image = image;
        cue.brush = brush;
#ifdef PBZ_VIDEO_QA
        counters.paired.fetch_add(1, std::memory_order_relaxed);
#endif
    }
    const ExclusiveLock guard;
    displayed[channel.group] = {std::move(scope.cues), count};
    updateImageMask();
    return result;
}

__declspec(noinline) bool __fastcall observeRaster(void* self) {
    return observeRasterFor(self, reinterpret_cast<Address>(_ReturnAddress()) - base, dialogue, originalRaster);
}

__declspec(noinline) bool __fastcall observeUiRaster(void* self) {
    return observeRasterFor(self, reinterpret_cast<Address>(_ReturnAddress()) - base, dateText, originalUiRaster);
}

const Cue* findPaintCue(Address image) {
    for (const auto& group : displayed) {
        const auto end = group.cues.begin() + group.count;
        const auto found = std::find_if(group.cues.begin(), end, [image](const auto& cue) { return cue.image == image; });
        if (found != end) return &*found;
    }
    return nullptr;
}

bool cueIsVisible(const Cue& cue) {
    const auto& channel = *cue.channel;
    Address brush{}, vtable{}, records{}, texture{}, image{};
    int active{}, count{};
    if (!read(cue.image + 0x1e0, brush) || brush != cue.brush
        || !read(cue.overlay, vtable) || vtable != base + channel.vtable
        || !read(cue.overlay + channel.active, active) || active != cue.index
        || !read(cue.overlay + channel.records, records)
        || !read(cue.overlay + channel.records + 8, count) || active < 0 || active >= count) return false;
    const Address entry = records + static_cast<Address>(active) * 0xd0;
    return entry + 0x10 == brush && read(entry, texture) && texture == cue.texture
        && read(entry + 0xc0, image) && image == cue.image;
}

__declspec(noinline) int __fastcall observePaint(const void* self, const void* args, const void* geometry, const void* clip,
    void* elements, int layer, const void* style, bool enabled) {
    const int result = originalPaint(self, args, geometry, clip, elements, layer, style, enabled);
    if (!enabled || videoMode.load(std::memory_order_acquire) == VideoMode::Off) return result;
    const Address image = reinterpret_cast<Address>(self);
    const unsigned hash = imageHash(image);
    if (!(imageMask[hash / 64].load(std::memory_order_acquire) & (uint64_t{1} << (hash % 64)))) return result;

    const ExclusiveLock guard;
    const auto* cue = findPaintCue(image);
    const auto mode = videoMode.load(std::memory_order_relaxed);
    if (!cue || mode == VideoMode::Off || !cueIsVisible(*cue)) return result;
    Geometry transform{};
    float culling[4]{};
    if (!read(reinterpret_cast<Address>(geometry), transform) || transform.width <= 0 || transform.height <= 0
        || !copy(culling, reinterpret_cast<Address>(clip), sizeof(culling))) return result;
    const bool drawn = drawPlan(*cue, transform, culling, reinterpret_cast<Address>(style), elements, result, mode == VideoMode::Names);
#ifdef PBZ_VIDEO_QA
    auto& counters = videoCounters[cue->channel->group];
    counters.paint.fetch_add(1, std::memory_order_relaxed);
    if (drawn) counters.drawn.fetch_add(1, std::memory_order_relaxed);
#endif
    return drawn ? result + 1 : result;
}
bool install() {
    if (!verifiedImage() || MH_Initialize() != MH_OK) return false;
    struct Hook { Address rva; void* detour; void** original; };
    const Hook hooks[]{
        {kRaster, reinterpret_cast<void*>(&observeRaster), reinterpret_cast<void**>(&originalRaster)},
        {kUiRaster, reinterpret_cast<void*>(&observeUiRaster), reinterpret_cast<void**>(&originalUiRaster)},
        {kDraw, reinterpret_cast<void*>(&observeDraw), reinterpret_cast<void**>(&originalDraw)},
        {kPaint, reinterpret_cast<void*>(&observePaint), reinterpret_cast<void**>(&originalPaint)}
    };
    for (const auto& hook : hooks) {
        void* entry = reinterpret_cast<void*>(base + hook.rva);
        if (MH_CreateHook(entry, hook.detour, hook.original) != MH_OK || MH_QueueEnableHook(entry) != MH_OK) {
            MH_Uninitialize();
            return false;
        }
    }
    if (MH_ApplyQueued() != MH_OK) {
        MH_Uninitialize();
        return false;
    }
    return true;
}
}

static void setVideoMode(VideoMode mode) {
    // Keep the original raster cache, including while F6 is off. A paused
    // movie may not rasterize again; filter cached plans at paint time so
    // switching scopes cannot keep an old body/date visible or require replay.
    const ExclusiveLock guard;
    videoMode.store(mode, std::memory_order_release);
}

static int enableVideoScope(void* state, VideoMode mode) {
    if (!state) return 0;
    static LuaAPI lua;
    static const bool luaReady = lua.bind();
    if (!luaReady) return 0;
    alignas(16) unsigned char wrapper[256]{};
    lua.ctor(wrapper, state);
    if (lua.state(wrapper) != state) return 0;

    static const bool installed = [] {
        base = reinterpret_cast<Address>(GetModuleHandleW(nullptr));
        if (!verifiedImage()) return false;
        HMODULE module{};
        // The loading thread can be inside a trampoline during Lua shutdown.
        return GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
            reinterpret_cast<const wchar_t*>(&enableVideoScope), &module) && install();
    }();
    if (!installed) return 0;
    setVideoMode(mode);
    lua.number(wrapper, 1);
    return 1;
}

extern "C" __declspec(dllexport) int luaopen_pbz_video_enable(void* state) {
    return enableVideoScope(state, VideoMode::All);
}
extern "C" __declspec(dllexport) int luaopen_pbz_video_names_enable(void* state) {
    return enableVideoScope(state, VideoMode::Names);
}
extern "C" __declspec(dllexport) int luaopen_pbz_video_disable(void*) {
    setVideoMode(VideoMode::Off);
    return 0;
}

#ifdef PBZ_VIDEO_QA
extern "C" __declspec(dllexport) int luaopen_pbz_video_qa_counters(void* state) {
    if (!state) return 0;
    static LuaAPI lua;
    static const bool luaReady = lua.bind();
    if (!luaReady) return 0;
    alignas(16) unsigned char wrapper[256]{};
    lua.ctor(wrapper, state);
    if (lua.state(wrapper) != state) return 0;
    for (const auto& group : videoCounters) {
        for (const auto* value : {&group.raster, &group.plans, &group.paired, &group.paint, &group.drawn}) {
            lua.number(wrapper, value->load(std::memory_order_relaxed));
        }
    }
    return static_cast<int>(videoCounters.size() * 5);
}
#endif
