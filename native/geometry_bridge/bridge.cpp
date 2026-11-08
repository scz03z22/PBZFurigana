#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include "bindings.h"
using Ctor=void*(__fastcall*)(void*,void*);
using GetState=void*(__fastcall*)(const void*);
using SetNumber=void(__fastcall*)(const void*,double);
static bool readable(const void* p,size_t n){
 MEMORY_BASIC_INFORMATION m{};
 return p&&VirtualQuery(p,&m,sizeof(m))==sizeof(m)&&m.State==MEM_COMMIT&&!(m.Protect&(PAGE_GUARD|PAGE_NOACCESS))&&
 static_cast<const char*>(p)+n<=static_cast<const char*>(m.BaseAddress)+m.RegionSize;
}
struct LuaAPI {
 HMODULE module{};Ctor ctor{};GetState state{};SetNumber number{};
 bool bind(){
  module=GetModuleHandleW(L"UE4SS.dll");if(!module)return false;
  ctor=reinterpret_cast<Ctor>(GetProcAddress(module,kCtorName));
  state=reinterpret_cast<GetState>(GetProcAddress(module,kStateName));
  number=reinterpret_cast<SetNumber>(GetProcAddress(module,kNumberName));
  for(const auto& s:kSignatures){
   auto p=reinterpret_cast<const unsigned char*>(module)+s.rva;
   if(!readable(p,32)||std::memcmp(p,s.bytes,32))return false;
  }
  return ctor&&state&&number;
 }
};
extern "C" __declspec(dllexport) int luaopen_pbz_geometry_ping(void* L){
 LuaAPI api;if(!api.bind()||!L)return 0;
 alignas(16) unsigned char wrapper[256]{};
 // Exported constructor from this exact DLL writes through offset0x98.
 // No engine Lua internals or separately compiled Lua runtime are used.
 api.ctor(wrapper,L);if(api.state(wrapper)!=L)return 0;
 api.number(wrapper,123.25);
 api.number(wrapper,static_cast<double>(GetCurrentProcessId()));
 api.number(wrapper,static_cast<double>(GetCurrentThreadId()));
 return 3;
}
