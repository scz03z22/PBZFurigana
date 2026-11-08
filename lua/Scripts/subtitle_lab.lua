-- Runtime subtitle diagnostics. All calls are made on the game thread.
local M={}
local function valid(o) return o and o:IsValid() end
local function str(o) if type(o)=='string' then return o end return o:ToString() end
local function safe(fn) local ok,v=pcall(fn);return ok and tostring(v) or ('ERR '..tostring(v)) end
local function path(o) return o:GetFullName():match('^[^ ]+ (.+)$') end
function M.stop(state,log,root)
 state.subtitle_active=false
 local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
 for _,layer in pairs(state.subtitle_layers or {}) do renderer.detach(layer.handle) end
 state.subtitle_layers={}
end
function M.start(state,log,root)
 local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
 local readings=state.release_readings.load('prologue_readings',root,log)
 local originModule=assert(loadfile(root..'Scripts/subtitle_origin.lua'))()
 local geometryService
 local widgetClass=assert(StaticFindObject('/Script/UMG.Widget'))
 local activatableClass=assert(StaticFindObject('/Script/CommonUI.CommonActivatableWidget'))
 local function origin(w)
  local parent=w:GetParent();local outer=valid(parent)and parent:GetParent()
  if valid(outer)and outer:GetClass():GetFName():ToString()=='SizeBox'and not geometryService then
   geometryService=assert(loadfile(root..'Scripts/geometry_service.lua'))().new(root)
  end
  return originModule.resolve(w,geometryService)
 end
 for _,layer in pairs(state.subtitle_layers or {}) do renderer.detach(layer.handle) end
 state.subtitle_layers={};state.subtitle_wait={}
 state.subtitle_active=true;state.ruby_enabled=true
 state.subtitle_tick=function()
  local seen={}
  local function shown(w)
   local layer=state.subtitle_layers[w:GetFullName()]
   local p=w
   for i=1,10 do
    if not valid(p)or not p:IsA(widgetClass) then break end
    local visibility=p:GetVisibility()
    local opacity=p:GetRenderOpacity()
    if p:GetFullName()==w:GetFullName() and layer and layer.handle and layer.handle.sourcePath then opacity=layer.handle.originalOpacity end
    if visibility==1 or visibility==2 or opacity<.01 then return false end
    p=p:GetParent()
   end
   local owner=w:GetOuter():GetOuter()
   if valid(owner)and owner:IsA(activatableClass)and not owner:IsActivated()then return false end
   return true
  end
  for _,w in ipairs(FindAllOf('PBZCommonLocRichText') or {}) do
   local full=w:GetFullName()
   if full:find('/Engine/Transient',1,true)and not full:find('Default__',1,true) and (full:find('FlowSubTitle',1,true) or full:find('FlowDialog',1,true)) and (full:find('.ContentRichText',1,true) or full:find('.SpeakerText',1,true))
    and (not state.scope_policy or state.scope_policy.subtitle(state.scope,full)) then
    local t=str(w:GetText())
    local visible=shown(w)
    seen[full]=true
    local entry=readings[t]
    if state.scope and not state.scope.full_text and state.scope.characters and not full:match('%.SpeakerText$') then
     entry=state.character_mentions and state.character_mentions[t]
    end
    -- A character-name entry is only valid in the speaker label, never a generic noun.
    if entry and entry.key:find('Character_',1,true) and not full:find('.SpeakerText',1,true) then entry=nil end
    local rects=visible and renderer.rects(w) or {}
    local overlay,x,y
    if visible and entry and #rects>0 then
     local ok,p,px,py=pcall(origin,w)
     if ok then overlay,x,y=p,px,py
     else
      state.subtitle_origin_errors=state.subtitle_origin_errors or{}
      local reason=tostring(p)
      if state.subtitle_origin_errors[full]~=reason then state.subtitle_origin_errors[full]=reason;log('subtitle_origin_pending '..full..' '..reason)end
     end
    end
    local font=w.DefaultTextStyleOverride.Font
    local signature=t..'|'..tostring(visible)..'|'..tostring(font.Size)..'|'..tostring(font.LetterSpacing)..'|'..str(font.TypefaceFontName)
    signature=signature..'|'..(valid(font.FontObject) and font.FontObject:GetFullName() or '')
    signature=signature..'|'..(x and string.format('%.2f,%.2f',x,y) or 'no-origin')
    for _,r in ipairs(rects) do signature=signature..string.format('|%.2f,%.2f,%.2f,%.2f',r.x,r.y,r.width,r.height) end
    local layer=state.subtitle_layers[full]
    if layer and layer.signature~=signature then renderer.detach(layer.handle);state.subtitle_layers[full]=nil;state.subtitle_wait[full]=nil;layer=nil end
    if not visible then state.subtitle_wait[full]=nil end
    if not layer and visible and entry and #rects>0 and valid(overlay) then
     local pending=state.subtitle_wait[full]
     if not pending or pending.signature~=signature then pending={signature=signature,ticks=0,attempts=0};state.subtitle_wait[full]=pending end
     pending.ticks=pending.ticks+1
     if pending.ticks>=3 then
      local handle,stats=renderer.attach(w,entry.segments,state,log,{sourceText=t,rects=rects,overlay=overlay,originX=x,originY=y,reflow=#rects>1,
        richText=true,keepReadingWords=true,requireAllReadings=true,protectSource=true,boundedHorizontal=true,justification=w.Justification})
      pending.attempts=pending.attempts+1;pending.ticks=0
      if handle or pending.attempts>=3 then state.subtitle_layers[full]={signature=signature,handle=handle,stats=stats} end
      log('subtitle_result key='..entry.key..' origin='..x..','..y..' '..(handle and 'attached' or tostring(stats.reason)))

     end
    end
    layer=state.subtitle_layers[full]
    if layer and layer.handle and valid(overlay) then
     local opacity=1;local p=w
     while valid(p) and p:GetFullName()~=overlay:GetFullName() do
      local value=p:GetRenderOpacity()
      if p:GetFullName()==w:GetFullName() and layer.handle.sourcePath then value=layer.handle.originalOpacity end
      opacity=opacity*value;p=p:GetParent()
     end
     local canvas=StaticFindObject(layer.handle.path)
     if valid(canvas) then canvas:SetRenderOpacity(opacity) end
    end
   end
  end
  for full,layer in pairs(state.subtitle_layers) do
   if not seen[full] then renderer.detach(layer.handle);state.subtitle_layers[full]=nil;state.subtitle_wait[full]=nil;log('subtitle_removed '..full) end
  end

 end
 if not state.subtitle_timer then
  state.subtitle_timer=true
  LoopInGameThreadWithDelay(150,function()
   if state.subtitle_active and state.subtitle_tick then
    local ok,err=pcall(state.subtitle_tick)
    if not ok and err~=state.subtitle_last_error then state.subtitle_last_error=err;log('subtitle_tick_error '..tostring(err)) end
   end
  end)
 end
 log('subtitle watcher active')
end
return M
