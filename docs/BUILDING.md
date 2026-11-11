# Building from source

## Requirements

- An Apple Silicon Mac. Intel and Rosetta builds are not provided.
- Full Xcode, selected as the active developer directory, with its initial setup completed. The development build used Xcode 27.2.
- Python 3.9+, Git, Swift/Clang from Xcode, CMake, Boost, LLVM and Rust. The development build used Rust 1.99.1.
- For iPhone/iPad: XcodeGen, Rust source components, an Apple signing team and a unique bundle identifier. A device must be trusted, in Developer Mode and unlocked for launch.
- Supported game assets imported locally as described in [ASSETS.md](ASSETS.md).

Homebrew is one way to install the command-line dependencies:

```sh
brew install cmake boost llvm rust xcodegen
```

If using rustup instead of Homebrew Rust, install the tested toolchain and its source component:

```sh
rustup toolchain install 1.99.1 --component rust-src
rustup override set 1.99.1
```

The mobile build uses `-Zbuild-std=std,panic_abort` with `RUSTC_BOOTSTRAP=1`, matching the working experimental recipe. It needs the Rust library sources in the selected toolchain. A missing `rust/library/Cargo.lock` or `rust-src` error means those sources are absent; install `rust-src` with rustup or provide the source component for your Homebrew toolchain. This is an experimental cross-build, not an App Store release recipe.

Allow substantial time and free storage. The first build fetches dependencies, records short reference runs and compiles thousands of generated C++ units. Temporary libraries and build trees can consume many gigabytes. Analysis traces and generated code stay ignored by Git.

## 1. Fetch the runtime

From a checkout of this repository:

```sh
python3 scripts/bootstrap.py
```

For mobile work, prepare both runtime variants and the patched SDL crate:

```sh
python3 scripts/bootstrap.py --ios
```

The exact public Git revisions are in `dependencies.json`. Patches are checked before application. The setup script does not install games or publish anything.

## 2. Import the games

Use the full v1.2 ZIP obtained from the [original project's releases](https://github.com/jedeyesniv-art/MinotaurProjectRemastered/releases):

```sh
python3 scripts/import_assets.py --windows-zip /path/to/MinotaurProjectRemastered-1.2.zip
```

The importer reads embedded archives and artwork; it never runs the Windows executables. Alternatively:

```sh
python3 scripts/import_assets.py --ipa-dir /path/to/supported-decrypted-ipas --icon /optional/path/to/icon.png
```

Omit `--icon` to use an imported upstream icon, or a generated pixel-M fallback. The supported binary hashes are in `games.json`. Assets live under ignored `local-assets/`.

## 3. Build a Mac app

```sh
python3 scripts/build.py macos
```

For a smaller first build, start with one game:

```sh
python3 scripts/build.py macos --game Gridrunner
```

The source pipeline builds a reference executable, records each game's startup briefly, recovers function/switch roots, emits static translations and links a native engine. A short game window can appear during reference recording. Later packaging enables only the helpers actually built; the other picker tiles are disabled.

The result is:

```text
build/MinotaurProjectRemastered for Apple.app
```

The app is self-contained. Copy it to Applications and open it. It does not need this checkout or Homebrew at runtime. The script creates an ad-hoc signature and verifies all nested signatures; it does not notarize or publish the app. It never replaces an installed application automatically.

## 4. Build for iPad / iPhone

The current source generates a universal device app. **The iPhone canvas correction passed initial rendering checks for all nine games on a physical phone; touch, rotation and full gameplay remain experimental.** All nine supported game assets are currently required for the combined mobile CPU library.

```sh
python3 scripts/build.py ios --team YOURTEAMID --bundle-id your.unique.minotaur.id
```

Use your own Apple team and identifier, not somebody else's provisioning profile. An unsigned compilation check is available with `--no-sign`; its app cannot be installed directly on a normal device.

The app is produced at:

```text
ios/build/Xcode/Build/Products/Release-iphoneos/MinotaurApple.app
```

You can also open the generated `ios/MinotaurApple.xcodeproj`, select your team and connected device, then run. Xcode 27.2 / iOS 27.2 was the tested device environment; the deployment target is iOS 15 but older OS versions have not been checked.

For a command-line device installation:

```sh
xcrun devicectl list devices
xcrun devicectl device install app --device DEVICE_ID ios/build/Xcode/Build/Products/Release-iphoneos/MinotaurApple.app
xcrun devicectl device process launch --device DEVICE_ID your.unique.minotaur.id
```

Keep the device unlocked for launch. No development team ID, device identifier, signing certificate or provisioning profile is stored in this repository.

## Checks and rebuilding

```sh
python3 scripts/check_repo.py
python3 -m unittest discover -s tests
```

Runtime builds and source patches are versioned, while reference traces and generated translations are local. To regenerate a game's translations, remove only that game's ignored `games/<id>/generated` directory and rebuild. Keep your actual player-save folder outside this checkout untouched.

For instruction comparisons, use `tools/prepare-checks.py`, `tools/build-check-tool.py` and the emitted `work/check-expanded.trace` with `MPR_EXPERIMENT_ROOT` set to the relevant game workspace. See [ARCHITECTURE.md](ARCHITECTURE.md) for what those checks do and do not compare.

After changing the reference runtime itself, also remove its ignored cached `work/touchHLE-trace` so the next translation build recreates it. Do not reuse old traces as evidence for a changed runtime or a different game binary.
