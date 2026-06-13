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
local scanner = dofile(SCRIPT_ROOT .. "scanner.lua")(config, utils, cache)

utils.log("Loaded. Press " .. config.HIGHLIGHT_KEY_NAME .. " to temporarily highlight nearby items and lootable corpses.")
utils.debugLog("Debug mode enabled")

ExecuteInGameThread(function()
    cache.refreshTargets()
end)

cache.registerItemStream()
cache.registerChestStream()

RegisterKeyBind(config.HIGHLIGHT_KEY, function()
    ExecuteInGameThread(function()
        scanner.scanAndHighlight()
    end)
end)
