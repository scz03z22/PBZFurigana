local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- The two foreground widgets of a native dialogue/bell button crossfade.
-- Keep their native text, layout and hit area intact, including during reuse.
local M = {}
local SCRIPTS = 'Scripts/'
local FIELDS = {'PBZCommonLocRichText_39', 'Selected'}

local function valid(object)
    return object and object:IsValid()
end

local function str(value)
    return type(value) == 'string' and value or value:ToString()
end

local function kind(object)
    return valid(object) and str(object:GetClass():GetFName()) or ''
end

local function path(object)
    return object:GetFullName():match('^[^ ]+ (.+)$')
end

local function parent(widget, widgetClass)
    local p = widget:GetParent()
    if valid(p) then return p end
    local tree = widget:GetOuter()
    if kind(tree) == 'WidgetTree' then
        local owner = tree:GetOuter()
        if valid(owner) and owner:IsA(widgetClass) then return owner end
    end
end

local function visibleOpacity(source, overlay, classes)
    local widget, alpha, belowOverlay = source, 1, true
    for _ = 1, 40 do
        if not valid(widget) then return not belowOverlay and alpha or nil end
        if widget:GetVisibility() == 1 or widget:GetVisibility() == 2 or widget:GetRenderOpacity() < .01 then return end
        if widget:IsA(classes.activatable) and not widget:IsActivated() then return end
        if path(widget) == path(overlay) then belowOverlay = false end
        if belowOverlay then
            if widget:GetClipping() ~= 0 then return end
            alpha = alpha * widget:GetRenderOpacity()
        end
        local p = parent(widget, classes.widget)
        if valid(p) and kind(p):find('Switcher', 1, true) then
            local active = p:GetActiveWidget()
            if not valid(active) or path(active) ~= path(widget) then return end
        end
        widget = p
    end
end

local function chooseReadings(domain, source, text, dialogue, bell)
    local namespace, key = str(source.LocText.Namespace), str(source.LocText.Key)
    if namespace ~= 'Default' and namespace ~= '' then return end
    if domain == 'bell' then return bell('ui_menu_text', key, text) end
    local entry = dialogue[text]
    if entry and entry.key:match('^Dlg_') and (key == '' or key == entry.key) then return entry end
    local fingerprint = compact.fingerprint(text)
    if fingerprint == '6:6420c6250ceb50a6' or fingerprint == '12:93771698611418dd' then return bell('ui_menu_text', key, text) end
end

local function candidate(button, field, domain, classes, geometry, renderer, dialogue, bell)
    local source = button[field]
    if kind(source) ~= 'PBZCommonLocRichText' then return end
    local overlay = button.Overlay_120
    if kind(overlay) ~= 'Overlay' or not path(overlay):find(path(button) .. '.', 1, true) then return end
    local alpha = visibleOpacity(source, overlay, classes)
    if not alpha then return end
    local text = str(source:GetText())
    if text == '' then return end
    local sourceGeometry, host = geometry.read(source), geometry.read(overlay)
    local c = {source = source, overlay = overlay, text = text, alpha = alpha,
        sourceGeometry = sourceGeometry, host = host, button = path(button), field = field}
    if text:find('[<>\r\n]') then return c end
    local entry = chooseReadings(domain, source, text, dialogue, bell)
    if not entry then return c end
    local style = source.DefaultTextStyleOverride
    local font, tint = style.Font, style.ColorAndOpacity.SpecifiedColor
    if not valid(font.FontObject) or not path(font.FontObject):find('/Fonts/JP_', 1, true) then return c end
    local rects = renderer.rects(source)
    if #rects ~= 1 then return c end
    local r = geometry.relative(sourceGeometry, host)
    local line = rects[1]
    local signature = table.concat({text, path(overlay), path(font.FontObject), font.Size, font.LetterSpacing,
        str(font.TypefaceFontName), font.OutlineSettings.OutlineSize,
        string.format('%.3f,%.3f,%.3f,%.3f', tint.R, tint.G, tint.B, tint.A),
        string.format('%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f',
            r.x, r.y, line.x, line.y, line.width, line.height, host.width, host.height)}, '|')
    c.entry, c.rects, c.rect, c.signature = entry, rects, r, signature
    return c
end

local function placementFits(c, runs, neighbors, geometry)
    local obstacles = {}
    for _, other in pairs(neighbors) do
        if other.button ~= c.button then
            local ok, rect = pcall(geometry.relative, other.sourceGeometry, c.host)
            if ok then obstacles[#obstacles + 1] = rect end
        end
    end
    for _, run in ipairs(runs) do
        local x, y = c.rect.x + run.x - run.width / 2, c.rect.y + run.y
        -- The label is vertically centered in the 40px button. Ruby can use
        -- the inter-row gap if the actual neighboring text leaves it clear.
        if x < -.5 or x + run.width > c.host.width + .5 or y < -16
            or (y < 0 and c.overlay:GetClipping() ~= 0) or y + run.height > c.host.height + .5 then
            return false, 'reading leaves button and its upper margin'
        end
        for _, b in ipairs(obstacles) do
            if x < b.x + b.width and x + run.width > b.x
                and y < b.y + b.height + 1 and y + run.height > b.y - 1 then
                return false, 'reading intersects a neighboring button'
            end
        end
    end
    return true
end

function M.stop(state)
    state.choice_labels_active = false
    state.choice_labels_tick = nil
    local renderer = state.choice_labels_renderer
    for _, layer in pairs(state.choice_labels_layers or {}) do renderer.detach(layer.handle) end
    state.choice_labels_layers = {}
end

function M.start(state, log, root)
    M.stop(state)
    local scripts = root .. SCRIPTS
    local renderer = assert(loadfile(scripts .. 'subtitle_ruby.lua'))()
    state.choice_labels_renderer = renderer
    local dialogue = state.release_readings.load('prologue_readings', root, log)
    if not state.choice_bell_lookup then
        local reviewed = assert(loadfile(scripts .. 'public14_readings.lua'))().entries
        local bell = {}
        for key, entry in pairs(reviewed) do
            if key:match('^UI_BellMenu_') then bell[key] = entry end
        end
        state.choice_bell_lookup = assert(loadfile(scripts .. 'surface_readings.lua'))().index(bell)
    end
    local classes = {widget = StaticFindObject('/Script/UMG.Widget'),
        activatable = StaticFindObject('/Script/CommonUI.CommonActivatableWidget')}
    local service = assert(loadfile(scripts .. 'geometry_service.lua'))()
    local geometry, rejected = nil, {}
    local layers = state.choice_labels_layers
    state.choice_labels_active = true
    state.choice_labels_tick = function()
        local candidates, order = {}, {}
        for _, button in ipairs(FindAllOf('W_DialogueButton_C') or {}) do
            if valid(button) then
                local p = path(button)
                local domain = p:find('.WBP_FlowDialog_C_', 1, true) and 'dialogue'
                    or p:find('.W_BellMenu', 1, true) and 'bell'
                if domain and p:find('/Engine/Transient.', 1, true) and not p:find('Default__', 1, true) then
                    for _, field in ipairs(FIELDS) do
                        local id = p .. '.' .. field
                        local ok, c = pcall(function()
                            geometry = geometry or service.new(root)
                            return candidate(button, field, domain, classes, geometry, renderer, dialogue, state.choice_bell_lookup)
                        end)
                        if ok and c then
                            candidates[id] = c
                            if c.entry then order[#order + 1] = id end
                        end
                    end
                end
            end
        end
        for id, layer in pairs(layers) do
            local c = candidates[id]
            local bounds = StaticFindObject(layer.handle.path)
            if not c or layer.signature ~= c.signature or not valid(bounds)
                or not placementFits(c, layer.runs, candidates, geometry) then
                renderer.detach(layer.handle); layers[id] = nil
            elseif layer.alpha ~= c.alpha then
                bounds:SetRenderOpacity(c.alpha); layer.alpha = c.alpha
            end
        end
        local builds = 0
        for _, id in ipairs(order) do
            if builds >= 2 then break end
            local c = candidates[id]
            if not layers[id] and rejected[id] ~= c.signature then
                builds = builds + 1
                local h, result = renderer.attach(c.source, c.entry.segments, state, log,
                    {sourceText = c.text, rects = c.rects, overlay = c.overlay, originX = c.rect.x,
                     originY = c.rect.y, ratio = .5, keepReadingWords = true, requireAllReadings = true,
                     protectSource = true, boundedHorizontal = true, justification = c.source.Justification})
                if h then
                    local fits, reason = placementFits(c, result.runs, candidates, geometry)
                    if not fits then renderer.detach(h); h = nil; result.reason = reason end
                end
                if h then
                    layers[id] = {handle = h, signature = c.signature, runs = result.runs}
                    local bounds = StaticFindObject(h.path)
                    if valid(bounds) then bounds:SetRenderOpacity(c.alpha); layers[id].alpha = c.alpha end
                else
                    rejected[id] = c.signature
                end
                log('choice_labels_result ' .. c.entry.key .. ' ' .. c.field .. ' ' .. (h and 'attached' or tostring(result.reason)))
            end
        end
        for id in pairs(rejected) do if not candidates[id] then rejected[id] = nil end end
    end
    if not state.choice_labels_timer then
        state.choice_labels_timer = true
        LoopInGameThreadWithDelay(150, function()
            if state.choice_labels_active and state.choice_labels_tick then
                local ok, reason = pcall(state.choice_labels_tick)
                if not ok then M.stop(state); log('choice_labels_watcher_stopped ' .. tostring(reason)) end
            end
        end)
    end
end

return M
