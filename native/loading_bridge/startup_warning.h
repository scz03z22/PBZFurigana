// Ruby for the three verified text widgets on the native startup warning screen.
#include "startup_warning_readings.h"

constexpr Address kWarningConstruct = 0x6a5bcc0;
constexpr Address kPlainConstruct = 0x1a40880;
constexpr Address kPlainPaint = 0x1a4caf0;
constexpr Address kPlainLayoutPaint = 0x1a4b030;
constexpr Address kPlainLayoutCaller = 0x1a4cf2a;
constexpr Address kPlainVtable = 0xa7fe6f8;
constexpr Address kWarningTitleCaller = 0x6a5c40a;
constexpr Address kWarningBodyCaller = 0x6a5c7ea;
constexpr Address kPlainHelperCaller = 0x18d948e;
Construct originalWarningConstruct;
Construct originalPlainConstruct;
Paint originalPlainLayoutPaint;
struct WarningConstruction {
    Address args;
    float iconCenter{};
    bool movedIcon{};
};
thread_local WarningConstruction* warningConstruction{};

struct WarningWidget {
    ULONGLONG created{};
    Address font{};
    LoadingRender render{};
#ifdef PBZ_STARTUP_WARNING_QA
    unsigned paints{};
    int textLength{}, firstGlyph{}, simpleMode{}, lines{};
    float width{}, height{}, scale{}, firstLineHeight{}, minimumGap{};
    float nativeSpacing{}, trialSpacing{}, textGap{};
    unsigned rubyPaints{};
#endif
};

std::array<std::atomic<Address>, 3> warningAddresses{};
std::array<WarningWidget, 3> warningWidgets{};
std::atomic<bool> warningActive{};
std::atomic<int> warningStatus{};
SRWLOCK warningLock = SRWLOCK_INIT;

void __fastcall traceWarningConstruct(void* view, const void* args) {
    if (!warningActive.load(std::memory_order_acquire)) {
        originalWarningConstruct(view, args);
        return;
    }
    WarningConstruction construction{reinterpret_cast<Address>(args)};
    const auto previous = warningConstruction;
    warningConstruction = &construction;
    originalWarningConstruct(view, args);
    if (construction.movedIcon) {
        std::memcpy(reinterpret_cast<void*>(construction.args + 0x314), &construction.iconCenter, sizeof(float));
    }
    warningConstruction = previous;
}

float warningSpacingIncrease(size_t index) {
    if (index != 1 || warningConstruction->movedIcon) return 0.28f;
    // SaveIconCenterY belongs to the warning's FPBZStartupWarningSettings.
    // The native builder reads it after constructing the body and hint.
    auto& construction = *warningConstruction;
    const auto iconPosition = construction.args + 0x314;
    if (!read(iconPosition, construction.iconCenter)
        || !std::isfinite(construction.iconCenter) || construction.iconCenter < 700 || construction.iconCenter > 750) return 0.28f;
    const float shiftedCenter = construction.iconCenter + 48;
    std::memcpy(reinterpret_cast<void*>(iconPosition), &shiftedCenter, sizeof(shiftedCenter));
    construction.movedIcon = true;
    return 0.42f;
}

bool isReviewedWarning(Address text, size_t index) {
    wchar_t raw[1024]{};
    char utf8[4096]{};
    if (!toText(text, raw)) return false;
    const int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, raw, -1, utf8, sizeof(utf8), nullptr, nullptr);
    const auto& entry = pbz_startup::entries[index];
    if (count != entry.bytes + 1) return false;
    uint64_t digest = 0xcbf29ce484222325ULL;
    for (int offset = 0; offset < count - 1; ++offset) {
        digest ^= static_cast<unsigned char>(utf8[offset]);
        digest *= 0x100000001b3ULL;
    }
    return digest == entry.digest;
}

__declspec(noinline) void __fastcall tracePlainConstruct(void* self, const void* args) {
    const Address caller = reinterpret_cast<Address>(_ReturnAddress()) - base;
    if (!warningConstruction || (caller != kWarningTitleCaller && caller != kWarningBodyCaller && caller != kPlainHelperCaller)) {
        originalPlainConstruct(self, args);
        return;
    }
    const size_t index = caller == kWarningTitleCaller ? 0 : caller == kWarningBodyCaller ? 1 : 2;
    const Address nativeArgs = reinterpret_cast<Address>(args);
    float nativeSpacing{}, trialSpacing{};
    Address delegate{};
    unsigned char set{};
    Address textStyle{};
    float fontSize{};
    const bool reviewed = isReviewedWarning(nativeArgs + 0x1a8, index);
    const bool safeBodyFont = index != 1 || (read(nativeArgs + 0x1d0, textStyle) && textStyle
        && read(textStyle + 0x50, fontSize) && fontSize >= 10 && fontSize <= 18.25f);
    const bool trySpacing = reviewed && index != 0 && safeBodyFont
        && read(nativeArgs + 0x3e0, nativeSpacing) && std::isfinite(nativeSpacing)
        && nativeSpacing >= 0.95f && nativeSpacing <= 1.35f && read(nativeArgs + 0x3e4, set) && set == 1
        && read(nativeArgs + 0x3e8, delegate) && !delegate;
    if (trySpacing) {
        trialSpacing = nativeSpacing + warningSpacingIncrease(index);
        // The verified call sites pass a mutable stack arguments object to this constructor.
        std::memcpy(reinterpret_cast<void*>(nativeArgs + 0x3e0), &trialSpacing, sizeof(trialSpacing));
    }
    originalPlainConstruct(self, args);
    if (trySpacing) std::memcpy(reinterpret_cast<void*>(nativeArgs + 0x3e0), &nativeSpacing, sizeof(nativeSpacing));
    const Address widget = reinterpret_cast<Address>(self);
    Address vtable{}, cache{};
    if (!read(widget, vtable) || vtable != base + kPlainVtable || !read(widget + 0x1f0, cache) || !cache) return;
    WarningWidget sample{};
    sample.created = GetTickCount64();
#ifdef PBZ_STARTUP_WARNING_QA
    sample.nativeSpacing = nativeSpacing;
    sample.trialSpacing = trialSpacing;
    wchar_t raw[1024]{};
    unsigned char simple{};
    if (toText(widget + 0x1e0, raw)) {
        sample.textLength = static_cast<int>(std::wcslen(raw));
        sample.firstGlyph = raw[0];
    }
    if (read(widget + 0x5de, simple)) sample.simpleMode = simple != 0;
#else
    unsigned char simple{1};
    read(widget + 0x5de, simple);
#endif
    uint16_t attributeFlags{};
    if (reviewed && !simple && (index == 0 || trySpacing) && read(widget + 0x5dc, attributeFlags)) {
        sample.font = widget + ((attributeFlags & 2) != 0 ? 0x4e0 : 0x208);
        sample.render.widget = widget;
        sample.render.cache = cache;
        sample.render.entry = &pbz_startup::entries[index];
    }
    AcquireSRWLockExclusive(&warningLock);
    warningWidgets[index] = sample;
    warningAddresses[index].store(cache, std::memory_order_release);
    ReleaseSRWLockExclusive(&warningLock);
}

int drawWarning(WarningWidget& sample, Address cache, const void* geometry,
    void* elements, int layer, const void* style) {
    auto& plan = sample.render;
    Address layout{}, lines{}, currentCache{};
    int lineCount{};
    float scale{};
    Geometry shape{};
    if (!plan.entry || !read(plan.widget + 0x1f0, currentCache) || currentCache != cache
        || !read(reinterpret_cast<Address>(geometry), shape)
        || !read(cache, layout) || !read(layout + 0x30, lines)
        || !read(layout + 0x38, lineCount) || lineCount < 1 || lineCount > kPlacementLineCapacity
        || !read(layout + 0x94, scale) || scale <= 0 || !simpleGeometry(shape, scale)) return layer;
    NativeLine captured[kPlacementLineCapacity]{};
    for (int index = 0; index < lineCount; ++index) {
        const auto ref = lines + static_cast<Address>(index) * 0x68 + 0x30;
        auto& line = captured[index];
        if (!read(ref, line) || line.model < 0 || line.model >= plan.entry->modelCount
            || line.begin < 0 || line.end < line.begin || line.end > 1024 || !std::isfinite(line.y)
            || !std::isfinite(line.width) || !std::isfinite(line.textHeight)) return layer;
    }
    if (updatePlanGeometry(plan, layout, lines, captured, lineCount, scale)) {
        plan.ready = makePlan(plan, sample.font, pbz_startup::readings, pbz_startup::modelLengths);
    }
    const int result = drawPlacedReadings(plan, sample.font, shape, elements, layer, style);
#ifdef PBZ_STARTUP_WARNING_QA
    if (result > layer) ++sample.rubyPaints;
#endif
    return result;
}

__declspec(noinline) int __fastcall tracePlainLayoutPaint(const void* self, const void* args, const void* geometry,
    const void* clip, void* elements, int layer, const void* style, bool enabled) {
    const Address caller = reinterpret_cast<Address>(_ReturnAddress()) - base;
    int result = originalPlainLayoutPaint(self, args, geometry, clip, elements, layer, style, enabled);
    if (caller != kPlainLayoutCaller || !warningActive.load(std::memory_order_acquire)) return result;
    const Address cache = reinterpret_cast<Address>(self);
    const auto match = std::find_if(warningAddresses.begin(), warningAddresses.end(), [cache](const auto& address) {
        return address.load(std::memory_order_acquire) == cache;
    });
    if (match == warningAddresses.end()) return result;
    AcquireSRWLockExclusive(&warningLock);
    auto& sample = warningWidgets[static_cast<size_t>(match - warningAddresses.begin())];
    if (match->load(std::memory_order_relaxed) == cache && warningActive.load(std::memory_order_relaxed)) {
        if (GetTickCount64() - sample.created > 45000) {
            match->store(0, std::memory_order_release);
        } else {
#ifdef PBZ_STARTUP_WARNING_QA
            if (++sample.paints <= 3) {
            Geometry shape{};
            Address layout{}, lines{};
            if (read(reinterpret_cast<Address>(geometry), shape)) {
                sample.width = shape.width;
                sample.height = shape.height;
            }
            if (read(cache, layout)
                && read(layout + 0x30, lines) && read(layout + 0x38, sample.lines)
                && read(layout + 0x94, sample.scale) && sample.lines > 0 && sample.lines <= 40) {
                NativeLine previous{};
                bool gapCaptured{};
                for (int index = 0; index < sample.lines; ++index) {
                    NativeLine line{};
                    if (!read(lines + index * 0x68 + 0x30, line)) break;
                    if (index == 0) sample.firstLineHeight = static_cast<float>(line.height);
                    if (index && line.width > 0 && previous.width > 0) {
                        const auto gap = static_cast<float>(line.y - previous.y - previous.height);
                        const auto glyphGap = static_cast<float>(line.y - previous.y - previous.textHeight);
                        sample.minimumGap = gapCaptured ? std::min(sample.minimumGap, gap) : gap;
                        sample.textGap = gapCaptured ? std::min(sample.textGap, glyphGap) : glyphGap;
                        gapCaptured = true;
                    }
                    previous = line;
                }
            }
            }
#endif
            if (enabled) result = drawWarning(sample, cache, geometry, elements, result, style);
        }
    }
    ReleaseSRWLockExclusive(&warningLock);
    return result;
}

bool installWarning() {
    const unsigned char warning[] = {0x48,0x89,0x5c,0x24,0x18,0x55,0x56,0x57,0x41,0x54,0x41,0x55,0x41,0x56,0x41,0x57};
    const unsigned char construct[] = {0x48,0x89,0x5c,0x24,0x18,0x48,0x89,0x74,0x24,0x20,0x55,0x57,0x41,0x54,0x41,0x56};
    const unsigned char paint[] = {0x48,0x89,0x5c,0x24,0x08,0x48,0x89,0x6c,0x24,0x10,0x48,0x89,0x74,0x24,0x18,0x48};
    const unsigned char caller[] = {0xe8,0x06,0xe1,0xff,0xff,0x0f,0x57,0xc0,0x8b,0xd8};
    Address slot{};
    if (!verify(kWarningConstruct, warning) || !verify(kPlainConstruct, construct)
        || !verify(kPlainLayoutPaint, paint) || !verify(kPlainLayoutCaller - 5, caller)
        || !read(base + kPlainVtable + 0x230, slot) || slot != base + kPlainPaint) {
        warningStatus.store(-1, std::memory_order_release);
        return false;
    }
    const auto screen = reinterpret_cast<void*>(base + kWarningConstruct);
    const auto text = reinterpret_cast<void*>(base + kPlainConstruct);
    const auto onPaint = reinterpret_cast<void*>(base + kPlainLayoutPaint);
    const auto screenStatus = MH_CreateHook(screen, reinterpret_cast<void*>(&traceWarningConstruct),
        reinterpret_cast<void**>(&originalWarningConstruct));
    const auto textStatus = MH_CreateHook(text, reinterpret_cast<void*>(&tracePlainConstruct),
        reinterpret_cast<void**>(&originalPlainConstruct));
    const auto paintStatus = MH_CreateHook(onPaint, reinterpret_cast<void*>(&tracePlainLayoutPaint),
        reinterpret_cast<void**>(&originalPlainLayoutPaint));
    if (screenStatus != MH_OK || textStatus != MH_OK || paintStatus != MH_OK) {
        warningStatus.store(-(1000 * screenStatus + 32 * textStatus + paintStatus), std::memory_order_release);
        return false;
    }
    const bool installed = MH_QueueEnableHook(screen) == MH_OK && MH_QueueEnableHook(text) == MH_OK
        && MH_QueueEnableHook(onPaint) == MH_OK && MH_ApplyQueued() == MH_OK;
    warningStatus.store(installed ? 1 : -2, std::memory_order_release);
    return installed;
}

bool retireWarning() {
    if (!warningActive.exchange(false, std::memory_order_acq_rel)) return warningStatus.load() == 2;
    const bool removed = MH_QueueDisableHook(reinterpret_cast<void*>(base + kWarningConstruct)) == MH_OK
        && MH_QueueDisableHook(reinterpret_cast<void*>(base + kPlainConstruct)) == MH_OK
        && MH_QueueDisableHook(reinterpret_cast<void*>(base + kPlainLayoutPaint)) == MH_OK
        && MH_ApplyQueued() == MH_OK;
    warningStatus.store(removed ? 2 : -3, std::memory_order_release);
    return removed;
}

#ifdef PBZ_STARTUP_WARNING_QA
int exportWarningSample(void* state, size_t index) {
    if (!state) return 0;
    static LuaAPI lua;
    static const bool luaReady = lua.bind();
    if (!luaReady) return 0;
    alignas(16) unsigned char wrapper[256]{};
    lua.ctor(wrapper, state);
    if (lua.state(wrapper) != state) return 0;
    AcquireSRWLockShared(&warningLock);
    const auto sample = warningWidgets[index];
    ReleaseSRWLockShared(&warningLock);
    lua.number(wrapper, warningStatus.load(std::memory_order_acquire));
    lua.number(wrapper, static_cast<double>(sample.created));
    lua.number(wrapper, sample.paints);
    lua.number(wrapper, sample.textLength);
    lua.number(wrapper, sample.firstGlyph);
    lua.number(wrapper, sample.simpleMode);
    lua.number(wrapper, sample.lines);
    lua.number(wrapper, sample.width);
    lua.number(wrapper, sample.height);
    lua.number(wrapper, sample.scale);
    lua.number(wrapper, sample.firstLineHeight);
    lua.number(wrapper, sample.minimumGap);
    lua.number(wrapper, sample.nativeSpacing);
    lua.number(wrapper, sample.trialSpacing);
    lua.number(wrapper, sample.textGap);
    lua.number(wrapper, sample.render.attempted);
    lua.number(wrapper, sample.render.count);
    lua.number(wrapper, sample.rubyPaints);
    float minFont{}, maxFont{};
    if (sample.render.ready && sample.render.count) {
        minFont = maxFont = sample.render.words[0].fontSize;
        for (unsigned word = 1; word < sample.render.count; ++word) {
            const auto size = sample.render.words[word].fontSize;
            minFont = std::min(minFont, size);
            maxFont = std::max(maxFont, size);
        }
    }
    lua.number(wrapper, minFont);
    lua.number(wrapper, maxFont);
    return 20;
}
#endif
