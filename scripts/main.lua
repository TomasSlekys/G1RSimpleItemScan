local MOD_NAME = "SimpleItemScan"

local SCRIPT_ROOT = "Mods/SimpleItemScan/Scripts/"

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

RegisterKeyBind(config.HIGHLIGHT_KEY, function()
    ExecuteInGameThread(function()
        scanner.scanAndHighlight()
    end)
end)
