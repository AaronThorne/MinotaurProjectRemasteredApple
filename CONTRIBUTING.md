# Contributing

Bug fixes, controller improvements, and feature ideas are welcome. Check the [known issues](docs/STATUS.md) and [open issues](https://github.com/AaronThorne/MinotaurProjectRemasteredApple/issues) first. For code changes, follow the [build guide](docs/BUILDING.md) and use the [architecture guide](docs/ARCHITECTURE.md) to find the relevant code.

Use the pinned dependencies. Keep original assets, generated game translations, device data, player saves, signing material and build products out of commits. New platform work should not silently change the working desktop or iPad paths.

Run these checks before opening a pull request.

```sh
python3 scripts/check_repo.py
python3 -m unittest discover -s tests
```

Run a relevant build and describe precisely what you verified. For input or presentation changes, distinguish a source/configuration audit from a physical controller/device test. For CPU changes, record differential scope and mismatches, and retain explicit errors for unsupported instructions. Avoid claiming complete game compatibility from a startup check.

Bug reports should name the game, platform/device model, OS, commit/build, input method, steps and observed result. Include a short, redacted log excerpt or an app-only screenshot where useful. Do not attach original games, certificates, device identifiers or personal save folders.

This project was developed with AI assistance. Please be clear about assisted changes and their validation. Do not submit this fork's patches to upstream touchHLE or direct derivative-project issues at that team or at Jeff/Llamasoft.
