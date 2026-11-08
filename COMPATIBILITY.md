# UE4SS compatibility in 0.24.4-preview

This patch retains the features/readings of 0.24.3 and adds a second verified
UE4SS native binding profile. It does not remove the unsupported-build guard.

| Dependency | Internal Git revision | UE4SS.dll SHA-256 |
| --- | --- | --- |
| Existing test baseline | 1ceefac8 | e1fb9a7e1d868afef6a091c2012e711c3ec47f05d100ba37f9631a4f75f31df2 |
| [UE4SS for Phantom Blade Zero, Nexus #5](https://www.nexusmods.com/phantombladezero/mods/5), 1.0.3, file 1780 | cdbc0b66c | 60b6414257cfb02a2f76669f86497abc9b9ffe96265c6e4690dddd180e25f290 |

The package version and UE4SS's internal version are different identifiers.
Both tested DLLs print `v3.0.1 Beta #0`; that version string alone is insufficient
to determine binary compatibility. Other UE4SS builds remain unverified and
are rejected by the native bridge.

## Implementation

`LuaAPI::bind()` verifies x64 PE headers, exact image size and timestamp, nine
export names and addresses, and 32 code bytes per required export before
using version-specific ABI functions. Both profiles retain strict matching.
The four DLLs compile the shared binder from geometry_bridge/bridge.cpp.
No UE4SS binary or third-party dependency archive is redistributed here.

## Verification on 2026-11-09

- All four native DLLs compiled successfully with the documented toolchain.
- Six isolated tests passed: both actual dependency images accepted; a changed
  constructor instruction and altered PE timestamp rejected in each image.
  Images were mapped without initialization and no dependency export was run
  during these isolated checks.
- In-game with Nexus #5 1.0.3: startup, loading a save, F6 off/on, equipment
  names and long descriptions, book text, original book-page switching and
  scrolling displayed correctly in the sampled screens.
- In-game with baseline 1ceefac8: startup, loading a save, F6 off/on, and
  weapon-name filtering displayed correctly.
- Game test build: Steam 26367565; title version 302256-17280; Japanese text,
  1440p borderless display. Save files and user preferences were restored.

These are targeted compatibility checks, not a new complete playthrough or
verification of every scene/video/other-mod combination. Existing content and
layout limitations still apply. Video bridge initialization was observed;
independent video playback was not retested for this patch.
