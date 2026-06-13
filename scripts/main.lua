local MOD_NAME = "SimpleItemScan"

local HIGHLIGHT_KEY = Key.X
local ITEM_CLASS = "ItemVisualWorld"
local CORPSE_CLASS = "GothicCharacter"

local RADIUS = 2500.0       -- 25 metres, Gothic/UE units
local DURATION = 5.0        -- seconds
local STENCIL_USAGE = 2
local USE_THICK_OUTLINE = true
local HIGHLIGHT_CORPSES = true
local OUTLINE_ALPHA = 1.0
local THICKNESS_MULTIPLIER = 2.0
local DEBUG_MODE = true

local highlighted = {}
local cachedItems = {}
local cachedCorpses = {}
local cachedOutlineSubsystem = nil
local outlineConfigApplied = false

local function log(msg)
    print("[" .. MOD_NAME .. "] " .. msg .. "\n")
end

local function isValid(obj)
    if obj == nil then return false end
    local ok, valid = pcall(function()
        return obj:IsValid()
    end)
    return ok and valid
end

local function debugLog(msg)
    if not DEBUG_MODE then
        return
    end

    log(msg)
end

local function getProp(obj, prop)
    local ok, value = pcall(function()
        return obj[prop]
    end)
    if ok then return value end
    return nil
end

local function setProp(obj, prop, value)
    local ok = pcall(function()
        obj[prop] = value
    end)
    return ok
end

local function getOutlineSubsystem()
    if isValid(cachedOutlineSubsystem) then
        return cachedOutlineSubsystem
    end

    local list = FindAllOf("OutlineSubsystem")
    if not list then return nil end

    for _, obj in pairs(list) do
        if isValid(obj) then
            cachedOutlineSubsystem = obj
            return obj
        end
    end

    return nil
end

local function applyOutlineConfig(subsystem)
    if outlineConfigApplied then
        return
    end

    subsystem = subsystem or getOutlineSubsystem()
    if not isValid(subsystem) then
        return
    end

    local config = getProp(subsystem, "Config")
    if not isValid(config) then
        return
    end

    local closestThickness = getProp(config, "OutlineClosestThickness")
    local farthestThickness = getProp(config, "OutlineFarthestThickness")

    setProp(config, "OutlineClosestAlpha", OUTLINE_ALPHA)
    setProp(config, "OutlineFarthestAlpha", OUTLINE_ALPHA)

    if type(closestThickness) == "number" then
        setProp(config, "OutlineClosestThickness", closestThickness * THICKNESS_MULTIPLIER)
    end

    if type(farthestThickness) == "number" then
        setProp(config, "OutlineFarthestThickness", farthestThickness * THICKNESS_MULTIPLIER)
    end

    outlineConfigApplied = true
    debugLog("Applied outline visibility config")
end

local function refreshTargetCache()
    local items = FindAllOf(ITEM_CLASS)
    local freshItems = {}
    local freshCorpses = {}

    if items then
        for _, item in pairs(items) do
            if isValid(item) then
                freshItems[#freshItems + 1] = item
            end
        end
    end

    if HIGHLIGHT_CORPSES then
        local corpses = FindAllOf(CORPSE_CLASS)

        if corpses then
            for _, corpse in pairs(corpses) do
                if isValid(corpse) then
                    freshCorpses[#freshCorpses + 1] = corpse
                end
            end
        end
    end

    cachedItems = freshItems
    cachedCorpses = freshCorpses
    debugLog("Cached " .. tostring(#cachedItems) .. " item(s) and " .. tostring(#cachedCorpses) .. " corpse(s)")
end

local function getPlayerPawn()
    local controllers = FindAllOf("PlayerController")
    if not controllers then return nil end

    for _, pc in pairs(controllers) do
        if isValid(pc) then
            local pawn = getProp(pc, "Pawn")
            if isValid(pawn) then
                return pawn
            end
        end
    end

    return nil
end

local function getLocation(actor)
    if not isValid(actor) then return nil end

    local root = getProp(actor, "RootComponent")
    if root then
        local loc = getProp(root, "RelativeLocation")
        if loc and loc.X and loc.Y and loc.Z then
            return loc.X, loc.Y, loc.Z
        end
    end

    local ok, loc = pcall(function()
        return actor:K2_GetActorLocation()
    end)

    if ok and loc and loc.X and loc.Y and loc.Z then
        return loc.X, loc.Y, loc.Z
    end

    return nil
end

local function getInteractiveComponent(actor)
    local component = getProp(actor, "m_InteractiveComponent")
    if isValid(component) then
        return component
    end
    return nil
end

local function isLootableCorpse(actor, pawn)
    if not HIGHLIGHT_CORPSES or not isValid(actor) then
        return false, nil
    end

    if pawn ~= nil and actor == pawn then
        return false, nil
    end

    local ragdollComponent = getProp(actor, "m_RagdollComponent")
    if not isValid(ragdollComponent) then
        return false, nil
    end

    if getProp(ragdollComponent, "m_IsRagdollActive") ~= true then
        return false, nil
    end

    local component = getInteractiveComponent(actor)
    if not component then
        return false, nil
    end

    if getProp(component, "m_ForceDisableInteraction") == true then
        return false, nil
    end

    if getProp(component, "m_CanBeUsed") == false then
        return false, nil
    end

    return true, component
end

local function removeHighlights(subsystem)
    subsystem = subsystem or getOutlineSubsystem()
    if not isValid(subsystem) then return end

    for _, component in pairs(highlighted) do
        if isValid(component) then
            pcall(function()
                subsystem:QueueRemoveOutline(component)
            end)
        end
    end

    highlighted = {}
    debugLog("Removed temporary outlines")
end

local function scanAndHighlight()
    local subsystem = getOutlineSubsystem()
    local pawn = getPlayerPawn()

    if not isValid(subsystem) then
        debugLog("OutlineSubsystem not found")
        return
    end

    if not isValid(pawn) then
        debugLog("Player pawn not found")
        return
    end

    if #cachedItems == 0 and (not HIGHLIGHT_CORPSES or #cachedCorpses == 0) then
        refreshTargetCache()
    end

    applyOutlineConfig(subsystem)
    removeHighlights(subsystem)

    pcall(function()
        subsystem:SetIsSystemEnabled(true)
    end)

    local px, py, pz = getLocation(pawn)
    if not px then
        debugLog("Player location not found")
        return
    end

    local radiusSquared = RADIUS * RADIUS
    local count = 0
    local activeItems = {}
    local activeCorpses = {}

    for _, item in ipairs(cachedItems) do
        if isValid(item) then
            activeItems[#activeItems + 1] = item
            local ix, iy, iz = getLocation(item)

            if ix then
                local dx = ix - px
                local dy = iy - py
                local dz = iz - pz
                local distanceSquared = dx * dx + dy * dy + dz * dz

                if distanceSquared <= radiusSquared then
                    local component = getInteractiveComponent(item)

                    if component then
                        local ok = pcall(function()
                            subsystem:AddOutline(component, STENCIL_USAGE, USE_THICK_OUTLINE)
                        end)

                        if ok then
                            highlighted[#highlighted + 1] = component
                            count = count + 1
                        end
                    end
                end
            end
        end
    end

    for _, corpse in ipairs(cachedCorpses) do
        if isValid(corpse) then
            activeCorpses[#activeCorpses + 1] = corpse
            local cx, cy, cz = getLocation(corpse)

            if cx then
                local dx = cx - px
                local dy = cy - py
                local dz = cz - pz
                local distanceSquared = dx * dx + dy * dy + dz * dz

                if distanceSquared <= radiusSquared then
                    local lootable, component = isLootableCorpse(corpse, pawn)

                    if lootable then
                        local ok = pcall(function()
                            subsystem:AddOutline(component, STENCIL_USAGE, USE_THICK_OUTLINE)
                        end)

                        if ok then
                            highlighted[#highlighted + 1] = component
                            count = count + 1
                        end
                    end
                end
            end
        end
    end

    cachedItems = activeItems
    cachedCorpses = activeCorpses

    debugLog("Highlighted " .. tostring(count) .. " nearby target(s)")

    ExecuteWithDelay(math.floor(DURATION * 1000), function()
        ExecuteInGameThread(function()
            removeHighlights()
        end)
    end)
end

log("Loaded. Press X to temporarily highlight nearby items and lootable corpses.")
debugLog("Debug mode enabled")

ExecuteInGameThread(function()
    refreshTargetCache()
end)

RegisterKeyBind(HIGHLIGHT_KEY, function()
    ExecuteInGameThread(function()
        scanAndHighlight()
    end)
end)
