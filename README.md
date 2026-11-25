# WoW GamePad Tweaks

Controller tweaks for WoW: Forever (Interface 16001). Remap bumpers and triggers and put any action on any controller button. Three optional modules add the rest:

| Folder | What it does |
| --- | --- |
| `WowGamePadTweaks` | The main addon: remapping, crossbar actions, profiles, sync between computers, tweaks. Required. |
| `WowGamePadTweaks_Keyboard` | An on-screen keyboard for chat and text boxes, with word suggestions. |
| `WowGamePadTweaks_Rings` | Action rings: hold a button, aim with the stick, release to use. |
| `WowGamePadTweaks_Touch` | Touch bars: buttons on the screen edges to tap on a touch screen (Steam Link). |

## Install

1. Download this repository (**Code → Download ZIP**) or clone it.
2. Copy the four `WowGamePadTweaks*` folders into `World of Warcraft/_forever_/Interface/AddOns/`.
3. Start the game, or type `/reload` if it's already running.

Type `/fct` in game to open the settings, or `/fct help` to list every command.

### Coming from Forever Controller Tweaks

This addon has a new folder name, so the game treats it as a new addon:

- Delete the old `ForeverControllerTweaks*` folders from your AddOns folder so the two don't load together.
- To keep your settings, copy `WTF/Account/<account>/SavedVariables/ForeverControllerTweaks.lua` to `WowGamePadTweaks.lua` in the same folder, then open the copy and change `ForeverControllerTweaksDB` to `WowGamePadTweaksDB` at the top.

## Changes

See [CHANGELOG.md](WowGamePadTweaks/CHANGELOG.md).

## Credits

WoW GamePad Tweaks is based on **[Forever Controller Tweaks](https://racha.github.io/forever-controller-tweaks/)** by **HouseLegend**, released under the MIT license. Almost all of the code here is their work. Thank you, HouseLegend!

The original addon also credits these projects:

- **Improved Forever** by markg (MIT): the bag priority and ring stick handling were learnt from it.
- **Controller Companion** (MIT): the check in `Core.lua`.
- **Gamepad Suite** and **Controller Forever**: ideas only; none of their code is used.

## License

MIT. See [LICENSE](WowGamePadTweaks/LICENSE). The original copyright notice is kept as the license requires.
