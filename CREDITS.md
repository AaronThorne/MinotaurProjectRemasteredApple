# Credits and provenance

## Original games

**Jeff Minter and Ivan “Giles” Zorzin — Llamasoft.** The entire reason this project exists is to make it possible to enjoy their Minotaur Project games again.

- [Jeff’s original Minotaur Project website](http://www.minotaurproject.co.uk/frontpage.php)
- [Support Llamasoft on Steam and PlayStation](README.md#support-jeff-and-giles)

The original games, their names, artwork and logos remain © Llamasoft / their respective owners. This repository does not claim to own them or to be an official Llamasoft release.

## Starting point

**jedeyesniv-art — Minotaur Project Remastered.** The Windows collection, controller mappings, presentation work and touchHLE fork made this experiment possible.

- [Original collection and README](https://github.com/jedeyesniv-art/MinotaurProjectRemastered)
- [Original release downloads](https://github.com/jedeyesniv-art/MinotaurProjectRemastered/releases)
- [Runtime fork](https://github.com/jedeyesniv-art/MinotaurProjectRemastered-touchHLE)
- [Pinned runtime revision used for this port](https://github.com/jedeyesniv-art/MinotaurProjectRemastered-touchHLE/commit/666ba85451fe28718b368d4e22683f4bdb92c0ce)

The original collection's README states that its release has Llamasoft's kind permission. This Apple adaptation does not extend that statement into a claim of official Apple-port approval or support.

## Compatibility runtime and tools

- [touchHLE](https://github.com/touchHLE/touchHLE), by hikari_no_yume and contributors: old iOS framework compatibility, MPL-2.0.
- [Dynarmic, touchHLE fork](https://github.com/touchHLE/dynarmic): offline ARM/Thumb translation and reference checking; retain its 0BSD notices.
- [SDL2](https://github.com/libsdl-org/SDL) and [the touchHLE Rust SDL bindings](https://github.com/touchHLE/rust-sdl2): windowing/input, zlib and crate licences.
- [OpenAL Soft](https://github.com/kcat/openal-soft): audio; retain its LGPL notices.
- The runtime's other libraries, fonts and guest dylibs retain their own notices. The pinned source includes dependency and font licences, which the packager carries into the app's runtime resources.

The Apple adaptation adds the AppKit/UIKit pickers, Metal background, pixel title, static CPU tooling, mobile presentation changes, game-start repairs and Mac GoatUp control selection. Development was assisted by Codex/AI. It still depends substantially on the work credited above.

The upstream touchHLE project does not accept this AI-assisted fork's changes upstream. Do not submit this port's patches there or send its bug reports to that team. Keep derivative-project support with this project.
