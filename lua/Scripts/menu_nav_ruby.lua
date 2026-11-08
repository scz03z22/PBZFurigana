local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Three reviewed Japanese navigation labels. Zero-size centered siblings share
-- the native text's Overlay and ScaleBox; no native text/style/layout setters.
local M={}
local ALLOWED={["UI_Character_13"]="7:99d5864ba6c13c09",["UI_Character_48"]="9:a61edd192afa6416",["UI_Inventory_07"]="9:cea83626a3453c54"}

local PREFIX='PBZFurigana_MenuNav_'
local function valid(o)return o and o:IsValid()end
local function cls(o)return o:GetClass():GetFName():ToString()end
local function path(o)return o:GetFullName():match('^[^ ]+ (.+)$')end
local function obj(o)return valid(o)and o:GetFullName()or ''end
local function str(v)return type(v)=='string'and v or v:ToString()end
local function near(a,b)return math.abs(a-b)<.05 end
local function xy(v)return {x=v.X,y=v.Y}end
local function pad(v)return {left=v.Left,top=v.Top,right=v.Right,bottom=v.Bottom}end
local function zero(p)return p.left==0 and p.top==0 and p.right==0 and p.bottom==0 end
local function rgba(v)local c=v.SpecifiedColor;return {c.R,c.G,c.B,c.A,v.ColorUseRule}end
local function transform(w)local t=w.RenderTransform;return {t.Translation.X,t.Translation.Y,t.Scale.X,t.Scale.Y,t.Shear.X,t.Shear.Y,t.Angle}end
local function identity(t)return t[1]==0 and t[2]==0 and t[3]==1 and t[4]==1 and t[5]==0 and t[6]==0 and t[7]==0 end
local function same(a,b,label)
 for k,v in pairs(a)do local q=b[k]
  if type(v)=='table'then assert(type(q)=='table',label..'.'..k);same(v,q,label..'.'..k)
  elseif type(v)=='number'then assert(type(q)=='number'and near(v,q),label..'.'..k)
  else assert(v==q,label..'.'..k)end
 end
 for k in pairs(b)do assert(a[k]~=nil,label..'.extra.'..k)end
end
local function signature(t)
 local keys={};for k in pairs(t)do keys[#keys+1]=k end;table.sort(keys)
 local out={};for _,k in ipairs(keys)do local v=t[k];local s=type(v)=='table'and signature(v)or tostring(v);out[#out+1]=tostring(k)..':'..#s..':'..s end
 return table.concat(out,';')
end
local function parent(w)
 local p=w:GetParent();if valid(p)then return p end
 local t=w:GetOuter();if valid(t)and cls(t)=='WidgetTree'then return t:GetOuter()end
end
local function visible(w)
 local p=w
 for _=1,40 do
  if not valid(p)then return true end
  if p:GetVisibility()==1 or p:GetVisibility()==2 or p:GetRenderOpacity()<.01 then return false end
  local next=parent(p)
  if valid(next)and (cls(next)=='WidgetSwitcher'or cls(next)=='PBZCommonVisibilitySwitcher'or cls(next)=='CommonVisibilitySwitcher')then
   local active=next:GetActiveWidget();if not valid(active)or path(active)~=path(p)then return false end
  end
  p=next
 end
 return false
end
local function scoped(w)
 if not valid(w)or cls(w)~='PBZCommonLocText'then return false end
 local n=obj(w)
 return n:find('/Engine/Transient',1,true)and n:find('.TabList.',1,true)and n:find('.W_System_NavButton_C_',1,true)
  and not n:find('Default__',1,true)and n:match('%.Text$')~=nil
end
local function node(w)return {path=path(w),size=xy(w:GetDesiredSize()),opacity=w:GetRenderOpacity(),visibility=w:GetVisibility(),clipping=w:GetClipping(),transform=transform(w)}end
local function audit(w)
 local r=node(w);local f=w.Font
 r.text=str(w:GetText());r.key=str(w.LocText.Key);r.namespace=str(w.LocText.Namespace);r.culture=str(w.DisplayCultureOverride)
 r.font={object=obj(f.FontObject),size=f.Size,typeface=str(f.TypefaceFontName),spacing=f.LetterSpacing,outline=f.OutlineSettings.OutlineSize}
 r.color=rgba(w.ColorAndOpacity);r.shadow=xy(w.ShadowOffset);r.shadowColor={w.ShadowColorAndOpacity.R,w.ShadowColorAndOpacity.G,w.ShadowColorAndOpacity.B,w.ShadowColorAndOpacity.A}
 r.justification=w.Justification;r.autoWrap=w.AutoWrapText;r.wrap=w.WrapTextAt;r.slot=obj(w.Slot)
 r.padding=pad(w.Slot.Padding);r.horizontal=w.Slot.HorizontalAlignment;r.vertical=w.Slot.VerticalAlignment
 return r
end
local function snapshot(w)
 local overlay=w:GetParent();local scale=valid(overlay)and overlay:GetParent()
 assert(valid(overlay)and cls(overlay)=='Overlay'and path(overlay):match('%.Overlay_0$'),'Unexpected navigation overlay')
 assert(valid(scale)and cls(scale)=='ScaleBox'and path(scale):match('%.TabContentScaleBox$'),'Unexpected navigation scale parent')
 local source=audit(w);local children={}
 for i=0,overlay:GetChildrenCount()-1 do local c=overlay:GetChildAt(i)
  if not obj(c):find('.'..PREFIX,1,true)then children[#children+1]=node(c)end
 end
 local s=node(scale);s.stretch=scale.Stretch;s.direction=scale.StretchDirection;s.userScale=scale.UserSpecifiedScale;s.ignoreInherited=scale.IgnoreInheritedScale
 return {source=source,overlay=node(overlay),scale=s,children=children}
end
local function refresh(w)for _=1,18 do if not valid(w)then return end;w:ForceLayoutPrepass();w=parent(w)end end
local function make(kind,outer,name)local o=StaticConstructObject(StaticFindObject('/Script/UMG.'..kind),outer,FName(name));assert(valid(o),'Cannot construct navigation ruby');return o end
function M.detach(handle,log)
 if not handle then return true end
 local w=StaticFindObject(handle.sourcePath);local beforeOk,before=pcall(snapshot,w)
 local errors={}
 local function attempt(label,fn)local ok,why=pcall(fn);if not ok then errors[#errors+1]=label..': '..tostring(why)end end
 local o=StaticFindObject(handle.path);if valid(o)then attempt('remove',function()o:RemoveFromParent()end)end
 local overlay=StaticFindObject(handle.overlayPath);if valid(overlay)then attempt('refresh',function()refresh(overlay)end)end
 local ok,after=pcall(snapshot,w)
 handle.detachSourceAvailable=ok;handle.restoredUnchanged=false
 if beforeOk and ok then handle.restoredUnchanged=pcall(same,before,after,'navigation detach')end
 handle.detachAfter=ok and after or nil
 handle.detachErrors=errors
 if log then log('menu_nav_detach source_available='..tostring(ok)..' native_unchanged='..tostring(handle.restoredUnchanged))end
 local checked,removed=pcall(function()return not valid(o)or not valid(o:GetParent())end)
 return checked and removed,errors
end
local function release(state,handle,log)
 state.menu_nav_cleanup=state.menu_nav_cleanup or{}
 local ok,removed=pcall(M.detach,handle,log)
 if ok and removed then state.menu_nav_cleanup[handle.path]=nil;return true end
 state.menu_nav_cleanup[handle.path]=handle
 return false
end
function M.attach(w,entry,state,log,root)
 local handle,stats
 local ok,why=pcall(function()
  assert(scoped(w)and visible(w),'Navigation source is outside active scope')
  local before=snapshot(w);local a=before.source
  assert(ALLOWED[a.key]==compact.fingerprint(a.text) and a.namespace=='Default'and entry.key==a.key and entry.original==a.text,'Unreviewed navigation text')
  assert(a.horizontal==2 and a.vertical==2 and zero(a.padding),'Navigation text must be centered without padding')
  assert(a.wrap==0 and not a.autoWrap and a.font.outline==0 and a.shadow.x==0 and a.shadow.y==0,'Unsupported navigation wrapping/shadow')
  assert(a.size.x>0 and a.size.y>0 and a.font.size>0,'Navigation source is not laid out')
  for _,n in ipairs({a,before.overlay,before.scale})do assert(identity(n.transform)and n.clipping==0,'Unsupported navigation transform/clipping')end
  assert(#before.children==2 and before.children[1].path==path(w)and before.children[2].path:match('%.RedImage$')and before.children[2].visibility==1,'Navigation badge/layout needs separate inspection')
  assert(near(before.overlay.size.x,a.size.x)and near(before.overlay.size.y,a.size.y),'Unexpected navigation content extent')
  local overlay=w:GetParent();state.serial=(state.serial or 0)+1;local prefix=PREFIX..state.serial..'_'
  local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds')
  handle={sourcePath=path(w),overlayPath=path(overlay),path=path(bounds),before=before}
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(a.opacity)
  local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Canvas');canvas:SetVisibility(3);bounds:AddChild(canvas)
  local slot=overlay:AddChildToOverlay(bounds);slot:SetHorizontalAlignment(2);slot:SetVerticalAlignment(2);slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
  local helper=assert(loadfile(root..'Scripts/item_title_ruby.lua'))()
  -- Ruby sits above the selected button's white brush, on the dark header.
  -- Keep its own color light; the original selected black text is untouched.
  local rubyColor={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0}
  local runs,widgets,fitted=helper.build_segment_runs(w,entry.segments,canvas,overlay,prefix,root,{font=w.Font,color=rubyColor,text=a.text,rects={{x=0,y=0,width=a.size.x,height=a.size.y}},ratio=.6,shadowX=0})
  assert(#runs==2 and #fitted.skipped==0 and fitted.remainingCollisions==0,'Incomplete navigation annotation')
  -- Keep edge readings within the native label, while retaining the shared
  -- fitter's per-word movement limits and the two-pixel inter-reading gap.
  local lower,upper,latest={},{},{}
  for i,run in ipairs(runs)do
   lower[i]=math.max(run.width/2,run.minimumX or run.x)
   upper[i]=math.min(a.size.x-run.width/2,run.maximumX or run.x)
  end
  for i=#runs,1,-1 do
   latest[i]=upper[i]
   if i<#runs then latest[i]=math.min(latest[i],latest[i+1]-(runs[i].width+runs[i+1].width)/2-2)end
   assert(latest[i]>=lower[i]-.001,'Navigation readings cannot fit within native label')
  end
  for i,run in ipairs(runs)do
   local minimum=lower[i]
   if i>1 then minimum=math.max(minimum,runs[i-1].x+(runs[i-1].width+run.width)/2+2)end
   local original=run.x;run.x=math.min(math.max(run.x,minimum),latest[i]);run.navigationBoundaryShift=run.x-original
   assert(run.width>0 and run.height<a.size.y and run.x-run.width/2>=-.05 and run.x+run.width/2<=a.size.x+.05,'Navigation ruby exceeds text bounds')
   run.canvasX=run.x-a.size.x/2;run.y=-a.size.y/2-run.height-1
   widgets[run.segment].slot:SetPosition({X=run.canvasX,Y=run.y})
  end
  refresh(overlay);assert(near(bounds:GetDesiredSize().X,0)and near(bounds:GetDesiredSize().Y,0),'Navigation ruby changes layout size')
  local after=snapshot(w);same(before,after,'navigation native source')
  stats={key=a.key,text=a.text,runs=runs,skipped={},sourceUnchanged=true,sourceBefore=before,sourceAfter=after,remainingCollisions=0,placement='centered_zero_size_sibling_same_native_scalebox',rubyColor=rgba(rubyColor),colorPolicy='light_ruby_above_original_selected_brush'}
  handle.stats=stats
 end)
 if not ok then local rolledBack=not handle or release(state,handle,log);return nil,{reason=tostring(why),rollback=rolledBack}end
 return handle,stats
end
function M.stop(state,log)
 state.menu_nav_active=false;state.menu_nav_tick=nil;state.menu_nav_last_removed={}
 local handles={};for id,h in pairs(state.menu_nav_cleanup or{})do handles[id]=h end
 for _,v in pairs(state.menu_nav_layers or{})do handles[v.handle.path]=v.handle end
 local clean=true
 for _,h in pairs(handles)do if not release(state,h,log)then clean=false end;state.menu_nav_last_removed[#state.menu_nav_last_removed+1]=h end
 state.menu_nav_layers={};state.menu_nav_pending={};state.menu_nav_sources={}
 return clean
end
function M.start(state,log,root)
 if not M.stop(state,log)then log('menu_nav_start deferred until prior layer cleanup succeeds');return false end
 local package=assert(loadfile(root..'Scripts/public14_readings.lua'))();local entries={}
 for _,e in pairs(package.entries)do if ALLOWED[e.key]then assert(e.fingerprint==ALLOWED[e.key]);entries[e.key]=e end end
 for key in pairs(ALLOWED)do assert(entries[key],'Missing reviewed navigation source '..key)end
 state.menu_nav_active=true;local tick=0
 state.menu_nav_tick=function()
  tick=tick+1
  for _,h in pairs(state.menu_nav_cleanup or{})do if not release(state,h,log)then return end end
  if tick==1 or tick%8==0 then
   local found={}
   for _,button in ipairs(FindAllOf('W_System_NavButton_C') or {}) do
    local tree=valid(button) and button.WidgetTree
    local treePath=valid(tree) and path(tree)
    if treePath and treePath:find('.TabList.',1,true) then
     local w=StaticFindObject(treePath..'.Text')
     if scoped(w) then found[path(w)]=w end
    end
   end
   state.menu_nav_sources=found
  end
  local seen={}
  for id,w in pairs(state.menu_nav_sources)do
   local ok,why=pcall(function()
    local record=valid(w)and entries[str(w.LocText.Key)]
    local entry=record and visible(w) and compact.match(record,str(w:GetText()))
    local shown=state.ruby_enabled~=false and entry
    local current=shown and signature(snapshot(w))or 'hidden';seen[id]=true
    local layer=state.menu_nav_layers[id]
    if layer and (layer.signature~=current or not valid(StaticFindObject(layer.handle.path)))then
     local clean=release(state,layer.handle,log);state.menu_nav_layers[id]=nil;state.menu_nav_pending[id]=nil;layer=nil;if not clean then return end
    end
    if not shown then state.menu_nav_pending[id]=nil;return end
    if not layer then
     local pending=state.menu_nav_pending[id]
     if not pending or pending.signature~=current then pending={signature=current,ticks=0};state.menu_nav_pending[id]=pending end
     pending.ticks=pending.ticks+1
     if pending.ticks==2 then local h,s=M.attach(w,entry,state,log,root);if h then state.menu_nav_layers[id]={signature=current,handle=h,stats=s}end;log('menu_nav_result '..entry.key..' '..(h and 'attached'or s.reason))end
    end
   end)
   if not ok then local layer=state.menu_nav_layers[id];if layer then release(state,layer.handle,log);state.menu_nav_layers[id]=nil end;if state.menu_nav_error~=tostring(why)then state.menu_nav_error=tostring(why);log('menu_nav_error '..tostring(why))end end
  end
  for id,v in pairs(state.menu_nav_layers)do if not seen[id]then release(state,v.handle,log);state.menu_nav_layers[id]=nil;state.menu_nav_pending[id]=nil end end
 end
 if not state.menu_nav_timer then state.menu_nav_timer=true;LoopInGameThreadWithDelay(250,function()
  if not state.menu_nav_active or not state.menu_nav_tick then return end
  local ok,why=pcall(state.menu_nav_tick);if not ok and state.menu_nav_error~=tostring(why)then state.menu_nav_error=tostring(why);log('menu_nav_error '..tostring(why))end
 end)end
end
M.snapshot=snapshot
return M
