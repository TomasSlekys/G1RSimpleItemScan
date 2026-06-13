local DEFAULT_CONFIG = {
    highlight_key = "X",
    radius = 2500.0,
    duration = 5.0,
    stencil_usage = 2,
    use_thick_outline = true,
    highlight_corpses = true,
    highlight_chests = true,
    outline_alpha = 1.0,
    thickness_multiplier = 2.0,
    debug_mode = true,
}

local function scriptRoot()
    local source = debug.getinfo(1, "S").source
    if type(source) ~= "string" then
        return "Mods/SimpleItemScan/Scripts/"
    end

    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end

    local normalized = source:gsub("\\", "/")
    return normalized:match("^(.*)/") .. "/"
end

local SCRIPT_ROOT = scriptRoot()

local localConfig = {}
pcall(function()
    localConfig = dofile(SCRIPT_ROOT .. "config.lua") or {}
end)

local function cfgNumber(name)
    local value = localConfig[name]
    if type(value) == "number" then
        return value
    end
    return DEFAULT_CONFIG[name]
end

local function cfgBoolean(name)
    local value = localConfig[name]
    if type(value) == "boolean" then
        return value
    end
    return DEFAULT_CONFIG[name]
end

local function cfgString(name)
    local value = localConfig[name]
    if type(value) == "string" and value ~= "" then
        return value
    end
    return DEFAULT_CONFIG[name]
end

local highlightKeyName = cfgString("highlight_key")

return {
    ITEM_CLASS = "ItemVisualWorld",
    ITEM_CLASS_PATH = "/Script/G1R.ItemVisualWorld",
    CORPSE_CLASS = "GothicCharacter",
    CHEST_CLASS = "InteractiveObjectActor",
    HIGHLIGHT_KEY_NAME = highlightKeyName,
    HIGHLIGHT_KEY = Key[highlightKeyName] or Key[DEFAULT_CONFIG.highlight_key],
    RADIUS = cfgNumber("radius"),
    DURATION = cfgNumber("duration"),
    STENCIL_USAGE = cfgNumber("stencil_usage"),
    USE_THICK_OUTLINE = cfgBoolean("use_thick_outline"),
    HIGHLIGHT_CORPSES = cfgBoolean("highlight_corpses"),
    HIGHLIGHT_CHESTS = cfgBoolean("highlight_chests"),
    OUTLINE_ALPHA = cfgNumber("outline_alpha"),
    THICKNESS_MULTIPLIER = cfgNumber("thickness_multiplier"),
    DEBUG_MODE = cfgBoolean("debug_mode"),
}
