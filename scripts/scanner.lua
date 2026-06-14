return function(config, utils, cache, chestMemory)
    local M = {}

    local highlighted = {}
    local highlightedByAddress = {}
    local cachedOutlineSubsystem = nil
    local configuredOutlineConfigAddress = nil
    local baseClosestThickness = nil
    local baseFarthestThickness = nil
    local activeScanId = 0
    local itemLocationCache = {}
    local chestLocationCache = {}
    local chestTypeCache = {}
    local chestStateLogged = {}
    local scanBatchSize = 16
    local lastCorpseRefreshMs = 0
    local corpseRefreshIntervalMs = 1000
    local corpseRefreshQueued = false
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

    local function elapsedMs(startMs)
        return nowMs() - startMs
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

    local function queueCorpseRefresh()
        if not config.HIGHLIGHT_CORPSES then
            return
        end

        local currentMs = nowMs()
        if corpseRefreshQueued then
            return
        end

        if #cache.corpses == 0 or currentMs - lastCorpseRefreshMs >= corpseRefreshIntervalMs then
            corpseRefreshQueued = true

            ExecuteWithDelay(0, function()
                ExecuteInGameThread(function()
                    local refreshStartMs = nowMs()
                    cache.refreshCorpses()
                    lastCorpseRefreshMs = nowMs()
                    corpseRefreshQueued = false
                    utils.debugLog("ScanTiming corpse_refresh=" .. tostring(elapsedMs(refreshStartMs)) .. "ms corpses=" .. tostring(#cache.corpses))
                end)
            end)
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
        subsystem = subsystem or getOutlineSubsystem()
        if not utils.isValid(subsystem) then
            return
        end

        local configObject = utils.getProp(subsystem, "Config")
        if not utils.isValid(configObject) then
            return
        end

        local configAddress = utils.getAddress(configObject)
        if configAddress ~= configuredOutlineConfigAddress then
            configuredOutlineConfigAddress = configAddress
            baseClosestThickness = utils.getProp(configObject, "OutlineClosestThickness")
            baseFarthestThickness = utils.getProp(configObject, "OutlineFarthestThickness")
        end

        utils.setProp(configObject, "OutlineClosestAlpha", config.OUTLINE_ALPHA)
        utils.setProp(configObject, "OutlineFarthestAlpha", config.OUTLINE_ALPHA)

        if type(baseClosestThickness) == "number" then
            utils.setProp(configObject, "OutlineClosestThickness", baseClosestThickness * config.THICKNESS_MULTIPLIER)
        end

        if type(baseFarthestThickness) == "number" then
            utils.setProp(configObject, "OutlineFarthestThickness", baseFarthestThickness * config.THICKNESS_MULTIPLIER)
        end

        local stencilMap = utils.getProp(configObject, "StencilOutlineData")
        if stencilMap ~= nil and type(config.OUTLINE_COLOR) == "table" then
            local currentFn = nil

            local function stencilForEachCallback(_, valueProxy)
                if currentFn == nil then
                    return
                end

                local value = valueProxy
                local okGet = pcall(function()
                    local unwrapped = valueProxy:get()
                    if unwrapped ~= nil then
                        value = unwrapped
                    end
                end)

                if not okGet then
                    value = valueProxy
                end

                local color = utils.getProp(value, "Color")
                if color ~= nil then
                    currentFn(color, value)
                end
            end

            local function eachStencilColor(fn)
                currentFn = fn
                local ok = pcall(function()
                    stencilMap:ForEach(stencilForEachCallback)
                end)
                currentFn = nil
                return ok
            end

            local function applyStencilColor(color, value)
                utils.setProp(color, "R", config.OUTLINE_COLOR[1])
                utils.setProp(color, "G", config.OUTLINE_COLOR[2])
                utils.setProp(color, "B", config.OUTLINE_COLOR[3])
                utils.setProp(color, "A", config.OUTLINE_ALPHA)
                utils.setProp(value, "Color", color)
            end

            local pushed = false
            local changed = eachStencilColor(applyStencilColor)
            if changed then
                pcall(function()
                    local world = subsystem:GetWorld()
                    if world ~= nil then
                        configObject:UpdateColorTable(world)
                        pushed = true
                    end
                end)
            end

            if pushed then
                utils.debugLog("Applied custom outline color")
            end
        end

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

        if utils.getProp(component, "m_CanBeUsed") == false then
            return false, nil
        end

        local mesh = utils.getProp(actor, "Mesh")
        if utils.isValid(mesh) then
            return true, mesh
        end

        return true, component
    end

    local function resolveCorpseOutlineComponent(actor)
        local mesh = utils.getProp(actor, "Mesh")
        if utils.isValid(mesh) then
            return mesh
        end

        return utils.getInteractiveComponent(actor)
    end

    local function isLikelyLootContainerType(actor)
        if not config.HIGHLIGHT_CHESTS or not utils.isValid(actor) then
            return false
        end

        local address = utils.getAddress(actor)
        if chestMemory and chestMemory.isRemembered(actor) then
            if address ~= nil then
                chestTypeCache[address] = false
            end
            return false
        end

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
        local blockReason = nil

        if string.find(nameLower, "worldpointactor", 1, true) then
            blockReason = "worldpointactor"
            if address ~= nil then
                chestTypeCache[address] = false
            end
            if config.LOG_CHEST_STATE and address ~= nil and not chestStateLogged[address] then
                chestStateLogged[address] = true
                utils.log("ChestState " .. tostring(address) .. " rejected: " .. blockReason .. " | " .. fullName)
            end
            return false
        end

        if string.find(nameLower, "itai", 1, true) then
            blockReason = "itai"
            if address ~= nil then
                chestTypeCache[address] = false
            end
            if config.LOG_CHEST_STATE and address ~= nil and not chestStateLogged[address] then
                chestStateLogged[address] = true
                utils.log("ChestState " .. tostring(address) .. " rejected: " .. blockReason .. " | " .. fullName)
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
            blockReason = "excluded_interactable"
            if address ~= nil then
                chestTypeCache[address] = false
            end
            if config.LOG_CHEST_STATE and address ~= nil and not chestStateLogged[address] then
                chestStateLogged[address] = true
                utils.log("ChestState " .. tostring(address) .. " rejected: " .. blockReason .. " | " .. fullName)
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
            blockReason = "no_keyword_match"
            if address ~= nil then
                chestTypeCache[address] = false
            end
            if config.LOG_CHEST_STATE and address ~= nil and not chestStateLogged[address] then
                chestStateLogged[address] = true
                utils.log("ChestState " .. tostring(address) .. " rejected: " .. blockReason .. " | " .. fullName)
            end
            return false
        end

        local actorLocked = utils.getProp(actor, "m_Locked")
        local actorKeyName = utils.getProp(actor, "m_KeyName")
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
            if actorLocked == true then
                hasLootData = true
            else
                if actorKeyName ~= nil then
                    local keyString = tostring(actorKeyName)
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

        if config.LOG_CHEST_STATE and address ~= nil and not chestStateLogged[address] then
            chestStateLogged[address] = true
            utils.log("ChestState " .. tostring(address) .. " result=" .. tostring(result) .. " | name=" .. fullName)
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
        local startingPhase = state.phase

        while processed < scanBatchSize do
            local actor = nil
            local list = nil
            local targetKind = nil

            if state.phase == "items" then
                list = state.itemCandidates
                targetKind = "item"
            elseif state.phase == "corpses" then
                list = cache.corpses
                targetKind = "corpse"
            elseif state.phase == "chests" then
                list = state.chestCandidates
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
                                if lootable and addHighlight(subsystem, actor, component, resolveCorpseOutlineComponent) then
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

        if startingPhase == "items" then
            state.processedItems = state.index
        elseif startingPhase == "corpses" then
            state.processedCorpses = state.index
        elseif startingPhase == "chests" then
            state.processedChests = state.index
        end

        return state.phase == "done"
    end

    function M.scanAndHighlight()
        local scanStartMs = nowMs()
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
            local refreshStartMs = nowMs()
            cache.refreshTargets()
            utils.debugLog(
                "ScanTiming target_refresh=" .. tostring(elapsedMs(refreshStartMs))
                .. "ms items=" .. tostring(#cache.items)
                .. " corpses=" .. tostring(#cache.corpses)
                .. " chests=" .. tostring(#cache.chests)
            )
        end

        activeScanId = activeScanId + 1
        local scanId = activeScanId

        local outlineStartMs = nowMs()
        applyOutlineConfig(subsystem)
        utils.debugLog("ScanTiming outline_config=" .. tostring(elapsedMs(outlineStartMs)) .. "ms")

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
            itemCandidates = cache.queryNearbyStaticActors("item", px, py, config.RADIUS),
            chestCandidates = cache.queryNearbyStaticActors("chest", px, py, config.RADIUS),
            processedItems = 0,
            processedCorpses = 0,
            processedChests = 0,
            batchCount = 0,
        }

        local function finishScan()
            cache.items = state.activeItems
            cache.corpses = state.activeCorpses
            cache.chests = state.activeChests
            cache.rebuildAddressSets()

            utils.debugLog("Highlighted " .. tostring(state.count) .. " nearby target(s)")
            utils.debugLog(
                "ScanTiming total=" .. tostring(elapsedMs(scanStartMs))
                .. "ms batches=" .. tostring(state.batchCount)
                .. " item_candidates=" .. tostring(#state.itemCandidates)
                .. " chest_candidates=" .. tostring(#state.chestCandidates)
                .. " items=" .. tostring(#state.activeItems)
                .. " corpses=" .. tostring(#state.activeCorpses)
                .. " chests=" .. tostring(#state.activeChests)
            )

            queueCorpseRefresh()

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

                state.batchCount = state.batchCount + 1
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
