# Changelog

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
