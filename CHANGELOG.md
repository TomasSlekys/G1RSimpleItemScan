# Changelog

## v1.0.15

- Fixed a runtime error while updating stencil outline colors when UE4SS supplies a function-valued map entry.
- Added optional SharedModMenu integration for changing scan, filter, outline, stealing-warning, and debug settings in game.
- Added live inventory filtering so corpses with no remaining items can be skipped, plus an optional experimental data-driven hunting-skill filter and diagnostic logging for building its item map.
- Stored auto-discovered hunting loot mappings in a separate update-safe user file and added support for ignoring persistent internal corpse entries such as `LurkerTail`.

## v1.0.14

- Fixed outline thickness gradually increasing during normal play.
- Added an optional red warning outline for items and chests owned by others.
- Improved stability when pressing the scan key repeatedly in quick succession.
- Added highlighting for NPC pickpocket pouches.
- Replaced experimental opened-chest memory with live empty-chest detection.

## v1.0.13

- Corrected the documented key name for numpad 0.
- Reworked target discovery to scan only nearby actors when the scan key is pressed, reducing background work and removing the older full-world scanning fallback.

## v1.0.12

- Added an option to disable automatic background updates and refresh nearby targets only when scanning.
- Increased the default highlight duration from 5 to 8 seconds.

## v1.0.11

- Added support for using the scan key while holding common modifier keys such as Shift, Control, or Alt.
- Improved scan stability during loading and quickloads.

## v1.0.10

- Reduced crash risk after quickloads and world changes by clearing stale cached scan targets before the next scan.

## v1.0.9

- Fixed a periodic background stutter that could happen even without pressing the scan key.

## v1.0.8

- Fixed cases where some nearby items could be missed until restarting the game.
- Improved startup target collection so already loaded items and chests are picked up more reliably.
- Excluded AI/helper-style bag items from normal item highlighting.
- Added optional item debug logging to help identify unwanted highlighted objects.
- Improved outline setting persistence so custom color and thickness reapply more reliably after quickloads and world changes.

## v1.0.7

- Fixed an issue introduced by the performance update where some nearby items could stop being highlighted.

## v1.0.6

- Improved scan performance to reduce hitching when pressing the scan key.
- Optimised nearby target collection so scans do less work in dense areas.
- Reduced the impact of corpse refreshes on the immediate scan button press.
- Improved corpse coverage so more nearby corpses are detected and highlighted reliably.
- Updated the README config list so it matches the current options and default values.

## v1.0.5

- Improved outline consistency so custom thickness and color settings reapply more reliably during play.
- Added an experimental option to remember opened chests and stop highlighting them in later scans.
- Added a manual chest memory slot setting so different saves or characters can use separate remembered chest lists.

## v1.0.4

- Improved stability to reduce crashes during repeated scans.
- Smoothed out scan performance so pressing the scan key causes less stutter.
- Improved chest detection so chests recover more reliably after loading into the world.
- Added a configurable custom outline color.

## v1.0.3

- Removed the hardcoded `SimpleItemScan` folder-name requirement so the mod can run from versioned release folders too.

## v1.0.2

- Added chest/container scanning.
- Improved corpse cache refresh so newly encountered corpses can be highlighted.
- Refactored the Lua code into smaller modules for easier maintenance.
- Guarded location reads against non-numeric values to avoid scan-time Lua errors.

## v1.0.1

- Added `enabled.txt` packaging support.
- Documented required installation steps in `README.md`.
- Documented the required in-game `Accessibility > Object Outliner` setting.

## v1.0.0

- Initial public release.
- Added configurable scan key, radius, duration, and outline settings.
- Added temporary highlighting for nearby items and lootable corpses.
- Reduced scan stutter with cached target discovery.
- Added external `config.lua` configuration and user documentation.
