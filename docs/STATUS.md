# Known issues and testing

The maintainer reports stable playtesting on Apple Silicon Mac, iPad and iPhone. The development checks also covered startup for all nine games and returning from each game to the picker on iPad. The original iPhone cropping issue was fixed and verified during startup in all nine games.

| Area | What to look for |
| --- | --- |
| Later levels and long sessions | An untested game path can still reach a missing ARM translation and stop the game. Include the game, level and missing-location log in a report. |
| Controller compatibility | All nine games have mappings. Testing across controller models and all game screens is still in progress. GoatUp 2 requires selecting its original tilt control mode inside the game. |
| Mobile display and touch | Reports from other screen sizes, rotations and longer touch play sessions are welcome. |

See [validation](VALIDATION.md) for the clean-source checks and [the iPhone scaling investigation](issues/001-iphone-scaling.md) for details of the fixed issue.
