local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Ruby-only adapter for native book alignment decorators.
-- PBZAlignDecorator keeps its original SBox/SRichTextBlock and source text.
-- Only complete, single-line, otherwise plain center paragraphs are supported.
-- A zero-desired-size sibling adds ruby; one saved OverlaySlot padding reserves
-- its height in the native scroll flow. No source text/style/opacity setter.
local M={}
local function valid(o)return o and o:IsValid()end
local function path(o)return o:GetFullName():match('^[^ ]+ (.+)$')end
local function class(o)return o:GetClass():GetFName():ToString()end
local function str(v)return type(v)=='string' and v or v:ToString()end
local function near(a,b)return math.abs(a-b)<.05 end
local function pad(p)return {Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom}end
local function size(s)return {X=s.X,Y=s.Y}end
local function equal(a,b)
 if type(a)~=type(b)then return false end
 if type(a)=='table'then
  for k,v in pairs(a)do if not equal(v,b[k])then return false end end
  for k in pairs(b)do if a[k]==nil then return false end end
  return true
 end
 if type(a)=='number'then return near(a,b)end
 return a==b
end
local function up(w)
 local p=w:GetParent()
 if not valid(p)then
  local tree=w:GetOuter()
  if valid(tree) and class(tree)=='WidgetTree'then p=tree:GetOuter()end
 end
 return p
end
local function refresh(w)
 local p=w
 for _=1,30 do if not valid(p)then return end;p:ForceLayoutPrepass();p=up(p)end
 error('Unresolved center layout ancestry')
end
local function make(name,outer,id)
 local o=StaticConstructObject(StaticFindObject('/Script/UMG.'..name),outer,FName(id))
 assert(valid(o),'Could not construct center '..name);return o
end
function M.scoped(w)
 if not valid(w) or class(w)~='PBZCommonLocRichText'then return false end
 local name=w:GetFullName()
 return name:find('/Engine/Transient.',1,true) and not name:find('Default__',1,true)
  and name:find('.WB_Literature.',1,true) and name:find('.W_UnifiedTextDescription.',1,true)
  and name:find('.DetailText.',1,true) and name:find('.W_PBZItemDescText_C_',1,true)
  and name:match('%.PBZCommonLocRichText_34$')~=nil
end
local function audit(w)
 local s=w.DefaultTextStyleOverride;local f=s.Font;local c=s.ColorAndOpacity
 local t=w.RenderTransform
 return {text=str(w:GetText()),namespace=str(w.LocText.Namespace),key=str(w.LocText.Key),
  font={size=f.Size,object=valid(f.FontObject)and path(f.FontObject)or '',typeface=str(f.TypefaceFontName),
   spacing=f.LetterSpacing,outline=f.OutlineSettings.OutlineSize},
  color={c.SpecifiedColor.R,c.SpecifiedColor.G,c.SpecifiedColor.B,c.SpecifiedColor.A,c.ColorUseRule},
  shadow={s.ShadowOffset.X,s.ShadowOffset.Y},culture=str(w.DisplayCultureOverride),
  wrap=w.WrapTextAt,autoWrap=w.AutoWrapText,justification=w.Justification,
  lineHeight=w.LineHeightPercentage,margin=pad(w.Margin),opacity=w:GetRenderOpacity(),
  desired=size(w:GetDesiredSize()),parent=path(w:GetParent()),slot=path(w.Slot),
  horizontal=w.Slot.HorizontalAlignment,vertical=w.Slot.VerticalAlignment,
  transform={t.Translation.X,t.Translation.Y,t.Scale.X,t.Scale.Y,t.Shear.X,t.Shear.Y,t.Angle}}
end
local function plainSegments(raw,segments)
 local tag,visible=raw:match('^<([a-z]+)>([^<>\r\n]+)</>$')
 assert(tag=='center' or tag=='right','Alignment requires one complete nonnested plain paragraph')
 local all={};for _,p in ipairs(segments)do all[#all+1]=p.text end
 assert(table.concat(all)==raw,'Center source segments mismatch')
 local out={};local first,last=#tag+3,#raw-3;local offset=1
 for _,segment in ipairs(segments)do
  local finish=offset+#segment.text-1;local a,b=math.max(first,offset),math.min(last,finish)
  if a<=b then
   assert(not segment.reading or (a==offset and b==finish),'Center tag intersects a reading')
   local copy={};for k,v in pairs(segment)do copy[k]=v end
   copy.text=segment.text:sub(a-offset+1,b-offset+1);out[#out+1]=copy
  else assert(not segment.reading,'Center tag cannot receive a reading')end
  offset=finish+1
 end
 all={};for _,p in ipairs(out)do all[#all+1]=p.text end
 assert(table.concat(all)==visible,'Center visible segmentation mismatch')
 return visible,out,tag
end
M.plain_segments=plainSegments

function M.detach(handle,log)
 if not handle then return true end;log=log or function()end
 local errors={}
 local function attempt(label,fn)local ok,e=pcall(fn);if not ok then errors[#errors+1]=label..': '..tostring(e)end end
 local bounds=handle.path and StaticFindObject(handle.path)
 if valid(bounds)then attempt('ruby removal',function()bounds:RemoveFromParent()end)end
 local w=StaticFindObject(handle.sourcePath)
 if valid(w)then
  attempt('padding restore',function()
   assert(valid(w.Slot) and path(w.Slot)==handle.slotPath,'Native center slot was replaced')
   local current=pad(w.Slot.Padding)
   assert(equal(current,handle.appliedPadding) or equal(current,handle.originalPadding),'Native center padding changed externally')
   w.Slot:SetPadding(pad(handle.originalPadding));refresh(w)
   handle.paddingRestored=equal(pad(w.Slot.Padding),handle.originalPadding)
   assert(handle.paddingRestored,'Center padding restoration failed')
  end)
  attempt('source audit',function()
   handle.restoreAudit=audit(w)
   handle.sourceUnchanged=equal(handle.sourceBefore,handle.restoreAudit)
  end)
 end
 handle.restoreErrors=errors
 if #errors>0 then log('book_center_restore_error '..table.concat(errors,'; '));return false,table.concat(errors,'; ')end
 return true,handle.restoreAudit
end

function M.attach(w,segments,state,log,root,options)
 log=log or function()end;options=options or {};local handle;local stats
 local ok,err=pcall(function()
  assert(M.scoped(w),'Center ruby is restricted to the observed native literature body')
  local visible,parts,alignment=plainSegments(str(w:GetText()),segments)
  if alignment=='right' then
   assert(compact.fingerprint(visible)=='36:049f1ad207c22bd9','Unreviewed right-aligned book signature')
  end
  local overlay=w:GetParent();local slot=w.Slot
  assert(valid(overlay) and class(overlay)=='Overlay' and valid(slot) and class(slot)=='OverlaySlot','Center native body layout changed')
  assert((slot.HorizontalAlignment==0 or slot.HorizontalAlignment==1)and slot.VerticalAlignment==1,'Unsupported center native alignment')
  local before=audit(w);local font=w.DefaultTextStyleOverride.Font
  assert(before.opacity>0 and before.font.size>0 and before.font.object~='','Center source has no visible resolved font')
  assert(before.font.spacing==0 and before.font.outline==0 and before.shadow[1]==0 and before.shadow[2]==0,'Unmeasured center spacing/outline/shadow')
  assert(equal(before.transform,{0,0,1,1,0,0,0})and equal(before.margin,{Left=0,Top=0,Right=0,Bottom=0}),'Unsupported center transform/margin')
  assert(not before.autoWrap and before.justification==0 and before.wrap>0 and near(before.desired.X,before.wrap),'Unproven center width constraint')
  local found=false
  local function check(o)if valid(o)and o:GetFullName():find('/Script/ProjectPBZ.PBZAlignDecorator',1,true)then found=true end end
  if type(w.DecoratorClasses)=='table'then for _,o in ipairs(w.DecoratorClasses)do check(o)end
  else w.DecoratorClasses:ForEach(function(_,v)local ok,value=pcall(function()return v:get()end);check(ok and value or v)end)end
  assert(found,'Native center decorator is not present')
  local mapped=false;w.TagStyleMapping:ForEach(function()mapped=true end)
  assert(not mapped,'Mapped center tag requires separate review')
  local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
  local rects=renderer.rects(w)
  assert(#rects==1 and near(rects[1].x,0)and near(rects[1].y,0)and near(rects[1].width,before.wrap)
   and near(rects[1].height,before.desired.Y),'Center must retain one measured native inline box')
  state.serial=(state.serial or 0)+1;local prefix='PBZFurigana_BookCenter_'..state.serial..'_'
  local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds')
  handle={kind='book_center',path=path(bounds),sourcePath=path(w),slotPath=path(slot),
   sourceBefore=before,originalOpacity=before.opacity,originalPadding=pad(slot.Padding),appliedPadding=pad(slot.Padding)}
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(before.opacity)
  local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Canvas');handle.canvasPath=path(canvas)
  canvas:SetVisibility(3)
  local cs=bounds:AddChild(canvas);cs:SetHorizontalAlignment(0);cs:SetVerticalAlignment(0)
  local bs=overlay:AddChildToOverlay(bounds);bs:SetHorizontalAlignment(0);bs:SetVerticalAlignment(0)
  -- Native SRichTextBlock has the resolved default style, not the outer
  -- 530-pixel inline-box rect. Measure that plain inner text in the same tree.
  local measure=make('RichTextBlock',w:GetOuter(),prefix..'MeasureRich')
  measure:SetDefaultTextStyle(w.DefaultTextStyleOverride);measure:SetDefaultFont(font)
  -- Generic URichTextBlock has inherited WrapTextAt, but PBZ's
  -- SetWrapTextWidth convenience function is not part of that class.
  measure:SetAutoWrapText(false);measure.WrapTextAt=0;measure:SetJustification(0)
  measure:SetVisibility(3);measure:SetRenderOpacity(0)
  local ms=canvas:AddChildToCanvas(measure);ms:SetAutoSize(true)
  local checkMeasure=make('TextBlock',w:GetOuter(),prefix..'MeasurePlain')
  checkMeasure:SetFont(font);checkMeasure:SetAutoWrapText(false);checkMeasure:SetShadowOffset({X=0,Y=0})
  checkMeasure:SetVisibility(3);checkMeasure:SetRenderOpacity(0)
  canvas:AddChildToCanvas(checkMeasure):SetAutoSize(true)
  local widths={['']=0};local measured={}
  local function width(text)
   if widths[text]~=nil then return widths[text]end
   measure:SetText(FText(text));checkMeasure:SetText(FText(text));refresh(overlay)
   local a,b=measure:GetDesiredSize().X,checkMeasure:GetDesiredSize().X
   assert(a>0 and b>0 and math.abs(a-b)<=.8,'Center native rich/plain font advances disagree')
   assert(measure.DefaultTextStyleOverride.Font.Size==font.Size,'Center measurement font changed')
   widths[text]=a;measured[#measured+1]={text=text,richWidth=a,textWidth=b};return a
  end
  local textWidth=width(visible)
  assert(textWidth<=before.wrap+.05,'Centered paragraph would wrap; not supported')
  local left=(before.wrap-textWidth)/(alignment=='center' and 2 or 1)
  local plan,reason=renderer.layout(visible,parts,{{x=left,y=0,width=textWidth,height=rects[1].height}},width,.8,{outline=0,shadowX=0,glyphOffset=0})
  assert(plan,reason);assert(#plan.lines==1 and #plan.skipped==0 and #plan.runs>0,'Center reading crosses a native line boundary')
  local widgets,candidates={},{}
  local ratio=options.ratio or .6;assert(ratio>=.45 and ratio<=.6,'Unsupported center ruby ratio')
  for _,run in ipairs(plan.runs)do
   local ruby=make('TextBlock',w:GetOuter(),prefix..'Reading_'..run.segment)
   ruby:SetFont(font);ruby.Font.Size=font.Size*ratio;ruby.Font.LetterSpacing=0;ruby:SetFont(ruby.Font)
   ruby:SetText(FText(run.reading));ruby:SetColorAndOpacity(w.DefaultTextStyleOverride.ColorAndOpacity)
   ruby:SetShadowOffset({X=0,Y=0});ruby:SetJustification(1);ruby:SetAutoWrapText(false);ruby:SetVisibility(3)
   local rs=canvas:AddChildToCanvas(ruby);rs:SetAutoSize(true);rs:SetAlignment({X=.5,Y=0});rs:SetZOrder(1)
   refresh(overlay);local desired=ruby:GetDesiredSize()
   candidates[#candidates+1]={segment=run.segment,text=run.text,reading=run.reading,line=1,
    x=run.x,baseLeft=run.baseLeft,baseRight=run.baseRight,ratio=ratio,width=desired.X,height=desired.Y}
   widgets[run.segment]={widget=ruby,slot=rs}
  end
  local function resize(run,newRatio)
   local ruby=widgets[run.segment].widget;ruby.Font.Size=font.Size*newRatio;ruby:SetFont(ruby.Font)
   refresh(overlay);local d=ruby:GetDesiredSize();return d.X,d.Y
  end
  local fit={minimumRatio=.45,horizontalGap=2}
  if alignment=='right' then fit.clipLeft,fit.clipRight=0,before.wrap end
  local fitted=renderer.fit_subtitle_horizontal(candidates,resize,fit)
  assert(not fitted.reason,fitted.reason)
  assert(#fitted.skipped==0 and fitted.remainingCollisions==0,'Center readings collide')
  local reserve=0
  for _,run in ipairs(fitted.runs)do
   run.width,run.height=resize(run,run.ratio);run.fontSize=font.Size*run.ratio
   assert(run.x-run.width/2>=0 and run.x+run.width/2<=before.wrap,'Center ruby exceeds native paragraph width')
   reserve=math.max(reserve,run.height+1)
  end
  reserve=math.ceil(reserve)
  handle.appliedPadding={Left=handle.originalPadding.Left,Right=handle.originalPadding.Right,
   Top=handle.originalPadding.Top+reserve,Bottom=handle.originalPadding.Bottom}
  slot:SetPadding(pad(handle.appliedPadding))
  for _,run in ipairs(fitted.runs)do
   run.y=handle.originalPadding.Top+reserve-run.height-1
   widgets[run.segment].slot:SetPosition({X=handle.originalPadding.Left+run.x,Y=run.y})
  end
  measure:RemoveFromParent();checkMeasure:RemoveFromParent();refresh(w)
  local after=audit(w);assert(equal(before,after),'Center source text/style/layout changed')
  local bd=bounds:GetDesiredSize();assert(near(bd.X,0)and near(bd.Y,0),'Center ruby sibling affects desired size')
  stats={kind='book_center_ruby_only',sourceBefore=before,sourceAfter=after,sourceTextUnchanged=true,
   sourceFontUnchanged=true,sourceSizeUnchanged=true,sourceOpacityUnchanged=true,
   sourceTagsRetained=true,nativeSourceVisible=true,nativeCenterPreserved=alignment=='center',alignment=alignment,
   visibleText=visible,centerBoxWidth=before.wrap,nativeTextWidth=textWidth,nativeTextLeft=left,
   measurementModel='native RichTextBlock resolved-style advances crosschecked against native TextBlock',
   measurements=measured,runs=fitted.runs,lines=plan.lines,skipped={},remainingCollisions=0,
   horizontalCollisions=0,verticalCollisions=0,topReserve=reserve,addedBottomPadding=0,
   reflow=false,richText=true,originalPadding=handle.originalPadding,appliedPadding=handle.appliedPadding}
  handle.stats=stats;handle.sourceAfter=after
  log('book_center_attach runs='..#stats.runs..' innerWidth='..textWidth..' centerLeft='..left..' topReserve='..reserve)
 end)
 if not ok then
  local restored=handle and M.detach(handle,log)
  return nil,{reason=tostring(err),rollback=not not restored,sourceBefore=handle and handle.sourceBefore}
 end
 return handle,stats
end
return M
