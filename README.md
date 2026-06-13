Description

SimpleItemScan is a lightweight Gothic 1 Remake Lua mod that scans for nearby loot when you press a key and temporarily highlights it with the game's outline system. It is meant to stay simple and practical: quick manual scans, no always-on processing, and minimal gameplay intrusion.

Installation instructions

1. Copy the `SimpleItemScan` mod folder into your game's `Mods` directory.
2. Make sure the mod's Lua files are inside `Mods/SimpleItemScan/Scripts/`.
3. Start the game with UE4SS / your Lua mod loader enabled.
4. Enable `Accessibility > Object Outliner` in the game's settings.
5. Edit `Scripts/config.lua` if you want to change the scan key, radius, duration, or outline settings.

Main features

- Press the configured scan key to highlight nearby world items.
- Lootable ragdoll corpses can also be highlighted.
- Repeated scans refresh the timer on already highlighted targets instead of clearing them immediately.
- Newly streamed items are added to the cache automatically.
- Newly encountered corpses are refreshed into the cache on scan.
- Outline visibility can be tuned through config options such as thickness and opacity.
- User-facing settings are stored in a separate `Scripts/config.lua` file.

Requirements

- Gothic 1 Remake
- UE4SS or the Lua mod loading setup you are already using for Gothic 1 Remake mods
- The game's own item highlight / outline system should be available and enabled, because this mod feeds targets into the existing outline subsystem rather than drawing its own markers
