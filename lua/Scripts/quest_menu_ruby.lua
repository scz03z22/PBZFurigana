local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Selected quest cards and the compact titles in unselected quest rows.
-- Evidence: quest_menu_layout_resting/later.txt, including GetSelected=true.
-- The native text, Retainers, slots and card are never written. A zero-size
-- sibling of the Retainers carries ruby. The one authorized layout adjustment
-- translates VerticalBox_81 down 6px, shared by both labels and fully restored.
local M={}
local PREFIX='PBZFurigana_QuestMenu_'
local BLOCK_SHIFT=6 -- Native JPG showed the paper texture's top is not a safe ink area.
local DEFINITIONS={["QuestName_Selected"]={["aliases"]={"Chapter_01","Chapter_En_01","QuestStory_01_1"},["fingerprint"]="15:2de0a245295ecc58",["gap"]=2,["index"]=1,["key"]="QuestStory_01_1",["parts"]={{6,"けいりゅう"},{3},{3,"さかのぼ"},{3}},["plain"]=true},["QuestTargetText"]={["aliases"]={"QuestStory_SubTitle_01_1"},["fingerprint"]="33:9d748cd98c574052",["gap"]=1,["index"]=2,["key"]="QuestStory_SubTitle_01_1",["parts"]={{3,"さか"},{6},{3,"もの"},{3},{6,"きと"},{3},{3,"と"},{6}},["plain"]=true}}
M.definitions=DEFINITIONS
local questFields={'QuestName_Selected','QuestTargetText','QuestText'}
local function valid(o)return o and o:IsValid()end
local function str(v)if type(v)=='string'then return v end;return v:ToString()end
local function class(o)return str(o:GetClass():GetFName())end
local function path(o)return o:GetFullName():match('^[^ ]+ (.+)$')end
local function name(o)return path(o):match('%.([^%.]+)$')end
local function near(a,b)return math.abs(a-b)<.05 end
local function size(v)return {X=v.X,Y=v.Y}end
local function pad(v)return {Left=v.Left,Top=v.Top,Right=v.Right,Bottom=v.Bottom}end
local function color(v)local c=v.SpecifiedColor;return {R=c.R,G=c.G,B=c.B,A=c.A,rule=v.ColorUseRule}end
local function zero(v)return v.Left==0 and v.Top==0 and v.Right==0 and v.Bottom==0 end
local function transform(w)
 local t=w.RenderTransform
 return {x=t.Translation.X,y=t.Translation.Y,sx=t.Scale.X,sy=t.Scale.Y,hx=t.Shear.X,hy=t.Shear.Y,angle=t.Angle}
end
local function identity(t)return t.x==0 and t.y==0 and t.sx==1 and t.sy==1 and t.hx==0 and t.hy==0 and t.angle==0 end
local function parent(w)
 local p=w:GetParent();if valid(p)then return p end
 local t=w:GetOuter()
 if valid(t)and class(t)=='WidgetTree'then local o=t:GetOuter();if valid(o)and path(o)~=path(w)then return o end end
end
local function shown(w)
 local seen={}
 for _=1,48 do
  if not valid(w)then return true end
  local p=path(w);if seen[p]then return false end;seen[p]=true
  local v=w:GetVisibility();if v==1 or v==2 or w:GetRenderOpacity()<.01 then return false end
  local up=parent(w)
  if valid(up)and class(up):find('Switcher',1,true)then
   local active=up:GetActiveWidget();if not valid(active)or path(active)~=p then return false end
  end
  w=up
 end
 return false
end
local function refresh(w)
 local seen={}
 for _=1,40 do
  if not valid(w)or seen[path(w)]then return end
  seen[path(w)]=true;w:ForceLayoutPrepass();w=parent(w)
 end
end
local function questEntry(w)
 if not valid(w)or class(w)~='PBZCommonLocText'then return false end
 local p=path(w)
 return p:find('/Engine/Transient',1,true)and not p:find('Default__',1,true)
  and p:find('.W_DIsplayQuest.',1,true)and p:find('.W_QuestListView_Entry_C_',1,true)
end
function M.matches(w)
 return questEntry(w) and DEFINITIONS[name(w)]~=nil
end
local function reviewedDefinition(field,text,key,state)
 local base=DEFINITIONS[field]
 local matched=compact.match(base,text)
 if matched then
  matched.text=text
  if key=='' then return matched end
  for _,alias in ipairs(base.aliases)do if key==alias then return matched end end
 end
 if not base or not state or not state.quest_menu_lookup then return nil end
 local context=base.index==1 and 'quest_title' or 'quest_subtitle'
 local entry=state.quest_menu_lookup(context,key,text)
 if not entry and context=='quest_title' and state.quest_chapter_lookup then
  entry=state.quest_chapter_lookup('chapter_title',key,text)
 end
 if entry then
  return {text=text,key=entry.key,segments=entry.segments,index=base.index,gap=base.gap}
 end
end
local function definition(w,state)
 assert(M.matches(w),'Outside the observed quest-menu source scope')
 assert(str(w.LocText.Namespace)=='Default','Unexpected quest namespace')
 return assert(reviewedDefinition(name(w),str(w:GetText()),str(w.LocText.Key),state),
  'Quest key/text pair has not been reviewed')
end
local function node(w)
 local s=w.Slot
 local a={path=path(w),class=class(w),parent=valid(w:GetParent())and path(w:GetParent())or '',
  desired=size(w:GetDesiredSize()),visibility=w:GetVisibility(),opacity=w:GetRenderOpacity(),
  clipping=w:GetClipping(),transform=transform(w),slot=valid(s)and path(s)or '',slotClass=valid(s)and class(s)or ''}
 if valid(s)and a.slotClass~='PanelSlot'and a.slotClass~='ButtonSlot'then
  a.padding=pad(s.Padding);a.horizontal=s.HorizontalAlignment;a.vertical=s.VerticalAlignment
  if a.slotClass=='VerticalBoxSlot'or a.slotClass=='HorizontalBoxSlot'then a.sizeRule=s.Size.SizeRule;a.sizeValue=s.Size.Value end
 end
 if a.class=='SizeBox'then
  a.overrides={}
  for _,field in ipairs({'WidthOverride','HeightOverride','MinDesiredWidth','MaxDesiredWidth','MinDesiredHeight','MaxDesiredHeight'})do
   a.overrides[field]=w[field];a.overrides['bOverride_'..field]=w['bOverride_'..field]
  end
 elseif a.class=='RetainerBox'then
  a.retainer={bRetainRender=w.bRetainRender,RenderOnInvalidation=w.RenderOnInvalidation,RenderOnPhase=w.RenderOnPhase,Phase=w.Phase,PhaseCount=w.PhaseCount}
 end
 return a
end
local function source(w)
 local a=node(w);local f=w.Font
 a.text=str(w:GetText());a.namespace=str(w.LocText.Namespace);a.key=str(w.LocText.Key)
 a.culture=str(w.DisplayCultureOverride);a.fontSize=f.Size;a.fontObject=valid(f.FontObject)and f.FontObject:GetFullName()or ''
 a.typeface=str(f.TypefaceFontName);a.letterSpacing=f.LetterSpacing;a.outline=f.OutlineSettings.OutlineSize
 a.color=color(w.ColorAndOpacity);a.shadow=size(w.ShadowOffset)
 a.shadowColor={R=w.ShadowColorAndOpacity.R,G=w.ShadowColorAndOpacity.G,B=w.ShadowColorAndOpacity.B,A=w.ShadowColorAndOpacity.A}
 a.justification=w.Justification;a.wrap=w.WrapTextAt;a.autoWrap=w.AutoWrapText;a.lineHeight=w.LineHeightPercentage
 return a
end
local function encode(t)
 local keys={};for k in pairs(t)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in ipairs(keys)do local v=type(t[k])=='table'and encode(t[k])or tostring(t[k]);out[#out+1]=tostring(k)..'='..#v..':'..v end
 return table.concat(out,';')
end
local function same(a,b,label)
 for k,v in pairs(a)do
  local q=b[k]
  if type(v)=='table'then assert(type(q)=='table',label..'.'..k);same(v,q,label..'.'..k)
  elseif type(v)=='number'then assert(type(q)=='number'and near(v,q),label..'.'..k..' changed')
  else assert(v==q,label..'.'..k..' changed')end
 end
 for k in pairs(b)do assert(a[k]~=nil,label..'.'..k..' added')end
end
local function copy(t)
 if type(t)~='table'then return t end
 local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out
end
local function applyTransform(w,t)
 w:SetRenderTransform({Translation={X=t.x,Y=t.y},Scale={X=t.sx,Y=t.sy},Shear={X=t.hx,Y=t.hy},Angle=t.angle})
end
local function auditNative(a,b,layout,label)
 local x,y=copy(a),copy(b)
 if layout then
  local function normalize(n)
   local t=n.nodes[5].transform
   assert(encode(t)==encode(layout.original)or encode(t)==encode(layout.applied),'Unexpected external quest transform')
   n.nodes[5].transform=copy(layout.original)
  end
  normalize(x);normalize(y)
 end
 same(x,y,label)
end
local function nativeSignature(a,state)
 local normalized=copy(a)
 local layout=state.quest_menu_layouts and state.quest_menu_layouts[a.nodes[5].path]
 if layout then normalized.nodes[5].transform=copy(layout.original)end
 local companion=a.source.path:match('%.QuestName_Selected$') and 2 or 1
 local retainer=a.branches[companion].retainer
 normalized.branches[companion]={height=retainer.desired.Y,padding=retainer.padding}
 return encode(normalized)
end
local function own(w)return path(w):find('.'..PREFIX,1,true)~=nil end
local function children(w)
 local out={};for i=0,w:GetChildrenCount()-1 do local c=w:GetChildAt(i);if not own(c)then out[#out+1]=c end end;return out
end
local function snapshot(w)
 local chain={w};for i=2,10 do chain[i]=assert(chain[i-1]:GetParent(),'Missing native quest ancestor')end
 local entry=w:GetOuter():GetOuter()
 assert(valid(entry)and class(entry)=='W_QuestListView_Entry_C','Unobserved quest entry owner')
 local a={source=source(w),nodes={},branches={},selected=entry:GetSelected(),owner=path(entry)}
 for i,c in ipairs(chain)do a.nodes[i]=node(c)end
 local branches=children(chain[5])
 for i,r in ipairs(branches)do
  local box=r:GetContent();local hb=box:GetContent();local kids=children(hb)
  local b={retainer=node(r),box=node(box),marquee=node(hb),children={}}
  for q,c in ipairs(kids)do b.children[q]=class(c)=='PBZCommonLocText'and source(c)or node(c)end
  a.branches[i]=b
 end
 a.icon=node(chain[6]:GetChildAt(0))
 return a,chain,entry
end
local function slot(a,kind,h,v,l,t,r,b,rule)
 assert(a.slotClass==kind and a.horizontal==h and a.vertical==v,'Unobserved quest slot/alignment: '..a.path)
 local p=a.padding
 assert(near(p.Left,l)and near(p.Top,t)and near(p.Right,r)and near(p.Bottom,b),'Unobserved quest padding: '..a.path)
 if rule~=nil then assert(a.sizeRule==rule,'Unobserved quest sizing rule')end
end
local function validate(w,state)
 local d=definition(w,state);assert(shown(w),'Quest source or selected card is hidden')
 local a,c=snapshot(w);assert(a.selected==true,'Quest card is not natively selected')
 local kinds={'PBZCommonLocText','HorizontalBox','SizeBox','RetainerBox','VerticalBox','HorizontalBox','Overlay','Overlay','SizeBox','Overlay'}
 local names={nil,nil,nil,nil,'VerticalBox_81','HorizontalBox_72','Overlay','SelectedLayerRoot','SizeBox','Overlay_82'}
 for i,n in ipairs(a.nodes)do
  assert(n.class==kinds[i]and(not names[i]or name(c[i])==names[i]),'Unobserved quest hierarchy')
  local owned=state and state.quest_menu_layouts and state.quest_menu_layouts[path(c[5])]
  assert(identity(n.transform)or(i==5 and owned and encode(n.transform)==encode(owned.applied)),
   'Transformed/moving quest label cannot be tracked safely')
  assert(i==4 and n.clipping==1 or i~=4 and n.clipping==0,'Unobserved quest clipping boundary')
  if i<=4 then assert(n.opacity==1,'Unsupported inner opacity')end
 end
 local s=a.source
 assert(s.desired.X>0 and s.desired.Y>0 and s.fontSize>0,'Quest text has not been laid out')
 assert(s.justification==0 and s.wrap==0 and not s.autoWrap and s.lineHeight==1,'Quest source must remain a native single line')
 assert(s.outline==0 and s.shadow.X==0 and s.shadow.Y==0 and s.letterSpacing==0,'Unobserved quest font effects')
 assert(#a.branches==2,'Expected exactly two native label Retainers')
 local height=0
 for i,b in ipairs(a.branches)do
  local field=i==1 and 'QuestName_Selected' or 'QuestTargetText'
  assert(b.retainer.class=='RetainerBox'and b.box.class=='SizeBox'and b.marquee.class=='HorizontalBox','Unobserved quest branch')
  assert(b.retainer.retainer.bRetainRender==false and b.retainer.clipping==1,'Inner Retainer must be the observed non-retaining clip')
  slot(b.retainer,'VerticalBoxSlot',i==1 and 0 or 1,1,0,i==1 and 0 or 10,0,0,0)
  local o=b.box.overrides
  assert(o.bOverride_MaxDesiredWidth and near(o.MaxDesiredWidth,350),'Unobserved marquee width cap')
  for _,f in ipairs({'WidthOverride','HeightOverride','MinDesiredWidth','MinDesiredHeight','MaxDesiredHeight'})do assert(not o['bOverride_'..f],'Unobserved marquee size override')end
  assert(#b.children==3 and b.children[1].path:match('%.([^%.]+)$')==field
   and b.children[1].namespace=='Default','Unknown quest label or marquee children')
  assert(b.children[1].visibility~=1 and b.children[1].visibility~=2,'Companion quest label is hidden')
  if i==d.index then
   assert(b.children[2].visibility==1 and b.children[3].visibility==1,'Active marquee copies cannot be tracked')
   assert(b.children[1].desired.X<=o.MaxDesiredWidth+.05,'Overflowing marquee is unsupported')
   for _,v in ipairs({b.retainer,b.box,b.marquee,b.children[1],b.children[2],b.children[3]})do
    assert(identity(v.transform),'Moving marquee is unsupported');assert(v.opacity==1,'Unobserved inner branch opacity')
   end
   assert(near(b.retainer.desired.Y,b.children[1].desired.Y)and near(b.marquee.desired.Y,b.children[1].desired.Y),'Marquee clips/scales native line height')
   assert(near(b.box.desired.X,b.children[1].desired.X)and near(b.marquee.desired.X,b.children[1].desired.X),'Marquee clips/scales native line width')
  end
  assert(b.box.clipping==0 and b.marquee.clipping==0 and b.children[1].clipping==0,'Unobserved companion clipping')
  slot(b.marquee,'SizeBoxSlot',0,0,0,0,0,0)
  slot(b.children[1],'HorizontalBoxSlot',0,0,0,0,0,0,0)
  height=height+b.retainer.desired.Y+b.retainer.padding.Top
 end
 slot(a.nodes[5],'HorizontalBoxSlot',0,2,16,0,0,0,1)
 slot(a.nodes[6],'OverlaySlot',1,2,147,0,0,0)
 slot(a.nodes[7],'OverlaySlot',0,0,0,0,0,0)
 slot(a.nodes[8],'SizeBoxSlot',0,0,0,0,0,0)
 slot(a.nodes[9],'OverlaySlot',0,0,345,0,0,0)
 local o=a.nodes[9].overrides
 assert(o.bOverride_WidthOverride and near(o.WidthOverride,700)and o.bOverride_HeightOverride and near(o.HeightOverride,110),'Quest card must retain the observed 700 x 110 overrides')
 for _,f in ipairs({'MinDesiredWidth','MaxDesiredWidth','MinDesiredHeight','MaxDesiredHeight'})do assert(not o['bOverride_'..f],'Unobserved card size constraint')end
 assert(near(a.nodes[9].desired.Y,110)and near(a.nodes[10].desired.Y,110),'Card desired height differs from fixed native height')
 assert(near(a.nodes[5].desired.Y,height)and near(a.nodes[6].desired.Y,height),'Native label block height cannot be proved')
 -- The annotation is a sibling inside the text column. Its left edge is
 -- constrained to that column's own padding, independent of icon width.
 assert(a.icon.transform.x==0,'Horizontally displaced quest icon is unsupported')
 local top=(110-height)/2
 assert(top+height+BLOCK_SHIFT<=110,'Translated native block would leave the existing card')
 local room=d.index==1 and top or a.branches[2].retainer.padding.Top
 assert(room>d.gap,'No vertical space above the native label')
 return {definition=d,before=a,chain=c,row=c[5],height=height,top=top,
  sourceY=d.index==1 and 0 or(a.branches[1].retainer.desired.Y+a.branches[2].retainer.padding.Top),availableHeight=room-d.gap}
end
local function acquireLayout(v,state,h)
 state.quest_menu_layouts=state.quest_menu_layouts or {}
 local p=path(v.row);local layout=state.quest_menu_layouts[p]
 if not layout then
  local original=transform(v.row);assert(identity(original),'Unowned quest block transform')
  local applied=copy(original);applied.y=applied.y+BLOCK_SHIFT
  layout={path=p,original=original,applied=applied,refs=0};state.quest_menu_layouts[p]=layout
 end
 layout.refs=layout.refs+1;h.layout=layout;h.layoutState=state;h.layoutAcquired=true
 applyTransform(v.row,layout.applied)
 same(layout.applied,transform(v.row),'Quest owned translation')
end
local function releaseLayout(h,log)
 if not h.layoutAcquired then return end
 h.layoutAcquired=false;local layout=h.layout;layout.refs=math.max(0,layout.refs-1)
 if layout.refs==0 then
  local row=StaticFindObject(layout.path)
  if valid(row)then
   local current=transform(row)
   if encode(current)==encode(layout.applied)or encode(current)==encode(layout.original)then
    applyTransform(row,layout.original);layout.restored=encode(transform(row))==encode(layout.original)
   else
    layout.restored=false;layout.externalTransformPreserved=copy(current)
    log('quest_menu_external_transform_preserved '..layout.path)
   end
  else layout.restored=nil end
  h.layoutState.quest_menu_layouts[layout.path]=nil
 end
 h.layoutRestored=layout.restored;h.layoutReferencesRemaining=layout.refs
end
local function make(kind,outer,id)
 local o=StaticConstructObject(StaticFindObject('/Script/UMG.'..kind),outer,FName(id));assert(valid(o),'Cannot construct quest '..kind);return o
end
function M.detach(h,log)
 if not h then return true end;log=log or function()end
 local w=StaticFindObject(h.sourcePath);local got,before=pcall(function()return snapshot(w)end)
 local ok,err=pcall(function()
  local bounds=h.path and StaticFindObject(h.path);if valid(bounds)then bounds:RemoveFromParent()end
  releaseLayout(h,log)
  local row=StaticFindObject(h.rowPath);if valid(row)then refresh(row)end
 end)
 if ok and valid(w)then
  local measured,after=pcall(snapshot,w)
  if measured then
   h.detachAfter=after
   h.restoreAuditAvailable=got
   h.detachUnchanged=got and pcall(auditNative,before,after,h.layout,'quest detach')or false
   h.restoredToAttachState=pcall(auditNative,h.before,after,h.layout,'quest attach restore')
  end
 end
 if not ok then log('quest_menu_detach_error '..tostring(err))end
 return ok,err
end
function M.attach(w,state,log,root)
 log=log or function()end;local h,stats
 local ok,err=pcall(function()
  local v=validate(w,state);local a=v.before.source;local d=v.definition
  state.serial=(state.serial or 0)+1;local prefix=PREFIX..state.serial..'_'
  h={kind='quest_menu',sourcePath=path(w),rowPath=path(v.row),before=v.before}
  acquireLayout(v,state,h)
  local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds');h.path=path(bounds)
  bounds:SetWidthOverride(0);bounds:SetHeightOverride(0);bounds:SetVisibility(3);bounds:SetRenderOpacity(a.opacity)
  local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Canvas');canvas:SetVisibility(3)
  local cs=bounds:AddChild(canvas);cs:SetHorizontalAlignment(0);cs:SetVerticalAlignment(0)
  local slot=v.row:AddChildToVerticalBox(bounds)
  slot:SetSize({Value=1,SizeRule=0});slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0});slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(1)
  local helper=assert(loadfile(root..'Scripts/item_title_ruby.lua'))()
  local runs,widgets,fitted=helper.build_segment_runs(w,d.segments,canvas,v.row,prefix,root,
   {font=w.Font,color=w.ColorAndOpacity,text=d.text,rects={{x=0,y=0,width=a.desired.X,height=a.desired.Y}},ratio=.6,shadowX=0,clipLeft=-16,clipRight=v.before.branches[d.index].box.overrides.MaxDesiredWidth})
  assert(fitted.remainingCollisions==0 and #fitted.skipped==0,'Quest ruby collision/missing reading')
  for _,run in ipairs(runs)do
   local ruby=widgets[run.segment].widget
   for _=1,5 do
    if run.height<=v.availableHeight+.001 then break end
    local ratio=math.floor((run.ratio*v.availableHeight/run.height-.002)*10000)/10000
    assert(ratio>=.45,'Insufficient space at minimum readable ruby ratio .45')
    run.ratio=ratio;run.fontSize=a.fontSize*ratio;ruby.Font.Size=run.fontSize;ruby:SetFont(ruby.Font)
    refresh(v.row);local measured=ruby:GetDesiredSize();run.width=measured.X;run.height=measured.Y
   end
   assert(run.height<=v.availableHeight+.001 and run.ratio>=.45 and run.ratio<=.6,'Quest ruby exceeds available vertical space')
   -- The 16px native left padding is empty; the preceding icon ends before it.
   assert(run.x-run.width/2>=-16 and 147+38+16+run.x+run.width/2<=700,'Quest ruby exceeds proven horizontal card allowance')
   run.y=-v.height+v.sourceY-d.gap-run.height;run.canvasX=run.x
   run.cardTop=v.top+BLOCK_SHIFT+v.sourceY-d.gap-run.height;run.cardBottom=run.cardTop+run.height
   assert(run.cardTop>=-.001 and run.cardBottom<=110,'Quest ruby leaves fixed card height')
   widgets[run.segment].slot:SetPosition({X=run.canvasX,Y=run.y})
  end
  refresh(v.row)
  assert(near(bounds:GetDesiredSize().X,0)and near(bounds:GetDesiredSize().Y,0),'Quest sibling changed desired size')
  local after=snapshot(w);auditNative(v.before,after,h.layout,'native quest audit')
  stats={key=d.key,sourceKey=a.key,keyPolicy='Blank native key is resolved only by exact reviewed text plus observed native path; aliases recorded, not inferred as native key.',
   sourceBefore=a,sourceAfter=after.source,sourceTextUnchanged=true,sourceFontUnchanged=true,sourceCultureUnchanged=true,
   sourceSlotUnchanged=true,nativeSubtreeStructureUnchanged=true,sourcePositionUnchanged=false,
   nativeOtherLayoutUnchanged=true,cardUnchanged=true,selected=true,marqueeActive=false,
   ownedLayoutAdjustment={path=h.rowPath,original=copy(h.layout.original),applied=copy(h.layout.applied),shiftY=BLOCK_SHIFT},
   nativeAuditBefore=v.before,nativeAuditAfter=after,runs=runs,skipped={},remainingCollisions=0,
   rubyCulturePolicy='Copied resolved source Font; original raw culture is untouched. UMG ruby has no PBZ culture property.',
   positionBasis='Observed fixed-height card and centered native block slots; geometry getters are not used. Native visual QA is still required.',
   cardHeight=110,blockHeight=v.height,sourceTopInCard=v.top+BLOCK_SHIFT+v.sourceY,availableRubyHeight=v.availableHeight,gap=d.gap}
  h.stats=stats
  log('quest_menu_attached key='..d.key..' runs='..#runs..' native_unchanged_except_owned_shift='..BLOCK_SHIFT)
  for _,r in ipairs(runs)do log('quest_menu_run '..r.text..'='..r.reading..' ratio='..r.ratio..' top='..r.cardTop..' height='..r.height)end
 end)
 if not ok then if h then M.detach(h,log)end;return nil,{reason=tostring(err),rollback=h and h.restoredToAttachState}end
 return h,stats
end
local function compactRoute(w, geometry, state)
 if not shown(w) or str(w.LocText.Namespace)~='Default' then return end
 local text,key=str(w:GetText()),str(w.LocText.Key)
 local entry=reviewedDefinition('QuestName_Selected',text,key,state)
 if not entry or text:find('[<>\r\n]') then return end
 local box=w:GetParent()
 local row=valid(box) and box:GetParent()
 local overlay=valid(row) and row:GetParent()
 if not valid(overlay) or class(overlay)~='Overlay' or name(overlay)~='Overlay_0'
  or class(row)~='HorizontalBox' or name(row)~='HorizontalBox_0'
  or class(box)~='SizeBox' or name(box)~='SizeBox_3' then return end
 local font=w.Font
 local d=w:GetDesiredSize()
 if d.X<=0 or d.Y<=0 or not valid(font.FontObject) or not path(font.FontObject):find('/Fonts/JP_',1,true)
  or w.Justification~=0 or w.AutoWrapText or w.WrapTextAt~=0
  or font.OutlineSettings.OutlineSize~=0 or w.ShadowOffset.X~=0 or w.ShadowOffset.Y~=0 then return end
 local ok,r=pcall(function()
  return geometry.relative(geometry.read(w),geometry.read(overlay))
 end)
 if not ok or r.x<0 or r.y<-.5 or r.width<d.X-.5 or r.height<d.Y-.5 then return end
 local tint=w.ColorAndOpacity.SpecifiedColor
 local signature=string.format('%s|%s|%.2f,%.2f,%.2f,%.2f|%.4f,%.4f,%.4f,%.4f|%.4f',
  text,path(overlay),r.x,r.y,d.X,d.Y,tint.R,tint.G,tint.B,tint.A,w:GetRenderOpacity())
 return {entry=entry,text=text,route={overlay=overlay,rect=r,opacity=w:GetRenderOpacity()},
  lines={{x=0,y=0,width=d.X,height=d.Y}},ratio=.48,signature=signature}
end

function M.stop(state,log)
 state.quest_menu_active=false;state.quest_menu_tick=nil
 for _,l in pairs(state.quest_menu_layers or {})do M.detach(l.handle,log)end
 for _,l in pairs(state.quest_compact_layers or {})do state.quest_compact_renderer.detach(l.handle)end
 state.quest_menu_layers={};state.quest_menu_wait={};state.quest_menu_rejected={}
 state.quest_compact_layers={}
end
function M.inspect(w,state)
 local v=validate(w,state)
 return {native=v.before,blockHeight=v.height,sourceTopInCard=v.top+v.sourceY,availableRubyHeight=v.availableHeight,key=v.definition.key}
end
function M.start(state,log,root)
 log=log or function()end;M.stop(state,log)
 local scripts=root..'Scripts/'
 local index=assert(loadfile(scripts..'surface_readings.lua'))()
 if not state.quest_menu_lookup then
  local package=assert(loadfile(scripts..'public19_readings.lua'))()
  state.quest_menu_lookup=index.index(package.entries)
 end
 if not state.quest_chapter_lookup then
  local chapter=assert(loadfile(scripts..'public22_readings.lua'))()
  state.quest_chapter_lookup=index.index(chapter.entries)
 end
 local compact=assert(loadfile(scripts..'plain_line_ruby.lua'))()
 local geometryModule=assert(loadfile(scripts..'geometry_service.lua'))()
 local geometry,rejected
 state.quest_compact_renderer=compact
 local compactLayers=state.quest_compact_layers
 rejected={}
 state.quest_menu_active=true;state.quest_menu_layers={};state.quest_menu_wait={}
 state.quest_menu_tick=function()
  local seen,compactSeen={},{}
  local builds=0
  local found={}
  for _,row in ipairs(FindAllOf('W_QuestListView_Entry_C') or {}) do
   local tree=valid(row) and row.WidgetTree
   local treePath=valid(tree) and path(tree)
   if treePath and treePath:find('.W_DIsplayQuest.',1,true) then
    for _,field in ipairs(questFields) do
     local w=StaticFindObject(treePath..'.'..field)
     if valid(w) then found[#found+1]=w end
    end
   end
  end
  for _,w in ipairs(found)do
   if M.matches(w)and not seen[path(w)]then
    local p=path(w);seen[p]=true
    local ok,v=pcall(validate,w,state);local active=ok and state.ruby_enabled~=false
    if not ok and state.quest_menu_rejected[p]~=tostring(v)then
     state.quest_menu_rejected[p]=tostring(v);log('quest_menu_rejected '..name(w)..' '..tostring(v))
    elseif ok then state.quest_menu_rejected[p]=nil end
    local signature=active and nativeSignature(v.before,state)or 'inactive'
    local layer=state.quest_menu_layers[p]
    local bounds=layer and StaticFindObject(layer.handle.path)
    if layer and (layer.signature~=signature or not valid(bounds)or not valid(bounds:GetParent())or path(bounds:GetParent())~=layer.handle.rowPath)then
     M.detach(layer.handle,log);state.quest_menu_layers[p]=nil;state.quest_menu_wait[p]=nil;layer=nil
    end
    if active and not layer then
     local pending=state.quest_menu_wait[p]
     if not pending or pending.signature~=signature then pending={signature=signature,ticks=0};state.quest_menu_wait[p]=pending end
     pending.ticks=pending.ticks+1
     if pending.ticks==2 then
      local h,result=M.attach(w,state,log,root)
      if h then state.quest_menu_layers[p]={signature=nativeSignature(snapshot(w),state),handle=h,stats=result}end
      log('quest_menu_result '..(h and result.key or result.reason))
     end
    elseif not active then state.quest_menu_wait[p]=nil end
   elseif questEntry(w) and name(w)=='QuestText' then
    local p=path(w)
    compactSeen[p]=true
    if shown(w) then geometry=geometry or geometryModule.new(root) end
    local c=geometry and compactRoute(w,geometry,state)
    local layer=compactLayers[p]
    if layer and (not c or layer.signature~=c.signature) then
     compact.detach(layer.handle);compactLayers[p]=nil;layer=nil
    end
    if not layer and c and builds<2 and rejected[p]~=c.signature then
     builds=builds+1
     local h,result=compact.attach(w,c,state,log,root)
     if h then
      compactLayers[p]={handle=h,signature=c.signature}
     else
      rejected[p]=c.signature
     end
     log('quest_menu_result compact '..c.entry.key..' '..(h and 'attached' or result.reason))
    end
   end
  end
  for p,l in pairs(state.quest_menu_layers)do if not seen[p]then M.detach(l.handle,log);state.quest_menu_layers[p]=nil;state.quest_menu_wait[p]=nil end end
  for p in pairs(state.quest_menu_wait)do if not seen[p]then state.quest_menu_wait[p]=nil end end
  for p in pairs(state.quest_menu_rejected)do if not seen[p]then state.quest_menu_rejected[p]=nil end end
  for p,l in pairs(compactLayers)do if not compactSeen[p]then compact.detach(l.handle);compactLayers[p]=nil end end
  for p in pairs(rejected)do if not compactSeen[p]then rejected[p]=nil end end
 end
 if not state.quest_menu_timer then
  state.quest_menu_timer=true
  LoopInGameThreadWithDelay(250,function()
   if state.quest_menu_active and state.quest_menu_tick then
    local ok,err=pcall(state.quest_menu_tick)
    if not ok then
     M.stop(state,log)
     log('quest_menu_watcher_stopped '..tostring(err))
    end
   end
  end)
 end
 log('quest_menu watcher active')
end
return M
