local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Five reviewed medicine descriptions with one native InputAction decorator.
-- Exact source/style preserved; same-class native rich copies retain the icon.
-- A placeholder is used ONLY by the pure layout planner; never shown/measured.
local M={}
local TAG='<InputAction id="HeavyAttack" height="26" RightPadding="5" LeftPadding="5"/>'
local ATOM=utf8.char(0xFFFC)
local KNOWN={["196:680a83a28f774698"]="Item_Medicine_FunctionDes_007_5",["196:b6a9a796c81dc326"]="Item_Medicine_FunctionDes_007_2",["196:d887b166e3750db1"]="Item_Medicine_FunctionDes_007_1",["196:d8bac94cd50e1d1f"]="Item_Medicine_FunctionDes_007_4",["196:ef9b62254b9013a6"]="Item_Medicine_FunctionDes_007"}
function M.matches(text)return KNOWN[compact.fingerprint(text)]end
local function valid(o)return o and o:IsValid()end
local function obj(o)return valid(o)and o:GetFullName()or ''end
local function class(o)return o:GetClass():GetFName():ToString()end
local function str(v)return type(v)=='string'and v or v:ToString()end
local function unwrap(v)local ok,x=pcall(function()return v:get()end);return ok and x or v end
local function list(a,limit,fn)
 local r={};local function add(v)assert(#r<limit,'Native array bound exceeded');r[#r+1]=fn(unwrap(v))end
 if type(a)=='table'then for _,v in ipairs(a)do add(v)end else a:ForEach(function(_,v)add(v)end)end;return r
end
local function near(a,b)return math.abs(a-b)<.08 end
local function equal(a,b,label)
 for k,v in pairs(a)do local q=b[k]
  if type(v)=='table'then assert(type(q)=='table',label..'.'..k);equal(v,q,label..'.'..k)
  elseif type(v)=='number'then assert(type(q)=='number'and near(v,q),label..'.'..k)
  else assert(v==q,label..'.'..k)end
 end
 for k in pairs(b)do assert(a[k]~=nil,label..'.extra.'..k)end
end
local function measure(w)
 local s=w:GetDesiredSize();return {desired={width=s.X,height=s.Y},lineHeight=w.LineHeightPercentage,
  rects=list(w:GetVisualLineRects(),32,function(r)return {x=r.X,y=r.Y,width=r.Z,height=r.W}end)}
end
local function decorators(w)
 return {classes=list(w.DecoratorClasses,32,obj),instances=list(w.InstanceDecorators,32,function(d)
  local r={class=class(d)}
  if r.class:find('InputAction',1,true)then
   for _,f in ipairs({'DataTable','InputActionMappingTable','ImageSet'})do r[f]=obj(d[f])end
   for _,f in ipairs({'FixedLeftPadding','FixedRightPadding','DefaultLeftPadding','DefaultRightPadding'})do r[f]=d[f]end
  end;return r
 end)}
end
local function margin(p)return {Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom}end
local function audit(w)
 local s=w.DefaultTextStyleOverride;local f=s.Font;local c=s.ColorAndOpacity;local q=c.SpecifiedColor
 return {text=str(w:GetText()),key=str(w.LocText.Key),namespace=str(w.LocText.Namespace),culture=str(w.DisplayCultureOverride),
  font={object=obj(f.FontObject),size=f.Size,typeface=str(f.TypefaceFontName),spacing=f.LetterSpacing,outline=f.OutlineSettings.OutlineSize},
  color={q.R,q.G,q.B,q.A,c.ColorUseRule},opacity=w:GetRenderOpacity(),visibility=w:GetVisibility(),
  parent=obj(w:GetParent()),slot=obj(w.Slot),padding=margin(w.Slot.Padding),horizontal=w.Slot.HorizontalAlignment,vertical=w.Slot.VerticalAlignment,
  layout=measure(w),wrap=w.WrapTextAt,autoWrap=w.AutoWrapText,justification=w.Justification,decorators=decorators(w)}
end
local function parent(w)
 local p=w:GetParent();if not valid(p)then local t=w:GetOuter();if valid(t)and class(t)=='WidgetTree'then p=t:GetOuter()end end;return valid(p)and p or nil
end
local function owner(w)
 assert(class(w)=='PBZCommonLocRichText','Not a native PBZ rich body')
 local n=obj(w);assert(n:find('/Engine/Transient',1,true)and not n:find('Default__',1,true),'Not a transient source')
 assert(n:find('.W_UnifiedTextDescription.',1,true)and n:find('.DetailText.',1,true)and n:find('.W_PBZItemDescText_C_',1,true)
  and n:match('%.PBZCommonLocRichText_34$'),'Not a dynamic medicine paragraph')
 assert(not n:find('.WB_Literature.',1,true),'Book hosts are prohibited')
 local p=w;local foundDetail,foundCharacter,foundInventory=false,false,false;local seen={};local ended=false
 for _=1,45 do
  if not valid(p)then ended=true;break end
  assert(not seen[obj(p)],'Cyclic native item ancestry');seen[obj(p)]=true
  assert(p:GetVisibility()~=1 and p:GetVisibility()~=2 and p:GetRenderOpacity()>.01,'Native source/ancestor is hidden')
  local c=class(p);foundDetail=foundDetail or c=='W_UnifiedTextDescription_C'
  foundCharacter=foundCharacter or c=='WB_Character_V4_C';foundInventory=foundInventory or c=='WB_Inventory_C'
  local up=parent(p)
  if valid(up)and (class(up)=='WidgetSwitcher'or class(up)=='PBZCommonVisibilitySwitcher'or class(up)=='CommonVisibilitySwitcher')then assert(obj(up:GetActiveWidget())==obj(p),'Native ancestor not selected')end
  p=up
 end
 assert(ended,'Native item ancestry exceeded the supported bound')
 assert(foundDetail and (foundCharacter or foundInventory),'No real item menu owner')
 assert(class(w:GetParent())=='Overlay'and class(w.Slot)=='OverlaySlot','Unsupported native body parent')
 return foundCharacter and 'actual_character_medicine_description'or 'actual_inventory_description'
end
local function path(w)return w:GetFullName():match('^[^ ]+ (.+)$')end
local function refresh(w)
 local seen={}
 for _=1,45 do
  if not valid(w)then return end
  local n=obj(w);assert(not seen[n],'Cyclic native item ancestry');seen[n]=true
  w:ForceLayoutPrepass();w=parent(w)
 end
 error('Unbounded native item ancestry')
end
local function expanded(text)return (text:gsub(ATOM,function()return TAG end))end
function M.plan_segments(raw,segments)
 assert(KNOWN[compact.fingerprint(raw)],'Only five exact reviewed InputAction sources are supported')
 local joined={};local parts={};local count=0;local atoms=0
 for i,s in ipairs(segments)do
  joined[#joined+1]=s.text
  local p={};for k,v in pairs(s)do p[k]=v end
  if s.text:find('<',1,true)then
   assert(not s.reading,'An icon tag cannot receive ruby')
   local a,b=s.text:find(TAG,1,true);assert(a,'Tag must remain whole inside an unannotated segment')
   p.text=s.text:sub(1,a-1)..ATOM..s.text:sub(b+1);atoms=atoms+1
  end
  assert(not p.text:find('[<>]'),'Foreign or fragmented item markup')
  if p.reading then count=count+1 end
  parts[i]=p
 end
 assert(table.concat(joined)==raw and atoms==1 and count==10,'Exact source/ten-reading manifest mismatch')
 local text={};for _,s in ipairs(parts)do text[#text+1]=s.text end
 text=table.concat(text);assert(expanded(text)==raw,'Atomic icon roundtrip failed')
 return text,parts,count
end
local function cloneRich(w,canvas,overlay,name,raw,wrapped)
 local copy=StaticConstructObject(w:GetClass(),w:GetOuter(),FName(name));assert(valid(copy),'Cannot construct same-class native item copy')
 copy:SetRenderOpacity(0);copy:SetVisibility(3)
 -- Attach immediately, so every subsequent error is owned by the bounds cleanup.
 local slot=canvas:AddChildToCanvas(copy);slot:SetAutoSize(true)
 for _,field in ipairs({'PBZTextStyleSet','RichTextStyleConfig','bFindConfigTextStyleSet','SavedColorAndOpacity','DefaultColor','bUseCustomColor',
  'bUseWidgetLineHighSetting','bUseLineHighPercentageOnBottomLine','bTintInlineIcon','bDisplayAllCaps','MobileTextBlockScale','InlineIconDisplayMode',
  'TextSizeScaleConfigs','ScrollStyle','ScrollOrientation','MinDesiredWidth','TextTransformPolicy','TextOverflowPolicy','ShapedTextOptions',
  'WrappingPolicy','ApplyLineHeightToBottomLine','Margin','LineHeightPercentage'})do copy[field]=w[field]end
 copy:SetDecorators(w.DecoratorClasses)
 if valid(w.DefaultTextStyleOverrideClass)then copy:SetStyle(w.DefaultTextStyleOverrideClass)end
 copy:SetDisplayCultureOverride(str(w.DisplayCultureOverride));copy:SetTagStyleMapping(w.TagStyleMapping)
 copy:SetDefaultTextStyle(w.DefaultTextStyleOverride);copy:SetOutlineOverride(w.OutlineOverride)
 copy:OverrideTextColor(w.SavedColorAndOpacity,w.bUseCustomColor);copy:SetScrollingEnabled(w.bIsScrollingEnabled)
 copy:SetAutoWrapText(wrapped and w.AutoWrapText or false);copy:SetWrapTextWidth(wrapped and w.WrapTextAt or 0);copy:SetJustification(w.Justification)
 copy:SetText(FText(raw));refresh(overlay)
 copy:SetDefaultTextStyle(w.DefaultTextStyleOverride);copy:SetDefaultFont(w.DefaultTextStyleOverride.Font)
 copy:OverrideTextColor(w.SavedColorAndOpacity,w.bUseCustomColor);copy:RefreshTextLayout();refresh(overlay)
 return copy,slot
end
function M.detach(handle,log)
 if not handle then return true end;log=log or function()end
 local errors={};local function attempt(label,fn)local ok,e=pcall(fn);if not ok then errors[#errors+1]=label..': '..tostring(e)end end
 local layer=handle.path and StaticFindObject(handle.path)
 if valid(layer)then attempt('remove copies',function()layer:RemoveFromParent()end)end
 local w=StaticFindObject(handle.sourcePath)
 if valid(w)then
  attempt('restore opacity',function()w:SetRenderOpacity(handle.originalOpacity)end)
  attempt('restore padding',function()
   assert(valid(w.Slot)and path(w.Slot)==handle.slotPath,'Original source slot was replaced')
   local p=margin(w.Slot.Padding)
   local originalOk=pcall(equal,p,handle.originalPadding,'Original padding')
   local appliedOk=handle.appliedPadding and pcall(equal,p,handle.appliedPadding,'Applied padding')
   assert(originalOk or appliedOk,'Source padding changed externally')
   w.Slot:SetPadding(margin(handle.originalPadding))
  end)
  attempt('audit source',function()
   refresh(w);handle.restoreAudit=audit(w);equal(handle.sourceBefore,handle.restoreAudit,'Restored native item source')
   assert(w:GetParent():GetChildrenCount()==handle.originalChildren,'Temporary item icon child remained')
  end)
 end
 handle.restoreErrors=errors;handle.restored=#errors==0
 if #errors>0 then log('item_icon_restore_error '..table.concat(errors,'; '));return false,table.concat(errors,'; ')end
 return true,handle.restoreAudit
end
function M.attach(w,segments,state,log,root,options)
 options=options or {};log=log or function()end;local h;local stats
 local ok,why=pcall(function()
  assert(valid(w),'Invalid item source');local host=owner(w)
  local raw=str(w:GetText());local key=assert(KNOWN[compact.fingerprint(raw)],'Not one of five reviewed icon bodies')
  local layoutText,parts,expected=M.plan_segments(raw,segments)
  local before=audit(w);local font=w.DefaultTextStyleOverride.Font
  assert(before.wrap>0 and not before.autoWrap and before.justification==0,'Only measured fixed-width left-aligned item text is supported')
  assert(before.font.outline==0 and before.font.spacing==0,'Unmeasured item outline/letter spacing')
  local style=w.DefaultTextStyleOverride
  assert(style.ShadowOffset.X==0 and style.ShadowOffset.Y==0,'Unmeasured native item shadow')
  local tr=w.RenderTransform
  assert(tr.Translation.X==0 and tr.Translation.Y==0 and tr.Scale.X==1 and tr.Scale.Y==1 and tr.Shear.X==0 and tr.Shear.Y==0 and tr.Angle==0,'Unmeasured native item transform')
  assert((w.Slot.HorizontalAlignment==0 or w.Slot.HorizontalAlignment==1)and w.Slot.VerticalAlignment==1,'Unmeasured native item slot alignment')
  assert(#before.layout.rects>0 and #before.layout.rects<=5,'Unexpected native icon paragraph lines')
  local input=false;for _,d in ipairs(before.decorators.instances)do if d.class:find('InputAction',1,true)then input=true end end
  assert(input,'Native InputAction decorator is absent')
  local overlay=w:GetParent();local originalChildren=overlay:GetChildrenCount()
  local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
  state.serial=(state.serial or 0)+1;local prefix='PBZFurigana_ItemIcon_'..state.serial..'_'
  local function make(c,n)local o=StaticConstructObject(StaticFindObject('/Script/UMG.'..c),w:GetOuter(),FName(prefix..n));assert(valid(o));return o end
  local bounds=make('SizeBox','Bounds')
  h={kind='item_input_action',path=path(bounds),sourcePath=path(w),slotPath=path(w.Slot),sourceBefore=before,
   originalOpacity=before.opacity,originalPadding=before.padding,originalChildren=originalChildren}
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(0)
  local bs=overlay:AddChildToOverlay(bounds);bs:SetHorizontalAlignment(0);bs:SetVerticalAlignment(0);bs:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
  local canvas=make('CanvasPanel','Canvas');canvas:SetVisibility(3);h.canvasPath=path(canvas)
  local cs=bounds:AddChild(canvas);cs:SetHorizontalAlignment(0);cs:SetVerticalAlignment(0)
  local measureCopy=cloneRich(w,canvas,overlay,prefix..'Measure',raw,true)
  equal(before.layout,measure(measureCopy),'Full native icon clone')
  equal(before.decorators,decorators(measureCopy),'Native icon decorator configuration')
  measureCopy:SetAutoWrapText(false);measureCopy:SetWrapTextWidth(0)
  local widths={['']=0};local measurements=0
  local function width(text)
   if widths[text]~=nil then return widths[text]end
   measurements=measurements+1;assert(measurements<=400,'Bounded icon measurement limit')
   local textRaw=expanded(text)
   assert(not textRaw:find(ATOM,1,true),'Internal icon placeholder must never reach native text')
   measureCopy:SetText(FText(textRaw));measureCopy:RefreshTextLayout();refresh(overlay)
   local m=measure(measureCopy);assert(#m.rects==1 and m.desired.width>0,'Native atomic line measurement unavailable')
   assert(near(m.rects[1].width,m.desired.width),'Native line advance and desired width disagree')
   widths[text]=m.desired.width;return widths[text]
  end
  local iconWidth=width(ATOM)
  local plan,reason=renderer.layout(layoutText,parts,before.layout.rects,width,.08,{},
   {forceWordWrap=true,keepReadingWords=true,availableWidth=before.wrap,justification=0})
  assert(plan,reason);assert(#plan.runs==expected and #plan.skipped==0,'An icon paragraph reading was omitted')
  local bodySizes,bodyWidgets,rebuilt={},{},{}
  for i,line in ipairs(plan.lines)do
   local text=expanded(line.text);rebuilt[#rebuilt+1]=text
   local copy,slot=cloneRich(w,canvas,overlay,prefix..'Body_'..i,text,false)
   equal(before.decorators,decorators(copy),'Line native decorator configuration')
   local m=measure(copy);assert(#m.rects==1 and near(m.desired.width,width(line.text)),'Reflow line differs from native measured copy')
   assert(m.desired.width<=before.wrap+.08,'Reflow body exceeds original wrap width')
   bodySizes[i]={width=m.desired.width,height=m.desired.height};bodyWidgets[i]={widget=copy,slot=slot}
  end
  assert(table.concat(rebuilt)==raw,'Reflow changed native text/icon order')
  local rubyWidgets={};local candidates={}
  for _,run in ipairs(plan.runs)do
   local ruby=make('TextBlock','Ruby_'..run.segment);ruby:SetFont(font)
   ruby.Font.Size=font.Size*.6;ruby.Font.LetterSpacing=0;ruby:SetFont(ruby.Font)
   ruby:SetText(FText(run.reading));ruby:SetColorAndOpacity(style.ColorAndOpacity);ruby:SetShadowOffset({X=0,Y=0})
   ruby:SetAutoWrapText(false);ruby:SetJustification(1);ruby:SetVisibility(3)
   local slot=canvas:AddChildToCanvas(ruby);slot:SetAutoSize(true);slot:SetAlignment({X=.5,Y=0});slot:SetZOrder(1)
   refresh(overlay);local d=ruby:GetDesiredSize()
   run.width=d.X;run.height=d.Y;run.ratio=.6;candidates[#candidates+1]=run;rubyWidgets[run.segment]={widget=ruby,slot=slot}
  end
  local function resize(run,ratio)
   local ruby=rubyWidgets[run.segment].widget;ruby.Font.Size=font.Size*ratio;ruby:SetFont(ruby.Font)
   refresh(overlay);local d=ruby:GetDesiredSize();return d.X,d.Y
  end
  local fitted=renderer.fit_subtitle_horizontal(candidates,resize,{minimumRatio=.45,horizontalGap=2})
  assert(not fitted.reason,fitted.reason);assert(#fitted.skipped==0 and fitted.remainingCollisions==0,'Icon paragraph ruby collision')
  for _,r in ipairs(fitted.runs)do
   r.width,r.height=resize(r,r.ratio);r.fontSize=font.Size*r.ratio
   assert(r.x-r.width/2>=-.08 and r.x+r.width/2<=before.wrap+.08,'Ruby exceeds the native item width')
  end
  local lines,reflow=renderer.reflow(plan.lines,fitted.runs,bodySizes,{gap=1,reflowRowGap=2,reflowLineHeight=1.7})
  local reserve=0;for _,r in ipairs(fitted.runs)do if r.line==1 then reserve=math.max(reserve,r.height+1)end end
  reserve=math.ceil(reserve)
  local last=lines[#lines];local expandedHeight=last.y+last.height
  local added=math.max(0,expandedHeight-before.layout.desired.height)
  for i,line in ipairs(lines)do
   local v=bodyWidgets[i];v.slot:SetPosition({X=before.padding.Left+line.x,Y=before.padding.Top+reserve+line.y});v.widget:SetRenderOpacity(1)
   line.text=rebuilt[i];line.visibleText=nil
  end
  local vertical=0
  for _,r in ipairs(fitted.runs)do
   local line=lines[r.line];r.y=before.padding.Top+reserve+line.y-r.height-1
   local x=before.padding.Left+r.x;rubyWidgets[r.segment].slot:SetPosition({X=x,Y=r.y})
   if r.line>1 then local previous=lines[r.line-1];if r.y<before.padding.Top+reserve+previous.y+previous.height+1-.08 then vertical=vertical+1 end end
  end
  assert(vertical==0,'Ruby overlaps previous native line/icon')
  -- Recheck the full wrapped clone immediately before any source mutation.
  measureCopy:SetAutoWrapText(w.AutoWrapText);measureCopy:SetWrapTextWidth(w.WrapTextAt);measureCopy:SetText(FText(raw))
  measureCopy:RefreshTextLayout();refresh(overlay);equal(before.layout,measure(measureCopy),'Full native clone repeat')
  equal(before.decorators,decorators(measureCopy),'Repeated native decorator configuration');measureCopy:RemoveFromParent()
  equal(before,audit(w),'Source before reveal')
  h.appliedPadding={Left=before.padding.Left,Top=before.padding.Top+reserve,Right=before.padding.Right,Bottom=before.padding.Bottom+added}
  w.Slot:SetPadding(margin(h.appliedPadding));w:SetRenderOpacity(0);bounds:SetRenderOpacity(before.opacity);refresh(overlay)
  assert(overlay:GetChildrenCount()==originalChildren+1,'Unexpected item icon sibling count')
  local after=audit(w);local expectedAfter={};for k,v in pairs(before)do expectedAfter[k]=v end
  expectedAfter.opacity=0;expectedAfter.padding=h.appliedPadding;equal(expectedAfter,after,'Source after reversible icon reflow')
  stats={key=key,host=host,runs=fitted.runs,lines=lines,skipped={},horizontalCollisions=0,verticalCollisions=0,
   richText=true,sourceBefore=before,sourceAfter=after,sourceTextUnchanged=true,sourceFontUnchanged=true,sourceSizeUnchanged=true,
   topReserve=reserve,addedBottomPadding=added,reflow=reflow,iconWidth=iconWidth,atomicTag=TAG,iconCount=1,
   measurementCount=measurements,fullNativeCloneVerified=true,fullNativeRepeatVerified=true,decoratorsVerified=true,
   expected=expected,covered=#fitted.runs,adjustments=fitted.adjustments,ratio=.6,minimumRatio=.45}
  h.stats=stats;log('item_icon_attached '..key..' runs='..#stats.runs..' iconWidth='..iconWidth..' lines='..#lines)
 end)
 if not ok then
  local restored,restoreReason=true,nil;if h then restored,restoreReason=M.detach(h,log)end
  return nil,{reason=tostring(why),rollback=restored,rollbackReason=restoreReason,sourceBefore=h and h.sourceBefore}
 end
 return h,stats
end
return M
