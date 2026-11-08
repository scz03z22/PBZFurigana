local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Book chapter-title adapter for the observed ItemSubHeadText surface.
-- Borrow only this title box's existing bottom padding for ruby above the text;
-- preserve total padding, native source font/text, tree structure and TopBox size.
-- ScaleBox-downscaled long titles fail closed until their native alignment is verified.
local M={}
local PREFIX='PBZFurigana_BookSubhead_'
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
  and name:match('%.ItemSubHeadText$')~=nil
end
local function node(w)
 local slot=w.Slot
 return {path=path(w),parent=valid(w:GetParent()) and path(w:GetParent()) or '',
  slot=valid(slot) and path(slot) or '',slotClass=valid(slot) and class(slot) or '',
  padding=valid(slot) and class(slot)~="ScaleBoxSlot" and margin(slot.Padding) or {},
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
 local scale=w:GetParent();local box=valid(scale)and scale:GetParent();local row=valid(box)and box:GetParent()
 assert(valid(scale)and valid(box)and valid(row),'Missing book title ancestors')
 return {source=sourceAudit(w),scale=node(scale),box=node(box),row=node(row),children=nativeChildren(row),
  scaleConfig={stretch=scale.Stretch,direction=scale.StretchDirection,userScale=scale.UserSpecifiedScale,ignoreInherited=scale.IgnoreInheritedScale},
  boxConfig={height=box.HeightOverride,heightOverride=box.bOverride_HeightOverride,width=box.WidthOverride,widthOverride=box.bOverride_WidthOverride,
   maxWidth=box.MaxDesiredWidth,maxWidthOverride=box.bOverride_MaxDesiredWidth,minWidthOverride=box.bOverride_MinDesiredWidth,
   minHeightOverride=box.bOverride_MinDesiredHeight,maxHeightOverride=box.bOverride_MaxDesiredHeight}}
end
local function make(name,outer,id)
 local o=StaticConstructObject(StaticFindObject('/Script/UMG.'..name),outer,FName(id))
 assert(valid(o),'Could not construct book title '..name);return o
end

local function copy(t)
 if type(t)~='table'then return t end
 local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out
end
local function auditNative(a,b,h,label)
 local x,y=copy(a),copy(b)
 for _,n in ipairs({x,y})do
  local p=n.box.padding
  assert(encode(p)==encode(h.originalPadding)or encode(p)==encode(h.appliedPadding),'External title padding changed')
  n.box.padding=copy(h.originalPadding)
  for _,child in ipairs(n.children)do if child.path==h.boxPath then child.padding=copy(h.originalPadding)end end
 end
 same(x,y,label)
end
M.matches=scoped
local function entryFor(w,state)
 assert(scoped(w),'Outside observed literature ItemSubHeadText scope')
 local text=str(w:GetText());local key=str(w.LocText.Key)
 assert(str(w.LocText.Namespace)=='Default','Unexpected literature namespace')
 assert(not text:find('[<>\r\n]'),'Multiline or rich chapter titles require a separate adapter')
 local entry
 if key:match('^Item_Memo_Subhead_') then
  entry=state.memory_subhead_entries and compact.match(state.memory_subhead_entries[key],text)
  assert(entry and entry.context=='memory_subhead','Unreviewed memory petal title')
 else
  assert(key:match('^Reading_'),'Unrecognized literature title key')
  entry=state.book_subhead_readings and state.book_subhead_readings[text]
  assert(entry and(entry.context=='item_title'or entry.context=='book_title'),'Exact book title has no loaded title entry')
 end
 local matched=entry.key==key;for _,alias in ipairs(entry.keys or {})do if alias==key then matched=true end end
 assert(matched,'Book title source key is not one of the reviewed aliases')
 local parts,n={},0
 for _,s in ipairs(entry.segments)do parts[#parts+1]=s.text;if s.reading then n=n+1 end end
 assert(table.concat(parts)==text and n>0,'Book title reading must exactly reconstruct original text')
 return entry,key,n
end
local function validate(w,state,root)
 local entry,key,count=entryFor(w,state);assert(visible(w),'Book title is hidden/inactive')
 local memory=entry.context=='memory_subhead'
 local scale=w:GetParent();local box=scale:GetParent();local row=box:GetParent()
 assert(class(scale)=='ScaleBox'and path(scale):match('%.ScaleBox_1$'),'Unexpected book title ScaleBox')
 assert(class(box)=='SizeBox'and path(box):match('%.SizeBox_2$'),'Unexpected book title SizeBox')
 assert(class(row)=='VerticalBox'and path(row):match('%.TopBox$'),'Unexpected book title TopBox')
 assert(scale:GetChildrenCount()==1 and path(scale:GetContent())==path(w)and box:GetChildrenCount()==1,'Unexpected source subtree')
 local a=snapshot(w);local s=a.source
 assert(s.slotClass=='ScaleBoxSlot'and s.horizontal==1 and s.vertical==2,'Unobserved source alignment')
 assert(s.justification==0 and not s.autoWrap and s.wrap==0,'Chapter title must be one native unwrapped line')
 assert(s.fontSize>0 and s.desired.X>0 and s.desired.Y>0,'Chapter title is not laid out')
 assert(s.outline==0 and s.shadowX==0 and s.shadowY==0,'Unobserved source outline/shadow')
 for _,n in ipairs({s,a.scale,a.box,a.row})do assert(identity(n.transform)and n.clipping==0,'Transformed/clipped book title is unsupported')end
 assert(a.scale.opacity==1 and a.box.opacity==1,'Unobserved inner title opacity')
 assert(a.scale.slotClass=='SizeBoxSlot'and a.scale.horizontal==0 and a.scale.vertical==0 and zero(a.scale.padding),'Unobserved ScaleBox parent slot')
 local sc=a.scaleConfig;assert(sc.stretch==2 and sc.direction==1 and sc.userScale==1 and not sc.ignoreInherited,'Unobserved scaling policy')
 local bc=a.boxConfig
 assert(bc.heightOverride and near(bc.height,50)and not bc.widthOverride and bc.maxWidthOverride and near(bc.maxWidth,533)
  and not bc.minWidthOverride and not bc.minHeightOverride and not bc.maxHeightOverride,'Unobserved title box constraints')
 local contentScale, bodyTop, width = 1, (bc.height-s.desired.Y)/2, s.desired.X
 if s.desired.X>bc.maxWidth+.01 then
  assert(root and not memory and near(a.box.desired.X,bc.maxWidth),'Unverified scaled literature title')
  local geo=assert(loadfile(root..'Scripts/geometry_service.lua'))().new(root)
  local sourceFrame,boxFrame=geo.read(w),geo.read(box)
  assert(boxFrame.xx>0 and boxFrame.yy>0 and math.abs(boxFrame.xy)<.001 and math.abs(boxFrame.yx)<.001
   and math.abs(sourceFrame.xy)<.001 and math.abs(sourceFrame.yx)<.001,'Scaled title transforms must be axis aligned')
  contentScale=sourceFrame.xx/boxFrame.xx
  bodyTop=(sourceFrame.y-boxFrame.y)/boxFrame.yy
  width=sourceFrame.width
  assert(contentScale>=.25 and contentScale<1 and math.abs(contentScale-sourceFrame.yy/boxFrame.yy)<.002
   and math.abs(sourceFrame.x-boxFrame.x)<.1 and bodyTop>=0
   and math.abs(bodyTop-(bc.height-sourceFrame.height*contentScale)/2)<.25
   and math.abs(a.scale.desired.X*contentScale-bc.maxWidth)<.5
   and math.abs(boxFrame.width-bc.maxWidth)<.5,'Scaled title geometry differs from native allocation')
 else
  assert(s.desired.Y<=bc.height+.01 and near(a.box.desired.X,s.desired.X)
   and near(a.scale.desired.X,s.desired.X),'Unexpected unscaled literature title allocation')
 end
 assert(near(a.box.desired.Y,50),'Native title box height changed')
 assert(a.box.slotClass=='VerticalBoxSlot'and a.box.horizontal==1 and a.box.vertical==1 and box.Slot.Size.SizeRule==0,'Unobserved title box slot')
 assert(a.row.slotClass=='VerticalBoxSlot'and a.row.horizontal==0 and a.row.vertical==1 and row.Slot.Size.SizeRule==0 and zero(a.row.padding),'Unobserved TopBox slot')
 local expected={'SizeBox_0','HorizontalBox_0','SizeBox_2','ProgressEntrySizeBox','spacersub','Image_130','TopSwitcher'}
 assert(#a.children==#expected,'Expected seven native TopBox children')
 local height,offset,previousGap,found=0,0,0,false
 for i,c in ipairs(a.children)do
  assert(c.path:match('%.([^%.]+)$')==expected[i]and c.slotClass=='VerticalBoxSlot'and c.sizeRule==0,'Unobserved TopBox order/sizing')
  if c.visibility~=1 then
   if c.path==a.box.path then offset=height+c.padding.Top;found=true
   elseif not found then previousGap=c.padding.Bottom end
   height=height+c.padding.Top+c.desired.Y+c.padding.Bottom
  end
 end
 assert(found and near(height,a.row.desired.Y),'TopBox automatic height cannot be reconstructed')
 local p=a.box.padding
 assert(p.Left==0 and p.Right==0 and p.Top>=0 and p.Bottom>=0,'Unsupported literature title padding')
 assert(memory or near(p.Top+p.Bottom,49),'Book title must retain the observed 49px total padding budget')
 return {entry=entry,key=key,count=count,before=a,row=row,box=box,height=height,offset=offset,memory=memory,
  bodyTop=bodyTop,contentScale=contentScale,width=width,previousGap=previousGap}
end
function M.inspect(w,state,root)
 local v=validate(w,state,root)
 return {key=v.key,native=v.before,height=v.height,offset=v.offset,bodyTop=v.bodyTop,previousGap=v.previousGap}
end
function M.detach(h,log)
 if not h then return true end;log=log or function()end
 local w=StaticFindObject(h.sourcePath);local got,before=pcall(snapshot,w)
 local ok,err=pcall(function()
  local bounds=h.path and StaticFindObject(h.path);if valid(bounds)then bounds:RemoveFromParent()end
  local box=StaticFindObject(h.boxPath)
  if valid(box)and valid(box.Slot)then
   local p=margin(box.Slot.Padding)
   if encode(p)==encode(h.appliedPadding)or encode(p)==encode(h.originalPadding)then
    box.Slot:SetPadding(h.originalPadding);h.paddingRestored=encode(margin(box.Slot.Padding))==encode(h.originalPadding)
   else h.paddingRestored=false;h.externalPaddingPreserved=p;log('book_subhead_external_padding_preserved')end
  end
  local row=StaticFindObject(h.rowPath);if valid(row)then refresh(row)end
 end)
 if valid(w)then
  local measured,after=pcall(snapshot,w)
  if measured then
   h.restoreAudit=after;h.detachUnchanged=got and pcall(auditNative,before,after,h,'book title detach')or false
   h.restoredToAttachState=pcall(same,h.before,after,'book title restore')
  end
 end
 if not ok then log('book_subhead_restore_error '..tostring(err))end
 return ok,err
end
function M.attach(w,state,log,root)
 log=log or function()end;local h,stats
 local ok,err=pcall(function()
  local v=validate(w,state,root);local a=v.before.source
  assert(v.memory or (near(v.before.box.padding.Top,0)and near(v.before.box.padding.Bottom,49)),
   'Unowned book title padding adjustment')
  state.serial=(state.serial or 0)+1;local prefix=PREFIX..state.serial..'_'
  h={kind='book_subhead',sourcePath=path(w),boxPath=path(v.box),rowPath=path(v.row),before=v.before,
   originalPadding=copy(v.before.box.padding),appliedPadding=copy(v.before.box.padding)}
  local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds');h.path=path(bounds)
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(a.opacity)
  local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Canvas');canvas:SetVisibility(3)
  local cs=bounds:AddChild(canvas);cs:SetHorizontalAlignment(0);cs:SetVerticalAlignment(0)
  local slot=v.row:AddChildToVerticalBox(bounds)
  slot:SetSize({Value=1,SizeRule=0});slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0});slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(1)
  local helper=assert(loadfile(root..'Scripts/item_title_ruby.lua'))()
  local runs,widgets,fitted=helper.build_segment_runs(w,v.entry.segments,canvas,v.row,prefix,root,
   {font=w.Font,color=w.ColorAndOpacity,text=a.text,rects={{x=0,y=0,width=v.width,height=a.desired.Y}},
    ratio=.6,shadowX=0,titleContentScale=v.contentScale,titleAllocatedWidth=v.before.boxConfig.maxWidth,
    clipLeft=0,clipRight=v.before.boxConfig.maxWidth})
  assert(#runs==v.count and fitted.remainingCollisions==0 and #fitted.skipped==0,'Book title ruby coverage/collision failure')
  local tallest=0
  for _,r in ipairs(runs)do
   tallest=math.max(tallest,r.height)
   assert(r.x-r.width/2>=-.01 and r.x+r.width/2<=v.before.boxConfig.maxWidth+.01,'Chapter-title ruby exceeds the measured column')
  end
  local gap,clearance=2,2
  local reserve=math.max(0,math.ceil(tallest+gap+clearance-v.bodyTop-v.previousGap))
  local room=math.max(0,h.originalPadding.Bottom-clearance)
  assert(reserve<=room,'Insufficient existing literature title padding')
  h.appliedPadding.Top=h.appliedPadding.Top+reserve;h.appliedPadding.Bottom=h.appliedPadding.Bottom-reserve
  v.box.Slot:SetPadding(h.appliedPadding)
  for _,r in ipairs(runs)do
   r.y=-v.height+v.offset+reserve+v.bodyTop-r.height-gap;r.canvasX=r.x
   r.clearanceFromPrevious=v.previousGap+reserve+v.bodyTop-r.height-gap
   assert(r.clearanceFromPrevious>=clearance-.01,'Ruby overlaps previous native row')
   widgets[r.segment].slot:SetPosition({X=r.canvasX,Y=r.y})
  end
  refresh(v.row)
  assert(near(bounds:GetDesiredSize().X,0)and near(bounds:GetDesiredSize().Y,0),'Book title sibling contributes layout size')
  local after=snapshot(w);auditNative(v.before,after,h,'book title native audit')
  stats={key=v.key,runs=runs,skipped={},remainingCollisions=0,sourceBefore=a,sourceAfter=after.source,
   sourceTextUnchanged=true,sourceFontUnchanged=true,sourceCultureUnchanged=true,sourceSlotUnchanged=true,
   sourcePositionUnchanged=reserve==0,sourceSubtreeUnchanged=true,topBoxSizeUnchanged=true,scaleFactor=v.contentScale,
   paddingOriginal=copy(h.originalPadding),paddingApplied=copy(h.appliedPadding),paddingTotalUnchanged=true,
   topReserve=reserve,nativeAuditBefore=v.before,nativeAuditAfter=after,
   rubyCulturePolicy='Resolved native Font copied; PBZ source raw culture stays unchanged.',
   longTitlePolicy='Use measured native ScaleBox geometry and keep every reading inside the title column.'}
  h.stats=stats;log('book_subhead_attached key='..v.key..' runs='..#runs..' reserve='..reserve
   ..' total_padding='..(h.originalPadding.Top+h.originalPadding.Bottom))
 end)
 if not ok then if h then M.detach(h,log)end;return nil,{reason=tostring(err),rollback=h and h.restoredToAttachState}end
 return h,stats
end
function M.stop(state,log)
 state.book_subhead_active=false;state.book_subhead_tick=nil
 for _,l in pairs(state.book_subhead_layers or {})do M.detach(l.handle,log)end
 state.book_subhead_layers={};state.book_subhead_wait={};state.book_subhead_rejected={}
end
function M.start(state,log,root)
 log=log or function()end;M.stop(state,log)
 state.book_subhead_readings=state.release_readings.load('item_readings',root,log)
 if not state.memory_subhead_entries then
  state.memory_subhead_entries=assert(loadfile(root..'Scripts/public10_readings.lua'))().entries
 end
 state.book_subhead_active=true
 state.book_subhead_tick=function()
  local seen={};local found=FindAllOf('PBZCommonLocText')or {}
  for i=1,math.min(#found,2048)do
   local w=found[i]
   if scoped(w)and not seen[path(w)]then
    local p=path(w);seen[p]=true
    local ok,v=pcall(validate,w,state,root);local active=ok and state.ruby_enabled~=false
    local signature=active and encode(v.before)or 'inactive';local layer=state.book_subhead_layers[p]
    if not ok and state.book_subhead_rejected[p]~=tostring(v)then state.book_subhead_rejected[p]=tostring(v);log('book_subhead_rejected '..tostring(v))
    elseif ok then state.book_subhead_rejected[p]=nil end
    local bounds=layer and StaticFindObject(layer.handle.path)
    if layer and(layer.signature~=signature or not valid(bounds)or not valid(bounds:GetParent())or path(bounds:GetParent())~=layer.handle.rowPath)then
     M.detach(layer.handle,log);state.book_subhead_layers[p]=nil;state.book_subhead_wait[p]=nil;layer=nil
     ok,v=pcall(validate,w,state,root);active=ok and state.ruby_enabled~=false;signature=active and encode(v.before)or'inactive'
    end
    if active and not layer then
     local wait=state.book_subhead_wait[p]
     if not wait or wait.signature~=signature then wait={signature=signature,ticks=0};state.book_subhead_wait[p]=wait end
     wait.ticks=wait.ticks+1
     if wait.ticks==2 then
      local h,result=M.attach(w,state,log,root)
      if h then state.book_subhead_layers[p]={signature=encode(snapshot(w)),handle=h,stats=result}end
      log('book_subhead_result '..(h and result.key or result.reason))
     end
    elseif not active then state.book_subhead_wait[p]=nil end
   end
  end
  for p,l in pairs(state.book_subhead_layers)do if not seen[p]then M.detach(l.handle,log);state.book_subhead_layers[p]=nil;state.book_subhead_wait[p]=nil end end
  for p in pairs(state.book_subhead_wait)do if not seen[p]then state.book_subhead_wait[p]=nil end end
  for p in pairs(state.book_subhead_rejected)do if not seen[p]then state.book_subhead_rejected[p]=nil end end
 end
 if not state.book_subhead_timer then
  state.book_subhead_timer=true
  LoopInGameThreadWithDelay(250,function()
   if state.book_subhead_active and state.book_subhead_tick then
    local ok,err=pcall(state.book_subhead_tick);if not ok then M.stop(state,log);log('book_subhead_watcher_stopped '..tostring(err))end
   end
  end)
 end
 log('book_subhead watcher active; reviewed Reading_ titles on ItemSubHeadText only')
end
return M

