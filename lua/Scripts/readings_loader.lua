local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Effective tables are built by the same review loader used in development.
local M = {}
local tables = {}

function M.load(name, root)
    assert(name == 'prologue_readings' or name == 'item_readings' or name == 'bestiary_readings',
        'Unknown release reading domain')
    if not tables[name] then
        local records = assert(loadfile(root .. 'Scripts/reviewed_' .. name .. '.lua'))()
        if name == 'bestiary_readings' then
            records.titles = compact.exact(records.titles)
            records.paragraphs = compact.exact(records.paragraphs)
            tables[name] = records
        else
            tables[name] = compact.exact(records)
        end
    end
    return tables[name]
end

return M
