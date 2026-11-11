# Source snapshot validation

Checked on 10 November 2026, on an Apple Silicon development Mac.

| Check | Result |
| --- | --- |
| Public dependency setup | Pinned Mac and iOS runtime checkouts fetched; both runtime patches and the SDL scene patch applied. A second bootstrap pass succeeded without reapplying changes. |
| Real upstream asset import | All nine original game binaries recovered from the full Windows v1.2 ZIP and matched the manifest hashes. |
| Import unit tests | Four checks passed: bundle-ID identification/archive preservation, wrong-version rejection, embedded archive recovery, and path traversal rejection. Synthetic fixtures contain no game code. |
| AppKit picker compilation | Passed from this new source checkout. |
| GoatUp control helper | First-profile setup, both control modes, preserving non-control data and rejecting malformed save data passed. |
| Resource staging | Clean Mac/mobile runtime resources, icons and game-data inputs generated. No player save folder was read. |
| Xcode project generation | Passed for the universal device project. This does not constitute a fresh full mobile build or device test. |
| Fresh Mac source build | `python3 scripts/build.py macos --game Gridrunner` completed, including new reference build, tracing, offline lift, C++ compilation, native runtime link and app packaging. |
| Fresh Gridrunner execution | The newly built static engine ran for 12 seconds, produced three render captures, showed its title/demo screen and exited normally. No AOT-missing or panic error appeared. The captured render was inspected. |
| Packaged signature | The standalone one-game test app and nested helper passed strict deep verification. |
| Source hygiene | Python syntax, local documentation links, manifests and tracked-file checks passed. Original games, build products, signing material and personal checkout/device data are absent from Git. |

The complete nine-game cold build and a fresh mobile static-library build were **not** rerun as part of preparing this source snapshot. The device and development-build checks below describe separate runs using the local development builds.

The Gridrunner lift emitted 112,609 static functions. Its analysis coverage report retains unsupported IR occurrences as explicit failures; the startup observation did not reach them. A startup observation is not an instruction-level proof or full-game test. Successful source checks alone do not establish correct iPhone presentation.

## iPhone canvas correction

The existing local mobile experiment rebuilt all nine static CPU translations, the
mobile runtime and the signed universal app after the canvas correction. The
updated runtime patch also passed an application check against the pinned upstream
source. This is a rebuild using archived translation inputs, not a cold run of the
portable source pipeline. The app installed on the physical iPhone. After unlocking, all nine timed startup
runs produced fresh GPU captures and returned to the picker without a missing-code
or panic error. All nine captures were visually inspected and showed the complete
game canvas fitted into the output. Gridrunner used a 440×587 viewport at (0,184)
inside the 440×956 drawable, preserving its 768×1024 guest canvas. The app was then
relaunched normally without test flags. Physical touch/rotation, later-level and
long-session checks remain pending.

## Development build checks

- The maintainer reports stable playtesting on Apple Silicon Mac, iPad and iPhone.
- On Mac, replayed controller input verified Start-to-resume in Minotaur Rescue after pausing with A. The Minotron: 2112 and Super Ox Wars integer division repairs passed 8,288 arithmetic calls through the compiled CPU wrapper, including the logged crash states.
- On the physical iPad Pro, the in-game Games button passed hit testing and returned to the picker from all nine games. A separate device run verified four distinct sprites on launch and after three game returns.
