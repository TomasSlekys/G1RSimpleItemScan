return function(config, utils)
    local M = {
        items = {},
        corpses = {},
        chests = {},
        itemAddresses = {},
        corpseAddresses = {},
        chestAddresses = {},
        itemBuckets = {},
        chestBuckets = {},
    }

    local gameplayStatics = nil
    local classCache = {}
    local staticBucketSize = 1000.0

    local function rebuildAddressSet(actors)
        local addresses = {}

        for _, actor in ipairs(actors) do
            local address = utils.getAddress(actor)
            if address ~= nil then
                addresses[address] = true
            end
        end

        return addresses
    end

    local function getBucketCoords(x, y)
        if type(x) ~= "number" or type(y) ~= "number" then
            return nil, nil
        end

        return math.floor(x / staticBucketSize), math.floor(y / staticBucketSize)
    end

    local function bucketKey(bx, by)
        return tostring(bx) .. ":" .. tostring(by)
    end

    local function addStaticActorToBuckets(buckets, actor)
        local x, y = utils.getLocation(actor)
        local bx, by = getBucketCoords(x, y)
        if bx == nil then
            return
        end

        local key = bucketKey(bx, by)
        local bucket = buckets[key]
        if bucket == nil then
            bucket = {}
            buckets[key] = bucket
        end

        bucket[#bucket + 1] = actor
    end

    local function rebuildStaticBuckets(actors)
        local buckets = {}

        for _, actor in ipairs(actors) do
            if utils.isValid(actor) then
                addStaticActorToBuckets(buckets, actor)
            end
        end

        return buckets
    end

    local function resolveGameplayStatics()
        if utils.isValid(gameplayStatics) then
            return gameplayStatics
        end

        local ok, value = pcall(function()
            return StaticFindObject("/Script/Engine.Default__GameplayStatics")
        end)

        if ok and value ~= nil then
            gameplayStatics = value
            return gameplayStatics
        end

        return nil
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

        if ok and value ~= nil then
            classCache[classPath] = value
            return value
        end

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

    local function collectActors(className, classPath)
        local worldContext = utils.getPlayerController() or utils.getPlayerPawn()
        local gs = resolveGameplayStatics()
        local cls = resolveActorClass(classPath)

        if utils.isValid(worldContext) and gs ~= nil and cls ~= nil then
            local out = {}
            local ok = pcall(function()
                gs:GetAllActorsOfClass(worldContext, cls, out)
            end)

            if ok then
                local actors = {}
                for _, entry in ipairs(out) do
                    local actor = unwrapActor(entry)
                    if actor then
                        actors[#actors + 1] = actor
                    end
                end
                return actors
            end
        end

        local fallback = FindAllOf(className)
        if fallback then
            return fallback
        end

        return nil
    end

    function M.refreshTargets()
        local items = collectActors(config.ITEM_CLASS, config.ITEM_CLASS_PATH)
        local freshItems = {}
        local freshCorpses = {}
        local freshChests = {}
        local freshItemAddresses = {}
        local freshCorpseAddresses = {}
        local freshChestAddresses = {}

        if items then
            for _, item in pairs(items) do
                if utils.isValid(item) then
                    utils.addUniqueActor(freshItems, freshItemAddresses, item)
                end
            end
        end

        if config.HIGHLIGHT_CORPSES then
            local corpses = collectActors(config.CORPSE_CLASS, config.CORPSE_CLASS_PATH)
            if corpses then
                for _, corpse in pairs(corpses) do
                    if utils.isValid(corpse) then
                        utils.addUniqueActor(freshCorpses, freshCorpseAddresses, corpse)
                    end
                end
            end
        end

        if config.HIGHLIGHT_CHESTS then
            local chests = collectActors(config.CHEST_CLASS, config.CHEST_CLASS_PATH)
            if chests then
                for _, chest in pairs(chests) do
                    if utils.isValid(chest) then
                        utils.addUniqueActor(freshChests, freshChestAddresses, chest)
                    end
                end
            end
        end

        M.items = freshItems
        M.corpses = freshCorpses
        M.chests = freshChests
        M.itemAddresses = freshItemAddresses
        M.corpseAddresses = freshCorpseAddresses
        M.chestAddresses = freshChestAddresses
        M.itemBuckets = rebuildStaticBuckets(M.items)
        M.chestBuckets = rebuildStaticBuckets(M.chests)

        utils.debugLog("Cached " .. tostring(#M.items) .. " item(s), " .. tostring(#M.corpses) .. " corpse(s), and " .. tostring(#M.chests) .. " chest(s)")
    end

    function M.refreshCorpses()
        if not config.HIGHLIGHT_CORPSES then
            return
        end

        local corpses = collectActors(config.CORPSE_CLASS, config.CORPSE_CLASS_PATH)
        if not corpses then
            return
        end

        for _, corpse in pairs(corpses) do
            if utils.isValid(corpse) then
                utils.addUniqueActor(M.corpses, M.corpseAddresses, corpse)
            end
        end
    end

    function M.refreshStaticTargets()
        local changed = false

        local items = collectActors(config.ITEM_CLASS, config.ITEM_CLASS_PATH)
        if items then
            for _, item in pairs(items) do
                if utils.isValid(item) then
                    if utils.addUniqueActor(M.items, M.itemAddresses, item) then
                        addStaticActorToBuckets(M.itemBuckets, item)
                        changed = true
                    end
                end
            end
        end

        if config.HIGHLIGHT_CHESTS then
            local chests = collectActors(config.CHEST_CLASS, config.CHEST_CLASS_PATH)
            if chests then
                for _, chest in pairs(chests) do
                    if utils.isValid(chest) then
                        if utils.addUniqueActor(M.chests, M.chestAddresses, chest) then
                            addStaticActorToBuckets(M.chestBuckets, chest)
                            changed = true
                        end
                    end
                end
            end
        end

        if changed then
            utils.debugLog("Merged late-loaded static targets. Items=" .. tostring(#M.items) .. " Chests=" .. tostring(#M.chests))
        end
    end

    function M.rebuildAddressSets()
        M.itemAddresses = rebuildAddressSet(M.items)
        M.corpseAddresses = rebuildAddressSet(M.corpses)
        M.chestAddresses = rebuildAddressSet(M.chests)
        M.itemBuckets = rebuildStaticBuckets(M.items)
        M.chestBuckets = rebuildStaticBuckets(M.chests)
    end

    function M.queryNearbyStaticActors(targetKind, px, py, radius)
        local buckets = nil
        if targetKind == "item" then
            buckets = M.itemBuckets
        elseif targetKind == "chest" then
            buckets = M.chestBuckets
        else
            return {}
        end

        local minX, minY = getBucketCoords(px - radius, py - radius)
        local maxX, maxY = getBucketCoords(px + radius, py + radius)
        if minX == nil or maxX == nil then
            return {}
        end

        local results = {}
        local seen = {}
        for bx = minX, maxX do
            for by = minY, maxY do
                local bucket = buckets[bucketKey(bx, by)]
                if bucket ~= nil then
                    for _, actor in ipairs(bucket) do
                        local address = utils.getAddress(actor)
                        if address == nil or not seen[address] then
                            if address ~= nil then
                                seen[address] = true
                            end
                            results[#results + 1] = actor
                        end
                    end
                end
            end
        end

        return results
    end

    function M.registerItemStream()
        pcall(function()
            NotifyOnNewObject(config.ITEM_CLASS_PATH, function(obj)
                ExecuteInGameThread(function()
                    if utils.isValid(obj) then
                        if utils.addUniqueActor(M.items, M.itemAddresses, obj) then
                            addStaticActorToBuckets(M.itemBuckets, obj)
                        end
                    end
                end)
            end)
        end)
    end

    function M.registerChestStream()
        if not config.HIGHLIGHT_CHESTS then
            return
        end

        pcall(function()
            NotifyOnNewObject(config.CHEST_CLASS_PATH, function(obj)
                ExecuteInGameThread(function()
                    if utils.isValid(obj) then
                        if utils.addUniqueActor(M.chests, M.chestAddresses, obj) then
                            addStaticActorToBuckets(M.chestBuckets, obj)
                        end
                    end
                end)
            end)
        end)
    end

    return M
end
