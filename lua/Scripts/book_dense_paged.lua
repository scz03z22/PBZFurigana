-- Pure exact-paragraph pagination of already native-measured inline rows.
local M={}
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function finite(v)return type(v)=='number'and v==v and v>-math.huge and v<math.huge end
function M.split(layout,options)
 options=options or{};assert(type(layout)=='table'and layout.source.key=='ReadingDes_YiJi_Letter_003'and layout.source.paragraph_index==2,'Exact dense part2 only')
 assert(layout.readingCount==30 and #layout.runs==30 and layout.maxLanes==1 and layout.rubyRatio==.6,'Full30 single-lane inline plan required')
 local height,footer,gap=options.height,options.footerHeight,options.footerGap or 1
 assert(finite(height)and height>0 and height<=4096 and finite(footer)and footer>0 and finite(gap)and gap>=0 and gap<=64,'Actual native page/footer heights required')
 local available=height-footer-gap;assert(available>0,'No native content area after page counter')
 local maxRows=options.maxRows or 16;assert(type(maxRows)=='number'and maxRows%1==0 and maxRows>=1 and maxRows<=16,'Bounded rows per page required')
 assert(#layout.lines>0 and #layout.lines<=16 and #layout.units<=160,'Measured row/unit bound')
 local all=copy(layout);all.pages={};all.units={};all.runs={};all.availableHeight=height;all.contentBudget=available
 all.footerHeight=footer;all.footerGap=gap;all.unpagedHeight=layout.height;all.sourceNativeLineCountIsNotPageLineCount=true
 local current,previousByte=nil,0;local joined={};local seenUnits,seenReadings={},{}
 local function commit()
  if not current then return end
  current.index=#all.pages+1;current.text=table.concat(current.fragments);current.fragments=nil
  all.pages[#all.pages+1]=current;assert(#all.pages<=16,'Subpage count bound');current=nil
 end
 for index,line in ipairs(layout.lines)do
  assert(finite(line.bodyY)and finite(line.rubyReserve)and finite(line.bodyHeight)and line.bodyHeight>0,'Native row heights missing')
  local top,bottom=line.bodyY-line.rubyReserve,line.bodyY+line.bodyHeight
  assert(bottom>top and line.width<=layout.width+.00001,'Invalid native row bounds')
  if bottom-top>available+.00001 then return nil,{reason='complete_native_row_exceeds_page_content_height',line=index,rowHeight=bottom-top,contentBudget=available}end
  if current and(bottom-current.globalTop>available+.00001 or #current.lines>=maxRows)then commit()end
  if not current then current={globalTop=top,contentHeight=0,firstLine=index,lastLine=index,lines={},units={},readingCount=0,fragments={}}end
  local pg=#all.pages+1;local localLine=copy(line);localLine.globalLine=index;localLine.page=pg;localLine.bodyY=line.bodyY-current.globalTop
  localLine.y=localLine.bodyY;localLine.units={};current.lines[#current.lines+1]=localLine
  assert(line.firstByte==previousByte+1 and layout.source.text:sub(line.firstByte,line.lastByte)==line.text,'Page row UTF8 byte continuity failed')
  previousByte=line.lastByte;joined[#joined+1]=line.text;current.fragments[#current.fragments+1]=line.text
  current.firstByte=current.firstByte or line.firstByte;current.lastByte=line.lastByte;current.lastLine=index;current.contentHeight=bottom-current.globalTop
  for _,original in ipairs(line.units)do
   assert(not seenUnits[original.id],'Repeated native unit');seenUnits[original.id]=true
   local u=copy(original);u.page=pg;u.globalBodyY=u.bodyY;u.bodyY=u.bodyY-current.globalTop
   if u.reading then
    assert(not seenReadings[u.segment]and layout.source.segments[u.segment].reading==u.reading,'Repeated/changed reading');seenReadings[u.segment]=true
    u.globalRubyY=u.rubyY;u.rubyY=u.rubyY-current.globalTop;current.readingCount=current.readingCount+1
    assert(u.rubyY>=-.00001 and u.rubyY+u.rubyHeight<=u.bodyY-.99999,'Ruby lane not retained')
    all.runs[#all.runs+1]={segment=u.segment,text=u.text,reading=u.reading,page=pg,line=index,lane=1,x=u.rubyX,y=u.rubyY,
     width=u.rubyWidth,height=u.rubyHeight,ratio=.6,fontSize=10.8,completeSingleLineReading=true}
   end
   assert(u.bodyY>=0 and u.bodyY+u.baseHeight<=available+.00001,'Native body unit outside content area')
   current.units[#current.units+1]=u;localLine.units[#localLine.units+1]=u;all.units[#all.units+1]=u
  end
 end
 commit();assert(table.concat(joined)==layout.source.text and previousByte==#layout.source.text,'Paged source changed')
 assert(#all.units==#layout.units and #all.runs==30,'Paged source/ruby count changed')
 local rebuilt={};local runs,maxContentHeight=0,0
 for _,page in ipairs(all.pages)do
  rebuilt[#rebuilt+1]=page.text;runs=runs+page.readingCount
  maxContentHeight=math.max(maxContentHeight,page.contentHeight)
 end
 -- Anchor the controls below the tallest subpage, away from the
 -- native scroll fade, while keeping their position fixed during turns.
 local footerY=maxContentHeight+gap
 all.height=footerY+footer
 assert(all.height<=height+.00001,'Page exceeds actual available height')
 for _,page in ipairs(all.pages)do
  page.height=all.height;page.footerY=footerY
  page.unusedContentHeight=maxContentHeight-page.contentHeight
 end
 assert(table.concat(rebuilt)==layout.source.text and runs==30,'Page concatenation/30 readings failed')
 all.pageCount=#all.pages;all.allPagesReassembleExactSource=true;all.omittedReadings=0;all.repeatedReadings=0
 all.pagePolicy='Whole native-measured inline rows only; no annotated segment or kinsoku group is split; original wrap width/body18/ruby10.8 are retained.'
 return all
end
return M
