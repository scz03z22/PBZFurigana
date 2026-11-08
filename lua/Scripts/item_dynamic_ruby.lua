-- Narrow ruby-only adapter for the native dynamic medicine usage line.
-- Original full FText/green number/style/opacity remain visible and untouched.
-- Only source OverlaySlot top padding and the inherited scrolling-enabled flag
-- may be temporarily reserved/pinned, and are restored exactly on detach.
local M={}
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
  layout=measure(w),wrap=w.WrapTextAt,autoWrap=w.AutoWrapText,justification=w.Justification,decorators=decorators(w),
  styleSet=obj(w.TextStyleSet),pbzStyleSet=obj(w.PBZTextStyleSet),richConfig=obj(w.RichTextStyleConfig),
  scrollingEnabled=w.bIsScrollingEnabled,scrollStyle=obj(w.ScrollStyle),scrollOrientation=w.ScrollOrientation}
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
 -- Let PBZTextStyleSet/RichTextStyleConfig build the native tag styles. The
 -- actual reflected base TextStyleSet is not the effective PBZ tag dictionary:
 -- assigning it made WeaponDes_Num_Green render literally in the native probe.
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
local function styleSignature(w)
 local s=w.DefaultTextStyleOverride;local f=s.Font;local c=s.ColorAndOpacity;local q=c.SpecifiedColor
 return {font={size=f.Size,object=obj(f.FontObject),material=obj(f.FontMaterial),typeface=str(f.TypefaceFontName),spacing=f.LetterSpacing,outline=f.OutlineSettings.OutlineSize},
  color={q.R,q.G,q.B,q.A,c.ColorUseRule},culture=str(w.DisplayCultureOverride),
  styleClass=obj(w.DefaultTextStyleOverrideClass),styleSet=obj(w.TextStyleSet),pbzStyleSet=obj(w.PBZTextStyleSet),richConfig=obj(w.RichTextStyleConfig),
  lineHeight=w.LineHeightPercentage,autoWrap=w.AutoWrapText,wrap=w.WrapTextAt,justification=w.Justification,
  scrollingEnabled=w.bIsScrollingEnabled,scrollStyle=obj(w.ScrollStyle),scrollOrientation=w.ScrollOrientation}
end
function M.scoped(w)
 if not valid(w)then return false end
 return pcall(owner,w)
end
function M.detach(h,log)
 if not h then return true end;log=log or function()end
 local errors={};local function attempt(label,fn)local ok,e=pcall(fn);if not ok then errors[#errors+1]=label..': '..tostring(e)end end
 local bounds=h.path and StaticFindObject(h.path)
 if valid(bounds)then attempt('remove ruby',function()bounds:RemoveFromParent()end)end
 local w=StaticFindObject(h.sourcePath)
 if valid(w)then
  attempt('restore reserved padding',function()
   assert(valid(w.Slot)and path(w.Slot)==h.slotPath,'Native usage slot was replaced')
   local current=margin(w.Slot.Padding)
   local sameOriginal=pcall(equal,current,h.originalPadding,'Original padding')
   local sameApplied=h.appliedPadding and pcall(equal,current,h.appliedPadding,'Applied padding')
   assert(sameOriginal or sameApplied,'Native usage padding changed externally')
   w.Slot:SetPadding(margin(h.originalPadding));refresh(w)
  end)
  attempt('restore native scrolling flag',function()
   if h.scrollingPinApplied then
    assert(type(w.bIsScrollingEnabled)=='boolean','Native usage scrolling flag unavailable')
    if w.bIsScrollingEnabled==false then w:SetScrollingEnabled(h.originalScrollingEnabled);refresh(w)end
    assert(w.bIsScrollingEnabled==h.originalScrollingEnabled,'Original usage scrolling flag was not restored')
   end
   h.scrollingRestored=w.bIsScrollingEnabled==h.originalScrollingEnabled
   assert(h.scrollingRestored,'Native usage scrolling flag changed externally')
  end)
  attempt('audit native source',function()
   h.restoreAudit=audit(w);h.paddingRestored=pcall(equal,margin(w.Slot.Padding),h.originalPadding,'Restored padding')
   assert(h.paddingRestored,'Original usage padding was not restored')
   -- Counts/pages may change naturally. Never write an old text, opacity or
   -- style over a newly displayed native value during watcher cleanup.
   h.sourceChangedExternally=h.restoreAudit.text~=h.sourceBefore.text
   h.sourceUnchanged=pcall(equal,h.sourceBefore,h.restoreAudit,'Restored usage source')
   if not h.sourceChangedExternally then assert(h.sourceUnchanged,'Native usage source changed during ruby detach')end
   assert(w:GetParent():GetChildrenCount()==h.originalChildren,'Temporary usage child remained')
  end)
 end
 h.restoreErrors=errors;h.restored=#errors==0
 if #errors>0 then log('item_usage_restore_error '..table.concat(errors,'; '));return false,table.concat(errors,'; ')end
 return true,h.restoreAudit
end
function M.attach(w,segments,state,log,root,options)
 options=options or {};log=log or function()end;local h;local stats
 local ok,why=pcall(function()
  assert(valid(w),'Invalid dynamic usage source');local host=owner(w)
  local matcher=assert(loadfile(root..'Scripts/item_dynamic_readings.lua'))()
  local raw=str(w:GetText());local entry=assert(matcher.lookup(raw),'Not an exact reviewed dynamic medicine usage line')
  assert(type(segments)=='table'and #segments==4,'Dynamic usage requires its four reviewed segments')
  for i,s in ipairs(entry.segments)do assert(segments[i].text==s.text and segments[i].reading==s.reading,'Dynamic usage reading/source mismatch')end
  local before=audit(w);local font=w.DefaultTextStyleOverride.Font
  assert(#before.layout.rects==1,'Dynamic usage must stay on one native line')
  local rect=before.layout.rects[1]
  assert(near(rect.x,0)and near(rect.y,0)and near(rect.width,before.layout.desired.width),'Unproven dynamic usage alignment')
  assert(before.wrap>0 and before.layout.desired.width<=before.wrap+.08 and not before.autoWrap and before.justification==0,'Unproven usage width/wrap')
  assert(before.font.outline==0 and before.font.spacing==0 and w.MinDesiredWidth==0,'Unmeasured usage outline/spacing/minimum width')
  local shadow=w.DefaultTextStyleOverride.ShadowOffset;assert(shadow.X==0 and shadow.Y==0,'Unmeasured usage shadow')
  assert(type(w.bIsScrollingEnabled)=='boolean','Native usage scrolling flag unavailable')
  -- Native samples have enabled=true but no ScrollStyle. Geometry getters are
  -- zero, so do not infer that this flag can never cause movement. Pin this
  -- narrow, single-line source explicitly; configured marquees still fail closed.
  assert(not valid(w.ScrollStyle),'Configured usage marquee is not supported')
  local tr=w.RenderTransform;assert(tr.Translation.X==0 and tr.Translation.Y==0 and tr.Scale.X==1 and tr.Scale.Y==1 and tr.Shear.X==0 and tr.Shear.Y==0 and tr.Angle==0,'Unmeasured usage transform')
  local m=w.Margin;assert(m.Left==0 and m.Top==0 and m.Right==0 and m.Bottom==0,'Unmeasured usage text margin')
  assert((w.Slot.HorizontalAlignment==0 or w.Slot.HorizontalAlignment==1)and w.Slot.VerticalAlignment==1,'Unproven usage slot alignment')
  local overlay=w:GetParent();local count=overlay:GetChildrenCount()
  local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
  state.serial=(state.serial or 0)+1;local prefix='PBZFurigana_Usage_'..state.serial..'_'
  local function make(c,n)local q=StaticConstructObject(StaticFindObject('/Script/UMG.'..c),w:GetOuter(),FName(prefix..n));assert(valid(q));return q end
  local bounds=make('SizeBox','Bounds')
  h={kind='item_dynamic_usage',path=path(bounds),sourcePath=path(w),slotPath=path(w.Slot),sourceBefore=before,
   originalPadding=before.padding,originalOpacity=before.opacity,originalChildren=count,
   originalScrollingEnabled=before.scrollingEnabled,scrollingPinApplied=false}
  local effectiveBefore={};for k,v in pairs(before)do effectiveBefore[k]=v end
  if before.scrollingEnabled then
   -- Mark ownership before the setter so partial native failure also rolls back.
   h.scrollingPinApplied=true;w:SetScrollingEnabled(false);refresh(w)
   effectiveBefore.scrollingEnabled=false
  end
  equal(effectiveBefore,audit(w),'Native source after scrolling pin')
  local sourceStyle=styleSignature(w)
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(before.opacity)
  local bs=overlay:AddChildToOverlay(bounds);bs:SetHorizontalAlignment(0);bs:SetVerticalAlignment(0);bs:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
  local canvas=make('CanvasPanel','Canvas');canvas:SetVisibility(3);h.canvasPath=path(canvas)
  local cs=bounds:AddChild(canvas);cs:SetHorizontalAlignment(0);cs:SetVerticalAlignment(0)
  local measureCopy=cloneRich(w,canvas,overlay,prefix..'MeasureRich',raw,true)
  equal(before.layout,measure(measureCopy),'Full native usage clone')
  equal(before.decorators,decorators(measureCopy),'Native usage decorators')
  local cloneStyle=styleSignature(measureCopy)
  assert(cloneStyle.styleSet=='','Unexpected explicit usage clone style table')
  local expectedCloneStyle={};for k,v in pairs(sourceStyle)do expectedCloneStyle[k]=v end
  expectedCloneStyle.styleSet=''
  equal(expectedCloneStyle,cloneStyle,'Native usage clone style')
  measureCopy:SetAutoWrapText(false);measureCopy:SetWrapTextWidth(0)
  local widths={['']=0};local measured={}
  local function width(text)
   if widths[text]~=nil then return widths[text]end
   assert(not text:find('[<>]')and #measured<12,'Only bounded plain usage prefix measurement is allowed')
   measureCopy:SetText(FText(text));measureCopy:RefreshTextLayout();refresh(overlay)
   local m=measure(measureCopy);assert(#m.rects==1 and m.desired.width>0 and near(m.rects[1].width,m.desired.width),'Native usage prefix advance unavailable')
   widths[text]=m.desired.width;measured[#measured+1]={text=text,width=m.desired.width,height=m.desired.height};return m.desired.width
  end
  local label=entry.label
  local prefixWidth=width(label);local countStart=width(label..': ')
  assert(prefixWidth<countStart and countStart<before.layout.desired.width,'Native counter/tag suffix missing from full line')
  local readings={segments[1],segments[2],segments[3]}
  local plan,reason=renderer.layout(label,readings,{{x=rect.x,y=rect.y,width=prefixWidth,height=rect.height}},width,.08,{})
  assert(plan,reason);assert(#plan.lines==1 and #plan.runs==3 and #plan.skipped==0,'Dynamic usage readings were omitted')
  local widgets={};local candidates={}
  for _,r in ipairs(plan.runs)do
   local ruby=make('TextBlock','Ruby_'..r.segment);ruby:SetFont(font)
   ruby.Font.Size=font.Size*.6;ruby.Font.LetterSpacing=0;ruby:SetFont(ruby.Font)
   ruby:SetText(FText(r.reading));ruby:SetColorAndOpacity(w.DefaultTextStyleOverride.ColorAndOpacity)
   ruby:SetShadowOffset({X=0,Y=0});ruby:SetAutoWrapText(false);ruby:SetJustification(1);ruby:SetVisibility(3)
   local slot=canvas:AddChildToCanvas(ruby);slot:SetAutoSize(true);slot:SetAlignment({X=.5,Y=0});slot:SetZOrder(1)
   refresh(overlay);local d=ruby:GetDesiredSize();r.width=d.X;r.height=d.Y;r.ratio=.6;candidates[#candidates+1]=r
   widgets[r.segment]={widget=ruby,slot=slot}
  end
  local function resize(r,ratio)
   local ruby=widgets[r.segment].widget;ruby.Font.Size=font.Size*ratio;ruby:SetFont(ruby.Font)
   refresh(overlay);local d=ruby:GetDesiredSize();return d.X,d.Y
  end
  local fit=renderer.fit_subtitle_horizontal(candidates,resize,{minimumRatio=.45,horizontalGap=2})
  assert(not fit.reason,fit.reason);assert(#fit.skipped==0 and fit.remainingCollisions==0,'Dynamic usage ruby collision')
  local reserve=0
  for _,r in ipairs(fit.runs)do
   r.width,r.height=resize(r,r.ratio);r.fontSize=font.Size*r.ratio
   assert(r.x-r.width/2>=-.08 and r.x+r.width/2<=countStart+.08,'Usage reading overhang reaches the native green count')
   reserve=math.max(reserve,r.height+1)
  end
  reserve=math.ceil(reserve)
  -- Restore the measuring copy's complete original string/style and verify it
  -- again. The real source has never received the plain prefix or any setter.
  measureCopy:SetAutoWrapText(w.AutoWrapText);measureCopy:SetWrapTextWidth(w.WrapTextAt);measureCopy:SetText(FText(raw))
  measureCopy:RefreshTextLayout();refresh(overlay)
  equal(before.layout,measure(measureCopy),'Full native usage clone repeat')
  equal(expectedCloneStyle,styleSignature(measureCopy),'Repeated native usage style');equal(before.decorators,decorators(measureCopy),'Repeated native usage decorators')
  measureCopy:RemoveFromParent();equal(effectiveBefore,audit(w),'Native full source before ruby')
  h.appliedPadding={Left=before.padding.Left,Top=before.padding.Top+reserve,Right=before.padding.Right,Bottom=before.padding.Bottom}
  w.Slot:SetPadding(margin(h.appliedPadding))
  for _,r in ipairs(fit.runs)do
   r.y=before.padding.Top+reserve+rect.y-r.height-1
   widgets[r.segment].slot:SetPosition({X=before.padding.Left+r.x,Y=r.y})
  end
  refresh(w);local after=audit(w);local expected={};for k,v in pairs(effectiveBefore)do expected[k]=v end;expected.padding=h.appliedPadding
  equal(expected,after,'Visible native usage source after ruby')
  assert(overlay:GetChildrenCount()==count+1,'Unexpected usage sibling count')
  local size=bounds:GetDesiredSize();assert(near(size.X,0)and near(size.Y,0),'Usage ruby sibling contributes desired size')
  stats={kind='item_dynamic_usage_ruby_only',key=entry.key,dynamicPattern=entry.dynamic_pattern,dynamicValue=entry.dynamic_value,
   sourceBefore=before,sourceAfter=after,sourceTextUnchanged=true,sourceFontUnchanged=true,sourceSizeUnchanged=true,sourceOpacityUnchanged=true,
   sourceTagsRetained=true,nativeSourceVisible=true,nativeGreenCountRetained=true,richText=true,
   fullNativeCloneVerified=true,fullNativeRepeatVerified=true,stylesVerified=true,decoratorsVerified=true,
   styleVerification='Native PBZ config resolution; all captured style fields equal except explicitly unset reflected clone TextStyleSet',
   sourceReflectedTextStyleSet=sourceStyle.styleSet,cloneReflectedTextStyleSet=cloneStyle.styleSet,
   originalScrollingEnabled=before.scrollingEnabled,scrollingPinApplied=h.scrollingPinApplied,scrollingEnabledWhileAnnotated=after.scrollingEnabled,
   runs=fit.runs,lines={{text=raw,x=rect.x,y=rect.y,width=rect.width,height=rect.height}},expected=3,covered=3,
   skipped={},horizontalCollisions=0,verticalCollisions=0,remainingCollisions=0,topReserve=reserve,addedBottomPadding=0,
   nativePrefix=label,nativePrefixWidth=prefixWidth,nativeCountStart=countStart,measurements=measured,reflow=false,ratio=.6,minimumRatio=.45,adjustments=fit.adjustments,
   originalPadding=before.padding,appliedPadding=h.appliedPadding}
  h.stats=stats;log('item_usage_attached value='..entry.dynamic_value..' runs=3 prefixWidth='..prefixWidth..' reserve='..reserve)
 end)
 if not ok then
  local restored,restoreReason=true,nil;if h then restored,restoreReason=M.detach(h,log)end
  return nil,{reason=tostring(why),rollback=restored,rollbackReason=restoreReason,sourceBefore=h and h.sourceBefore}
 end
 return h,stats
end
return M
