local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Resolve reviewed entries for widgets that sometimes receive a formatted FText
-- with no localization key. An ambiguous exact string requires the actual key.
local M = {}

local function readingSignature(segments)
    local position = 0
    local spans = {}
    for _, segment in ipairs(segments) do
        if segment.reading then
            spans[#spans + 1] = string.format('%d:%d:%s', position, #segment.text, segment.reading)
        end
        position = position + #segment.text
    end
    return table.concat(spans, '|')
end

local DTV = '<dtv id="X%d%d%d"/>'
local NUMBER_STYLE = '<WeaponDes_Num_Green>'

local function compileDynamic(entry)
    local count, start = 0, 1
    local parts = {'^'}
    while true do
        local first, last = entry.original:find(DTV, start)
        local literal = entry.original:sub(start, first and first - 1 or #entry.original)
        parts[#parts + 1] = literal:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
        if not first then break end
        count = count + 1
        if count > 12 then return end
        parts[#parts + 1] = '(' .. NUMBER_STYLE .. '[%d%+%-%.,%%]+</>)'
        start = last + 1
    end
    if count == 0 then return end
    local segments = 0
    for _, segment in ipairs(entry.segments) do
        local _, occurrences = segment.text:gsub(DTV, '')
        if occurrences > 0 and segment.reading then return end
        segments = segments + occurrences
    end
    if count ~= segments then return end
    parts[#parts + 1] = '$'
    return {entry = entry, pattern = table.concat(parts)}
end

local function resolveDynamic(candidate, text)
    if candidate.entry.dynamic then return compact.dynamic(candidate.entry, text) end
    local values = {text:match(candidate.pattern)}
    if #values == 0 then return end
    for _, value in ipairs(values) do
        local number = value:sub(#NUMBER_STYLE + 1, -4)
        if #number > 24 or not number:match('^[+%-]?%d[%d,]*%.?%d*%%?$') then return end
    end
    local parts, offset = {}, 0
    for index, segment in ipairs(candidate.entry.segments) do
        if segment.reading then
            parts[index] = segment
        else
            local piece = segment.text:gsub(DTV, function()
                offset = offset + 1
                return values[offset]
            end)
            parts[index] = {text = piece}
        end
    end
    return {key = candidate.entry.key, context = candidate.entry.context, original = text, segments = parts}
end

function M.index(entries, allowDynamic)
    local byKey = {}
    local byContext = {}
    local dynamicByKey, dynamicByContext = {}, {}
    local keys = {}
    for key in pairs(entries) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local entry = entries[key]
        local signature = entry.parts and compact.signature(entry.parts) or readingSignature(entry.segments)
        if signature ~= '' then
            byKey[key] = entry
            if allowDynamic then
                local candidate = entry.dynamic and {entry = entry}
                    or entry.original and compileDynamic(entry)
                if candidate then
                    dynamicByKey[key] = candidate
                    local group = dynamicByContext[entry.context] or {}
                    group[#group + 1] = candidate
                    dynamicByContext[entry.context] = group
                end
            end
            local texts = byContext[entry.context] or {}
            byContext[entry.context] = texts
            local fingerprint = entry.fingerprint or compact.fingerprint(entry.original)
            local previous = texts[fingerprint]
            if previous == nil then
                texts[fingerprint] = {entry = entry, signature = signature}
            elseif previous and previous.signature ~= signature then
                texts[fingerprint] = false
            end
        end
    end
    return function(context, key, text)
        if key ~= '' then
            local entry = byKey[key]
            local resolved = entry and entry.context == context and compact.match(entry, text)
            if resolved then return resolved end
            local candidate = dynamicByKey[key]
            if candidate and candidate.entry.context == context then return resolveDynamic(candidate, text) end
        else
            local texts = byContext[context]
            local fingerprint = texts and compact.fingerprint(text)
            local match = fingerprint and texts[fingerprint]
            if match then return compact.match(match.entry, text, fingerprint) end
            if match == false or not text:find(NUMBER_STYLE, 1, true) then return end
            local resolved
            for _, candidate in ipairs(dynamicByContext[context] or {}) do
                local entry = resolveDynamic(candidate, text)
                if entry then
                    if resolved and readingSignature(resolved.segments) ~= readingSignature(entry.segments) then return end
                    resolved = resolved or entry
                end
            end
            return resolved
        end
    end
end

return M
