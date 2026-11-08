"""Compile review sources only. Does not install or load the mod."""
from pathlib import Path
import argparse,os,shutil,subprocess
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--config-only',action='store_true');parser.add_argument('--toolchain-root',type=Path);args=parser.parse_args()
env=os.environ.copy();cl=shutil.which('cl.exe');out=ROOT/'build';out.mkdir(exist_ok=True)
if args.toolchain_root:
    tree=args.toolchain_root.resolve();vc=sorted((tree/'VC/Tools/MSVC').iterdir())[-1];sdk=tree/'Windows Kits/10';version=sorted((sdk/'Include').iterdir())[-1].name
    compiler=vc/'bin/Hostx64/x64';cl=str(compiler/'cl.exe');env['PATH']=str(compiler)+os.pathsep+env.get('PATH','')
    env['INCLUDE']=';'.join(str(p)for p in[vc/'include',*[sdk/'Include'/version/x for x in('ucrt','shared','um')]])
    env['LIB']=';'.join(str(p)for p in[vc/'lib/x64',*[sdk/'Lib'/version/x/'x64'for x in('ucrt','um')]])
windows=Path(os.environ.get('SystemRoot','C:/Windows'));csc=windows/'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if not csc.is_file():csc=windows/'Microsoft.NET/Framework/v4.0.30319/csc.exe'
assert csc.is_file(),'.NET Framework 4.x compiler not found'
config=out/'configurator';config.mkdir(exist_ok=True)
subprocess.run([str(csc),'/nologo','/target:winexe','/platform:anycpu','/optimize+','/warnaserror+','/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/win32manifest:'+str(ROOT/'configurator/app.manifest'),'/out:'+str(config/'PBZFuriganaConfig.exe'),str(ROOT/'configurator/PBZFuriganaConfigurator.cs')],check=True)
if args.config_only:raise SystemExit(0)
assert cl,'Use an x64 Native Tools Command Prompt, or pass --toolchain-root'
def run(folder,*flags):
    folder.mkdir(parents=True,exist_ok=True);subprocess.run([cl,'/nologo',*map(str,flags)],cwd=folder,env=env,check=True)
geo=ROOT/'native/geometry_bridge';geometry=out/'geometry'
for source,dll,libs in [('geometry_v2.cpp','pbz_geometry_v2r1.dll',['kernel32.lib']),('input.cpp','pbz_hotkeys_v1.dll',['kernel32.lib','user32.lib'])]:
    run(geometry,'/W4','/O2','/MT','/std:c++17','/utf-8',geo/source,'/LD','/Fe:'+str(geometry/dll),'/Fo:'+str(geometry/(Path(source).stem+'.obj')),*libs,'/link','/DYNAMICBASE','/NXCOMPAT')
vendor=ROOT/'vendor/minhook';objects=[]
for source in('buffer.c','hook.c','trampoline.c','hde/hde64.c'):
    obj=out/'vendor'/(Path(source).stem+'.obj');run(out/'vendor','/O2','/MT','/c',vendor/'src'/source,'/Fo:'+str(obj));objects.append(obj)
for domain,source,dll in[('loading','loading.cpp','pbz_loading_v1.dll'),('video','video.cpp','pbz_video_v1.dll')]:
    folder=out/domain;run(folder,'/W4','/WX','/O2','/MT','/EHsc','/std:c++17','/utf-8','/I'+str(vendor/'include'),'/I'+str(geo),ROOT/('native/'+domain+'_bridge')/source,*objects,'/LD','/Fe:'+str(folder/dll),'/link','/DYNAMICBASE','/NXCOMPAT')
print('Built configuration application and all four native DLLs; nothing installed.')
