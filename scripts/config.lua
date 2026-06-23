return {
    -- Keyboard key used to trigger the scan.
    -- Use a UE4SS/OpenUnreal key name such as "X", "F6", "V", "NUM_ZERO".
    highlight_key = "X",

    -- Scan radius in Unreal units.
    -- 100 uu is roughly 1 meter, so 2500 ~= 25 meters.
    radius = 2500.0,

    -- How long highlighted targets stay outlined after a scan, in seconds.
    -- Pressing the scan key again refreshes the timer for existing outlines.
    duration = 8.0,

    -- Uses a warning color for world items and chests owned by someone else.
    -- If ownership cannot be determined, the normal outline color is used.
    use_stealing_outline = true,

    -- Outline color for items and chests that would count as stealing.
    stealing_outline_color = { 1.0, 0.2, 0.0 },

    -- Enables the subsystem's built-in "thick outline" mode.
    -- Leave this on unless you want a thinner, more vanilla-looking outline.
    use_thick_outline = true,

    -- When true, ragdoll corpses with active loot interaction are included in scans.
    -- When false, the mod only highlights world items.
    highlight_corpses = true,

    -- When true, corpses with a confirmed empty live inventory are skipped.
    -- Corpses whose inventory is not loaded yet remain visible.
    skip_empty_corpses = true,

    -- When true, chests are included in scans.
    highlight_chests = true,

    -- When true, chests with a confirmed empty live inventory are skipped.
    -- Chests whose inventory is not loaded yet remain visible.
    skip_empty_chests = true,

    -- When true, NPC pickpocket pouch actors are included in scans.
    highlight_pouches = true,

    -- Keeps outline settings refreshed automatically.
    -- Set to false to disable that automatic task. Nearby target discovery
    -- still happens only when the scan key is pressed.
    background_updates = true,

    -- Outline opacity applied to the outline subsystem config.
    -- 1.0 = fully solid, lower values make the outline fainter.
    outline_alpha = 1.0,

    -- Optional custom outline color.
    -- Values use 0.0 to 1.0 for red, green, and blue.
    -- Example: { 0.2, 0.55, 1.0 } gives a blue outline.
    outline_color = { 1.0, 1.0, 1.0 },

    -- Multiplies the game's default outline thickness.
    -- 1.0 keeps the vanilla width, 2.0 is thicker and easier to see.
    thickness_multiplier = 2.0,

    -- Enables extra log output in the UE4SS / mod log.
    -- Useful for troubleshooting, but usually not needed for normal play.
    debug_mode = false,

    -- EXPERIMENTAL

    -- When true, mapped hunting trophies only count as loot when the hero has
    -- the required skill effect. Built-in mappings are in hunting_loot_map.lua;
    -- new discoveries and user assignments are kept in hunting_loot_discovered.lua.
    -- Unmapped items and unavailable skill state are treated as lootable.
    respect_hunting_skills = false,

    -- Logs extra chest/container state details to the UE4SS log.
    -- Useful for comparing full vs empty chests while testing.
    log_chest_state = false,

    -- Logs nearby corpse scan decisions to the UE4SS log.
    -- Useful for troubleshooting why some corpses are not highlighted.
    log_corpse_state = false,

    -- Logs nearby item scan decisions to the UE4SS log.
    -- Useful for identifying highlighted items that should be excluded.
    log_item_state = false,

}
