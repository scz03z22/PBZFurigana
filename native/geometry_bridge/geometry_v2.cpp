#include "bridge.cpp"
#include <cmath>
#include <algorithm>
using Integer=long long(__fastcall*)(const void*,int);
using Event=void(__fastcall*)(void*,void*,void*);
using U16=const unsigned short*(__fastcall*)(void*);
using I32=const int*(__fastcall*)(void*);
using U32=const unsigned int*(__fastcall*)(void*);
struct Field {void* object{};int offset{},size{};};
struct Function {void* object{};unsigned short size{};};
struct Service {
 DWORD pid{},tid{};Event event{};void* slate{};Function f[4]{};Field p[7]{};bool initialized{};
} static service;
struct Vec {double x,y;};
struct Buffer {
 alignas(16) unsigned char bytes[544]{};
 int size{};
 void reset(int n){size=n;std::memset(bytes,0,sizeof(bytes));std::memset(bytes+n,0xA5,32);}
 bool intact()const{for(int i=0;i<32;++i)if(bytes[size+i]!=0xA5)return false;return true;}
 void put(const Field& p,const void* value){std::memcpy(bytes+p.offset,value,p.size);}
 template<class T>T value(const Field& p)const{T out{};std::memcpy(&out,bytes+p.offset,sizeof(out));return out;}
};
static Integer integer(HMODULE module){return reinterpret_cast<Integer>(GetProcAddress(module,"?get_integer@Lua@LuaMadeSimple@RC@@QEBA_JH@Z"));}
static bool init_service(LuaAPI& api,void* wrapper){
 const auto get=integer(api.module);
 const auto parms=reinterpret_cast<U16>(GetProcAddress(api.module,"?GetParmsSize@UFunction@Unreal@RC@@QEBAAEBGXZ"));
 const auto offset=reinterpret_cast<I32>(GetProcAddress(api.module,"?GetOffset_Internal@FProperty@Unreal@RC@@QEBAAEBHXZ"));
 const auto size=reinterpret_cast<I32>(GetProcAddress(api.module,"?GetElementSize@FProperty@Unreal@RC@@QEBAAEBHXZ"));
 const auto flags=reinterpret_cast<U32>(GetProcAddress(api.module,"?GetFunctionFlags@UFunction@Unreal@RC@@QEBAAEBIXZ"));
 if(!get||!parms||!offset||!size||!flags)return false;
 // LuaMadeSimple::get_integer removes the selected argument from the stack.
 // Read right-to-left so removing one never shifts the remaining indexes.
 long long args[12]{};for(int i=11;i>=0;--i)args[i]=get(wrapper,i+1);
 Service s{};s.pid=GetCurrentProcessId();s.tid=GetCurrentThreadId();
 s.event=reinterpret_cast<Event>(GetProcAddress(api.module,"?ProcessEvent@UObject@Unreal@RC@@QEAAXPEAVUFunction@23@PEAX@Z"));
 s.slate=reinterpret_cast<void*>(args[4]);
 if(!s.event||!readable(s.slate,0x28))return false;
 for(int i=0;i<4;++i){
  s.f[i].object=reinterpret_cast<void*>(args[i]);
  if(!readable(s.f[i].object,0x80))return false;
  s.f[i].size=*parms(s.f[i].object);
  if(!s.f[i].size||s.f[i].size>512||!(*flags(s.f[i].object)&0x400))return false;
 }
 for(int i=0;i<7;++i){
  auto& p=s.p[i];p.object=reinterpret_cast<void*>(args[i+5]);
  if(!readable(p.object,0x60))return false;
  p.offset=*offset(p.object);p.size=*size(p.object);
  if(p.offset<0||p.size<=0||p.offset+p.size>512)return false;
 }
 const int geometry=s.p[0].size;
 if(geometry>192||s.p[1].size!=geometry||s.p[2].size!=geometry||s.p[4].size!=geometry)return false;
 if(s.p[3].size!=sizeof(Vec)||s.p[5].size!=sizeof(Vec)||s.p[6].size!=sizeof(Vec))return false;
 const int owners[7]={0,1,2,2,3,3,3};
 for(int i=0;i<7;++i)if(s.p[i].offset+s.p[i].size>s.f[owners[i]].size)return false;
 if(s.p[0].offset||s.p[1].offset||s.p[2].offset||s.p[4].offset)return false;
 if(s.p[3].offset<geometry||s.p[5].offset<geometry||s.p[6].offset<s.p[5].offset+sizeof(Vec))return false;
 s.initialized=true;
 if(service.initialized){
  if(service.pid!=s.pid||service.tid!=s.tid||service.slate!=s.slate)return false;
  for(int i=0;i<4;++i)if(service.f[i].object!=s.f[i].object||service.f[i].size!=s.f[i].size)return false;
 }
 service=s;return true;
}
static bool invoke(int index,void* target,Buffer& p){
 if(!readable(target,0x28)||GetCurrentProcessId()!=service.pid||GetCurrentThreadId()!=service.tid)return false;
 __try{service.event(target,service.f[index].object,p.bytes);}
 __except(EXCEPTION_EXECUTE_HANDLER){return false;}
 return p.intact();
}
extern "C" __declspec(dllexport) int luaopen_pbz_geometry_init_v2(void* L){
 LuaAPI api;if(!L||!api.bind())return 0;
 alignas(16) unsigned char wrapper[256]{};api.ctor(wrapper,L);
 if(api.state(wrapper)!=L||!init_service(api,wrapper))return 0;
 api.number(wrapper,1);
 api.number(wrapper,service.p[0].size);api.number(wrapper,service.f[0].size);
 api.number(wrapper,service.f[2].size);api.number(wrapper,service.f[3].size);
 return 5;
}
static bool geometry(void* widget,double* result){
 Buffer source,size,point;
 bool found=false;Vec dimensions{};
 for(int index=0;index<2;++index){
  source.reset(service.f[index].size);
  if(!invoke(index,widget,source))return false;
  size.reset(service.f[2].size);size.put(service.p[2],source.bytes+service.p[index].offset);
  if(!invoke(2,service.slate,size))return false;
  dimensions=size.value<Vec>(service.p[3]);
  if(std::isfinite(dimensions.x)&&std::isfinite(dimensions.y)&&dimensions.x>0&&dimensions.y>0){found=true;break;}
 }
 if(!found||dimensions.x>65536||dimensions.y>65536)return false;
 Vec coordinates[3]={{0,0},{1,0},{0,1}},points[3]{};
 for(int i=0;i<3;++i){
  point.reset(service.f[3].size);point.put(service.p[4],source.bytes);
  point.put(service.p[5],&coordinates[i]);
  if(!invoke(3,service.slate,point))return false;
  points[i]=point.value<Vec>(service.p[6]);
  if(!std::isfinite(points[i].x)||!std::isfinite(points[i].y))return false;
 }
 result[0]=dimensions.x;result[1]=dimensions.y;result[2]=points[0].x;result[3]=points[0].y;
 result[4]=points[1].x-points[0].x;result[5]=points[1].y-points[0].y;
 result[6]=points[2].x-points[0].x;result[7]=points[2].y-points[0].y;
 return true;
}
extern "C" __declspec(dllexport) int luaopen_pbz_geometry_read_v2(void* L){
 LuaAPI api;if(!L||!service.initialized||!api.bind())return 0;
 const auto get=integer(api.module);if(!get)return 0;
 alignas(16) unsigned char wrapper[256]{};api.ctor(wrapper,L);if(api.state(wrapper)!=L)return 0;
 auto widget=reinterpret_cast<void*>(get(wrapper,1));double out[8]{};
 if(!geometry(widget,out))return 0;
 for(double v:out)api.number(wrapper,v);
 return 8;
}
