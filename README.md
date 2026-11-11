# Minotaur Project Remastered for Apple

Play all nine of Llamasoft’s original Minotaur Project games on Apple Silicon Mac, iPad and iPhone. The collection brings them together in one picker with original game artwork, an animated pixel title and a Metal kaleidoscope full of sprites from the games.

**Jeff Minter and Ivan “Giles” Zorzin, thank you for all the fun your games have given me over so many years.** This fan project is my way of saying thanks and helping more people enjoy these games again. — Aaron

## Support Jeff and Giles

Visit [Jeff’s original Minotaur Project site](http://www.minotaurproject.co.uk/frontpage.php). If you enjoy these games, support their work by buying their other releases.

| Game | Stores |
| --- | --- |
| Moose Life | [Steam](https://store.steampowered.com/app/1342740/) · [PlayStation](https://store.playstation.com/en-gb/product/EP4461-CUSA26621_00-9854696025743028) |
| Tempest 4000 | [Steam](https://store.steampowered.com/app/688140/) · [PlayStation](https://store.playstation.com/en-gb/product/EP0182-CUSA09885_00-TEMPEST400000001) |
| Llamasoft: The Jeff Minter Story | [Steam](https://store.steampowered.com/app/2236680/) · [PlayStation](https://store.playstation.com/en-gb/product/EP7816-PPSA18158_00-0079142450506243) |

The Apple adaptation is an unofficial fan project developed with AI assistance. See [credits and provenance](CREDITS.md).

## Play the games

Gridrunner · Super Ox Wars · Minotron: 2112 · Minotaur Rescue · Five A Day · Deflex · Caverns of Minos · GoatUp · GoatUp 2.

- **Apple Silicon Mac.** Download the macOS ARM64 ZIP from [Releases](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/releases), unzip it and move **MinotaurProjectRemastered for Apple.app** to Applications. Open it and pick a game. The app targets macOS 13 or later. The maintainer tested on an M5 Mac Studio.
- **iPad and iPhone.** Build and sign the universal app for your device using Xcode and your own Apple development team. The [build guide](docs/BUILDING.md) covers the steps and supported game assets. The maintainer playtested on iPad Pro and iPhone 17 Pro Max.
- **Windows and Steam Deck.** See [the original Windows collection](https://github.com/jedeyesniv-art/MinotaurProjectRemastered).

### First launch on macOS

The Mac release is signed with Developer ID and notarised by Apple. The notarisation ticket is attached to the app, so you can open it normally from Applications.

### Switch games

- **Mac.** With the game window active, press **⌘Q (Command–Q)**, then pick another game. Use the mouse or a controller. **F11** or **Option–Return** toggles fullscreen. For GoatUp, choose **Controls → GoatUp → Gamepad** before launching to enable stick movement.
- **iPad or iPhone.** Tap **‹ Games** at the top left of the game screen, then pick another game.

The picker’s **Info → Joystick** tab lists the per-game mappings. Controller **Back** and keyboard **Esc** depend on the game and the current screen. See the [controller guide](docs/CONTROLLERS.md) and [troubleshooting](docs/TROUBLESHOOTING.md).

## From Windows to Apple Silicon

This started with [jedeyesniv-art’s Minotaur Project Remastered](https://github.com/jedeyesniv-art/MinotaurProjectRemastered), which runs the original 32-bit iPad games on Windows using a [modified touchHLE runtime](https://github.com/jedeyesniv-art/MinotaurProjectRemastered-touchHLE). The Apple adaptation uses that runtime’s source, controller mappings and compatibility work. The Windows distribution can supply the original game assets during setup. The importer reads the bundled archives directly.

- **CPU translation.** Dynarmic helps analyse and check the original 32-bit ARM/Thumb game code during development. The build translates that code ahead of time into C++ and compiles it to ARM64. The shipped engines use those compiled routines and a cached dispatcher, with no runtime JIT or interpreter fallback.
- **Compatibility.** The games still use touchHLE for the old iOS graphics, audio, UIKit and Foundation behaviour. We built the Mac and mobile runtime variants for Apple platforms. The Mac app needs neither Windows nor Rosetta.
- **Presentation and input.** The Mac picker uses AppKit and the iPad/iPhone picker uses UIKit, with a shared Metal backdrop. The mobile presenter fits each game’s original iPad canvas to the physical display and maps touches back to that canvas. The Mac adds mouse and controller controls, including a dedicated GoatUp gamepad setting.

See [architecture and repository layout](docs/ARCHITECTURE.md) for the pipeline and [validation](docs/VALIDATION.md) for the scope of the checks.

## Contribute

Bug fixes, controller improvements and feature ideas are welcome. Start with the [known issues](docs/STATUS.md) and [contribution guide](CONTRIBUTING.md). Please bring Apple-port reports to [this project’s issues](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/issues).

The repository contains the port source, runtime patches and build tools. Build from locally imported assets using [BUILDING.md](docs/BUILDING.md) and [ASSETS.md](docs/ASSETS.md). The port code and runtime modifications use [MPL-2.0](LICENSE). The original games, names, logos and artwork remain their owners’ work. See [licensing notes](docs/LICENSING.md).
