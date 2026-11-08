-- Shared single-line PBZCommonLocText adapter. Most labels use a zero-size
-- ruby sibling. The boss label can also display a translated copy below its bar.
local M={}
local function valid(w)return w and w:IsValid()end
local function full(w)return valid(w)and w:GetFullName()or''end
local function path(w)return full(w):match('^[^ ]+ (.+)$')end
local function text(v)return type(v)=='string'and v or v:ToString()end
local function audit(w)
 local f=w.Font;local c=w.ColorAndOpacity.SpecifiedColor;local d=w:GetDesiredSize()
 return{text=text(w:GetText()),font=full(f.FontObject),fontSize=f.Size,spacing=f.LetterSpacing,typeface=text(f.TypefaceFontName),
  opacity=w:GetRenderOpacity(),width=d.X,height=d.Y,r=c.R,g=c.G,b=c.B,a=c.A,parent=full(w:GetParent()),slot=full(w.Slot)}
end
local function equal(a,b)
 for k,v in pairs(a)do
  if type(v)=='number'then assert(math.abs(v-b[k])<.05,'Plain source changed: '..k)
  else assert(v==b[k],'Plain source changed: '..k)end
 end
end
function M.detach(h)
 if not h then return true end
 local w=StaticFindObject(h.auditedSourcePath);local before
 if valid(w)then before=audit(w)end
 local bounds=StaticFindObject(h.path);if valid(bounds)then bounds:RemoveFromParent()end
 if before and h.originalOpacity and before.opacity==0 then
  w:SetRenderOpacity(h.originalOpacity);before.opacity=h.originalOpacity
 end
 if h.overlayPath then
  local overlay=StaticFindObject(h.overlayPath)
  if valid(overlay)then overlay:InvalidateLayoutAndVolatility()end
 end
 if before then equal(before,audit(w))end
 return true
end
function M.activateOffset(h,opacity)
 local w=StaticFindObject(h.auditedSourcePath)
 local bounds=StaticFindObject(h.path)
 assert(valid(w) and valid(bounds),'Translated label lost its native source')
 h.originalOpacity=w:GetRenderOpacity()
 w:SetRenderOpacity(0)
 bounds:SetRenderOpacity(opacity)
 return h.originalOpacity
end
function M.attach(w,c,state,log,root)
 local h,stats
 local ok,why=pcall(function()
  assert(w:GetClass():GetFName():ToString()=='PBZCommonLocText','Expected native PBZ plain label')
  local before=audit(w);local overlay=c.route.overlay;local offset=c.plainOffset or 0
  local originalOverlaySize=offset>0 and overlay:GetDesiredSize()
  local width,height=offset>0 and c.route.width or 0,offset>0 and c.route.height or 0
  state.serial=(state.serial or 0)+1;local prefix='PBZFurigana_PlainLine_'..state.serial..'_'
  local function make(k,n)return assert(StaticConstructObject(assert(StaticFindObject('/Script/UMG.'..k)),w:GetOuter(),FName(prefix..n)))end
  local bounds=make('SizeBox','Bounds')
  h={path=path(bounds),auditedSourcePath=path(w),kind='general_plain_line'}
  bounds:SetWidthOverride(width);bounds:SetHeightOverride(height);bounds:SetVisibility(3)
  bounds:SetRenderOpacity(offset>0 and .001 or c.route.opacity)
  local canvas=make('CanvasPanel','Canvas');canvas:SetVisibility(3)
  local inner=bounds:AddChild(canvas);inner:SetHorizontalAlignment(0);inner:SetVerticalAlignment(0)
  local slot=overlay:AddChildToOverlay(bounds);slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
  if offset>0 then
   h.overlayPath=path(overlay)
   -- The health bar's invalidation root can cull a newly added zero-size
   -- layer. Give it a paint rect while neutralizing its desired size.
   slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(1)
   slot:SetPadding({Left=0,Top=0,Right=-width,Bottom=-height})
   bounds:ForceVolatile(true)
  end
  local helper=assert(loadfile(root..'Scripts/item_title_ruby.lua'))()
  local frame,rect=c.route.frame,c.route.rect
  local runs,widgets,fitted=helper.build_segment_runs(w,c.entry.segments,canvas,overlay,prefix,root,
   {font=w.Font,color=w.ColorAndOpacity,text=c.text,rects=c.lines,ratio=c.ratio or .6,shadowX=0,
    fontScale=c.contentScale,clipLeft=frame and frame.x-rect.x,clipRight=frame and frame.x+frame.width-rect.x})
  assert(#fitted.skipped==0 and fitted.remainingCollisions==0,'Plain label readings overlap')
  for _,run in ipairs(runs)do
   run.y=offset-run.height-1
   widgets[run.segment].slot:SetPosition({X=c.route.rect.x+run.x,Y=c.route.rect.y+run.y})
   -- Shared placement validation checks the actual outer Overlay and nearby
   -- native text; a reading may extend slightly beyond its base glyphs.
  end
  if offset>0 then
   local rect,line=c.route.rect,c.lines[1]
   assert(rect.x+line.x>=0 and rect.x+line.x+line.width<=c.route.width+.5
    and rect.y+offset+line.height<=c.route.height+.5,'Translated label leaves its native overlay')
   local copy=make('TextBlock','SourceCopy')
   copy:SetFont(w.Font);copy:SetColorAndOpacity(w.ColorAndOpacity);copy:SetText(w:GetText())
   copy.ShapedTextOptions=w.ShapedTextOptions
   copy:SetShadowOffset({X=0,Y=0});copy:SetAutoWrapText(false);copy:SetVisibility(3)
   local body=canvas:AddChildToCanvas(copy);body:SetAutoSize(true);body:SetZOrder(0)
   body:SetPosition({X=rect.x+line.x,Y=rect.y+offset})
   overlay:ForceLayoutPrepass()
   local size=copy:GetDesiredSize()
   assert(math.abs(size.X-line.width)<.5 and math.abs(size.Y-line.height)<.5,'Translated label changes native text size')
   local after=overlay:GetDesiredSize()
   assert(math.abs(after.X-originalOverlaySize.X)<.05 and math.abs(after.Y-originalOverlaySize.Y)<.05,
    'Translated label expanded the native overlay')
   overlay:InvalidateLayoutAndVolatility()
  else
   assert(bounds:GetDesiredSize().X==0 and bounds:GetDesiredSize().Y==0,'Plain ruby changes parent desired size')
  end
  equal(before,audit(w))
  if offset>0 then h.waitForPaint=true end
  stats={runs=runs,lines=c.lines,skipped={},horizontalCollisions=0,verticalCollisions=0,fontSize=before.fontSize,
   sourceBefore=before,sourceTextUnchanged=true,sourceFontUnchanged=true,sourceSizeUnchanged=true,inheritedOpacity=c.route.opacity,nativeSourceKind='PBZCommonLocText'}
 end)
 if not ok then if h then M.detach(h)end;return nil,{reason=tostring(why)}end
 return h,stats
end
return M
