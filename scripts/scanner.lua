return function(config, utils, cache)
    local M = {}

    local highlighted = {}
    local highlightedByAddress = {}
    local cachedOutlineSubsystem = nil
    local outlineConfigApplied = false
    local activeScanId = 0
    local itemLocationCache = {}
    local chestLocationCache = {}
    local chestTypeCache = {}
    local scanBatchSize = 64
    local lastCorpseRefreshMs = 0
    local corpseRefreshIntervalMs = 1000
    local chestKeywords = {
        "chest", "box", "barrel", "basket", "container", "safe", "crate",
        "cupboard", "wardrobe", "locker", "urn", "tomb", "sarcophagus"
    }

    local function nowMs()
        local ok, value = pcall(function()
            return os.clock()
        end)

        if ok and type(value) == "number" then
            return math.floor(value * 1000)
        end

        return 0
    end

    local function getCachedStaticLocation(cacheTable, actor)
        local address = utils.getAddress(actor)
        if address ~= nil then
            local cached = cacheTable[address]
            if cached then
                return cached.x, cached.y, cached.z
            end
        end

        local x, y, z = utils.getLocation(actor)
        if address ~= nil and x ~= nil then
            cacheTable[address] = {
                x = x,
                y = y,
                z = z,
            }
        end

        return x, y, z
    end

    local function maybeRefreshCorpses()
        if not config.HIGHLIGHT_CORPSES then
            return
        end

        local currentMs = nowMs()
        if #cache.corpses == 0 or currentMs - lastCorpseRefreshMs >= corpseRefreshIntervalMs then
            cache.refreshCorpses()
            lastCorpseRefreshMs = currentMs
        end
    end

    local function getOutlineSubsystem()
        if utils.isValid(cachedOutlineSubsystem) then
            return cachedOutlineSubsystem
        end

        local list = FindAllOf("OutlineSubsystem")
        if not list then
            return nil
        end

        for _, obj in pairs(list) do
            if utils.isValid(obj) then
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
        if not utils.isValid(subsystem) then
            return
        end

        local configObject = utils.getProp(subsystem, "Config")
        if not utils.isValid(configObject) then
            return
        end

        local closestThickness = utils.getProp(configObject, "OutlineClosestThickness")
        local farthestThickness = utils.getProp(configObject, "OutlineFarthestThickness")

        utils.setProp(configObject, "OutlineClosestAlpha", config.OUTLINE_ALPHA)
        utils.setProp(configObject, "OutlineFarthestAlpha", config.OUTLINE_ALPHA)

        if type(closestThickness) == "number" then
            utils.setProp(configObject, "OutlineClosestThickness", closestThickness * config.THICKNESS_MULTIPLIER)
        end

        if type(farthestThickness) == "number" then
            utils.setProp(configObject, "OutlineFarthestThickness", farthestThickness * config.THICKNESS_MULTIPLIER)
        end

        outlineConfigApplied = true
        utils.debugLog("Applied outline visibility config")
    end

    local function isLootableCorpse(actor, pawn)
        if not config.HIGHLIGHT_CORPSES or not utils.isValid(actor) then
            return false, nil
        end

        if pawn ~= nil and actor == pawn then
            return false, nil
        end

        local ragdollComponent = utils.getProp(actor, "m_RagdollComponent")
        if not utils.isValid(ragdollComponent) then
            return false, nil
        end

        if utils.getProp(ragdollComponent, "m_IsRagdollActive") ~= true then
            return false, nil
        end

        local component = utils.getInteractiveComponent(actor)
        if not component then
            return false, nil
        end

        if utils.getProp(component, "m_ForceDisableInteraction") == true then
            return false, nil
        end

        if utils.getProp(component, "m_CanBeUsed") == false then
            return false, nil
        end

        return true, component
    end

    local function isLikelyLootContainerType(actor)
        if not config.HIGHLIGHT_CHESTS or not utils.isValid(actor) then
            return false
        end

        local address = utils.getAddress(actor)
        if address ~= nil and chestTypeCache[address] ~= nil then
            return chestTypeCache[address]
        end

        local ok, fullName = pcall(function()
            return actor:GetFullName()
        end)
        if not ok then
            return false
        end

        fullName = tostring(fullName or "")
        local nameLower = string.lower(fullName)

        if string.find(nameLower, "worldpointactor", 1, true) then
            if address ~= nil then
                chestTypeCache[address] = false
            end
            return false
        end

        if string.find(nameLower, "itai", 1, true) then
            if address ~= nil then
                chestTypeCache[address] = false
            end
            return false
        end

        if string.find(nameLower, "sit", 1, true)
            or string.find(nameLower, "bench", 1, true)
            or string.find(nameLower, "chair", 1, true)
            or string.find(nameLower, "bed", 1, true)
            or string.find(nameLower, "door", 1, true)
            or string.find(nameLower, "lever", 1, true)
            or string.find(nameLower, "button", 1, true)
            or string.find(nameLower, "ladder", 1, true)
            or string.find(nameLower, "wheel", 1, true)
            or string.find(nameLower, "gate", 1, true) then
            if address ~= nil then
                chestTypeCache[address] = false
            end
            return false
        end

        local matchesKeyword = false
        for _, keyword in ipairs(chestKeywords) do
            if string.find(nameLower, keyword, 1, true) then
                matchesKeyword = true
                break
            end
        end

        if not matchesKeyword then
            if address ~= nil then
                chestTypeCache[address] = false
            end
            return false
        end

        local hasLootData = false
        if utils.getProp(actor, "m_Inventory") ~= nil
            or utils.getProp(actor, "m_Items") ~= nil
            or utils.getProp(actor, "m_LootTable") ~= nil then
            hasLootData = true
        end

        local component = utils.getInteractiveComponent(actor)
        if component and not hasLootData then
            if utils.getProp(component, "m_Inventory") ~= nil
                or utils.getProp(component, "m_Items") ~= nil
                or utils.getProp(component, "m_LootTable") ~= nil then
                hasLootData = true
            end
        end

        if not hasLootData then
            if utils.getProp(actor, "m_Locked") == true then
                hasLootData = true
            else
                local keyName = utils.getProp(actor, "m_KeyName")
                if keyName ~= nil then
                    local keyString = tostring(keyName)
                    if keyString ~= "" and keyString ~= "None" then
                        hasLootData = true
                    end
                end
            end
        end

        local result = component ~= nil and hasLootData
        if address ~= nil then
            chestTypeCache[address] = result
        end

        return result
    end

    local function resolveHighlightedComponent(entry)
        if type(entry) ~= "table" then
            return nil
        end

        local actor = entry.actor
        if not utils.isValid(actor) then
            return nil
        end

        if type(entry.resolveComponent) ~= "function" then
            return nil
        end

        local ok, component = pcall(entry.resolveComponent, actor)
        if not ok or not utils.isValid(component) then
            return nil
        end

        return component
    end

    local function removeHighlights(subsystem)
        subsystem = subsystem or getOutlineSubsystem()
        if not utils.isValid(subsystem) then
            return
        end

        for _, entry in pairs(highlighted) do
            local component = resolveHighlightedComponent(entry)
            if component then
                pcall(function()
                    subsystem:QueueRemoveOutline(component)
                end)
            end
        end

        highlighted = {}
        highlightedByAddress = {}
        utils.debugLog("Removed temporary outlines")
    end

    local function addHighlight(subsystem, actor, component, resolveComponent)
        local address = utils.getAddress(component)
        if address ~= nil and highlightedByAddress[address] then
            return false
        end

        local ok = pcall(function()
            subsystem:AddOutline(component, config.STENCIL_USAGE, config.USE_THICK_OUTLINE)
        end)

        if not ok then
            return false
        end

        highlighted[#highlighted + 1] = {
            actor = actor,
            resolveComponent = resolveComponent,
        }

        if address ~= nil then
            highlightedByAddress[address] = true
        end

        return true
    end

    local function processScanBatch(subsystem, pawn, px, py, pz, radiusSquared, state)
        local processed = 0

        while processed < scanBatchSize do
            local actor = nil
            local list = nil
            local targetKind = nil

            if state.phase == "items" then
                list = cache.items
                targetKind = "item"
            elseif state.phase == "corpses" then
                list = cache.corpses
                targetKind = "corpse"
            elseif state.phase == "chests" then
                list = cache.chests
                targetKind = "chest"
            else
                break
            end

            state.index = state.index + 1
            actor = list[state.index]

            if actor == nil then
                if state.phase == "items" then
                    state.phase = "corpses"
                elseif state.phase == "corpses" then
                    state.phase = "chests"
                else
                    state.phase = "done"
                end
                state.index = 0
            else
                processed = processed + 1

                if utils.isValid(actor) then
                    if targetKind == "item" then
                        state.activeItems[#state.activeItems + 1] = actor
                    elseif targetKind == "corpse" then
                        state.activeCorpses[#state.activeCorpses + 1] = actor
                    else
                        state.activeChests[#state.activeChests + 1] = actor
                    end

                    local tx, ty, tz = nil, nil, nil
                    if targetKind == "item" then
                        tx, ty, tz = getCachedStaticLocation(itemLocationCache, actor)
                    elseif targetKind == "corpse" then
                        tx, ty, tz = utils.getLocation(actor)
                    else
                        tx, ty, tz = getCachedStaticLocation(chestLocationCache, actor)
                    end

                    if tx then
                        local dx = tx - px
                        local dy = ty - py
                        local dz = tz - pz
                        local distanceSquared = dx * dx + dy * dy + dz * dz

                        if distanceSquared <= radiusSquared then
                            if targetKind == "item" then
                                local component = utils.getInteractiveComponent(actor)
                                if component and addHighlight(subsystem, actor, component, utils.getInteractiveComponent) then
                                    state.count = state.count + 1
                                end
                            elseif targetKind == "corpse" then
                                local lootable, component = isLootableCorpse(actor, pawn)
                                if lootable and addHighlight(subsystem, actor, component, utils.getInteractiveComponent) then
                                    state.count = state.count + 1
                                end
                            else
                                if isLikelyLootContainerType(actor) then
                                    local component = utils.getInteractiveComponent(actor)
                                    if component and addHighlight(subsystem, actor, component, utils.getInteractiveComponent) then
                                        state.count = state.count + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        return state.phase == "done"
    end

    function M.scanAndHighlight()
        local subsystem = getOutlineSubsystem()
        local pawn = utils.getPlayerPawn()

        if not utils.isValid(subsystem) then
            utils.debugLog("OutlineSubsystem not found")
            return
        end

        if not utils.isValid(pawn) then
            utils.debugLog("Player pawn not found")
            return
        end

        if #cache.items == 0
            or (config.HIGHLIGHT_CORPSES and #cache.corpses == 0)
            or (config.HIGHLIGHT_CHESTS and #cache.chests == 0) then
            cache.refreshTargets()
        end

        maybeRefreshCorpses()

        activeScanId = activeScanId + 1
        local scanId = activeScanId

        applyOutlineConfig(subsystem)

        pcall(function()
            subsystem:SetIsSystemEnabled(true)
        end)

        local px, py, pz = utils.getLocation(pawn)
        if not px then
            utils.debugLog("Player location not found")
            return
        end

        local radiusSquared = config.RADIUS * config.RADIUS
        local state = {
            phase = "items",
            index = 0,
            count = 0,
            activeItems = {},
            activeCorpses = {},
            activeChests = {},
        }

        local function finishScan()
            cache.items = state.activeItems
            cache.corpses = state.activeCorpses
            cache.chests = state.activeChests
            cache.rebuildAddressSets()

            utils.debugLog("Highlighted " .. tostring(state.count) .. " nearby target(s)")

            ExecuteWithDelay(math.floor(config.DURATION * 1000), function()
                ExecuteInGameThread(function()
                    if scanId == activeScanId then
                        removeHighlights()
                    end
                end)
            end)
        end

        local function runNextBatch()
            ExecuteInGameThread(function()
                if scanId ~= activeScanId then
                    return
                end

                local done = processScanBatch(subsystem, pawn, px, py, pz, radiusSquared, state)
                if done then
                    finishScan()
                else
                    ExecuteWithDelay(0, runNextBatch)
                end
            end)
        end

        runNextBatch()
    end

    return M
end
