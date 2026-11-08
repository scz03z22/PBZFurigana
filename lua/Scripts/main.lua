-- UE4SS entry point for the standalone build.
local source = debug.getinfo(1, 'S').source
local path = source:sub(1, 1) == '@' and source:sub(2):gsub('\\', '/') or ''
local root = path:match('^(.*[/])[Ss]cripts/main%.lua$')
assert(root, 'PBZFurigana must be loaded from its Scripts/main.lua file')

local watchers = {
    {'subtitle', 'subtitle_lab'},
    {'item', 'item_lab'},
    {'book_dense', 'book_dense_ruby'},
    {'detail_rows', 'detail_rows_ruby'},
    {'map', 'map_lab'},
    {'general_rich', 'settings_ruby'},
    {'category', 'category_ruby'},
    {'tutorial', 'tutorial_ruby'},
    {'book_tab', 'book_tab_ruby'},
    {'quest_menu', 'quest_menu_ruby'},
    {'book_subhead', 'book_subhead_ruby'},
    {'menu_nav', 'menu_nav_ruby'},
    {'choice_labels', 'choice_labels_ruby'},
}
local state = {ruby_enabled = false}
local scopePolicy = assert(loadfile(root .. 'Scripts/scope_config.lua'))()
state.scope_policy = scopePolicy
local owners = {}
local nativeAdapters = {
    {id = 'loading', label = 'loading tip'},
    {id = 'video', label = 'video subtitle'},
}
local function report(message)
    print('[PBZFurigana] ' .. message .. '\n')
end

local preferencePath = root .. 'furigana.enabled'
local function readPreference()
    local file = io.open(preferencePath, 'rb')
    if not file then return false end
    local value = file:read(4)
    file:close()
    return value == 'on\n'
end

local function rememberPreference(enabled)
    if readPreference() == enabled then return end
    if enabled then
        local file, reason = io.open(preferencePath, 'wb')
        if not file then
            report('could not remember F6: ' .. tostring(reason))
            return
        end
        local wrote, writeError = file:write('on\n')
        local closed, closeError = file:close()
        if not wrote or not closed then
            os.remove(preferencePath)
            report('could not remember F6: ' .. tostring(writeError or closeError))
        end
    else
        local ok, reason = os.remove(preferencePath)
        if not ok then report('could not remember F6: ' .. tostring(reason)) end
    end
end

local function startNative(adapter, namesOnly)
    local stem = 'pbz_' .. adapter.id
    local dll = root .. 'native/' .. adapter.id .. '_bridge/build/' .. stem .. '_v1.dll'
    local disable, disableError = package.loadlib(dll, 'luaopen_' .. stem .. '_disable')
    assert(disable, disableError)
    local entry = namesOnly and 'luaopen_pbz_video_names_enable' or 'luaopen_' .. stem .. '_enable'
    local enable, enableError = package.loadlib(dll, entry)
    assert(enable, enableError)
    assert(enable() == 1, 'game or UE4SS build does not match')
    adapter.disable = disable
end

local function watcherLog(message)
    if message:find('_error', 1, true) or message:find('_watcher_stopped', 1, true)
        or message:find('subtitle_origin_pending', 1, true)
        or message:match('^book_dense_') or message:match('^detail_rows_') or message:match('^map_marker_result')
        or message:match('^general_rich_result') or message:match('^general_prose_result')
        or message:match('^choice_labels_result')
        or message:match('^bestiary_result')
        or message:match('^quest_menu_result') or message:match('^book_subhead_result')
        or message:match('^book_subhead_rejected.*memory') then
        report(message)
    end
end

local function stop()
    state.ruby_enabled = false
    for _, adapter in ipairs(nativeAdapters) do
        if adapter.disable then
            adapter.disable()
            adapter.disable = nil
        end
    end
    local complete = true
    for index = #watchers, 1, -1 do
        local module = owners[index]
        if module then
            local prefix = watchers[index][1]
            state[prefix .. '_active'] = false
            local ok, result = pcall(module.stop, state, watcherLog, root)
            if ok and result ~= false then
                owners[index] = nil
                state[prefix .. '_tick'] = nil
            else
                complete = false
                report(prefix .. ' cleanup failed: ' .. tostring(result))
            end
        end
    end
    return complete
end

local function start()
    local started = os.clock()
    state.scope = scopePolicy.read(root, report)
    if state.scope.characters and not state.scope.full_text and not state.character_mentions then
        state.character_mentions = assert(loadfile(root .. 'Scripts/character_mentions.lua'))()
    end
    if not state.release_readings then
        state.release_readings = assert(loadfile(root .. 'Scripts/readings_loader.lua'))()
    end
    local modules = {}
    local count = 0
    for index, watcher in ipairs(watchers) do
        if scopePolicy.watcher(state.scope, watcher[1]) then
            local module = assert(loadfile(root .. 'Scripts/' .. watcher[2] .. '.lua'))()
            assert(type(module.start) == 'function' and type(module.stop) == 'function', watcher[2])
            modules[index] = module
        end
    end
    for index = 1, #watchers do
        local module = modules[index]
        if module then
            -- A watcher can acquire resources before its start function returns.
            owners[index] = module
            assert(module.start(state, watcherLog, root) ~= false, watchers[index][2])
            count = count + 1
        end
    end
    state.ruby_enabled = true
    for _, adapter in ipairs(nativeAdapters) do
        local wanted = state.scope.full_text or (adapter.id == 'video' and state.scope.characters)
        if wanted then
            local ok, reason = pcall(startNative, adapter, not state.scope.full_text)
            if ok then
                report(adapter.label .. ' furigana ready')
            elseif not adapter.warned then
                adapter.warned = true
                report(adapter.label .. ' furigana unavailable: ' .. tostring(reason))
            end
        end
    end
    report(string.format('on (%d watchers, %.0f ms startup)', count, (os.clock() - started) * 1000))
end

local function startOrRollback()
    local ok, reason = pcall(start)
    if ok then return true end
    stop()
    report('startup failed: ' .. tostring(reason))
    return false
end

local poll, pollError = package.loadlib(root .. 'native/geometry_bridge/build/pbz_hotkeys_v1.dll', 'luaopen_pbz_hotkeys')
assert(poll, pollError)
local resumePending = readPreference()
state.scope = scopePolicy.read(root, report)
if resumePending then
    local retire
    if state.scope.full_text then
        local dll = root .. 'native/loading_bridge/build/pbz_loading_v1.dll'
        local enable, enableError = package.loadlib(dll, 'luaopen_pbz_startup_warning_enable')
        retire = package.loadlib(dll, 'luaopen_pbz_startup_warning_retire')
        local ok, result
        if enable and retire then ok, result = pcall(enable) end
        if ok and result == 1 then
            report('startup warning furigana ready')
        else
            retire = nil
            report('startup warning furigana unavailable: ' .. tostring(enableError or result))
        end
    end

    local helpersLoaded, helpers = pcall(require, 'UEHelpers')
    local attempts = 0
    local function restoreWhenReady()
        attempts = attempts + 1
        local world = helpersLoaded and helpers.GetWorld()
        local title = world and world:IsValid() and world:GetFullName():find('StartMenu', 1, true)
        if not title and attempts < 60 then
            ExecuteInGameThreadWithDelay(250, restoreWhenReady)
            return
        end
        resumePending = false
        if retire then
            ExecuteInGameThreadWithDelay(2000, function()
                if retire() == 1 then
                    report('startup warning hooks retired')
                else
                    report('startup warning hook retirement failed')
                end
            end)
        end
        if startOrRollback() then report('restored F6 setting') end
    end
    ExecuteInGameThreadWithDelay(250, restoreWhenReady)
end
local warned = false
local checkExistingLayers = false
LoopInGameThreadWithDelay(16, function()
    local bits = poll()
    if not bits then
        if not warned then report('hotkey bridge rejected this UE4SS build'); warned = true end
        return
    end
    if resumePending then return end
    if (bits & 1) ~= 0 then
        if state.ruby_enabled or next(owners) then
            if stop() then report('off') end
            rememberPreference(false)
            return
        end
        if startOrRollback() then rememberPreference(true) end
        return
    end
    checkExistingLayers = not checkExistingLayers
    if checkExistingLayers then
        if state.item_active and state.item_invalidate then state.item_invalidate() end
        if state.general_rich_active and state.general_rich_invalidate then state.general_rich_invalidate() end
    end
    local page = bits & 6
    if (page == 2 or page == 4) and state.book_dense_active and state.book_dense_turn then
        local ok, reason = pcall(state.book_dense_turn, page == 2 and -1 or 1)
        if not ok then report('book_dense_turn_error ' .. tostring(reason)) end
    end
end)
report('ready. F6 toggles furigana.')
