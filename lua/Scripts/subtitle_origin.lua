-- Read-only subtitle coordinates. Keep the established FlowSubTitle path;
-- FlowDialog's extra SizeBox uses actual allocated geometry, never guessed padding.
local M={}
local function valid(o)return o and o:IsValid()end
local function kind(o)return valid(o)and o:GetClass():GetFName():ToString()or''end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<65536 end
function M.resolve(w,geometryService)
 local parent=w:GetParent();assert(kind(parent)=='VerticalBox','unsupported subtitle layout')
 local overlay=parent:GetParent()
 if kind(overlay)=='SizeBox'then
  overlay=overlay:GetParent();assert(kind(overlay)=='Overlay','unsupported subtitle SizeBox parent')
  if geometryService then
   local r=geometryService.relative(geometryService.read(w),geometryService.read(overlay))
   return overlay,r.x,r.y,'native_SizeBox_geometry'
  end
  local slate=assert(StaticFindObject('/Script/UMG.Default__SlateBlueprintLibrary'))
  local nativeMath=assert(StaticFindObject('/Script/Engine.Default__KismetMathLibrary'))
  local sourceGeometry=w:GetCachedGeometry();local overlayGeometry=overlay:GetCachedGeometry()
  local sourceSize=slate:GetLocalSize(sourceGeometry);local overlaySize=slate:GetLocalSize(overlayGeometry)
  assert(sourceSize.X>0 and sourceSize.Y>0 and overlaySize.X>0 and overlaySize.Y>0,'subtitle geometry not allocated')
  local function point(x,y)
   local absolute=slate:LocalToAbsolute(sourceGeometry,nativeMath:MakeVector2D(x,y))
   local localPoint=slate:AbsoluteToLocal(overlayGeometry,absolute)
   assert(finite(localPoint.X)and finite(localPoint.Y),'nonfinite subtitle geometry');return localPoint
  end
  local p=point(0,0);local x=point(1,0);local y=point(0,1)
  assert(math.abs(x.X-p.X-1)<.002 and math.abs(x.Y-p.Y)<.002 and math.abs(y.X-p.X)<.002 and math.abs(y.Y-p.Y-1)<.002,'unsupported relative subtitle transform')
  return overlay,p.X,p.Y,'allocated_SizeBox_geometry'
 end
 assert(kind(overlay)=='Overlay','unsupported subtitle overlay')
 local padding=parent.Slot.Padding;local x=padding.Left;local y=padding.Top
 for i=0,parent:GetChildrenCount()-1 do
  local child=parent:GetChildAt(i)
  if child:GetVisibility()~=1 then
   local slot=child.Slot;local p=slot.Padding;local size=child:GetDesiredSize()
   if child:GetFullName()==w:GetFullName()then
    local available=parent:GetDesiredSize().X-p.Left-p.Right;local align=slot.HorizontalAlignment
    return overlay,x+p.Left+(align==2 and(available-size.X)/2 or align==3 and(available-size.X)or 0),y+p.Top,'legacy_VerticalBox_Overlay'
   end
   y=y+p.Top+size.Y+p.Bottom
  end
 end
 error('subtitle not found in parent')
end
return M
