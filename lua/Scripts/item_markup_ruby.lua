local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- 37 exact reviewed item bodies with one native language-style tag type.
-- Tags are retained in every native copy; Bold is a pure-planner alias only.
-- No generic icon/img/Niagara path; no shared renderer modification.
local M={}
local OPEN='<Character_Yellow_Decorator2>'
local KNOWN={["122:207334ac171b95a9"]={["expected"]=8,["key"]="WeaponDes_020"},["125:c903f669aa0d47e1"]={["expected"]=10,["key"]="WeaponDes_014"},["131:199776bc448f3732"]={["expected"]=12,["key"]="WeaponDes_010"},["131:701af34c3d86ff56"]={["expected"]=9,["key"]="PhantomEdgesDes_001"},["149:5b418261971984a5"]={["expected"]=11,["key"]="WeaponDes_024"},["152:b87884ec2ce471ec"]={["expected"]=16,["key"]="WeaponDes_029"},["164:9075c33256194443"]={["expected"]=14,["key"]="WeaponDes_026"},["167:951080884e0d253c"]={["expected"]=14,["key"]="PhantomEdgesDes_002"},["167:b5305c73d604e2f9"]={["expected"]=15,["key"]="PhantomEdgesDes_005"},["170:354b1556bdff9ca9"]={["expected"]=14,["key"]="WeaponDes_007"},["170:ccc2d47fe83551f7"]={["expected"]=15,["key"]="PhantomEdgesDes_012"},["173:d9a199e4e43d74e2"]={["expected"]=11,["key"]="WeaponDes_027"},["185:653265bb1185f3a3"]={["expected"]=13,["key"]="WeaponDes_015"},["185:735cbb571a54c29b"]={["expected"]=14,["key"]="PhantomEdgesDes_019"},["185:a1995e7dd55f8f27"]={["expected"]=15,["key"]="PhantomEdgesDes_024"},["185:be139904e2fa9b23"]={["expected"]=15,["key"]="PhantomEdgesDes_109"},["193:2287294b6d3c53da"]={["expected"]=10,["key"]="WeaponDes_028"},["193:e59f0302c24d877d"]={["expected"]=9,["key"]="PhantomEdgesDes_004"},["194:8c939a34deeb2525"]={["expected"]=17,["key"]="PhantomEdgesDes_020"},["199:79655698954245ee"]={["expected"]=8,["key"]="WeaponDes_018"},["200:5ffed9c478e3a252"]={["expected"]=21,["key"]="PhantomEdgesDes_011"},["200:fdea79c70f5cf284"]={["expected"]=12,["key"]="WeaponDes_009"},["205:ad5dec1d7f9ec911"]={["expected"]=11,["key"]="WeaponDes_002"},["211:8265b84f93279f51"]={["expected"]=14,["key"]="WeaponDes_031"},["212:639d8b630f532e6c"]={["expected"]=19,["key"]="WeaponDes_023"},["214:098a051a429c4420"]={["expected"]=15,["key"]="WeaponDes_017"},["220:e303e8c1007d4bf3"]={["expected"]=13,["key"]="WeaponDes_005"},["230:ddb8d3942a7a0ae6"]={["expected"]=18,["key"]="PhantomEdgesDes_014"},["238:b6b3a9d576984a66"]={["expected"]=14,["key"]="WeaponDes_019"},["239:488832aa6f3d5157"]={["expected"]=18,["key"]="WeaponDes_103"},["242:df5b7f4231bb7655"]={["expected"]=19,["key"]="PhantomEdgesDes_124"},["262:0a5b53be6050530f"]={["expected"]=16,["key"]="WeaponDes_008"},["269:126c86900a64f81a"]={["expected"]=23,["key"]="PhantomEdgesDes_125"},["277:4e80426b60ff0500"]={["expected"]=19,["key"]="PhantomEdgesDes_017"},["287:a1badef10e7be2e7"]={["expected"]=25,["key"]="PhantomEdgesDes_016"},["300:df78e4ba413c3a46"]={["expected"]=16,["key"]="WeaponDes_030"},["303:873e70a9367e7684"]={["expected"]=20,["key"]="WeaponDes_013"}}
function M.matches(text)local e=KNOWN[compact.fingerprint(text)];return e and e.key or nil end
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
  if r.class=='BP_Decorator2_C'then
   r.defaultStyle=obj(d.DefaultStyle);r.styleSet={};local count=0
   local function add(k,v)count=count+1;assert(count<=32,'Language style map bound');r.styleSet[str(unwrap(k))]=obj(unwrap(v))end
   if type(d.StyleSet)=='table'then for k,v in pairs(d.StyleSet)do add(k,v)end else d.StyleSet:ForEach(add)end
  elseif r.class:find('InputAction',1,true)then
   for _,f in ipairs({'DataTable','InputActionMappingTable','ImageSet'})do r[f]=obj(d[f])end
   for _,f in ipairs({'FixedLeftPadding','FixedRightPadding','DefaultLeftPadding','DefaultRightPadding'})do r[f]=d[f]end
  end;return r
 end)}
end
local function margin(p)return {Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom}end
local function resolvedStyle(w)
 local f=w.DefaultTextStyleOverride.Font;local c=w.DefaultTextStyleOverride.ColorAndOpacity;local q=c.SpecifiedColor
 local tags={};local n=0
 local function add(k,v)n=n+1;assert(n<=32,'Style mapping bound');tags[str(unwrap(k))]=str(unwrap(v))end
 if type(w.TagStyleMapping)=='table'then for k,v in pairs(w.TagStyleMapping)do add(k,v)end else w.TagStyleMapping:ForEach(add)end
 local excluded={}
 if valid(w.RichTextStyleConfig)then excluded=list(w.RichTextStyleConfig.ColorOnlyExcludedTags,32,str)end
 return{font={object=obj(f.FontObject),material=obj(f.FontMaterial),size=f.Size,typeface=str(f.TypefaceFontName),spacing=f.LetterSpacing,outline=f.OutlineSettings.OutlineSize},
  defaultColor={q.R,q.G,q.B,q.A,c.ColorUseRule},styleClass=obj(w.DefaultTextStyleOverrideClass),pbzStyleSet=obj(w.PBZTextStyleSet),
  richConfig=obj(w.RichTextStyleConfig),culture=str(w.DisplayCultureOverride),resolvedCulture=str(w:GetDisplayCultureName()),
  tagMapping=tags,colorOnlyExcludedTags=excluded,useCustomColor=w.bUseCustomColor,
  useWidgetLineHeight=w.bUseWidgetLineHighSetting,lineHeight=w.LineHeightPercentage,scrollStyle=obj(w.ScrollStyle),scrollingEnabled=w.bIsScrollingEnabled}
end
local function audit(w,released)
 local s=w.DefaultTextStyleOverride;local f=s.Font;local c=s.ColorAndOpacity;local q=c.SpecifiedColor
 local result={text=str(w:GetText()),key=str(w.LocText.Key),namespace=str(w.LocText.Namespace),culture=str(w.DisplayCultureOverride),
  font={object=obj(f.FontObject),size=f.Size,typeface=str(f.TypefaceFontName),spacing=f.LetterSpacing,outline=f.OutlineSettings.OutlineSize},
  color={q.R,q.G,q.B,q.A,c.ColorUseRule},opacity=w:GetRenderOpacity(),visibility=w:GetVisibility(),
  parent=obj(w:GetParent()),slot=obj(w.Slot),padding=margin(w.Slot.Padding),horizontal=w.Slot.HorizontalAlignment,vertical=w.Slot.VerticalAlignment,
  wrap=w.WrapTextAt,autoWrap=w.AutoWrapText,justification=w.Justification}
 if not released then result.layout=measure(w);result.decorators=decorators(w);result.resolvedStyle=resolvedStyle(w)end
 return result
end
local function parent(w)
 local p=w:GetParent();if not valid(p)then local t=w:GetOuter();if valid(t)and class(t)=='WidgetTree'then p=t:GetOuter()end end;return valid(p)and p or nil
end
local function releasedPickup(w)
 for _=1,45 do
  if not valid(w)then return false end
  if class(w)=='W_pickupgear_C'then
   return not w:IsActivated() and not w:IsInViewport() and not valid(w:GetParent())
  end
  w=parent(w)
 end
 return false
end
local function owner(w)
 assert(class(w)=='PBZCommonLocRichText','Not a native PBZ rich body')
 local n=obj(w);assert(n:find('/Engine/Transient',1,true)and not n:find('Default__',1,true),'Not a transient source')
 local weapon=n:find('.W_UnifiedTextDescription_Weapon.',1,true)~=nil
 local pickup=weapon and n:match('%.W_pickupgear_C_%d+%.WidgetTree_%d+%.W_UnifiedTextDescription_Weapon%.')
 assert((n:find('.W_UnifiedTextDescription.',1,true)or weapon)and n:find('.DetailText.',1,true)and n:find('.W_PBZItemDescText_C_',1,true)
  and n:match('%.PBZCommonLocRichText_34$'),'Not a supported native item detail paragraph')
 assert(not n:find('.WB_Literature.',1,true),'Book hosts are prohibited')
 local p=w;local foundDetail,foundCharacter,foundInventory,foundPickup=false,false,false,false;local seen={};local ended=false
 for _=1,45 do
  if not valid(p)then ended=true;break end
  assert(not seen[obj(p)],'Cyclic native item ancestry');seen[obj(p)]=true
  assert(p:GetVisibility()~=1 and p:GetVisibility()~=2 and p:GetRenderOpacity()>.01,'Native source/ancestor is hidden')
  local c=class(p);foundDetail=foundDetail or c=='W_UnifiedTextDescription_C'or c=='W_UnifiedTextDescription_Weapon_C'
  foundCharacter=foundCharacter or c=='WB_Character_V4_C';foundInventory=foundInventory or c=='WB_Inventory_C'
  foundPickup=foundPickup or (pickup and c=='W_pickupgear_C')
  local up=parent(p)
  if valid(up)and (class(up)=='WidgetSwitcher'or class(up)=='PBZCommonVisibilitySwitcher'or class(up)=='CommonVisibilitySwitcher')then assert(obj(up:GetActiveWidget())==obj(p),'Native ancestor not selected')end
  p=up
 end
 assert(ended,'Native item ancestry exceeded the supported bound')
 assert(foundDetail and (foundCharacter or foundInventory or foundPickup),'No real item menu or pickup owner')
 assert(class(w:GetParent())=='Overlay'and class(w.Slot)=='OverlaySlot','Unsupported native body parent')
 if foundPickup then return 'actual_pickup_weapon_description' end
 return weapon and 'actual_character_weapon_description'or foundCharacter and 'actual_character_medicine_description'or 'actual_inventory_description'
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
function M.plan_segments(raw,segments,renderer)
 local known=assert(KNOWN[compact.fingerprint(raw)],'Only 37 exact pure-style item sources are supported')
 assert(type(segments)=='table'and #segments<=256,'Pure-style segment bound exceeded')
 local joined,aliased,count={},{},0
 for i,s in ipairs(segments)do
  assert(type(s.text)=='string','Missing source segment text');joined[#joined+1]=s.text
  local q={};for k,v in pairs(s)do q[k]=v end
  q.text=s.text:gsub(OPEN,'<Bold>');aliased[i]=q
  if s.reading then assert(s.reading~=''and not s.text:find('[<>]'),'A reading cannot overlap style markup');count=count+1 end
 end
 assert(table.concat(joined)==raw and count==known.expected,'Frozen pure-style source/reading count mismatch')
 local alias=raw:gsub(OPEN,'<Bold>');local parsed,why=renderer.parse_rich_text(alias,aliased);assert(parsed,why)
 local rebuilt=renderer.rich_slice(parsed,1,#parsed.visible,{Bold='Character_Yellow_Decorator2'})
 assert(rebuilt==raw,'Pure-style source/tag roundtrip failed')
 parsed.sourceOriginal=raw
 for i,s in ipairs(segments)do if s.reading then assert(parsed.segments[i].text==s.text,'Style parser changed a reviewed reading span')end end
 return parsed,count
end
local function slice(renderer,parsed,first,last)
 local raw=renderer.rich_slice(parsed,first,last,{Bold='Character_Yellow_Decorator2'})
 assert(not raw:find('<Bold>',1,true),'Planner alias must never enter native text')
 return raw
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
   local released=handle.stats and handle.stats.host=='actual_pickup_weapon_description'and releasedPickup(w)
   local expected=handle.sourceBefore
   if released then
    -- Removing the native popup releases Slate's decorator instances and its
    -- cached lines. Its UObject text, style, slots and opacity still restore.
    expected={};for k,v in pairs(handle.sourceBefore)do
     if k~='layout'and k~='decorators'and k~='resolvedStyle'then expected[k]=v end
    end
   else refresh(w)end
   handle.restoreAudit=audit(w,released);equal(expected,handle.restoreAudit,'Restored native item source')
   handle.nativeSlateReleased=not not released
   assert(w:GetParent():GetChildrenCount()==handle.originalChildren,'Temporary pure-style child remained')
  end)
 end
 handle.restoreErrors=errors;handle.restored=#errors==0
 if #errors>0 then log('item_markup_restore_error '..table.concat(errors,'; '));return false,table.concat(errors,'; ')end
 return true,handle.restoreAudit
end
function M.attach(w,segments,state,log,root,options)
 options=options or {};log=log or function()end;local h;local stats
 local ok,why=pcall(function()
  assert(valid(w),'Invalid item source');local host=owner(w)
  local raw=str(w:GetText());local known=assert(KNOWN[compact.fingerprint(raw)],'Not one of 37 reviewed pure-style bodies');local key=known.key
  local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
  local parsed,expected=M.plan_segments(raw,segments,renderer)
  local layoutText,parts=parsed.visible,parsed.segments
  local before=audit(w);local font=w.DefaultTextStyleOverride.Font
  assert(before.resolvedStyle.resolvedCulture=='ja','Pure-style adapter requires the native Japanese culture')
  assert(before.wrap>0 and not before.autoWrap and before.justification==0,'Only measured fixed-width left-aligned item text is supported')
  assert(before.font.outline==0 and before.font.spacing==0,'Unmeasured item outline/letter spacing')
  local style=w.DefaultTextStyleOverride
  assert(style.ShadowOffset.X==0 and style.ShadowOffset.Y==0,'Unmeasured native item shadow')
  local tr=w.RenderTransform
  assert(tr.Translation.X==0 and tr.Translation.Y==0 and tr.Scale.X==1 and tr.Scale.Y==1 and tr.Shear.X==0 and tr.Shear.Y==0 and tr.Angle==0,'Unmeasured native item transform')
  assert((w.Slot.HorizontalAlignment==0 or w.Slot.HorizontalAlignment==1)and w.Slot.VerticalAlignment==1,'Unmeasured native item slot alignment')
  assert(#before.layout.rects>0 and #before.layout.rects<=12,'Unexpected native style paragraph lines')
  local language=false;for _,d in ipairs(before.decorators.instances)do if d.class=='BP_Decorator2_C'then language=true end end
  assert(language,'Native language-style decorator is absent')
  local overlay=w:GetParent();local originalChildren=overlay:GetChildrenCount()
  assert(originalChildren<=16,'Unexpected pure-style parent child count')
  state.serial=(state.serial or 0)+1;local prefix='PBZFurigana_ItemMarkup_'..state.serial..'_'
  local function make(c,n)local o=StaticConstructObject(StaticFindObject('/Script/UMG.'..c),w:GetOuter(),FName(prefix..n));assert(valid(o));return o end
  local bounds=make('SizeBox','Bounds')
  h={kind='item_style_markup',path=path(bounds),sourcePath=path(w),slotPath=path(w.Slot),sourceBefore=before,
   originalOpacity=before.opacity,originalPadding=before.padding,originalChildren=originalChildren}
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(0)
  local bs=overlay:AddChildToOverlay(bounds);bs:SetHorizontalAlignment(0);bs:SetVerticalAlignment(0);bs:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
  local canvas=make('CanvasPanel','Canvas');canvas:SetVisibility(3);h.canvasPath=path(canvas)
  local cs=bounds:AddChild(canvas);cs:SetHorizontalAlignment(0);cs:SetVerticalAlignment(0)
  local measureCopy=cloneRich(w,canvas,overlay,prefix..'Measure',raw,true)
  local measured=measure(measureCopy)
  local bottomLineSynchronized=false
  if host=='actual_pickup_weapon_description' and not near(before.layout.desired.height,measured.desired.height) then
   -- The pickup's existing Slate layout can retain bottom-line spacing that
   -- differs from its reflected default. Permit only that measured difference;
   -- the full clone still has to match every native line after synchronization.
   equal(before.layout.rects,measured.rects,'Pickup native line geometry')
   assert(near(before.layout.desired.width,measured.desired.width)
    and near(before.layout.lineHeight,measured.lineHeight),'Pickup native width or spacing differs')
   local last=before.layout.rects[#before.layout.rects]
   assert(before.layout.lineHeight>1 and before.layout.lineHeight<=2
    and near(before.layout.desired.height-measured.desired.height,last.height*(before.layout.lineHeight-1)),
    'Unmeasured pickup bottom-line spacing')
   measureCopy.ApplyLineHeightToBottomLine=true
   measureCopy.bUseLineHighPercentageOnBottomLine=true
   measureCopy:OnCultureChanged();measureCopy:RefreshTextLayout();refresh(overlay)
   measured=measure(measureCopy);bottomLineSynchronized=true
  end
  equal(before.layout,measured,'Full native style clone')
  equal(before.decorators,decorators(measureCopy),'Native style decorator configuration')
  equal(before.resolvedStyle,resolvedStyle(measureCopy),'Native full clone resolved style')
  measureCopy:SetAutoWrapText(false);measureCopy:SetWrapTextWidth(0)
  local widths={};local measurements=0
  local function width(text,first,last)
   if text==''then return 0 end
   assert(first and last and parsed.visible:sub(first,last)==text,'Native style measurement needs exact visible byte range')
   local id=first..':'..last;if widths[id]then return widths[id]end
   measurements=measurements+1;assert(measurements<=600,'Bounded style measurement limit')
   local textRaw=slice(renderer,parsed,first,last)
   measureCopy:SetText(FText(textRaw));measureCopy:RefreshTextLayout();refresh(overlay)
   local m=measure(measureCopy);assert(#m.rects==1 and m.desired.width>0,'Native styled line measurement unavailable')
   assert(near(m.rects[1].width,m.desired.width),'Native styled line advance and desired width disagree')
   widths[id]=m.desired.width;return widths[id]
  end
  local plan,reason=renderer.layout(layoutText,parts,before.layout.rects,width,.08,{richSpans=parsed.spans,outline=0,shadowX=0,glyphOffset=0},
   {forceWordWrap=true,keepReadingWords=true,availableWidth=before.wrap,justification=0})
  assert(plan,reason);assert(#plan.runs==expected and #plan.skipped==0,'A pure-style reading was omitted')
  local bodySizes,bodyWidgets,rebuilt={},{},{}
  local styleRanges={};local readingStyles={};local cursor=1
  for _,span in ipairs(parsed.spans)do styleRanges[#styleRanges+1]={firstByte=span.firstByte,lastByte=span.lastByte,text=span.text,
   nativeTag=span.tag and'Character_Yellow_Decorator2'or'plain',nativeResolution='source PBZ class/config/decorator/culture copied verbatim; visible color requires screen verification'}end
  for index,segment in ipairs(parts)do
   local last=cursor+#segment.text-1
   if segment.reading then
    local covered=false
    for _,span in ipairs(styleRanges)do if cursor>=span.firstByte and last<=span.lastByte then
     readingStyles[index]={firstByte=cursor,lastByte=last,nativeTag=span.nativeTag};covered=true;break end end
    assert(covered,'Reviewed reading crosses a native style boundary')
   end
   cursor=last+1
  end
  for i,line in ipairs(plan.lines)do
   local text=slice(renderer,parsed,line.firstByte,line.lastByte);rebuilt[#rebuilt+1]=text
   local copy,slot=cloneRich(w,canvas,overlay,prefix..'Body_'..i,text,false)
   equal(before.decorators,decorators(copy),'Line native decorator configuration')
   equal(before.resolvedStyle,resolvedStyle(copy),'Line native resolved style')
   local m=measure(copy);assert(#m.rects==1 and near(m.desired.width,width(line.text,line.firstByte,line.lastByte)),'Reflow line differs from native measured copy')
   assert(m.desired.width<=before.wrap+.08,'Reflow body exceeds original wrap width')
   bodySizes[i]={width=m.desired.width,height=m.desired.height};bodyWidgets[i]={widget=copy,slot=slot}
  end
  local plainRebuilt={};for _,line in ipairs(plan.lines)do plainRebuilt[#plainRebuilt+1]=line.text end
  assert(table.concat(plainRebuilt)==parsed.visible,'Reflow changed visible native text order')
  local rubyWidgets={};local candidates={}
  for _,run in ipairs(plan.runs)do
   run.sourceStyle=readingStyles[run.segment];assert(run.sourceStyle,'Missing reviewed native style origin')
   local ruby=make('TextBlock','Ruby_'..run.segment);ruby:SetFont(font)
   ruby.Font.Size=font.Size*.6;ruby.Font.LetterSpacing=0;ruby:SetFont(ruby.Font)
   ruby:SetText(FText(run.reading));ruby:SetColorAndOpacity(style.ColorAndOpacity);ruby:SetShadowOffset({X=0,Y=0})
   ruby:SetAutoWrapText(false);ruby:SetJustification(1);ruby:SetVisibility(3)
   local slot=canvas:AddChildToCanvas(ruby);slot:SetAutoSize(true);slot:SetAlignment({X=.5,Y=0});slot:SetZOrder(1)
   refresh(overlay);local d=ruby:GetDesiredSize()
   run.width=d.X;run.height=d.Y;run.ratio=.6;candidates[#candidates+1]=run;rubyWidgets[run.segment]={widget=ruby,slot=slot}
  end
  local function resize(run,ratio)
   if run.boundaryConstraint then return 0,0 end
   local ruby=rubyWidgets[run.segment].widget;ruby.Font.Size=font.Size*ratio;ruby:SetFont(ruby.Font)
   refresh(overlay);local d=ruby:GetDesiredSize();return d.X,d.Y
  end
  -- Zero-width fixed constraints encode x-width/2>=0 and
  -- x+width/2<=nativeWrap in the existing distance solver. They are never
  -- rendered/count as readings and cannot move or consume glyph dimensions.
  local boundaryConstraints={}
  for i=1,#plan.lines do
   for side,x in ipairs({-2,before.wrap+2})do
    local c={boundaryConstraint=true,segment=-(i*2+side),text='',reading='',line=i,x=x,baseLeft=x,baseRight=x,width=0,height=0,ratio=.6}
    candidates[#candidates+1]=c;boundaryConstraints[#boundaryConstraints+1]={line=i,x=x,kind=side==1 and'left'or'right'}
   end
  end
  local fitted=renderer.fit_subtitle_horizontal(candidates,resize,{minimumRatio=.45,horizontalGap=2})
  assert(not fitted.reason,fitted.reason);assert(#fitted.skipped==0 and fitted.remainingCollisions==0,'Pure-style paragraph ruby collision')
  local real,adjustments={},{}
  for _,r in ipairs(fitted.runs)do if not r.boundaryConstraint then real[#real+1]=r end end
  for _,r in ipairs(fitted.adjustments)do if r.segment>0 then adjustments[#adjustments+1]=r end end
  fitted.runs=real;fitted.adjustments=adjustments
  assert(#fitted.runs==expected,'Boundary solver omitted a reviewed style reading')
  for _,r in ipairs(fitted.runs)do
   r.width,r.height=resize(r,r.ratio);r.fontSize=font.Size*r.ratio
   assert(r.x-r.width/2>=-.08 and r.x+r.width/2<=before.wrap+.08,'Ruby exceeds the native item width')
  end
  local horizontal=0
  for i=2,#fitted.runs do local a,b=fitted.runs[i-1],fitted.runs[i]
   if a.line==b.line and b.x-a.x<(a.width+b.width)/2+2-.01 then horizontal=horizontal+1 end
  end
  assert(horizontal==0,'Final native style ruby widths collide')
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
  assert(vertical==0,'Ruby overlaps previous native line')
  -- Recheck the full wrapped clone immediately before any source mutation.
  measureCopy:SetAutoWrapText(w.AutoWrapText);measureCopy:SetWrapTextWidth(w.WrapTextAt);measureCopy:SetText(FText(raw))
  measureCopy:RefreshTextLayout();refresh(overlay);equal(before.layout,measure(measureCopy),'Full native clone repeat')
  equal(before.decorators,decorators(measureCopy),'Repeated native decorator configuration')
  equal(before.resolvedStyle,resolvedStyle(measureCopy),'Repeated native resolved style')
  measureCopy:RemoveFromParent()
  equal(before,audit(w),'Source before reveal')
  h.appliedPadding={Left=before.padding.Left,Top=before.padding.Top+reserve,Right=before.padding.Right,Bottom=before.padding.Bottom+added}
  w.Slot:SetPadding(margin(h.appliedPadding));w:SetRenderOpacity(0);bounds:SetRenderOpacity(before.opacity);refresh(overlay)
  assert(overlay:GetChildrenCount()==originalChildren+1,'Unexpected pure-style sibling count')
  local after=audit(w);local expectedAfter={};for k,v in pairs(before)do expectedAfter[k]=v end
  expectedAfter.opacity=0;expectedAfter.padding=h.appliedPadding;equal(expectedAfter,after,'Source after reversible pure-style reflow')
  stats={key=key,host=host,runs=fitted.runs,lines=lines,skipped={},horizontalCollisions=0,verticalCollisions=0,
   richText=true,sourceBefore=before,sourceAfter=after,sourceTextUnchanged=true,sourceFontUnchanged=true,sourceSizeUnchanged=true,
   topReserve=reserve,addedBottomPadding=added,reflow=reflow,sourceTag='Character_Yellow_Decorator2',visibleText=parsed.visible,styleSpans=styleRanges,
   bodyStyleResolution='native PBZ automatic style/decorators with exact source culture override',rubyColorPolicy='source default body text color',
   styleByteCoordinates='visible UTF-8 bytes, 1-based inclusive',sourceStyleDefinition=before.resolvedStyle,
   visibleStyleColorVerified=false,naturalSourceVerified=false,
   lineEdgeConstraints=boundaryConstraints,
   measurementCount=measurements,fullNativeCloneVerified=true,fullNativeRepeatVerified=true,decoratorsVerified=true,
   bottomLineSynchronized=bottomLineSynchronized,
   expected=expected,covered=#fitted.runs,adjustments=fitted.adjustments,ratio=.6,minimumRatio=.45}
  h.stats=stats;log('item_markup_attached '..key..' runs='..#stats.runs..' lines='..#lines)
 end)
 if not ok then
  local restored,restoreReason=true,nil;if h then restored,restoreReason=M.detach(h,log)end
  return nil,{reason=tostring(why),rollback=restored,rollbackReason=restoreReason,sourceBefore=h and h.sourceBefore}
 end
 return h,stats
end
return M
