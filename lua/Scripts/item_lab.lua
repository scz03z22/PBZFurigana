-- Item annotation watcher and read-only diagnostics, run on the game thread.
local M={}
local function valid(o) return o and o:IsValid() end
local function str(v) if type(v)=='string' then return v end return v:ToString() end
local function safe(fn) local ok,v=pcall(fn);return ok and tostring(v) or ('ERR '..tostring(v)) end
local function path(o) return o:GetFullName():match('^[^ ]+ (.+)$') end
local function dynamic_item_surface(w)
 if not valid(w) then return false end
 local full=w:GetFullName()
 local inventory=full:find('.WB_Inventory.',1,true)
 local character=full:find('.WB_CharacterV5.',1,true) and full:find('.WB_Character_V4.',1,true)
 return (inventory or character) and full:find('.W_UnifiedTextDescription.',1,true)
  and full:find('.DetailText.',1,true) and full:find('.W_PBZItemDescText_C_',1,true)
  and full:match('%.PBZCommonLocRichText_34$')~=nil
end
local function entry_for(readings,text,isTitle,dynamic,w)
 local entry=readings[text]
 if entry and not isTitle and entry.paragraph_entry then return entry.paragraph_entry end
 if not entry and isTitle then
  local base,suffix=text:match('^(.+)(%+[12])$')
  local accessory=base and readings[base]
  if accessory and accessory.context=='item_title' and accessory.key:match('^Item_Accessory_%d%d%d$') then
   local segments={}
   for i,part in ipairs(accessory.segments)do segments[i]=part end
   segments[#segments+1]={text=suffix}
   return {key=accessory.key,context=accessory.context,segments=segments,original=text}
  end
 end
 -- Exact reviewed static entries keep priority. Only the proven medicine body
 -- may supplement a missing entry with the finite 0..99 native format.
 if not entry and not isTitle and dynamic and dynamic_item_surface(w) then return dynamic.lookup(text) end
 return entry
end
local function bestiary_entry(catalog,w,full,text,isTitle)
 if not catalog or not full:find('.WB_Literature.',1,true)
   or not full:find('.W_UnifiedTextDescription.',1,true)
   or not isTitle and not full:find('.DetailText.',1,true) then return nil end
 local entries=isTitle and catalog.titles or catalog.paragraphs
 local entry=entries[text]
 if not entry or str(w.LocText.Namespace)~='Default' then return nil end
 local key=str(w.LocText.Key)
 if (key=='' and not isTitle) or entry.keys[key] then return entry end
end
local function xy(v) return tostring(v.X)..','..tostring(v.Y) end
local function margin(v) return tostring(v.Left)..','..tostring(v.Top)..','..tostring(v.Right)..','..tostring(v.Bottom) end
local function transient(name)
 return name:find('/Engine/Transient',1,true) and not name:find('Default__',1,true)
end

local function owner_up(w)
 local p=w:GetParent()
 if valid(p) then return p end
 local tree=w:GetOuter()
 if valid(tree) and tree:GetClass():GetFName():ToString()=='WidgetTree' then
  local owner=tree:GetOuter()
  if valid(owner) then return owner end
 end
 return nil
end
local function visible(w,layer,sourceName)
 local p=w;local seen={}
 for i=1,45 do
  if not valid(p) then return true end
  local full=p:GetFullName()
  if seen[full] then return false,'ancestor_cycle',full end;seen[full]=true
  local v=p:GetVisibility();local opacity=p:GetRenderOpacity()
  if full==sourceName and layer and layer.handle then opacity=layer.originalOpacity end
  if v==1 or v==2 or not opacity or opacity<.01 then return false,'ancestor_hidden',full end
  local up=owner_up(p)
  if valid(up) then
   local cls=up:GetClass():GetFName():ToString()
   if cls=='WidgetSwitcher' or cls=='PBZCommonVisibilitySwitcher' or cls=='CommonVisibilitySwitcher' then
    local active=up:GetActiveWidget()
    if not valid(active) or active:GetFullName()~=full then return false,'inactive_switcher',up:GetFullName() end
   end
  end
  p=up
 end
 return false,'ancestor_limit',valid(p) and p:GetFullName() or ''
end
local function detail_owner(w)
 local p=w;local seen={}
 for _=1,45 do
  if not valid(p) then return nil end
  local full=p:GetFullName();if seen[full] then return nil end;seen[full]=true
  if p:GetClass():GetFName():ToString()=='W_UnifiedTextDescription_C' then return full end
  p=owner_up(p)
 end
end
function M.stop(state,log,root)
 state.item_active=false
 state.item_invalidate=nil
 local renderer=assert(loadfile(root..'Scripts/item_ruby.lua'))()
 -- Paragraph layout refreshes may rebuild title Slate widgets. Restore the
 -- captured title style last so F6 leaves the original Japanese font intact.
 for pass=1,2 do
  for _,layer in pairs(state.item_layers or {}) do
   local title=layer.handle and layer.handle.kind=='item_title'
   if (pass==2)==(not not title) then (layer.renderer or renderer).detach(layer.handle,log) end
  end
 end
 state.item_layers={};state.ruby_enabled=false
end
function M.start(state,log,root)
 local renderer=assert(loadfile(root..'Scripts/item_ruby.lua'))()
 local titleRenderer=assert(loadfile(root..'Scripts/item_title_ruby.lua'))()
 local native=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
 local readings=state.release_readings.load('item_readings',root,log)
 local bestiary=state.release_readings and state.release_readings.load('bestiary_readings',root)
 local dynamic=assert(loadfile(root..'Scripts/item_dynamic_readings.lua'))()
 M.stop(state,log,root)
 state.item_layers={};state.item_wait={};state.item_routes={};state.item_active=true;state.ruby_enabled=true
 local lookups={}
 local function invalidate()
  local changedOwners
  for _,layer in pairs(state.item_layers)do
   local source=layer.liveSource
   if source and layer.isTitle and (not valid(source) or str(source:GetText())~=layer.sourceText) then
    changedOwners=changedOwners or {}
    changedOwners[layer.detailOwner]=true
   end
  end
  -- Remove the previous description before refreshing its shared title row.
  -- A switched detail can still report the old text on recycled paragraph widgets.
  for pass=1,2 do
   for name,layer in pairs(state.item_layers)do
    local source=layer.liveSource
    if source and (pass==2)==layer.isTitle
     and ((changedOwners and changedOwners[layer.detailOwner])
      or (not layer.isTitle and (not valid(source) or str(source:GetText())~=layer.sourceText))) then
     if layer.renderer.detach(layer.handle,log)~=false then
      state.item_layers[name]=nil;state.item_wait[name]=nil
     end
    end
   end
  end
 end
 state.item_invalidate=function()
  if not next(state.item_layers) then return end
  local ok,err=pcall(invalidate)
  if not ok and state.item_error~=tostring(err) then
   state.item_error=tostring(err);log('item_invalidate_error '..tostring(err))
  end
 end
 state.item_tick=function()
  local seen={}
  local widgets=FindAllOf('PBZCommonLocRichText') or {}
  local waitingTitles, candidates, routes = {}, {}, {}
  state.item_routes=routes
  for _,w in ipairs(widgets) do
   if valid(w) then
    local full=w:GetFullName()
    local isTitle=full:find('W_UnifiedTextDescription',1,true) and full:match('%.ItemNameText$')
    local isParagraph=full:find('W_PBZItemDescText_C_',1,true) and full:find('.PBZCommonLocRichText_34',1,true)
    if (isTitle or isParagraph) and transient(full) then
     local layer=state.item_layers[full]
     local shown,hiddenReason,hiddenAt=visible(w,layer,full)
     local text,entry,bio,owner
     if shown then
      text=str(w:GetText())
      local cached=lookups[full]
      if not cached or cached.text~=text or full:find('.WB_Literature.',1,true) then
       bio=bestiary_entry(bestiary,w,full,text,isTitle)
       entry=bio or entry_for(readings,text,isTitle,dynamic,w)
       lookups[full]={text=text,entry=entry}
      else entry=cached.entry end
      if entry and state.scope_policy and not state.scope_policy.item(state.scope,entry,isTitle,bio~=nil)then entry=nil end
      owner=detail_owner(w)
      if isTitle and owner and entry and entry.context=='item_title'
       and not (layer and layer.key==entry.key) then
       waitingTitles[owner]=full
      end
     end
     candidates[#candidates+1]={widget=w,full=full,isTitle=isTitle,layer=layer,shown=shown,
      hiddenReason=hiddenReason,hiddenAt=hiddenAt,text=text,entry=entry,bio=bio,owner=owner}
    end
   end
  end
  for _,candidate in ipairs(candidates) do
    local w,full,isTitle,layer=candidate.widget,candidate.full,candidate.isTitle,candidate.layer
    local shown,hiddenReason,hiddenAt=candidate.shown,candidate.hiddenReason,candidate.hiddenAt
    local t,entry,bio,owner=candidate.text,candidate.entry,candidate.bio,candidate.owner
    local waitingTitle=owner and waitingTitles[owner]
    seen[full]=true
    if not shown then
     if layer then (layer.renderer or renderer).detach(layer.handle,log);state.item_layers[full]=nil end
     state.item_wait[full]=nil
     routes[full]={shown=false,hiddenReason=hiddenReason or '',hiddenAt=hiddenAt or '',status='hidden',
      nativeRectCount=0,isTitle=not not isTitle}
    else
    if entry and ((entry.context=='item_title')~=(not not isTitle)) then entry=nil end
    if not isTitle and state.book_dense_matches and state.book_dense_matches(t, full) then entry=nil end
    local selectedRenderer=isTitle and titleRenderer or renderer
    local rects=entry and native.rects(w) or {}
    local gate={key=entry and entry.key or '',owner=owner or '',shown=shown,hiddenReason=hiddenReason or '',hiddenAt=hiddenAt or '',
     waitingTitle=waitingTitle or '',nativeRectCount=#rects,isTitle=not not isTitle}
    routes[full]=gate
    gate.status=not shown and 'hidden' or not entry and 'unreviewed' or #rects==0 and 'no_native_rects'
     or not isTitle and waitingTitle and 'waiting_same_description_title' or layer and 'existing_layer' or 'settling'

    local font=w.DefaultTextStyleOverride.Font
    local sig=t..'|'..tostring(shown)..'|'..font.Size
    if isTitle then
     sig=sig..'|'..tostring(font.LetterSpacing)..'|'..str(font.TypefaceFontName)..'|'..(valid(font.FontObject) and font.FontObject:GetFullName() or '')
    end
    for _,v in ipairs(rects) do sig=sig..string.format('|%.2f,%.2f,%.2f,%.2f',v.x,v.y,v.width,v.height) end
    if layer and layer.signature~=sig then
     if isTitle then log('item_title_signature old='..layer.signature..' new='..sig) end
     (layer.renderer or renderer).detach(layer.handle,log);state.item_layers[full]=nil;state.item_wait[full]=nil;layer=nil
    end
    if not layer and shown and entry and #rects>0 and (isTitle or not waitingTitle) then
     local pending=state.item_wait[full]
     if not pending or pending.signature~=sig then pending={signature=sig,ticks=0,attempts=0};state.item_wait[full]=pending end
     pending.ticks=pending.ticks+1
     -- Preserve the native title style before paragraph prepasses rebuild the owner.
     if pending.ticks>=(isTitle and 3 or 4) then
      local originalOpacity=w:GetRenderOpacity()
      local options={rects=rects,itemKey=entry.key}
      -- Title geometry has no run-aware adapter yet. Its renderer rejects
      -- markup before mutations and records a bounded, visible fallback.
      -- Paragraphs reuse the native PBZ rich-copy path; unsupported tags/styles
      -- still fail closed and the item adapter restores padding and opacity.
      if not isTitle and t:find('[<>]')then options.richText=true end
      if options.richText and entry.key:match('^Item_Accessory_FunctionDes_') then
       options.inlineEffects=t:find('<Niagara id="Fire"/>',1,true)~=nil
       if options.inlineEffects or t:find('<img id="SpiritShadow" width="40"/>',1,true) then
        options.weaponMarkup=true
        options.measureNativeRich=true
       end
      end
      if entry.context=='book_body' or entry.context=='item_body' or options.richText then
       options.keepReadingWords=true;options.requireAllReadings=true
       options.boundedHorizontal=true;options.protectSource=true
      end
      local handle,stats=selectedRenderer.attach(w,entry.segments,state,log,root,options)
      pending.attempts=pending.attempts+1;pending.ticks=0
      if handle or pending.attempts>=3 then
       local record={signature=sig,handle=handle,stats=stats,originalOpacity=originalOpacity,key=entry.key,renderer=selectedRenderer}
       if handle and owner and (full:find('.WB_CharacterV5.',1,true) or full:find('.WB_Inventory.',1,true)) then
        record.liveSource=w;record.sourceText=t;record.detailOwner=owner;record.isTitle=not not isTitle
       end
       state.item_layers[full]=record
      end
      gate.status=handle and 'attached' or 'renderer_rejected';gate.reason=stats.reason or ''
      log('item_result key='..entry.key..' '..(handle and 'attached' or tostring(stats.reason)))
      if bio and (handle or pending.attempts>=3) then
       log('bestiary_result key='..bio.key..' '..(handle and ('attached runs='..#(stats.runs or {})) or tostring(stats.reason)))
      end
     end
    end
   end
  end
  for full in pairs(lookups) do if not seen[full] then lookups[full]=nil end end
  for full,layer in pairs(state.item_layers) do
   if not seen[full] then (layer.renderer or renderer).detach(layer.handle,log);state.item_layers[full]=nil;state.item_wait[full]=nil end
  end
 end
 if not state.item_timer then
  state.item_timer=true
  LoopInGameThreadWithDelay(150,function()
   if state.item_active and state.item_tick then
    local ok,err=pcall(state.item_tick)
    if not ok and state.item_error~=tostring(err) then state.item_error=tostring(err);log('item_tick_error '..tostring(err)) end
   end
  end)
 end
 log('item watcher active')
end

return M
