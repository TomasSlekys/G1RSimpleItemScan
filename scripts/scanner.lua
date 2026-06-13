return function(config, utils, cache)
    local M = {}

    local highlighted = {}
    local highlightedByAddress = {}
    local cachedOutlineSubsystem = nil
    local outlineConfigApplied = false
    local activeScanId = 0

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

    local function removeHighlights(subsystem)
        subsystem = subsystem or getOutlineSubsystem()
        if not utils.isValid(subsystem) then
            return
        end

        for _, component in pairs(highlighted) do
            if utils.isValid(component) then
                pcall(function()
                    subsystem:QueueRemoveOutline(component)
                end)
            end
        end

        highlighted = {}
        highlightedByAddress = {}
        utils.debugLog("Removed temporary outlines")
    end

    local function addHighlight(subsystem, component)
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

        highlighted[#highlighted + 1] = component

        if address ~= nil then
            highlightedByAddress[address] = true
        end

        return true
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

        if #cache.items == 0 or (config.HIGHLIGHT_CORPSES and #cache.corpses == 0) then
            cache.refreshTargets()
        end

        cache.refreshCorpses()

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
        local count = 0
        local activeItems = {}
        local activeCorpses = {}

        for _, item in ipairs(cache.items) do
            if utils.isValid(item) then
                activeItems[#activeItems + 1] = item
                local ix, iy, iz = utils.getLocation(item)

                if ix then
                    local dx = ix - px
                    local dy = iy - py
                    local dz = iz - pz
                    local distanceSquared = dx * dx + dy * dy + dz * dz

                    if distanceSquared <= radiusSquared then
                        local component = utils.getInteractiveComponent(item)
                        if component and addHighlight(subsystem, component) then
                            count = count + 1
                        end
                    end
                end
            end
        end

        for _, corpse in ipairs(cache.corpses) do
            if utils.isValid(corpse) then
                activeCorpses[#activeCorpses + 1] = corpse
                local cx, cy, cz = utils.getLocation(corpse)

                if cx then
                    local dx = cx - px
                    local dy = cy - py
                    local dz = cz - pz
                    local distanceSquared = dx * dx + dy * dy + dz * dz

                    if distanceSquared <= radiusSquared then
                        local lootable, component = isLootableCorpse(corpse, pawn)
                        if lootable and addHighlight(subsystem, component) then
                            count = count + 1
                        end
                    end
                end
            end
        end

        cache.items = activeItems
        cache.corpses = activeCorpses
        cache.rebuildAddressSets()

        utils.debugLog("Highlighted " .. tostring(count) .. " nearby target(s)")

        ExecuteWithDelay(math.floor(config.DURATION * 1000), function()
            ExecuteInGameThread(function()
                if scanId == activeScanId then
                    removeHighlights()
                end
            end)
        end)
    end

    return M
end
