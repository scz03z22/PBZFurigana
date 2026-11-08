local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Native scrolling rows for weapon moves and memory flower dialogue.
-- Put each layer inside its own row so the game's scroll clipping applies.
local M = {}
local SCRIPT = 'Scripts/'

local function valid(object)
    return object and object:IsValid()
end

local function name(object)
    return object:GetFullName()
end

local function kind(object)
    return valid(object) and object:GetClass():GetFName():ToString() or ''
end

local function asString(value)
    return type(value) == 'string' and value or value:ToString()
end

local function padding(slot)
    local p = slot.Padding
    return {Left = p.Left, Top = p.Top, Right = p.Right, Bottom = p.Bottom}
end

local function samePadding(a, b)
    for _, field in ipairs({'Left', 'Top', 'Right', 'Bottom'}) do
        if math.abs(a[field] - b[field]) > .05 then return false end
    end
    return true
end

local function visible(widget, classes)
    for _ = 1, 36 do
        if not valid(widget) then return true end
        if not widget:IsA(classes.widget) then return false end
        local visibility = widget:GetVisibility()
        if visibility == 1 or visibility == 2 or widget:GetRenderOpacity() < .01 then return false end
        if widget:IsA(classes.activatable) and not widget:IsActivated() then return false end
        local parent = widget:GetParent()
        if valid(parent) then
            if parent:IsA(classes.switcher) or parent:IsA(classes.commonSwitcher) then
                local active = parent:GetActiveWidget()
                if not valid(active) or name(active) ~= name(widget) then return false end
            end
        else
            local tree = widget:GetOuter()
            parent = kind(tree) == 'WidgetTree' and tree:GetOuter() or nil
            if valid(parent) and not parent:IsA(classes.widget) then return false end
        end
        widget = parent
    end
    return false
end

local function make(class, owner, id)
    local object = StaticConstructObject(StaticFindObject('/Script/UMG.' .. class), owner, FName(id))
    return assert(valid(object) and object, 'Cannot create scrolling row ruby ' .. class)
end

local function readSource(widget, context, lookup, renderer, allowMarkup, singleLine, reviewed)
    local class = kind(widget)
    local plain = class == 'PBZCommonLocText'
    if not plain and class ~= 'PBZCommonLocRichText' then return nil end
    if widget:GetVisibility() == 1 or widget:GetVisibility() == 2 then return nil end
    local text = asString(widget:GetText())
    local key = asString(widget.LocText.Key)
    local namespace = asString(widget.LocText.Namespace)
    if namespace ~= '' and namespace ~= 'Default' then return nil end
    local cacheKey = context .. '\0' .. key .. '\0' .. text
    local source = reviewed[cacheKey]
    if source == nil then
        local entry = lookup(context, key, text)
        local markup = text:find('[<>]') ~= nil
        local effects = markup and text:find('<Niagara id="Fire"/>', 1, true) ~= nil
        source = false
        if entry and (not markup or (allowMarkup and renderer.parse_rich_text(text, entry.segments, true, effects))) then
            for _, segment in ipairs(entry.segments) do
                if segment.reading then
                    source = {entry = entry, markup = markup, effects = effects}
                    break
                end
            end
        end
        if reviewed.count == 128 then
            for entryKey in pairs(reviewed) do reviewed[entryKey] = nil end
            reviewed.count = 0
        end
        reviewed[cacheKey] = source
        reviewed.count = reviewed.count + 1
    end
    if not source then return nil end
    local entry, markup, effects = source.entry, source.markup, source.effects
    local font = plain and widget.Font or widget.DefaultTextStyleOverride.Font
    if not valid(font.FontObject) or not name(font.FontObject):find('/Fonts/JP_', 1, true) then return nil end
    local rects
    if plain then
        local m = widget.Margin
        local d = widget:GetDesiredSize()
        if markup or widget.Justification ~= 0 or widget.MinDesiredWidth ~= 0
            or widget.TextTransformPolicy ~= 0 or widget.bSimpleTextMode
            or widget.ColorAndOpacity.ColorUseRule ~= 0 or widget.ColorAndOpacity.SpecifiedColor.A < .01
            or font.OutlineSettings.OutlineSize ~= 0 or widget.ShadowOffset.X ~= 0 or widget.ShadowOffset.Y ~= 0
            or m.Left ~= 0 or m.Top ~= 0 or m.Right ~= 0 or m.Bottom ~= 0 or d.X <= 0 or d.Y <= 0 then return nil end
        rects = {{x = 0, y = 0, width = d.X, height = d.Y}}
    else
        rects = renderer.rects(widget)
    end
    if #rects == 0 or #rects > 20 or (singleLine and #rects ~= 1) then return nil end
    local signature = {name(widget), text, key, name(font.FontObject), tostring(font.Size),
        tostring(font.LetterSpacing), tostring(widget.WrapTextAt), tostring(widget.LineHeightPercentage),
        tostring(widget.AutoWrapText), tostring(widget.Justification)}
    for _, rect in ipairs(rects) do
        signature[#signature + 1] = string.format('%.2f,%.2f,%.2f,%.2f', rect.x, rect.y, rect.width, rect.height)
    end
    return {widget = widget, entry = entry, text = text, markup = markup, effects = effects, rects = rects,
        plain = plain, font = font, color = plain and widget.ColorAndOpacity or nil,
        signature = table.concat(signature, '|')}
end

local function detach(layer, renderer, log)
    local complete = true
    local function attempt(fn)
        local ok, reason = pcall(fn)
        if not ok then
            complete = false
            log('detail_rows_cleanup_error ' .. tostring(reason))
        end
    end
    for i = #layer.parts, 1, -1 do
        local part = layer.parts[i]
        attempt(function()
            if part.handle then renderer.detach(part.handle); part.handle = nil end
            if part.applied and valid(part.owner) and valid(part.slot) then
                if valid(part.owner.Slot) and name(part.owner.Slot) == name(part.slot) then
                    local current = padding(part.slot)
                    if samePadding(current, part.applied) then part.slot:SetPadding(part.original) end
                end
                part.applied = nil
            end
        end)
    end
    attempt(function()
        if valid(layer.host) then layer.host:RemoveFromParent(); layer.host = nil end
        if valid(layer.column) then layer.column:ForceLayoutPrepass() end
    end)
    return complete
end

local function weaponSources(row)
    local title = row.TitleText
    local body = row.DescText
    assert(kind(title) == 'PBZCommonLocRichText' and kind(body) == 'PBZCommonLocRichText',
        'Unknown weapon row text fields')
    local titleBox = title:GetParent()
    local column = body:GetParent()
    assert(kind(titleBox) == 'SizeBox' and kind(column) == 'VerticalBox', 'Unknown weapon row layout')
    assert(name(titleBox:GetParent()) == name(column), 'Weapon title and description are in different columns')
    assert(name(column:GetChildAt(0)) == name(titleBox)
        and name(column:GetChildAt(1)) == name(body), 'Unexpected native weapon row children')
    return column, titleBox, title, body
end

local function advancedWeaponSources(row)
    local title, body = row.TitleText, row.DescText
    assert(kind(title) == 'PBZCommonLocRichText' and kind(body) == 'PBZCommonLocRichText',
        'Unknown advanced weapon text fields')
    local heading, column = title:GetParent(), body:GetParent()
    assert(kind(heading) == 'HorizontalBox' and kind(column) == 'VerticalBox'
        and name(heading:GetParent()) == name(column), 'Unknown advanced weapon row layout')
    assert(name(column:GetChildAt(0)) == name(heading)
        and name(column:GetChildAt(1)) == name(body), 'Unexpected advanced weapon row children')
    return column, heading, title, body
end

local function memorySources(row)
    local title, body = row.SpeakerText, row.ContentText
    assert(kind(title) == 'PBZCommonLocRichText' and kind(body) == 'PBZCommonLocRichText',
        'Unknown memory transcript text fields')
    local column = body:GetParent()
    assert(kind(column) == 'VerticalBox' and valid(title:GetParent())
        and name(title:GetParent()) == name(column), 'Unknown memory transcript row layout')
    local children, speakerSeen = column:GetChildrenCount(), false
    assert(children >= 2 and children <= 6, 'Unexpected memory transcript child count')
    for index = 0, children - 1 do
        local child = column:GetChildAt(index)
        if name(child) == name(title) then speakerSeen = true end
        if name(child) == name(body) then
            assert(speakerSeen, 'Memory speaker must precede its text')
            return column, title, title, body
        end
    end
    error('Memory content left its transcript row')
end

local function memoryLookup(readings)
    return function(context, key, text)
        local speaker = context == 'character'
        if speaker and not text:match(':$') then return nil end
        local entry = readings[speaker and text:sub(1, -2) or text]
        -- A few reviewed Character_* labels predate the optional context field.
        -- Accept them only on the native speaker field; the exact key/aliases
        -- below still guard against unrelated labels with the same text.
        local legacySpeaker = speaker and entry and entry.context == nil
            and type(entry.key) == 'string' and entry.key:match('^Character_')
        if not entry or (entry.context ~= context and not legacySpeaker) then return nil end
        if key ~= '' and key ~= entry.key then
            local matched = false
            for _, alias in ipairs(entry.keys or {}) do
                if alias == key then matched = true; break end
            end
            if not matched then return nil end
        end
        if not speaker then return entry end
        local segments = {}
        for index, part in ipairs(entry.segments) do segments[index] = part end
        segments[#segments + 1] = {text = ':'}
        return {key = entry.key, segments = segments}
    end
end

local function questSources(row)
    local title, body = row.QuestName, row.QuestDesc
    assert(kind(title) == 'PBZCommonLocText' and kind(body) == 'PBZCommonLocText',
        'Unknown quest details fields')
    local column = body:GetParent()
    assert(kind(column) == 'VerticalBox' and name(column):match('%.QuestDescBox$')
        and name(title:GetParent()) == name(column), 'Unknown quest details box')
    return column, title, title, body
end

local function abilitySources(row)
    local body = row.NodeDesc
    assert(kind(body) == 'PBZCommonLocRichText', 'Unknown ability description')
    local scroll = body:GetParent()
    assert(kind(scroll) == 'PBZScrollBoxBase' and name(scroll):match('%.PBZScrollBox_NodeDesc$')
        and scroll:GetClipping() == 1 and name(scroll:GetChildAt(0)) == name(body),
        'Unknown ability description scroll box')
    return scroll, nil, nil, body
end

local function abilityItemSources(row)
    local effect, flavor = row.NodeDesc_Item, row.NodeDesc_ItemFlavor
    assert(kind(effect) == 'PBZCommonLocRichText' and kind(flavor) == 'PBZCommonLocRichText',
        'Unknown ability material fields')
    local column = flavor:GetParent()
    assert(kind(column) == 'VerticalBox' and name(column):match('%.VerticalBox_ItemDesc$')
        and name(effect:GetParent()) == name(column), 'Unknown ability material column')
    assert(name(column:GetChildAt(0)) == name(effect) and name(column:GetChildAt(1)) == name(flavor)
        and column:GetChildrenCount() >= 2, 'Unexpected ability material field order')
    return column, effect, effect, flavor
end

local function abilityLookup(root, state, log)
    local entries = {}
    local data = assert(loadfile(root .. SCRIPT .. 'public16_readings.lua'))()
    local reviewed = data.entries
    for key, entry in pairs(data.ability_variants) do entries[key] = entry end
    for key, entry in pairs(reviewed) do
        if key:match('^UI_AbilityNode_') then entries[key] = entry end
    end
    local index = assert(loadfile(root .. SCRIPT .. 'surface_readings.lua'))().index(entries, true)
    local loader = state.release_readings or assert(loadfile(root .. SCRIPT .. 'readings_loader.lua'))()
    local items = loader.load('item_readings', root, log)
    local owned = assert(reviewed.UI_AbilityWidget_04)
    local totals = {}
    for _, suffix in ipairs({'05', '06', '07'}) do
        local total = assert(reviewed['UI_AbilityWidget_' .. suffix])
        totals[total.fingerprint] = total
    end
    return function(context, key, text)
        if context == 'item_body' then
            local entry = items[text]
            if entry and entry.context == context and (key == '' or key == entry.key) then return entry end
            return nil
        end
        local entry = index(context, key, text)
        if entry or key ~= '' then return entry end
        local label, count, separator, stat, increase = text:match(
            '^([^<>\r\n]+): (<Ability_Yellow>%d+</>)(\r?\n)([^<>]+) (<WeaponDes_Num_Green>%+%d+%%</>)$')
        if not label or #count > 30 or #increase > 36 then return nil end
        local ownedLabel = compact.match(owned, label)
        local total = compact.match(totals[compact.fingerprint(stat)], stat)
        if not ownedLabel or not total then return nil end
        local segments = {}
        for _, part in ipairs(ownedLabel.segments) do segments[#segments + 1] = part end
        segments[#segments + 1] = {text = ': ' .. count .. separator}
        for _, part in ipairs(total.segments) do segments[#segments + 1] = part end
        segments[#segments + 1] = {text = ' ' .. increase}
        return {key = owned.key .. '+' .. total.key, context = context, original = text, segments = segments}
    end
end

local function questLookup(lookup, chapterTitle)
    local function lookupTitle(key, text)
        local exact = lookup('quest_title', key, text)
        if exact then return exact end
        local title = compact.match(chapterTitle, text)
        if not title or key == '' then return title end
        for _, alias in ipairs(chapterTitle.aliases) do
            if alias == key then return title end
        end
    end
    local status = {["12:06a7224d27b000fd"]="かんりょう",["12:c986b4f78eb027de"]="しっぱい"}
    local noTracking = {["fingerprint"]="78:62a549b1dc64c9f1",["key"]="UI_Quest_15",["parts"]={{3,"いま"},{18},{6,"ついせき"},{18},{6,"じゆう"},{3},{6,"たんさく"},{18}},["plain"]=true}
    return function(context, key, text)
        if context == 'quest_title' then
            local exact = lookupTitle(key, text)
            if exact then return exact end
            local body, label = text:match('^(.*)（(.-)）$')
            local reading = label and status[compact.fingerprint('（' .. label .. '）')]
            local title = reading and lookupTitle(key, body)
            if not title then return nil end
            local parts = {}
            for index, segment in ipairs(title.segments) do parts[index] = segment end
            parts[#parts + 1] = {text = '（'}
            parts[#parts + 1] = {text = label, reading = reading}
            parts[#parts + 1] = {text = '）'}
            return {key = title.key, segments = parts}
        end
        local idle = (key == '' or key == noTracking.key) and compact.match(noTracking, text)
        if idle then return idle end
        local exact = lookup('quest_objective', key, text) or lookup('quest_detail', key, text)
            or lookup('quest_hint', key, text)
        if exact or key ~= '' or not text:find('；', 1, true) then return exact end
        -- The quest map joins the visible branch descriptions with this separator.
        local segments, keys = {}, {}
        local start = 1
        while true do
            local first, last = text:find('；', start, true)
            local part = lookup('quest_objective', '', text:sub(start, first and first - 1 or #text))
            if not part then return nil end
            keys[#keys + 1] = part.key
            for _, segment in ipairs(part.segments) do segments[#segments + 1] = segment end
            if not first then return {key = table.concat(keys, '+'), segments = segments} end
            segments[#segments + 1] = {text = '；'}
            start = last + 1
        end
    end
end

local function attach(layer, sources, state, renderer, geometryOfColumn, log)
    local column = layer.column
    local scroll = layer.scroll
    local oldHeight = column:GetDesiredSize().Y
    local scrollHostHeight
    if scroll then
        assert(column:GetChildrenCount() == 1, 'Ability scroll box has extra children')
    else
        assert(math.abs(oldHeight - geometryOfColumn.height) <= .75, 'Detail row is scaled or stretched')
    end
    for _, source in pairs(sources) do
        local owner = source.owner
        local relative = source.relative
        if scroll then
            local slot = owner.Slot
            local p = padding(slot)
            assert(kind(slot) == 'ScrollBoxSlot' and slot.HorizontalAlignment == 0 and slot.VerticalAlignment == 0
                and relative.x >= -.5 and relative.x + relative.width <= geometryOfColumn.width + 4.5
                and math.abs(relative.height - owner:GetDesiredSize().Y) <= .75,
                'Ability scroll text must fill its native slot')
            scrollHostHeight = relative.height + p.Bottom
            relative.y = 0
        else
            assert(kind(owner.Slot) == 'VerticalBoxSlot' and owner.Slot.Size.SizeRule == 0,
                'Detail row must use auto-sized text slots')
            assert(relative.y >= -.5 and relative.y + relative.height <= oldHeight + .75,
                'Text leaves its scrolling row')
        end
    end
    state.serial = (state.serial or 0) + 1
    local prefix = 'PBZFurigana_DetailRow_' .. state.serial .. '_'
    local host = make('SizeBox', column:GetOuter(), prefix .. 'Bounds')
    layer.host = host
    host:SetWidthOverride(0); host:SetHeightOverride(scrollHostHeight or 0); host:SetVisibility(3)
    local overlay = make('Overlay', column:GetOuter(), prefix .. 'Overlay')
    overlay:SetVisibility(3)
    local inside = host:AddChild(overlay)
    inside:SetHorizontalAlignment(0); inside:SetVerticalAlignment(0)
    local slot = scroll and column:AddChild(host) or column:AddChildToVerticalBox(host)
    slot:SetHorizontalAlignment(1); slot:SetVerticalAlignment(1)
    if scroll then
        -- Make the added child's allocated rect overlap the native text.
        -- A zero-height child after the text is culled by the ScrollBox.
        slot:SetHorizontalAlignment(0)
        slot:SetPadding({Left = 0, Top = -scrollHostHeight, Right = 0, Bottom = 0})
    else
        slot:SetSize({Value = 1, SizeRule = 0})
    end
    column:ForceLayoutPrepass()
    assert(math.abs(column:GetDesiredSize().Y - oldHeight) < .08, 'Detail overlay expanded the native row')

    local priorExtra = 0
    for i = 1, 2 do
        local source = sources[i]
        if source then
            local r = source.relative
            local reflow = layer.firstBody or i == 2
            local handle, stats = renderer.attach(source.widget, source.entry.segments, state, log, {
                sourceText = source.text, rects = source.rects, overlay = overlay, layoutRoot = column,
                originX = r.x, originY = r.y, availableWidth = r.width,
                preserveNativeLines = not reflow, reflow = reflow and not source.plain,
                richText = source.markup, weaponMarkup = source.markup, inlineEffects = source.effects,
                measureNativeRich = not source.plain,
                plainSource = source.plain, allowPlainReflow = source.plain and reflow,
                font = source.font, rubyColor = source.color,
                shadowX = source.plain and 0 or nil,
                keepReadingWords = true, requireAllReadings = true, protectSource = true,
                conditionalOpacityRestore = true,
                boundedHorizontal = true, justification = source.widget.Justification,
                clipLeft = -r.x, clipRight = geometryOfColumn.width - r.x,
            })
            if handle then
                local part = {handle = handle, owner = source.owner, slot = source.owner.Slot, source = source.widget,
                    nativeOpacity = not handle.reflow,
                    message = 'detail_rows_attached key=' .. source.entry.key .. ' lines=' .. #stats.lines ..
                        ' readings=' .. #stats.runs}
                layer.parts[#layer.parts + 1] = part
                local top = 0
                for _, run in ipairs(stats.runs) do
                    top = math.max(top, -run.y)
                    assert(r.x + run.x - run.width / 2 >= -.75 and
                        r.x + run.x + run.width / 2 <= geometryOfColumn.width + .75,
                        'Reading leaves its row horizontally')
                end
                local bottom = 0
                if stats.reflow then
                    local last = stats.lines[#stats.lines]
                    bottom = math.max(0, last.y + last.height - r.height)
                end
                part.original = padding(part.slot)
                part.applied = {Left = part.original.Left, Right = part.original.Right,
                    Top = part.original.Top + top, Bottom = part.original.Bottom + bottom}
                part.slot:SetPadding(part.applied)
                local bounds = StaticFindObject(handle.path)
                assert(valid(bounds), 'Reading bounds disappeared')
                bounds:SetRenderTranslation({X = 0, Y = priorExtra + top})
                priorExtra = priorExtra + top + bottom
            else
                log('detail_rows_deferred key=' .. source.entry.key .. ' ' .. tostring(stats.reason))
            end
        end
    end
    assert(#layer.parts > 0, 'No safe annotations in this row')
    if scroll then
        local height = scrollHostHeight + priorExtra
        host:SetHeightOverride(height)
        slot:SetPadding({Left = 0, Top = -height, Right = 0, Bottom = 0})
    end
    column:ForceLayoutPrepass()
    local newHeight = column:GetDesiredSize().Y
    assert(math.abs(newHeight - oldHeight - priorExtra) < .25, 'Detail row padding did not settle')
    if layer.maxHeight then
        assert(newHeight <= layer.maxHeight + .75, 'Quest details exceed the visible panel')
    end
    if not scroll then host:SetRenderTranslation({X = 0, Y = -newHeight}) end
    for _, part in ipairs(layer.parts) do log(part.message); part.message = nil end
end

function M.stop(state, log, root)
    state.detail_rows_active = false
    local renderer = assert(loadfile(root .. SCRIPT .. 'subtitle_ruby.lua'))()
    local complete = true
    for id, layer in pairs(state.detail_rows_layers or {}) do
        if detach(layer, renderer, log) then state.detail_rows_layers[id] = nil
        else complete = false end
    end
    return complete
end

function M.start(state, log, root)
    assert(M.stop(state, log, root), 'Prior detail row restoration is pending')
    local renderer = assert(loadfile(root .. SCRIPT .. 'subtitle_ruby.lua'))()
    local geometryModule = assert(loadfile(root .. SCRIPT .. 'geometry_service.lua'))()
    local geometry
    local classes
    if not state.weapon_and_advanced_lookup then
        local index = assert(loadfile(root .. SCRIPT .. 'surface_readings.lua'))()
        local data = assert(loadfile(root .. SCRIPT .. 'public11_readings.lua'))()
        local extra = assert(loadfile(root .. SCRIPT .. 'menu_coverage_readings.lua'))()
        for key, entry in pairs(extra.weapon) do data.entries[key] = entry end
        state.weapon_and_advanced_lookup = index.index(data.entries, true)
    end
    if not state.memory_transcript_lookup then
        local loader = state.release_readings or assert(loadfile(root .. SCRIPT .. 'readings_loader.lua'))()
        state.memory_transcript_lookup = memoryLookup(loader.load('prologue_readings', root, log))
    end
    if not state.quest_menu_lookup then
        local index = assert(loadfile(root .. SCRIPT .. 'surface_readings.lua'))()
        local data = assert(loadfile(root .. SCRIPT .. 'public19_readings.lua'))()
        state.quest_menu_lookup = index.index(data.entries)
    end
    state.ability_lookup = state.ability_lookup or abilityLookup(root, state, log)
    local questMenu = assert(loadfile(root .. SCRIPT .. 'quest_menu_ruby.lua'))()
    local questDetails = questLookup(state.quest_menu_lookup, questMenu.definitions.QuestName_Selected)
    local surfaces = {
        {class = 'W_WeaponNormalText_C', host = '.W_WeaponDetailList.', sources = weaponSources,
            lookup = state.weapon_and_advanced_lookup, title = 'skill_title', body = 'skill_body', markup = true},
        {class = 'W_WeaponAdvancdText_C', host = '.W_WeaponDetailList.', sources = advancedWeaponSources,
            lookup = state.weapon_and_advanced_lookup, title = 'skill_title', body = 'skill_body', markup = true},
        {class = 'W_MemoryFlowerEntry_C', host = '.WB_Literature.', sources = memorySources,
            lookup = state.memory_transcript_lookup, title = 'character', body = 'chapter_dialogue', markup = true},
        {class = 'W_DIsplayQuest_C', host = '.W_DIsplayQuest', sources = questSources,
            lookup = questDetails, title = 'quest_title', body = 'quest_objective', boundedPanel = true},
        {class = 'W_AbilityWidget_C', host = '.W_AbilityWidget_C_', sources = abilitySources,
            lookup = state.ability_lookup, body = 'ui_menu_text', markup = true, scroll = true},
        {class = 'W_AbilityWidget_C', host = '.W_AbilityWidget_C_', sources = abilityItemSources,
            lookup = state.ability_lookup, title = 'ui_menu_text', body = 'item_body',
            markup = true, firstBody = true},
    }
    for _, surface in ipairs(surfaces) do surface.reviewed = {count = 0} end
    state.detail_rows_layers = {}
    local layers = state.detail_rows_layers
    local waiting, rejected, lastError = {}, {}, {}
    state.detail_rows_active = true
    state.detail_rows_tick = function()
        local seen, candidates = {}, {}
        local built = false
        local function visit(surface, row)
            if state.scope_policy and not state.scope_policy.detail(state.scope,surface.class)then return end
            local id = valid(row) and name(row) or ''
            if not id:find('/Engine/Transient.', 1, true) or not id:find(surface.host, 1, true)
                or id:find('Default__', 1, true) then return end
            if surface.scroll then id = id .. ':description' end
            candidates[id] = true
            local ok, reason = pcall(function()
                classes = classes or {
                    widget = assert(StaticFindObject('/Script/UMG.Widget')),
                    activatable = assert(StaticFindObject('/Script/CommonUI.CommonActivatableWidget')),
                    switcher = assert(StaticFindObject('/Script/UMG.WidgetSwitcher')),
                    commonSwitcher = assert(StaticFindObject('/Script/CommonUI.CommonVisibilitySwitcher')),
                }
                if not visible(row, classes) then return end
                local column, titleBox, titleWidget, bodyWidget = surface.sources(row)
                if (surface.scroll or surface.firstBody) and not visible(column, classes) then return end
                local title = readSource(titleWidget, surface.title, surface.lookup, renderer,
                    surface.firstBody, not surface.firstBody, surface.reviewed)
                local body = readSource(bodyWidget, surface.body, surface.lookup, renderer, surface.markup, false, surface.reviewed)
                if state.scope_policy and state.scope and not state.scope.full_text and surface.class=='W_MemoryFlowerEntry_C'and not state.scope.books then
                    local mentions = body and state.character_mentions and state.character_mentions[body.text]
                    if mentions then body.entry = mentions; body.signature = body.signature .. '|character-mentions' else body=nil end
                end
                if not title and not body then return end
                seen[id] = true
                local signature = (title and title.signature or '') .. '\0' .. (body and body.signature or '')
                local layer = layers[id]
                if layer and (layer.failed or layer.signature ~= signature) then
                    if not detach(layer, renderer, log) then return end
                    layers[id] = nil
                    layer = nil
                end
                if layer then
                    for _, part in ipairs(layer.parts) do
                        if part.handle.reflow and part.source:GetRenderOpacity() ~= 0 then
                            layer.failed = true
                            if detach(layer, renderer, log) then layers[id] = nil; waiting[id] = nil end
                            return
                        elseif part.nativeOpacity then
                            local bounds = StaticFindObject(part.handle.path)
                            local opacity = part.source:GetRenderOpacity()
                            if valid(bounds) and bounds:GetRenderOpacity() ~= opacity then bounds:SetRenderOpacity(opacity) end
                        end
                    end
                    return
                end
                if rejected[id] == signature then return end
                if waiting[id] ~= signature then waiting[id] = signature; return end
                if built then return end
                if (title and title.widget:GetRenderOpacity() < .01)
                    or (body and body.widget:GetRenderOpacity() < .01) then return end
                geometry = geometry or geometryModule.new(root)
                local allocated, rect = pcall(geometry.read, column)
                if not allocated then return end
                if surface.boundedPanel or (surface.markup and not surface.scroll) then
                    -- The map may update wrapped desired size one frame before
                    -- the native overlay receives its new geometry.
                    column:ForceLayoutPrepass()
                    if math.abs(column:GetDesiredSize().Y - rect.height) > .75 then return end
                end
                local sources = {[1] = title, [2] = body}
                for _, source in pairs(sources) do
                    local measured, relative = pcall(function()
                        return geometry.relative(geometry.read(source.widget), rect)
                    end)
                    if not measured then return end
                    source.relative = relative
                end
                built = true
                if title then title.owner = titleBox end
                if body then body.owner = bodyWidget end
                layer = {column = column, parts = {}, signature = signature, failed = true,
                    firstBody = surface.firstBody, scroll = surface.scroll}
                if surface.boundedPanel then
                    local panel = geometry.read(column:GetParent())
                    local relative = geometry.relative(rect, panel)
                    layer.maxHeight = panel.height - relative.y
                end
                layers[id] = layer
                attach(layer, sources, state, renderer, rect, log)
                layer.failed = false
            end)
            if not ok then
                reason = tostring(reason)
                if lastError[id] ~= reason then log('detail_rows_deferred ' .. surface.class .. ' ' .. reason) end
                lastError[id] = reason
                rejected[id] = waiting[id]
                if layers[id] and detach(layers[id], renderer, log) then layers[id] = nil end
            end
        end
        local rowsByClass = {}
        for _, surface in ipairs(surfaces) do
            local rows = rowsByClass[surface.class]
            if not rows then
                rows = FindAllOf(surface.class) or {}
                rowsByClass[surface.class] = rows
            end
            for i, row in ipairs(rows) do
                if i > 256 then break end
                visit(surface, row)
            end
        end
        for id, layer in pairs(layers) do
            if not seen[id] and detach(layer, renderer, log) then layers[id] = nil end
        end
        for id in pairs(rejected) do if not seen[id] then rejected[id] = nil end end
        for id in pairs(waiting) do if not seen[id] then waiting[id] = nil end end
        for id in pairs(lastError) do if not candidates[id] then lastError[id] = nil end end
    end
    if not state.detail_rows_timer then
        LoopInGameThreadWithDelay(250, function()
            if state.detail_rows_active and state.detail_rows_tick then
                local ok, reason = pcall(state.detail_rows_tick)
                if not ok then log('detail_rows_tick_error ' .. tostring(reason)) end
            end
        end)
        state.detail_rows_timer = true
    end
end

return M
