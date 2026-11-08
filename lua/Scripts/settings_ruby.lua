local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Settings explanations and exact labels in the system, equipment and load menus.
local M = {}
local SCRIPT = 'Scripts/'

local function loadField(path)
    local load = path:find('.WB_LoadGame_C_', 1, true) and path:find('.W_LoadGameSlot_C_', 1, true)
    local save = path:find('.WB_SaveGame_C_', 1, true) and path:find('.W_SaveGameSlot_C_', 1, true)
    if not load and not save then return end
    if path:match('%.BellName$') then return 'bell' end
    if path:match('%.DifficultyText$') then return 'difficulty' end
    if save and (path:match('%.NewGameDataText$') or path:match('%.NewGameDataText_1$')) then return 'new' end
end

local function bellName(path)
    return path:find('.W_BellMenu_C_', 1, true) and path:match('%.CurrentBellNameText$')
end

local function dayCounterLabel(path)
    return path:match('%.W_ChangeDaysLeft_MenuWidget_C_%d+%.WidgetTree_%d+%.LabelText$')
end

local function sequenceDateLabel(path)
    return path:match('%.WBP_FlowSequencer_UI_Text_C_%d+%.WidgetTree_%d+%.CustomText$')
end

-- These two frozen localization keys contain the same reviewed date. Keep the
-- alias here rather than changing the shared dialogue-reading records.
local sequenceDateAliases = {Dlg_BaiHe_IMPTMEM3_Date_1 = 'Dlg_XiMeng_IMPTMEM1_Date_1'}

local function abilityName(path)
    return path:find('.W_AbilityWidget_C_', 1, true) and path:match('%.NodeName$')
end

local function abilityCaption(path)
    return path:find('.W_AbilityWidget_C_', 1, true) and path:find('.W_LongPressButton.', 1, true)
        and path:match('%.PBZCommonLocRichText_0$')
end

local function titleButton(path)
    if not path:find('.WB_StartMenu_V2_C_', 1, true)
        and not path:find('.WB_DifficultySelect_V2_C_', 1, true) then return nil end
    return path:match('%.([%a]+)%.WidgetTree_%d+%.ButtonTextBlock$')
end

local function difficultyDescription(path)
    return path:find('.WB_DifficultySelect_V2_C_', 1, true) and path:match('%.Desc[1-4]$')
end

local function confirmation(path)
    return path:find('.W_ConfirmationDefault_C_', 1, true) or path:find('.W_ConfirmationError_C_', 1, true)
end

local function confirmationButton(path)
    return confirmation(path) and path:find('.W_MenuButton_V2_SelectedVersion_Decorator2_C_', 1, true)
        and path:match('%.ButtonTextBlock$')
end

local function confirmationProse(path)
    return confirmation(path) and (path:match('%.RichText_Description$') or path:match('%.RichText_Title$'))
end

local function entitlementField(path)
    local tree, field = path:match('^[^ ]+ (.+%.W_EntitlementNotify_C_%d+%.WidgetTree_%d+)%.(.+)$')
    if field == 'CategoryText' then return field, tree end
    if not field then return end
    if field:match('^W_MenuButton_V2_SelectedVersion_C_0%.WidgetTree_%d+%.ButtonTextBlock$') then
        return 'ButtonTextBlock', tree
    end
    local row = field:match('^W_W_EntitlementNotify_Entry_C_%d+%.WidgetTree_%d+%.(%a+)$')
    if row == 'NameText' or row == 'DescText' or row == 'EffectText' then return row, tree end
end

local function entitlementEntryParent(row, owner)
    if row:GetClass():GetFName():ToString() ~= 'W_W_EntitlementNotify_Entry_C'
        or owner:GetClass():GetFName():ToString() ~= 'W_EntitlementNotify_C' then return end
    -- DynamicEntryBox's live rows have an owning WidgetTree but no UPanelSlot.
    local box = owner.PBZDynamicEntryBox_71
    if not box or not box:IsValid() then return false end
    for _, ref in ipairs(box:GetAllEntries()) do
        local entry = ref:get()
        if entry and entry:IsValid() and entry:GetAddress() == row:GetAddress() then return box end
    end
    return false
end

local function titleSettings(path)
    return path:find('.W_SettingActivateableWidget_C_', 1, true)
end

local function settingsPanel(path)
    return path:find('.Settings_Panel.', 1, true)
        and (path:find('.Settings.', 1, true) or (titleSettings(path) and path:find('.W_SettingWidget.', 1, true)))
end

local function complexTutorialField(path)
    local variant, field = path:match('%.WB_HudTutorialComplex_(%w[%w_]+)_C_%d+%.WidgetTree_%d+%.(.+)$')
    if variant == 'OnlyBell' or variant == 'Tutorial_GameInputMode' then return field end
end

local function actionOwner(path)
    return path:find('.WB_LoadGame_C_', 1, true) or path:find('.WB_SaveGame_C_', 1, true)
        or path:find('.W_Systembase_C_', 1, true) or path:find('.W_AbilityWidget_C_', 1, true)
        or path:match('%.W_TeleportMap_C_%d+%.WidgetTree_%d+%.') or titleSettings(path)
        or path:match('%.W_pickupgear_C_%d+%.WidgetTree_%d+%.')
        or complexTutorialField(path)
end

local function actionLabel(path)
    return actionOwner(path) and path:find('.WB_TriggerBoundButton_C_', 1, true) and path:match('%.RichText$')
end

local MAP_COMPLETION_KEYS = {
    BellText = 'UI_Map_26',
    BellText_1 = 'UI_Map_27',
    BellText_2 = 'UI_Map_28',
    BellText_3 = 'UI_Map_29',
    BellText_4 = 'UI_Map_01',
    BellText_5 = 'UI_Map_02',
    BellText_6 = 'UI_Map_20',
}

local function mapChromeKey(path)
    local field = path:match('%.WB_MapNew%.WidgetTree_%d+%.(.+)$')
        or path:match('%.W_TeleportMap_C_%d+%.WidgetTree_%d+%.WB_MapNew_%d+%.WidgetTree_%d+%.(.+)$')
    if field == 'PercentageText' then return 'UI_Map_07' end
    if not field then return end
    if field:match('^WB_InputWidget%.WidgetTree_%d+%.RichText$') then return 'UI_Inventory_11' end
    return MAP_COMPLETION_KEYS[field:match('^W_MapItemCompletionUI%.WidgetTree_%d+%.([%w_]+)$')]
end

local function bestiaryLabel(path)
    if not path:find('.WB_Literature.', 1, true) then return end
    if path:match('%.W_ChapterRotator%.WidgetTree_%d+%.ChapterNameText$') then return 'region' end
    if path:match('%.W_UnifiedTextDescription%.WidgetTree_%d+%.ItemTypeText$') then return 'category' end
end

local EMPTY_MENU_OVERLAYS = {
    WB_Inventory = 'Overlay_373',
    WB_Literature = 'EmptyOverlay',
    W_DIsplayQuest = 'Overlay_373',
}

local function emptyMenuOverlay(path)
    local tail = path:match('%.W_Systembase_C_%d+%.WidgetTree_%d+%.(.+%.PBZCommonLocText_69)$')
    if not tail then return end
    if tail:match('^WB_CharacterV5%.WidgetTree_%d+%.WB_Character_V4%.WidgetTree_%d+%.PBZCommonLocText_69$') then
        return 'Overlay_60'
    end
    local screen = tail:match('^([%w_]+)%.WidgetTree_%d+%.PBZCommonLocText_69$')
    return EMPTY_MENU_OVERLAYS[screen]
end

local function chapterLabel(path)
    if path:match('%.WB_ChapterIntro_C_%d+%.WidgetTree_%d+%.Text$')
        or path:match('%.WB_Chapterend_C_%d+%.WidgetTree_%d+%.introtextlocal$') then return 'title' end
    if path:match('%.WB_Chapterend_C_%d+%.WidgetTree_%d+%.endtextlocal$') then return 'end' end
end

local function notificationField(path)
    if path:find('.W_TIpsLayer_C_', 1, true)
        and path:match('%.WB_TipsText_C_%d+%.WidgetTree_%d+%.ItemText$') then
        return 'toast'
    end
    if path:match('%.W_FrontEndHUDLayout_C_%d+%.WidgetTree_%d+%.PBZCommonLocRichText_0$') then return 'weapon' end
    if path:find('.W_FrontEndHUDLayout_C_', 1, true)
        and (path:match('%.W_WeaponUI%.WidgetTree_%d+%.WeaponText$')
            or path:match('%.W_WeaponUI%.WidgetTree_%d+%.BulletText$')) then
        return 'weapon'
    end
end

local HUD_QUEST_FIELDS = {
    QuestName = 'quest_title',
    QuestName_Right = 'quest_title',
    QuestTarget = 'quest_objective',
    QuestStateTarget_Right = 'quest_objective',
    QuestStateTarget = 'tutorial_hint',
    TutorialQuestName = 'tutorial_hint',
}

local function hudQuestField(path)
    local field = path:match('%.W_questupdate_C_%d+%.WidgetTree_%d+%.([%w_]+)$')
    if HUD_QUEST_FIELDS[field] then return field end
end

local function pickupLabel(path)
    return path:find('.W_TIpsLayer_C_', 1, true) and path:find('.WB_ItemTips.', 1, true)
        and path:match('%.WB_ItemText_C_%d+%.WidgetTree_%d+%.Text$')
end

local function pickupWeaponDescription(path)
    return path:match('%.W_pickupgear_C_%d+%.WidgetTree_%d+%.W_UnifiedTextDescription_Weapon%.WidgetTree_%d+%.(.+)$')
end

local function pickupEquipLabel(path)
    local field = path:match('%.W_pickupgear_C_%d+%.WidgetTree_%d+%.(%a+)$') or pickupWeaponDescription(path)
    return field == 'EquipTIp' or field == 'ReplaceItemTip'
end

local function pickupGearField(source, path)
    local field = path:match('%.W_pickupgear_C_%d+%.WidgetTree_%d+%.(%a+)$')
    if field ~= 'ItemTypeText' and field ~= 'ItemNameText' and field ~= 'ItemSubHeadText' then return end
    local category = source:GetOuter():GetOuter().ItemTypeText
    if category and category:IsValid() and compact.fingerprint(category:GetText():ToString()) == '6:bac2d064631c32f9' then
        local key = category.LocText.Key
        if type(key) ~= 'string' then key = key:ToString() end
        if key == 'UI_Literature_02' then return field, 'book' end
    end
    if field == 'ItemNameText' then return field, 'item' end
end

local function memoryProgress(path)
    return path:match('%.WB_Literature%.WidgetTree_%d+%.W_UnifiedTextDescription%.WidgetTree_%d+%.MemoryFlowerLineText$')
end

local function memoryProgressParts(text)
    return text:match('^(%(<MainCN>%d/%d</>%) )([^<>\r\n]+)( <DemoGreen>%+%d%d?%%</>)$')
end

local EQUIPMENT_LABELS = {
    Category_Weapon_First = 'UI_Character_01',
    Category_ShaChiWeapon_First = 'UI_Character_02',
    MainAttributeName = 'UI_WeaponSkill_1',
    SubAttributeName = 'UI_WeaponSkill_2',
    LineText = 'UI_Character_71',
}

local function weaponDescriptionLabel(weapon)
    if not weapon then return end
    if weapon == 'ItemTypeText' then return 'ItemTypeText' end
    local stat = weapon:match('^W_WeaponBuffText%.WidgetTree_%d+%.(%a+)$')
    if stat == 'MainAttributeName' or stat == 'SubAttributeName' then return stat end
end

local function equipmentLabel(path)
    local tail = path:match('%.WB_CharacterV5%.WidgetTree_%d+%.(.+)$')
    if not tail then return weaponDescriptionLabel(pickupWeaponDescription(path)) end
    if tail:match('^W_SecondTabLine%.WidgetTree_%d+%.LineText$') then return 'LineText' end
    tail = tail:match('^WB_Character_V4%.WidgetTree_%d+%.(.+)$')
    if not tail then return end
    if tail == 'Category_Weapon_First' or tail == 'Category_ShaChiWeapon_First' then return tail end
    if tail:match('^W_UnifiedTextDescription%.WidgetTree_%d+%.ItemTypeText$') then return 'AccessoryTypeText' end
    return weaponDescriptionLabel(tail:match('^W_UnifiedTextDescription_Weapon%.WidgetTree_%d+%.(.+)$'))
end

local function bossLabel(path)
    return path:match('%.WB_BossHPBar_C_%d+%.WidgetTree_%d+%.BossName$')
end

local function pickupParts(text)
    local base, count = text:match('^([^<>]+)( <Num_ItemText>%+ %d+</>)$')
    if not base then base, count = text:match('^([^<>]+)( <Num_ItemText> %-%d+</>)$') end
    if not base then base, count = text:match('^([^<>]+)( %(%d+/%d+%))$') end
    if not base and not text:find('[<>]') then return text end
    return base, count
end

local function reflowHudObjective(source)
    local field = hudQuestField(source:GetFullName())
    if field ~= 'QuestTarget' and field ~= 'QuestStateTarget_Right' then return false end
    local hud = source:GetOuter():GetOuter()
    if not hud:IsValid() or hud:GetClass():GetFName():ToString() ~= 'W_questupdate_C' then return false end
    -- Completion draws a stroke using the original line geometry.
    if field == 'QuestTarget' then
        return hud:IsAnimationPlaying(hud.Questshow) and not hud:IsAnimationPlaying(hud.QuestShowWithLIne)
    end
    return hud:IsAnimationPlaying(hud.RQuestShow) and not hud:IsAnimationPlaying(hud.RQuestShowWithLine)
end

local function forceGuide(path)
    return path:match('%.WB_hud_tutorial_ForceGuide_C_%d+%.WidgetTree_%d+%.PBZCommonLocRichText_0$')
end

local function complexTutorialLabel(path)
    local field = complexTutorialField(path)
    return (field == 'TutorialDesc' or field == 'PBZCommonLocRichText_0') and field or nil
end

local function smallTutorialLabel(path)
    return path:match('%.WB_hud_tutorial_C_%d+%.WidgetTree_%d+%.PBZCommonLocRichText_0$')
end

local function weaponTutorialCard(path)
    local field = path:match('%.W_TutorialWidget_ShuangDao_C_%d+%.WidgetTree_%d+%.PBZCommonLocRichText_([25])$')
    if field == '2' then return 'Tutorial_ChangeWeapon_1_2', '.Overlay_4' end
    if field == '5' then return 'Tutorial_ChangeWeapon_1_3', '.Overlay_7' end
end

local function tutorialLabel(source, path)
    path = path or source:GetFullName()
    if hudQuestField(path) == 'QuestStateTarget' or hudQuestField(path) == 'TutorialQuestName' then
        return true
    end
    if smallTutorialLabel(path) or forceGuide(path) or complexTutorialLabel(path) or weaponTutorialCard(path) then
        return true
    end
    if path:find('.W_FrontEndHUDLayout_C_', 1, true) then
        return path:match('%.W_TutorialBar_Hint_[%w_]+_C_%d+%.WidgetTree_%d+%.PBZCommonLocRichText$')
            and not path:find('.W_TutorialBar_Hint_Potion_C_', 1, true)
    end
    if not path:find('.W_questupdate_C_', 1, true) or not path:match('%.PBZCommonLocRichText_0$') then return end
    local owner = source:GetOuter():GetOuter()
    if owner and owner:IsValid() then
        local class = owner:GetClass():GetFName():ToString()
        return class == 'WB_TutorialTips_C' or class == 'WB_TutorialTips1_C'
    end
end

local function traceWithoutHold(entry)
    -- The game's input decorator shows this prefix only for the Generic pad. Keep
    -- it in the source FText and measure only the visible suffix.
    local prefixBytes = 32
    assert(compact.fingerprint(entry.original:sub(1, prefixBytes)) == '32:5193dab4b632b50e',
        'Unexpected trace tutorial prefix')
    local parts, remaining = {}, prefixBytes
    for _, part in ipairs(entry.segments) do
        if remaining <= 0 then
            parts[#parts + 1] = part
        elseif #part.text > remaining then
            assert(not part.reading, 'Trace prefix splits a reviewed reading')
            parts[#parts + 1] = {text = part.text:sub(remaining + 1)}
        end
        remaining = remaining - #part.text
    end
    return {key = entry.key, context = entry.context, original = entry.original,
        visible_source = entry.original:sub(prefixBytes + 1), segments = parts}
end

local function traceInputMode(widget)
    local library = StaticFindObject('/Script/Engine.Default__SubsystemBlueprintLibrary')
    local class = StaticFindObject('/Script/CommonInput.CommonInputSubsystem')
    if not library or not library:IsValid() or not class or not class:IsValid() then return end
    local input = library:GetLocalPlayerSubsystem(widget, class)
    if not input or not input:IsValid() then return end
    local mode = input:GetCurrentInputType()
    if mode == 0 then return 'without_hold' end
    if mode == 1 then
        return input:GetCurrentGamepadName():ToString() == 'Generic' and 'with_hold' or 'without_hold'
    end
end

local function captionParts(text)
    local open, value = text:match('^(<CharacterButton_%a+>)([^<>]+)</>$')
    if open == '<CharacterButton_White>' or open == '<CharacterButton_Yellow>' then return open, value end
end

local function settingsGroup(path)
    return settingsPanel(path)
        and path:match('%.W_SettingsListEntry_Collection_Category_C_%d+%.WidgetTree_%d+%.Text_SettingName$')
end

local function settingsLabel(path)
    if not settingsPanel(path) or not path:find('.W_SettingsListEntry_', 1, true) then return false end
    return path:match('%.Text_SettingName$') or
        (path:find('.Rotator_SettingValue.', 1, true) and path:match('%.MyText$'))
end

local function settingsRow(path)
    return path:match('^[^ ]+ (.+%.W_SettingsListEntry_[%w_]+_C_%d+)%.WidgetTree_%d+%.')
end

local function allowLabelClip(source, parent, clipping)
    local path = source:GetFullName()
    if complexTutorialLabel(path) == 'TutorialDesc' then
        local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
        return clipping == 1 and parent:GetFullName() == 'PBZScrollBoxBase ' .. tree .. '.PBZScrollBoxBase_58'
            and math.abs(parent:GetScrollOffset()) < .05 and parent:GetScrollOffsetOfEnd() < .05
    end
    -- The row overlay has space above the label. The native scroll panel
    -- still clips the whole row, including the added readings.
    return clipping == 1 and path:match('%.Text_SettingName$') and settingsLabel(path)
        and parent:GetFullName() == 'SizeBox ' .. path:match('^[^ ]+ (.+)%.Text_SettingName$') .. '.EntryHeightSB'
end

local function selectedLabelScale(source, font)
    local path = source:GetFullName()
    local field = loadField(path)
    if (field == 'bell' and font.Size == 240) or (field == 'difficulty' and font.Size == 144) then
        return .125
    end
    if field == 'new' and font.OutlineSettings.OutlineSize == 1 then
        if path:match('%.NewGameDataText$') and font.Size == 60 then return .5 end
        if path:match('%.NewGameDataText_1$') and font.Size == 72 then return .25 end
    end
    if not settingsLabel(path) or font.OutlineSettings.OutlineSize ~= 1 then return end
    -- The selected row's native style stores the font at four times the
    -- displayed size. The size pairs were measured on both native fields.
    if (path:match('%.Text_SettingName$') and font.Size == 78)
        or (path:match('%.MyText$') and font.Size == 72) then
        return .25
    end
end

local function addActionSources(pool)
    for _, host in ipairs(FindAllOf('WB_PBZTriggerBoundAction_C') or {}) do
        if host:IsValid() then
            local path = host:GetFullName()
            if actionOwner(path) and path:find('/Engine/Transient.', 1, true)
                and not path:find('Default__', 1, true) then
                local bar, safeZone = host.ActionBar, host.ActionBarSZ
                if bar and bar:IsValid() and safeZone and safeZone:IsValid()
                    and bar:GetVisibility() ~= 1 and bar:GetVisibility() ~= 2
                    and safeZone:GetVisibility() ~= 1 and safeZone:GetVisibility() ~= 2
                    and bar:GetRenderOpacity() >= .99 and safeZone:GetRenderOpacity() >= .99
                    and bar:GetNumEntries() > 0 and bar:GetNumEntries() <= 24 then
                    -- DynamicEntryBox keeps retired entries alive with stale
                    -- geometry. Only the native active pool is displayed.
                    for _, entry in ipairs(bar:GetAllEntries()) do
                        local button = entry:get()
                        if button and button:IsValid()
                            and button:GetClass():GetFName():ToString() == 'WB_TriggerBoundButton_C' then
                            local source = button.RichText
                            if source and source:IsValid() and actionLabel(source:GetFullName()) then
                                pool[#pool + 1] = source
                            end
                        end
                    end
                end
            end
        end
    end
end

local function addBossSources(pool)
    for _, hud in ipairs(FindAllOf('W_FrontEndHUDLayout_C') or {}) do
        if hud:IsValid() and hud:GetFullName():find('/Engine/Transient.', 1, true) and hud:IsActivated() then
            -- Retired boss bars keep their text and geometry in the widget pool.
            for _, ref in ipairs(hud:GetBossHPBarInstances() or {}) do
                local bar = ref:get()
                if bar and bar:IsValid() and bar:GetClass():GetFName():ToString() == 'WB_BossHPBar_C' then
                    local source = bar.BossName
                    if source and source:IsValid() and bossLabel(source:GetFullName()) then
                        pool[#pool + 1] = source
                    end
                end
            end
        end
    end
end

local function visibleSettingsRows()
    local displayed = {}
    for _, panel in ipairs(FindAllOf('W_PBZSettingPanel_C') or {}) do
        if panel:IsValid() then
            local path = panel:GetFullName()
            if path:find('/Engine/Transient.', 1, true) and settingsPanel(path .. '.') then
                local list = panel.ListView_Settings
                if list and list:IsValid() then
                    for _, ref in ipairs(list:GetDisplayedEntryWidgets() or {}) do
                        local row = ref:get()
                        if row and row:IsValid() then
                            displayed[row:GetFullName():match('^[^ ]+ (.+)$')] = true
                        end
                    end
                end
            end
        end
    end
    return displayed
end

local function questMapLabel(path)
    return path:match('%.W_DIsplayQuest%.WidgetTree_%d+%.MapText$') ~= nil
end

local questMapSetter = '/Script/ProjectPBZ.PBZCommonLocText:SetTextByLocKey'

local function watchQuestMapReplacement(state, log)
    if state.quest_map_hook or state.quest_map_hook_failed then return end
    local function afterSetText(context)
        if not state.general_rich_active or not state.ruby_enabled then return end
        local source = context:get()
        if not source or not source:IsValid() or source:GetFName():ToString() ~= 'MapText' then return end
        local path = source:GetFullName()
        local layer = state.general_rich_layers[path]
        if not layer or not questMapLabel(path) then return end
        local text = source:GetText()
        if type(text) ~= 'string' then text = text:ToString() end
        if text == layer.sourceText then return end
        local bounds = StaticFindObject(layer.handle.path)
        if bounds and bounds:IsValid() then
            -- Suppress the old reading before Slate can paint the replacement.
            bounds:SetRenderOpacity(0)
            layer.stats.inheritedOpacity = 0
        end
    end
    local ok, pre, post = pcall(RegisterHook, questMapSetter, function() end, function(context)
        local success, reason = pcall(afterSetText, context)
        if not success and state.quest_map_hook_error ~= reason then
            state.quest_map_hook_error = reason
            log('quest_map_setter_error ' .. tostring(reason))
        end
    end)
    if ok then
        state.quest_map_hook = {pre, post}
    else
        state.quest_map_hook_failed = true
        log('quest_map_setter_error ' .. tostring(pre))
    end
end

local function settingsEnumExtension(path)
    return path:match('^[^ ]+ ((.+%.Details_Settings%.WidgetTree_%d+)%.W_EnumOptionExtension_C_%d+)%.')
end

local function attachedEnumExtension(extensionPath, detailsTree, checks)
    local attached = checks[extensionPath]
    if attached ~= nil then return attached end
    -- The details widget keeps the old extension alive after removing it.
    -- Its UObject outer is unchanged. Only the current extension has a slot.
    local extension = StaticFindObject(extensionPath)
    local parent = extension and extension:IsValid() and extension:GetParent()
    attached = parent and parent:IsValid() and parent:GetFullName() == 'VerticalBox ' .. detailsTree .. '.Box_DetailsExtension'
    checks[extensionPath] = not not attached
    return attached
end

local function richSources()
    local pool = {}
    local checks = {}
    for _, widget in ipairs(FindAllOf('PBZCommonLocRichText') or {}) do
        if widget:IsValid() then
            local path = widget:GetFullName()
            if path:find('/Engine/Transient.', 1, true) and not path:find('PBZFurigana_', 1, true)
                and (abilityName(path) or abilityCaption(path) or confirmationProse(path)
                    or entitlementField(path)
                    or hudQuestField(path) or pickupLabel(path) or tutorialLabel(widget, path) or chapterLabel(path)
                    or notificationField(path) or memoryProgress(path) or pickupGearField(widget, path) or mapChromeKey(path)
                    or (settingsPanel(path) and path:find('.Details_Settings.', 1, true))) then
                local extension, detailsTree = settingsEnumExtension(path)
                if not extension or attachedEnumExtension(extension, detailsTree, checks) then
                    pool[#pool + 1] = widget
                end
            end
        end
    end
    return pool
end

local function plainSources()
    local pool = {}
    local displayedSettings = visibleSettingsRows()
    for _, widget in ipairs(FindAllOf('PBZCommonLocText') or {}) do
        if widget:IsValid() then
            local path = widget:GetFullName()
            if path:find('/Engine/Transient.', 1, true) and not path:find('PBZFurigana_', 1, true) then
                local slot = loadField(path)
                local bell = bellName(path)
                local button = titleButton(path) or confirmationButton(path) or difficultyDescription(path)
                local quest = hudQuestField(path)
                local chapter = chapterLabel(path)
                local emptyMenu = emptyMenuOverlay(path)
                local pickup = pickupGearField(widget, path)
                if slot or bell or dayCounterLabel(path) or sequenceDateLabel(path) or mapChromeKey(path) or button or quest or chapter
                    or emptyMenu or pickup or pickupEquipLabel(path) or entitlementField(path)
                    or (pickupWeaponDescription(path) and equipmentLabel(path)) then
                    pool[#pool + 1] = widget
                else
                    local equipment = path:find('.WB_CharacterV5.', 1, true)
                    local bestiary = bestiaryLabel(path)
                    local mapLabel = questMapLabel(path)
                    local row = settingsLabel(path) and settingsRow(path)
                    local displayedRow = row and displayedSettings[row]
                    if equipment or bestiary or mapLabel or displayedRow then
                        local key = widget.LocText.Key
                        if type(key) ~= 'string' then key = key:ToString() end
                        if (displayedRow and (key == '' or key:match('^UI_Setting_')))
                            or (equipment and (key:match('^UI_Character_0[1-4]$') or equipmentLabel(path)))
                            or (mapLabel and key:match('^Levelname_'))
                            or (bestiary == 'region' and (key:match('^Levelname_') or key == 'UI_LoadGame_08'))
                            or (bestiary == 'category' and key:match('^UI_Literature_')) then
                            pool[#pool + 1] = widget
                        end
                    end
                end
            end
        end
    end
    return pool
end

local function sourceScanner()
    local rich, plain = {}, {}
    local refreshRich = true
    return function()
        -- Enumerate one localization class per cycle. The previous class
        -- snapshot remains eligible and the adapter validates each live widget.
        if refreshRich then rich = richSources() else plain = plainSources() end
        refreshRich = not refreshRich
        local pool = {}
        for _, widget in ipairs(rich) do pool[#pool + 1] = widget end
        for _, widget in ipairs(plain) do pool[#pool + 1] = widget end
        addActionSources(pool)
        addBossSources(pool)
        return pool
    end
end

function M.start(state, log, root)
    local adapter = assert(loadfile(root .. SCRIPT .. 'general_rich_ruby.lua'))()
    state.settings_prose_adapter = adapter
    if not state.settings_prose_catalog then
        local index = assert(loadfile(root .. SCRIPT .. 'surface_readings.lua'))()
        local coverage = assert(loadfile(root .. SCRIPT .. 'menu_coverage_readings.lua'))()
        local entries = coverage.settings
        local actions = {}
        local notices = {toast = {}, weapon = {}}
        local memoryEntries = {}
        local emptyMenuEntry
        local equipmentEntries = {}
        local weaponTypes = {}
        local accessoryTypes = {}
        local mapChromeEntries = {}
        local pickupEquipEntries = {}
        for _, dataset in ipairs({'public14_readings', 'public15_readings'}) do
            local reviewed = assert(loadfile(root .. SCRIPT .. dataset .. '.lua'))().entries
            for key, entry in pairs(reviewed) do
                if not entries[key] and (key:match('^UI_Setting_') or key:match('^UI_Character_0[1-4]$')) then
                    entries[key] = entry
                end
                if key:match('^UI_Character_') or key:match('^UI_Quest_') or key:match('^UI_BellMenu_0[457]$')
                    or key == 'UI_Setting_38' or key == 'UI_Inventory_11' then
                    actions[key] = entry
                end
                if key:match('^UI_Weapon_0[1-5]$') then notices.weapon[key] = entry end
                if key == 'UI_BellMenu_16' then notices.toast[key] = entry end
                if key == 'UI_Character_41' then emptyMenuEntry = entry end
                if key:match('^UI_Pickup_0[6-8]$') then memoryEntries[entry.fingerprint] = entry end
                if key:match('^UI_Character_0[6-8]$') then weaponTypes[key] = entry end
                if key:match('^UI_Character_6[2-4]$') then accessoryTypes[key] = entry end
                if key == 'UI_Inventory_11' then mapChromeEntries[key] = entry end
                if key:match('^UI_Pickup_0[1-5]$') then pickupEquipEntries[key] = entry end
                if key:match('^UI_Character_0[12]$') or key == 'UI_Character_71' or key:match('^UI_WeaponSkill_[12]$') then
                    equipmentEntries[key] = entry
                end
            end
        end
        for key, entry in pairs({["SettingsDisplay_Difficulty"]={["context"]="ui_menu_text",["fingerprint"]="15:39a1fe48cb7e5aac",["key"]="SettingsDisplay_Difficulty",["parts"]={{9,"なんいど"},{6,"せんたく"}},["plain"]=true},["SettingsDisplay_Japanese"]={["context"]="ui_menu_text",["fingerprint"]="9:ee9ee2b5c854ef87",["key"]="SettingsDisplay_Japanese",["parts"]={{9,"にほんご"}},["plain"]=true}}) do entries[key] = entry end
        local lookup = index.index(entries)
        local weaponTypeLookup = index.index(weaponTypes)
        local accessoryTypeLookup = index.index(accessoryTypes)
        local mapLookup = index.index(coverage.map)
        local entitlementEntries = assert(loadfile(root .. SCRIPT .. 'public16_readings.lua'))().entries
        local entitlementAppearance = {
            Appearance_Name_3 = {key = 'Appearance_Name_3', fingerprint = '12:d74868178a0afbac',
                parts = {{6, 'ぶりん'}, {6, 'でんせつ'}}},
            Appearance_Name_4 = {key = 'Appearance_Name_4', fingerprint = '12:86b5dcc53dd9fc16',
                parts = {{6, 'きかい'}, {6, 'まく'}}},
            Appearance_Name_6 = {key = 'Appearance_Name_6', fingerprint = '6:cc2d904486173eff',
                parts = {{6, 'けいしょう'}}},
        }
        local abilityEntries = {}
        local captionEntries = {}
        local confirms = {}
        local difficultyEntries = {}
        local bestiaryCategories = {}
        local bookPickupCategory
        local dayCounterEntry
        local bestiaryPrologue
        local questDone
        local titleEntries = {Settings = entries.UI_Setting_01, Easy = entries.UI_Setting_05,
            Normal = entries.UI_Setting_06, Hard = entries.UI_Setting_11, Nightmare = entries.UI_SelectDifficutly_09}
        for key, entry in pairs(assert(loadfile(root .. SCRIPT .. 'public16_readings.lua'))().entries) do
            if key:match('^UI_AbilityName_') or key == 'UI_AbilityWidget_01' then
                abilityEntries[key] = entry
            end
            if key:match('^UI_AbilityWidget_') and compact.is_plain(entry) then
                captionEntries[key] = entry
            end
            if key:match('^UI_Confirmation_') or key:match('^UI_SaveGame_') or key:match('^UI_GameMenu_')
                or key == 'UI_SelectDifficutly_14' then
                confirms[key] = entry
            end
            if key:match('^UI_Confirmation_Code_') or key:match('^UI_AbilityWidget_') or key:match('^UI_SaveGame_') then
                if compact.is_plain(entry) then actions[key] = entry end
            end
            if key == 'UI_Map_05' or key == 'UI_Map_47' or key == 'UI_Map_49' then actions[key] = entry end
            if key:match('^UI_Map_2[06789]$') or key:match('^UI_Map_0[127]$') then mapChromeEntries[key] = entry end
            if key == 'UI_StartMenu_03' then titleEntries.QuitGame = entry end
            if key == 'UI_BonusCollection_01' then titleEntries.BonusCollection = entry end
            if key == 'UI_Quest_01' then questDone = entry end
            if key == 'UI_Literature_02' then bookPickupCategory = entry end
            if key == 'UI_Dead_08' then dayCounterEntry = entry end
            if key:match('^UI_SelectDifficutly_') then difficultyEntries[key] = entry end
            if key == 'UI_LoadGame_08' then bestiaryPrologue = entry end
            if key:match('^UI_OpenDoor_0[134]$') then notices.toast[key] = entry end
            if key:match('^UI_Literature_2[578]$') or key == 'UI_Literature_04' or key == 'UI_Literature_05'
                or key == 'UI_Ending_11' or key == 'UI_BonusCollection_Key_05' then
                actions[key] = entry
            elseif key == 'UI_Literature_29' or key:match('^UI_Literature_3[1-5]$') then
                bestiaryCategories[key] = entry
            end
        end
        local abilityLookup = index.index(abilityEntries)
        local captionLookup = index.index(captionEntries)
        local confirmLookup = index.index(confirms)
        local actionLookup = index.index(actions)
        local pickupEquipLookup = index.index(pickupEquipEntries)
        local difficultyLookup = index.index(difficultyEntries)
        local tutorialEntries = assert(loadfile(root .. SCRIPT .. 'public01_readings.lua'))().entries
        local tutorialLookup = index.index(tutorialEntries)
        local trace = tutorialEntries.Tutorial_Trace_1
        local questLookup = index.index(assert(loadfile(root .. SCRIPT .. 'public19_readings.lua'))().entries)
        local bossEntries = {}
        for key, entry in pairs(assert(loadfile(root .. SCRIPT .. 'public17_readings.lua'))().entries) do
            entry.context = 'hud_combatant'
            bossEntries[key] = entry
        end
        local bossLookup = index.index(bossEntries)
        local chapterTitle = assert(loadfile(root .. SCRIPT .. 'quest_menu_ruby.lua'))().definitions.QuestName_Selected
        local chapterEntries = {}
        for key, entry in pairs(assert(loadfile(root .. SCRIPT .. 'public22_readings.lua'))().entries) do
            if entry.context == 'chapter_title' then chapterEntries[key] = entry end
        end
        for _, key in ipairs(chapterTitle.aliases) do
            if key:match('^Chapter_') then
                chapterEntries[key] = {key = key, context = 'chapter_title', fingerprint = chapterTitle.fingerprint,
                    parts = chapterTitle.parts}
            end
        end
        local chapterLookup = index.index(chapterEntries)
        -- Reuse the subtitle loader's compact cache; do not duplicate its data.
        state.release_readings = state.release_readings or assert(loadfile(root .. SCRIPT .. 'readings_loader.lua'))()
        local sequenceDateReadings = state.release_readings.load('prologue_readings', root, log)
        for field, group in pairs(notices) do notices[field] = index.index(group) end
        local function resolveQuest(field, key, text)
            local context = HUD_QUEST_FIELDS[field]
            if context == 'quest_title' then
                local title = compact.match(chapterTitle, text)
                if title then
                    if key == '' then return title end
                    for _, alias in ipairs(chapterTitle.aliases) do
                        if key == alias then return title end
                    end
                end
                return questLookup(context, key, text)
            end
            if context == 'quest_objective' then
                local done = questDone and (key == '' or key == questDone.key) and compact.match(questDone, text)
                if done then return done end
                return questLookup(context, key, text) or questLookup('quest_detail', key, text)
                    or questLookup('quest_hint', key, text)
            end
            local entry = tutorialLookup(context, key, text)
            if entry or field ~= 'QuestStateTarget' then return entry end
            local base, count = text:match('^(.-)( %(%d+/%d+%))$')
            entry = base and tutorialLookup(context, key, base)
            if not entry then return nil end
            local segments = {}
            for _, part in ipairs(entry.segments) do segments[#segments + 1] = part end
            segments[#segments + 1] = {text = count}
            return {key = entry.key, context = context, segments = segments}
        end
        local loader = state.release_readings or assert(loadfile(root .. SCRIPT .. 'readings_loader.lua'))()
        local itemNames = loader.load('item_readings', root, log)
        local bestiaryRegions = state.release_readings and loader.load('bestiary_readings', root).regions or {}
        local function resolvePickup(key, text)
            local base, count = pickupParts(text)
            local item = base and itemNames[base]
            if not item or item.context ~= 'item_title' or (key ~= '' and key ~= item.key) then return nil end
            local segments = {}
            for _, part in ipairs(item.segments) do segments[#segments + 1] = part end
            if count then segments[#segments + 1] = {text = count} end
            return {key = item.key, context = 'hud_item_tip', segments = segments}
        end
        local difficultyPrefix = {["fingerprint"]="12:d2655b6554beefa3",["parts"]={{9,"なんいど"},{3}},["plain"]=true}
        local function resolveDifficulty(text)
            local prefix, value = text:match('^(.-：)(.+)$')
            local label = prefix and compact.match(difficultyPrefix, prefix)
            if not label then return nil end
            for _, key in ipairs({'UI_Setting_05', 'UI_Setting_06', 'UI_Setting_11', 'UI_SelectDifficutly_09'}) do
                local difficulty = compact.match(entries[key], value)
                if difficulty then
                    for _, part in ipairs(difficulty.segments) do label.segments[#label.segments + 1] = part end
                    return {key = key, original = text, context = 'ui_menu_text', segments = label.segments}
                end
            end
        end
        local function resolveUnfiltered(key, text, source)
            local path = source:GetFullName()
            local entitlement = entitlementField(path)
            if entitlement == 'ButtonTextBlock' then return compact.match(entries.UI_Setting_322, text) end
            if entitlement then
                if key:match('^UI_Entitlement_%d+$') then return compact.match(entitlementEntries[key], text) end
                if entitlement == 'DescText' then
                    local appearance = compact.match(entitlementAppearance[key], text)
                    if appearance then return appearance end
                end
                local item = itemNames[text]
                local context = entitlement == 'DescText' and 'item_title'
                    or entitlement == 'EffectText' and 'item_body'
                if context and item and item.key == key and item.context == context then return item end
                return nil
            end
            if pickupEquipLabel(path) then return pickupEquipLookup('ui_menu_text', key, text) end
            local pickupField, pickupKind = pickupGearField(source, path)
            if pickupField == 'ItemTypeText' then return compact.match(bookPickupCategory, text) end
            if pickupField then
                local entry = itemNames[text]
                if not entry or entry.context ~= 'item_title' then return nil end
                if pickupKind == 'book' then
                    if not entry.key:match('^Reading_') then return nil end
                elseif not entry.key:match('^Item_') or (key ~= '' and key ~= entry.key) then
                    return nil
                end
                return {key = entry.key, context = 'hud_item_tip', segments = entry.segments}
            end
            local equipment = equipmentLabel(path)
            if equipment == 'ItemTypeText' then return weaponTypeLookup('ui_menu_text', key, text) end
            if equipment == 'AccessoryTypeText' then return accessoryTypeLookup('ui_menu_text', key, text) end
            if equipment then
                local entry = equipmentEntries[EQUIPMENT_LABELS[equipment]]
                if entry and (key == '' or key == entry.key) then return compact.match(entry, text) end
                return nil
            end
            local field = loadField(path)
            if field == 'bell' or bellName(path) then return mapLookup('map_title', key, text) end
            local mapKey = mapChromeKey(path)
            if mapKey then
                if key == '' or key == mapKey then return compact.match(mapChromeEntries[mapKey], text) end
                return nil
            end
            if dayCounterLabel(path) then
                if key == '' or key == 'UI_Dead_08' then return compact.match(dayCounterEntry, text) end
                return nil
            end
            if field == 'difficulty' then return key == '' and resolveDifficulty(text) or nil end
            if field == 'new' then
                local id = path:match('%.NewGameDataText_1$') and 'UI_SaveGame_10' or 'UI_SaveGame_04'
                if key == '' or key == id then return confirmLookup('ui_menu_text', id, text) end
                return nil
            end
            if abilityName(path) then
                local entry = abilityLookup('ui_menu_text', key, text)
                if entry then return entry end
                entry = itemNames[text]
                if entry and entry.context == 'item_title' and (key == '' or key == entry.key) then
                    return {key = entry.key, context = 'ui_menu_text', segments = entry.segments}
                end
                return nil
            end
            if abilityCaption(path) then
                local open, label = captionParts(text)
                local entry = label and captionLookup('ui_menu_text', key, label)
                if not entry then return nil end
                local segments = {{text = open}}
                for _, part in ipairs(entry.segments) do segments[#segments + 1] = part end
                segments[#segments + 1] = {text = '</>'}
                return {key = entry.key, context = entry.context, segments = segments}
            end
            local title = titleButton(path)
            if title then
                local entry = titleEntries[title]
                if entry and (key == '' or key == entry.key) then return compact.match(entry, text) end
                return nil
            end
            if confirmationProse(path) then return confirmLookup('ui_menu_text', key, text) end
            if actionLabel(path) or confirmationButton(path) then return actionLookup('ui_menu_text', key, text) end
            if emptyMenuOverlay(path) then
                if key == '' or key == emptyMenuEntry.key then return compact.match(emptyMenuEntry, text) end
                return nil
            end
            local quest = hudQuestField(path)
            if quest then return resolveQuest(quest, key, text) end
            if pickupLabel(path) then return resolvePickup(key, text) end
            if memoryProgress(path) then
                local prefix, label, suffix = memoryProgressParts(text)
                local entry = label and compact.match(memoryEntries[compact.fingerprint(label)], label)
                if not entry or (key ~= '' and key ~= entry.key) then return nil end
                local segments = {{text = prefix}}
                for _, part in ipairs(entry.segments) do segments[#segments + 1] = part end
                segments[#segments + 1] = {text = suffix}
                return {key = entry.key, context = entry.context, segments = segments}
            end
            if bossLabel(path) then return bossLookup('hud_combatant', key, text) end
            if sequenceDateLabel(path) then
                local entry = sequenceDateReadings[text]
                if not entry then return nil end
                local dateKey
                for _, alias in ipairs(entry.keys or {entry.key}) do
                    if alias:match('^Dlg_.+_Date_%d+$') and (key == '' or (sequenceDateAliases[key] or key) == alias) then
                        dateKey = key ~= '' and key or alias; break
                    end
                end
                if not dateKey then return nil end
                return {key = dateKey, context = 'sequence_date', segments = entry.segments}
            end
            local notification = notificationField(path)
            if notification then return notices[notification]('ui_menu_text', key, text) end
            local chapter = chapterLabel(path)
            if chapter then
                local entry = chapterLookup('chapter_title', key, text)
                if entry and (entry.key == 'Chapter_End') == (chapter == 'end') then return entry end
                return nil
            end
            if questMapLabel(path) then return compact.match(bestiaryRegions[key], text) end
            local bestiary = bestiaryLabel(path)
            if bestiary then
                local entry = (bestiary == 'region' and bestiaryRegions or bestiaryCategories)[key]
                if bestiary == 'region' and key == 'UI_LoadGame_08' then entry = bestiaryPrologue end
                return compact.match(entry, text)
            end
            if tutorialLabel(source, path) then
                local weaponCard = weaponTutorialCard(path)
                if weaponCard then
                    if key == '' or key == weaponCard then return tutorialLookup('tutorial_hint', weaponCard, text) end
                    return nil
                end
                local guide = forceGuide(path) and (key == '' or key == trace.key) and compact.match(trace, text)
                if guide then
                    local mode = traceInputMode(source:GetOuter():GetOuter())
                    if mode == 'without_hold' then return traceWithoutHold(guide) end
                    if mode == 'with_hold' then return guide end
                    return nil
                end
                return tutorialLookup('tutorial_hint', key, text)
            end
            if difficultyDescription(path) then return difficultyLookup('ui_menu_text', key, text) end
            return lookup('ui_menu_text', key, text)
        end
        local function resolve(key, text, source)
            local entry = resolveUnfiltered(key, text, source)
            if entry and state.scope_policy and not state.scope_policy.general(state.scope, entry, source:GetFullName()) then return nil end
            return entry
        end
        state.settings_prose_catalog = {
            lookup = resolve,
            lookup_text = function(text, source) return resolve('', text, source) end,
            tree_parent = entitlementEntryParent,
            watch_source_text = function(source)
                local path = source:GetFullName()
                if questMapLabel(path) then
                    watchQuestMapReplacement(state, log)
                    return true
                end
                local extension, detailsTree = settingsEnumExtension(path)
                if extension then
                    return true, function(checks)
                        return attachedEnumExtension(extension, detailsTree, checks)
                    end
                end
                local row = settingsGroup(path) and settingsRow(path)
                if row then
                    return true, function(checks)
                        checks.settingsRows = checks.settingsRows or visibleSettingsRows()
                        return checks.settingsRows[row] == true
                    end
                end
                local field = equipmentLabel(path)
                return field == 'AccessoryTypeText' or field == 'ItemTypeText' or actionLabel(path)
                    or (field and pickupWeaponDescription(path))
                    or dayCounterLabel(path) or sequenceDateLabel(path) or mapChromeKey(path)
                    or smallTutorialLabel(path) or pickupEquipLabel(path) or entitlementField(path)
                    or (settingsPanel(path) and path:find('.Details_Settings.', 1, true))
            end,
            follow_source_opacity = function(source)
                local path = source:GetFullName()
                return dayCounterLabel(path) or sequenceDateLabel(path) or questMapLabel(path) or entitlementField(path)
            end,
            passive_visible = function(owner)
                if not owner:GetFullName():match('%.WB_hud_tutorial_C_%d+$') then return false end
                local parent = owner:GetParent()
                return owner:IsInViewport() or (parent and parent:IsValid())
            end,
            local_plain = true,
            allow_label_clip = allowLabelClip,
            selected_label_scale = selectedLabelScale,
            accept_wrapped_plain = function(source, font)
                local path = source:GetFullName()
                local equipment = equipmentLabel(path)
                local reviewed = (bestiaryLabel(path) == 'region' and source.WrapTextAt == 235 and font.Size == 24)
                    or (equipment and equipment:match('^Category_') and source.WrapTextAt == 120 and font.Size == 19.5)
                return reviewed
                    and source:GetDesiredSize().Y <= font.Size * 1.5
            end,
            accept_plain_outline = function(source, font)
                return chapterLabel(source:GetFullName()) == 'title'
                    and font.Size == 24 and font.OutlineSettings.OutlineSize == 2
            end,
            styled_label = function(source, text)
                local path = source:GetFullName()
                return (abilityCaption(path) and captionParts(text) ~= nil)
                    or (pickupLabel(path) and text:find('<Num_ItemText>', 1, true) and pickupParts(text) ~= nil)
                    or (memoryProgress(path) and memoryProgressParts(text) ~= nil)
            end,
            allow_two_styled_lines = function(source)
                return memoryProgress(source:GetFullName()) ~= nil
            end,
            interactive_label = function(source)
                local path = source:GetFullName()
                return actionLabel(path) or mapChromeKey(path) == 'UI_Inventory_11'
            end,
            native_tutorial = tutorialLabel,
            rich_layout_scale = function(source, font)
                -- These cards paint at a quarter of the native line metrics.
                if weaponTutorialCard(source:GetFullName()) and font.Size == 72
                    and font.OutlineSettings.OutlineSize == 1 then return .25 end
            end,
            preserve_lines = function(source)
                local path = source:GetFullName()
                return hudQuestField(path) ~= nil or pickupLabel(path) ~= nil or notificationField(path) ~= nil
                    or forceGuide(path) ~= nil or memoryProgress(path) ~= nil or complexTutorialLabel(path) ~= nil
                    or weaponTutorialCard(path) ~= nil or smallTutorialLabel(path) ~= nil
            end,
            reflow_in_place = function(source)
                local path = source:GetFullName()
                return complexTutorialLabel(path) == 'TutorialDesc' or smallTutorialLabel(path) or reflowHudObjective(source)
            end,
            compact_reflow = function(source)
                return smallTutorialLabel(source:GetFullName()) ~= nil
            end,
            native_color = function(source)
                local path = source:GetFullName()
                return hudQuestField(path) ~= nil or chapterLabel(path) ~= nil or notificationField(path) ~= nil
                    or forceGuide(path) ~= nil or weaponTutorialCard(path) ~= nil
            end,
            neighbor_is_current = function(source, checks)
                local extension, detailsTree = settingsEnumExtension(source:GetFullName())
                return not extension or attachedEnumExtension(extension, detailsTree, checks)
            end,
            use_neighbor_line_bounds = function(source, other)
                local path, otherPath = source:GetFullName(), other:GetFullName()
                local _, detailsTree = settingsEnumExtension(path)
                if detailsTree then
                    local _, otherTree = settingsEnumExtension(otherPath)
                    return detailsTree == otherTree
                end
                return chapterLabel(path) == 'end'
                    and otherPath:match('%.WB_Chapterend_C_%d+%.WidgetTree_%d+%.introtextlocal$')
                    and source:GetOuter():GetFullName() == other:GetOuter():GetFullName()
            end,
            ruby_gap = function(source)
                local path = source:GetFullName()
                if chapterLabel(path) == 'end' or notificationField(path) == 'weapon' and path:match('%.WeaponText$') then
                    return 0
                end
            end,
            plain_offset = function(source)
                if bossLabel(source:GetFullName()) then return 17 end
            end,
            plain_top_reserve = function(source, key)
                if key ~= 'Item_Accessory_FunctionDes_048'
                    or entitlementField(source:GetFullName()) ~= 'EffectText' then return end
                local textColumn = source:GetParent()
                local row = source:GetOuter():GetOuter()
                local reserve = 8
                -- The icon fixes the row height. Spend only the existing
                -- slack above its bottom-aligned text column.
                if row:GetDesiredSize().Y - textColumn:GetDesiredSize().Y >= reserve then return reserve end
            end,
            label_ratio = function(source)
                local path = source:GetFullName()
                if hudQuestField(path) then return .45 end
                if pickupLabel(path) then return .55 end
                if bossLabel(path) then return .52 end
                if chapterLabel(path) == 'end' then return .45 end
                if chapterLabel(path) then return .55 end
                if notificationField(path) == 'weapon' and path:match('%.WeaponText$') then return .45 end
                if notificationField(path) then return .5 end
                if memoryProgress(path) then return .5 end
                if smallTutorialLabel(path) then return .45 end
                if complexTutorialLabel(path) then return .5 end
                if weaponTutorialCard(path) then return .45 end
                local entitlement = entitlementField(path)
                if entitlement then return entitlement == 'CategoryText' and .5 or .43 end
                local pickup = pickupGearField(source, path)
                if pickup then return pickup == 'ItemNameText' and .34 or .45 end
                local equipment = equipmentLabel(path)
                if equipment == 'MainAttributeName' or equipment == 'SubAttributeName' then return .45 end
            end,
            placement_frame = function(source)
                local path = source:GetFullName()
                if complexTutorialLabel(path) == 'TutorialDesc' then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    -- The demo panel leaves a gap above this fixed-height text viewport.
                    return StaticFindObject(tree .. '.SizeBox_326'), 18
                end
                local equipment = equipmentLabel(path)
                if equipment == 'MainAttributeName' or equipment == 'SubAttributeName' then
                    return source:GetParent()
                end
                if confirmationButton(path) then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return StaticFindObject(tree .. '.HorizontalBox_0')
                end
                if settingsGroup(path) then
                    -- The row has no Overlay. Bound its sibling against the
                    -- visible list so recycled rows cannot draw over the footer.
                    local panel = path:match('^[^ ]+ (.+%.Settings_Panel)%.WidgetTree_%d+%.')
                    return StaticFindObject(panel).ListView_Settings
                end
                if memoryProgress(path) then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return StaticFindObject(tree .. '.PbzScrollBox')
                end
            end,
            accept_overlay = function(source, overlay)
                local path = source:GetFullName()
                local name = overlay:GetFullName()
                local entitlement, entitlementTree = entitlementField(path)
                if entitlement then return name == 'Overlay ' .. entitlementTree .. '.Overlay_1' end
                if mapChromeKey(path) == 'UI_Inventory_11' then
                    -- The R prompt sits four units below the top of its local Overlay.
                    return not name:match('%.WB_MapNew_?%d*%.WidgetTree_%d+%.Overlay_1$')
                end
                local _, cardOverlay = weaponTutorialCard(path)
                if cardOverlay then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. cardOverlay
                end
                if complexTutorialLabel(path) then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. '.Overlay_1'
                end
                if pickupGearField(source, path) then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. '.Overlay_19'
                end
                local equipment = equipmentLabel(path)
                if equipment then
                    if equipment == 'LineText' then
                        return name:match('%.WB_CharacterV5%.WidgetTree_%d+%.Overlay_0$')
                    end
                    if equipment == 'ItemTypeText' and pickupWeaponDescription(path) then
                        -- Its own Overlay starts exactly at the label's top.
                        -- Use the pickup panel's real frame for the space above it.
                        return name:match('%.W_pickupgear_C_%d+%.WidgetTree_%d+%.Overlay_19$') ~= nil
                    end
                    if equipment == 'ItemTypeText' or equipment == 'AccessoryTypeText' then
                        return name:match('%.WB_Character_V4%.WidgetTree_%d+%.Overlay_32$')
                    end
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    local host = equipment:match('^Category_') and '.Overlay_62' or '.Overlay_1'
                    return name == 'Overlay ' .. tree .. host
                end
                local quest = hudQuestField(path)
                if quest then
                    local host = (quest == 'QuestName' or quest == 'QuestTarget') and 'Overlay_7'
                        or (quest == 'QuestName_Right' or quest == 'QuestStateTarget_Right') and 'Overlay_1'
                        or 'Overlay_113'
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. '.' .. host
                end
                if pickupLabel(path) then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. '.Overlay_164'
                end
                if memoryProgress(path) then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. '.Overlay_1'
                end
                if bossLabel(path) then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. '.Overlay_35'
                end
                if chapterLabel(path) then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. '.Overlay_44'
                end
                if sequenceDateLabel(path) then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. '.Overlay_0'
                end
                if titleButton(path) then
                    return name:match('%.WB_StartMenu_V2_C_%d+%.WidgetTree_%d+%.Overlay_26$')
                        or name:match('%.WB_DifficultySelect_V2_C_%d+%.WidgetTree_%d+%.Overlay_61$')
                end
                if confirmationButton(path) then
                    return name:match('%.W_MenuButton_V2_SelectedVersion_Decorator2_C_%d+%.WidgetTree_%d+%.Overlay_0$')
                end
                if bestiaryLabel(path) == 'category' then
                    return name:match('%.WB_Literature%.WidgetTree_%d+%.Overlay_70$')
                end
                if settingsGroup(path) then
                    return name:match('%.WidgetTree_%d+%.Overlay_45$')
                end
                local emptyMenu = emptyMenuOverlay(path)
                if emptyMenu then
                    local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                    return name == 'Overlay ' .. tree .. '.' .. emptyMenu
                end
                if abilityCaption(path) then return name:match('%.W_AbilityWidget_C_%d+%.WidgetTree_%d+%.Overlay_0$') end
                if not abilityName(path) then return true end
                local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                return name == 'Overlay ' .. tree .. '.Overlay_0'
            end,
            plain_ratio = function(source)
                local path = source:GetFullName()
                local field = loadField(path)
                if field == 'bell' or field == 'new' or bellName(path) or dayCounterLabel(path) then return .5 end
                if sequenceDateLabel(path) then return .55 end
                if mapChromeKey(path) then return .45 end
                if settingsPanel(path) and path:find('.W_SettingsListEntry_Scalar_C_', 1, true) then return .52 end
            end,
            plain_host = function(source, overlay)
                local path = source:GetFullName()
                local field = loadField(path)
                local host = field == 'new' and '.Overlay_86' or field and '.Overlay_31'
                    or bellName(path) and '.Overlay_55' or dayCounterLabel(path) and '.Overlay_30'
                if not host then return true end
                local tree = source:GetOuter():GetFullName():match('^[^ ]+ (.+)$')
                return overlay:GetFullName() == 'Overlay ' .. tree .. host
            end,
        }
    end
    return adapter.start(state, log, root, {
        catalog = state.settings_prose_catalog,
        selectSources = sourceScanner(),
        interval = 125,
    })
end

function M.stop(state, log, root)
    if state.quest_map_hook then
        local ok, reason = pcall(UnregisterHook, questMapSetter, table.unpack(state.quest_map_hook))
        if ok then state.quest_map_hook = nil
        else log('quest_map_setter_cleanup_error ' .. tostring(reason)) end
    end
    state.quest_map_hook_failed = nil
    state.quest_map_hook_error = nil
    if state.settings_prose_adapter then return state.settings_prose_adapter.stop(state, log, root) end
    return true
end

return M
