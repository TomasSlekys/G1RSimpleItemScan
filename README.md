Description

SimpleItemScan is a lightweight Gothic 1 Remake Lua mod that scans for nearby loot when you press a key and temporarily highlights it with the game's outline system. By default, the scan is triggered with `X`, covers a 2500 uu radius (about 25 meters) around the player, and keeps the highlight active for 8 seconds. All of these values can be changed in `Scripts/config.lua`.

The scan is a snapshot taken from the player's position at the moment the key is pressed. Highlighted targets stay highlighted for the configured duration even if you move away, and newly approached targets are not added automatically until you scan again. Repeated scans refresh the timer on already highlighted targets instead of clearing them immediately.

Installation instructions

1. Copy the mod folder into your game's `Mods` directory. The folder name can be anything.
2. Make sure the mod's Lua files are inside that folder's `Scripts` directory.
3. Start the game with UE4SS / your Lua mod loader enabled.
4. Enable `Accessibility > Object Outliner` in the game's settings.
5. Edit `Scripts/config.lua` if you want to change the scan key, radius, duration, or outline settings.
6. If you use chest memory on multiple saves or characters, set a different `chest_memory_slot` value in `Scripts/config.lua` for each one.

Main features

- Press the configured scan key ("X" by default) to highlight nearby world items, corpses and chest in a configurable radius (25m by default) around the player.
- Scan radius and highlight duration are configurable in `Scripts/config.lua`.
- Repeated scans refresh the timer on already highlighted targets instead of clearing them immediately.
- Experimental chest memory can remember opened chests and stop highlighting them in later scans.
- Outline visibility can be tuned through config options such as thickness, opacity, and color.
- You can configure:
  - the scan button; default: `X`
  - scan radius; default: `2500 uu` (about `25m`)
  - highlight duration; default: `8 seconds`
  - whether thick outlines are used; default: `enabled`
  - whether corpses are included; default: `enabled`
  - whether chests are included; default: `enabled`
  - whether outline settings refresh automatically and opened chests are tracked; default: `enabled`
  - whether opened chests should be remembered and skipped later (EXPERIMENTAL); default: `disabled`
  - chest memory slot name for separate save/playthrough tracking; default: `default`
  - outline thickness; default: `thick outline enabled`, multiplier `2.0`
  - outline opacity; default: `1.0`
  - outline color; default: white `1.0, 1.0, 1.0`
  - debug logging; default: `disabled`

Requirements

- Gothic 1 Remake
- UE4SS or the Lua mod loading setup you are already using for Gothic 1 Remake mods
- The game's own item highlight / outline system should be available and enabled, because this mod feeds targets into the existing outline subsystem rather than drawing its own markers
