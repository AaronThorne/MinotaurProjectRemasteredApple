# 001 — iPhone game canvas does not fit the screen

Status: **startup cropping correction verified; touch/rotation validation pending**. Reported 10 November 2026.

Environment: iPhone 17 Pro Max, iOS 27.2. The native picker is usable; the games themselves are incorrectly scaled. Do not label the iPhone port ready based on the picker alone.

## Reproduction / next verification

1. Build and sign the universal app using a unique bundle identifier.
2. Launch on the physical phone in portrait, then start a portrait game such as Gridrunner or Super Ox Wars.
3. Compare the guest renderbuffer size, viewport and output drawable dimensions. Repeat with a landscape game such as Minotron or Deflex, including a device rotation and a return to the picker.
4. Confirm that touch coordinates match visible buttons/objects, not just that the picture fills more space.
5. Recheck iPad output before shipping the correction.

## Relevant code

- `ios/App/ES2Presenter.m`: source renderbuffer copy, output viewport and texture-coordinate rotation.
- `ios/App/main.m`: phone detection, safe areas and return-to-picker button.
- `patches/runtime-ios.patch`: native mobile presentation, `window.rs` viewport calculation, guest screen sizes and the `mpr_run_game` bridge.

## Cause and correction

A physical-phone capture reproduced the upper-left crop in Gridrunner. The bridge selected the old 320×480 iPhone guest screen on a phone, while the game retained its fixed iPad-sized layer. The fullscreen-layer presenter correctly cropped that larger layer to the reported guest screen, discarding the right and bottom of the game before scaling it for the host.

The bridge now keeps the original iPad guest canvas on both phones and tablets. Host-device detection still controls the native picker; the runtime viewport fits the complete guest canvas into the actual drawable and preserves its aspect ratio. Black margins on a tall phone are expected. The mobile runtime and universal app rebuilt successfully, and the update was installed on the phone. After unlocking, a fresh timed session captured all nine games and returned each to the picker. Visual review confirmed distinct game images fitted inside the phone drawable. Gridrunner now shows the full score line, play area and bottom labels in a 440×587 viewport centred in the 440×956 drawable. The normal picker was relaunched without test flags. This verifies initial canvas presentation; player touch/rotation checks and later gameplay remain pending.

Development-only environment flags available in the app:

- `MPR_CAPTURE_PICKER=1`: picker captures in app Documents.
- `MPR_CAPTURE_FRAME=1`: captures a presented GPU frame per game.
- `MPR_AUTOSTART=Gridrunner`: opens one game.
- `MPR_TEST_SEQUENCE=Gridrunner,SuperOxWars`: runs a sequence.
- `MPR_SMOKE_SECONDS=20`: returns to the picker after each timed run.

Always relaunch without the test variables before handing the app to a player. The timed run setting otherwise interrupts normal play. Do not commit device IDs, user logs or captures containing personal information.
