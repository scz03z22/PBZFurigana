#pragma once
#include <algorithm>
#include <iterator>
#include "loading_readings.h"

namespace pbz_loading {
// Draw a single reading together when a native wrap falls on an indivisible
// boundary. Anchor it to the fragment with the most base characters.
template<class Line, class Place>
bool placeReading(const Reading& reading, int kanaLength, const Line* lines, int lineCount, Place place) {
    int kanaBegin = 0;
    int anchorLine = -1, anchorBegin = 0, anchorEnd = 0;
    for (int index = 0; index < lineCount; ++index) {
        const auto& line = lines[index];
        if (line.model != reading.model) continue;
        const int begin = std::max(line.begin, static_cast<int>(reading.begin));
        const int end = std::min(line.end, static_cast<int>(reading.end));
        if (begin >= end) continue;
        if (end - begin > anchorEnd - anchorBegin) {
            anchorLine = index;
            anchorBegin = begin;
            anchorEnd = end;
        }
        const auto split = static_cast<unsigned>(end - reading.begin - 1);
        const int kanaEnd = end == reading.end ? kanaLength
            : split < std::size(reading.kanaBreaks) ? reading.kanaBreaks[split] : 0;
        if (kanaEnd == 0) continue;
        if (kanaEnd <= kanaBegin || kanaEnd > kanaLength
            || !place(anchorLine, anchorBegin, anchorEnd, kanaBegin, kanaEnd)) return false;
        kanaBegin = kanaEnd;
        anchorLine = -1;
        anchorBegin = anchorEnd = 0;
    }
    return kanaBegin == kanaLength;
}
}
