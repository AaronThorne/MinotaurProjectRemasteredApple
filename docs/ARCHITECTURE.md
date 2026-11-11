# Architecture

This is a static CPU translation experiment on top of an old-iOS compatibility runtime. It is not a source recreation of the nine game engines.

1. The pinned Windows-derived runtime runs a short reference session on the development Mac. Its translation hook records code locations and words locally.
2. `audit-ipa.py` extracts the supported ARM32 slice and metadata. `seed-functions.py` adds function entries and validated ARM/Thumb switch targets.
3. `dump-ir.cpp` uses Dynarmic's offline frontend to describe one instruction at a time and follow reachable paths, including continuation after optional cache hints.
4. `generate-aot.py` emits C++ state-transform functions and a cached dispatcher. `aot/wrapper.cpp` connects this backend to touchHLE's CPU boundary.
5. The final Mac executables / mobile library use the compiled functions. They do not include a runtime instruction decoder or dynamic fallback. touchHLE still provides the guest frameworks, object runtime, drawing/audio behavior and old system interfaces.

## Layout

| Path | Purpose |
| --- | --- |
| `aot/`, `tools/` | CPU wrapper, generator, analysis and differential tools. |
| `macos/` | AppKit picker, Metal view, pixel title and game bootstrap/control selection. |
| `ios/App/` | UIKit picker, Metal background and native GLES presenter. |
| `patches/` | Exact Mac/mobile runtime changes and the SDL UIKit scene patch. |
| `scripts/` | Dependency setup, local asset import, clean staging, building and packaging. |
| `games.json`, `dependencies.json` | Supported game hashes and pinned public source revisions. |
| `runtime/`, `ios/runtime/` | Ignored dependency checkouts created by bootstrap. |
| `games/<id>/` | Ignored traces, analysis output, translations and compiled engines. |
| `local-assets/`, `build/`, `work/` | Ignored original inputs, app output and scratch data. |

Mac and mobile runtime checkouts are separate. The iPad/mobile CPU overlay restores Minotron's original touch instructions where the desktop controller fork patched them. The shared generator handles cache-prefetch hints and bounded jump-table recovery; unsupported instructions remain explicit failures.

The mobile app combines namespaced game translations into one CPU library. Its UI and compatibility code select the correct namespace for each launched game, and return to the native picker on exit. The Mac collection instead embeds separate game helpers in one outer application. Writable player data is outside the signed app bundle.

## Instruction checks

The checker uses a reference ARM engine only on the development Mac. Four deterministic input states are tested for each eligible location. Current comparisons include integer registers, extended-register bits, CPSR and memory writes. FPSCR exception/status flags are not fully compared. Trapping/unsupported operations are separately scoped by `prepare-checks.py`.

Passing instruction tests does not validate UIKit behavior, audio quality, viewport math, touch alignment or a whole game. Those need platform-specific runtime tests and player feedback.

## Guest canvas and host display

The mobile picker adapts to the physical phone or tablet. Games retain the original
iPad guest geometry used by the collection layouts and static translations. The
runtime fits that canvas into the SDL output drawable without changing its aspect
ratio; the same viewport also maps touch input back to guest coordinates. Choosing
an old iPhone guest size can crop a fixed iPad game layer before presentation, so
host phone detection must not select the guest screen size.
