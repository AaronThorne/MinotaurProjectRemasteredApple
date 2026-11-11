# Original games and local assets

The source repository does not contain original IPAs, decrypted game binaries, extracted artwork, generated game translations or a playable app bundle.

Obtain the supported games from your own decrypted copies, or use the full distribution offered by [the original Minotaur Project Remastered project](https://github.com/jedeyesniv-art/MinotaurProjectRemastered/releases). Its README describes a full release with games and a separate bring-your-own-games release. The latter will not supply the game files to the importer.

Use `scripts/import_assets.py` to import them. Files may have arbitrary names: the importer identifies the original bundle ID and checks the selected ARM32 binary against `games.json`. An encrypted IPA or a different game revision is rejected rather than silently applying version-specific fixes to it.

The nine accepted bundle IDs and hashes are recorded in `games.json`. They match the original game versions used by this experiment. Other versions need separate analysis and validation; changing a hash alone is not a compatibility fix.

The Windows ZIP importer extracts embedded ZIP/IPA and PNG data without executing any `.exe`. It also imports the supplied sheep icon and game art when present. IPA-only imports use the IPA icons; an optional `--icon` supplies the collection icon. Without one, a generated pixel-M icon is used.

Imported files and staging trees live in ignored directories. `scripts/prepare_assets.py` builds clean runtime resources and per-game data from those imports. It does not read the builder's Application Support folder or copy a player's saves into a release.

The picker shuffles four different sprites into its corners when it opens or you return from a game. Its pool includes the camel, pixel sheep and minotaur from Minotron: 2112, the GoatUp 2 goat, the Deflex camel, the Super Ox Wars fighter and the Gridrunner invader. The build copies their sprite sheets from the locally imported IPAs into the app.

Fonts and guest dylibs are fetched with the pinned runtime and retain their included licences. Their notices are carried into packaged resources.

Before making a binary release, decide separately what game material you are permitted to redistribute. This source licence does not grant a new licence to Llamasoft's games or artwork, and the original project's stated permission is not represented as official support for this Apple port.
