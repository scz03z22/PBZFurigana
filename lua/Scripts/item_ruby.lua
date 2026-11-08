-- Item paragraph adapter for the verified native subtitle renderer.
-- Extra OverlaySlot padding participates in ScrollBox content sizing; source
-- FText/font/wrap remain untouched. No item assets or inventory data are changed.
local M={}
local function valid(o) return o and o:IsValid() end
local function path(o) return o:GetFullName():match('^[^ ]+ (.+)$') end
local function copyPadding(p) return {Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom} end
local function copySize(s) return {X=s.X,Y=s.Y} end
local function nearly(a,b) return math.abs(a-b)<.05 end
local function audit(w)
 return {text=w:GetText():ToString(),fontSize=w.DefaultTextStyleOverride.Font.Size,
  desired=copySize(w:GetDesiredSize()),opacity=w:GetRenderOpacity(),
  padding=copyPadding(w.Slot.Padding)}
end
local function describe(a)
 return 'text='..a.text..' font='..a.fontSize..' desired='..a.desired.X..','..a.desired.Y..
  ' opacity='..a.opacity..' padding='..a.padding.Left..','..a.padding.Top..','..a.padding.Right..','..a.padding.Bottom
end
local function refresh(w)
 local p=w
 for i=1,12 do
  if not valid(p) then break end
  p:ForceLayoutPrepass()
  local nextParent=p:GetParent()
  if not valid(nextParent) then
   -- A UUserWidget's root panel has no UWidget parent. Its owning UserWidget
   -- participates in the outer DynamicEntryBox and must also be invalidated.
   local tree=p:GetOuter()
   if valid(tree) and tree:GetClass():GetFName():ToString()=='WidgetTree' then
    local owner=tree:GetOuter()
    if valid(owner) and owner:GetFullName()~=p:GetFullName() then nextParent=owner end
   end
  end
  p=nextParent
 end
end

function M.detach(handle,log)
 if not handle then return true end
 if handle.kind=='item_dynamic_usage' and handle.dynamicRenderer then return handle.dynamicRenderer.detach(handle,log)end
 if handle.kind=='item_input_action' and handle.iconRenderer then return handle.iconRenderer.detach(handle,log)end
 if handle.kind=='item_style_markup' then
  if not handle.markupRenderer then return false,'Missing owned markup renderer' end
  return handle.markupRenderer.detach(handle,log)
 end
 if handle.kind=='item_input_action_v2' then
  if not handle.iconV2Renderer then return false,'Missing owned InputAction v2 renderer' end
  return handle.iconV2Renderer.detach(handle,log)
 end
 if handle.kind=='book_center' and handle.centerRenderer then return handle.centerRenderer.detach(handle,log)end
 log=log or function()end
 local errors={}
 if handle.inner then
  local ok,err=pcall(function()handle.renderer.detach(handle.inner)end)
  if not ok then errors[#errors+1]='renderer detach: '..tostring(err)end
 end
 local w=StaticFindObject(handle.sourcePath)
 if valid(w) then
  -- Restore each field independently so one failed operation cannot leave the
  -- source hidden or prevent padding restoration.
  local ok,err=pcall(function()w:SetRenderOpacity(handle.originalOpacity)end)
  if not ok then errors[#errors+1]='opacity restore: '..tostring(err)end
  ok,err=pcall(function()
   local slot=StaticFindObject(handle.slotPath)
   if valid(slot) then slot:SetPadding(copyPadding(handle.originalPadding))
   else error('original item OverlaySlot no longer valid')end
  end)
  if not ok then errors[#errors+1]='padding restore: '..tostring(err)end
  ok,err=pcall(function()refresh(w)end)
  if not ok then errors[#errors+1]='layout refresh: '..tostring(err)end
  local observed,after=pcall(function()return audit(w)end)
  if observed then
   handle.restoreAudit=after
   log('item_restore '..describe(after))
  else errors[#errors+1]='restore audit: '..tostring(after)end
 end
 if #errors>0 then log('item_restore_error '..table.concat(errors,'; '));return false,table.concat(errors,'; ')end
 return true,handle.restoreAudit
end

-- Returns handle,stats. Call M.detach(handle) before attaching again to the same
-- source. options are forwarded to the shared renderer except overlay/origin/
-- font/sourceText/rects/reflow, which this adapter resolves from the live widget.
function M.attach(w,segments,state,log,root,options)
 options=options or {};log=log or function()end
 -- The full native counter remains visible; this adapter only draws three
 -- prefix readings and reserves top padding. No generic rich-text reflow.
 if valid(w) and w:GetText():ToString():find(': <WeaponDes_Num_Green>',1,true) then
  local dynamicReadings=assert(loadfile(root..'Scripts/item_dynamic_readings.lua'))()
  if dynamicReadings.lookup(w:GetText():ToString()) then
   local dynamic=assert(loadfile(root..'Scripts/item_dynamic_ruby.lua'))()
   local handle,stats=dynamic.attach(w,segments,state,log,root,options)
   if handle then handle.dynamicRenderer=dynamic end
   return handle,stats
  end
 end
 if valid(w) and w:GetText():ToString():find('<InputAction ',1,true)then
  local icon=assert(loadfile(root..'Scripts/item_input_action_ruby.lua'))()
  if icon.matches(w:GetText():ToString())then
   local handle,stats=icon.attach(w,segments,state,log,root,options)
   if handle then handle.iconRenderer=icon end
   return handle,stats
  end
  local iconV2=assert(loadfile(root..'Scripts/item_input_action_v2_ruby.lua'))()
  if iconV2.matches(w:GetText():ToString())then
   local handle,stats=iconV2.attach(w,segments,state,log,root,options)
   if handle then handle.iconV2Renderer=iconV2 end
   return handle,stats
  end
 end
 if valid(w) and w:GetText():ToString():find('<Character_Yellow_Decorator2>',1,true)then
  local markup=assert(loadfile(root..'Scripts/item_markup_ruby.lua'))()
  if markup.matches(w:GetText():ToString())then
   local handle,stats=markup.attach(w,segments,state,log,root,options)
   if handle then handle.markupRenderer=markup end
   return handle,stats
  end
 end
 -- Alignment tags stay in the native book body while ruby is added above it.
 local alignment=valid(w) and w:GetText():ToString():match('^<([a-z]+)>')
 if alignment=='center' or alignment=='right' then
  local center=assert(loadfile(root..'Scripts/book_center_ruby.lua'))()
  if center.scoped(w)then
   local handle,stats=center.attach(w,segments,state,log,root,options)
   if handle then handle.centerRenderer=center end
   return handle,stats
  end
 end
 local handle;local stats
 local ok,err=pcall(function()
  assert(valid(w),'Invalid item paragraph')
  local overlay=w:GetParent()
  assert(valid(overlay) and overlay:GetClass():GetFName():ToString()=='Overlay','Item paragraph must be a direct Overlay child')
  local slot=w.Slot
  assert(valid(slot) and slot:GetClass():GetFName():ToString()=='OverlaySlot','Item paragraph requires an OverlaySlot')
  -- This adapter is deliberately limited to the observed left/fill layout.
  assert(slot.HorizontalAlignment==0 or slot.HorizontalAlignment==1,'Unsupported item paragraph horizontal alignment')
  local before=audit(w)
  assert(options.richText or not before.text:find('[<>]'),'Rich-text item paragraphs need run-aware rendering')
  local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
  local rects=renderer.rects(w)
  assert(#rects>0,'No item paragraph visual lines yet')
  handle={sourcePath=path(w),slotPath=path(slot),overlayPath=path(overlay),
   originalOpacity=before.opacity,originalPadding=before.padding,sourceBefore=before,renderer=renderer}
  local reserve=options.topReserve or math.ceil(before.fontSize*.95)
  local added=0
  local function setSpace()
   slot:SetPadding({Left=before.padding.Left,Top=before.padding.Top+reserve,
    Right=before.padding.Right,Bottom=before.padding.Bottom+added})
   refresh(w)
  end
  local function render()
   local args={};for key,value in pairs(options)do args[key]=value end
   args.overlay=overlay;args.originX=before.padding.Left;args.originY=before.padding.Top+reserve
   args.sourceText=before.text;args.font=w.DefaultTextStyleOverride.Font;args.rects=rects
   args.reflow=#rects>1;args.ratio=options.ratio or .6
   local inner,result=renderer.attach(w,segments,state,log,args)
   assert(inner,result and result.reason or 'Item renderer attach failed')
   handle.inner=inner;handle.path=inner.path;handle.canvasPath=inner.canvasPath
   stats=result
  end
  setSpace();render()
  local needed=0
  for _,run in ipairs(stats.runs or {})do
   if run.line==1 then needed=math.max(needed,run.height+(options.gap or 1))end
  end
  -- Usually the initial reserve is sufficient. If a font has unusually tall
  -- kana, rebuild once at the measured height rather than clipping its first row.
  if needed>reserve+.05 then
   renderer.detach(handle.inner);handle.inner=nil
   reserve=math.ceil(needed);setSpace();render()
  end
  added=math.max(0,stats.reflow and stats.reflow.addedHeight or 0)
  setSpace()
  local after=audit(w)
  assert(after.text==before.text,'Item source text changed while adding ruby')
  assert(after.fontSize==before.fontSize,'Item source font changed while adding ruby')
  assert(nearly(after.desired.X,before.desired.X) and nearly(after.desired.Y,before.desired.Y),'Item source desired size changed while adding ruby')
  stats.sourceBefore=before;stats.sourceAfter=after
  stats.sourceTextUnchanged=after.text==before.text
  stats.sourceFontUnchanged=after.fontSize==before.fontSize
  stats.sourceSizeUnchanged=nearly(after.desired.X,before.desired.X) and nearly(after.desired.Y,before.desired.Y)
  stats.topReserve=reserve;stats.firstRubyHeight=needed;stats.addedBottomPadding=added
  stats.overlayDesired=copySize(overlay:GetDesiredSize())
  handle.stats=stats;handle.sourceAfter=after
  log('item_before '..describe(before))
  log('item_after '..describe(after))
  log('item_space top='..reserve..' bottom='..added..' overlay='..stats.overlayDesired.X..','..stats.overlayDesired.Y)
 end)
 if not ok then
  if handle then M.detach(handle,log)end
  return nil,{reason=tostring(err),sourceBefore=handle and handle.sourceBefore}
 end
 return handle,stats
end
return M
