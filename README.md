Description

SimpleItemScan is a lightweight Gothic 1 Remake Lua mod that scans for nearby loot when you press a key and temporarily highlights it with the game's outline system. By default, the scan is triggered with `X`, covers a 2500 uu radius (about 25 meters) around the player, and keeps the highlight active for 5 seconds. All of these values can be changed in `Scripts/config.lua`.

The scan is a snapshot taken from the player's position at the moment the key is pressed. Highlighted targets stay highlighted for the configured duration even if you move away, and newly approached targets are not added automatically until you scan again. Repeated scans refresh the timer on already highlighted targets instead of clearing them immediately.

Installation instructions

1. Copy the mod folder into your game's `Mods` directory. The folder name can be anything.
2. Make sure the mod's Lua files are inside that folder's `Scripts` directory.
3. Start the game with UE4SS / your Lua mod loader enabled.
4. Enable `Accessibility > Object Outliner` in the game's settings.
5. Edit `Scripts/config.lua` if you want to change the scan key, radius, duration, or outline settings.

Main features

- Press the configured scan key to highlight nearby world items in a configurable radius around the player.
- Lootable ragdoll corpses can also be highlighted.
- Chests can also be highlighted.
- Scan radius and highlight duration are configurable in `Scripts/config.lua`.
- Repeated scans refresh the timer on already highlighted targets instead of clearing them immediately.
- Newly streamed items are added to the cache automatically.
- Newly encountered corpses are refreshed into the cache on scan.
- Outline visibility can be tuned through config options such as thickness, opacity, and color.
- User-facing settings are stored in a separate `Scripts/config.lua` file.
- You can configure:
  the scan button, scan radius, highlight duration, whether corpses are included, whether chests are included, outline thickness, outline opacity, outline color, and debug logging

Requirements

- Gothic 1 Remake
- UE4SS or the Lua mod loading setup you are already using for Gothic 1 Remake mods
- The game's own item highlight / outline system should be available and enabled, because this mod feeds targets into the existing outline subsystem rather than drawing its own markers
