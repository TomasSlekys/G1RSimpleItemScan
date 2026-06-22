local DEFAULT_CONFIG = {
    highlight_key = "X",
    radius = 2500.0,
    duration = 8.0,
    use_stealing_outline = true,
    stealing_outline_color = { 1.0, 0.2, 0.0 },
    use_thick_outline = true,
    highlight_corpses = true,
    highlight_chests = true,
    highlight_pouches = true,
    background_updates = true,
    remember_opened_chests = false,
    chest_memory_slot = "default",
    outline_alpha = 1.0,
    thickness_multiplier = 2.0,
    debug_mode = true,
    log_chest_state = false,
    log_corpse_state = false,
    log_item_state = false,
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

local function cfgColor(name, fallback)
    local value = localConfig[name]
    if type(value) == "table"
        and type(value[1]) == "number"
        and type(value[2]) == "number"
        and type(value[3]) == "number" then
        return {
            value[1],
            value[2],
            value[3],
        }
    end
    return fallback
end

local highlightKeyName = cfgString("highlight_key")
local outlineColor = cfgColor("outline_color", { 1.0, 1.0, 1.0 })
local stealingOutlineColor = cfgColor("stealing_outline_color", { 1.0, 0.2, 0.0 })

return {
    ITEM_CLASS_PATH = "/Script/G1R.ItemVisualWorld",
    CORPSE_CLASS_PATH = "/Script/Engine.Character",
    CHEST_CLASS_PATH = "/Script/G1R.InteractiveObjectActor",
    POUCH_CLASS_PATH = "/Script/G1R.PouchActor",
    HIGHLIGHT_KEY_NAME = highlightKeyName,
    HIGHLIGHT_KEY = Key[highlightKeyName] or Key[DEFAULT_CONFIG.highlight_key],
    RADIUS = cfgNumber("radius"),
    DURATION = cfgNumber("duration"),
    STENCIL_USAGE = 2,
    USE_STEALING_OUTLINE = cfgBoolean("use_stealing_outline"),
    STEALING_STENCIL_USAGE = 1,
    STEALING_OUTLINE_COLOR = stealingOutlineColor,
    USE_THICK_OUTLINE = cfgBoolean("use_thick_outline"),
    HIGHLIGHT_CORPSES = cfgBoolean("highlight_corpses"),
    HIGHLIGHT_CHESTS = cfgBoolean("highlight_chests"),
    HIGHLIGHT_POUCHES = cfgBoolean("highlight_pouches"),
    BACKGROUND_UPDATES = cfgBoolean("background_updates"),
    REMEMBER_OPENED_CHESTS = cfgBoolean("remember_opened_chests"),
    CHEST_MEMORY_SLOT = cfgString("chest_memory_slot"),
    OUTLINE_ALPHA = cfgNumber("outline_alpha"),
    OUTLINE_COLOR = outlineColor,
    THICKNESS_MULTIPLIER = cfgNumber("thickness_multiplier"),
    DEBUG_MODE = cfgBoolean("debug_mode"),
    LOG_CHEST_STATE = cfgBoolean("log_chest_state"),
    LOG_CORPSE_STATE = cfgBoolean("log_corpse_state"),
    LOG_ITEM_STATE = cfgBoolean("log_item_state"),
}
