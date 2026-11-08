// Native loading-view ruby. The original Slate text and layout stay in place.
struct Vec2d { double x, y; };
struct Vec2f { float x, y; };
struct Shared { Address object, control; };
struct StringView { const wchar_t* data; int length, reserved; };
struct PaintGeometry {
    float px, py, scale, drawWidth, drawHeight, localWidth, localHeight;
    float xx, xy, yx, yy, x, y;
    unsigned char flags;
};
static_assert(sizeof(PaintGeometry) == 0x38 && offsetof(PaintGeometry, flags) == 0x34);
static_assert(sizeof(wchar_t) == sizeof(char16_t));
constexpr Address kRunVtable = 0xa7f1800, kBlockVtable = 0xa7f1bd8;
constexpr Address kLocate = 0x1987130, kMeasure = 0x17405d0, kAcquireMeasure = 0x1783230;
constexpr Address kRelease = 0x126ec80, kDrawText = 0x1786ef0, kSlateApp = 0xde4e500;
using Font = std::array<unsigned char, 0x60>;
using Locate = Vec2d*(__fastcall*)(Address, Vec2d*, const Shared*, int, float);
using Measure = Vec2f*(__fastcall*)(Address, Vec2f*, const StringView*, const void*, float);
using AcquireMeasure = Shared*(__fastcall*)(Address, Shared*);
using Release = void(__fastcall*)(Address);
using DrawText = void(__fastcall*)(void*, unsigned, const PaintGeometry*, const NativeString*,
    const void*, unsigned char, const float*);

struct Placement {
    std::array<wchar_t, pbz_loading::maxKanaLength + 1> kana;
    int length;
    float center, x, y, width, height, fontSize;
    int line;
};
constexpr int kPlacementLineCapacity = 20;

struct LoadingRender {
    Address widget, cache, layout, lines;
    const pbz_loading::Tip* entry;
    ULONGLONG created;
    unsigned count;
    float scale;
    int lineCount;
    std::array<NativeLine, kPlacementLineCapacity> nativeLines;
    std::array<Placement, 96> words;
    bool attempted, ready;
};
std::array<LoadingRender, 8> loadingWidgets{};
std::array<std::atomic<Address>, 8> loadingAddresses{};
size_t replacementIndex{};
SRWLOCK loadingLock = SRWLOCK_INIT;
struct LoadingLock {
    LoadingLock() { AcquireSRWLockExclusive(&loadingLock); }
    ~LoadingLock() { ReleaseSRWLockExclusive(&loadingLock); }
};

#ifdef PBZ_LOADING_QA
struct LoadingQASample {
    unsigned serial, words, painted;
    int entry, lines;
    bool ready;
    Address widget;
    std::array<NativeLine, kPlacementLineCapacity> native;
};
LoadingQASample loadingQA{};
#endif

bool verifiedRender() {
    const unsigned char locate[] = {0x48,0x89,0x5c,0x24,0x18,0x48,0x89,0x74,0x24,0x20,0x55,0x57,0x41,0x56,0x48,0x8d};
    const unsigned char measure[] = {0x4c,0x8b,0xdc,0x53,0x48,0x83,0xec,0x70,0x41,0x0f,0x10,0x00,0x49,0x8d,0x43,0x10};
    const unsigned char acquire[] = {0x48,0x89,0x5c,0x24,0x08,0x57,0x48,0x83,0xec,0x20,0x48,0x8b,0xda,0x48,0x8b,0xf9};
    const unsigned char release[] = {0x48,0x85,0xc9,0x74,0x42,0x53,0x48,0x83,0xec,0x20,0x48,0x89,0x7c,0x24,0x30,0x48};
    const unsigned char draw[] = {0x40,0x53,0x55,0x56,0x41,0x54,0x41,0x56,0x48,0x83,0xec,0x40,0x48,0x8b,0xe9,0x4d};
    Address slot{};
    return verify(kLocate, locate) && verify(kMeasure, measure) && verify(kAcquireMeasure, acquire)
        && verify(kRelease, release) && verify(kDrawText, draw)
        && read(base + kRunVtable + 0x58, slot) && slot == base + kLocate;
}

const pbz_loading::Tip* identifyTip(const wchar_t* raw) {
    char utf8[4096]{};
    const int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, raw, -1, utf8, sizeof(utf8), nullptr, nullptr);
    if (count <= 1) return nullptr;
    uint64_t digest = 0xcbf29ce484222325ULL;
    for (int i = 0; i < count - 1; ++i) {
        digest ^= static_cast<unsigned char>(utf8[i]);
        digest *= 0x100000001b3ULL;
    }
    const auto end = std::end(pbz_loading::tips);
    const auto tip = std::lower_bound(std::begin(pbz_loading::tips), end, digest,
        [](const auto& item, uint64_t key) { return item.digest < key; });
    return tip != end && tip->digest == digest && tip->bytes == count - 1 ? tip : nullptr;
}

void identifyLoadingWidget(Address widget, const wchar_t* raw) {
    const auto* entry = identifyTip(raw);
    Address cache{};
    const bool recognized = entry && read(widget + 0x208, cache) && cache;
    const LoadingLock lock;
    if (!enabledForLoading.load(std::memory_order_relaxed)) return;
    const auto slot = std::find_if(loadingWidgets.begin(), loadingWidgets.end(), [widget](const auto& item) {
        return item.widget == widget;
    });
    if (!recognized && slot == loadingWidgets.end()) return;
    const size_t index = slot != loadingWidgets.end()
        ? static_cast<size_t>(slot - loadingWidgets.begin()) : replacementIndex++ % loadingWidgets.size();
    auto& rendering = loadingWidgets[index];
    rendering = {};
    if (recognized) {
        rendering.widget = widget;
        rendering.cache = cache;
        rendering.entry = entry;
        rendering.created = GetTickCount64();
    }
    loadingAddresses[index].store(rendering.widget, std::memory_order_release);
}

bool positionAt(Address line, int character, bool trailing, float scale, double& result) {
    Address blocks{};
    int count{};
    if (!read(line, blocks) || !read(line + 8, count) || count <= 0 || count > 64) return false;
    for (int index = 0; index < count; ++index) {
        Shared block{};
        Address vtable{}, run{}, runVtable{};
        int begin{}, end{};
        const Address ref = blocks + static_cast<Address>(index) * sizeof(Shared);
        if (!read(ref, block) || !read(block.object, vtable) || vtable != base + kBlockVtable
            || !read(block.object + 0x18, begin) || !read(block.object + 0x1c, end)) continue;
        const bool inside = trailing ? begin < character && character <= end : begin <= character && character < end;
        if (!inside || !read(block.object + 8, run) || !read(run, runVtable) || runVtable != base + kRunVtable) continue;
        Vec2d location{};
        reinterpret_cast<Locate>(base + kLocate)(run, &location, &block, character - begin, scale);
        result = location.x;
        return std::isfinite(result) && std::abs(result) < 16384;
    }
    return false;
}

bool collectPositions(LoadingRender& plan, const pbz_loading::Reading* readings,
    const uint16_t* modelLengths) {
    const auto* entry = plan.entry;
    if (entry->readingCount > plan.words.size()) return false;
    for (int model = 0; model < entry->modelCount; ++model) {
        int expected{};
        for (int index = 0; index < plan.lineCount; ++index) {
            const auto& line = plan.nativeLines[index];
            if (line.model != model) continue;
            if (line.begin != expected) return false;
            expected = line.end;
        }
        if (expected != modelLengths[entry->modelBegin + model]) return false;
    }
    for (unsigned index = 0; index < entry->readingCount; ++index) {
        const auto& reading = readings[entry->readingBegin + index];
        const auto* kana = reinterpret_cast<const wchar_t*>(reading.kana);
        const int length = static_cast<int>(std::wcslen(kana));
        if (length <= 0 || static_cast<unsigned>(length) > pbz_loading::maxKanaLength) return false;
        const auto place = [&](int lineIndex, int begin, int end, int kanaBegin, int kanaEnd) {
            if (plan.count == plan.words.size()) return false;
            const auto& line = plan.nativeLines[lineIndex];
            const auto blocks = plan.lines + static_cast<Address>(lineIndex) * 0x68;
            double left{}, right{};
            if (!positionAt(blocks, begin, false, plan.scale, left)
                || !positionAt(blocks, end, true, plan.scale, right)
                || right <= left || left < line.x - 2 || right > line.x + line.width + 2) return false;
            auto& word = plan.words[plan.count++];
            word.length = kanaEnd - kanaBegin;
            std::copy_n(kana + kanaBegin, word.length, word.kana.begin());
            word.kana[word.length] = L'\0';
            word.center = static_cast<float>((left + right) * 0.5);
            word.line = lineIndex;
            return true;
        };
        if (!pbz_loading::placeReading(reading, length, plan.nativeLines.data(), plan.lineCount, place)) return false;
    }
    return plan.count > 0;
}

void sizeFont(Font& font, float size) {
    constexpr int none = 0;
    std::memcpy(font.data() + 0x10, &none, sizeof(none));
    std::memcpy(font.data() + 0x48, &size, sizeof(size));
    std::memcpy(font.data() + 0x4c, &none, sizeof(none));
}

Shared acquireMeasure() {
    Address app{}, rendererHandle{}, renderer{};
    Shared result{};
    if (read(base + kSlateApp, app) && read(app + 0x60, rendererHandle)
        && read(rendererHandle + 8, renderer) && renderer) {
        reinterpret_cast<AcquireMeasure>(base + kAcquireMeasure)(renderer, &result);
    }
    return result;
}

bool fitWords(LoadingRender& plan, Font& font, Address measure) {
    float originalSize{};
    std::memcpy(&originalSize, font.data() + 0x48, sizeof(originalSize));
    if (!std::isfinite(originalSize) || originalSize < 10 || originalSize > 128) return false;
    unsigned begin{};
    while (begin < plan.count) {
        const int lineIndex = plan.words[begin].line;
        unsigned end = begin + 1;
        while (end < plan.count && plan.words[end].line == lineIndex) ++end;
        const auto& line = plan.nativeLines[lineIndex];
        bool placed{};
        for (float fraction : {0.46f, 0.42f, 0.38f, 0.34f, 0.30f, 0.26f}) {
            const float fontSize = originalSize * fraction;
            sizeFont(font, fontSize);
            float previousEnd{};
            bool fits = true;
            for (unsigned index = begin; index < end; ++index) {
                auto& word = plan.words[index];
                const StringView kana{word.kana.data(), word.length, 0};
                Vec2f size{};
                reinterpret_cast<Measure>(base + kMeasure)(measure, &size, &kana, font.data(), plan.scale);
                if (!std::isfinite(size.x) || !std::isfinite(size.y) || size.x <= 0 || size.y <= 0) return false;
                word.width = size.x;
                word.height = size.y;
                word.fontSize = fontSize;
                word.x = word.center - size.x / 2;
                word.y = static_cast<float>(line.y) - size.y - plan.scale;
                const bool overlap = index > begin && word.x < previousEnd + plan.scale;
                const bool belowPreviousLine = lineIndex == 0
                    || word.y >= plan.nativeLines[lineIndex - 1].y + plan.nativeLines[lineIndex - 1].textHeight - plan.scale;
                if (overlap || !belowPreviousLine) {
                    fits = false;
                    break;
                }
                previousEnd = word.x + size.x;
            }
            if (fits) {
                placed = true;
                break;
            }
        }
        if (!placed) return false;
        begin = end;
    }
    return true;
}

bool makePlan(LoadingRender& plan, Address fontAddress, const pbz_loading::Reading* readings,
    const uint16_t* modelLengths) {
    Font font{};
    plan.count = 0;
    if (!copy(font.data(), fontAddress, font.size()) || !collectPositions(plan, readings, modelLengths)) return false;
    const Shared service = acquireMeasure();
    const bool ok = service.object && fitWords(plan, font, service.object);
    if (service.control) reinterpret_cast<Release>(base + kRelease)(service.control);
    return ok;
}

bool simpleGeometry(const Geometry& geometry, float scale) {
    auto closeTo = [](float a, float b) { return std::abs(a - b) < 0.002f; };
    return closeTo(geometry.padding[0], scale) && closeTo(geometry.xx, scale) && closeTo(geometry.yy, scale)
        && closeTo(geometry.xy, 0) && closeTo(geometry.yx, 0);
}

bool updatePlanGeometry(LoadingRender& plan, Address layout, Address lines,
    const NativeLine* nativeLines, int lineCount, float scale) {
    const bool changed = !plan.attempted || plan.layout != layout || plan.lines != lines || plan.scale != scale
        || plan.lineCount != lineCount || std::memcmp(nativeLines, plan.nativeLines.data(), lineCount * sizeof(NativeLine));
    if (changed) {
        plan.attempted = true;
        plan.layout = layout;
        plan.lines = lines;
        plan.lineCount = lineCount;
        plan.scale = scale;
        std::copy_n(nativeLines, lineCount, plan.nativeLines.data());
    }
    return changed;
}

int drawPlacedReadings(const LoadingRender& plan, Address fontAddress,
    const Geometry& geometry, void* elements, int layer, const void* style) {
    Font font{};
    float tint[4]{};
    if (!plan.ready || !copy(font.data(), fontAddress, font.size())
        || !copy(tint, reinterpret_cast<Address>(style), sizeof(tint))
        || !std::isfinite(tint[3]) || tint[3] <= 0) return layer;
    const float scale = plan.scale;
    float size{};
    for (unsigned index = 0; index < plan.count; ++index) {
        const auto& word = plan.words[index];
        if (size != word.fontSize) {
            size = word.fontSize;
            sizeFont(font, size);
        }
        const PaintGeometry paint{
            geometry.padding[1] + word.x, geometry.padding[2] + word.y, scale, 0, 0,
            word.width / scale, word.height / scale, scale, 0, 0, scale,
            geometry.x + word.x, geometry.y + word.y, 0
        };
        const NativeString kana{word.kana.data(), word.length + 1, word.length + 1};
        reinterpret_cast<DrawText>(base + kDrawText)(elements, static_cast<unsigned>(layer + 1),
            &paint, &kana, font.data(), 0, tint);
    }
    return layer + 1;
}

int renderLoading(LoadingRender& plan, Address layout, Address lines, const NativeLine* nativeLines,
    int lineCount, float scale, const Geometry& geometry, void* elements, int layer, const void* style) {
    const auto tip = plan.widget;
    float internalScale{};
    if (!simpleGeometry(geometry, scale) || !read(tip + 0x600, internalScale)
        || !std::isfinite(internalScale) || std::abs(internalScale - 1) >= 0.002f) return layer;
    if (updatePlanGeometry(plan, layout, lines, nativeLines, lineCount, scale)) {
        plan.ready = makePlan(plan, tip + 0x218, pbz_loading::readings, pbz_loading::modelLengths);
#ifdef PBZ_LOADING_QA
        loadingQA = {loadingQA.serial + 1, plan.count, 0, static_cast<int>(plan.entry - pbz_loading::tips),
            lineCount, plan.ready, plan.widget, plan.nativeLines};
#endif
    }
    const int result = drawPlacedReadings(plan, tip + 0x218, geometry, elements, layer, style);
#ifdef PBZ_LOADING_QA
    if (result > layer && loadingQA.widget == plan.widget) ++loadingQA.painted;
#endif
    return result;
}

