-- Opaque FGeometry has no reflected fields and becomes {} in this Lua build.
-- The native bridge copies its actual parameter bytes through getter UFunctions.
local M={}
function M.new(root)
 if _G.PBZGeometryServiceV2 then return _G.PBZGeometryServiceV2 end
 local function functionAndFields(path,names)
  local f=StaticFindObject(path);assert(f and f:IsValid()and f:GetFullName()=='Function '..path,'Geometry function identity differs')
  local fields={};local count=0
  f:ForEachProperty(function(p)
   count=count+1;local name=p:GetFName():ToString()
   assert(names[name]and not fields[name]and p:GetFullName():match('^StructProperty '),'Geometry schema differs')
   fields[name]=p:GetAddress()
  end)
  local expected=0;for name in pairs(names)do expected=expected+1;assert(fields[name],'Missing geometry field')end
  assert(count==expected);return f:GetAddress(),fields
 end
 local cache,cf=functionAndFields('/Script/UMG.Widget:GetCachedGeometry',{ReturnValue=true})
 local paint,pf=functionAndFields('/Script/UMG.Widget:GetPaintSpaceGeometry',{ReturnValue=true})
 local size,sf=functionAndFields('/Script/UMG.SlateBlueprintLibrary:GetLocalSize',{Geometry=true,ReturnValue=true})
 local point,xf=functionAndFields('/Script/UMG.SlateBlueprintLibrary:LocalToAbsolute',{Geometry=true,LocalCoordinate=true,ReturnValue=true})
 local cdo=StaticFindObject('/Script/UMG.Default__SlateBlueprintLibrary')
 local widgetClass=StaticFindObject('/Script/UMG.Widget')
 assert(cdo and cdo:IsValid()and widgetClass and widgetClass:IsValid())
 local dll=root..'native/geometry_bridge/build/pbz_geometry_v2r1.dll'
 local initialize,err=package.loadlib(dll,'luaopen_pbz_geometry_init_v2');assert(initialize,err)
 local read,err=package.loadlib(dll,'luaopen_pbz_geometry_read_v2');assert(read,err)
 local ok,geometryBytes,cacheBytes,sizeBytes,pointBytes=initialize(cache,paint,size,point,cdo:GetAddress(),
  cf.ReturnValue,pf.ReturnValue,sf.Geometry,sf.ReturnValue,xf.Geometry,xf.LocalCoordinate,xf.ReturnValue)
 assert(ok==1,'Native geometry binding rejected')
 local service={schema={geometryBytes=geometryBytes,cacheBytes=cacheBytes,sizeBytes=sizeBytes,pointBytes=pointBytes}}
 function service.read(w)
  assert(w and w:IsValid()and w:IsA(widgetClass),'Expected live native UWidget')
  local width,height,x,y,xx,xy,yx,yy=read(w:GetAddress())
  assert(width and height and width>0 and height>0,'Native widget geometry is not allocated')
  return{width=width,height=height,x=x,y=y,xx=xx,xy=xy,yx=yx,yy=yy}
 end
 function service.relative(source,target)
  local determinant=target.xx*target.yy-target.xy*target.yx
  assert(math.abs(determinant)>.000001,'Degenerate parent transform')
  local function vector(x,y)return(target.yy*x-target.yx*y)/determinant,(-target.xy*x+target.xx*y)/determinant end
  local x,y=vector(source.x-target.x,source.y-target.y)
  local xx,xy=vector(source.xx,source.xy);local yx,yy=vector(source.yx,source.yy)
  assert(math.abs(xx-1)<.002 and math.abs(xy)<.002 and math.abs(yx)<.002 and math.abs(yy-1)<.002,'Relative source transform unsupported')
  return{x=x,y=y,width=source.width,height=source.height}
 end
 _G.PBZGeometryServiceV2=service;return service
end
return M
