-- Native subtitle annotation layer. Original localized FText and font are intact.
-- Optional reflow temporarily hides the source while equivalent line copies show.
-- GetVisualLineRects is x,y,width,height (verified against a live multiline widget).
-- Layout is inferred only when Slate's measured substring widths match every line.
local M={}
local function valid(o) return o and o:IsValid() end
local function object_path(o) return o:GetFullName():match('^[^ ]+ (.+)$') end
local function make(class,outer,name)
 local o=StaticConstructObject(StaticFindObject('/Script/UMG.'..class),outer,FName(name))
 assert(valid(o),'Could not construct '..class)
 return o
end
local function characters(text)
 local a={};local p=1
 for c in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
  a[#a+1]={text=c,first=p,last=p+#c-1};p=p+#c
 end
 assert(p==#text+1,'Invalid UTF-8 in subtitle')
 return a
end
function M.rects(w)
 local result={}
 local function append(v)
  local ok,a=pcall(function() return v:get() end)
  if not ok then a=v end
  result[#result+1]={x=a.X,y=a.Y,width=a.Z,height=a.W}
 end
 local values=w:GetVisualLineRects()
 if type(values)=='table' then
  for i=1,math.min(#values,21) do append(values[i]) end
 elseif values then
  values:ForEach(function(_,value)if #result<21 then append(value)end end)
 end
 return result
end

-- The observed prose uses non-nested Bold and LetterBold spans. Keep the exact
-- source tag and byte ranges so copies retain each native style and its color.
local INLINE_OBJECT=utf8.char(0xFFFC)
local WEAPON_STYLES={
 ['<MainCN>']=true,
 ['<DemoGreen>']=true,
 ['<Character_Yellow_Decorator2>']=true,
 ['<Character_Purple_Decorator2>']=true,
 ['<WeaponDes_Num_Green>']=true,
 ['<WeaponDes_Main_Green>']=true,
 ['<Ability_Yellow_Decorator2>']=true,
 ['<Ability_Yellow>']=true,
 ['<CharacterButton_White>']=true,
 ['<CharacterButton_Yellow>']=true,
 ['<Num_ItemText>']=true,
}
local WEAPON_ATOMS={
 '^<InputAction id="[%w_]+" height="%d+" RightPadding="%d+" LeftPadding="%d+"/>$',
 '^<dtv id="X%d%d%d"/>$',
 '^<img id="Fire" width="40"/>$',
 '^<img id="Ice" width="40"/>$',
 '^<img id="Thunder" width="40"/>$',
 '^<img id="SpiritShadow" width="40"/>$',
}
local TUTORIAL_STYLES={
 ['<Tutorial_Title_Red>']=true, ['<Tutorial_Title_Blue>']=true,
 ['<Tutorial_Title_Yellow>']=true, ['<Tutorial_Title_Green>']=true,
 ['<Tutorial_Body_Red>']=true, ['<Tutorial_Body_Blue>']=true,
 ['<Tutorial_Body_Yellow>']=true, ['<Tutorial_Body_Green>']=true,
 ['<pad name="Generic">']=true,
}
local TUTORIAL_ATOMS={
 '^<InputAction id="[%w_]+" height="%d+"/>$',
 '^<InputAction id="Move" dir="Forward" height="%d+"/>$',
 '^<UIRowName id="[%w_]+" height="%d+"/>$',
 '^<UIRowName id="[%w_]+" height="%d+" LeftPadding="%d+" RightPadding="%d+"/>$',
}
local function weaponAtom(markup, inlineEffects)
 if inlineEffects and markup=='<Niagara id="Fire"/>' then return true end
 for _,pattern in ipairs(WEAPON_ATOMS) do if markup:match(pattern) then return true end end
 return false
end
local function tutorialAtom(markup)
 for _,pattern in ipairs(TUTORIAL_ATOMS) do if markup:match(pattern) then return true end end
 return false
end
function M.parse_rich_text(text,segments,weaponMarkup,inlineEffects,tutorialMarkup)
 local rawParts={};for _,s in ipairs(segments) do rawParts[#rawParts+1]=s.text end
 if table.concat(rawParts)~=text then return nil,'rich-text segments differ from source' end
 local spans={};local visible={};local rawPos=1;local visiblePos=1;local tag
 while rawPos<=#text do
  local first=text:find('<',rawPos,true)
  local finish=first and first-1 or #text
  if finish>=rawPos then
   local part=text:sub(rawPos,finish)
   spans[#spans+1]={rawFirst=rawPos,rawLast=finish,firstByte=visiblePos,lastByte=visiblePos+#part-1,text=part,tag=tag}
   visible[#visible+1]=part;visiblePos=visiblePos+#part
  end
  if not first then break end
  local last=text:find('>',first,true)
  if not last then return nil,'unclosed subtitle markup' end
  local markup=text:sub(first,last)
  local weaponStyle=weaponMarkup and WEAPON_STYLES[markup]
  local tutorialStyle=tutorialMarkup and TUTORIAL_STYLES[markup]
  if (markup=='<Bold>' or markup=='<LetterBold>' or weaponStyle or tutorialStyle) and not tag then tag=markup:sub(2,-2)
  elseif markup=='</>' and tag then tag=nil
  elseif not tag and ((weaponMarkup and weaponAtom(markup,inlineEffects)) or (tutorialMarkup and tutorialAtom(markup))) then
   spans[#spans+1]={rawFirst=first,rawLast=last,firstByte=visiblePos,lastByte=visiblePos+#INLINE_OBJECT-1,atom=markup}
   visible[#visible+1]=INLINE_OBJECT;visiblePos=visiblePos+#INLINE_OBJECT
  else return nil,'unsupported or nested subtitle markup: '..markup end
  rawPos=last+1
 end
 if tag then return nil,'unclosed subtitle style span: '..tag end
 local plainSegments={};local cursor=1
 for _,segment in ipairs(segments) do
  local finish=cursor+#segment.text-1;local parts={};local copy={}
  for key,value in pairs(segment) do copy[key]=value end
  for _,span in ipairs(spans) do
   local first=math.max(cursor,span.rawFirst);local last=math.min(finish,span.rawLast)
   if first<=last then
    if span.atom then
     if segment.reading or first~=span.rawFirst or last~=span.rawLast then return nil,'Split or annotated inline object' end
     parts[#parts+1]=INLINE_OBJECT
    else parts[#parts+1]=text:sub(first,last) end
   end
  end
  copy.text=table.concat(parts);plainSegments[#plainSegments+1]=copy;cursor=finish+1
 end
 return {original=text,visible=table.concat(visible),segments=plainSegments,spans=spans}
end

function M.rich_slice(parsed,first,last,tagMapping)
 local parts={};tagMapping=tagMapping or {}
 for _,span in ipairs(parsed.spans) do
  local begin=math.max(first,span.firstByte);local finish=math.min(last,span.lastByte)
  if begin<=finish then
   local piece=parsed.visible:sub(begin,finish)
   if span.atom then
    assert(begin==span.firstByte and finish==span.lastByte,'Inline object cannot be sliced')
    piece=span.atom
   end
   if span.tag then piece='<'..(tagMapping[span.tag] or span.tag)..'>'..piece..'</>' end
   parts[#parts+1]=piece
  end
 end
 return table.concat(parts)
end

-- Pure helper. rects use widget-local pixels; width(s) must measure the actual font.
-- Returns nil and a reason instead of guessing a line boundary.
function M.partition(text,rects,width,tolerance,model)
 tolerance=tolerance or 0.8
 model=model or {}
 if text:find('[<>]') then return nil,'rich-text markup requires run-aware measurement' end
 local chars=characters(text)
 if #chars>2048 or #rects>20 then return nil,'diagnostic layout limit exceeded' end
 if #rects==0 then return nil,'no native visual lines yet' end
 local cache={}
 local function measured(first,last)
  if last<first then return 0 end
  local key=first..':'..last
  if cache[key]==nil then
   local atStart=first==1 or chars[first-1].text=='\n' or chars[first-1].text=='\r'
   local atEnd=last==#chars or chars[last+1].text=='\n' or chars[last+1].text=='\r'
   local extra=(atStart and (model.outline or 0) or 0)+(atEnd and (model.outline or 0) or 0)
   local shadow=model.shadowX or 0
   if (shadow<0 and atStart) or (shadow>0 and atEnd) then extra=extra+math.abs(shadow) end
   local firstByte,lastByte=chars[first].first,chars[last].last
   cache[key]=width(text:sub(firstByte,lastByte),firstByte,lastByte)+extra
  end
  return cache[key]
 end
 local memo={}
 local function solve(lineIndex,first)
  if lineIndex>#rects then return first>#chars and {{}} or {} end
  local cacheKey=lineIndex..':'..first
  if memo[cacheKey] then return memo[cacheKey] end
  local rect=rects[lineIndex]
  if not rect or rect.width<0 or rect.height<=0 then return {} end
  local lastLimit=first
  while lastLimit<=#chars and chars[lastLimit].text~='\n' and chars[lastLimit].text~='\r' do lastLimit=lastLimit+1 end
  lastLimit=lastLimit-1
  local paths={}
  for last=first-1,lastLimit do
   local measuredWidth=measured(first,last)
   if math.abs(measuredWidth-rect.width)<=tolerance then
    local nextFirst=last+1
    if chars[nextFirst] and chars[nextFirst].text=='\r' then nextFirst=nextFirst+1 end
    if chars[nextFirst] and chars[nextFirst].text=='\n' then nextFirst=nextFirst+1 end
    -- Nonempty remaining text cannot be consumed by an empty zero-width line.
    if last>=first or nextFirst>first or first>#chars then
     local tails=solve(lineIndex+1,nextFirst)
     for _,tail in ipairs(tails) do
      local line={firstByte=chars[first] and chars[first].first or #text+1,
       lastByte=last>=first and chars[last].last or (chars[first] and chars[first].first or #text+1)-1,
       x=rect.x,y=rect.y,width=rect.width,height=rect.height,measuredWidth=measuredWidth}
      line.text=text:sub(line.firstByte,line.lastByte)
      local path={line};for _,item in ipairs(tail) do path[#path+1]=item end
      paths[#paths+1]=path
      if #paths>1 then memo[cacheKey]=paths;return paths end
     end
    end
   end
   -- Positive glyph advances let us stop once this line is already too wide.
   if measuredWidth>rect.width+tolerance then break end
  end
  memo[cacheKey]=paths;return paths
 end
 local paths=solve(1,1)
 if #paths==0 then return nil,'measured text does not match native line widths' end
 if #paths>1 then return nil,'ambiguous native line boundaries' end
 return paths[1]
end

-- Keep each reviewed reading span on one visual line.
-- The source widget keeps its original wrapping; only the optional overlay copies
-- use these lines. Never divide a reading into guessed syllable fragments.
function M.wrap_words(text,segments,rects,width,model,options)
 options=options or {};model=model or {}
 local maximum=options.availableWidth or 0
 if maximum<=0 then for _,r in ipairs(rects) do maximum=math.max(maximum,r.x+r.width) end end
 if maximum<=0 or #rects==0 then return nil,'no native width for subtitle word wrapping' end
 local extra=2*(model.outline or 0)+math.abs(model.shadowX or 0)
 local limit=maximum-extra
 if limit<=0 then return nil,'subtitle width is smaller than its outline' end
 local tokens={};local cursor=1
 for index,segment in ipairs(segments) do
  if segment.reading and segment.reading~='' then
   tokens[#tokens+1]={text=segment.text,first=cursor,last=cursor+#segment.text-1,segment=index}
  else
   for _,c in ipairs(characters(segment.text)) do
    tokens[#tokens+1]={text=c.text,first=cursor+c.first-1,last=cursor+c.last-1}
   end
  end
  cursor=cursor+#segment.text
 end
 -- Keep closing punctuation with its preceding word and opening punctuation
 -- with the following word. No visible characters or reading spans are split.
 local closing,opening={},{}
 for _,c in ipairs(characters('、。，．？！：；!?.,:;）］｝〉》」』】〕〟’”ー…)］]}ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ々ゝゞヽヾ')) do closing[c.text]=true end
 for _,c in ipairs(characters('（［｛〈《「『【〔〝‘“([{')) do opening[c.text]=true end
 local units={};local openPrefix
 for _,token in ipairs(tokens) do
  if token.text=='\n' or token.text=='\r' then
   if openPrefix then units[#units+1]=openPrefix;openPrefix=nil end
   local previous=units[#units]
   if token.text=='\n' and previous and previous.text=='\r' then
    previous.text='\r\n';previous.last=token.last
   else
    units[#units+1]=token
   end
  elseif not token.segment and opening[token.text] then
   if openPrefix then openPrefix.text=openPrefix.text..token.text;openPrefix.last=token.last else openPrefix=token end
  else
   if openPrefix then token={text=openPrefix.text..token.text,first=openPrefix.first,last=token.last,segment=token.segment};openPrefix=nil end
   local previous=units[#units]
   if not token.segment and closing[token.text] and previous and not previous.text:find('[\r\n]') then
    previous.text=previous.text..token.text;previous.last=token.last
   else units[#units+1]=token end
  end
 end
 if openPrefix then units[#units+1]=openPrefix end
 tokens=units
 local lines={};local first,last;local pending=''
 local height=rects[1].height
 for _,r in ipairs(rects) do height=math.max(height,r.height) end
 local initialY=rects[1].y
 local step=#rects>1 and math.max(height,rects[2].y-rects[1].y) or height
 local function commit(emptyAt)
  if first or emptyAt then
   local glyphWidth=first and width(pending,first,last) or 0
   local measured=first and glyphWidth+extra or 0
   assert(measured<=maximum+.8,'Wrapped subtitle line exceeds its available width')
   local justification=options.justification or 0
   local x=justification==1 and (maximum-measured)/2 or justification==2 and maximum-measured or 0
   lines[#lines+1]={firstByte=first or emptyAt,lastByte=last or emptyAt-1,text=pending,
    x=x,y=initialY+#lines*step,width=measured,height=height,measuredWidth=measured}
  end
  first=nil;last=nil;pending=''
 end
 for _,token in ipairs(tokens) do
  if token.text:find('[\r\n]') then
   commit(token.first)
  elseif token.text~='' then
   local candidate=pending..token.text
   local candidateWidth=width(candidate,first or token.first,token.last)
   if candidateWidth>limit+.8 then
    if first then commit();candidateWidth=width(token.text,token.first,token.last) end
    if candidateWidth>limit+.8 then return nil,'one reviewed reading span exceeds the native subtitle width' end
   end
   first=first or token.first;last=token.last;pending=pending..token.text
  end
 end
 commit(text:find('[\r\n]$') and #text+1 or nil)
 if #lines==0 or #lines>20 then return nil,'subtitle word-wrap line count outside supported range' end
 return lines
end

function M.layout(text,segments,rects,width,tolerance,model,options)
 local combined={};for _,s in ipairs(segments) do combined[#combined+1]=s.text end
 if table.concat(combined)~=text then return nil,'annotation segments differ from the localized subtitle' end
 local lines,reason
 if options and options.forceWordWrap then lines,reason=M.wrap_words(text,segments,rects,width,model,options)
 else lines,reason=M.partition(text,rects,width,tolerance,model) end
 if not lines then return nil,reason end
 local repacked=options and options.forceWordWrap or false
 if options and options.keepReadingWords then
  local cursor=1;local split=false
  for _,segment in ipairs(segments) do
   local finish=cursor+#segment.text-1
   if segment.reading and segment.reading~='' then
    local fits=false
    for _,line in ipairs(lines) do if cursor>=line.firstByte and finish<=line.lastByte then fits=true;break end end
    if not fits then split=true;break end
   end
   cursor=finish+1
  end
  if split then
   lines,reason=M.wrap_words(text,segments,rects,width,model,options)
   if not lines then return nil,reason end
   repacked=true
  end
 end
 local runs={};local skipped={};local cursor=1
 for index,segment in ipairs(segments) do
  local finish=cursor+#segment.text-1
  if segment.reading and segment.reading~='' then
   local found=false
   for lineIndex,line in ipairs(lines) do
    if cursor>=line.firstByte and finish<=line.lastByte then
     local before=text:sub(line.firstByte,cursor-1)
     local through=text:sub(line.firstByte,finish)
     local left=before=='' and 0 or width(before,line.firstByte,cursor-1)
     local right=width(through,line.firstByte,finish)
     if model and model.richOutline then
      local newRun=cursor==line.firstByte
      for _,span in ipairs(model.richSpans or {}) do if span.firstByte==cursor then newRun=true;break end end
      left=left+(newRun and model.richOutline or -model.richOutline)
      right=right-model.richOutline
     end
     local glyphOrigin=line.x+(model and model.glyphOffset or 0)
     runs[#runs+1]={segment=index,text=segment.text,reading=segment.reading,line=lineIndex,
      x=glyphOrigin+(left+right)/2,y=line.y,baseLeft=glyphOrigin+left,baseRight=glyphOrigin+right,
      previousBottom=lineIndex>1 and (lines[lineIndex-1].y+lines[lineIndex-1].height) or nil}
     found=true;break
    end
   end
   if not found then skipped[#skipped+1]={segment=index,text=segment.text,reason='reading spans a native line break'} end
  end
  cursor=finish+1
 end
 return {lines=lines,runs=runs,skipped=skipped,repacked=repacked}
end

function M.detach(handle)
 if not handle then return end
 if handle.sourcePath and handle.originalOpacity~=nil then
  local source=StaticFindObject(handle.sourcePath)
  if valid(source) and (not handle.conditionalOpacityRestore or source:GetRenderOpacity()==0) then
   source:SetRenderOpacity(handle.originalOpacity)
  end
 end
 local canvas=StaticFindObject(handle.path or handle.detachable)
 if valid(canvas) then canvas:RemoveFromParent() end
end

-- Reserve real space above each following line for its tallest reading. Shared
-- callers keep native breaks; subtitle callers may explicitly repack whole words.
function M.reflow(lines,runs,bodySizes,options)
 options=options or {};bodySizes=bodySizes or {}
 local minimumRatio=options.compactReflow and 1.55 or 1.7
 local ratio=math.max(minimumRatio,options.reflowLineHeight or minimumRatio)
 local gap=options.gap or 1
 local rowGap=options.reflowRowGap or 2
 local maxRuby={}
 for _,r in ipairs(runs) do maxRuby[r.line]=math.max(maxRuby[r.line] or 0,r.height) end
 local result={}
 for i,line in ipairs(lines) do
  local copy={};for key,value in pairs(line) do copy[key]=value end
  copy.nativeY=line.y;copy.nativeHeight=line.height
  copy.height=math.max(line.height,bodySizes[i] and bodySizes[i].height or 0)
  copy.bodyWidth=bodySizes[i] and bodySizes[i].width or line.width
  copy.rubyHeight=maxRuby[i] or 0
  if i>1 then
   local previous=result[i-1]
   copy.y=math.max(line.y,previous.y+math.max(previous.height*ratio,previous.height+copy.rubyHeight+gap+rowGap))
  end
  result[i]=copy
 end
 local oldHeight=#lines>0 and (lines[#lines].y+lines[#lines].height-lines[1].y) or 0
 local height=#result>0 and (result[#result].y+result[#result].height-result[1].y) or 0
 return result,{lineHeightRatio=ratio,rowGap=rowGap,originalHeight=oldHeight,height=height,addedHeight=height-oldHeight}
end

-- Resolve actual neighboring collisions without moving a reading off its kanji.
-- Only colliding readings are constrained to the midpoint between centers; this
-- preserves ordinary overhang into adjacent unannotated kana. measure(run,ratio)
-- returns the real desired width/height for that font size. No glyph squeezing.
function M.fit_horizontal(runs,measure,options)
 options=options or {}
 local gap=options.horizontalGap or 2
 local minimum=math.max(.45,options.minimumRatio or .45)
 local function ordered()
  local a={};for _,r in ipairs(runs) do if not r.omitted then a[#a+1]=r end end
  table.sort(a,function(a,b) if a.line~=b.line then return a.line<b.line end;return a.x<b.x end)
  return a
 end
 local function collisions(a)
  local count,marked=0,{}
  for i=1,#a-1 do
   local left,right=a[i],a[i+1]
   if left.line==right.line and right.x-left.x<(left.width+right.width)/2+gap-.01 then
    count=count+1;marked[left]=true;marked[right]=true
   end
  end
  return count,marked
 end
 local initial=collisions(ordered())
 local skipped,adjustments={},{}
 for pass=1,#runs*2+1 do
  local a=ordered();local count,marked=collisions(a)
  if count==0 then break end
  local changed=false
  for i,r in ipairs(a) do
   if marked[r] then
    local available=math.huge
    local left,right=a[i-1],a[i+1]
    if left and left.line==r.line then available=math.min(available,r.x-left.x-gap) end
    if right and right.line==r.line then available=math.min(available,right.x-r.x-gap) end
    if r.width>available+.01 then
     local minRatio=math.min(minimum,r.ratio)
     local minWidth,minHeight=measure(r,minRatio)
     if available<=0 or minWidth>available+.01 then
      r.omitted=true
      skipped[#skipped+1]={segment=r.segment,text=r.text,reading=r.reading,line=r.line,
       reason='reading cannot fit midpoint bounds at minimum font size',minimumRatio=minRatio,
       minimumWidth=minWidth,availableWidth=available,originalWidth=r.width}
      changed=true
      -- Recompute neighbors after removing one reading; another can now fit.
      break
     end
     local lower,upper=minRatio,r.ratio
     local bestRatio,bestWidth,bestHeight=minRatio,minWidth,minHeight
     for iteration=1,8 do
      local ratio=(lower+upper)/2
      local width,height=measure(r,ratio)
      if width<=available+.01 then bestRatio,bestWidth,bestHeight=ratio,width,height;lower=ratio else upper=ratio end
     end
     adjustments[#adjustments+1]={segment=r.segment,text=r.text,reading=r.reading,line=r.line,
      originalRatio=r.ratio,ratio=bestRatio,originalWidth=r.width,width=bestWidth,
      availableWidth=available,minimumRatio=minRatio}
     r.ratio=bestRatio;r.width=bestWidth;r.height=bestHeight;r.availableWidth=available
     changed=true
    end
   end
  end
  if not changed then break end
 end
 local active=ordered();local remaining=collisions(active)
 return {runs=active,skipped=skipped,adjustments=adjustments,initialCollisions=initial,
  remainingCollisions=remaining,horizontalGap=gap,minimumRatio=minimum}
end

-- Subtitle-only bounded placement. Midpoint quotas unnecessarily reject a long
-- reading next to a short one: the actual constraint is their combined half
-- widths plus a gap. Keep every center within the middle half of its own base
-- word, and shrink only an infeasible neighboring group, never the whole line.
local function fitSubtitleBounds(runs,measure,options,movementFraction)
 options=options or {}
 local gap=options.horizontalGap or 2
 local minimum=math.max(.45,options.minimumRatio or .45)
 local a={};local initial=0
 for _,r in ipairs(runs) do
  assert(r.baseLeft and r.baseRight and r.baseRight>=r.baseLeft,'Subtitle reading has no valid base bounds')
  r.originalX=r.x;r.originalRatio=r.ratio;r.originalWidth=r.width
  local movement=(r.baseRight-r.baseLeft)*movementFraction
  r.minimumX=r.x-movement;r.maximumX=r.x+movement
  a[#a+1]=r
 end
 table.sort(a,function(left,right)if left.line~=right.line then return left.line<right.line end;return left.x<right.x end)
 local function distance(left,right)return (left.width+right.width)/2+gap end
 local function lower(r)
  return math.max(r.minimumX,(options.clipLeft or -math.huge)+r.width/2)
 end
 local function upper(r)
  return math.min(r.maximumX,(options.clipRight or math.huge)-r.width/2)
 end
 local function collisionCount()
  local n=0
  for i=2,#a do if a[i].line==a[i-1].line and a[i].x-a[i-1].x<distance(a[i-1],a[i])-.01 then n=n+1 end end
  return n
 end
 initial=collisionCount()
 -- Earliest feasible centers identify the exact interval whose upper bound is
 -- exceeded. A reset to a word's own lower bound starts a new independent group.
 local function feasible(last)
  local earliest,start
  for i=1,last or #a do
   local r=a[i]
   local minimumX,maximumX=lower(r),upper(r)
   if i==1 or a[i-1].line~=r.line then earliest=minimumX;start=i
   else
    local nextCenter=earliest+distance(a[i-1],r)
    if nextCenter>minimumX then earliest=nextCenter else earliest=minimumX;start=i end
   end
   if earliest>maximumX+.001 then return false,start,i end
  end
  return true
 end
 local measured={}
 local function setRatio(r,ratio)
  measured[r]=measured[r] or {}
  local cached=measured[r][ratio]
  if not cached then local width,height=measure(r,ratio);cached={width,height};measured[r][ratio]=cached end
  r.ratio=ratio;r.width=cached[1];r.height=cached[2]
 end
 local failure
 for pass=1,#a*2+1 do
  local fits,first,last=feasible()
  if fits then break end
  local previous={}
  for i=first,last do previous[i]=a[i].ratio end
  local function setGroup(factor)
   for i=first,last do
    local floor=math.min(minimum,previous[i])
    setRatio(a[i],floor+(previous[i]-floor)*factor)
   end
  end
  setGroup(0)
  if not feasible(last) then
   failure='neighboring subtitle readings cannot fit within their own base bounds at the minimum font size'
   break
  end
  local low,high=0,1
  for iteration=1,9 do
   local factor=(low+high)/2;setGroup(factor)
   if feasible(last) then low=factor else high=factor end
  end
  setGroup(low)
 end
 local fits=feasible()
 if not fits then failure=failure or 'subtitle horizontal placement did not converge' end
 if not failure then
  -- Backward latest centers reserve all future words' space. A forward pass
  -- then chooses the nearest original center that still leaves a feasible tail.
  local latest={}
  for i=#a,1,-1 do
   latest[i]=upper(a[i])
   if a[i+1] and a[i+1].line==a[i].line then latest[i]=math.min(latest[i],latest[i+1]-distance(a[i],a[i+1])) end
  end
  for i,r in ipairs(a) do
   local earliest=lower(r)
   if a[i-1] and a[i-1].line==r.line then earliest=math.max(earliest,a[i-1].x+distance(a[i-1],r)) end
   r.x=math.max(earliest,math.min(r.originalX,latest[i]))
  end
 end
 local adjustments={}
 for _,r in ipairs(a) do
  if math.abs(r.x-r.originalX)>.01 or r.ratio<r.originalRatio-.00001 then
   adjustments[#adjustments+1]={segment=r.segment,text=r.text,reading=r.reading,line=r.line,
    originalRatio=r.originalRatio,ratio=r.ratio,originalWidth=r.originalWidth,width=r.width,
    originalX=r.originalX,x=r.x,shift=r.x-r.originalX,minimumRatio=minimum,
    availableWidth=r.width,minimumX=r.minimumX,maximumX=r.maximumX}
  end
 end
 return {runs=a,skipped={},adjustments=adjustments,initialCollisions=initial,
  remainingCollisions=collisionCount(),horizontalGap=gap,minimumRatio=minimum,reason=failure}
end

-- Keep successful middle-half placements unchanged. A dense sequence of
-- single kanji can need a little more room even at the readable size floor.
-- Retry only failed placements with centers bounded by their own base edges;
-- never move a center over another word or omit a reviewed reading.
function M.fit_subtitle_horizontal(runs,measure,options)
 local original={}
 for i,r in ipairs(runs)do original[i]={x=r.x,ratio=r.ratio,width=r.width,height=r.height}end
 local narrow=fitSubtitleBounds(runs,measure,options,.25)
 narrow.baseMovementFraction=.25;narrow.usedBaseEdgeFallback=false
 if not narrow.reason or (options and options.allowBaseEdgeFallback==false)then return narrow end
 for i,r in ipairs(runs)do
  local old=original[i];r.x=old.x;r.ratio=old.ratio;r.width=old.width;r.height=old.height
 end
 local wider=fitSubtitleBounds(runs,measure,options,.5)
 wider.baseMovementFraction=.5;wider.usedBaseEdgeFallback=true
 wider.narrowFailure=narrow.reason
 return wider
end

-- options: overlay, originX/Y (widget origin relative to overlay), font,
-- sourceText, rects, ratio (default .6), gap (default 1), tolerance,
-- horizontalGap (default 2), minimumRatio (default .45), reflow (default false),
-- reflowLineHeight (minimum/default 1.7), allowCrowded
-- (explicit diagnostic opt-in). Source layout is intact; reflow only hides its
-- rendering while attached, and detach restores the source's original opacity.
function M.attach(w,segments,state,log,options)
 options=options or {};log=log or function()end
 local text=options.sourceText or w:GetSynchronizedText():ToString()
 local parsed
 local hasMarkup=options.richText==true and text:find('[<>]')~=nil
 if hasMarkup or options.measureNativeRich then
  local reason;parsed,reason=M.parse_rich_text(text,segments,options.weaponMarkup,options.inlineEffects,options.tutorialMarkup)
  if not parsed then return nil,{reason=reason} end
 end
 local layoutText=parsed and parsed.visible or text
 local layoutSegments=parsed and parsed.segments or segments
 local overlay=options.overlay or w:GetParent():GetParent()
 if not valid(overlay) or overlay:GetClass():GetFName():ToString()~='Overlay' then return nil,{reason='unsupported subtitle parent'} end
 local layoutRoot=options.layoutRoot or overlay
 local font=options.font or w.DefaultTextStyleOverride.Font
 if not font.Size or font.Size<=0 then return nil,{reason='no resolved subtitle font'} end
 local rects=options.rects or M.rects(w)
 local originalDesired=w:GetDesiredSize()
 local sourceBefore={text=w:GetText():ToString(),fontSize=font.Size,fontObject=font.FontObject:GetFullName(),desiredX=originalDesired.X,desiredY=originalDesired.Y}
 state.serial=(state.serial or 0)+1
 local prefix='PBZFurigana_Subtitle_'..state.serial..'_'
 local canvas=make('CanvasPanel',w:GetOuter(),prefix..'Layer')
 -- SConstraintCanvas normally includes child extents in its desired size. Keep
 -- that from expanding the source subtitle's Overlay/VerticalBox layout.
 local bounds=make('SizeBox',w:GetOuter(),prefix..'Bounds')
 bounds:SetWidthOverride(0);bounds:SetHeightOverride(0)
 local handle={path=object_path(bounds),canvasPath=object_path(canvas)};handle.detachable=handle.path
 local stats={fontSize=font.Size,ratio=math.max(.45,options.ratio or .6),verticalCollisions=0,horizontalCollisions=0,richText=hasMarkup,visibleText=layoutText,sourceBefore=sourceBefore}
 local ok,err=pcall(function()
  local inner=bounds:AddChild(canvas);inner:SetHorizontalAlignment(0);inner:SetVerticalAlignment(0)
  local slot=overlay:AddChildToOverlay(bounds)
  slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
  bounds:SetVisibility(3);bounds:SetRenderOpacity(w:GetRenderOpacity())
  canvas:SetVisibility(3)
  local measure=make('TextBlock',w:GetOuter(),prefix..'Measure')
  measure:SetFont(font);measure:SetVisibility(3);measure:SetRenderOpacity(0)
  -- A fresh widget has no tick geometry. Measuring its own prepass uses scale 1,
  -- while the game's UI can be scaled (e.g. 4/3), changing rasterized advances.
  -- Prepass the existing parent so the new widget inherits the actual UI scale.
  -- Measure glyph advances without outline/shadow; SlateTextRun only adds their
  -- horizontal extents at the full run's start/end, not at every wrapped line.
  measure.Font.OutlineSettings.OutlineSize=0;measure:SetFont(measure.Font)
  measure:SetShadowOffset({X=0,Y=0})
  measure:SetAutoWrapText(false)
  if options.plainSource then
   measure.LineHeightPercentage=w.LineHeightPercentage
   measure.ApplyLineHeightToBottomLine=w.ApplyLineHeightToBottomLine
   measure.ShapedTextOptions=w.ShapedTextOptions
  end
  local measureSlot=canvas:AddChildToCanvas(measure);measureSlot:SetAutoSize(true)
  local outline=font.OutlineSettings.OutlineSize
  local shadowX=options.shadowX or w.DefaultTextStyleOverride.ShadowOffset.X
  local scale=1
  local scaleOk,actualScale=pcall(function()
   return StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary'):GetViewportScale(w)
  end)
  if scaleOk and type(actualScale)=='number' and actualScale>0 then scale=actualScale end
  local model={outline=outline,shadowX=shadowX,
   glyphOffset=math.floor(outline*scale+.5)/scale+math.max(0,-shadowX)}
  stats.measurementModel=model;stats.layoutScale=scale
  local widths={['']=0}
  local function plainWidth(s)
   if widths[s]~=nil then return widths[s] end
   measure:SetText(FText(s));layoutRoot:ForceLayoutPrepass()
   local result=measure:GetDesiredSize().X
   assert(result>0,'Slate text measurement unavailable')
   widths[s]=result;return result
  end
  local measureRich
  local function richWidget(name,raw,wrapped)
   local copy=StaticConstructObject(w:GetClass(),w:GetOuter(),FName(name))
   assert(valid(copy),'Could not construct native rich subtitle copy')
   copy.PBZTextStyleSet=w.PBZTextStyleSet;copy.RichTextStyleConfig=w.RichTextStyleConfig
   copy.bFindConfigTextStyleSet=w.bFindConfigTextStyleSet
   -- PBZ's custom-color policy applies to rich runs as well as default text.
   -- A newly constructed widget otherwise falls back to the data table's tag
   -- colors (for example yellow Bold) even when the source overrides them.
   copy.SavedColorAndOpacity=w.SavedColorAndOpacity;copy.DefaultColor=w.DefaultColor
   copy.bUseCustomColor=w.bUseCustomColor
   copy.bUseWidgetLineHighSetting=w.bUseWidgetLineHighSetting
   copy.bUseLineHighPercentageOnBottomLine=w.bUseLineHighPercentageOnBottomLine
   copy.bTintInlineIcon=w.bTintInlineIcon;copy.bDisplayAllCaps=w.bDisplayAllCaps
   copy.MobileTextBlockScale=w.MobileTextBlockScale
   -- Subtitle language decorators own run handling too; the source's SubBody
   -- decorator must be instantiated for this copy rather than using a generic
   -- widget's empty decorator list. The engine copies the class array and owns
   -- fresh decorator instances, so the source's instances are never reused.
   copy:SetDecorators(w.DecoratorClasses)
   if valid(w.DefaultTextStyleOverrideClass) then copy:SetStyle(w.DefaultTextStyleOverrideClass) end
   local cultureOverride=w.DisplayCultureOverride
   if type(cultureOverride)~='string' then cultureOverride=cultureOverride:ToString() end
   copy:SetDisplayCultureOverride(cultureOverride)
   copy:SetDefaultTextStyle(w.DefaultTextStyleOverride)
   copy:SetOutlineOverride(w.OutlineOverride)
   copy:OverrideTextColor(w.SavedColorAndOpacity,w.bUseCustomColor)
   if options.weaponMarkup or options.measureNativeRich then
    for _,field in ipairs({'InlineIconDisplayMode','TextSizeScaleConfigs','MinDesiredWidth','TextTransformPolicy',
     'TextOverflowPolicy','ShapedTextOptions','WrappingPolicy','ApplyLineHeightToBottomLine','Margin','LineHeightPercentage',
     'ScrollStyle','ScrollOrientation'})do
     copy[field]=w[field]
    end
    copy:SetTagStyleMapping(w.TagStyleMapping)
    copy:SetScrollingEnabled(w.bIsScrollingEnabled)
   end
   local wrapWidth=wrapped and w.WrapTextAt or 0
   local autoWrap=wrapped and (w.AutoWrapText==true or w.AutoWrapText==1)
   if autoWrap and options.availableWidth and options.availableWidth>0 then
    wrapWidth=wrapWidth>0 and math.min(wrapWidth,options.availableWidth) or options.availableWidth
   end
   copy:SetAutoWrapText(autoWrap)
   copy:SetWrapTextWidth(wrapWidth);copy:SetJustification(wrapped and w.Justification or 0)
   copy:SetText(FText(raw));copy:SetVisibility(3)
   return copy
  end
  local function resolveRich(copy)
   -- The first Slate construction applies the CommonUI style class again. Keep
   -- that class's rich-run policy, then restore the source's already resolved
   -- language/font style only after construction has finished.
   layoutRoot:ForceLayoutPrepass()
   copy:SetDefaultTextStyle(w.DefaultTextStyleOverride)
   copy:SetDefaultFont(font)
   copy:OverrideTextColor(w.SavedColorAndOpacity,w.bUseCustomColor)
   copy:RefreshTextLayout()
   layoutRoot:ForceLayoutPrepass()
  end
  local width=plainWidth;local layoutModel=model;local layoutOptions=options
  local richLayoutScale=options.richLayoutScale or 1
  assert(richLayoutScale==1 or (parsed and not hasMarkup and options.preserveNativeLines),
   'Scaled rich text must retain its native layout')
  local rubyFontSize=font.Size*richLayoutScale
  if options.plainSource then
   local limit=options.availableWidth
   assert(limit and limit>0,'Plain text has no allocated width')
   if w.WrapTextAt>0 then limit=math.min(limit,w.WrapTextAt) end
   local explicitBreak=text:find('[\r\n]')~=nil
   local measuredWidth=not explicitBreak and plainWidth(text) or nil
   if measuredWidth and measuredWidth<=limit+.08 then
    -- The source's allocated line supplies Y and height. PBZ may override
    -- line spacing, so the unwrapped measuring widget only verifies advances.
    assert(math.abs(measuredWidth-originalDesired.X)<.8,
     string.format('Plain single-line width changed from %.3f to %.3f',originalDesired.X,measuredWidth))
   else
    local autoWrap=w.AutoWrapText==true or w.AutoWrapText==1
    assert(options.allowPlainReflow and (explicitBreak or autoWrap or w.WrapTextAt>0),
     'Plain text cannot reflow in this widget')
    assert((utf8.len(text) or math.huge)<=2048,'Plain text exceeds the reflow character limit')
    plainWidth('漢')
    local lineHeight=measure:GetDesiredSize().Y
    assert(lineHeight>0 and originalDesired.Y>lineHeight+.08,
     'Plain multiline layout has not settled')
    rects={{x=0,y=0,width=limit,height=lineHeight}}
    layoutOptions={}
    for key,value in pairs(options) do layoutOptions[key]=value end
    layoutOptions.availableWidth=limit
    layoutOptions.forceWordWrap=true
   end
  end
  if parsed then
   assert(not hasMarkup or valid(w.PBZTextStyleSet),'Native subtitle style table is unavailable')
   local mapped=false;w.TagStyleMapping:ForEach(function()mapped=true end)
   assert(not hasMarkup or not mapped or options.weaponMarkup,'Mapped subtitle tags require an explicitly reviewed mapping')
   if valid(w.PBZTextStyleSet) then stats.richStyleTable=w.PBZTextStyleSet:GetFullName() end
   local checkNativeClone=options.weaponMarkup or options.measureNativeRich
   measureRich=richWidget(prefix..'MeasureRich',text,checkNativeClone);measureRich:SetRenderOpacity(0)
   local richSlot=canvas:AddChildToCanvas(measureRich);richSlot:SetAutoSize(true)
   resolveRich(measureRich)
   if checkNativeClone then
    local nativeLines=M.rects(measureRich)
    assert(#nativeLines==#rects,'Weapon clone changes line count')
    for i,line in ipairs(nativeLines)do
     local original=rects[i]
     for _,field in ipairs({'x','y','width','height'})do
     assert(math.abs(original[field]-line[field])<.08,
       string.format('Rich clone line %d %s changed from %.3f to %.3f',i,field,original[field],line[field]))
     end
    end
    measureRich:SetAutoWrapText(false);measureRich:SetWrapTextWidth(0)
   end
   local richWidths={}
   local measurementCount=0
   local measurementLimit=math.min(2048,math.max(300,3*utf8.len(layoutText)+24))
   width=function(s,first,last)
    if s=='' then return 0 end
    assert(first and last,'Rich subtitle measurement needs original visible byte ranges')
    local key=M.rich_slice(parsed,first,last)
    if richWidths[key]~=nil then return richWidths[key] end
    measurementCount=measurementCount+1
    assert(not checkNativeClone or measurementCount<=measurementLimit,'Rich text measurement exceeded the per-row budget')
    measureRich:SetText(FText(key));layoutRoot:ForceLayoutPrepass()
    local measured=measureRich:GetDesiredSize().X
    assert(measured>0,'Native rich subtitle measurement unavailable')
    assert(measureRich.DefaultTextStyleOverride.Font.Size==font.Size,'Native rich copy changed the resolved subtitle font size: source='..font.Size..' copy='..measureRich.DefaultTextStyleOverride.Font.Size)
    richWidths[key]=measured;return measured
   end
   -- Rich copies measure their real native style runs, including their edges.
   -- They can be wrapped directly without pretending Bold has default metrics.
   layoutModel={outline=0,shadowX=0,glyphOffset=0,richOutline=outline,richSpans=parsed.spans}
   layoutOptions={};for key,value in pairs(options) do layoutOptions[key]=value end
   layoutOptions.forceWordWrap=not options.requireNativeBreaks and ((hasMarkup and not options.preserveNativeLines)
    or options.forceWordWrap or (checkNativeClone and options.reflow))
  end
  if richLayoutScale~=1 then
   local scaled={}
   for i,line in ipairs(rects)do
    scaled[i]={x=line.x*richLayoutScale,y=line.y*richLayoutScale,width=line.width*richLayoutScale,height=line.height*richLayoutScale}
   end
   rects=scaled
  end
  local plan,reason=M.layout(layoutText,layoutSegments,rects,width,options.tolerance,layoutModel,layoutOptions)
  if not plan then
   log('subtitle_measure_mismatch glyph_width='..width(layoutText,1,#layoutText)..' native_width='..tostring(rects[1] and rects[1].width)..' font='..font.Size..' letterspacing='..font.LetterSpacing..' outline='..outline..' shadowX='..shadowX..' scale='..scale..' text='..text)
   error(reason)
  end
  stats.lines=plan.lines;stats.skipped=plan.skipped;stats.runs={};stats.repacked=plan.repacked
  assert(not options.requireNativeBreaks or not plan.repacked,'Reflow would change native line breaks')
  local doReflow=options.reflow or plan.repacked or hasMarkup
  if options.preserveNativeLines then
   assert((not hasMarkup or options.measureNativeRich) and not plan.repacked,
    'Native-line-only mode requires unchanged measured text lines')
   doReflow=false
  end
  local originX,originY=options.originX or 0,options.originY or 0
  local widgets={};local candidates={}
  for _,run in ipairs(plan.runs) do
   local ruby=make('TextBlock',w:GetOuter(),prefix..'Reading_'..run.segment)
   ruby:SetFont(font);ruby.Font.Size=rubyFontSize*stats.ratio; ruby.Font.LetterSpacing=0
   ruby.Font.OutlineSettings.OutlineSize=math.max(0,math.floor(outline*stats.ratio+.5))
   ruby:SetFont(ruby.Font);ruby:SetText(FText(run.reading));ruby:SetJustification(1)
   ruby:SetColorAndOpacity(options.rubyColor or {SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0})
   ruby:SetVisibility(3);ruby:SetAutoWrapText(false)
   local rs=canvas:AddChildToCanvas(ruby);rs:SetAutoSize(true);rs:SetAlignment({X=.5,Y=0});rs:SetZOrder(1)
   layoutRoot:ForceLayoutPrepass();local size=ruby:GetDesiredSize()
   candidates[#candidates+1]={segment=run.segment,text=run.text,reading=run.reading,
    line=run.line,x=run.x,lineTop=run.y,previousBottom=run.previousBottom,
    baseLeft=run.baseLeft,baseRight=run.baseRight,
    ratio=stats.ratio,width=size.X,height=size.Y}
   widgets[run.segment]={widget=ruby,slot=rs}
  end
  local function resize(run,ratio)
   local ruby=widgets[run.segment].widget
   ruby.Font.Size=rubyFontSize*ratio
   ruby.Font.OutlineSettings.OutlineSize=math.max(0,math.floor(outline*ratio+.5))
   ruby:SetFont(ruby.Font);layoutRoot:ForceLayoutPrepass()
   local size=ruby:GetDesiredSize();return size.X,size.Y
  end
  local fitted=(options.boundedHorizontal and M.fit_subtitle_horizontal or M.fit_horizontal)(candidates,resize,options)
  stats.initialHorizontalCollisions=fitted.initialCollisions
  stats.horizontalCollisions=fitted.remainingCollisions
  stats.horizontalGap=fitted.horizontalGap;stats.minimumRatio=fitted.minimumRatio
  stats.adjustments=fitted.adjustments
  stats.baseMovementFraction=fitted.baseMovementFraction
  stats.usedBaseEdgeFallback=fitted.usedBaseEdgeFallback
  if fitted.reason then error(fitted.reason) end
  for _,s in ipairs(fitted.skipped) do
   stats.skipped[#stats.skipped+1]=s
   log('ruby_skip text='..s.text..' minimum_width='..s.minimumWidth..' available='..s.availableWidth)
  end
  for _,a in ipairs(fitted.adjustments) do
   log('ruby_fit text='..a.text..' ratio='..a.ratio..' width='..a.width..' available='..a.availableWidth..' shift='..tostring(a.shift or 0))
  end
  for _,run in ipairs(candidates) do
   if run.omitted then widgets[run.segment].widget:RemoveFromParent() end
  end
  for _,run in ipairs(fitted.runs) do
   -- Binary search may have last measured a rejected size. Apply the chosen size.
   run.width,run.height=resize(run,run.ratio)
  end
  if doReflow then
   local style=options.plainSource and w or w.DefaultTextStyleOverride
   local bodyWidgets,bodySizes={},{}
   for i,line in ipairs(plan.lines) do
    local body
    if parsed then body=richWidget(prefix..'Body_'..i,M.rich_slice(parsed,line.firstByte,line.lastByte))
    else
     body=make('TextBlock',w:GetOuter(),prefix..'Body_'..i)
     body:SetFont(font);body:SetText(FText(line.text));body:SetJustification(0)
     body:SetColorAndOpacity(style.ColorAndOpacity)
     body:SetShadowOffset({X=style.ShadowOffset.X,Y=style.ShadowOffset.Y});body:SetShadowColorAndOpacity(style.ShadowColorAndOpacity)
     if options.plainSource then body.ShapedTextOptions=w.ShapedTextOptions end
     body:SetVisibility(3);body:SetAutoWrapText(false)
    end
    local slot=canvas:AddChildToCanvas(body)
    slot:SetAutoSize(true);slot:SetAlignment({X=0,Y=0});slot:SetZOrder(0)
    if parsed then resolveRich(body) end
    layoutRoot:ForceLayoutPrepass();local size=body:GetDesiredSize()
    if options.plainSource then
     assert(size.X<=layoutOptions.availableWidth+.8 and math.abs(size.X-line.width)<.08,
      'Plain reflow changed measured line width')
    end
    bodyWidgets[i]={widget=body,slot=slot}
    bodySizes[i]={width=size.X,height=size.Y}
   end
   local lines,details=M.reflow(plan.lines,fitted.runs,bodySizes,options)
   stats.nativeLines=plan.lines;stats.lines=lines;stats.reflow=details
   for i,line in ipairs(lines) do
    -- Both the original rich-text block and this outlined copy draw the glyphs
    -- after the same quantized outline offset. Keep the native line's X offset.
    bodyWidgets[i].slot:SetPosition({X=originX+line.x,Y=originY+line.y})
   end
   for _,run in ipairs(fitted.runs) do
    run.lineTop=lines[run.line].y
    run.previousBottom=run.line>1 and (lines[run.line-1].y+lines[run.line-1].height) or nil
   end
  end
  for _,run in ipairs(fitted.runs) do
   local top=run.lineTop-run.height-(options.gap or 1)
   if run.previousBottom and top<run.previousBottom-.5 then stats.verticalCollisions=stats.verticalCollisions+1 end
   run.y=top;run.fontSize=rubyFontSize*run.ratio
   stats.runs[#stats.runs+1]=run
   widgets[run.segment].slot:SetPosition({X=originX+run.x,Y=originY+top})
  end
  measure:RemoveFromParent()
  if measureRich then measureRich:RemoveFromParent() end
  if #stats.runs==0 then error('no readings can be placed on the current native lines') end
  if not options.allowCrowded and (stats.verticalCollisions>0 or stats.horizontalCollisions>0) then
   error('ruby collision: vertical='..stats.verticalCollisions..' horizontal='..stats.horizontalCollisions)
  end
  if options.requireAllReadings and #stats.skipped>0 then error('not every reviewed subtitle reading fits safely') end
  if options.protectSource then
   local after=w:GetDesiredSize();local afterFont=options.plainSource and w.Font or w.DefaultTextStyleOverride.Font
   assert(w:GetText():ToString()==sourceBefore.text,'Source subtitle text changed during annotation')
   assert(afterFont.Size==sourceBefore.fontSize and afterFont.FontObject:GetFullName()==sourceBefore.fontObject,'Source subtitle font changed during annotation')
   assert(math.abs(after.X-sourceBefore.desiredX)<.05 and math.abs(after.Y-sourceBefore.desiredY)<.05,'Source subtitle desired size changed during annotation')
   stats.sourceTextUnchanged=true;stats.sourceFontUnchanged=true;stats.sourceSizeUnchanged=true
  end
  if doReflow then
   assert(w:GetText():ToString()==text,'Source subtitle changed during reflow')
   handle.sourcePath=object_path(w);handle.originalOpacity=w:GetRenderOpacity();handle.reflow=true
   handle.conditionalOpacityRestore=options.conditionalOpacityRestore
   -- Preserve the original localized FText and its layout. The overlay owns only
   -- visible copies; detaching restores the source widget's previous opacity.
   w:SetRenderOpacity(0)
   stats.sourceTextUnchanged=w:GetText():ToString()==text
   log('subtitle_reflow lines='..#stats.lines..' height='..stats.reflow.height..' added='..stats.reflow.addedHeight..' source_unchanged='..tostring(stats.sourceTextUnchanged))
  end
  log('subtitle_ruby lines='..#stats.lines..' runs='..#stats.runs..' skipped='..#stats.skipped..' adjusted='..#stats.adjustments..' font='..stats.fontSize..' ratio='..stats.ratio)
 end)
 if not ok then M.detach(handle);stats.reason=tostring(err);return nil,stats end
 return handle,stats
end
return M
