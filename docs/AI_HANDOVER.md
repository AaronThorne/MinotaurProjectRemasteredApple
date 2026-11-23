# MinotaurProjectRemasteredApple AI developer handover

Reviewed 2026-11-23 against `main` at [`384e39062405`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/commit/384e390624059a824e8d94f915b41fb283d3deee).

This review used the default-branch tree, selected source and documentation, recent commits, and available GitHub issue, Actions and release metadata. **Verified** means visible in those sources. **Documented** refers to maintainer notes or commit history. **Unverified** marks runtime or external state not established here. **Proposed** marks follow-up work. The available project conversation was the QuePane handover and its cross-project references.

## Purpose and current implementation

Apple-platform adaptation of the Minotaur Project Remastered fan port. Repository docs cover architecture, assets, controllers, licensing, builds and publishing. The README documents an Apple Silicon Mac release and signed iPhone/iPad builds from source.

## Architecture and navigation

**Verified stack.** Swift with AppKit in reviewed files and native host wrappers and Python build tooling.

- **Build and project entry points.** [`ios/project.yml`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/ios/project.yml).
- **Representative source reviewed.** [`aot/wrapper.cpp`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/aot/wrapper.cpp), [`ios/build-cpu.py`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/ios/build-cpu.py), [`ios/prepare-app-icon.swift`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/ios/prepare-app-icon.swift).
- **Documentation.** [`README.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/README.md), [`docs/ARCHITECTURE.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/docs/ARCHITECTURE.md), [`docs/ASSETS.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/docs/ASSETS.md), [`docs/BUILDING.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/docs/BUILDING.md), [`docs/CONTROLLERS.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/docs/CONTROLLERS.md), [`docs/LICENSING.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/docs/LICENSING.md), [`docs/PUBLISHING.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/docs/PUBLISHING.md), [`docs/RELEASE-NOTES.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/docs/RELEASE-NOTES.md), [`docs/STATUS.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/docs/STATUS.md), [`docs/TROUBLESHOOTING.md`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/docs/TROUBLESHOOTING.md).

## Design decisions and development history

**Documented decision.** Follow the repository asset and licensing boundaries for builds and redistribution. The documented guest-canvas and host-display split supports Apple-specific presentation.

- [`384e390624`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/commit/384e390624059a824e8d94f915b41fb283d3deee) · 2026-11-14 · Document and prepare Minotaur Project v1.4.13
- [`94683e3090`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/commit/94683e3090605ec9c173ba4b002043111e3d6d32) · 2026-11-13 · Clarify App Store release plans
- [`ce2daa4b9c`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/commit/ce2daa4b9cca59dd987a33dd6dead36e830eaa4b) · 2026-11-13 · Show the macOS game picker
- [`b2c3e3cfa3`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/commit/b2c3e3cfa3a204ccacabcbb0cbb814c4432476ea) · 2026-11-13 · Link directly to the conceptAlpha Minotaur post

## Build, deployment and testing

**Tracked test paths.** [`tests/test_import_assets.py`](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/blob/384e390624059a824e8d94f915b41fb283d3deee/tests/test_import_assets.py). Presence does not establish passing results.

**Actions.** No runs were returned by the Actions API at review time.

**GitHub releases.** [release record 442158650](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/releases/tag/v1.4.12) (2026-11-11), [release record 441712777](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/releases/tag/v1.4.11) (2026-11-11).

No app builds, device tests or deployments were performed during this portfolio review.

## Known bugs, blockers and next steps

No open issue was returned on the reviewed issue page.

**Unverified.** The available evidence does not establish a complete defect inventory or current production behavior.

**Proposed next step.** Follow the licensing and asset docs before packaging. Verify controller mapping and game picker behavior on Mac and use the iOS build guide for a device check.
