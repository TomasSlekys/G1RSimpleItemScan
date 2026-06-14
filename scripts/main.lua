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
local MOD_NAME = SCRIPT_ROOT:match("/Mods/([^/]+)/Scripts/$") or "SimpleItemScan"

local config = dofile(SCRIPT_ROOT .. "config_loader.lua")
local utils = dofile(SCRIPT_ROOT .. "utils.lua")(MOD_NAME, config.DEBUG_MODE)
local cache = dofile(SCRIPT_ROOT .. "cache.lua")(config, utils)
local chestMemory = dofile(SCRIPT_ROOT .. "chest_memory.lua")(config, utils)
local scanner = dofile(SCRIPT_ROOT .. "scanner.lua")(config, utils, cache, chestMemory)

utils.log("Loaded. Press " .. config.HIGHLIGHT_KEY_NAME .. " to temporarily highlight nearby items and lootable corpses.")
utils.debugLog("Debug mode enabled")

cache.registerItemStream()
cache.registerChestStream()
chestMemory.registerHooks()

ExecuteInGameThread(function()
    cache.refreshTargets()
end)

ExecuteWithDelay(3000, function()
    ExecuteInGameThread(function()
        cache.refreshStaticTargets()
    end)
end)

local function reapplyOutlineSettingsOnce()
    ExecuteInGameThread(function()
        scanner.refreshOutlineSettings()
    end)
end

ExecuteWithDelay(2000, reapplyOutlineSettingsOnce)
ExecuteWithDelay(5000, reapplyOutlineSettingsOnce)

RegisterKeyBind(config.HIGHLIGHT_KEY, function()
    ExecuteInGameThread(function()
        scanner.scanAndHighlight()
    end)
end)
