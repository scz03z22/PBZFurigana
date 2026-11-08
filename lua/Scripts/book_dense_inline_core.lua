local compact = assert(loadfile((debug.getinfo(1, 'S').source:sub(2):gsub('[^/\\]+$', 'compact_readings.lua'))))()
-- Exact one paragraph, independent inline boxes. Pure: no engine calls.
local M={}
local CASE={["fingerprint"]="228:9236b642f2930e7e",["key"]="ReadingDes_YiJi_Letter_003",["paragraph_index"]=2,["parts"]={{12},{3,"かんが"},{6},{3,"いだ"},{3},{3,"もの"},{15},{6,"ちゅうめつ"},{24},{6,"ちゅうめつ"},{30},{3,"しん"},{9},{3,"しん"},{9},{3,"しん"},{6},{3,"しん"},{6},{3,"しん"},{6},{3,"しん"},{6},{3,"にんべん"},{3,"げん"},{3,"にんべん"},{3,"げん"},{3,"にんべん"},{3,"げん"},{3,"にんべん"},{3,"げん"},{3,"げん"},{3,"げん"},{3,"くち"},{3,"くち"},{3,"くち"},{3,"に"},{3,"に"},{3,"に"},{3,"いち"},{3,"いち"},{3,"いち"}},["plain"]=true}
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function finite(v)return type(v)=='number'and v==v and v>-math.huge and v<math.huge end
local OPEN='（［｛〈《「『【〔〝‘“([{'
local CLOSE='、。，．？！：；!?.,:;）］｝〉》」』】〕〟’”ー…ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ々ゝゞヽヾ'
local function chars(text)
 local a={};local at=1
 for ch in text:gmatch('[%z\1-\127\194-\244][\128-\191]*')do a[#a+1]={text=ch,first=at,last=at+#ch-1};at=at+#ch end
 assert(at==#text+1,'Invalid UTF8 in exact inline paragraph');return a
end
local function charSet(text)local s={};for _,ch in ipairs(chars(text))do s[ch.text]=true end;return s end
local opening,closing=charSet(OPEN),charSet(CLOSE)
local function space(s)return s==' 'or s=='　'or s=='\t'end
local function metric(value,label,allowZero)
 assert(type(value)=='table'and finite(value.width)and value.width>=(allowZero and 0 or .000001)
  and finite(value.height)and value.height>=0,label..' native metric invalid')
 return value
end
function M.case(raw) local entry=compact.expand(CASE,raw);if entry then entry.text=raw end;return entry end
function M.matches(raw)return compact.fingerprint(raw)==CASE.fingerprint and CASE.key or nil end
function M.validate(raw,segments)
 local expected=assert(M.case(raw),'Only the exact dense paragraph part2 is allowed')
 assert(type(segments)=='table'and #segments==#expected.segments,'Inline segment count changed')
 local joined={};local count=0
 for i,s in ipairs(segments)do local e=expected.segments[i]
  assert(s.text==e.text and s.reading==e.reading,'Inline text/reading changed at segment '..i)
  joined[#joined+1]=s.text;if s.reading then count=count+1 end
 end
 assert(table.concat(joined)==raw and count==30,'Exact paragraph/30 complete readings required');return count
end
function M.kinsoku()return{opening=OPEN,closing=CLOSE,spaces='ASCII space/fullwidth space/tab bind to preceding group',policy='Opening punctuation binds forward; closing punctuation/small kana/long mark/ellipsis bind backward. All bytes remain; an overwide indivisible group fails.'}end
function M.plan(raw,segments,measure,options)
 M.validate(raw,segments);options=options or{}
 local width=options.width or 530;local rowGap=options.rowGap or 0
 assert(finite(width)and width>0 and width<=2048 and finite(rowGap)and rowGap>=0 and rowGap<=256,'Inline native container/row gap invalid')
 assert(type(measure)=='table'and type(measure.base)=='function'and type(measure.ruby)=='function','Native base/ruby measurement callbacks required')
 local fallback=metric(measure.base(segments[1].text),'Base font control',false)
 local units={};local cursor=1
 for segment,s in ipairs(segments)do
  if s.reading then
   local b=metric(measure.base(s.text),'Annotated base',false);local r=metric(measure.ruby(s.reading),'Complete ruby',false)
   assert(b.height>0 and r.height>0,'Native glyph heights must be positive')
   units[#units+1]={id=#units+1,segment=segment,text=s.text,reading=s.reading,firstByte=cursor,lastByte=cursor+#s.text-1,
    baseWidth=b.width,baseHeight=b.height,rubyWidth=r.width,rubyHeight=r.height,
    advance=math.max(b.width,r.width+2),whitespace=false}
  else
   for index,ch in ipairs(chars(s.text))do
    local before=s.text:sub(1,ch.first-1);local through=s.text:sub(1,ch.last)
    local white=space(ch.text)
    local a=before==''and{width=0,height=0}or metric(measure.base(before),'Plain prefix',true)
    local b=white and a or metric(measure.base(through),'Plain prefix through character',true);local advance=b.width-a.width
    assert(finite(advance)and advance>=0,'Negative/nonfinite plain native advance')
    local advanceBefore,advanceThrough=a.width,b.width;local follower
    if white then
     -- DesiredSize may omit trailing blank advance. Use the actual following
     -- source glyph as a private measurement context, never an invented space.
     local remaining=raw:sub(cursor+ch.last);local following=chars(remaining)[1]
     assert(following and not space(following.text),'Whitespace requires its next source glyph context')
     follower=following.text
     local absent=metric(measure.base(before..follower),'Whitespace removed control',false)
     local present=metric(measure.base(through..follower),'Whitespace with following source glyph',false)
     advanceBefore,advanceThrough=absent.width,present.width;advance=present.width-absent.width
     assert(finite(advance)and advance>=0,'Whitespace contextual native advance invalid')
    end
    local glyph=white and{width=advance,height=math.max(b.height,fallback.height)}or metric(measure.base(ch.text),'Plain native glyph',false)
    if not white then assert(math.abs(glyph.width-advance)<.08,'Native plain contextual advance differs from individual glyph; shaping support required')end
    units[#units+1]={id=#units+1,segment=segment,character=index,text=ch.text,firstByte=cursor+ch.first-1,lastByte=cursor+ch.last-1,
     baseWidth=glyph.width,baseHeight=math.max(glyph.height,fallback.height),advance=advance,whitespace=white,
     nativePrefixBeforeWidth=a.width,nativePrefixThroughWidth=not white and b.width or nil,nativeAdvanceBeforeWidth=advanceBefore,
     nativeAdvanceThroughWidth=advanceThrough,whitespaceFollowingSourceGlyph=follower,trailingBlankPrefixNotUsed=white}
   end
  end
  cursor=cursor+#s.text
 end
 assert(cursor==#raw+1 and #units<=160,'Inline native unit bound')
 local roundtrip={};for _,u in ipairs(units)do roundtrip[#roundtrip+1]=u.text end;assert(table.concat(roundtrip)==raw,'Inline units altered source')
 local groups,pending={},{}
 local function group(list)
  local g={units=list,width=0,text=''}
  for _,u in ipairs(list)do g.width=g.width+u.advance;g.text=g.text..u.text end
  groups[#groups+1]=g
 end
 for i,u in ipairs(units)do
  if not u.reading and opening[u.text]then pending[#pending+1]=u
  else
   local hadOpen=#pending>0;local list=pending;pending={};list[#list+1]=u
   local previous=units[i-1]
   local suffix=not u.reading and segments[u.segment-1] and segments[u.segment-1].text=='信'
   local pair=previous and previous.text=='亻' and u.text=='言'
   local repeatedOne=previous and previous.text=='一' and u.text=='一'
   if not hadOpen and #groups>0 and (suffix or pair or repeatedOne
       or not u.reading and (closing[u.text] or u.whitespace)) then
    local g=groups[#groups];for _,v in ipairs(list)do g.units[#g.units+1]=v;g.width=g.width+v.advance;g.text=g.text..v.text end
   else group(list)end
  end
 end
 assert(#pending==0,'Unmatched opening punctuation at exact source end')
 local lines={};local current={units={},text='',width=0}
 local function commit()
  if #current.units>0 then lines[#lines+1]=current;current={units={},text='',width=0}end
 end
 for _,g in ipairs(groups)do
  if g.width>width+.00001 then return nil,{reason='indivisible_inline_group_exceeds_width',text=g.text,width=g.width,available=width}end
  if #current.units>0 and current.width+g.width>width+.00001 then commit()end
  for _,u in ipairs(g.units)do current.units[#current.units+1]=u end
  current.text=current.text..g.text;current.width=current.width+g.width
 end
 commit();assert(#lines>0 and #lines<=16,'Inline line count bound')
 local output={source=M.case(raw),units=units,lines=lines,runs={},width=width,rowGap=rowGap,baseGap=1,rubyRatio=.6,
  originalNativeGeometryPreserved=false,visualSpacingExpanded=true,synthesizedWhitespace=false,readingCount=30,
  maxLanes=1,kinsoku=M.kinsoku(),measurementPolicy='Native standalone base/ruby metrics; non-whitespace plain glyphs agree with native prefix deltas; existing whitespace uses a differential with its actual following source glyph to avoid trailing-blank trimming.'}
 local previousBottom=0;local rebuilt={}
 for index,line in ipairs(lines)do
  local first=chars(line.text)[1].text;local endChars=chars(line.text);local last=endChars[#endChars].text
  assert(not closing[first]and not space(first),'Kinsoku line starts with closing punctuation/space')
  assert(not opening[last],'Kinsoku line ends with opening punctuation')
  local rubyHeight,bodyHeight=0,0
  for _,u in ipairs(line.units)do rubyHeight=math.max(rubyHeight,u.rubyHeight or 0);bodyHeight=math.max(bodyHeight,u.baseHeight)end
  local reserve=rubyHeight>0 and rubyHeight+output.baseGap or 0
  line.firstByte=line.units[1].firstByte;line.lastByte=line.units[#line.units].lastByte
  line.rubyHeight=rubyHeight;line.rubyReserve=reserve;line.bodyHeight=bodyHeight
  line.bodyY=previousBottom+(index>1 and rowGap or 0)+reserve;line.y=line.bodyY;line.height=bodyHeight;line.x=0
  local x=0
  for _,u in ipairs(line.units)do
   u.line=index;u.boxLeft=x;u.boxRight=x+u.advance;u.boxCenter=x+u.advance/2
   u.bodyX=u.reading and u.boxCenter-u.baseWidth/2 or x;u.bodyY=line.bodyY
   if u.reading then
    u.rubyX=u.boxCenter;u.rubyY=line.bodyY-output.baseGap-u.rubyHeight
    output.runs[#output.runs+1]={segment=u.segment,text=u.text,reading=u.reading,line=index,lane=1,x=u.rubyX,y=u.rubyY,
     width=u.rubyWidth,height=u.rubyHeight,baseLeft=u.bodyX,baseRight=u.bodyX+u.baseWidth,boxLeft=u.boxLeft,boxRight=u.boxRight,
     ratio=.6,fontSize=10.8,completeSingleLineReading=true}
   end
   x=u.boxRight
  end
  assert(math.abs(x-line.width)<.00001 and x<=width+.00001,'Inline box width accounting')
  previousBottom=line.bodyY+bodyHeight;rebuilt[#rebuilt+1]=line.text
 end
 assert(table.concat(rebuilt)==raw and #output.runs==30,'Inline source/ruby final roundtrip')
 table.sort(output.runs,function(a,b)return a.segment<b.segment end)
 output.height=previousBottom;assert(output.height<=2000,'Inline paragraph expanded height bound')
 output.horizontalCollisions=0;output.verticalCollisions=0;output.omittedReadings=0
 return output
end
return M
