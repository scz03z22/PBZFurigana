-- Shared adapter for reviewed plain native rich text. Single lines keep their
-- source visible; multiline copies reserve reversible space in the source slot.
local M={}
local nativeGeometry
local frameCache
local NIL={}
local function memo(o,key,read)
 if not frameCache then return read()end
 local id=o:GetAddress();local row=frameCache[id]
 if not row then row={};frameCache[id]=row end
 local v=row[key];if v~=nil then if v==NIL then return nil end;return v end
 v=read();row[key]=v==nil and NIL or v;return v
end
local EXCLUDED={chapter_dialogue=true,character=true,item_body=true,item_title=true,
 book_body=true,map_title=true,tutorial_hint=true,untyped=true,unverified_item_variant=true}
local function valid(o)local ok,v=pcall(function()return o and o:IsValid()end);return ok and v==true end
local function full(o)return valid(o)and memo(o,'name',function()return o:GetFullName()end)or''end
local function path(o)return full(o):match('^[^ ]+ (.+)$')or''end
local function kind(o)return valid(o)and memo(o,'kind',function()return o:GetClass():GetFName():ToString()end)or''end
local function str(v)return type(v)=='string'and v or v:ToString()end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<65536 end
local classes={}
local function isa(o,class)
 if not valid(o)then return false end
 if not classes[class]then classes[class]=assert(StaticFindObject(class),'Missing widget class '..class)end
 return memo(o,'isa:'..class,function()return o:IsA(classes[class])end)
end
local function widget(o)return isa(o,'/Script/UMG.Widget')end
local function runtimeWidget(o)
 if not widget(o)then return false end
 local name=full(o)
 return name:find('/Engine/Transient.',1,true)~=nil and not name:find('Default__',1,true)
end
local function parent(w,state)
 assert(widget(w),'Parent traversal requires UWidget')
 local resolve=state and state.general_rich_tree_parent
 return memo(w,resolve and 'treeParent' or 'parent',function()
 local p=w:GetParent();if valid(p)then assert(widget(p),'Native parent is not UWidget');return p end
 local tree=w:GetOuter()
 if kind(tree)=='WidgetTree'then
  local owner=tree:GetOuter()
  -- Template WidgetTrees can be owned by a BlueprintGeneratedClass. UObject
  -- validity alone does not make calling UWidget functions on that owner safe.
  if widget(owner)then
   if resolve then
    local attached=resolve(w,owner)
    if attached~=nil then return attached end
   end
   return owner
  end
 end
 end)
end
local function opacity(w)return memo(w,'opacity',function()return w:GetRenderOpacity()end)end
local function geometry(w)return memo(w,'geometry',function()return nativeGeometry.read(w)end)end
local function shown(w,state,depth)
 if not valid(w)then return true end
 depth=(depth or 0)+1;if depth>48 or not runtimeWidget(w)then return false end
 return memo(w,'shown',function()
  local name=full(w)
  local alpha=opacity(w)
  local owned=state and state.general_rich_layers and state.general_rich_layers[name]
  if owned and owned.originalOpacity then alpha=owned.originalOpacity end
  local v=memo(w,'visibility',function()return w:GetVisibility()end);if v==1 or v==2 or alpha<.01 then return false end
  local p=parent(w,state)
  if p==false then return false end
  if valid(p)and(isa(p,'/Script/UMG.WidgetSwitcher')or isa(p,'/Script/CommonUI.CommonVisibilitySwitcher'))then
   if memo(p,'activeWidget',function()return full(p:GetActiveWidget())end)~=name then return false end
  end
  if isa(w,'/Script/CommonUI.CommonActivatableWidget')then
   local passive=state and state.general_rich_passive_visible
   if memo(w,'activated',function()return w:IsActivated()end)==false and not (passive and passive(w))then return false end
  end
  return shown(p,state,depth)
 end)
end
local function claimed(state,name)
 for key,layers in pairs(state)do
  if type(key)=='string'and key~='general_rich_layers'and key:match('_layers$')and type(layers)=='table'then
   local layer=layers[name]or layers[name:match('^[^ ]+ (.+)$')or'']
   if type(layer)=='table'and layer.handle then return true end
  end
 end
 return false
end
local function rect(g,slate,mathLib,overlayGeometry)
 local s=slate:GetLocalSize(g);assert(s.X>0 and s.Y>0,'unallocated text geometry')
 local function point(x,y)
  local p=slate:AbsoluteToLocal(overlayGeometry,slate:LocalToAbsolute(g,mathLib:MakeVector2D(x,y)))
  return{X=p.X,Y=p.Y}
 end
 local p=point(0,0);local q=point(s.X,s.Y);local x=point(1,0);local y=point(0,1)
 assert(finite(p.X)and finite(p.Y)and finite(q.X)and finite(q.Y),'nonfinite geometry')
 assert(math.abs(x.X-p.X-1)<.002 and math.abs(x.Y-p.Y)<.002 and math.abs(y.X-p.X)<.002 and math.abs(y.Y-p.Y-1)<.002,'relative text transform unsupported')
 return{x=p.X,y=p.Y,width=q.X-p.X,height=q.Y-p.Y}
end
local function allocatedGeometry(w,slate)
 local g=w:GetCachedGeometry();local s=slate:GetLocalSize(g)
 if s.X<=0 or s.Y<=0 then g=w:GetPaintSpaceGeometry();s=slate:GetLocalSize(g)end
 return g,{X=s.X,Y=s.Y}
end
local function route(w,outermost,allowClip,acceptOverlay,state)
 local p=parent(w,state);local overlay
 for _=1,32 do
  if not valid(p)then break end
  if kind(p)=='Overlay'and(not acceptOverlay or acceptOverlay(w,p))then overlay=p;if not outermost then break end end
  local clipping=memo(p,'clipping',function()return p:GetClipping()end)
  assert(clipping==0 or (allowClip and allowClip(w,p,clipping)),'crossing a clipping boundary is unsupported')
  p=parent(p,state)
 end
 assert(valid(overlay),'local Overlay traversal bound')
 local slate=assert(StaticFindObject('/Script/UMG.Default__SlateBlueprintLibrary'))
 local mathLib=assert(StaticFindObject('/Script/Engine.Default__KismetMathLibrary'))
 if nativeGeometry then
  local g=geometry(overlay);local source=geometry(w)
  return{overlay=overlay,geometry=g,rect=nativeGeometry.relative(source,g),width=g.width,height=g.height}
 end
 local g,s=allocatedGeometry(overlay,slate)
 assert(s.X>0 and s.Y>0,'unallocated Overlay')
 local sourceGeometry=allocatedGeometry(w,slate)
 local r=rect(sourceGeometry,slate,mathLib,g)
 return{overlay=overlay,geometry=g,slate=slate,mathLib=mathLib,rect=r,width=s.X,height=s.Y}
end
local function drawOpacity(w,overlay,state,depth)
 depth=(depth or 0)+1;assert(depth<=48,'Opacity ancestor bound')
 assert(widget(w),'Opacity route left UWidget ancestry')
 if full(w)==full(overlay)then return 1 end
 return memo(w,'draw:'..full(overlay),function()
  local layer=state.general_rich_layers and state.general_rich_layers[full(w)]
  return(layer and layer.originalOpacity or opacity(w))*drawOpacity(parent(w,state),overlay,state,depth)
 end)
end
local function classify(w,state,catalog,renderer)
 assert(runtimeWidget(w),'outside live UWidget instances')
 local name=full(w)
 assert(name:find('/Engine/Transient.',1,true)and not name:find('PBZFurigana_',1,true),'outside game source widgets')
 assert(not claimed(state,name),'source already owned by an existing adapter')
 assert(shown(w,state),'source hidden or inactive')
 local text=str(w:GetText())
 local styledLabel=catalog.styled_label and catalog.styled_label(w,text)
 local tutorial=catalog.native_tutorial and catalog.native_tutorial(w)
 local interactiveLabel=styledLabel or (catalog.interactive_label and catalog.interactive_label(w))
 assert(text~=''and(styledLabel or tutorial or not text:find('[<>]')),'plain text or reviewed styled label required')
 local key=str(w.LocText.Key);local namespace=str(w.LocText.Namespace)
 assert(namespace=='Default'or namespace=='','unknown localization namespace')
 local e=catalog.lookup(key,text,w);local binding='exact_key_text'
 if not e and catalog.lookup_text then e=catalog.lookup_text(text,w);binding='unambiguous_exact_text'end
 if not e and catalog.lookup_composed then e=catalog.lookup_composed(text);binding='composed_exact_lines'end
 assert(e,'no exact key/text reading')
 local plain=kind(w)=='PBZCommonLocText'
 assert(not EXCLUDED[e.context]or(tutorial and e.context=='tutorial_hint')
  or(plain and binding=='exact_key_text'and e.context~='untyped'and e.context~='unverified_item_variant'),'context handled by existing adapter')
 local ancestor=w
 for _=1,24 do
  if not valid(ancestor)then break end
  assert(plain or interactiveLabel or not kind(ancestor):find('Button',1,true),'interactive button foreground needs a dedicated route')
  ancestor=parent(ancestor,state)
 end
 local f=plain and w.Font or w.DefaultTextStyleOverride.Font;assert(valid(f.FontObject)and f.Size>0,'missing resolved font')
 local nativeColor=plain and w.ColorAndOpacity or w.DefaultTextStyleOverride.ColorAndOpacity
 local color=nativeColor.SpecifiedColor
 assert(color.A>.01,'text color is transparent')
 local useNativeColor=not plain and catalog.native_color and catalog.native_color(w)
 assert(not useNativeColor or nativeColor.ColorUseRule==0,'Rich foreground needs an explicit color')
 assert(f.FontObject:GetFullName():find('/Fonts/JP_',1,true),'unreviewed display font')
 local r=route(w,plain and not catalog.local_plain,(plain or tutorial) and catalog.allow_label_clip,catalog.accept_overlay,state)
 r.opacity=drawOpacity(w,r.overlay,state)
 local frame,topOverhang
 if catalog.placement_frame then frame,topOverhang=catalog.placement_frame(w) end
 if frame then
  assert(runtimeWidget(frame) and nativeGeometry and r.overlay:GetClipping()==0,'No visible button frame')
  r.frame=nativeGeometry.relative(geometry(frame),r.geometry)
  if topOverhang then
   r.frame.y=r.frame.y-topOverhang;r.frame.height=r.frame.height+topOverhang
  end
 end
 local lines,contentScale
 if plain then
  assert(not catalog.plain_host or catalog.plain_host(w,r.overlay),'Plain label left its native row')
  assert(not text:find('[\r\n]') and not w.AutoWrapText and
   (w.WrapTextAt==0 or catalog.accept_wrapped_plain and catalog.accept_wrapped_plain(w,f)),
   'Plain adapter requires one native line')
  contentScale=catalog.selected_label_scale and catalog.selected_label_scale(w,f)
  local reviewedOutline=catalog.accept_plain_outline and catalog.accept_plain_outline(w,f)
  assert((f.OutlineSettings.OutlineSize==0 or contentScale or reviewedOutline)
   and w.ShadowOffset.X==0 and w.ShadowOffset.Y==0,'Plain outline or shadow needs a separate route')
  assert(w.ColorAndOpacity.ColorUseRule==0 and (catalog.local_plain or color.R+color.G+color.B>.3),'Plain foreground needs a readable resolved color')
  local margin=w.Margin;assert(margin.Left==0 and margin.Top==0 and margin.Right==0 and margin.Bottom==0,'Plain source text margin is unsupported')
  assert(w.MinDesiredWidth==0,'Plain minimum desired width is unsupported')
  local d=w:GetDesiredSize();assert(d.X>0 and d.Y>0 and d.X<=r.rect.width+.5,'Plain source exceeds actual allocation')
  local x=w.Justification==1 and(r.rect.width-d.X)/2 or w.Justification==2 and r.rect.width-d.X or 0
  lines={{x=x,y=0,width=d.X,height=d.Y}}
 else lines=renderer.rects(w)end
 assert(#lines>0 and #lines<=20,'native line geometry absent')
 local twoStyledLines=styledLabel and #lines==2 and catalog.allow_two_styled_lines and catalog.allow_two_styled_lines(w)
 assert(not interactiveLabel or #lines==1 or twoStyledLines,'Interactive label must fit on one native line')
 assert(not e.visible_source or (tutorial and not plain and #lines==1),
  'Input-specific tutorial must fit on one native line')
 local reflowInPlace=#lines>1 and catalog.reflow_in_place and catalog.reflow_in_place(w)
 local preserveLines=catalog.preserve_lines and catalog.preserve_lines(w)
 local signature=key..'|'..text..'|'..full(f.FontObject)..'|'..f.Size..'|'..f.LetterSpacing..'|'..w.LineHeightPercentage..'|'..w.WrapTextAt
 if e.visible_source then signature=signature..'|input-specific'end
 signature=signature..string.format('|%.4f,%.4f,%.4f,%.4f|%.2f,%.2f|%s',color.R,color.G,color.B,color.A,r.rect.width,r.rect.height,full(r.overlay))
 for _,line in ipairs(lines)do signature=signature..string.format('|%.2f,%.2f,%.2f,%.2f',line.x,line.y,line.width,line.height)end
 if reflowInPlace then signature=signature..'|reflow_in_place'end
 if r.frame then
  signature=signature..string.format('|%.2f,%.2f,%.2f,%.2f',r.frame.x,r.frame.y,r.frame.width,r.frame.height)
 end
 local positioned=signature..string.format('|%.2f,%.2f',r.rect.x,r.rect.y)
 return{entry=e,text=text,plain=plain,identity=signature,signature=positioned,
  failureSignature=#lines>1 and not preserveLines and signature or positioned,
  route=r,lines=lines,binding=binding,contentScale=contentScale,styledLabel=styledLabel,tutorial=tutorial,
  richLayoutScale=not plain and catalog.rich_layout_scale and catalog.rich_layout_scale(w,f),
  preserveLines=preserveLines,reflowInPlace=reflowInPlace,
  compactReflow=reflowInPlace and catalog.compact_reflow and catalog.compact_reflow(w),
  rubyColor=useNativeColor and nativeColor or nil,
  rubyGap=catalog.ruby_gap and catalog.ruby_gap(w),
  plainOffset=plain and catalog.plain_offset and catalog.plain_offset(w),
  ratio=catalog.label_ratio and catalog.label_ratio(w) or (plain and catalog.plain_ratio and catalog.plain_ratio(w))}
end
local function intersects(a,b)
 return a.x<b.x+b.width-.5 and b.x<a.x+a.width-.5 and a.y<b.y+b.height-.5 and b.y<a.y+a.height-.5
end
local function validatePlacement(w,c,stats,neighbors,state,catalog,renderer)
 local r=c.route;local boxes={}
 local frame=r.frame or{x=0,y=0,width=r.width,height=r.height}
 for _,run in ipairs(stats.runs or{})do
  local b={x=r.rect.x+run.x-run.width/2,y=r.rect.y+run.y,width=run.width,height=run.height}
  assert(b.x>=frame.x-.5 and b.y>=frame.y-.5 and b.x+b.width<=frame.x+frame.width+.5
   and b.y+b.height<=frame.y+frame.height+.5,'reading leaves label bounds')
  boxes[#boxes+1]=b
 end
 assert(#boxes>0,'no reading boxes')
 local sourceChecks={}
 for _,other in ipairs(neighbors)do
  if runtimeWidget(other)and full(other)~=full(w)and not full(other):find('PBZFurigana_',1,true)and shown(other,state)
    and(not catalog.neighbor_is_current or catalog.neighbor_is_current(other,sourceChecks))then
   local ok,b=pcall(function()
    if nativeGeometry then return nativeGeometry.relative(geometry(other),r.geometry)end
    local g=allocatedGeometry(other,r.slate);return rect(g,r.slate,r.mathLib,r.geometry)
   end)
   local otherLayer=state and state.general_rich_layers and state.general_rich_layers[full(other)]
   if ok and otherLayer and otherLayer.stats.reflow then
    local lines=otherLayer.stats.lines;local last=lines[#lines];b.height=math.max(b.height,last.y+last.height)
   elseif ok and catalog.use_neighbor_line_bounds and catalog.use_neighbor_line_bounds(w,other) then
    -- Some native title rows allocate a trailing line-height pad. Use the
    -- actual visual line when both chapter-end labels share the same box.
    local lines=renderer.rects(other)
    local line=lines[1]
    if #lines==1 and line.x>=0 and line.y>=0 and line.width>0 and line.height>0
     and line.x+line.width<=b.width+.5 and line.y+line.height<=b.height+.5 then
     b={x=b.x+line.x,y=b.y+line.y,width=line.width,height=line.height}
    end
   end
   if ok then for _,a in ipairs(boxes)do assert(not intersects(a,b),'reading intersects visible text '..full(other))end end
  end
 end
end
local function padding(p)return{Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom}end
local function refresh(w)
 for _=1,48 do if not widget(w)then return end;w:ForceLayoutPrepass();w=parent(w)end
 error('Layout ancestor bound')
end
local function detachLayer(layer,renderer)
 if layer.plainRenderer then assert(layer.plainRenderer.detach(layer.handle))else renderer.detach(layer.handle)end
 if layer.originalPadding then
  local w=StaticFindObject(layer.sourcePath)
  if widget(w)then
   assert(full(w.Slot)==layer.slotName,'Owned source slot changed')
   local slot=w.Slot
   local fields={'Left','Top','Right','Bottom'}
   local ownsPadding=true
   if layer.appliedPadding then
    local current=slot.Padding
    for _,k in ipairs(fields)do
     if math.abs(current[k]-layer.appliedPadding[k])>=.05 then ownsPadding=false;break end
    end
   end
   if ownsPadding then
    slot:SetPadding(layer.originalPadding);refresh(w)
    local p=slot.Padding
    for _,k in ipairs(fields)do assert(math.abs(p[k]-layer.originalPadding[k])<.05,'Prose padding restore failed')end
   end
   if layer.originalOpacity and not layer.handle.conditionalOpacityRestore then
    assert(math.abs(w:GetRenderOpacity()-layer.originalOpacity)<.001,'Prose opacity restore failed')
   end
  end
 end
end
local function syncLayerOpacity(layer,alpha)
 if layer.stats.inheritedOpacity==alpha then return end
 local bounds=StaticFindObject(layer.handle.path)
 assert(widget(bounds),'Owned annotation layer disappeared')
 bounds:SetRenderOpacity(alpha);layer.stats.inheritedOpacity=alpha
end
local function neighbors(sources)
 assert(#sources<=2048,'Neighbor pool bound');return sources
end
function M.stop(state,log,root)
 if state.general_rich_gc_restore then collectgarbage('restart');state.general_rich_gc_restore=nil end
 state.general_rich_active=false;state.general_rich_tick=nil;state.general_rich_invalidate=nil
 state.general_rich_passive_visible=nil
 state.general_rich_tree_parent=nil
 state.general_rich_scan=nil
 local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
 local failed={};local errors={}
 for name,layer in pairs(state.general_rich_layers or{})do
  local ok,why=pcall(detachLayer,layer,renderer)
  if not ok then failed[name]=layer;errors[#errors+1]=tostring(why)end
 end
 state.general_rich_layers=failed;state.general_rich_wait={};state.general_rich_rejected={}
 state.general_rich_restore_errors=errors
 if log then log('general rich adapter stopped')end
 if #errors>0 and log then log('general_restore_pending '..table.concat(errors,'; '))end
 return #errors==0
end
function M.start(state,log,root,options)
 assert(M.stop(state,log,root),'Restore owned general layers before starting another trial')
 local catalog=options and options.catalog or assert(loadfile(root..'Scripts/realtime_catalog.lua'))()
 state.general_rich_passive_visible=catalog.passive_visible
 state.general_rich_tree_parent=catalog.tree_parent
 local renderer=assert(loadfile(root..'Scripts/subtitle_ruby.lua'))()
 local geometryModule=assert(loadfile(root..'Scripts/geometry_service.lua'))()
 local selectSources=options and options.selectSources
 if not selectSources then nativeGeometry=geometryModule.new(root) end
 local clock=geometryModule.clock and geometryModule.clock(root)or os.clock
 if options and options.pauseGC and collectgarbage('isrunning')then
  collectgarbage('collect')
  state.general_rich_gc_restore=true;state.general_rich_gc_heap=collectgarbage('count');collectgarbage('stop')
 end
 state.general_rich_metrics_samples={}
 state.general_rich_errors={}
 state.general_rich_active=true
 local function invalidateSources()
  frameCache={}
  local sourceChecks={}
  -- Clear already drawn text from recycled detail widgets even when the
  -- current slice is scanning a different group of widgets.
  for name,layer in pairs(state.general_rich_layers)do
   local source=layer.liveSource
   if source and (not valid(source) or str(source:GetText())~=layer.sourceText or not shown(source,state)
       or (layer.sourceIsCurrent and not layer.sourceIsCurrent(sourceChecks))) then
    local restored,why=pcall(detachLayer,layer,renderer)
    if restored then
     state.general_rich_layers[name]=nil
     state.general_rich_wait[name]=nil
    else
     layer.pendingRestore=true
     if state.general_rich_errors[name]~=why then
      state.general_rich_errors[name]=why;log('general_source_deferred '..name..' '..tostring(why))
     end
    end
   elseif source and layer.opacityHost and not layer.pendingRestore and not layer.handle.waitForPaint then
    syncLayerOpacity(layer,drawOpacity(source,layer.opacityHost,state))
   end
  end
 end
 state.general_rich_invalidate=function()
  if not next(state.general_rich_layers) then return end
  local ok,why=pcall(invalidateSources)
  frameCache=nil
  if not ok and state.general_rich_fast_error~=why then
   state.general_rich_fast_error=why;log('general_rich_invalidate_error '..tostring(why))
  end
 end
 local nextDue=0
 state.general_rich_tick=function()
  local wallStarted,cpuStarted=clock()
  if geometryModule.clock and wallStarted<nextDue then return end
  nextDue=wallStarted+.05
  frameCache={}
  if state.general_rich_gc_restore then assert(collectgarbage('count')-state.general_rich_gc_heap<65536,'Bounded GC diagnostic heap limit')end
  local heapStarted=collectgarbage('count')
  local started=os.clock();local scan=state.general_rich_scan
  if not scan then
   local pool
   if selectSources then
    pool=selectSources()
    if #pool>0 and not nativeGeometry then nativeGeometry=geometryModule.new(root) end
   else
    pool=FindAllOf('PBZCommonLocRichText')or{}
    for _,w in ipairs(FindAllOf('PBZCommonLocText')or{})do pool[#pool+1]=w end
   end
   assert(#pool<=2048,'Native text widget pool bound')
   scan={sources=pool,seen={},built=0,eligible=0,index=1};state.general_rich_scan=scan
  end
  local sources,seen=scan.sources,scan.seen
  local built,eligible=scan.built,scan.eligible
  local initialBuilt,processed,validations=built,0,0
  local sliceStarted=clock()
  while scan.index<=#sources do
   local w=sources[scan.index];scan.index=scan.index+1;processed=processed+1
   if runtimeWidget(w)and not full(w):find('PBZFurigana_',1,true)then
    local name=full(w);local classified
    local sourceOk,sourceError=pcall(function()
    local ok,c=pcall(classify,w,state,catalog,renderer);if ok then classified=c end
    local layer=state.general_rich_layers[name]
    if layer and(layer.pendingRestore or not ok or(layer.identity and layer.identity~=c.identity)or(not layer.identity and layer.signature~=c.signature))then detachLayer(layer,renderer);state.general_rich_layers[name]=nil;layer=nil end
    if ok then
     seen[name]=true;eligible=eligible+1
     if layer and layer.handle.waitForPaint then
      local bounds=StaticFindObject(layer.handle.path)
      local painted=widget(bounds) and nativeGeometry and pcall(geometry,bounds)
      if painted then
       layer.originalOpacity=layer.plainRenderer.activateOffset(layer.handle,c.route.opacity)
       layer.handle.waitForPaint=nil;layer.stats.inheritedOpacity=c.route.opacity
      else
       layer.paintChecks=(layer.paintChecks or 0)+1
       if layer.paintChecks>=3 then
        detachLayer(layer,renderer);state.general_rich_layers[name]=nil
        state.general_rich_rejected[name]=c.failureSignature;layer=nil
        log('general_rich_result key='..c.entry.key..' deferred no painted label geometry')
       end
      end
     end
     if layer and not layer.handle.waitForPaint then syncLayerOpacity(layer,c.route.opacity) end
     if layer and layer.originalPadding then
      local bounds=StaticFindObject(layer.handle.path)
      assert(widget(bounds),'Owned prose layer disappeared')
      local dx,dy=c.route.rect.x-layer.originX,c.route.rect.y-layer.originY
      if not layer.lastX or math.abs(dx-layer.lastX)>.01 or math.abs(dy-layer.lastY)>.01 then
       bounds:SetRenderTranslation({X=dx,Y=dy});layer.lastX=dx;layer.lastY=dy
      end
      layer.settle=layer.settle+1
      if layer.settle==3 then
       validations=validations+1
       local accepted,why=pcall(validatePlacement,w,c,layer.stats,neighbors(sources),state,catalog,renderer)
       if not accepted then
        detachLayer(layer,renderer);state.general_rich_layers[name]=nil;state.general_rich_rejected[name]=c.failureSignature;layer=nil
        log('general_prose_result key='..c.entry.key..' deferred '..tostring(why))
       else log('general_prose_result key='..c.entry.key..' settled runs='..#layer.stats.runs)end
      end
     end
     local pending=state.general_rich_wait[name]
     if not pending or pending.signature~=c.signature then pending={signature=c.signature,ticks=0};state.general_rich_wait[name]=pending end
     pending.ticks=pending.ticks+1
     if not layer and built<1 and pending.ticks>=2 and state.general_rich_rejected[name]~=c.failureSignature then
      local watch,sourceIsCurrent
      if catalog.watch_source_text then watch,sourceIsCurrent=catalog.watch_source_text(w) end
      if sourceIsCurrent and not sourceIsCurrent({}) then return end
      built=built+1
      local reserveProse=#c.lines>1 and not c.preserveLines
      local plainReserve
      if c.plain and catalog.plain_top_reserve then plainReserve=catalog.plain_top_reserve(w,c.entry.key)end
      local reserveSpace=reserveProse or plainReserve
      local multiline=reserveProse or c.reflowInPlace
      local originalPadding,reserve,slotName
      if reserveSpace then
       local slot=w.Slot;local k=kind(slot)
       assert(k=='SizeBoxSlot'or k=='OverlaySlot'or k=='VerticalBoxSlot'or k=='BorderSlot','Prose source slot lacks reviewed padding support')
       originalPadding=padding(slot.Padding);slotName=full(slot)
       reserve=plainReserve or math.ceil(w.DefaultTextStyleOverride.Font.Size*.95)
      else reserve=0 end
      local h,stats,plainRenderer
      if c.plain then
       plainRenderer=assert(loadfile(root..'Scripts/plain_line_ruby.lua'))()
       h,stats=plainRenderer.attach(w,c,state,log,root)
      else h,stats=renderer.attach(w,c.entry.segments,state,log,{sourceText=c.entry.visible_source or c.text,rects=c.lines,overlay=c.route.overlay,
       originX=c.route.rect.x,originY=c.route.rect.y+reserve,preserveNativeLines=not multiline,reflow=multiline,
       richText=c.styledLabel or c.tutorial,weaponMarkup=c.styledLabel or c.tutorial,
       measureNativeRich=c.styledLabel or c.tutorial,tutorialMarkup=c.tutorial,inlineEffects=c.tutorial,
       availableWidth=(c.styledLabel or c.tutorial) and c.route.rect.width or nil,
       ratio=c.ratio,gap=c.rubyGap,rubyColor=c.rubyColor,
       requireNativeBreaks=c.reflowInPlace,compactReflow=c.compactReflow,
       richLayoutScale=c.richLayoutScale,
       keepReadingWords=true,requireAllReadings=true,protectSource=true,boundedHorizontal=true,justification=w.Justification,
       conditionalOpacityRestore=selectSources~=nil})end
      local accepted,why=false,stats and stats.reason
      local pendingLayer
      if h then
       -- Own the handle before any post-attach setter or layout pass. If both
       -- installation and its rollback fail, stop/retry must still find it.
       pendingLayer={handle=h,signature=c.signature,key=c.entry.key,stats=stats,
        plainRenderer=plainRenderer,pendingRestore=true}
       if watch then
        pendingLayer.liveSource=w;pendingLayer.sourceText=c.text
        pendingLayer.sourceIsCurrent=sourceIsCurrent
        if catalog.follow_source_opacity and catalog.follow_source_opacity(w) then
         pendingLayer.opacityHost=c.route.overlay
        end
       end
       if reserveSpace then
        pendingLayer.identity=c.identity;pendingLayer.originalPadding=originalPadding
        pendingLayer.originalOpacity=h.originalOpacity;pendingLayer.slotName=slotName
        pendingLayer.sourcePath=path(w);pendingLayer.settle=0
        pendingLayer.originX=c.route.rect.x
        pendingLayer.originY=c.route.rect.y+(reserveProse and reserve or 0)
       end
       if c.reflowInPlace then pendingLayer.originalOpacity=h.originalOpacity end
       state.general_rich_layers[name]=pendingLayer
       accepted,why=pcall(function()
        stats.inheritedOpacity=c.route.opacity
        if c.route.opacity~=1 and not h.waitForPaint then
         local bounds=StaticFindObject(h.path);assert(widget(bounds),'Owned annotation layer is not UWidget');bounds:SetRenderOpacity(c.route.opacity)
        end
        if multiline then
         local last=stats.lines[#stats.lines]
         local bottom=c.route.frame and c.route.frame.y+c.route.frame.height or c.route.height
         assert(c.route.rect.y+reserve+last.y+last.height<=bottom+.5,'Expanded prose leaves its visible frame')
       end
       if reserveSpace then
         local last=stats.lines[#stats.lines]
         local appliedPadding={Left=originalPadding.Left,Top=originalPadding.Top+reserve,Right=originalPadding.Right,
          Bottom=originalPadding.Bottom+math.max(0,last.y+last.height-c.route.rect.height)}
         if selectSources then pendingLayer.appliedPadding=appliedPadding end
         w.Slot:SetPadding(appliedPadding)
         refresh(w)
        else validatePlacement(w,c,stats,neighbors(sources),state,catalog,renderer)end
       end)
       if not accepted then detachLayer(pendingLayer,renderer);state.general_rich_layers[name]=nil end
      end
      if h and accepted then
       pendingLayer.pendingRestore=nil
       log('general_rich_result key='..c.entry.key..' attached runs='..#stats.runs)
      else
       state.general_rich_rejected[name]=c.failureSignature
       log('general_rich_result key='..c.entry.key..' deferred '..tostring(why))
      end
     end
    else state.general_rich_wait[name]=nil end
    end)
    if not sourceOk then
     local layer=state.general_rich_layers[name]
     if layer then
      layer.pendingRestore=true
      local restored=pcall(detachLayer,layer,renderer)
      if restored then state.general_rich_layers[name]=nil end
     end
     if classified then state.general_rich_rejected[name]=classified.failureSignature end
     local reason=tostring(sourceError)
     if state.general_rich_errors[name]~=reason then state.general_rich_errors[name]=reason;log('general_source_deferred '..name..' '..reason)end
    end
   end
   if processed>=32 or clock()-sliceStarted>=.004 then break end
  end
  scan.built=built;scan.eligible=eligible
  local complete=scan.index>#sources
  if complete then
   for name,layer in pairs(state.general_rich_layers)do if not seen[name]then detachLayer(layer,renderer);state.general_rich_layers[name]=nil end end
   for name in pairs(state.general_rich_rejected)do if not seen[name]then state.general_rich_rejected[name]=nil end end
   for name in pairs(state.general_rich_wait)do if not seen[name]then state.general_rich_wait[name]=nil end end
   state.general_rich_scan=nil
  end
  local wallFinished,cpuFinished=clock()
  state.general_rich_metrics={scan_seconds=os.clock()-started,wall_seconds=wallFinished-wallStarted,
   thread_cpu_seconds=cpuFinished and(cpuFinished-cpuStarted)or 0,heap_kib=collectgarbage('count'),heap_delta_kib=collectgarbage('count')-heapStarted,
   gc_paused=state.general_rich_gc_restore==true,allocated=#sources,eligible=eligible,builds=built-initialBuilt,validations=validations,processed=processed,cycle_complete=complete}
  local samples=state.general_rich_metrics_samples
  if #samples>=256 then table.remove(samples,1)end;samples[#samples+1]=state.general_rich_metrics
  frameCache=nil
 end
 -- Earlier explicit trials left a 500 ms callback registered. Contain errors
 -- inside the current worker so that callback cannot run its older cleanup
 -- implementation against handles with newer padding ownership.
 local worker=state.general_rich_tick
 state.general_rich_tick=function()
  local ok,why=pcall(worker)
  if not ok then
   frameCache=nil
   local restored=M.stop(state,log,root)
   log('general_rich_contained_error restored='..tostring(restored)..' '..tostring(why))
  end
 end
 if not state.general_rich_sliced_timer then
  state.general_rich_sliced_timer=true
  LoopInGameThreadWithDelay(options and options.interval or 50,function()
   if state.general_rich_active and state.general_rich_tick then
    local ok,why=pcall(state.general_rich_tick)
    if not ok then
     frameCache=nil
     if state.general_rich_gc_restore then collectgarbage('restart');state.general_rich_gc_restore=nil end
     state.general_rich_active=false
     for _,layer in pairs(state.general_rich_layers or{})do detachLayer(layer,renderer)end
     state.general_rich_layers={}
     log('general_rich_stopped '..tostring(why))
    end
   end
  end)
 end
 if log then log('general rich adapter active; exact text bindings, reversible multiline space, bounded placement')end
end
M.classify=classify
return M
