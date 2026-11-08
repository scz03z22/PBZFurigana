-- Paginate the reviewed dense paragraph inside its native scrolling book.
local M = {}
local SCRIPT = 'Scripts/'

local function valid(widget)
    return widget and widget:IsValid()
end

local function kind(widget)
    return valid(widget) and widget:GetClass():GetFName():ToString() or ''
end

local function path(widget)
    return valid(widget) and widget:GetFullName():match('^[^ ]+ (.+)$') or nil
end

local function text(value)
    return type(value) == 'string' and value or value:ToString()
end

local function parent(widget)
    local owner = widget:GetParent()
    if valid(owner) then return owner end
    local tree = widget:GetOuter()
    if kind(tree) == 'WidgetTree' then return tree:GetOuter() end
end

local function bookSurface(id)
    if id:match('%.W_pickupgear_C_%d+%.WidgetTree_%d+%.DetailText1%.') then return 'pickup' end
    if id:find('.WB_Literature.', 1, true) and id:find('.W_UnifiedTextDescription.', 1, true)
        and id:find('.DetailText.', 1, true) then return 'menu' end
end

local function visibleViewport(widget)
    local viewport
    for _ = 1, 40 do
        if not valid(widget) then return end
        local visibility = widget:GetVisibility()
        if visibility == 1 or visibility == 2 or widget:GetRenderOpacity() < .01 then return end
        local class = kind(widget)
        if class == 'PBZScrollBoxBase' and not viewport then viewport = widget end
        if class == 'W_Systembase_C' then
            return widget:IsActivated() and viewport or nil
        end
        if class == 'W_pickupgear_C' then
            return widget:IsActivated() and viewport and path(viewport):match('%.ScrollBox1$') and viewport or nil
        end
        local up = parent(widget)
        local upClass = kind(up)
        if upClass == 'WidgetSwitcher' or upClass == 'PBZCommonVisibilitySwitcher'
            or upClass == 'CommonVisibilitySwitcher' then
            if path(up:GetActiveWidget()) ~= path(widget) then return end
        end
        widget = up
    end
end

local function candidate(w, matches)
    local id = path(w)
    if id and id:find('/Engine/Transient.', 1, true) and bookSurface(id)
        and id:match('%.PBZCommonLocRichText_34$') and matches(text(w:GetText()))
        and w:GetVisibility() ~= 1 and w:GetVisibility() ~= 2 then
        local overlay = w:GetParent()
        if kind(overlay) ~= 'Overlay' or kind(w.Slot) ~= 'OverlaySlot' then return end
        local viewport = visibleViewport(overlay)
        if viewport then return id, overlay, viewport end
    end
end

local function detach(state, log)
    local handle = state.book_dense_handle
    if not handle then return true end
    local source = StaticFindObject(handle.source)
    if handle.hidden then
        local ok, reason = pcall(function()
            if valid(source) and path(source.Slot) == handle.slot and source:GetRenderOpacity() == 0 then
                source:SetRenderOpacity(handle.opacity)
            end
            handle.hidden = false
        end)
        if not ok then log('book_dense_cleanup_error ' .. tostring(reason)); return false end
    end
    local ok, reason = pcall(function()
        if valid(handle.bounds) then handle.bounds:RemoveFromParent() end
        if valid(source) and valid(source:GetParent()) then source:GetParent():ForceLayoutPrepass() end
    end)
    if not ok then log('book_dense_cleanup_error ' .. tostring(reason)); return false end
    state.book_dense_handle = nil
    return true
end

local function setPage(handle, index)
    if handle.current then
        for _, widget in ipairs(handle.pages[handle.current]) do widget:SetVisibility(2) end
    end
    for _, widget in ipairs(handle.pages[index]) do widget:SetVisibility(3) end
    handle.footer:SetText(FText('PgUp    ' .. index .. ' / ' .. #handle.pages .. '    PgDn'))
    handle.current = index
end

local function attach(w, overlay, viewport, case, state, inline, pager, renderer, geometry, log)
    local style = w.DefaultTextStyleOverride
    local font = style.Font
    local wrap = w.WrapTextAt
    local slot = w.Slot
    local pad = slot.Padding
    assert(valid(font.FontObject) and path(font.FontObject):find('/Fonts/JP_', 1, true)
        and font.Size == 18 and font.LetterSpacing == 0 and font.OutlineSettings.OutlineSize == 0,
        'Unsupported book body font')
    assert(not w.AutoWrapText and w.Justification == 0 and wrap > 200 and wrap <= 1024
        and slot.VerticalAlignment == 1 and (slot.HorizontalAlignment == 0 or slot.HorizontalAlignment == 1)
        and style.ShadowOffset.X == 0 and style.ShadowOffset.Y == 0, 'Unsupported book body layout')
    local before = w:GetDesiredSize()
    local rects = renderer.rects(w)
    assert(#rects > 1 and #rects <= 12, 'Book paragraph has not laid out')
    local viewportGeometry = geometry.read(viewport)
    local sourceGeometry = geometry.relative(geometry.read(overlay), viewportGeometry)
    assert(wrap + pad.Left + pad.Right <= sourceGeometry.width + .08
        and sourceGeometry.x + pad.Left >= -.08
        and sourceGeometry.x + pad.Left + wrap <= viewportGeometry.width + .08,
        'Book text exceeds its scrolling viewport')
    local available = viewportGeometry.height - pad.Top - pad.Bottom
    local rowGap = 0
    for i = 2, #rects do rowGap = math.max(rowGap, rects[i].y - rects[i-1].y - rects[i-1].height) end

    state.serial = (state.serial or 0) + 1
    local prefix = 'PBZFurigana_DenseBook_' .. state.serial .. '_'
    local handle = {source = path(w), slot = path(slot), wrap = wrap, opacity = w:GetRenderOpacity(), pages = {}}
    state.book_dense_handle = handle
    local function make(class, id)
        local widget = StaticConstructObject(StaticFindObject('/Script/UMG.' .. class), w:GetOuter(), FName(prefix .. id))
        assert(valid(widget), 'Cannot create book widget ' .. class)
        return widget
    end
    local bounds = make('SizeBox', 'Bounds')
    handle.bounds = bounds
    bounds:SetRenderOpacity(0)
    bounds:SetVisibility(3)
    bounds:SetWidthOverride(0)
    bounds:SetHeightOverride(0)
    local boxSlot = overlay:AddChildToOverlay(bounds)
    boxSlot:SetHorizontalAlignment(1)
    boxSlot:SetVerticalAlignment(1)
    local canvas = make('CanvasPanel', 'Canvas')
    canvas:SetVisibility(3)
    bounds:AddChild(canvas)
    local function addText(id, value, small, center)
        local widget = make('TextBlock', id)
        widget:SetVisibility(3)
        widget:SetAutoWrapText(false)
        widget:SetJustification(center and 1 or 0)
        widget:SetFont(font)
        if small then
            local rubyFont = widget.Font
            rubyFont.Size = font.Size * .6
            widget:SetFont(rubyFont)
        end
        widget:SetText(FText(value))
        widget:SetColorAndOpacity(style.ColorAndOpacity)
        widget:SetShadowOffset({X = 0, Y = 0})
        local childSlot = canvas:AddChildToCanvas(widget)
        childSlot:SetAutoSize(true)
        childSlot:SetAlignment({X = center and .5 or 0, Y = 0})
        childSlot:SetZOrder(small and 1 or 0)
        return widget, childSlot
    end
    local baseMeasure = addText('MeasureBody', case.text, false, false)
    local rubyMeasure = addText('MeasureRuby', case.segments[2].reading, true, true)
    local function metric(measure)
        local cache = {}
        return function(value)
            if cache[value] then return cache[value] end
            measure:SetText(FText(value))
            overlay:ForceLayoutPrepass()
            local size = measure:GetDesiredSize()
            local result = {width = size.X, height = size.Y}
            cache[value] = result
            return result
        end
    end
    local layout, err = inline.plan(case.text, case.segments, {
        base = metric(baseMeasure), ruby = metric(rubyMeasure),
    }, {width = wrap, rowGap = rowGap})
    assert(layout, err and err.reason or 'Dense layout failed')
    baseMeasure:RemoveFromParent()
    rubyMeasure:RemoveFromParent()

    local footer, footerSlot = addText('Footer', 'PgUp    16 / 16    PgDn', true, true)
    handle.footer = footer
    overlay:ForceLayoutPrepass()
    local footerSize = footer:GetDesiredSize()
    assert(footerSize.X > 0 and footerSize.X < wrap and footerSize.Y > 0, 'Book pager footer has invalid dimensions')
    local plan, failure = pager.split(layout, {
        height = available, footerHeight = footerSize.Y, footerGap = 8, maxRows = 3,
    })
    assert(plan, failure and failure.reason or 'Dense page layout failed')
    footerSlot:SetPosition({X = pad.Left + wrap / 2, Y = pad.Top + plan.pages[1].footerY})
    for i = 1, plan.pageCount do handle.pages[i] = {} end
    local checks = {}
    for _, unit in ipairs(plan.units) do
        local page = handle.pages[unit.page]
        if not unit.whitespace then
            local body, bodySlot = addText('Body' .. unit.id, unit.text, false, false)
            bodySlot:SetPosition({X = pad.Left + unit.bodyX, Y = pad.Top + unit.bodyY})
            page[#page + 1] = body
            checks[#checks + 1] = {widget = body, width = unit.baseWidth, height = unit.baseHeight}
        end
        if unit.reading then
            local ruby, rubySlot = addText('Ruby' .. unit.id, unit.reading, true, true)
            rubySlot:SetPosition({X = pad.Left + unit.rubyX, Y = pad.Top + unit.rubyY})
            page[#page + 1] = ruby
            checks[#checks + 1] = {widget = ruby, width = unit.rubyWidth, height = unit.rubyHeight}
        end
    end
    overlay:ForceLayoutPrepass()
    for _, check in ipairs(checks) do
        local size = check.widget:GetDesiredSize()
        assert(math.abs(size.X - check.width) < .08 and math.abs(size.Y - check.height) < .08,
            'Rendered book glyph differs from its measured size')
    end
    for i = 2, #handle.pages do
        for _, widget in ipairs(handle.pages[i]) do widget:SetVisibility(2) end
    end
    bounds:SetWidthOverride(pad.Left + wrap + pad.Right)
    bounds:SetHeightOverride(pad.Top + plan.height + pad.Bottom)
    setPage(handle, 1)
    overlay:ForceLayoutPrepass()
    local after = w:GetDesiredSize()
    assert(text(w:GetText()) == case.text and math.abs(before.X - after.X) < .08
        and math.abs(before.Y - after.Y) < .08, 'Native book paragraph changed')
    assert(overlay:GetDesiredSize().Y >= plan.height + pad.Top + pad.Bottom - .08,
        'Book layout did not reserve the page height')
    handle.hidden = true
    w:SetRenderOpacity(0)
    bounds:SetRenderOpacity(handle.opacity)
    log('book_dense_attached pages=' .. plan.pageCount .. ' readings=' .. #plan.runs)
end

function M.stop(state, log)
    state.book_dense_active = false
    state.book_dense_matches = nil
    state.book_dense_turn = nil
    return detach(state, log)
end

function M.start(state, log, root)
    assert(M.stop(state, log), 'Dense book cleanup is pending')
    local inline = assert(loadfile(root .. SCRIPT .. 'book_dense_inline_core.lua'))()
    local pager = assert(loadfile(root .. SCRIPT .. 'book_dense_paged.lua'))()
    local geometryModule = assert(loadfile(root .. SCRIPT .. 'geometry_service.lua'))()
    local renderer = assert(loadfile(root .. SCRIPT .. 'subtitle_ruby.lua'))()
    local geometry, waiting, rejected
    state.book_dense_matches = function(value, id)
        return bookSurface(id) and inline.matches(value)
    end
    state.book_dense_active = true
    state.book_dense_tick = function()
        local handle = state.book_dense_handle
        if handle then
            local source = StaticFindObject(handle.source)
            local _, overlay = candidate(source, inline.matches)
            if handle.hidden and overlay and source:GetRenderOpacity() == 0
                and path(source.Slot) == handle.slot and source.WrapTextAt == handle.wrap
                and valid(handle.bounds) and path(handle.bounds:GetParent()) == path(overlay) then return end
            if not detach(state, log) then return end
        end
        local source, id, overlay, viewport
        for _, row in ipairs(FindAllOf('W_PBZItemDescText_C') or {}) do
            local rowPath = path(row)
            if rowPath and bookSurface(rowPath) then
                local w = row.PBZCommonLocRichText_34
                local current, host, scroll = candidate(w, inline.matches)
                if current then source, id, overlay, viewport = w, current, host, scroll; break end
            end
        end
        if not id then waiting, rejected = nil, nil; return end
        if waiting ~= id then waiting, rejected = id, nil; return end
        if rejected == id then return end
        geometry = geometry or geometryModule.new(root)
        local case = inline.case(text(source:GetText()))
        local ok, reason = pcall(attach, source, overlay, viewport, case, state, inline, pager, renderer, geometry, log)
        if not ok then
            rejected = id
            detach(state, log)
            log('book_dense_layout_error ' .. tostring(reason))
        end
    end
    state.book_dense_turn = function(delta)
        local handle = state.book_dense_handle
        if not handle or not handle.hidden then return end
        local source = StaticFindObject(handle.source)
        if not candidate(source, inline.matches) or source:GetRenderOpacity() ~= 0 then return end
        local target = math.max(1, math.min(#handle.pages, handle.current + delta))
        if target ~= handle.current then
            local ok, reason = pcall(setPage, handle, target)
            if ok then
                log('book_dense_page ' .. target .. '/' .. #handle.pages)
            else
                detach(state, log)
                log('book_dense_turn_error ' .. tostring(reason))
            end
        end
    end
    if not state.book_dense_timer then
        LoopInGameThreadWithDelay(250, function()
            if not state.book_dense_active then return end
            local ok, reason = pcall(state.book_dense_tick)
            if not ok then
                log('book_dense_tick_error ' .. tostring(reason))
                M.stop(state, log)
            end
        end)
        state.book_dense_timer = true
    end
end

return M
