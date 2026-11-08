local M = {}
local fingerprints, fingerprintCount = {}, 0

-- The digest is only an index into reviewed readings. Length and all segment
-- boundaries are checked before the live string is passed to the renderer.
function M.fingerprint(text)
    local cached = fingerprints[text]
    if cached then return cached end
    local hash = 0xcbf29ce484222325
    for position = 1, #text do
        hash = (hash ~ text:byte(position)) * 0x100000001b3
    end
    local fingerprint = string.format('%d:%016x', #text, hash)
    if fingerprintCount >= 512 then fingerprints, fingerprintCount = {}, 0 end
    fingerprints[text], fingerprintCount = fingerprint, fingerprintCount + 1
    return fingerprint
end

function M.expand(record, text, fingerprint)
    if type(record) ~= 'table' then return record end
    if not record.parts then return record end
    if type(text) ~= 'string' or (fingerprint or M.fingerprint(text)) ~= record.fingerprint then return nil end
    local entry = {}
    for key, value in pairs(record) do
        if key ~= 'parts' and key ~= 'fingerprint' and key ~= 'paragraph_entry' then entry[key] = value end
    end
    local segments, position = {}, 1
    for index, part in ipairs(record.parts) do
        local nextPosition = position + part[1]
        local nextByte = text:byte(nextPosition)
        if nextPosition > #text + 1 or (nextByte and nextByte >= 128 and nextByte < 192) then return nil end
        segments[index] = {text = text:sub(position, nextPosition - 1), reading = part[2]}
        position = nextPosition
    end
    if position ~= #text + 1 then return nil end
    entry.original, entry.segments = text, segments
    if record.paragraph_entry then entry.paragraph_entry = M.expand(record.paragraph_entry, text, fingerprint) end
    return entry
end

function M.match(record, text, fingerprint)
    if not record then return nil end
    if record.parts then return M.expand(record, text, fingerprint) end
    if record.original == text then return record end
end

function M.is_plain(record)
    if record.parts then return record.plain end
    return not record.original:find('[<>\r\n{}]')
end

function M.signature(parts)
    local position, spans = 0, {}
    for _, part in ipairs(parts) do
        if part[2] then spans[#spans + 1] = string.format('%d:%d:%s', position, part[1], part[2]) end
        position = position + part[1]
    end
    return table.concat(spans, '|')
end

function M.dynamic(record, text)
    local tag = '<dtv id="X001"/>'
    local values, pieces = {}, {}
    local cursor, shift = 1, 0
    for i, offset in ipairs(record.dynamic_offsets) do
        local start = offset + shift
        local first, last, number = text:find('^<WeaponDes_Num_Green>([%d%+%-%.,%%]+)</>', start)
        if not first or #number > 24 or not number:match('^[+%-]?%d[%d,]*%.?%d*%%?$') then return nil end
        pieces[#pieces + 1] = text:sub(cursor, first - 1)
        pieces[#pieces + 1] = tag
        values[i] = text:sub(first, last)
        shift = shift + #values[i] - #tag
        cursor = last + 1
    end
    pieces[#pieces + 1] = text:sub(cursor)
    local normalized = table.concat(pieces)
    if M.fingerprint(normalized) ~= record.dynamic then return nil end
    local normalizedRecord = {parts = record.parts, fingerprint = record.dynamic}
    local expanded = M.expand(normalizedRecord, normalized, record.dynamic)
    if not expanded then return nil end
    local index = 0
    for _, segment in ipairs(expanded.segments) do
        if not segment.reading then
            segment.text = segment.text:gsub(tag, function()
                index = index + 1
                return values[index]
            end)
        end
    end
    if index ~= #values then return nil end
    return {key = record.key, context = record.context, original = text, segments = expanded.segments}
end

function M.exact(records)
    local cache, size = {}, 0
    return setmetatable({}, {__index = function(_, text)
        if type(text) ~= 'string' then return nil end
        local entry = cache[text]
        if entry == nil then
            local fingerprint = M.fingerprint(text)
            entry = M.expand(records[fingerprint], text, fingerprint)
            if entry == nil then entry = true end
            if size >= 512 then cache, size = {}, 0 end
            cache[text], size = entry, size + 1
        end
        if entry ~= true then return entry end
    end})
end

return M

