local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Local-map region-title diagnostics and independent ruby layer.
-- No original text, font, opacity, or widget parent is changed.
local M={}
local function valid(o) return o and o:IsValid() end
local function class(o) return o:GetClass():GetFName():ToString() end
local function path(o) return o:GetFullName():match('^[^ ]+ (.+)$') end
local function str(v) if type(v)=='string' then return v end return v:ToString() end
local function safe(fn) local ok,value=pcall(fn);return ok and tostring(value) or ('ERR '..tostring(value)) end
local function xy(v) return tostring(v.X)..','..tostring(v.Y) end
local function margin(v) return tostring(v.Left)..','..tostring(v.Top)..','..tostring(v.Right)..','..tostring(v.Bottom) end
local function zeroMargin(v) return v.Left==0 and v.Top==0 and v.Right==0 and v.Bottom==0 end
local function localMapWidget(name)
 return name:find('.WB_MapNew.',1,true)
  or name:match('%.W_TeleportMap_C_%d+%.WidgetTree_%d+%.WB_MapNew_%d+%.WidgetTree_%d+%.')
end
local function targets()
 local result={};local seen={}
 for _,w in ipairs(FindAllOf('PBZCommonLocText') or {}) do
  local name=w:GetFullName()
  if name:find('/Engine/Transient',1,true) and localMapWidget(name) and name:match('%.MapText$') and not seen[name] then
   seen[name]=true;result[#result+1]=w
  end
 end
 return result
end
local function parent(w)
 local result=w:GetParent()
 if not valid(result) then
  local tree=w:GetOuter()
  if valid(tree) and class(tree)=='WidgetTree' then
   local owner=tree:GetOuter()
   if valid(owner) and owner:GetFullName()~=w:GetFullName() then result=owner end
  end
 end
 return result
end
local function size(value) return {X=value.X,Y=value.Y} end
local function near(a,b) return math.abs(a-b)<.05 end
local function visible(w)
 local p=w
 for _=1,30 do
  if not valid(p) then break end
  if p:GetVisibility()==1 or p:GetVisibility()==2 or p:GetRenderOpacity()<.01 then return false end
  local nextParent=parent(p)
  if valid(nextParent) then
   local parentClass=class(nextParent)
   if parentClass=='PBZCommonVisibilitySwitcher' or parentClass=='CommonVisibilitySwitcher' then
    local active=nextParent:GetActiveWidget()
    if not valid(active) or path(active)~=path(p) then return false end
   end
  end
  p=nextParent
 end
 return true
end
local function refresh(w)
 local p=w
 for _=1,20 do
  if not valid(p) then break end
  p:ForceLayoutPrepass();p=parent(p)
 end
end
local function make(name,outer,id)
 local result=StaticConstructObject(StaticFindObject('/Script/UMG.'..name),outer,FName(id))
 assert(valid(result),'Could not construct map '..name)
 return result
end
local function sourceAudit(w)
 local f=w.Font;local c=w.ColorAndOpacity;local rgba=c.SpecifiedColor
 return {text=str(w:GetText()),fontSize=f.Size,fontObject=valid(f.FontObject) and f.FontObject:GetFullName() or '',
  typeface=str(f.TypefaceFontName),letterSpacing=f.LetterSpacing,opacity=w:GetRenderOpacity(),desired=size(w:GetDesiredSize()),
  color={R=rgba.R,G=rgba.G,B=rgba.B,A=rgba.A,rule=c.ColorUseRule},parentPath=path(w:GetParent()),slotPath=path(w.Slot)}
end
local function sameSource(before,after)
 for _,key in ipairs({'text','fontSize','fontObject','typeface','letterSpacing','opacity','parentPath','slotPath'}) do
  assert(before[key]==after[key],'Map source changed: '..key)
 end
 for _,key in ipairs({'R','G','B','A','rule'}) do assert(before.color[key]==after.color[key],'Map source color changed: '..key) end
 assert(near(before.desired.X,after.desired.X) and near(before.desired.Y,after.desired.Y),'Map source desired size changed')
end
local function describe(a)
 return a.text..' font='..a.fontSize..' desired='..a.desired.X..','..a.desired.Y..' opacity='..a.opacity..
  ' fontObject='..a.fontObject..' spacing='..a.letterSpacing..' color='..a.color.R..','..a.color.G..','..a.color.B..','..a.color.A
end

function M.detach(handle,log)
 if not handle then return true end
 log=log or function()end
 local ok,err=pcall(function()
  local bounds=handle.path and StaticFindObject(handle.path)
  if valid(bounds) then bounds:RemoveFromParent() end
  local row=StaticFindObject(handle.rowPath)
  if valid(row) then refresh(row) end
  local w=StaticFindObject(handle.sourcePath)
  if valid(w) then
   handle.restored=sourceAudit(w)
   log('map_source_restore '..describe(handle.restored))
  end
 end)
 if not ok then log('map_restore_error '..tostring(err)) end
 return ok,err
end

function M.attach(w,term,state,log,root)
 log=log or function()end
 local handle
 local ok,err=pcall(function()
  assert(valid(w) and str(w:GetText())==term.japanese and term.category=='region','Map region source mismatch')
  local segments=term.segments or {{text=term.japanese,reading=term.reading}}
  local parts={};local readingCount=0
  for _,segment in ipairs(segments)do
   parts[#parts+1]=segment.text
   if segment.reading and segment.reading~='' then readingCount=readingCount+1 end
  end
  assert(table.concat(parts)==term.japanese and readingCount>0,'Map segments must preserve the localized title and contain reviewed readings')
  local before=sourceAudit(w);local box=w:GetParent();local row=valid(box) and box:GetParent()
  assert(valid(box) and class(box)=='SizeBox' and valid(row) and class(row)=='VerticalBox','Unexpected map-title hierarchy')
  assert(row:GetFullName():match('%.PercentageVerticalBox$'),'Unexpected map-title row')
  assert(row:GetChildrenCount()>0 and path(row:GetChildAt(0))==path(box),'Map title must be the first vertical child')
  assert(w.Justification==0 and not w.AutoWrapText and w.WrapTextAt==0,'Only unwrapped left-justified map labels are supported')
  assert(w.Slot.HorizontalAlignment==0 and w.Slot.VerticalAlignment==0 and zeroMargin(w.Slot.Padding),'Unsupported source map-title alignment or padding')
  assert(box.Slot.HorizontalAlignment==0 and box.Slot.VerticalAlignment==0 and zeroMargin(box.Slot.Padding),'Unsupported map-title box alignment or padding')
  local rowBefore=size(row:GetDesiredSize());local boxBefore=size(box:GetDesiredSize())
  assert(before.desired.X>0 and before.desired.Y>0 and rowBefore.Y>0,'Map title is not laid out')
  local nativeChildren={};local childHeight=0
  for index=0,row:GetChildrenCount()-1 do
   local child=row:GetChildAt(index);local slot=child.Slot
   assert(valid(slot) and class(slot)=='VerticalBoxSlot','Unexpected map vertical slot')
   nativeChildren[#nativeChildren+1]={path=path(child),slotPath=path(slot)}
   if child:GetVisibility()~=1 then
    assert(slot.Size.SizeRule==0,'Map title container requires automatic-height children')
    local pad=slot.Padding;childHeight=childHeight+pad.Top+child:GetDesiredSize().Y+pad.Bottom
   end
  end
  assert(near(childHeight,rowBefore.Y),'Map title child heights differ from desired row height')
  local rowCanvasSlot=row.Slot
  assert(valid(rowCanvasSlot) and class(rowCanvasSlot)=='CanvasPanelSlot','Map title row requires native canvas placement')
  local anchors=rowCanvasSlot.LayoutData.Anchors
  assert(anchors.Minimum.X==anchors.Maximum.X and anchors.Minimum.Y==anchors.Maximum.Y,'Stretched map row needs allocated-size positioning')
  if not rowCanvasSlot.bAutoSize then
   local offsets=rowCanvasSlot.LayoutData.Offsets
   assert(offsets.Bottom>=rowBefore.Y-.05,'Native map row is shorter than its desired content')
  end
  state.serial=(state.serial or 0)+1
  local prefix='PBZFurigana_Map_'..state.serial..'_'
  handle={sourcePath=path(w),boxPath=path(box),rowPath=path(row),sourceBefore=before,rowBefore=rowBefore,boxBefore=boxBefore,nativeChildren=nativeChildren,term_id=term.id}
  local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds');handle.path=path(bounds)
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(before.opacity)
  local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Canvas');canvas:SetVisibility(3)
  local canvasSlot=bounds:AddChild(canvas);canvasSlot:SetHorizontalAlignment(0);canvasSlot:SetVerticalAlignment(0)
  local endSlot=row:AddChildToVerticalBox(bounds)
  endSlot:SetSize({Value=1,SizeRule=0});endSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
  endSlot:SetHorizontalAlignment(0);endSlot:SetVerticalAlignment(0)
  local runs,widgets,fitted
  if #segments==1 then
   local ruby=make('TextBlock',w:GetOuter(),prefix..'Reading')
   ruby:SetFont(w.Font);ruby.Font.Size=before.fontSize*.6;ruby.Font.LetterSpacing=0
   ruby.Font.OutlineSettings.OutlineSize=math.max(0,math.floor(w.Font.OutlineSettings.OutlineSize*.6+.5))
   ruby:SetFont(ruby.Font);ruby:SetText(FText(segments[1].reading));ruby:SetColorAndOpacity(w.ColorAndOpacity)
   ruby:SetJustification(1);ruby:SetAutoWrapText(false);ruby:SetVisibility(3)
   local rubySlot=canvas:AddChildToCanvas(ruby);rubySlot:SetAutoSize(true);rubySlot:SetAlignment({X=.5,Y=0});rubySlot:SetZOrder(1)
   refresh(row);local rubySize=size(ruby:GetDesiredSize())
   assert(rubySize.X>0 and rubySize.Y>0,'Map reading measurement unavailable')
   runs={{segment=1,text=term.japanese,reading=segments[1].reading,line=1,
    x=before.desired.X/2,ratio=.6,fontSize=before.fontSize*.6,width=rubySize.X,height=rubySize.Y}}
   widgets={[1]={widget=ruby,slot=rubySlot}};fitted={initialCollisions=0,remainingCollisions=0,adjustments={}}
  else
   assert(type(root)=='string','Segmented map labels require the configured mod root')
   local adapter=assert(loadfile(root..'Scripts/item_title_ruby.lua'))()
   runs,widgets,fitted=adapter.build_segment_runs(w,segments,canvas,row,prefix,root,{font=w.Font,color=w.ColorAndOpacity,
    text=before.text,rects={{x=0,y=0,width=before.desired.X,height=before.desired.Y}},ratio=.6,shadowX=w.ShadowOffset.X})
  end
  assert(#runs==readingCount,'Map reading coverage differs from its reviewed segments')
  local leftEdge,rightEdge,maxHeight=math.huge,-math.huge,0
  for _,run in ipairs(runs)do
   run.y=-rowBefore.Y-run.height-2
   -- Existing local-map left inset permits modest overhang without moving it.
   assert(run.x-run.width/2>=-80 and run.x+run.width/2<=800,'Map reading exceeds the tested title area')
   widgets[run.segment].slot:SetPosition({X=run.x,Y=run.y})
   leftEdge=math.min(leftEdge,run.x-run.width/2);rightEdge=math.max(rightEdge,run.x+run.width/2);maxHeight=math.max(maxHeight,run.height)
  end
  refresh(row)
  local after=sourceAudit(w);sameSource(before,after)
  local rowAfter=size(row:GetDesiredSize());local boxAfter=size(box:GetDesiredSize())
  assert(near(rowBefore.X,rowAfter.X) and near(rowBefore.Y,rowAfter.Y),'Map original row desired size changed')
  assert(near(boxBefore.X,boxAfter.X) and near(boxBefore.Y,boxAfter.Y),'Map original SizeBox desired size changed')
  for index,child in ipairs(nativeChildren) do
   local current=row:GetChildAt(index-1)
   assert(path(current)==child.path and path(current.Slot)==child.slotPath,'Map original child or slot was replaced')
  end
  handle.stats={sourceBefore=before,sourceAfter=after,rowBefore=rowBefore,rowAfter=rowAfter,boxBefore=boxBefore,boxAfter=boxAfter,
   reading=term.reading,fontSize=before.fontSize*.6,ratio=.6,width=rightEdge-leftEdge,height=maxHeight,
   x=(leftEdge+rightEdge)/2,y=-rowBefore.Y-maxHeight-2,top=-maxHeight-2,runs=runs,
   skipped={},horizontalCollisions=fitted.remainingCollisions,initialHorizontalCollisions=fitted.initialCollisions,adjustments=fitted.adjustments,
   sourceUnchanged=true,sourceSubtreeUnchanged=true,sourceLayoutUnchanged=true,placement='native-vertical-sibling'}
  log('map_source_before '..describe(before));log('map_source_after '..describe(after))
  for _,run in ipairs(runs)do
   log('map_ruby text='..run.text..' reading='..run.reading..' ratio='..run.ratio..' xy='..run.x..','..run.y..' readingSize='..run.width..','..run.height..' row='..rowBefore.X..','..rowBefore.Y)
  end
 end)
 if not ok then if handle then M.detach(handle,log) end;return nil,{reason=tostring(err)} end
 return handle,handle.stats
end

local SCRIPT = 'Scripts/'

local function markerRoute(marker)
 local w = marker.PBZCommonLocText_45
 if not valid(w) or class(w) ~= 'PBZCommonLocText' or not visible(w) then return end
 if w.Justification ~= 0 or w.AutoWrapText or str(w:GetText()):find('[\r\n<>]') then return end
 local horizontal = w:GetParent()
 local vertical = valid(horizontal) and horizontal:GetParent()
 local overlay = valid(vertical) and vertical:GetParent()
 if not valid(overlay) or class(horizontal) ~= 'HorizontalBox' or class(vertical) ~= 'VerticalBox'
  or class(overlay) ~= 'Overlay' or not overlay:GetFullName():match('%.Overlay_0$') then return end
 local font = w.Font
 if not valid(font.FontObject) or not font.FontObject:GetFullName():find('/Fonts/JP_',1,true) then return end
 return w, overlay, font
end

local function updateMarkers(state, log, root, renderer, lookup, geometryModule)
 local layers = state.map_marker_layers
 local seen = {}
 for _, marker in ipairs(FindAllOf('W_MapBellText_Widget_C') or {}) do
  local full = valid(marker) and marker:GetFullName() or ''
  if full:find('/Engine/Transient.',1,true) and localMapWidget(full) then
   local w, overlay, font = markerRoute(marker)
   local text = w and str(w:GetText())
   local layer = layers[full]
   if w and (lookup('map_title', '', text) or layer) then
    seen[full] = true
    local desired = w:GetDesiredSize()
    local parentPadding = w:GetParent():GetParent().Slot.Padding
    local sig = table.concat({text, font.Size, font.LetterSpacing, desired.X, desired.Y,
     parentPadding.Left, parentPadding.Right, parentPadding.Top, parentPadding.Bottom}, '|')
    if layer and layer.signature ~= sig then
     renderer.detach(layer.handle)
     layers[full] = nil
     layer = nil
    end
    local entry = not layer and lookup('map_title', '', text)
    if entry and desired.X > 0 and desired.Y > 0 then
     local geometry = geometryModule.new(root)
     local ok, r = pcall(function() return geometry.relative(geometry.read(w),geometry.read(overlay)) end)
     if ok and r.width >= desired.X-.05 and r.height >= desired.Y-.05 then
      local handle, stats = renderer.attach(w, entry.segments, state, log, {
       sourceText = text, overlay = overlay, originX = r.x, originY = r.y, availableWidth = r.width,
       rects = {{x=0,y=0,width=desired.X,height=desired.Y}},
       font = font, plainSource = true, rubyColor = w.ColorAndOpacity, shadowX = w.ShadowOffset.X,
       preserveNativeLines = true, ratio = .5, gap = 0, requireAllReadings = true, protectSource = true,
       boundedHorizontal = true, clipLeft = -4, clipRight = desired.X+4,
      })
      layers[full] = {signature=sig,handle=handle}
      if handle then
       log('map_marker_result '..entry.key..' attached')
      else
       log('map_marker_layout_error '..entry.key..' '..tostring(stats.reason))
      end
     end
    end
   end
  end
 end
 for id, layer in pairs(layers) do
  if not seen[id] then renderer.detach(layer.handle);layers[id]=nil end
 end
end

function M.stop(state,log,root)
 state.map_active=false
 for _,layer in pairs(state.map_layers or {}) do M.detach(layer.handle,log) end
 state.map_layers={};state.map_wait={}
 if next(state.map_marker_layers or {}) then
  local renderer = assert(loadfile(root..SCRIPT..'subtitle_ruby.lua'))()
  for id, layer in pairs(state.map_marker_layers) do
   renderer.detach(layer.handle)
   state.map_marker_layers[id] = nil
  end
 end
end

function M.start(state,log,root)
 M.stop(state,log,root)
 local regions=compact.exact(assert(loadfile(root..'Scripts/game_terms.lua'))())
 local index = assert(loadfile(root..SCRIPT..'surface_readings.lua'))()
 local extra = assert(loadfile(root..SCRIPT..'menu_coverage_readings.lua'))()
 local markerLookup = state.map_marker_lookup or index.index(extra.map)
 state.map_marker_lookup = markerLookup
 local markerRenderer = assert(loadfile(root..SCRIPT..'subtitle_ruby.lua'))()
 local geometryModule = assert(loadfile(root..SCRIPT..'geometry_service.lua'))()
 state.map_marker_layers = {}
 state.map_active=true;state.ruby_enabled=true;state.map_layers={};state.map_wait={}
 state.map_tick=function()
  updateMarkers(state, log, root, markerRenderer, markerLookup, geometryModule)
  local seen={}
  for _,w in ipairs(targets()) do
   local full=w:GetFullName();seen[full]=true
   local shown=visible(w);local text=str(w:GetText());local term=regions[text];if term then term.japanese=text end
   local source=sourceAudit(w);local box=w:GetParent();local row=valid(box) and box:GetParent()
   local rowSize=valid(row) and row:GetDesiredSize() or {X=0,Y=0}
   local sig=text..'|'..tostring(shown)..'|'..source.fontObject..'|'..source.fontSize..'|'..source.letterSpacing..'|'..source.typeface..
    '|'..source.color.R..','..source.color.G..','..source.color.B..','..source.color.A..','..source.color.rule..
    string.format('|%.3f,%.3f,%.3f,%.3f|%.3f',source.desired.X,source.desired.Y,rowSize.X,rowSize.Y,source.opacity)
   local layer=state.map_layers[full]
   if layer and layer.signature~=sig then M.detach(layer.handle,log);state.map_layers[full]=nil;state.map_wait[full]=nil;layer=nil end
   if not shown then state.map_wait[full]=nil end
   if not layer and shown and term and source.desired.X>0 and source.desired.Y>0 then
    local pending=state.map_wait[full]
    if not pending or pending.signature~=sig then pending={signature=sig,ticks=0,attempts=0};state.map_wait[full]=pending end
    pending.ticks=pending.ticks+1
    if pending.ticks>=3 then
     local handle,stats=M.attach(w,term,state,log,root)
     pending.attempts=pending.attempts+1;pending.ticks=0
     if handle or pending.attempts>=3 then state.map_layers[full]={signature=sig,handle=handle,stats=stats,term=term} end
     log('map_result term='..term.id..' '..(handle and 'attached' or tostring(stats.reason)))
    end
   end
  end
  for full,layer in pairs(state.map_layers) do
   if not seen[full] then M.detach(layer.handle,log);state.map_layers[full]=nil;state.map_wait[full]=nil end
  end
 end
 if not state.map_timer then
  state.map_timer=true
  LoopInGameThreadWithDelay(150,function()
   if state.map_active and state.map_tick then
    local ok,err=pcall(state.map_tick)
    if not ok and state.map_error~=tostring(err) then state.map_error=tostring(err);log('map_tick_error '..tostring(err)) end
   end
  end)
 end
 log('map watcher active; region titles and visible markers')
end

return M
