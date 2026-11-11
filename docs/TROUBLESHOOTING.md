# Troubleshooting

## The picker works but an iPhone game is the wrong size

Update to a build containing the iPad guest-canvas correction. It preserves the complete game layout and fits it into the physical display; black margins on a tall phone are expected. The corrected phone build passed visually inspected startup-capture checks for all nine games. Touch and rotation checks remain pending. See [issue 001](issues/001-iphone-scaling.md) for validation status.

## A works in GoatUp but the goat will not move

Choose **Controls → GoatUp → Gamepad**, then relaunch GoatUp. The stick needs the game's Control Type C. See [CONTROLLERS.md](CONTROLLERS.md). GoatUp 2 separately requires its original tilt mode selected inside the game.

## A tile is disabled

That game's helper has not been built. Import its supported IPA, build it (or build the full collection), and package again. A one-game test build intentionally leaves the other tiles disabled.

## Unsupported or encrypted IPA

The input binary does not match `games.json`. Use the supported decrypted original version. Renaming the file, changing its hash in the manifest or installing an old 32-bit IPA directly on a modern phone does not fix compatibility.

## A game halts with AOT missing location / UndefinedInstruction

Record the exact game, platform, build revision and the few lines around the missing location. The static compiler has no interpreter fallback. A valid new branch may need analysis and translation; it should not be hidden by ignoring an arbitrary instruction.

## Xcode cannot launch on the device

Check trust, Developer Mode, signing team/bundle ID and that the device is unlocked. A successfully installed app can still be refused launch while locked. Do not delete the existing app to fix a signing/launch problem without backing up its data.

## Building depends on missing tools or Rust sources

Check [BUILDING.md](BUILDING.md). Full Xcode is required, not only Command Line Tools, for the mobile SDK and asset tools. The mobile build-std recipe needs `rust-src` for the selected compiler. Confirm `xcode-select -p`, `rustc --version`, `cargo --version` and `xcodebuild -version` when reporting a build failure.

## Saves disappeared / moving to another device

The Mac app writes outside its bundle, in the folder listed in the README. iOS data belongs to the installed app's container and bundle identifier. There is no automatic cloud sync. Copying a signed app does not copy its player saves; deleting an iOS app can remove them.

## Audio or later-level rendering looks wrong

These areas are not fully validated. Supply a concise reproduction and platform details. Do not report this derivative project's bugs to Llamasoft or upstream touchHLE.
