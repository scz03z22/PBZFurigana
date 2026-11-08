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
 const BindingProfile* profile{};
 bool bind(){
  ctor=nullptr;state=nullptr;number=nullptr;profile=nullptr;
  module=GetModuleHandleW(L"UE4SS.dll");if(!module)return false;
  // Reject unknown images before reading version-specific offsets. Resolve and
  // verify every expected export; no fallback to an unchecked ABI is allowed.
  const auto base=reinterpret_cast<const unsigned char*>(module);
  if(!readable(base,sizeof(IMAGE_DOS_HEADER)))return false;
  const auto dos=reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
  if(dos->e_magic!=IMAGE_DOS_SIGNATURE||dos->e_lfanew<0x40||dos->e_lfanew>0x2000)return false;
  const auto nt=reinterpret_cast<const IMAGE_NT_HEADERS64*>(base+dos->e_lfanew);
  if(!readable(nt,sizeof(*nt))||nt->Signature!=IMAGE_NT_SIGNATURE||
     nt->FileHeader.Machine!=IMAGE_FILE_MACHINE_AMD64||nt->OptionalHeader.Magic!=IMAGE_NT_OPTIONAL_HDR64_MAGIC)return false;
  for(const auto& candidate:kBindingProfiles){
   if(nt->OptionalHeader.SizeOfImage!=candidate.imageSize||nt->FileHeader.TimeDateStamp!=candidate.timestamp)continue;
   bool valid=true;
   for(size_t i=0;i<sizeof(kBindingExportNames)/sizeof(kBindingExportNames[0]);++i){
    const auto& s=candidate.signatures[i];
    if(s.rva>candidate.imageSize||32>candidate.imageSize-s.rva){valid=false;break;}
    const auto address=base+s.rva;
    if(reinterpret_cast<const void*>(GetProcAddress(module,kBindingExportNames[i]))!=address||
       !readable(address,32)||std::memcmp(address,s.bytes,32)){valid=false;break;}
   }
   if(valid){profile=&candidate;break;}
  }
  if(!profile)return false;
  ctor=reinterpret_cast<Ctor>(GetProcAddress(module,kCtorName));
  state=reinterpret_cast<GetState>(GetProcAddress(module,kStateName));
  number=reinterpret_cast<SetNumber>(GetProcAddress(module,kNumberName));
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
