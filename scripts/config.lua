return {
    -- Keyboard key used to trigger the scan.
    -- Use a UE4SS/OpenUnreal key name such as "X", "F6", "V", "NumPadZero".
    highlight_key = "X",

    -- Scan radius in Unreal units.
    -- 100 uu is roughly 1 meter, so 2500 ~= 25 meters.
    radius = 2500.0,

    -- How long highlighted targets stay outlined after a scan, in seconds.
    -- Pressing the scan key again refreshes the timer for existing outlines.
    duration = 5.0,

    -- Outline stencil slot passed to the game's outline subsystem.
    -- Default 2 matches the current mod behavior and should usually be left alone.
    stencil_usage = 2,

    -- Enables the subsystem's built-in "thick outline" mode.
    -- Leave this on unless you want a thinner, more vanilla-looking outline.
    use_thick_outline = true,

    -- When true, ragdoll corpses with active loot interaction are included in scans.
    -- When false, the mod only highlights world items.
    highlight_corpses = true,

    -- When true, chests are included in scans.
    highlight_chests = true,

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
    debug_mode = true,

    -- EXPERIMENTAL

    -- Logs extra chest/container state details to the UE4SS log.
    -- Useful for comparing full vs empty chests while testing.
    log_chest_state = false,

    -- When true, opened chests are remembered in a text file and skipped in later scans.
    -- Experimental: this is intended to reduce highlights on already looted containers.
    remember_opened_chests = false,

    -- Manual memory slot name used for remembered opened chests.
    -- Change this when playing on a different save or character profile so chest memory stays separate.
    chest_memory_slot = "default",
}
