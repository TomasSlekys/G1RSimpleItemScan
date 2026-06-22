return function(config, utils)
    local M = {}

    local classCache = {}
    local nearbyActorsSubsystem = nil
    local nearbyTrackedClasses = {}
    local nearbyFailuresLogged = {}

    local function logFailure(reason, detail)
        local key = tostring(reason) .. ":" .. tostring(detail or "")
        if nearbyFailuresLogged[key] then
            return
        end

        nearbyFailuresLogged[key] = true
        local message = "Native nearby query failed: " .. tostring(reason)
        if detail ~= nil then
            message = message .. " (" .. tostring(detail) .. ")"
        end
        utils.debugLog(message)
    end

    local function resolveActorClass(classPath)
        if type(classPath) ~= "string" or classPath == "" then
            return nil
        end

        local cached = classCache[classPath]
        if utils.isValid(cached) then
            return cached
        end

        local ok, value = pcall(function()
            return StaticFindObject(classPath)
        end)
        if ok and utils.isValid(value) then
            classCache[classPath] = value
            return value
        end

        return nil
    end

    local function getWorldAddress(object)
        if not utils.isValid(object) then
            return nil
        end

        local ok, world = pcall(function()
            return object:GetWorld()
        end)
        if not ok or not utils.isValid(world) then
            return nil
        end

        return utils.getAddress(world)
    end

    local function resolveSubsystem(worldContext)
        local wantedWorldAddress = getWorldAddress(worldContext)
        if utils.isValid(nearbyActorsSubsystem) then
            local subsystemWorldAddress = getWorldAddress(nearbyActorsSubsystem)
            if wantedWorldAddress == nil or subsystemWorldAddress == wantedWorldAddress then
                return nearbyActorsSubsystem
            end
        end

        nearbyActorsSubsystem = nil
        nearbyTrackedClasses = {}

        local candidates = FindAllOf("NearbyActorsSubsystem")
        if not candidates then
            logFailure("subsystem_not_found")
            return nil
        end

        for _, candidate in pairs(candidates) do
            if utils.isValid(candidate) then
                local candidateWorldAddress = getWorldAddress(candidate)
                if candidateWorldAddress ~= nil
                    and (wantedWorldAddress == nil or candidateWorldAddress == wantedWorldAddress) then
                    nearbyActorsSubsystem = candidate
                    return candidate
                end
            end
        end

        logFailure("current_world_subsystem_not_found")
        return nil
    end

    local function unwrapActor(value)
        if utils.isValid(value) then
            return value
        end

        local ok, unwrapped = pcall(function()
            return value:get()
        end)
        if ok and utils.isValid(unwrapped) then
            return unwrapped
        end

        return nil
    end

    local function collectActors(subsystem, classPath, center, radius)
        local actorClass = resolveActorClass(classPath)
        if not utils.isValid(actorClass) then
            logFailure("class_not_found", classPath)
            return nil
        end

        if not nearbyTrackedClasses[classPath] then
            local tracking = false
            local okTracking, result = pcall(function()
                return subsystem:IsTrackingActorClass(actorClass)
            end)
            if okTracking then
                tracking = result == true
            end

            if not tracking then
                local okTrack, trackError = pcall(function()
                    subsystem:TrackActorsOfClass(actorClass)
                end)
                if not okTrack then
                    logFailure("track_class_failed", trackError)
                    return nil
                end
            end

            nearbyTrackedClasses[classPath] = true
        end

        local ok, result = pcall(function()
            return subsystem:FindActorsOfClassInRadius(actorClass, center, radius)
        end)
        if not ok then
            logFailure("radius_call_failed", result)
            return nil
        end
        if result == nil then
            logFailure("radius_call_returned_nil", classPath)
            return nil
        end

        local okGet, unwrapped = pcall(function()
            return result:get()
        end)
        if okGet and unwrapped ~= nil then
            result = unwrapped
        end

        local actors = {}
        local okConvert, convertError = pcall(function()
            for _, entry in pairs(result) do
                local actor = unwrapActor(entry)
                if actor then
                    actors[#actors + 1] = actor
                end
            end
        end)
        if not okConvert then
            logFailure("result_conversion_failed", convertError)
            return nil
        end

        return actors
    end

    local function getPlayerCenter(pawn)
        local ok, center = pcall(function()
            return pawn:K2_GetActorLocation()
        end)
        if ok and center ~= nil then
            return center
        end

        local root = utils.getProp(pawn, "RootComponent")
        if not utils.isValid(root) then
            return nil
        end

        ok, center = pcall(function()
            return root:K2_GetComponentLocation()
        end)
        if ok and center ~= nil then
            return center
        end

        return utils.getProp(root, "RelativeLocation")
    end

    function M.queryNearbyTargets(pawn, radius)
        if not utils.isValid(pawn) then
            return nil
        end

        local center = getPlayerCenter(pawn)
        if center == nil then
            logFailure("player_location_unavailable")
            return nil
        end

        local subsystem = resolveSubsystem(pawn)
        if not utils.isValid(subsystem) then
            return nil
        end

        local items = collectActors(subsystem, config.ITEM_CLASS_PATH, center, radius)
        if items == nil then
            return nil
        end

        local corpses = {}
        if config.HIGHLIGHT_CORPSES then
            corpses = collectActors(subsystem, config.CORPSE_CLASS_PATH, center, radius)
            if corpses == nil then
                return nil
            end
        end

        local chests = {}
        if config.HIGHLIGHT_CHESTS then
            chests = collectActors(subsystem, config.CHEST_CLASS_PATH, center, radius)
            if chests == nil then
                return nil
            end
        end

        local pouches = {}
        if config.HIGHLIGHT_POUCHES then
            pouches = collectActors(subsystem, config.POUCH_CLASS_PATH, center, radius)
            if pouches == nil then
                return nil
            end
        end

        utils.debugLog(
            "Native nearby query: items=" .. tostring(#items)
            .. " corpses=" .. tostring(#corpses)
            .. " chests=" .. tostring(#chests)
            .. " pouches=" .. tostring(#pouches)
        )

        return {
            items = items,
            corpses = corpses,
            chests = chests,
            pouches = pouches,
        }
    end

    function M.reset()
        nearbyActorsSubsystem = nil
        nearbyTrackedClasses = {}
        nearbyFailuresLogged = {}
        utils.debugLog("Cleared native nearby-query state for world change")
    end

    return M
end
