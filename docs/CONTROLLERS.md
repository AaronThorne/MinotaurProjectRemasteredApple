# Controller guide

The Apple port uses the nine controller mappings from the Windows release. The table uses Xbox button names. Physical controller testing across every game and controller model is still pending.

| Game | Movement / aiming | Main actions |
| --- | --- | --- |
| Gridrunner | Left stick | A selects/starts; Start pauses; right shoulder changes game orientation/version. |
| Super Ox Wars | Left stick | A starts; Start pauses. |
| Five A Day | Left stick | A starts; Start pauses. |
| Minotron: 2112 | Left stick moves, right stick aims | In menus, left stick moves a pointer and A selects; Start pauses. |
| Minotaur Rescue | Left stick strokes a virtual finger to steer | Menus use pointer + A. Start pauses and resumes during a game. |
| Deflex | D-pad/stick left and right operate paddles | A selects; X plays; Start pauses. Other shoulder/button paddle mappings are retained from upstream. |
| Caverns of Minos | Left stick steers, right stick tilts | A or right trigger thrusts; Start pauses. |
| GoatUp | Left stick or D-pad | A jumps; hold it for a higher jump. Start pauses. |
| GoatUp 2 | Left stick provides tilt | A jumps; Start pauses. Select the game's tilt control mode; X changes it while paused. |

On Mac, open **Info → Joystick** for these mappings, mouse and trackpad gestures, and keyboard shortcuts. **Controls → Controller guide…** opens the same tab. The app menu’s **About** item opens **About**.

## Switch games

- **Mac** — Press **⌘Q (Command–Q)** with the game window active, then click another game in the picker.
- **iPad or iPhone** — Tap **‹ Games** at the top left of the game screen, then tap another game in the picker.

Controller **Back** and keyboard **Esc** can do different things depending on the game and screen.

## GoatUp on Mac

Use **Controls → GoatUp → Gamepad** before launching. The bootstrap sets the original game's Control Type C, which listens to tilt. In Type A, A can jump while the stick appears to do nothing: movement is still expecting a finger gesture. The explicit Mac mode fixes that mismatch.

Choose **Mouse — original controls** to return to Control Type A. Mode changes apply on the next launch. Scores and other progress bytes are preserved; a clean default profile is used for a new player.

GoatUp 2 has no equivalent automatic mode selector yet. Set its original tilt mode inside the game. Do not assume that its initial control setting is already correct just because A works.

## Mobile

Tap **Info → Joystick** on the picker to see these mappings in the app. **About** lists the original creators and links to the projects behind the port.

Pair an extended gamepad with your iPhone or iPad before opening a game. Minotaur selects that game's controller profile when it starts. If you pair a pad during play, return to the picker and open the game again. Opening a game without a controller selects its touch controls.

For **GoatUp**, choose **Control Type C** inside the game for stick movement. For **GoatUp 2**, select its tilt mode. In **Minotron: 2112**, use the left stick to move and the right stick to aim. The gamepad moves an on-screen pointer in menus and A selects.
