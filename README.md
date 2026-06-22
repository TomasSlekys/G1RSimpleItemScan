Description

SimpleItemScan is a lightweight Gothic 1 Remake Lua mod that scans for nearby loot when you press a key and temporarily highlights it with the game's outline system. By default, the scan is triggered with `X`, covers a 2500 uu radius (about 25 meters) around the player, and keeps the highlight active for 8 seconds. All of these values can be changed in `Scripts/config.lua`.

The scan is a snapshot taken from the player's position at the moment the key is pressed. Highlighted targets stay highlighted for the configured duration even if you move away, and newly approached targets are not added automatically until you scan again. Repeated scans refresh the timer on already highlighted targets instead of clearing them immediately.

Installation instructions

1. Copy the mod folder into your game's `Mods` directory. The folder name can be anything.
2. Make sure the mod's Lua files are inside that folder's `Scripts` directory.
3. Start the game with UE4SS / your Lua mod loader enabled.
4. Enable `Accessibility > Object Outliner` in the game's settings.
5. Edit `Scripts/config.lua` if you want to change the scan key, radius, duration, or outline settings.

Main features

- Press the configured scan key ("X" by default) to highlight nearby world items, corpses, chests, and pickpocket pouches in a configurable radius (25m by default) around the player.
- Scan radius and highlight duration are configurable in `Scripts/config.lua`.
- Repeated scans refresh the timer on already highlighted targets instead of clearing them immediately.
- Chests with a confirmed empty live inventory can be skipped automatically.
- Outline visibility can be tuned through config options such as thickness, opacity, and color.
- Items and chests owned by someone else can use a separate red warning outline.
- You can configure:
  - the scan button; default: `X`
  - scan radius; default: `2500 uu` (about `25m`)
  - highlight duration; default: `8 seconds`
  - whether thick outlines are used; default: `enabled`
  - whether corpses are included; default: `enabled`
  - whether chests are included; default: `enabled`
  - whether NPC pickpocket pouches are included; default: `enabled`
  - whether outline settings refresh automatically; default: `enabled`
  - whether confirmed empty chests are skipped (`skip_empty_chests`); default: `enabled`
  - outline thickness; default: `thick outline enabled`, multiplier `2.0`
  - outline opacity; default: `1.0`
  - outline color; default: white `1.0, 1.0, 1.0`
  - stealing warning outlines (`use_stealing_outline`); default: `enabled`
  - stealing warning color (`stealing_outline_color`); default: red-orange `{ 1.0, 0.2, 0.0 }`

Requirements

- Gothic 1 Remake
- UE4SS or the Lua mod loading setup you are already using for Gothic 1 Remake mods
- The game's own item highlight / outline system should be available and enabled, because this mod feeds targets into the existing outline subsystem rather than drawing its own markers
