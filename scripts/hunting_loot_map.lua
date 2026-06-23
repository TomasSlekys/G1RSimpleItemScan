-- Maps corpse item-definition name fragments to the hunting skill effects
-- required to loot them. Matching is case-insensitive and uses plain
-- substrings against m_UniqueName and GetFullName().
--
-- Unmapped items are treated as normally lootable. This makes an incomplete
-- map fail open instead of incorrectly hiding a corpse.
--
-- Example:
-- { pattern = "ITAT_WOLF_FUR", skill = "GE_Skill_Hunting_Fur_Trained" },
--
-- An item may accept any one of several effects:
-- { pattern = "EXAMPLE", skills = { "GE_Skill_One", "GE_Skill_Two" } },
-- Use skill = false for verified items that need no hunting skill.
-- Use ignore = true for internal corpse inventory entries that are not loot.
-- Runtime discoveries are stored in hunting_loot_discovered.lua so updates
-- can replace this built-in map without overwriting user assignments.

return {
    items = {
        {
            pattern = "ItAt_Bloodfly_01",
            label = "Wings",
            skill = false,
        },
        {
            pattern = "ItAt_Bloodfly_02",
            label = "Bloodfly Sting",
            skill = "GE_Skill_Hunting_StingsBloodfly_Trained",
        },
        {
            pattern = "ItAt_Bloodfly_03",
            label = "Bloodfly Poison Gland",
            skill = "GE_Skill_Hunting_Secretion_Trained",
        },
        {
            pattern = "ItAt_Claws_01",
            label = "Claws",
            skill = "GE_Skill_Hunting_Claw_Trained",
        },
        {
            pattern = "ItAt_Crawler_01",
            label = "Mandibles of a Crawler",
            skills = {
                "GE_Skill_Hunting_MandibleMineCrawler_Trained",
                "GE_Skill_Hunting_Secretion_Trained",
            },
        },
        {
            pattern = "ItAt_Crawler_02",
            label = "Armor Plate",
            skill = "GE_Skill_Hunting_MCPlate_Trained",
        },
        {
            pattern = "ItAt_Crawlerqueen",
            label = "Minecrawler's Egg",
            skill = false,
        },
        {
            pattern = "ItAt_DamLurker_01",
            label = "Dam Lurker's Claws",
            skill = "GE_Skill_Hunting_Claw_Trained",
        },
        {
            pattern = "ItAt_Lurker_01",
            label = "Lurker's Claws",
            skill = "GE_Skill_Hunting_Claw_Trained",
        },
        {
            pattern = "ItAt_Lurker_02",
            label = "Lurker's Skin",
            skill = "GE_Skill_Hunting_Reptiles_Trained",
        },
        {
            pattern = "LurkerTail",
            label = "Lurker Tail (internal)",
            ignore = true,
        },
        {
            pattern = "ItAt_Meatbug_01",
            label = "Bugmeat",
            skill = false,
        },
        {
            pattern = "ItAt_Shadow_01",
            label = "Skin of a Shadowbeast",
            skill = "GE_Skill_Hunting_Skin_Trained",
        },
        {
            pattern = "ItAt_Shadow_02",
            label = "Horn of a Shadowbeast",
            skill = "GE_Skill_Hunting_ShadowbeastHorn_Trained",
        },
        {
            pattern = "ItAt_Swampshark_01",
            label = "Skin of a Swampshark",
            skill = "GE_Skill_Hunting_SkinSwampshark_Trained",
        },
        {
            pattern = "ItAt_Swampshark_02",
            label = "Teeth of a Swampshark",
            skill = "GE_Skill_Hunting_TeethSwampshark_Trained",
        },
        {
            pattern = "ItAt_Teeth_01",
            label = "Teeth",
            skill = "GE_Skill_Hunting_Teeth_Trained",
        },
        {
            pattern = "ItAt_Troll_01",
            label = "Troll Skin",
            skill = "GE_Skill_Hunting_Skin_Trained",
        },
        {
            pattern = "ItAt_Troll_02",
            label = "Troll Tusk",
            skill = "GE_Skill_Hunting_TrollHorn_Trained",
        },
        {
            pattern = "ItAt_Waran_01",
            label = "Tongue of Fire",
            skill = "GE_Skill_Hunting_TongueOfFire_Trained",
        },
        {
            pattern = "ItAt_Wolf_01",
            label = "Wolfskin",
            skill = "GE_Skill_Hunting_Fur_Trained",
        },
        {
            pattern = "ItAt_Wolf_02",
            label = "Skin of an Orc Dog",
            skill = "GE_Skill_Hunting_Fur_Trained",
        },
    },

    -- Reference list discovered in the game. Some may be quest-specific.
    known_skills = {
        "GE_Skill_Hunting_Claw_Trained",
        "GE_Skill_Hunting_Fins_Trained",
        "GE_Skill_Hunting_Fur_Trained",
        "GE_Skill_Hunting_MCPlate_Trained",
        "GE_Skill_Hunting_MandibleMineCrawler_Trained",
        "GE_Skill_Hunting_Organ_Trained",
        "GE_Skill_Hunting_Reptiles_Trained",
        "GE_Skill_Hunting_Scutes_Trained",
        "GE_Skill_Hunting_Scutes_Master",
        "GE_Skill_Hunting_Secretion_Trained",
        "GE_Skill_Hunting_ShadowbeastHorn_Trained",
        "GE_Skill_Hunting_SkinSwampshark_Trained",
        "GE_Skill_Hunting_Skin_Trained",
        "GE_Skill_Hunting_SkullArmor_Trained",
        "GE_Skill_Hunting_Spines_Trained",
        "GE_Skill_Hunting_StingsBloodfly_Trained",
        "GE_Skill_Hunting_Stings_Trained",
        "GE_Skill_Hunting_TeethSwampshark_Trained",
        "GE_Skill_Hunting_Teeth_Trained",
        "GE_Skill_Hunting_TongueOfFire_Trained",
        "GE_Skill_Hunting_TrollHorn_Trained",
        "GE_Skill_Hunting_UluMulu_Trained",
    },
}
