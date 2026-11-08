PBZFurigana 0.24.4-preview - source

UE4SS compatibility update based on 0.24.3-preview.
Mod: https://www.nexusmods.com/phantombladezero/mods/647
Release archive SHA-256: 2a2228e7919cfbd97b455d32b913ad74a4a8a45e4fc27143c26b414202fa1f2c
See README.md and COMPATIBILITY.md for the tested builds and build instructions.

Contents
- configurator/: exact C# Windows Forms source and manifest for the Japanese scope selector.
- native/geometry_bridge/: geometry getters and F6/PageUp/PageDown key sampling.
- native/loading_bridge/: version-gated loading/startup text rendering.
- native/video_bridge/: version-gated native subtitle rendering and name selection.
- vendor/minhook/: the actual modified MinHook 1.3.4 source used by the release; see its license and derivative manifest.
- lua/Scripts/: the exact Lua files distributed in the release, including compact reading tables.
- SOURCE_MANIFEST.json: each copied source file's relative origin and SHA-256.
- RELEASE_FILES_SHA256.json: hashes of the original released package files.

No game executables, UE4SS binaries, save files, personal settings, account information,
email records, compiler installation, or prebuilt mod executables are included.
The game and UE4SS build guards are intentionally retained in the source.
The script below builds files under build/ and does not install or load them into a game.

Build requirements
Windows x64, Python 3, .NET Framework 4.x compiler, MSVC C/C++ Build Tools,
and the Windows SDK. The release used MSVC 14.44.35207 and Windows SDK 10.0.22621.0.
The native projects use C++17, /O2, /MT and /utf-8. No QA macros are enabled.

Build
From an x64 Native Tools Command Prompt for Visual Studio:
  python build.py
Alternatively, for an extracted MSVC + Windows SDK tree:
  python build.py --toolchain-root "PATH_TO_TOOLCHAIN_TREE"
The tree must contain VC/Tools/MSVC/<version> and Windows Kits/10/Include,Lib.
To build only the configuration application:
  python build.py --config-only

Outputs
build/configurator/PBZFuriganaConfig.exe
build/geometry/pbz_geometry_v2r1.dll
build/geometry/pbz_hotkeys_v1.dll
build/loading/pbz_loading_v1.dll
build/video/pbz_video_v1.dll

C# compilation references System.Windows.Forms.dll and System.Drawing.dll and uses
the bundled app.manifest. Native DLLs compile only the bundled implementation and
MinHook sources. This source snapshot is intentionally version bound: it is not a
promise of compatibility with other game or UE4SS versions.
Build timestamps, .NET module IDs, paths and compiler versions can change binary
hashes; byte-for-byte reproducibility of the release is not claimed.

Third-party licensing
MinHook's original license is preserved under vendor/minhook/LICENSE.txt.
The author has approved publication of this source snapshot for review.
No additional reuse license is granted for the author's own code. Third-party
components remain subject to their included licenses.
