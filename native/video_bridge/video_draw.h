// Placement coordinates use source raster pixels until the native image paints.
struct Vec2f { float x, y; };
struct NativeString { const wchar_t* data; int count, capacity; };
struct StringView { const wchar_t* data; int length, reserved; };
struct PaintGeometry {
    float px, py, scale, drawWidth, drawHeight, localWidth, localHeight;
    float xx, xy, yx, yy, x, y;
    unsigned char flags;
};
static_assert(sizeof(PaintGeometry) == 0x38 && sizeof(wchar_t) == sizeof(char16_t));
using Font = std::array<unsigned char, 0x60>;
constexpr Address kTextString = 0x131e1e0, kRunVtable = 0xa7f1800, kBlockVtable = 0xa7f1bd8;
constexpr Address kLocate = 0x1987130, kMeasure = 0x17405d0, kAcquireMeasure = 0x1783230;
constexpr Address kRelease = 0x126ec80, kDrawText = 0x1786ef0, kSlateApp = 0xde4e500;
using Locate = Vec*(__fastcall*)(Address, Vec*, const Shared*, int, float);
using Measure = Vec2f*(__fastcall*)(Address, Vec2f*, const StringView*, const void*, float);
using DrawText = void(__fastcall*)(void*, unsigned, const PaintGeometry*, const NativeString*,
    const void*, unsigned char, const float*);

bool verifiedDraw() {
    const unsigned char text[] = {0x40,0x53,0x48,0x83,0xec,0x20,0x48,0x8b,0xd9,0xe8,0x92,0xc1,0,0,0x48,0x8b};
    const unsigned char locate[] = {0x48,0x89,0x5c,0x24,0x18,0x48,0x89,0x74,0x24,0x20,0x55,0x57,0x41,0x56,0x48,0x8d};
    const unsigned char measure[] = {0x4c,0x8b,0xdc,0x53,0x48,0x83,0xec,0x70,0x41,0x0f,0x10,0x00,0x49,0x8d,0x43,0x10};
    const unsigned char acquire[] = {0x48,0x89,0x5c,0x24,0x08,0x57,0x48,0x83,0xec,0x20,0x48,0x8b,0xda,0x48,0x8b,0xf9};
    const unsigned char release[] = {0x48,0x85,0xc9,0x74,0x42,0x53,0x48,0x83,0xec,0x20,0x48,0x89,0x7c,0x24,0x30,0x48};
    const unsigned char draw[] = {0x40,0x53,0x55,0x56,0x41,0x54,0x41,0x56,0x48,0x83,0xec,0x40,0x48,0x8b,0xe9,0x4d};
    Address slot{};
    return verify(kTextString, text) && verify(kLocate, locate) && verify(kMeasure, measure)
        && verify(kAcquireMeasure, acquire) && verify(kRelease, release) && verify(kDrawText, draw)
        && read(base + kRunVtable + 0x58, slot) && slot == base + kLocate;
}

bool readText(Address text, wchar_t (&buffer)[1024]) {
    Address storage{}, vtable{};
    if (!read(text, storage) || !read(storage, vtable) || vtable < base || vtable >= base + kImageSize) return false;
    NativeString string{};
    __try {
        using Get = const NativeString*(__fastcall*)(Address);
        const auto value = reinterpret_cast<Get>(base + kTextString)(text);
        if (!read(reinterpret_cast<Address>(value), string)) return false;
    } __except (EXCEPTION_EXECUTE_HANDLER) {
        return false;
    }
    return string.count > 0 && string.count <= 1024 && string.capacity >= string.count && string.capacity <= 65536
        && copy(buffer, reinterpret_cast<Address>(string.data), string.count * sizeof(wchar_t))
        && buffer[string.count - 1] == 0;
}

const pbz_video::Cue* identify(Address text) {
    wchar_t raw[1024]{};
    if (!readText(text, raw)) return nullptr;
    char utf8[4096]{};
    const int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, raw, -1, utf8, sizeof(utf8), nullptr, nullptr);
    if (count <= 1) return nullptr;
    uint64_t digest = 0xcbf29ce484222325ULL;
    for (int index = 0; index < count - 1; ++index) {
        digest ^= static_cast<unsigned char>(utf8[index]);
        digest *= 0x100000001b3ULL;
    }
    const auto end = std::end(pbz_video::cues);
    const auto cue = std::lower_bound(std::begin(pbz_video::cues), end, digest,
        [](const auto& candidate, uint64_t key) { return candidate.digest < key; });
    return cue != end && cue->digest == digest && cue->bytes == count - 1 ? cue : nullptr;
}

bool locate(Address line, int character, bool trailing, float scale, double& result) {
    Address blocks{};
    int count{};
    if (!read(line, blocks) || !read(line + 8, count) || count <= 0 || count > 64) return false;
    for (int index = 0; index < count; ++index) {
        Shared block{};
        Address vtable{}, run{}, runVtable{};
        int begin{}, end{};
        if (!read(blocks + static_cast<Address>(index) * sizeof(Shared), block) || !read(block.object, vtable)
            || vtable != base + kBlockVtable || !read(block.object + 0x18, begin) || !read(block.object + 0x1c, end)) continue;
        const bool inside = trailing ? begin < character && character <= end : begin <= character && character < end;
        if (!inside || !read(block.object + 8, run) || !read(run, runVtable) || runVtable != base + kRunVtable) continue;
        Vec point{};
        reinterpret_cast<Locate>(base + kLocate)(run, &point, &block, character - begin, scale);
        result = point.x;
        return std::isfinite(result) && std::abs(result) < 16384;
    }
    return false;
}

Shared acquireMeasure() {
    using Acquire = Shared*(__fastcall*)(Address, Shared*);
    Address app{}, handle{}, renderer{};
    Shared result{};
    if (read(base + kSlateApp, app) && read(app + 0x60, handle) && read(handle + 8, renderer) && renderer) {
        reinterpret_cast<Acquire>(base + kAcquireMeasure)(renderer, &result);
    }
    return result;
}

void sizeFont(Font& font, float size) {
    constexpr int spacing = 0;
    int outline{};
    std::memcpy(&outline, font.data() + 0x10, sizeof(outline));
    outline = std::clamp(outline, 0, 1);
    std::memcpy(font.data() + 0x10, &outline, sizeof(outline));
    std::memcpy(font.data() + 0x48, &size, sizeof(size));
    std::memcpy(font.data() + 0x4c, &spacing, sizeof(spacing));
}

struct Anchor {
    const wchar_t* kana;
    int length, line;
    float center;
};

bool buildPlan(Cue& cue, Address widget, Address styleAddress, Address text, const Geometry& root, bool speaker, bool plain, bool namesOnly = false) {
    const auto* reading = identify(text);
    if (!reading) return false;
    const unsigned readingCount = namesOnly ? reading->nameCount : reading->readingCount;
    const unsigned readingBegin = namesOnly ? reading->nameBegin : reading->readingBegin;
    if (!readingCount || readingCount > 48) return false;
    const auto* readingWords = namesOnly ? pbz_video::nameReadings : pbz_video::readings;
    Geometry geometry{};
    Address cache{}, layout{}, lines{}, nativeFont{}, paintFont{};
    int count{};
    float scale{}, fontSize{};
    Font font{};
    unsigned char simple{};
    if (plain && (!read(widget + 0x5de, simple) || simple)) return false;
    if (!read(widget + 0x98, geometry) || !read(widget + (plain ? 0x1f0 : 0x208), cache) || !read(cache, layout)
        || !read(layout + 0x30, lines) || !read(layout + 0x38, count) || count <= 0 || count > 12
        || !read(layout + 0x94, scale) || !std::isfinite(scale) || scale < .1f || scale > 8
        || !read(styleAddress, paintFont) || !paintFont
        || (!plain && (!read(widget + 0x218, nativeFont) || nativeFont != paintFont))
        || !read(styleAddress + 0x48, fontSize) || !std::isfinite(fontSize) || fontSize < 10 || fontSize > 128
        || !copy(font.data(), styleAddress, font.size())) return false;
    if (!std::isfinite(geometry.xx) || std::abs(geometry.xx - scale) > .005 || std::abs(geometry.yy - scale) > .005
        || std::abs(geometry.xy) > .005 || std::abs(geometry.yx) > .005) return false;
    std::array<NativeLine, 12> native{};
    std::array<int, 12> covered{};
    if (reading->modelCount > covered.size()) return false;
    for (int line = 0; line < count; ++line) {
        auto& row = native[line];
        if (!read(lines + static_cast<Address>(line) * 0x68 + 0x30, row) || row.model < 0
            || row.model >= reading->modelCount || row.begin != covered[row.model] || row.end <= row.begin
            || !std::isfinite(row.y) || !std::isfinite(row.textHeight) || row.textHeight <= 0) return false;
        covered[row.model] = row.end;
    }
    for (int model = 0; model < reading->modelCount; ++model) {
        if (covered[model] != pbz_video::modelLengths[reading->modelBegin + model]) return false;
    }
    std::array<Anchor, 48> anchors{};
    unsigned anchorCount{};
    for (unsigned index = 0; index < readingCount; ++index) {
        const auto& word = readingWords[readingBegin + index];
        for (int line = 0; line < count; ++line) {
            if (native[line].model != word.model || native[line].begin > word.begin || native[line].end < word.end) continue;
            const auto address = lines + static_cast<Address>(line) * 0x68;
            double left{}, right{};
            if (!locate(address, word.begin, false, scale, left) || !locate(address, word.end, true, scale, right) || right <= left) return false;
            const auto* kana = reinterpret_cast<const wchar_t*>(word.kana);
            anchors[anchorCount++] = {kana, static_cast<int>(std::wcslen(kana)), line,
                geometry.x - root.x + static_cast<float>((left + right) / 2)};
            break;
        }
    }
    if (anchorCount != readingCount) return false;
    const auto service = acquireMeasure();
    struct Release {
        Address control;
        ~Release() { reinterpret_cast<void(__fastcall*)(Address)>(base + kRelease)(control); }
    } release{service.control};
    if (!service.object) return false;

    auto& destination = speaker ? cue.speaker : (namesOnly ? cue.bodyNames : cue.body);
    std::vector<Placement> positioned;
    for (unsigned begin = 0; begin < anchorCount;) {
        const int line = anchors[begin].line;
        unsigned end = begin + 1;
        while (end < anchorCount && anchors[end].line == line) ++end;
        bool placed{};
        for (float fraction : {0.46f, 0.42f, 0.38f, 0.34f, 0.30f, 0.26f}) {
            const float rubySize = fontSize * fraction;
            sizeFont(font, rubySize);
            const auto before = positioned.size();
            float previousEnd{};
            for (unsigned index = begin; index < end; ++index) {
                const auto& anchor = anchors[index];
                const StringView input{anchor.kana, anchor.length, 0};
                Vec2f measured{};
                reinterpret_cast<Measure>(base + kMeasure)(service.object, &measured, &input, font.data(), scale);
                if (!std::isfinite(measured.x) || !std::isfinite(measured.y) || measured.x <= 0 || measured.y <= 0) return false;
                const float x = anchor.center - measured.x / 2;
                const float top = static_cast<float>(native[line].y) - measured.y - scale;
                if ((index > begin && x < previousEnd + scale)
                    || (line > 0 && top < native[line - 1].y + native[line - 1].textHeight - scale)) break;
                positioned.push_back({anchor.kana, anchor.length, x, geometry.y - root.y + top, measured.x, measured.y, rubySize});
                previousEnd = x + measured.x;
            }
            if (positioned.size() == before + end - begin) {
                placed = true;
                break;
            }
            positioned.resize(before);
        }
        if (!placed) return false;
        begin = end;
    }
    destination = std::move(positioned);
    return true;
}

using Color = std::array<float, 4>;

bool readColor(Address address, Color& out) {
    return read(address, out) && std::all_of(out.begin(), out.end(), [](float component) {
        return std::isfinite(component) && component >= 0 && component <= 16;
    });
}

bool resolveColor(Address slateColor, Address style, Color& out) {
    unsigned char mode{};
    if (!read(slateColor + 0x10, mode)) return false;
    if (mode == 0) return readColor(slateColor, out);
    if (mode == 2) return readColor(style + 0x10, out);
    if (mode == 3) return readColor(style + 0x20, out);
    return false;
}

bool drawPlan(const Cue& cue, const Geometry& geometry, const float* culling, Address style,
    void* elements, int layer, bool namesOnly) {
    if (geometry.width <= 0 || geometry.height <= 0 || geometry.scale <= 0
        || !std::isfinite(geometry.x) || !std::isfinite(geometry.y)
        || std::abs(geometry.xx - geometry.scale) > .005 || std::abs(geometry.yy - geometry.scale) > .005
        || std::abs(geometry.xy) > .005 || std::abs(geometry.yx) > .005) return false;
    const float xRatio = static_cast<float>(geometry.width * geometry.xx / cue.rasterSize.x);
    const float yRatio = static_cast<float>(geometry.height * geometry.yy / cue.rasterSize.y);
    if (!std::isfinite(xRatio) || !std::isfinite(yRatio) || xRatio < .1f || xRatio > 8 || std::abs(xRatio - yRatio) > .015f) return false;
    Color parent{}, image{}, brush{};
    if (!readColor(style, parent) || !resolveColor(cue.image + 0x1e8, style, image)
        || !resolveColor(cue.brush + 8, style, brush)) return false;
    Color tint{};
    for (size_t index = 0; index < tint.size(); ++index) tint[index] = parent[index] * image[index] * brush[index];
    if (tint[3] <= 0) return false;
    bool drew{};
    const auto draw = [&](const std::vector<Placement>& words, Address styleAddress) {
        Font font{};
        if (words.empty() || !copy(font.data(), styleAddress, font.size())) return;
        Color color{};
        const bool gotColor = cue.channel == &dateText
            ? readColor(cue.overlay + 0x2d8, color) : resolveColor(styleAddress + 0x60, style, color);
        if (!gotColor || color[3] <= 0) return;
        for (size_t index = 0; index < color.size(); ++index) color[index] *= tint[index];
        Color outline{};
        std::memcpy(outline.data(), font.data() + 0x20, sizeof(outline));
        for (size_t index = 0; index < outline.size(); ++index) outline[index] *= tint[index];
        std::memcpy(font.data() + 0x20, outline.data(), sizeof(outline));
        float size{};
        for (const auto& word : words) {
            const float x = word.x * xRatio, y = word.y * yRatio;
            const float w = word.width * xRatio, h = word.height * yRatio;
            if (geometry.x + x < culling[0] || geometry.y + y < culling[1]
                || geometry.x + x + w > culling[2] || geometry.y + y + h > culling[3]) continue;
            if (size != word.size) {
                size = word.size;
                sizeFont(font, size * cue.rasterScale * xRatio / geometry.scale);
            }
            const PaintGeometry paint{geometry.layoutX + x, geometry.layoutY + y, geometry.scale, 0, 0,
                w / geometry.scale, h / geometry.scale, geometry.scale, 0, 0, geometry.scale, geometry.x + x, geometry.y + y, 0};
            const NativeString kana{word.kana, word.length + 1, word.length + 1};
            reinterpret_cast<DrawText>(base + kDrawText)(elements, static_cast<unsigned>(layer + 1),
                &paint, &kana, font.data(), 0, color.data());
            drew = true;
        }
    };
    draw(namesOnly || cue.body.empty() ? cue.bodyNames : cue.body, cue.overlay + cue.channel->bodyFont);
    if (cue.channel->speakerFont) draw(cue.speaker, cue.overlay + cue.channel->speakerFont);
    return drew;
}
