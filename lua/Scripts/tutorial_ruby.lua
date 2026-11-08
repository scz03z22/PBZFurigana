local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Exact, observed Potion HUD only. The native text and InputAction icon stay
-- visible and untouched. Native rich prefix measurements include the real icon.
local M={}
local PREFIX='PBZFurigana_Tutorial_'
local function valid(o)local ok,r=pcall(function()return o and o:IsValid()end);return ok and r==true end
local function str(v)if type(v)=='string'then return v end;return v:ToString()end
local function full(o)return valid(o)and o:GetFullName()or 'none'end
local function path(o)return o:GetFullName():match('^[^ ]+ (.+)$')end
local function class(o)return str(o:GetClass():GetFName())end
local function near(a,b)return math.abs(a-b)<.05 end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<1000000 end
local function size(v)return {x=v.X,y=v.Y}end
local function color(v)local c=v.SpecifiedColor;return {r=c.R,g=c.G,b=c.B,a=c.A,rule=v.ColorUseRule}end
local function margin(v)return {left=v.Left,top=v.Top,right=v.Right,bottom=v.Bottom}end
local function zero(t)for _,v in pairs(t)do if v~=0 then return false end end;return true end
local function unwrap(v)local ok,r=pcall(function()return v:get()end);return ok and r or v end
local function values(a,limit)
 local r={};if type(a)=='table'then for i=1,math.min(#a,limit)do r[#r+1]=unwrap(a[i])end
 elseif a then a:ForEach(function(_,v)if #r<limit then r[#r+1]=unwrap(v)end end)end;return r
end
local function rect(w)
 local rows=values(w:GetVisualLineRects(),3);assert(#rows==1,'Potion must remain one native visual line')
 local r=rows[1];assert(finite(r.X)and finite(r.Y)and finite(r.Z)and finite(r.W)and r.Z>0 and r.W>0,'Invalid native potion rectangle')
 return {x=r.X,y=r.Y,width=r.Z,height=r.W}
end
local function parent(w)
 local p=w:GetParent();if valid(p)then return p end
 local t=w:GetOuter();if valid(t)and class(t)=='WidgetTree'then return t:GetOuter()end
end
local function visible(w)
 local seen={};local p=w
 for _=1,30 do
  if not valid(p)then return true end
  local id=path(p);if seen[id]then return false end;seen[id]=true
  local v=p:GetVisibility();if v==1 or v==2 or p:GetRenderOpacity()<.01 then return false end
  local q=parent(p)
  if valid(q)and (class(q)=='WidgetSwitcher'or class(q)=='PBZCommonVisibilitySwitcher'or class(q)=='CommonVisibilitySwitcher')then
   local active=q:GetActiveWidget();if not valid(active)or path(active)~=id then return false end
  end
  p=q
 end
 return false
end
function M.scoped(w)
 if not valid(w)or class(w)~='PBZCommonLocRichText'then return false end
 local n=full(w)
 return n:find('/Engine/Transient',1,true)~=nil and not n:find('Default__',1,true)and
  n:match('%.W_FrontEndHUDLayout_C_%d+%.WidgetTree_%d+%.W_TutorialBar_Hint_Potion_C_%d+%.WidgetTree_%d+%.PBZCommonLocRichText$')~=nil
end
local function entryFor(w,entries)
 if not M.scoped(w)or str(w.LocText.Namespace)~='Default'or str(w.LocText.Key)~='Tutorial_Potion_3'then return nil end
 local e=entries[str(w:GetText())];return e and e.key=='Tutorial_Potion_3'and e or nil
end
local function transform(w)
 local t=w.RenderTransform;return {x=t.Translation.X,y=t.Translation.Y,sx=t.Scale.X,sy=t.Scale.Y,hx=t.Shear.X,hy=t.Shear.Y,angle=t.Angle}
end
local function identity(t)return t.x==0 and t.y==0 and t.sx==1 and t.sy==1 and t.hx==0 and t.hy==0 and t.angle==0 end
local function node(w)
 local s=w.Slot
 return {path=path(w),parent=full(w:GetParent()),slot=full(s),slotClass=valid(s)and class(s)or '',
  padding=valid(s)and margin(s.Padding)or {},horizontal=valid(s)and s.HorizontalAlignment or -1,vertical=valid(s)and s.VerticalAlignment or -1,
  desired=size(w:GetDesiredSize()),visibility=w:GetVisibility(),opacity=w:GetRenderOpacity(),clipping=w:GetClipping(),transform=transform(w)}
end
local function sourceAudit(w)
 local a=node(w);local f=w.DefaultTextStyleOverride.Font
 a.text=str(w:GetText());a.key=str(w.LocText.Key);a.namespace=str(w.LocText.Namespace);a.culture=str(w.DisplayCultureOverride)
 a.fontSize=f.Size;a.fontObject=full(f.FontObject);a.typeface=str(f.TypefaceFontName);a.letterSpacing=f.LetterSpacing;a.outline=f.OutlineSettings.OutlineSize
 a.color=color(w.DefaultTextStyleOverride.ColorAndOpacity);a.lineHeight=w.LineHeightPercentage;a.justification=w.Justification
 a.wrap=w.WrapTextAt;a.autoWrap=w.AutoWrapText;a.rect=rect(w);a.customColor=w.bUseCustomColor
 return a
end
local function snapshot(w)
 local overlay=w:GetParent();local result={source=sourceAudit(w),overlay=node(overlay),children={}}
 local n=overlay:GetChildrenCount();assert(n<=8,'Unexpected potion overlay child count')
 for i=0,n-1 do local c=overlay:GetChildAt(i)
  if not full(c):find('.'..PREFIX,1,true)then result.children[#result.children+1]=node(c)end
 end
 return result
end
local function same(a,b,label)
 for k,v in pairs(a)do local q=b[k]
  if type(v)=='table'then assert(type(q)=='table',label..'.'..k);same(v,q,label..'.'..k)
  elseif type(v)=='number'then assert(type(q)=='number'and near(v,q),label..'.'..k..' changed')
  else assert(v==q,label..'.'..k..' changed')end
 end
end
local function encode(t)
 if type(t)~='table'then return tostring(t)end
 local keys={};for k in pairs(t)do keys[#keys+1]=k end;table.sort(keys)
 local out={};for _,k in ipairs(keys)do local v=encode(t[k]);out[#out+1]=tostring(k)..'='..#v..':'..v end
 return table.concat(out,';')
end
local function loadEntries(root)return compact.exact(assert(loadfile(root..'Scripts/tutorial_readings.lua'))())end
local function make(kind,outer,name)
 local w=StaticConstructObject(StaticFindObject('/Script/UMG.'..kind),outer,FName(name));assert(valid(w),'Could not create tutorial '..kind);return w
end

-- Pure layout: all prefix widths include the exact native InputAction tag.
-- Nothing estimates the icon from its height attribute or removes its markup.
function M.plan(entry,nativeWidth,rubyMeasure,metrics)
 local parts={};for _,s in ipairs(entry.segments)do parts[#parts+1]=s.text end
 local raw=table.concat(parts);local icon=raw:match('^(<InputAction [^>]+/>)')
 assert(icon and icon:find('id="BottomMedicine"',1,true),'Unsupported tutorial InputAction')
 assert(not raw:sub(#icon+1):find('[<>\r\n]'),'Only the observed leading icon and one plain text line are supported')
 local width=nativeWidth(raw);assert(near(width,metrics.width),'Native full-copy width differs from source')
 local iconWidth=nativeWidth(icon);assert(iconWidth>0 and iconWidth<width,'Native icon measurement unavailable')
 local cursor=1;local runs={}
 for index,s in ipairs(entry.segments)do
  local finish=cursor+#s.text-1
  if s.reading then
   assert(cursor>#icon and not s.text:find('[<>\r\n]'),'A reading crosses native markup')
   local left,right=nativeWidth(raw:sub(1,cursor-1)),nativeWidth(raw:sub(1,finish))
   assert(left>=iconWidth and right>left and right<=width+.05,'Invalid native glyph span')
   local rw,rh=rubyMeasure(s.reading,index)
   assert(finite(rw)and finite(rh)and rw>0 and rh>0,'Ruby measurement unavailable')
   local center=(left+right)/2
   local run={segment=index,text=s.text,reading=s.reading,baseLeft=left,baseRight=right,x=center-width/2,
    y=-metrics.height/2-rh-metrics.gap,width=rw,height=rh,ratio=.6}
   assert(center-rw/2>=iconWidth-0.05 and center+rw/2<=width+.05,'Ruby overlaps the native input icon or exceeds the source line')
   if #runs>0 then local previous=runs[#runs];assert(previous.x+previous.width/2+metrics.gap<=run.x-run.width/2,'Tutorial readings collide')end
   runs[#runs+1]=run
  end
  cursor=finish+1
 end
 assert(#runs>0 and #runs<=12,'Unsupported reading count')
 return {text=raw,iconMarkup=icon,iconWidth=iconWidth,width=width,runs=runs}
end

function M.detach(handle,log)
 if not handle then return true end;log=log or function()end
 local ok,err=pcall(function()
  for _,p in ipairs(handle.measurePaths or {})do local w=StaticFindObject(p);if valid(w)then w:RemoveFromParent()end end
  local b=handle.path and StaticFindObject(handle.path);if valid(b)then b:RemoveFromParent()end
  local overlay=handle.overlayPath and StaticFindObject(handle.overlayPath);if valid(overlay)then overlay:ForceLayoutPrepass()end
  local source=handle.sourcePath and StaticFindObject(handle.sourcePath)
  if valid(source)then
   local after=snapshot(source);handle.restoredUnchanged=pcall(function()same(handle.before,after,'tutorial restore')end)
  end
 end)
 if not ok then log('tutorial_restore_error '..tostring(err))end
 if ok then return true,handle.restoredUnchanged end
 return false,tostring(err)
end

function M.attach(w,state,log,root)
 log=log or function()end;local handle,stats
 local ok,err=pcall(function()
  local entries=state.tutorial_entries or loadEntries(root);local entry=entryFor(w,entries)
  assert(entry and visible(w),'Outside the exact visible Potion tutorial scope')
  local overlay=w:GetParent();assert(valid(overlay)and class(overlay)=='Overlay'and path(overlay):match('%.Overlay$'),'Unexpected tutorial parent')
  local before=snapshot(w);local a=before.source
  assert(#before.children==2 and before.children[1].path:match('%.Image_2$')and before.children[2].path==path(w),'Unobserved native potion children')
  assert(a.slotClass=='OverlaySlot'and a.horizontal==2 and a.vertical==2 and zero(a.padding),'Potion source must retain its centered zero-padding slot')
  assert(a.justification==0 and not a.autoWrap and a.wrap==0 and a.letterSpacing==0,'Unsupported tutorial text flow')
  assert(identity(a.transform)and identity(before.overlay.transform)and a.clipping==0 and before.overlay.clipping==0,'Unobserved potion transform or clipping')
  assert(a.desired.x>0 and a.desired.y>0 and near(a.rect.x,0)and near(a.rect.y,0),'Native potion geometry unavailable')
  local scale=a.desired.x/a.rect.width
  assert(scale>.05 and scale<=2 and near(a.desired.y,a.rect.height*scale*a.lineHeight),'Unproved native glyph-to-layout scaling')
  assert(a.desired.y<=before.overlay.desired.y+.05,'Potion source exceeds its overlay')
  state.serial=(state.serial or 0)+1;local prefix=PREFIX..state.serial..'_'
  handle={kind='tutorial',sourcePath=path(w),overlayPath=path(overlay),before=before,root=root,measurePaths={}}
  local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds');handle.path=path(bounds)
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(a.opacity)
  local slot=overlay:AddChildToOverlay(bounds);slot:SetHorizontalAlignment(2);slot:SetVerticalAlignment(2);slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
  local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Canvas');handle.canvasPath=path(canvas);canvas:SetVisibility(3);bounds:AddChild(canvas)
  local copy=StaticConstructObject(w:GetClass(),w:GetOuter(),FName(prefix..'MeasureRich'));assert(valid(copy),'Could not construct native rich measure')
  handle.measurePaths[#handle.measurePaths+1]=path(copy);copy:SetRenderOpacity(0);copy:SetVisibility(3)
  for _,field in ipairs({'PBZTextStyleSet','RichTextStyleConfig','bFindConfigTextStyleSet','SavedColorAndOpacity','DefaultColor','bUseCustomColor',
   'bUseWidgetLineHighSetting','bUseLineHighPercentageOnBottomLine','bTintInlineIcon','bDisplayAllCaps','MobileTextBlockScale','InlineIconDisplayMode',
   'TextSizeScaleConfigs','ScrollStyle','ScrollOrientation','MinDesiredWidth','TextTransformPolicy','TextOverflowPolicy',
   'ShapedTextOptions','WrappingPolicy','ApplyLineHeightToBottomLine','Margin','LineHeightPercentage'})do copy[field]=w[field]end
  copy:SetDecorators(w.DecoratorClasses);if valid(w.DefaultTextStyleOverrideClass)then copy:SetStyle(w.DefaultTextStyleOverrideClass)end
  copy:SetDisplayCultureOverride(a.culture);copy:SetTagStyleMapping(w.TagStyleMapping);copy:SetDefaultTextStyle(w.DefaultTextStyleOverride)
  copy:SetOutlineOverride(w.OutlineOverride);copy:OverrideTextColor(w.SavedColorAndOpacity,w.bUseCustomColor)
  copy:SetScrollingEnabled(w.bIsScrollingEnabled);copy:SetAutoWrapText(false);copy:SetWrapTextWidth(0);copy:SetJustification(0);copy:SetText(FText(a.text))
  local ms=canvas:AddChildToCanvas(copy);ms:SetAutoSize(true);overlay:ForceLayoutPrepass()
  copy:SetDefaultTextStyle(w.DefaultTextStyleOverride);copy:SetDefaultFont(w.DefaultTextStyleOverride.Font)
  copy:OverrideTextColor(w.SavedColorAndOpacity,w.bUseCustomColor);copy:RefreshTextLayout();overlay:ForceLayoutPrepass()
  same(a.rect,rect(copy),'native full-copy rectangle');assert(near(copy:GetDesiredSize().X,a.desired.x),'Native full-copy width mismatch')
  local widths={}
  local function nativeWidth(raw)
   if widths[raw]then return widths[raw]end
   copy:SetText(FText(raw));copy:RefreshTextLayout();overlay:ForceLayoutPrepass()
   local r=rect(copy);local desired=copy:GetDesiredSize()
   assert(near(desired.X,r.width*scale),'Native prefix scale changed')
   assert(near(copy.DefaultTextStyleOverride.Font.Size,a.fontSize),'Native copy font changed')
   widths[raw]=desired.X;return desired.X
  end
  local effectiveSize=a.fontSize*scale;local plain=make('TextBlock',w:GetOuter(),prefix..'MeasurePlain')
  handle.measurePaths[#handle.measurePaths+1]=path(plain)
  plain:SetFont(w.DefaultTextStyleOverride.Font);plain.Font.Size=effectiveSize;plain.Font.OutlineSettings.OutlineSize=0;plain:SetFont(plain.Font)
  plain:SetShadowOffset({X=0,Y=0});plain:SetAutoWrapText(false);plain:SetRenderOpacity(0);plain:SetVisibility(3)
  local ps=canvas:AddChildToCanvas(plain);ps:SetAutoSize(true)
  local icon=a.text:match('^(<InputAction [^>]+/>)');assert(icon,'Native input tag disappeared')
  plain:SetText(FText(a.text:sub(#icon+1)));overlay:ForceLayoutPrepass()
  local nativeTail=nativeWidth(a.text)-nativeWidth(icon);local plainTail=plain:GetDesiredSize().X
  assert(math.abs(nativeTail-plainTail)<=math.max(1,nativeTail*.01),'Effective text font does not reproduce native glyph widths')
  local widgets={}
  local function rubyMeasure(reading,index)
   local ruby=make('TextBlock',w:GetOuter(),prefix..'Reading_'..index)
   ruby:SetFont(w.DefaultTextStyleOverride.Font);ruby.Font.Size=effectiveSize*.6;ruby.Font.OutlineSettings.OutlineSize=0;ruby.Font.LetterSpacing=0;ruby:SetFont(ruby.Font)
   ruby:SetShadowOffset({X=0,Y=0});ruby:SetText(FText(reading));ruby:SetColorAndOpacity(w.DefaultTextStyleOverride.ColorAndOpacity)
   ruby:SetJustification(1);ruby:SetAutoWrapText(false);ruby:SetVisibility(3)
   local rs=canvas:AddChildToCanvas(ruby);rs:SetAutoSize(true);rs:SetAlignment({X=.5,Y=0});rs:SetZOrder(1)
   overlay:ForceLayoutPrepass();local d=ruby:GetDesiredSize();widgets[index]={widget=ruby,slot=rs}
   assert(d.Y<a.desired.y,'Ruby font exceeds the native source height');return d.X,d.Y
  end
  local plan=M.plan(entry,nativeWidth,rubyMeasure,{width=a.desired.x,height=a.desired.y,gap=2})
  assert(plan.text==a.text,'Tutorial segments differ from native source')
  for _,run in ipairs(plan.runs)do widgets[run.segment].slot:SetPosition({X=run.x,Y=run.y})end
  -- Check the full line again after prefix measurements and release all hidden
  -- decorators. Only the three ordinary TextBlock readings remain attached.
  copy:SetText(FText(a.text));copy:RefreshTextLayout();overlay:ForceLayoutPrepass()
  same(a.rect,rect(copy),'native repeat rectangle');assert(near(copy:GetDesiredSize().X,a.desired.x),'Native icon changed during attachment')
  copy:RemoveFromParent();plain:RemoveFromParent();handle.measurePaths={};overlay:ForceLayoutPrepass()
  assert(near(bounds:GetDesiredSize().X,0)and near(bounds:GetDesiredSize().Y,0),'Tutorial sibling contributes layout size')
  local after=snapshot(w);same(before,after,'tutorial native audit')
  stats={key=entry.key,runs=plan.runs,skipped={},remainingCollisions=0,iconWidth=plan.iconWidth,scale=scale,
   effectiveFontSize=effectiveSize,rubyFontSize=effectiveSize*.6,plainTailWidth=plainTail,nativeTailWidth=nativeTail,
   nativeGlyphHeight=a.rect.height*scale,sourceHeight=a.desired.y,sourceBefore=a,sourceAfter=after.source,
   sourceTextUnchanged=true,sourceFontUnchanged=true,sourceSizeUnchanged=true,sourceSubtreeUnchanged=true,sourceCultureUnchanged=true}
  handle.stats=stats
  log('tutorial_attached key='..entry.key..' runs='..#plan.runs..' iconWidth='..plan.iconWidth..' effectiveFont='..effectiveSize..' rubyFont='..effectiveSize*.6)
 end)
 if not ok then if handle then M.detach(handle,log)end;return nil,{reason=tostring(err),rollback=handle and handle.restoredUnchanged}end
 return handle,stats
end

function M.stop(state,log)
 state.tutorial_active=false;state.tutorial_tick=nil
 for _,layer in pairs(state.tutorial_layers or {})do M.detach(layer.handle,log)end
 state.tutorial_layers={};state.tutorial_pending={};state.tutorial_sources={};state.tutorial_entries=nil
end
function M.start(state,log,root)
 log=log or function()end;M.stop(state,log);state.tutorial_entries=loadEntries(root)
 state.tutorial_active=true;local ticks=0
 state.tutorial_tick=function()
  ticks=ticks+1
  if state.ruby_enabled==false then
   for _,layer in pairs(state.tutorial_layers)do M.detach(layer.handle,log)end
   state.tutorial_layers={};state.tutorial_pending={};return
  end
  -- Discovery is bounded and infrequent. The active widget itself is cached;
  -- no new decorators or measurements are created for an unchanged signature.
  if ticks==1 or ticks%8==0 then
   local all=FindAllOf('PBZCommonLocRichText')or{};assert(type(all)=='table','FindAllOf must return a Lua table')
   local found={};local count=0;for i=1,math.min(#all,2048)do local w=all[i]
    if M.scoped(w)and not found[path(w)]and count<8 then found[path(w)]=w;count=count+1 end
   end
   state.tutorial_sources=found
  end
  local seen={}
  for id,w in pairs(state.tutorial_sources)do
   if valid(w)then
    seen[id]=true
    local ok,err=pcall(function()
     local shown=entryFor(w,state.tutorial_entries)and visible(w)
     local signature=shown and encode(snapshot(w))or 'hidden-or-outside-scope'
     local layer=state.tutorial_layers[id]
     local attached=layer and StaticFindObject(layer.handle.path)
     if layer and (layer.signature~=signature or not valid(attached)or not valid(attached:GetParent()))then
      M.detach(layer.handle,log);state.tutorial_layers[id]=nil;state.tutorial_pending[id]=nil;layer=nil
     end
     if not shown then state.tutorial_pending[id]=nil;return end
     if not layer then
      local pending=state.tutorial_pending[id]
      if not pending or pending.signature~=signature then pending={signature=signature,ticks=0};state.tutorial_pending[id]=pending end
      pending.ticks=pending.ticks+1
      if pending.ticks==2 then
       local handle,stats=M.attach(w,state,log,root)
       if handle then state.tutorial_layers[id]={signature=signature,handle=handle,stats=stats}end
       log('tutorial_result key=Tutorial_Potion_3 '..(handle and 'attached'or tostring(stats.reason)))
      end
     end
    end)
    if not ok then
     local layer=state.tutorial_layers[id];if layer then M.detach(layer.handle,log);state.tutorial_layers[id]=nil end
     if state.tutorial_error~=tostring(err)then state.tutorial_error=tostring(err);log('tutorial_tick_error '..tostring(err))end
    end
   end
  end
  for id,layer in pairs(state.tutorial_layers)do if not seen[id]then M.detach(layer.handle,log);state.tutorial_layers[id]=nil;state.tutorial_pending[id]=nil end end
  for id in pairs(state.tutorial_pending)do if not seen[id]then state.tutorial_pending[id]=nil end end
 end
 if not state.tutorial_timer then
  state.tutorial_timer=true
  LoopInGameThreadWithDelay(250,function()
   -- This UE4SS build does not cancel a loop when the callback returns true.
   -- Keep one persistent callback across F6 cycles; stop only makes it inert.
   if not state.tutorial_active or not state.tutorial_tick then return end
   local ok,err=pcall(state.tutorial_tick)
   if not ok and state.tutorial_error~=tostring(err)then state.tutorial_error=tostring(err);log('tutorial_tick_error '..tostring(err))end
  end)
 end
 log('tutorial watcher active; exact Potion HUD only')
end
return M
