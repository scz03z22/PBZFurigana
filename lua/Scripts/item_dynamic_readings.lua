local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Reviewed dynamic medicine text only. This module never attaches a renderer.
-- ItemDetailText.js appends ': <WeaponDes_Num_Green>${maxTime}</>' to UI_Shop_08.
-- 0..99 is a deliberately bounded recognition range, not a claimed game maximum.
local M = {}
local LABEL = {["context"]="item_body",["fingerprint"]="18:aec1d2f405f8fdaa",["key"]="UI_Shop_08",["keys"]={"UI_Shop_08"},["parts"]={{6,"しよう"},{6,"かのう"},{6,"かいすう"}},["plain"]=true}

function M.lookup(text)
    if type(text) ~= "string" then return nil end
    local label, digits = text:match('^([^<>]+): <WeaponDes_Num_Green>([0-9]+)</>$')
    local entry = label and compact.match(LABEL, label)
    if not entry then return nil end
    -- ASCII canonical decimal only: no signs, fractions, leading zeroes or tags.
    if not (digits:match("^[0-9]$") or digits:match("^[1-9][0-9]$")) then
        return nil
    end
    entry.segments[4] = {text = text:sub(#label + 1)}
    return {
        key = "UI_Shop_08",
        keys = {"UI_Shop_08"},
        context = "item_body",
        quality = "reviewed_dynamic_entry",
        reading_origin = "reviewed_dynamic_japanese",
        dynamic_pattern = "medicine_max_usage_0_99",
        dynamic_value = tonumber(digits),
        -- Source markup remains byte-for-byte intact. Supporting its native
        -- decorator in a renderer is a separate, explicitly gated integration.
        label = label,
        segments = entry.segments,
    }
end

return M
