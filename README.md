# PBZFurigana — 0.24.4-preview source

Source snapshot for the Japanese furigana Mod for **Phantom Blade Zero**.
Published by the author for Nexus Mods security review. This repository presents
the source as browsable version-controlled files, not only a downloadable archive.

- Mod page: https://www.nexusmods.com/phantombladezero/mods/647
- Current release: **0.24.4-preview**, UE4SS compatibility update.
- Release archive SHA-256: `2a2228e7919cfbd97b455d32b913ad74a4a8a45e4fc27143c26b414202fa1f2c`
- Previous manually reviewed release: **0.24.3-preview**, Nexus file **2450**.

This update changes the shared native UE4SS binding in `bindings.h` and
`bridge.cpp`, and rebuilds the four native DLLs. The Lua scripts, reading tables
and Japanese configuration application are unchanged from 0.24.3-preview.
`SOURCE_MANIFEST.json` records current source hashes; `RELEASE_FILES_SHA256.json`
identifies all 59 distributed files. See `COMPATIBILITY.md` for exact tested
dependency builds, guard behavior and the limits of verification.

## Components

| Directory | Purpose |
| --- | --- |
| `configurator/` | C# Windows Forms scope selector, Japanese UI, native minimize button, INI settings |
| `native/geometry_bridge/` | Game UI geometry access and F6 / Page Up / Page Down key sampling |
| `native/loading_bridge/` | Version-gated loading/startup text rendering |
| `native/video_bridge/` | Version-gated native subtitle rendering and character-name scope |
| `vendor/minhook/` | Actual modified MinHook 1.3.4 source used by the release, license and derivative manifest |
| `lua/Scripts/` | Distributed Lua rendering, scope logic and compact reading tables |

No game executable, UE4SS binary, save, personal settings, account information,
email correspondence, compiler binaries or prebuilt Mod EXE/DLL is included.
Game-version and UE4SS compatibility guards are retained in the source.

## Build requirements

Use **64-bit Windows** with:

1. Python 3, available as `python` in the command prompt.
2. Visual Studio 2022 C++ Build Tools: the **Desktop development with C++**
   workload, including the MSVC x64/x86 compiler and a Windows SDK.
3. The .NET Framework 4.x C# compiler. The script looks for
   `%SystemRoot%/Microsoft.NET/Framework64/v4.0.30319/csc.exe`, then the
   corresponding `Framework` path. Windows Forms and System.Drawing are used.

The release toolchain was **MSVC 14.44.35207** with **Windows SDK 10.0.22621.0**.
Other toolchains can produce different binaries and are not claimed equivalent.
No NuGet packages or network downloads are required by `build.py`.

## Build all five compiled components

1. Clone this repository, or obtain its source tree through GitHub.
2. Open **x64 Native Tools Command Prompt for VS 2022**.
3. Change to the repository root (the directory containing `build.py`).
4. Run:

```bat
python build.py
```

Alternatively, an extracted MSVC/SDK toolchain can be supplied explicitly:

```bat
python build.py --toolchain-root "PATH_TO_TOOLCHAIN_TREE"
```

That directory must contain `VC/Tools/MSVC/<version>` and
`Windows Kits/10/Include/<version>`, `Windows Kits/10/Lib/<version>`.
Use a tree with only the intended compiler/SDK version: the script selects the
last sorted version directory.

For only the scope configuration application:

```bat
python build.py --config-only
```

### Outputs and corresponding release paths

| Build output | Path inside the release's `PBZFurigana` folder |
| --- | --- |
| `build/configurator/PBZFuriganaConfig.exe` | `PBZFuriganaConfig.exe` |
| `build/geometry/pbz_geometry_v2r1.dll` | `native/geometry_bridge/build/pbz_geometry_v2r1.dll` |
| `build/geometry/pbz_hotkeys_v1.dll` | `native/geometry_bridge/build/pbz_hotkeys_v1.dll` |
| `build/loading/pbz_loading_v1.dll` | `native/loading_bridge/build/pbz_loading_v1.dll` |
| `build/video/pbz_video_v1.dll` | `native/video_bridge/build/pbz_video_v1.dll` |

The distributed Lua files are under `lua/Scripts/` and are not compiled by this
script. The script only writes under `build/`; it does not install, inject or
load any output into a running game.

The C# application is compiled with its manifest and Framework references.
Native code uses C++17, `/O2`, `/MT`, `/utf-8`, `/DYNAMICBASE` and `/NXCOMPAT`;
MinHook C sources are compiled locally. Test/QA macros are not enabled.
See `build.py` for the exact command lines and link inputs.

## Verification

The original source snapshot rebuilt the configuration application and all four
native DLLs successfully. Its GUI self-test passed and native DLL export
interfaces matched the release. The configurator's self-test may be run in a
normal Windows desktop session:

```bat
build\configurator\PBZFuriganaConfig.exe --self-test build\self-test
```

The output directory receives isolated test settings and a
`configurator-self-test.txt` result. This does not modify game settings.

This is a version-bound source snapshot, not a compatibility promise for other
game or UE4SS versions. Byte-for-byte reproducibility is not claimed: compiler
versions, build timestamps, paths and .NET module IDs can change binary hashes.
Source publication and Nexus file approval are separate processes.

## Rights and third-party notices

This source is publicly viewable with the author's permission for review.
No additional reuse license is granted for the author's own code.
MinHook remains subject to `vendor/minhook/LICENSE.txt`; its modification record
is included in the same directory. Game and UE4SS components are not distributed
here and remain subject to their respective owners' terms.
