local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Opt-in ruby for the observed literature detail category only.
-- Native widgets are never reparented or restyled. The only mutation is a
-- zero-desired-size sibling, which is removed on failure, hiding, or stop.
local M={}
local DEFINITIONS={["UI_Map_20"]={["fingerprint"]="12:49fefd3ca602aabc",["parts"]={{6,"きおく"},{3},{3,"はな"}},["plain"]=true},["UI_Pickup_14"]={["fingerprint"]="6:bac2d064631c32f9",["parts"]={{6,"しょもつ"}},["plain"]=true},["UI_Pickup_15"]={["fingerprint"]="18:c93b01958a1936ab",["parts"]={{6,"きおく"},{3},{3,"はな"},{6}},["plain"]=true},["UI_Pickup_16"]={["fingerprint"]="21:4fba60e96c4fdb0f",["parts"]={{6,"かんぜん"},{3},{6,"きおく"},{3},{3,"はな"}},["plain"]=true}}
local PREFIX='PBZFurigana_Category_'
local function valid(o) return o and o:IsValid() end
local function class(o) return o:GetClass():GetFName():ToString() end
local function path(o) return o:GetFullName():match('^[^ ]+ (.+)$') end
local function str(v) if type(v)=='string' then return v end return v:ToString() end
local function near(a,b) return math.abs(a-b)<.05 end
local function size(v) return {X=v.X,Y=v.Y} end
local function margin(v) return {Left=v.Left,Top=v.Top,Right=v.Right,Bottom=v.Bottom} end
local function zero(v) return v.Left==0 and v.Top==0 and v.Right==0 and v.Bottom==0 end
local function color(v)
 local c=v.SpecifiedColor
 return {R=c.R,G=c.G,B=c.B,A=c.A,rule=v.ColorUseRule}
end
local function transform(w)
 local t=w.RenderTransform
 return {x=t.Translation.X,y=t.Translation.Y,sx=t.Scale.X,sy=t.Scale.Y,
  hx=t.Shear.X,hy=t.Shear.Y,angle=t.Angle}
end
local function identity(t)
 return t.x==0 and t.y==0 and t.sx==1 and t.sy==1 and t.hx==0 and t.hy==0 and t.angle==0
end
local function parent(w)
 local p=w:GetParent()
 if not valid(p) then
  local tree=w:GetOuter()
  if valid(tree) and class(tree)=='WidgetTree' then
   local owner=tree:GetOuter()
   if valid(owner) and path(owner)~=path(w) then p=owner end
  end
 end
 return p
end
local function visible(w)
 local p=w
 for _=1,40 do
  if not valid(p) then return true end
  local v=p:GetVisibility()
  if v==1 or v==2 or p:GetRenderOpacity()<.01 then return false end
  local nextParent=parent(p)
  if valid(nextParent) then
   local c=class(nextParent)
   if c=='WidgetSwitcher' or c=='CommonVisibilitySwitcher' or c=='PBZCommonVisibilitySwitcher' then
    local active=nextParent:GetActiveWidget()
    if not valid(active) or path(active)~=path(p) then return false end
   end
  end
  p=nextParent
 end
 return false -- An unresolved/cyclic ancestry is not proof of visibility.
end
local function refresh(w)
 local p=w
 for _=1,30 do
  if not valid(p) then return end
  p:ForceLayoutPrepass();p=parent(p)
 end
end
local function scoped(w)
 if not valid(w) or class(w)~='PBZCommonLocText' then return false end
 local name=w:GetFullName()
 return name:find('/Engine/Transient',1,true) and not name:find('Default__',1,true)
  and name:find('.WB_Literature.',1,true) and name:find('.W_UnifiedTextDescription.',1,true)
  and name:match('%.ItemTypeText$')~=nil
end
local function eligible(w)
 if not scoped(w) or str(w.LocText.Namespace)~='Default' then return nil end
 local entry=DEFINITIONS[str(w.LocText.Key)]
 return compact.match(entry,str(w:GetText()))
end
local function node(w)
 local slot=w.Slot
 return {path=path(w),parent=valid(w:GetParent()) and path(w:GetParent()) or '',
  slot=valid(slot) and path(slot) or '',slotClass=valid(slot) and class(slot) or '',
  padding=valid(slot) and margin(slot.Padding) or {},
  horizontal=valid(slot) and slot.HorizontalAlignment or -1,
  vertical=valid(slot) and slot.VerticalAlignment or -1,
  desired=size(w:GetDesiredSize()),visibility=w:GetVisibility(),opacity=w:GetRenderOpacity(),
  clipping=w:GetClipping(),transform=transform(w)}
end
local function sourceAudit(w)
 local a=node(w);local f=w.Font
 a.text=str(w:GetText());a.namespace=str(w.LocText.Namespace);a.key=str(w.LocText.Key)
 a.culture=str(w.DisplayCultureOverride);a.fontSize=f.Size
 a.fontObject=valid(f.FontObject) and f.FontObject:GetFullName() or ''
 a.typeface=str(f.TypefaceFontName);a.letterSpacing=f.LetterSpacing
 a.outline=f.OutlineSettings.OutlineSize;a.color=color(w.ColorAndOpacity)
 a.shadowX=w.ShadowOffset.X;a.shadowY=w.ShadowOffset.Y
 a.shadowColor={R=w.ShadowColorAndOpacity.R,G=w.ShadowColorAndOpacity.G,B=w.ShadowColorAndOpacity.B,A=w.ShadowColorAndOpacity.A}
 a.wrap=w.WrapTextAt;a.autoWrap=w.AutoWrapText;a.justification=w.Justification
 return a
end
local function same(a,b,label)
 for k,v in pairs(a) do
  local q=b[k]
  if type(v)=='table' then assert(type(q)=='table',label..'.'..k);same(v,q,label..'.'..k)
  elseif type(v)=='number' then assert(type(q)=='number' and near(v,q),label..'.'..k..' changed')
  else assert(v==q,label..'.'..k..' changed') end
 end
end
local function encode(t)
 local keys={};for k in pairs(t)do keys[#keys+1]=k end;table.sort(keys)
 local out={}
 for _,k in ipairs(keys)do
  local v=t[k];local value=type(v)=='table' and encode(v) or tostring(v)
  out[#out+1]=tostring(k)..'='..#value..':'..value
 end
 return table.concat(out,';')
end
local function nativeChildren(row)
 local out={}
 for i=0,row:GetChildrenCount()-1 do
  local child=row:GetChildAt(i)
  if not child:GetFullName():find('.PBZFurigana_',1,true) then
   local a=node(child);a.sizeRule=child.Slot.Size.SizeRule;out[#out+1]=a
  else
   local d=child:GetDesiredSize()
   assert(near(d.X,0)and near(d.Y,0)and child.Slot.Size.SizeRule==0,'Another ruby sibling changes native TopBox size')
  end
 end
 return out
end
local function snapshot(w)
 local box=w:GetParent();local row=valid(box) and box:GetParent()
 assert(valid(box) and valid(row),'Missing category parents')
 return {source=sourceAudit(w),box=node(box),row=node(row),children=nativeChildren(row)}
end
local function make(name,outer,id)
 local o=StaticConstructObject(StaticFindObject('/Script/UMG.'..name),outer,FName(id))
 assert(valid(o),'Could not construct category '..name);return o
end

local function differences(before,after,prefix,result)
 result=result or {};prefix=prefix or ''
 local keys,seen={},{}
 for k in pairs(before or {})do keys[#keys+1]=k;seen[k]=true end
 for k in pairs(after or {})do if not seen[k]then keys[#keys+1]=k end end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 for _,k in ipairs(keys)do
  local a,b=before and before[k],after and after[k]
  local label=type(k)=='number' and (prefix..'['..k..']') or (prefix=='' and tostring(k)or prefix..'.'..k)
  if type(a)=='table'and type(b)=='table'then differences(a,b,label,result)
  elseif not (type(a)=='number'and type(b)=='number'and near(a,b))and a~=b then
   result[#result+1]={path=label,before=a,after=b}
  end
 end
 return result
end

function M.detach(handle,log)
 if not handle then return true end
 log=log or function()end
 local ok,err=pcall(function()
  local w=handle.sourcePath and StaticFindObject(handle.sourcePath)
  -- Other adapters may already have restored neighboring title heights. Compare
  -- this removal with the state that actually exists immediately before it.
  -- A failed capture must never prevent removing our own bounds.
  local captured,beforeDetach
  if valid(w)then captured,beforeDetach=pcall(snapshot,w)end
  handle.detachBefore=captured and beforeDetach or nil
  handle.detachChanges=nil;handle.restoredUnchanged=nil
  handle.detachAfter=nil;handle.restoreAudit=nil;handle.restoredToAttachState=nil
  handle.sourceChangesSinceAttach=nil;handle.sourceSinceAttachUnchanged=nil
  handle.externalChangesSinceAttach=captured and differences(handle.before,beforeDetach)or nil
  handle.detachAuditError=not captured and tostring(beforeDetach or 'source unavailable before detach')or nil
  local bounds=handle.path and StaticFindObject(handle.path)
  if valid(bounds) then bounds:RemoveFromParent() end
  local row=handle.rowPath and StaticFindObject(handle.rowPath)
  if valid(row) then refresh(row) end
  w=handle.sourcePath and StaticFindObject(handle.sourcePath)
  if valid(w) then
   local sampled,afterDetach=pcall(snapshot,w)
   if sampled then
    handle.detachAfter=afterDetach;handle.restoreAudit=afterDetach.source
    handle.sourceChangesSinceAttach=differences(handle.before.source,afterDetach.source,'source')
    handle.sourceSinceAttachUnchanged=#handle.sourceChangesSinceAttach==0
    handle.restoredToAttachState=#differences(handle.before,afterDetach)==0
    if captured then
     handle.detachChanges=differences(beforeDetach,afterDetach)
     handle.restoredUnchanged=#handle.detachChanges==0
    end
    log('category_detach_audit detachUnchanged='..tostring(handle.restoredUnchanged)..
     ' sourceSinceAttachUnchanged='..tostring(handle.sourceSinceAttachUnchanged)..
     ' externalChanges='..tostring(handle.externalChangesSinceAttach and #handle.externalChangesSinceAttach)..
     ' detachChanges='..tostring(handle.detachChanges and #handle.detachChanges))
    for _,group in ipairs({'externalChangesSinceAttach','detachChanges'})do
     for _,change in ipairs(handle[group]or {})do
      local function value(v)return type(v)=='table'and encode(v)or tostring(v)end
      log('category_'..group..' '..change.path..' before='..value(change.before)..' after='..value(change.after))
     end
    end
   else handle.detachAuditError=tostring(afterDetach)end
  end
  if handle.detachAuditError then log('category_detach_audit_unavailable '..handle.detachAuditError)end
 end)
 if not ok then log('category_restore_error '..tostring(err)) end
 return ok,ok and handle.restoreAudit or tostring(err)
end

function M.attach(w,state,log,root)
 log=log or function()end
 local handle,stats
 local ok,err=pcall(function()
  local entry=assert(eligible(w),'Category source is outside the exact literature scope')
  assert(visible(w),'Category source is not in the visible active subtree')
  local box=w:GetParent();local row=valid(box) and box:GetParent()
  assert(valid(box) and class(box)=='SizeBox' and path(box):match('%.SizeBox_0$'),'Unexpected category SizeBox')
  assert(valid(row) and class(row)=='VerticalBox' and path(row):match('%.TopBox$'),'Unexpected category TopBox')
  assert(#nativeChildren(row)==7 and path(row:GetChildAt(0))==path(box),'Category must be first of the seven observed native TopBox children')
  assert(box:GetChildrenCount()==1 and path(box:GetContent())==path(w),'Unexpected category SizeBox content')
  local before=snapshot(w);local a=before.source
  assert(a.slotClass=='SizeBoxSlot' and a.horizontal==0 and a.vertical==0 and zero(a.padding),'Unsupported source slot')
  assert(a.justification==0 and not a.autoWrap and a.wrap==0,'Category source must be a left-aligned unwrapped line')
  assert(a.desired.X>0 and a.desired.Y>0 and a.fontSize>0,'Category source is not laid out')
  assert(a.outline==0 and a.shadowX==0 and a.shadowY==0,'Unobserved category shadow/outline requires separate measurement')
  assert(identity(a.transform) and identity(before.box.transform),'Transformed category source requires allocated geometry')
  assert(a.clipping==0 and before.box.clipping==0 and before.row.clipping==0,'Clipped category ancestors are unsupported')
  assert(before.box.slotClass=='VerticalBoxSlot' and before.box.horizontal==1 and before.box.vertical==1,'Unsupported category box alignment')
  local pad=before.box.padding
  assert(pad.Left==0 and pad.Top==0 and pad.Right==0 and near(pad.Bottom,6),'Unobserved category box padding')
  assert(before.box.opacity==1 and box.bOverride_HeightOverride and near(box.HeightOverride,26),'Unobserved category box height/opacity')
  assert(not box.bOverride_WidthOverride and not box.bOverride_MinDesiredHeight and not box.bOverride_MaxDesiredHeight,'Unsupported category box sizing overrides')
  assert(near(before.box.desired.X,a.desired.X) and near(before.box.desired.Y,26) and a.desired.Y<=26+.05,'Category source is scaled or clipped in its box')
  assert(before.row.slotClass=='VerticalBoxSlot' and row.Slot.Size.SizeRule==0 and before.row.horizontal==0 and before.row.vertical==1 and zero(before.row.padding),'TopBox needs its observed automatic-height slot')
  local expected={'SizeBox_0','HorizontalBox_0','SizeBox_2','ProgressEntrySizeBox','spacersub','Image_130','TopSwitcher'}
  local height=0
  for i,child in ipairs(before.children)do
   assert(child.path:match('%.([^%.]+)$')==expected[i] and child.slotClass=='VerticalBoxSlot','Category native children differ from the observed layout')
   assert(child.sizeRule==0,'Category TopBox requires automatic-height children')
   if child.visibility~=1 then height=height+child.padding.Top+child.desired.Y+child.padding.Bottom end
  end
  assert(before.row.desired.X>0 and height>0 and near(height,before.row.desired.Y),'Native TopBox height cannot be proved from participating children')
  state.serial=(state.serial or 0)+1;local prefix=PREFIX..state.serial..'_'
  handle={kind='category',sourcePath=path(w),boxPath=path(box),rowPath=path(row),before=before,sourceBefore=a}
  local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds');handle.path=path(bounds)
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(a.opacity)
  local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Canvas');handle.canvasPath=path(canvas);canvas:SetVisibility(3)
  local cs=bounds:AddChild(canvas);cs:SetHorizontalAlignment(0);cs:SetVerticalAlignment(0)
  local slot=row:AddChildToVerticalBox(bounds)
  slot:SetSize({Value=1,SizeRule=0});slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0});slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(1)
  local helper=assert(loadfile(root..'Scripts/item_title_ruby.lua'))()
  local runs,widgets,fitted=helper.build_segment_runs(w,entry.segments,canvas,row,prefix,root,
   {font=w.Font,color=w.ColorAndOpacity,text=a.text,rects={{x=0,y=0,width=a.desired.X,height=a.desired.Y}},ratio=.6,shadowX=0})
  local expected=0
  for _,part in ipairs(entry.segments)do if part.reading then expected=expected+1 end end
  assert(#runs==expected and #fitted.skipped==0 and fitted.remainingCollisions==0,'Incomplete category reading')
  -- The appended zero-height child starts at the original end of TopBox.
  -- The native first child starts at its own top padding, without a ScaleBox.
  for _,run in ipairs(runs)do
   assert(run.x-run.width/2>=-8 and run.x+run.width/2<=a.desired.X+8 and run.height<=a.desired.Y,
    'Category reading exceeds the bounded label allowance')
   run.canvasX=pad.Left+run.x;run.y=-height+pad.Top-run.height-2
   widgets[run.segment].slot:SetPosition({X=run.canvasX,Y=run.y})
  end
  refresh(row)
  assert(near(bounds:GetDesiredSize().X,0) and near(bounds:GetDesiredSize().Y,0),'Category sibling contributes desired size')
  local after=snapshot(w);same(before,after,'category native audit')
  assert(#nativeChildren(row)==7 and path(row:GetChildAt(row:GetChildrenCount()-1))==handle.path,'Category sibling was not appended after the native children')
  stats={key=a.key,sourceBefore=a,sourceAfter=after.source,sourceTextUnchanged=true,sourceFontUnchanged=true,
   sourceSizeUnchanged=true,sourceSubtreeUnchanged=true,sourceCultureUnchanged=true,topBoxUnchanged=true,
   nativeChildCount=7,topBoxHeight=height,ratio=.6,skipped={},runs=runs,
   rubyCulturePolicy='UMG TextBlock uses the copied resolved source Font; no PBZ culture override exists on the ruby widget.'}
  handle.stats=stats
  log('category_attached key='..a.key..' readings='..#runs)
 end)
 if not ok then
  if handle then M.detach(handle,log) end
  return nil,{reason=tostring(err),sourceBefore=handle and handle.sourceBefore,rollback=handle and handle.restoredToAttachState}
 end
 return handle,stats
end

function M.stop(state,log)
 state.category_active=false;state.category_tick=nil
 for _,layer in pairs(state.category_layers or {})do M.detach(layer.handle,log) end
 state.category_layers={};state.category_wait={}
end

local function attached(handle)
 if not handle then return false end
 local bounds=StaticFindObject(handle.path)
 return valid(bounds) and valid(bounds:GetParent()) and path(bounds:GetParent())==handle.rowPath
end

function M.start(state,log,root)
 log=log or function()end;M.stop(state,log)
 state.category_active=true;state.category_layers={};state.category_wait={}
 state.category_tick=function()
  local seen={}
  for _,w in ipairs(FindAllOf('PBZCommonLocText') or {})do
   if scoped(w) then
    local full=path(w)
    if not seen[full] then
     seen[full]=true
     local ok,err=pcall(function()
      local shown=state.ruby_enabled~=false and eligible(w) and visible(w)
      local signature=shown and encode(snapshot(w)) or 'hidden-or-outside-scope'
      local layer=state.category_layers[full]
      if layer and (layer.signature~=signature or not attached(layer.handle)) then
       M.detach(layer.handle,log);state.category_layers[full]=nil;state.category_wait[full]=nil;layer=nil
      end
      if not shown then state.category_wait[full]=nil;return end
      if not layer then
       local pending=state.category_wait[full]
       if not pending or pending.signature~=signature then pending={signature=signature,ticks=0};state.category_wait[full]=pending end
       pending.ticks=pending.ticks+1
       if pending.ticks==2 then
        local handle,stats=M.attach(w,state,log,root)
        if handle then state.category_layers[full]={signature=signature,handle=handle,stats=stats} end
        -- A failed unchanged signature is not retried every frame.
        log('category_result key='..str(w.LocText.Key)..' '..(handle and 'attached' or tostring(stats.reason)))
       end
      end
     end)
     if not ok then
      local layer=state.category_layers[full];if layer then M.detach(layer.handle,log);state.category_layers[full]=nil end
      state.category_wait[full]=nil
      if state.category_error~=tostring(err) then state.category_error=tostring(err);log('category_tick_error '..tostring(err)) end
     end
    end
   end
  end
  for full,layer in pairs(state.category_layers)do
   if not seen[full] then M.detach(layer.handle,log);state.category_layers[full]=nil;state.category_wait[full]=nil end
  end
  for full in pairs(state.category_wait)do if not seen[full] then state.category_wait[full]=nil end end
 end
 if not state.category_timer then
  state.category_timer=true
  LoopInGameThreadWithDelay(250,function()
   if state.category_active and state.category_tick then
    local ok,err=pcall(state.category_tick)
    if not ok and state.category_error~=tostring(err) then state.category_error=tostring(err);log('category_tick_error '..tostring(err)) end
   end
  end)
 end
 log('category watcher active; literature ItemTypeText only')
end
return M
