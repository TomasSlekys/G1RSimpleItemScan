return function(config, utils)
    local M = {
        items = {},
        corpses = {},
        itemAddresses = {},
        corpseAddresses = {},
    }

    function M.refreshTargets()
        local items = FindAllOf(config.ITEM_CLASS)
        local freshItems = {}
        local freshCorpses = {}
        local freshItemAddresses = {}
        local freshCorpseAddresses = {}

        if items then
            for _, item in pairs(items) do
                if utils.isValid(item) then
                    utils.addUniqueActor(freshItems, freshItemAddresses, item)
                end
            end
        end

        if config.HIGHLIGHT_CORPSES then
            local corpses = FindAllOf(config.CORPSE_CLASS)
            if corpses then
                for _, corpse in pairs(corpses) do
                    if utils.isValid(corpse) then
                        utils.addUniqueActor(freshCorpses, freshCorpseAddresses, corpse)
                    end
                end
            end
        end

        M.items = freshItems
        M.corpses = freshCorpses
        M.itemAddresses = freshItemAddresses
        M.corpseAddresses = freshCorpseAddresses

        utils.debugLog("Cached " .. tostring(#M.items) .. " item(s) and " .. tostring(#M.corpses) .. " corpse(s)")
    end

    function M.refreshCorpses()
        if not config.HIGHLIGHT_CORPSES then
            return
        end

        local corpses = FindAllOf(config.CORPSE_CLASS)
        if not corpses then
            return
        end

        for _, corpse in pairs(corpses) do
            if utils.isValid(corpse) then
                utils.addUniqueActor(M.corpses, M.corpseAddresses, corpse)
            end
        end
    end

    function M.rebuildAddressSets()
        M.itemAddresses = {}
        M.corpseAddresses = {}

        for _, item in ipairs(M.items) do
            utils.addUniqueActor({}, M.itemAddresses, item)
        end

        for _, corpse in ipairs(M.corpses) do
            utils.addUniqueActor({}, M.corpseAddresses, corpse)
        end
    end

    function M.registerItemStream()
        pcall(function()
            NotifyOnNewObject(config.ITEM_CLASS_PATH, function(obj)
                ExecuteInGameThread(function()
                    if utils.isValid(obj) then
                        utils.addUniqueActor(M.items, M.itemAddresses, obj)
                    end
                end)
            end)
        end)
    end

    return M
end
