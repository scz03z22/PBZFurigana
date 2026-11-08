-- Title ruby in a zero-size sibling. Native source/ScaleBox/SizeBox
-- parents, slots, text, and style remain untouched, preserving culture updates.
local M={}
local function valid(o) return o and o:IsValid() end
local function path(o) return o:GetFullName():match('^[^ ]+ (.+)$') end
local function class(o) return o:GetClass():GetFName():ToString() end
local function size(s) return {X=s.X,Y=s.Y} end
local function padding(p) return {Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom} end
local function close(a,b) return math.abs(a-b)<.05 end
local function make(name,outer,id)
 local o=StaticConstructObject(StaticFindObject('/Script/UMG.'..name),outer,FName(id))
 assert(valid(o),'Could not create title '..name)
 return o
end
local function refresh(w)
 local p=w
 for i=1,18 do
  if not valid(p) then break end
  p:ForceLayoutPrepass()
  local nextParent=p:GetParent()
  if not valid(nextParent) then
   local tree=p:GetOuter()
   if valid(tree) and class(tree)=='WidgetTree' then
    local owner=tree:GetOuter()
    if valid(owner) and owner:GetFullName()~=p:GetFullName() then nextParent=owner end
   end
  end
  p=nextParent
 end
end
local function audit(w)
 local parent=w:GetParent();local slot=w.Slot
 local font=w.DefaultTextStyleOverride.Font
 local color=w.DefaultTextStyleOverride.ColorAndOpacity;local rgba=color.SpecifiedColor
 return {text=w:GetText():ToString(),fontSize=font.Size,
  fontObject=valid(font.FontObject) and font.FontObject:GetFullName() or '',
  typeface=font.TypefaceFontName:ToString(),letterSpacing=font.LetterSpacing,
  color={R=rgba.R,G=rgba.G,B=rgba.B,A=rgba.A,rule=color.ColorUseRule},
  desired=size(w:GetDesiredSize()),opacity=w:GetRenderOpacity(),
  padding={Left=0,Top=0,Right=0,Bottom=0},
  parentPath=valid(parent) and path(parent) or '',parentClass=valid(parent) and class(parent) or '',
  slotPath=valid(slot) and path(slot) or '',
  horizontalAlignment=valid(slot) and slot.HorizontalAlignment or -1,
  verticalAlignment=valid(slot) and slot.VerticalAlignment or -1}
end
local function describe(a)
 return 'text='..a.text..' font='..a.fontSize..' desired='..a.desired.X..','..a.desired.Y..
  ' opacity='..a.opacity..' letterSpacing='..a.letterSpacing..' parent='..a.parentClass..
  ' fontObject='..a.fontObject..' typeface='..a.typeface..
  ' color='..a.color.R..','..a.color.G..','..a.color.B..','..a.color.A..','..a.color.rule
end
local function assertStyle(before,after)
 assert(after.fontSize==before.fontSize and after.fontObject==before.fontObject and
  after.typeface==before.typeface and after.letterSpacing==before.letterSpacing,'Item title native font changed')
 for _,key in ipairs({'R','G','B','A','rule'}) do
  assert(after.color[key]==before.color[key],'Item title native color changed: '..key)
 end
end
local function nativeRects(w)
 local result={}
 local function append(value)
  local ok,r=pcall(function()return value:get()end)
  if not ok then r=value end
  result[#result+1]={x=r.X,y=r.Y,width=r.Z,height=r.W}
 end
 local values=w:GetVisualLineRects()
 if type(values)=='table' then for index=1,math.min(#values,21)do append(values[index])end
 elseif values then values:ForEach(function(_,value)if #result<21 then append(value)end end)end
 return result
end

-- Long titles alone need a different shaping scale. These private wrappers use
-- the fixed native full-string scale for every prefix and for the ruby glyphs.
-- Recomputing a scale for each prefix (or using allocated/native desired) is
-- wrong: native SScaleBox normalizes the full string before selecting its scale.
local function scaleWrapper(w,canvas,prefix,factor)
 local wrapper=make('ScaleBox',w:GetOuter(),prefix)
 local slot=canvas:AddChildToCanvas(wrapper);slot:SetAutoSize(true)
 wrapper:SetStretch(7);wrapper:SetStretchDirection(0);wrapper:SetUserSpecifiedScale(factor)
 wrapper:SetIgnoreInheritedScale(false);wrapper:SetVisibility(3)
 return wrapper,slot
end

local function prepareScaledTitle(w,scale,box,canvas,row,prefix,before,rects)
 assert(scale.Stretch==2 and scale.StretchDirection==1 and not scale.IgnoreInheritedScale,'Unproven long-title scaling policy')
 assert(box.bOverride_MaxDesiredWidth and not box.bOverride_WidthOverride and box.bOverride_HeightOverride,'Unproven long-title SizeBox constraints')
 assert(w.AutoWrapText==false and w.WrapTextAt==0 and w.Justification==0,'Long title must remain a native unwrapped line')
 local style=w.DefaultTextStyleOverride;local font=style.Font;local shadow=style.ShadowOffset
 assert(font.OutlineSettings.OutlineSize==0 and shadow.X==0 and shadow.Y==0,'Scaled-title outline/shadow not validated')
 local allocated=size(box:GetDesiredSize())
 assert(close(allocated.X,box.MaxDesiredWidth) and close(allocated.Y,box.HeightOverride),'Native long-title allocation differs from its constraints')
 local plainWrap=scaleWrapper(w,canvas,prefix..'NormalizingPlainScale',1)
 plainWrap:SetRenderOpacity(0)
 local plain=make('TextBlock',w:GetOuter(),prefix..'NormalizingPlain')
 plainWrap:AddChild(plain):SetHorizontalAlignment(1);plain.Slot:SetVerticalAlignment(1)
 plain:SetFont(font);plain:SetShadowOffset({X=0,Y=0});plain:SetAutoWrapText(false);plain:SetVisibility(3)
 plain:SetText(FText(before.text));refresh(row)
 local normal=size(plain:GetDesiredSize())
 assert(normal.X>allocated.X and normal.Y>0,'Long title is not wider at its normalizing scale')
 local factor=math.min(1,allocated.X/normal.X,allocated.Y/normal.Y)
 assert(factor>=.25 and factor<1,'Native long-title scale outside validated range')
 local richWrap=scaleWrapper(w,canvas,prefix..'NativeControlScale',factor)
 richWrap:SetRenderOpacity(0)
 local rich=StaticConstructObject(w:GetClass(),w:GetOuter(),FName(prefix..'NativeControl'))
 assert(valid(rich),'Could not create scaled-title native control')
 richWrap:AddChild(rich):SetHorizontalAlignment(1);rich.Slot:SetVerticalAlignment(1)
 rich:SetVisibility(3);rich:SetRenderOpacity(0)
 for _,field in ipairs({'PBZTextStyleSet','RichTextStyleConfig','bFindConfigTextStyleSet','SavedColorAndOpacity','DefaultColor','bUseCustomColor',
  'bUseWidgetLineHighSetting','bUseLineHighPercentageOnBottomLine','bTintInlineIcon','bDisplayAllCaps','MobileTextBlockScale','InlineIconDisplayMode',
  'TextSizeScaleConfigs','ScrollStyle','ScrollOrientation','MinDesiredWidth','TextTransformPolicy','TextOverflowPolicy','ShapedTextOptions','WrappingPolicy',
  'ApplyLineHeightToBottomLine','Margin','LineHeightPercentage'})do rich[field]=w[field]end
 rich:SetDecorators(w.DecoratorClasses)
 if valid(w.DefaultTextStyleOverrideClass)then rich:SetStyle(w.DefaultTextStyleOverrideClass)end
 local culture=w.DisplayCultureOverride
 rich:SetDisplayCultureOverride(type(culture)=='string'and culture or culture:ToString());rich:SetTagStyleMapping(w.TagStyleMapping)
 rich:SetDefaultTextStyle(style);rich:SetOutlineOverride(w.OutlineOverride)
 rich:OverrideTextColor(w.SavedColorAndOpacity,w.bUseCustomColor);rich:SetScrollingEnabled(w.bIsScrollingEnabled)
 rich:SetAutoWrapText(false);rich:SetWrapTextWidth(0);rich:SetJustification(0);rich:SetText(FText(before.text));refresh(row)
 rich:SetDefaultTextStyle(style);rich:SetDefaultFont(font);rich:OverrideTextColor(w.SavedColorAndOpacity,w.bUseCustomColor)
 rich:RefreshTextLayout();plainWrap:SetUserSpecifiedScale(factor);refresh(row)
 local actual=size(rich:GetDesiredSize());local plainActual=size(plain:GetDesiredSize());local lines=nativeRects(rich)
 assert(close(actual.X,before.desired.X) and close(actual.Y,before.desired.Y),'Same-scale native long-title full clone differs')
 assert(close(actual.X,plainActual.X) and close(actual.Y,plainActual.Y),'Same-scale native/plain long-title metrics differ')
 assert(#lines==1 and close(lines[1].x,rects[1].x) and close(lines[1].y,rects[1].y)
  and close(lines[1].width,rects[1].width) and close(lines[1].height,rects[1].height),'Same-scale long-title native line differs')
 assertStyle(before,audit(rich))
 plain:SetText(FText(before.text));rich:SetText(FText(before.text));rich:RefreshTextLayout();refresh(row)
 assert(close(plain:GetDesiredSize().X,plainActual.X) and close(rich:GetDesiredSize().X,actual.X),'Scaled-title full repeat differs')
 rich:RemoveFromParent();plain:RemoveFromParent();richWrap:RemoveFromParent();plainWrap:RemoveFromParent()
 return {factor=factor,normalized=normal,clone=actual,allocated=allocated,fullAndRepeatVerified=true,
  displaySource={X=actual.X*factor,Y=actual.Y*factor},sourceLogicalOverflow=math.max(0,actual.X*factor-allocated.X)}
end

-- Weapon detail explicitly sizes the name box before Slate resolves the final
-- DPI. On reopening the panel that box can be narrower than the current title.
local function fixedWeaponTitle(w,scale,box,row,boxSize,rect,padLeft,root)
 if not box.bOverride_WidthOverride or box.bOverride_HeightOverride
   or not box.bOverride_MaxDesiredWidth or not (box.MaxDesiredWidth==463 or box.MaxDesiredWidth==390)
   or not close(box.WidthOverride,boxSize.X) or boxSize.X>box.MaxDesiredWidth
   or scale.Stretch~=2 or scale.StretchDirection~=1 or scale.IgnoreInheritedScale then return end
 local geometry=assert(loadfile(root..'Scripts/geometry_service.lua'))().new(root)
 local source,target=geometry.read(w),geometry.read(row)
 assert(target.xx>0 and target.yy>0 and math.abs(target.xy)<.002 and math.abs(target.yx)<.002
  and math.abs(source.xy)<.002 and math.abs(source.yx)<.002,'Unsupported weapon title transform')
 local factor=source.xx/target.xx
 local x,y=(source.x-target.x)/target.xx,(source.y-target.y)/target.yy
 assert(factor>=.25 and factor<=1 and math.abs(factor-source.yy/target.yy)<.002
  and math.abs(x-padLeft)<.25,'Weapon title transform differs from its native row')
 assert(y>=-.25 and rect.x>=-.05 and (rect.x+rect.width)*factor<=boxSize.X+.25,
  'Weapon title is outside its native allocation')
 return {factor=factor,bodyTop=y,allocated=boxSize,fixedWeaponWidth=true}
end

-- Opt-in line-edge solver for scaled titles and ordinary title edge overflow.
-- Widths/centers are already in the
-- outside row's units. Prefer the middle half of each base. Only an otherwise
-- impossible measured edge may use its complete base; never cross that base,
-- squeeze glyphs, or let a reading leave the native allocated width.
local function fitTitleEdges(runs,measure,width)
 local gap=2;local adjustments={};local minimum=.45
 assert(#runs>0 and #runs<=128 and width>0,'Invalid scaled-title fitting bounds')
 table.sort(runs,function(a,b)return a.x<b.x end)
 local initial=0
 for i,r in ipairs(runs)do
  r.originalX=r.x;r.originalRatio=r.ratio;r.originalWidth=r.width
  r.movement=(r.baseRight-r.baseLeft)*.25
  if i>1 and r.x-runs[i-1].x<(r.width+runs[i-1].width)/2+gap-.01 then initial=initial+1 end
 end
 local function bounds(r)return math.max(r.originalX-r.movement,r.width/2),math.min(r.originalX+r.movement,width-r.width/2)end
 local function feasible(last)
  local earliest,start
  for i=1,last or #runs do
   local r=runs[i];local lo,hi=bounds(r)
   if i==1 then earliest=lo;start=i
   else local nextCenter=earliest+(runs[i-1].width+r.width)/2+gap
    if nextCenter>lo then earliest=nextCenter else earliest=lo;start=i end
   end
   if earliest>hi+.001 then return false,start,i end
  end
  return true
 end
 local cache={}
 local function set(r,ratio)
  cache[r]=cache[r]or{};local s=cache[r][ratio]
  if not s then local x,y=measure(r,ratio);s={x,y};cache[r][ratio]=s end
  r.ratio=ratio;r.width=s[1];r.height=s[2]
 end
 for _=1,#runs*2+1 do
  local ok,first,last=feasible();if ok then break end
  local previous={};for i=first,last do previous[i]=runs[i].ratio end
  local function group(f)for i=first,last do local floor=math.min(minimum,previous[i]);set(runs[i],floor+(previous[i]-floor)*f)end end
  group(0)
  if not feasible(last) then
   -- At minimum size a four-kana reading on the first/last single kanji can
   -- require a center outside its middle half. Relax only an individually
   -- empty edge interval, after the original measured fit has failed. Keep
   -- every other run's original bounds and every center inside its own base.
   local relaxed=false
   for i=first,last do
    local r=runs[i];local low,high=bounds(r)
    if low>high+.001 and not r.fullBaseCenter then
     r.movement=(r.baseRight-r.baseLeft)*.5;r.fullBaseCenter=true
     relaxed=true
    end
   end
   assert(relaxed and feasible(last),'Scaled title cannot fit all readings inside its native width at minimum ratio')
  end
  local lo,hi=0,1
  for _=1,9 do local mid=(lo+hi)/2;group(mid);if feasible(last)then lo=mid else hi=mid end end
  group(lo)
 end
 assert(feasible(),'Scaled title edge placement did not converge')
 local latest={}
 for i=#runs,1,-1 do local _,hi=bounds(runs[i]);latest[i]=hi
  if runs[i+1]then latest[i]=math.min(latest[i],latest[i+1]-(runs[i].width+runs[i+1].width)/2-gap)end
 end
 for i,r in ipairs(runs)do
  local lo=bounds(r);if runs[i-1]then lo=math.max(lo,runs[i-1].x+(runs[i-1].width+r.width)/2+gap)end
  r.x=math.max(lo,math.min(r.originalX,latest[i]))
  assert(r.x>=r.baseLeft-.05 and r.x<=r.baseRight+.05,'Title ruby center left its own native base')
  if r.fullBaseCenter then r.minimumX=r.baseLeft;r.maximumX=r.baseRight end
  if math.abs(r.x-r.originalX)>.001 or r.ratio~=r.originalRatio then
   adjustments[#adjustments+1]={segment=r.segment,originalX=r.originalX,x=r.x,originalRatio=r.originalRatio,ratio=r.ratio,kind='native_title_edges'}
   if r.fullBaseCenter then
    local a=adjustments[#adjustments];a.centerBounds='full-native-base';a.minimumX=r.baseLeft;a.maximumX=r.baseRight
   end
  end
 end
 return{runs=runs,skipped={},adjustments=adjustments,initialCollisions=initial,remainingCollisions=0,horizontalGap=gap,minimumRatio=minimum}
end

-- Shared only by opt-in segmented item/map labels. Measure the actual native
-- font advances, so unannotated kana occupy their own space and receive no ruby.
-- The caller owns the zero-size canvas and removes it on any failure.
function M.build_segment_runs(w,segments,canvas,layoutRoot,prefix,root,options)
 local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
 local font=options.font;local ratio=options.ratio or .6
 local fontSize=font.Size*(options.fontScale or 1)
 local contentScale=options.titleContentScale or 1
 assert(contentScale>0 and contentScale<=1,'Invalid private title content scale')
 local scaled=contentScale~=1
 if scaled then assert(#segments<=128,'Scaled-title segment bound exceeded')end
 local measureWrapper
 if scaled then measureWrapper=scaleWrapper(w,canvas,prefix..'MeasureScale',contentScale);measureWrapper:SetRenderOpacity(0)end
 local measure=make('TextBlock',w:GetOuter(),prefix..'Measure')
 measure:SetFont(font);measure.Font.Size=fontSize;measure.Font.OutlineSettings.OutlineSize=0;measure:SetFont(measure.Font)
 measure:SetShadowOffset({X=0,Y=0});measure:SetAutoWrapText(false);measure:SetVisibility(3);measure:SetRenderOpacity(0)
 if scaled then local ms=measureWrapper:AddChild(measure);ms:SetHorizontalAlignment(1);ms:SetVerticalAlignment(1)
 else local ms=canvas:AddChildToCanvas(measure);ms:SetAutoSize(true)end
 local widths={['']=0}
 local function width(text)
  if widths[text]~=nil then return widths[text]end
  measure:SetText(FText(text));refresh(layoutRoot)
  local value=measure:GetDesiredSize().X;assert(value>0,'Segmented title measurement unavailable')
  widths[text]=value;return value
 end
 local scale=1
 local scaleOk,value=pcall(function()return StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary'):GetViewportScale(w)end)
 if scaleOk and type(value)=='number' and value>0 then scale=value end
 local outline=options.fontScale and 0 or font.OutlineSettings.OutlineSize;local shadowX=options.shadowX or 0
 local model={outline=outline,shadowX=shadowX,glyphOffset=math.floor(outline*scale+.5)/scale+math.max(0,-shadowX)}
 local tolerance=options.fontScale and math.min(5,math.max(1.5,options.rects[1].width*.012)) or .8
 local plan,reason=renderer.layout(options.text,segments,options.rects,width,tolerance,model)
 if not plan and options.calibrateNativeWidth and #options.rects==1
    and reason=='measured text does not match native line widths' then
  -- Slate may round the native rich text and the measuring TextBlock at
  -- different points in the DPI transform. For a single unchanged line,
  -- fit measured advances to the native glyph width if the drift is small.
  local glyphWidth=width(options.text)
  local nativeWidth=options.rects[1].width-2*outline-math.abs(shadowX)
  local difference=math.abs(nativeWidth-glyphWidth)
  if nativeWidth>0 and difference<=math.min(glyphWidth*.035,4/scale) then
   local correction=nativeWidth/glyphWidth
   plan,reason=renderer.layout(options.text,segments,options.rects,
    function(text) return width(text)*correction end,tolerance,model)
  end
 end
 assert(plan,reason)
 assert(#plan.lines==1 and #plan.skipped==0 and #plan.runs>0,'Segmented title must preserve every reading on its native single line')
 local widgets={};local candidates={}
 for _,run in ipairs(plan.runs)do
  local wrapper,slot
  if scaled then wrapper,slot=scaleWrapper(w,canvas,prefix..'ReadingScale_'..run.segment,contentScale)end
  local ruby=make('TextBlock',w:GetOuter(),prefix..'Reading_'..run.segment)
  ruby:SetFont(font);ruby.Font.Size=fontSize*ratio;ruby.Font.LetterSpacing=0
  ruby.Font.OutlineSettings.OutlineSize=math.max(0,math.floor(outline*ratio+.5));ruby:SetFont(ruby.Font)
  ruby:SetText(FText(run.reading));ruby:SetColorAndOpacity(options.color)
  ruby:SetJustification(1);ruby:SetAutoWrapText(false);ruby:SetVisibility(3)
  if scaled then local inner=wrapper:AddChild(ruby);inner:SetHorizontalAlignment(1);inner:SetVerticalAlignment(1)
  else slot=canvas:AddChildToCanvas(ruby)end
  slot:SetAutoSize(true);slot:SetAlignment({X=.5,Y=0});slot:SetZOrder(1)
  refresh(layoutRoot);local desired=ruby:GetDesiredSize()
  candidates[#candidates+1]={segment=run.segment,text=run.text,reading=run.reading,line=1,
   x=run.x*contentScale,baseLeft=run.baseLeft*contentScale,baseRight=run.baseRight*contentScale,ratio=ratio,width=desired.X*contentScale,height=desired.Y*contentScale,
   term_id=segments[run.segment].term_id,reading_source=segments[run.segment].reading_source}
  widgets[run.segment]={widget=ruby,slot=slot,scaleWrapper=wrapper}
 end
 local function resize(run,newRatio)
  local ruby=widgets[run.segment].widget;ruby.Font.Size=fontSize*newRatio
  ruby.Font.OutlineSettings.OutlineSize=math.max(0,math.floor(outline*newRatio+.5));ruby:SetFont(ruby.Font)
  refresh(layoutRoot);local desired=ruby:GetDesiredSize()
  if scaled then local actual=widgets[run.segment].scaleWrapper:GetDesiredSize()
   assert(desired.X>0 and desired.Y>0 and desired.X<100000 and desired.Y<100000,'Private scaled ruby measurement unavailable')
   assert(close(actual.X,desired.X*contentScale) and close(actual.Y,desired.Y*contentScale),'Private ruby scale wrapper metrics differ')end
  return desired.X*contentScale,desired.Y*contentScale
 end
 local fitted
 if scaled then fitted=fitTitleEdges(candidates,resize,assert(options.titleAllocatedWidth,'Missing native scaled-title width'))
 else
  fitted=renderer.fit_subtitle_horizontal(candidates,resize,{minimumRatio=.45,horizontalGap=2,
   clipLeft=options.clipLeft,clipRight=options.clipRight})
 end
 assert(not fitted.reason,fitted.reason)
 assert(#fitted.skipped==0 and fitted.remainingCollisions==0,'Segmented title readings collide')
 for _,run in ipairs(fitted.runs)do
  run.width,run.height=resize(run,run.ratio);run.fontSize=fontSize*run.ratio
  if scaled then
   run.contentScale=contentScale;run.displayFontSize=run.fontSize*contentScale
   assert(run.x-run.width/2>=-.05 and run.x+run.width/2<=options.titleAllocatedWidth+.05,'Scaled title ruby exceeds native width')
  end
 end
 if scaled then
  local collisions=0
  for i=2,#fitted.runs do local a,b=fitted.runs[i-1],fitted.runs[i]
   if b.x-a.x<(a.width+b.width)/2+fitted.horizontalGap-.01 then collisions=collisions+1 end
  end
  fitted.remainingCollisions=collisions
  assert(collisions==0,'Final scaled-title native glyph measurements collide')
 end
 measure:RemoveFromParent()
 if measureWrapper then measureWrapper:RemoveFromParent()end
 return fitted.runs,widgets,fitted
end

function M.detach(handle,log)
 if not handle then return true end
 log=log or function()end
 local errors={}
 local function attempt(label,fn)
  local ok,err=pcall(fn)
  if not ok then errors[#errors+1]=label..': '..tostring(err) end
 end
 local bounds=handle.path and StaticFindObject(handle.path)
 if valid(bounds) then attempt('ruby removal',function()bounds:RemoveFromParent()end) end
 local w=StaticFindObject(handle.sourcePath)
 local box=StaticFindObject(handle.boxPath)
 local row=StaticFindObject(handle.rowPath)
 if valid(box) and valid(row) and valid(box:GetParent()) and path(box:GetParent())==handle.rowPath then
  attempt('title padding restore',function()
   assert(valid(box.Slot) and path(box.Slot)==handle.boxSlotPath,'Native title slot was replaced')
   box.Slot:SetPadding(padding(handle.originalBoxPadding))
  end)
 end
 if valid(row) then
  attempt('row padding restore',function()
   assert(valid(row.Slot) and path(row.Slot)==handle.rowSlotPath,'Native title row slot was replaced')
   row.Slot:SetPadding(padding(handle.originalRowPadding))
  end)
 end
 local rowBox=handle.rowBoxPath and StaticFindObject(handle.rowBoxPath)
 if valid(rowBox) and valid(row) and valid(rowBox:GetContent()) and path(rowBox:GetContent())==handle.rowPath then
  attempt('row height restore',function()
   rowBox:SetHeightOverride(handle.originalRowHeight)
   if not handle.originalRowHeightOverride then rowBox:ClearHeightOverride() end
   log('item_title_row_restore height='..rowBox.HeightOverride..' override='..tostring(rowBox.bOverride_HeightOverride))
  end)
 end
 if valid(row) then attempt('layout refresh',function()refresh(row)end) end
 if valid(w) then
  attempt('restore audit',function()
   handle.restoreAudit=audit(w)
   handle.restoreAudit.parentRestored=handle.restoreAudit.parentPath==handle.scalePath
   handle.restoreAudit.sourceSlotUnchanged=handle.restoreAudit.slotPath==handle.sourceBefore.slotPath
   if valid(box) and valid(box.Slot) then handle.restoreAudit.titlePadding=padding(box.Slot.Padding) end
   if valid(row) and valid(row.Slot) then handle.restoreAudit.rowPadding=padding(row.Slot.Padding) end
   if valid(rowBox) then
    handle.restoreAudit.rowBoxPath=handle.rowBoxPath
    handle.restoreAudit.rowHeight=rowBox.HeightOverride
    handle.restoreAudit.rowHeightOverride=rowBox.bOverride_HeightOverride
   end
   log('item_title_restore '..describe(handle.restoreAudit))
  end)
 end
 if #errors>0 then local message=table.concat(errors,'; ');log('item_title_restore_error '..message);return false,message end
 return true,handle.restoreAudit
end

function M.attach(w,segments,state,log,root,options)
 options=options or {};log=log or function()end
 local handle;local stats
 local ok,err=pcall(function()
  assert(valid(w),'Invalid item title')
  local scale=w:GetParent()
  assert(valid(scale) and class(scale)=='ScaleBox','Item title requires its native ScaleBox')
  local box=scale:GetParent()
  assert(valid(box) and class(box)=='SizeBox','Item title requires its native SizeBox')
  local row=box:GetParent()
  assert(valid(row) and class(row)=='HorizontalBox','Item title requires its native HorizontalBox')
  assert(row:GetChildrenCount()>0 and path(row:GetChildAt(0))==path(box),'Native title must be the first row child')
  local hasNonAutoChild=false
  for i=0,row:GetChildrenCount()-1 do
   local child=row:GetChildAt(i);local childSlot=child.Slot
   local visibility=child:GetVisibility();local childSize=child:GetDesiredSize()
   local slotClass=valid(childSlot) and class(childSlot) or 'invalid'
   local sizeRule=slotClass=='HorizontalBoxSlot' and childSlot.Size.SizeRule or 'n/a'
   log('item_title_row_child index='..i..' path='..path(child)..' class='..class(child)..
    ' visibility='..visibility..' slot='..slotClass..' sizeRule='..sizeRule..
    ' desired='..childSize.X..','..childSize.Y)
   -- Collapsed (1) contributes no layout; Hidden (2) still reserves space.
   if visibility~=1 and sizeRule~=0 then hasNonAutoChild=true end
  end
  assert(not hasNonAutoChild,'Item title row requires automatic-width participating children')
  assert(scale:GetChildrenCount()==1 and path(scale:GetContent())==path(w),'Unexpected native ScaleBox content')
  local before=audit(w)
  assert(before.horizontalAlignment==1 and before.verticalAlignment==2,'Unsupported native title alignment')
  assert(not before.text:find('[<>]'),'Rich-text item titles need run-aware rendering')
  assert(w.Justification==0,'Only left-justified item titles are supported')
  local rects=nativeRects(w)
  assert(#rects==1 and rects[1].width>0 and rects[1].height>0,'Native title must have one laid-out line')
  local combined={};local readingCount=0
  for _,s in ipairs(segments) do combined[#combined+1]=s.text;if s.reading and s.reading~='' then readingCount=readingCount+1 end end
  assert(table.concat(combined)==before.text,'Title segments differ from localized source')
  assert(readingCount>0,'Title adapter requires at least one reviewed reading')
  local boxSlot=box.Slot;local rowSlot=row.Slot
  assert(valid(boxSlot) and class(boxSlot)=='HorizontalBoxSlot','Unexpected native title slot')
  assert(valid(rowSlot) and (class(rowSlot)=='VerticalBoxSlot' or class(rowSlot)=='SizeBoxSlot'),'Unexpected native title row slot')
  local boxSize=size(box:GetDesiredSize());local rowSize=size(row:GetDesiredSize())
  assert(boxSize.X>0 and rowSize.X>0 and rowSize.Y>0,'Native title row is not laid out')
  local rowParent=row:GetParent();local rowBox
  if valid(rowParent) and class(rowParent)=='SizeBox' and rowParent.bOverride_HeightOverride then rowBox=rowParent end
  local originalRowHeight=rowBox and rowBox.HeightOverride or rowSize.Y
  assert(originalRowHeight>=before.desired.Y-.05,'Native row already scales the title')
  local bodyTop=math.max(0,(originalRowHeight-before.desired.Y)/2)
  state.serial=(state.serial or 0)+1
  local prefix='PBZFurigana_ItemTitle_'..state.serial..'_'
  handle={kind='item_title',placement='native-row-sibling',sourcePath=path(w),scalePath=path(scale),boxPath=path(box),rowPath=path(row),
   sourceBefore=before,originalOpacity=before.opacity,originalBoxSize=boxSize,
   boxSlotPath=path(boxSlot),rowSlotPath=path(rowSlot),
   originalBoxPadding=padding(boxSlot.Padding),originalRowPadding=padding(rowSlot.Padding),
   originalHeightOverride=box.bOverride_HeightOverride,originalHeight=box.HeightOverride,
   originalWidthOverride=box.bOverride_WidthOverride,originalWidth=box.WidthOverride,
   originalMaxWidthOverride=box.bOverride_MaxDesiredWidth,originalMaxWidth=box.MaxDesiredWidth}
  if rowBox then
   handle.rowBoxPath=path(rowBox);handle.originalRowHeight=rowBox.HeightOverride
   handle.originalRowHeightOverride=rowBox.bOverride_HeightOverride
  end
  local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds')
  handle.path=path(bounds)
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3)
  bounds:SetRenderOpacity(before.opacity)
  local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Canvas')
  handle.canvasPath=path(canvas);canvas:SetVisibility(3)
  local canvasSlot=bounds:AddChild(canvas)
  canvasSlot:SetHorizontalAlignment(0);canvasSlot:SetVerticalAlignment(0)
  local endSlot=row:AddChildToHorizontalBox(bounds)
  endSlot:SetSize({Value=1,SizeRule=0})
  endSlot:SetHorizontalAlignment(1);endSlot:SetVerticalAlignment(0)
  endSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
  local ratio=options.ratio or .6
  assert(ratio>0 and ratio<=1,'Invalid title ruby ratio')
  local line=rects[1];local center=line.x+line.width/2
  local scaledTitle,contentScale
  if before.desired.X>boxSize.X+.05 then
   if options.itemKey and options.itemKey:match('^Weapon_%d%d%d$') then
    scaledTitle=fixedWeaponTitle(w,scale,box,row,boxSize,line,handle.originalBoxPadding.Left,root)
   end
   scaledTitle=scaledTitle or prepareScaledTitle(w,scale,box,canvas,row,prefix,before,rects)
   contentScale=scaledTitle.factor
   bodyTop=scaledTitle.bodyTop or math.max(0,(originalRowHeight-before.desired.Y*contentScale)/2)
   center=center*contentScale
  else contentScale=1 end
  local runs,widgets,fitted
  if #segments==1 and not scaledTitle then
   local ruby=make('TextBlock',w:GetOuter(),prefix..'Reading')
   ruby:SetFont(w.DefaultTextStyleOverride.Font)
   ruby.Font.Size=before.fontSize*ratio; ruby.Font.LetterSpacing=0
   ruby.Font.OutlineSettings.OutlineSize=math.max(0,math.floor(w.DefaultTextStyleOverride.Font.OutlineSettings.OutlineSize*ratio+.5))
   ruby:SetFont(ruby.Font);ruby:SetText(FText(segments[1].reading))
   ruby:SetColorAndOpacity(w.DefaultTextStyleOverride.ColorAndOpacity)
   ruby:SetJustification(1);ruby:SetAutoWrapText(false);ruby:SetVisibility(3)
   local rubySlot=canvas:AddChildToCanvas(ruby)
   rubySlot:SetAutoSize(true);rubySlot:SetAlignment({X=.5,Y=0});rubySlot:SetZOrder(1)
   refresh(row);local rubySize=size(ruby:GetDesiredSize())
   assert(rubySize.X>0 and rubySize.Y>0,'Title reading measurement unavailable')
   runs={{segment=1,text=before.text,reading=segments[1].reading,line=1,x=center,ratio=ratio,
    fontSize=before.fontSize*ratio,width=rubySize.X,height=rubySize.Y}}
   widgets={[1]={widget=ruby,slot=rubySlot}}
   fitted={initialCollisions=0,remainingCollisions=0,adjustments={}}
  else
   runs,widgets,fitted=M.build_segment_runs(w,segments,canvas,row,prefix,root,{font=w.DefaultTextStyleOverride.Font,
    color=w.DefaultTextStyleOverride.ColorAndOpacity,text=before.text,rects=rects,ratio=ratio,
    shadowX=w.DefaultTextStyleOverride.ShadowOffset.X,titleContentScale=contentScale,calibrateNativeWidth=true,
    titleAllocatedWidth=scaledTitle and boxSize.X or nil})
  end
  assert(#runs==readingCount,'Title reading coverage differs from its reviewed segments')
  local function readingExtents()
   local leftEdge,rightEdge,maxHeight=math.huge,-math.huge,0
   for _,run in ipairs(runs)do
    leftEdge=math.min(leftEdge,run.x-run.width/2);rightEdge=math.max(rightEdge,run.x+run.width/2);maxHeight=math.max(maxHeight,run.height)
   end
   return leftEdge,rightEdge,maxHeight
  end
  local leftEdge,rightEdge,maxHeight=readingExtents()
  local left=math.ceil(math.max(0,-leftEdge))
  local right=math.ceil(math.max(0,rightEdge-boxSize.X))
  local wantedWidth=boxSize.X+left+right
  local widthLimit=options.maxTitleWidth
  local ordinaryColumn=box.bOverride_MaxDesiredWidth and close(box.MaxDesiredWidth,533)
   and scale.Stretch==2 and scale.StretchDirection==1
  if not widthLimit then
   -- The observed ordinary item column is capped at 533, including short
   -- titles plus their ruby edge reserves. Keep unknown layouts conservative.
   if ordinaryColumn then widthLimit=533
   else widthLimit=scaledTitle and boxSize.X or 460 end
  end
  local nativeEdgeFit
  if not scaledTitle and wantedWidth>widthLimit+.05 and ordinaryColumn and not scale.IgnoreInheritedScale
   and before.desired.X<=boxSize.X+.05 and boxSize.X<=533+.05 and boxSize.X<=widthLimit+.05 then
   -- The native base already fits. Only an otherwise rejected ruby edge may
   -- opt into bounded placement; successful short/scaled paths stay unchanged.
   nativeEdgeFit={originalWantedWidth=wantedWidth,allocatedWidth=boxSize.X}
   for _,run in ipairs(runs)do
    run.baseLeft=run.baseLeft or line.x;run.baseRight=run.baseRight or line.x+line.width
    assert(run.ratio>=.45 and run.ratio<=.6,'Ordinary title edge ratio outside validated range')
    -- The ordinary collision pass may already have moved a reading. Re-anchor
    -- to its actual base midpoint so the second fit cannot accumulate motion.
    run.x=(run.baseLeft+run.baseRight)/2
   end
   local outline=w.DefaultTextStyleOverride.Font.OutlineSettings.OutlineSize
   local function resizeEdge(run,newRatio)
    local ruby=widgets[run.segment].widget
    ruby.Font.Size=before.fontSize*newRatio
    ruby.Font.OutlineSettings.OutlineSize=math.max(0,math.floor(outline*newRatio+.5));ruby:SetFont(ruby.Font)
    refresh(row);local desired=ruby:GetDesiredSize()
    assert(desired.X>0 and desired.Y>0 and desired.X<100000 and desired.Y<100000,'Ordinary title edge measurement unavailable')
    return desired.X,desired.Y
   end
   fitted=fitTitleEdges(runs,resizeEdge,boxSize.X);runs=fitted.runs
   for _,run in ipairs(runs)do
    run.width,run.height=resizeEdge(run,run.ratio);run.fontSize=before.fontSize*run.ratio
    local quarter=run.fullBaseCenter and 0 or (run.baseRight-run.baseLeft)*.25
    run.minimumX=run.baseLeft+quarter;run.maximumX=run.baseRight-quarter
    assert(run.x>=run.minimumX-.05 and run.x<=run.maximumX+.05,'Ordinary title ruby center left its allowed native base bounds')
    assert(run.x-run.width/2>=-.05 and run.x+run.width/2<=boxSize.X+.05,'Ordinary title ruby exceeds native width')
   end
   for i=2,#runs do local a,b=runs[i-1],runs[i]
    assert(b.x-a.x>=(a.width+b.width)/2+fitted.horizontalGap-.01,'Final ordinary-title native glyph measurements collide')
   end
   leftEdge,rightEdge,maxHeight=readingExtents()
   -- Verified inside the existing allocation: reserve no horizontal padding.
   left=0;right=0;wantedWidth=boxSize.X
  end
  assert(wantedWidth<=widthLimit+.05,'Title reading exceeds the available detail-column width')
  if scaledTitle then assert(left==0 and right==0,'Scaled-title readings must not enlarge native horizontal allocation')end
  local gap=options.gap or 1
  local top=bodyTop+line.y*contentScale-maxHeight-gap
  local reserve=math.max(options.topReserve or math.ceil(before.fontSize*.95*contentScale),math.ceil(math.max(0,-top)))
  local bp=padding(handle.originalBoxPadding)
  bp.Left=bp.Left+left;bp.Right=bp.Right+right
  if not scaledTitle then boxSlot:SetPadding(bp)end
  local rp=padding(handle.originalRowPadding)
  rp.Top=rp.Top+reserve;rowSlot:SetPadding(rp)
  if rowBox then rowBox:SetHeightOverride(handle.originalRowHeight+reserve) end
  refresh(row)
  local rowAfter=size(row:GetDesiredSize())
  for _,run in ipairs(runs)do
   run.y=bodyTop+line.y*contentScale-run.height-gap;run.lineTop=bodyTop+line.y*contentScale
   run.canvasX=bp.Left+run.x-rowAfter.X
   widgets[run.segment].slot:SetPosition({X=run.canvasX,Y=run.y})
   if run.fullBaseCenter then
    log('item_title_full_base_center segment='..run.segment..' reading='..run.reading..' ratio='..run.ratio..
     ' base='..run.baseLeft..','..run.baseRight..' center='..run.x..' width='..run.width..' height='..run.height)
   end
  end
  local rubyX=runs[1].canvasX
  refresh(row)
  local after=audit(w)
  log('item_title_candidate_before '..describe(before))
  log('item_title_candidate_after '..describe(after))
  assert(after.text==before.text,'Item title text changed while adding ruby')
  assertStyle(before,after)
  assert(close(after.desired.X,before.desired.X) and close(after.desired.Y,before.desired.Y),'Item title desired size changed while adding ruby')
  assert(after.opacity==before.opacity,'Item title opacity changed while adding ruby')
  assert(after.parentPath==before.parentPath and after.slotPath==before.slotPath,'Native title subtree changed')
  assert(path(scale:GetParent())==handle.boxPath and path(box:GetParent())==handle.rowPath,'Native title ancestors changed')
  if scaledTitle or nativeEdgeFit then
   assert(scale.Stretch==2 and scale.StretchDirection==1 and not scale.IgnoreInheritedScale,'Native title scale policy changed')
   assert(box.bOverride_HeightOverride==handle.originalHeightOverride and box.HeightOverride==handle.originalHeight
    and box.bOverride_WidthOverride==handle.originalWidthOverride and box.WidthOverride==handle.originalWidth
    and box.bOverride_MaxDesiredWidth==handle.originalMaxWidthOverride and box.MaxDesiredWidth==handle.originalMaxWidth,'Native scaled-title allocation changed')
  end
  stats={fontSize=before.fontSize,ratio=ratio,verticalCollisions=0,horizontalCollisions=0,
   initialHorizontalCollisions=fitted.initialCollisions,skipped={},adjustments=fitted.adjustments,placement='native-row-sibling',
   sourceBefore=before,sourceAfter=after,sourceTextUnchanged=true,sourceFontUnchanged=true,sourceSizeUnchanged=true,sourceSubtreeUnchanged=true,
   nativeCenter=center,nativeLineWidth=line.width,nativeBodyTop=bodyTop,nativeAllocatedWidth=boxSize.X,nativeAllocatedHeight=originalRowHeight,
   contentScale=contentScale,scaledTitle=scaledTitle,nativeEdgeFit=nativeEdgeFit,displayLineWidth=line.width*contentScale,displayLineHeight=line.height*contentScale,
   topReserve=reserve,leftReserve=left,rightReserve=right,titleWidth=wantedWidth,availableTitleWidth=widthLimit,titleHeight=box.HeightOverride,originalTitleHeight=boxSize.Y,
   originalWidthOverride=handle.originalWidthOverride,originalWidth=handle.originalWidth,widthOverride=box.bOverride_WidthOverride,width=box.WidthOverride,
   originalMaxWidthOverride=handle.originalMaxWidthOverride,originalMaxWidth=handle.originalMaxWidth,maxWidthOverride=box.bOverride_MaxDesiredWidth,maxWidth=box.MaxDesiredWidth,
   originalTitlePadding=handle.originalBoxPadding,titlePadding=bp,originalRowPadding=handle.originalRowPadding,rowPadding=rp,
   rowDesired=rowAfter,rubyCanvasX=rubyX,rubyCanvasY=top,
   lines={{text=before.text,x=line.x*contentScale,y=bodyTop+line.y*contentScale,width=line.width*contentScale,height=line.height*contentScale,firstByte=1,lastByte=#before.text}},
   runs=runs}
  if rowBox then
   stats.rowBoxPath=handle.rowBoxPath;stats.originalRowHeight=handle.originalRowHeight
   stats.originalRowHeightOverride=handle.originalRowHeightOverride
   stats.rowHeight=rowBox.HeightOverride;stats.rowHeightOverride=rowBox.bOverride_HeightOverride
   log('item_title_row_space before='..handle.originalRowHeight..' after='..rowBox.HeightOverride..' reserve='..reserve)
  end
  handle.stats=stats;handle.sourceAfter=after
  log('item_title_before '..describe(before));log('item_title_after '..describe(after))
  log('item_title_space top='..reserve..' left='..left..' right='..right..' width='..wantedWidth..' nativeRowHeight='..originalRowHeight..
   ' rowWidth='..rowAfter.X..' rubyXY='..rubyX..','..top..' placement=native-row-sibling')
 end)
 if not ok then
  if handle then M.detach(handle,log) end
  return nil,{reason=tostring(err),sourceBefore=handle and handle.sourceBefore}
 end
 return handle,stats
end
return M
