local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Ruby for the shared left literature, quest and equipment category labels.
-- A zero-size sibling shares its outer Overlay and inherits the same scaling.
local M={}
local LITERATURE=compact.exact({["12:49fefd3ca602aabc"]={["fingerprint"]="12:49fefd3ca602aabc",["parts"]={{6,"きおく"},{3},{3,"はな"}},["plain"]=true},["6:96a3803ca090d63f"]={["fingerprint"]="6:96a3803ca090d63f",["parts"]={{6,"ずかん"}},["plain"]=true},["6:bac2d064631c32f9"]={["fingerprint"]="6:bac2d064631c32f9",["parts"]={{6,"しょもつ"}},["plain"]=true}})
local QUEST=compact.exact({["6:3576155837350cba"]={["fingerprint"]="6:3576155837350cba",["parts"]={{6,"いつわ"}},["plain"]=true},["6:b0a8a50bbd195a45"]={["fingerprint"]="6:b0a8a50bbd195a45",["parts"]={{6,"しゅうしゅう"}},["plain"]=true},["6:eaa9060e9d86e754"]={["fingerprint"]="6:eaa9060e9d86e754",["parts"]={{6,"ものがたり"}},["plain"]=true}})
local EQUIPMENT=compact.exact({["18:746872686d73e060"]={["context"]="ui_menu_text",["fingerprint"]="18:746872686d73e060",["key"]="UI_Character_63",["keys"]={[1]="UI_Character_63"},["parts"]={[1]={[1]=6,[2]="ぼうぎょ"},[2]={[1]=3,[2]="けい"},[3]={[1]=9,[2]="そうしょくひん"}},["plain"]=true},["18:c087cbd0bb921669"]={["context"]="ui_menu_text",["fingerprint"]="18:c087cbd0bb921669",["key"]="UI_Character_62",["keys"]={[1]="UI_Character_62"},["parts"]={[1]={[1]=6,[2]="こうげき"},[2]={[1]=3,[2]="けい"},[3]={[1]=9,[2]="そうしょくひん"}},["plain"]=true},["18:ce54f1a443921c8e"]={["context"]="ui_menu_text",["fingerprint"]="18:ce54f1a443921c8e",["key"]="UI_Character_64",["keys"]={[1]="UI_Character_64"},["parts"]={[1]={[1]=6,[2]="ほじょ"},[2]={[1]=3,[2]="けい"},[3]={[1]=9,[2]="そうしょくひん"}},["plain"]=true}})
local PREFIX='PBZFurigana_BookTab_'
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
 if not valid(w)or class(w)~='PBZCommonLocText'then return false end
 local n=w:GetFullName()
 return n:find('/Engine/Transient',1,true)and not n:find('Default__',1,true)
  and (n:find('.WB_Literature.',1,true)or n:find('.W_DIsplayQuest.',1,true)
   or (n:find('.WB_CharacterV5.',1,true)and n:find('.WB_Character_V4.',1,true)))
  and n:match('%.W_SecondTabLine%.WidgetTree_%d+%.LineText$')~=nil
end
local function eligible(w)
 if not scoped(w) or str(w.LocText.Namespace)~='Default' or str(w.LocText.Key)~='' then return nil end
 local name=path(w)
 local definitions=name:find('.W_DIsplayQuest.',1,true) and QUEST
  or name:find('.WB_Character_V4.',1,true) and EQUIPMENT or LITERATURE
 local entry=definitions[str(w:GetText())]
 return entry and entry.segments
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
  if not child:GetFullName():find('.'..PREFIX,1,true) then
   local a=node(child);a.sizeRule=child.Slot.Size.SizeRule;out[#out+1]=a
  end
 end
 return out
end

local function context(w)
 local switch=w:GetParent();local row=valid(switch)and switch:GetParent();local box=valid(row)and row:GetParent()
 local owner=valid(box)and parent(box);local overlay=valid(owner)and owner:GetParent()
 assert(valid(switch)and valid(row)and valid(box)and valid(owner)and valid(overlay),'Missing book tab parents')
 return switch,row,box,owner,overlay
end
local function snapshot(w)
 local switch,row,box,owner,overlay=context(w)
 return {source=sourceAudit(w),switch=node(switch),row=node(row),box=node(box),owner=node(owner),children=nativeChildren(row),
  overlay={path=path(overlay),desired=size(overlay:GetDesiredSize()),opacity=overlay:GetRenderOpacity(),visibility=overlay:GetVisibility(),clipping=overlay:GetClipping(),transform=transform(overlay)}}
end
local function make(kind,outer,name)
 local w=StaticConstructObject(StaticFindObject('/Script/UMG.'..kind),outer,FName(name));assert(valid(w),'Could not construct book tab '..kind);return w
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
 if not handle then return true end;log=log or function()end
 local ok,err=pcall(function()
  local w=handle.sourcePath and StaticFindObject(handle.sourcePath)
  local captured,beforeDetach;if valid(w)then captured,beforeDetach=pcall(snapshot,w)end
  handle.detachBefore=captured and beforeDetach or nil;handle.detachAfter=nil;handle.restoreAudit=nil
  handle.restoredUnchanged=nil;handle.detachChanges=nil;handle.sourceSinceAttachUnchanged=nil;handle.restoredToAttachState=nil
  handle.externalChangesSinceAttach=captured and differences(handle.before,beforeDetach)or nil
  local bounds=handle.path and StaticFindObject(handle.path);if valid(bounds)then bounds:RemoveFromParent()end
  local overlay=handle.overlayPath and StaticFindObject(handle.overlayPath);if valid(overlay)then refresh(overlay)end
  if valid(w)then
   local sampled,after=pcall(snapshot,w)
   if sampled then
    handle.detachAfter=after;handle.restoreAudit=after.source
    handle.sourceSinceAttachUnchanged=#differences(handle.before.source,after.source)==0
    handle.restoredToAttachState=#differences(handle.before,after)==0
    if captured then handle.detachChanges=differences(beforeDetach,after);handle.restoredUnchanged=#handle.detachChanges==0 end
   else handle.auditError=tostring(after)end
  end
 end)
 if not ok then log('book_tab_restore_error '..tostring(err))end
 log('book_tab_detach unchanged='..tostring(handle.restoredUnchanged)..' sourceSinceAttachUnchanged='..tostring(handle.sourceSinceAttachUnchanged))
 return ok,ok and handle.restoreAudit or tostring(err)
end
function M.attach(w,state,log,root)
 log=log or function()end;local handle,stats
 local ok,err=pcall(function()
  local segments=assert(eligible(w),'Outside the exact shared category scope')
  assert(visible(w),'Tab source is not in the active subtree')
  local switch,row,box,owner,overlay=context(w)
  assert(class(switch)=='WidgetSwitcher'and path(switch):match('%.WidgetSwitcher_0$'),'Unobserved book tab switcher')
  assert(class(row)=='HorizontalBox'and path(row):match('%.HorizontalBox_862$'),'Unobserved book tab row')
  assert(class(box)=='SizeBox'and path(box):match('%.SizeBox_59$'),'Unobserved book tab size box')
  local equipment=path(w):find('.WB_CharacterV5.',1,true)and path(w):find('.WB_Character_V4.',1,true)
  local localOverlay=equipment and path(overlay):match('%.WB_Character_V4%.WidgetTree_%d+%.Overlay_60$')
   or not equipment and path(overlay):match('%.Overlay_19$')
  assert(class(owner)=='W_SecondTabLine_C'and class(overlay)=='Overlay'and localOverlay,'Unobserved shared tab owner')
  assert(valid(switch:GetActiveWidget())and path(switch:GetActiveWidget())==path(w),'Book text is not the active switcher child')
  local before=snapshot(w);local a=before.source
  assert(a.slotClass=='WidgetSwitcherSlot'and a.horizontal==0 and a.vertical==0 and zero(a.padding),'Unobserved text slot')
  assert(a.justification==0 and not a.autoWrap and a.wrap==0 and a.outline==0 and a.shadowX==0 and a.shadowY==0,'Unsupported book tab font flow')
  assert(a.fontSize>0 and a.desired.X>0 and a.desired.Y>0,'Book tab is not laid out')
  for _,n in ipairs({a,before.switch,before.row,before.box,before.owner,before.overlay})do
   assert(identity(n.transform)and n.clipping==0,'Transformed or clipped book tab requires another adapter')
  end
  for _,n in ipairs({before.switch,before.row,before.box,before.owner})do assert(n.opacity==1,'Fading native book tab parent is unsupported')end
  assert(before.switch.slotClass=='HorizontalBoxSlot'and before.switch.horizontal==2 and before.switch.vertical==2 and switch.Slot.Size.SizeRule==0,'Switcher must be the centered automatic-width cell')
  local sp=before.switch.padding
  assert(sp.Top==0 and sp.Bottom==0 and near(sp.Left,sp.Right)and sp.Left>=0,'Asymmetric book tab padding')
  assert(before.row.slotClass=='SizeBoxSlot'and before.row.horizontal==0 and before.row.vertical==0 and zero(before.row.padding),'Row must fill the fixed-width box')
  assert(box.bOverride_WidthOverride and box.WidthOverride>0 and not box.bOverride_HeightOverride and not box.bOverride_MinDesiredHeight and not box.bOverride_MaxDesiredHeight,'Unobserved book tab box sizing')
  assert(before.owner.slotClass=='OverlaySlot'and before.owner.horizontal==1 and before.owner.vertical==1,'Owner must be top-left aligned in its overlay')
  local op=before.owner.padding
  assert(op.Right==0 and op.Bottom==0 and op.Left>=0 and op.Top>0,'Unsupported book tab owner padding')
  local children=before.children
  assert(#children==3 and children[1].path:match('%.Image_325$')and children[2].path==path(switch)and children[3].path:match('%.Image_45$'),'Native horizontal children changed')
  for _,i in ipairs({1,3})do local c=children[i];local native=row:GetChildAt(i-1)
   assert(c.slotClass=='HorizontalBoxSlot'and c.sizeRule==1 and c.horizontal==0 and c.vertical==2 and zero(c.padding),'Both line images must fill with zero padding')
   assert(c.visibility~=1 and identity(c.transform)and c.opacity==1 and c.clipping==0 and native.Slot.Size.Value>0,'Unsupported decorative line state')
  end
  assert(near(row:GetChildAt(0).Slot.Size.Value,row:GetChildAt(2).Slot.Size.Value)and near(children[1].desired.X,children[3].desired.X),'Line columns must be symmetric')
  assert(near(before.row.desired.X,children[1].desired.X+a.desired.X+sp.Left+sp.Right+children[3].desired.X),'Native row desired width does not match its children')
  assert(box.WidthOverride>a.desired.X+sp.Left+sp.Right,'No room for the symmetric line columns')
  assert(near(before.box.desired.X,box.WidthOverride)and near(before.owner.desired.X,box.WidthOverride),'Fixed-width owner allocation is unproved')
  for _,n in ipairs({before.switch,before.row,before.box,before.owner})do assert(near(n.desired.Y,a.desired.Y),'Native row has unproved vertical slack')end
  assert(near(before.switch.desired.X,a.desired.X),'Switcher width differs from its active text')
  state.serial=(state.serial or 0)+1;local prefix=PREFIX..state.serial..'_'
  handle={kind='book_tab',sourcePath=path(w),overlayPath=path(overlay),before=before,sourceBefore=a}
  local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds');handle.path=path(bounds)
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(a.opacity)
  local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Canvas');handle.canvasPath=path(canvas);canvas:SetVisibility(3);bounds:AddChild(canvas)
  local slot=overlay:AddChildToOverlay(bounds);slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(1);slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
  local helper=assert(loadfile(root..'Scripts/item_title_ruby.lua'))()
  local runs,widgets,fitted=helper.build_segment_runs(w,segments,canvas,overlay,prefix,root,
   {font=w.Font,color=w.ColorAndOpacity,text=a.text,rects={{x=0,y=0,width=a.desired.X,height=a.desired.Y}},
    ratio=.6,shadowX=0,clipLeft=-sp.Left,clipRight=a.desired.X+sp.Right})
  local expected=0
  for _,part in ipairs(segments)do if part.reading then expected=expected+1 end end
  assert(#runs==expected and #fitted.skipped==0 and fitted.remainingCollisions==0,'Incomplete tab reading')
  -- The two equal Fill columns divide the allocated fixed width symmetrically.
  -- Desired row width (350 in the sample) is NOT the allocated box width (400).
  local textLeft=op.Left+(box.WidthOverride-a.desired.X)/2
  for _,run in ipairs(runs)do
   assert(run.x-run.width/2>=-sp.Left and run.x+run.width/2<=a.desired.X+sp.Right
    and run.height<a.desired.Y,'Tab reading exceeds its proven allowance')
   run.canvasX=textLeft+run.x;run.y=op.Top-run.height-2
   assert(run.y>=0,'Tab annotation would extend above its overlay')
   widgets[run.segment].slot:SetPosition({X=run.canvasX,Y=run.y})
  end
  refresh(overlay)
  assert(near(bounds:GetDesiredSize().X,0)and near(bounds:GetDesiredSize().Y,0),'Book tab sibling contributes layout size')
  local after=snapshot(w);same(before,after,'book tab native audit')
  stats={key=a.key,text=a.text,sourceBefore=a,sourceAfter=after.source,sourceTextUnchanged=true,sourceFontUnchanged=true,sourceSizeUnchanged=true,
   sourceSubtreeUnchanged=true,sourceCultureUnchanged=true,sourceContext='shared left category label',ratio=.6,runs=runs,skipped={},
   nativeRowDesiredWidth=before.row.desired.X,allocatedRowWidth=box.WidthOverride,centerFromEqualFillColumns=true}
  handle.stats=stats;log('book_tab_attached text='..a.text..' readings='..#runs)
 end)
 if not ok then if handle then M.detach(handle,log)end;return nil,{reason=tostring(err),rollback=handle and handle.restoredToAttachState}end
 return handle,stats
end
function M.stop(state,log)
 state.book_tab_active=false;state.book_tab_tick=nil
 for _,layer in pairs(state.book_tab_layers or {})do M.detach(layer.handle,log)end
 state.book_tab_layers={};state.book_tab_pending={};state.book_tab_sources={}
end
function M.start(state,log,root)
 log=log or function()end;M.stop(state,log);state.book_tab_active=true;local tick=0
 state.book_tab_tick=function()
  tick=tick+1
  if state.ruby_enabled==false then
   for _,layer in pairs(state.book_tab_layers)do M.detach(layer.handle,log)end
   state.book_tab_layers={};state.book_tab_pending={};return
  end
  if tick==1 or tick%8==0 then
   local found,count={},0
   for _,tab in ipairs(FindAllOf('W_SecondTabLine_C') or {}) do
    local tree=valid(tab) and tab.WidgetTree
    if valid(tree) then
     local w=StaticFindObject(path(tree)..'.LineText')
     if scoped(w) and not found[path(w)] then
      found[path(w)]=w;count=count+1
      if count==8 then break end
     end
    end
   end
   state.book_tab_sources=found
  end
  local seen={}
  for id,w in pairs(state.book_tab_sources)do if valid(w)then
   seen[id]=true
   local ok,err=pcall(function()
    local shown=eligible(w)and visible(w)and(not state.scope_policy or state.scope_policy.literatureUI(state.scope,w:GetFullName()));local signature=shown and encode(snapshot(w))or 'hidden'
    local layer=state.book_tab_layers[id];local bounds=layer and StaticFindObject(layer.handle.path)
    if layer and(layer.signature~=signature or not valid(bounds)or not valid(bounds:GetParent()))then M.detach(layer.handle,log);state.book_tab_layers[id]=nil;state.book_tab_pending[id]=nil;layer=nil end
    if not shown then state.book_tab_pending[id]=nil;return end
    if not layer then
     local wait=state.book_tab_pending[id]
     if not wait or wait.signature~=signature then wait={signature=signature,ticks=0};state.book_tab_pending[id]=wait end
     wait.ticks=wait.ticks+1
     if wait.ticks==2 then
      local h,s=M.attach(w,state,log,root);if h then state.book_tab_layers[id]={signature=signature,handle=h,stats=s}end
      log('book_tab_result '..(h and 'attached'or tostring(s.reason)))
     end
    end
   end)
   if not ok then
    local layer=state.book_tab_layers[id];if layer then M.detach(layer.handle,log);state.book_tab_layers[id]=nil end
    if state.book_tab_error~=tostring(err)then state.book_tab_error=tostring(err);log('book_tab_tick_error '..tostring(err))end
   end
  end end
  for id,layer in pairs(state.book_tab_layers)do if not seen[id]then M.detach(layer.handle,log);state.book_tab_layers[id]=nil;state.book_tab_pending[id]=nil end end
  for id in pairs(state.book_tab_pending)do if not seen[id]then state.book_tab_pending[id]=nil end end
 end
 if not state.book_tab_timer then
  state.book_tab_timer=true
  LoopInGameThreadWithDelay(250,function()
   if not state.book_tab_active or not state.book_tab_tick then return end
   local ok,err=pcall(state.book_tab_tick)
   if not ok and state.book_tab_error~=tostring(err)then state.book_tab_error=tostring(err);log('book_tab_tick_error '..tostring(err))end
  end)
 end
 log('book tab watcher active; exact shared category labels')
end
return M
