return function(config, utils, cache)
    local M = {}

    local highlighted = {}
    local highlightedByAddress = {}
    local cachedOutlineSubsystem = nil
    local cachedOwnershipSubsystem = nil
    local cachedDefaultOutlineConfig = nil
    local cachedDataModuleLibrary = nil
    local cachedGothicGASLibrary = nil
    local baseClosestThickness = nil
    local baseFarthestThickness = nil
    local lastPawnAddress = nil
    local lastOutlineWorldAddress = nil
    local activeScanId = 0
    local scanInProgress = false
    local lastScanStartedMs = -1000
    local minimumScanIntervalMs = 750
    local chestTypeCache = {}
    local stealingByAddress = {}
    local chestStateLogged = {}
    local itemStateLogged = {}
    local huntingSkillEffectClasses = {}
    local scanBatchSize = 16
    local chestKeywords = {
        "chest", "box", "barrel", "basket", "container", "safe", "crate",
        "cupboard", "wardrobe", "locker", "urn", "tomb", "sarcophagus"
    }
    local ignoredItemKeywords = {
        "itai_",
        "orebag",
        "pouch",
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

    local function getObjectWorldAddress(obj)
        if not utils.isValid(obj) then
            return nil
        end

        local ok, world = pcall(function()
            return obj:GetWorld()
        end)
        if not ok or not utils.isValid(world) then
            return nil
        end

        return utils.getAddress(world)
    end

    local function resetOutlineCache()
        cachedOutlineSubsystem = nil
        cachedOwnershipSubsystem = nil
        lastOutlineWorldAddress = nil
    end

    local function resetScanState()
        activeScanId = activeScanId + 1
        scanInProgress = false
        lastScanStartedMs = -1000
        highlighted = {}
        highlightedByAddress = {}
        chestTypeCache = {}
        stealingByAddress = {}
        chestStateLogged = {}
        itemStateLogged = {}
        cache.reset()
        utils.debugLog("Reset scan state for world change")
    end

    local function checkWorldReload(pawn)
        local pawnAddress = utils.getAddress(pawn)
        if pawnAddress ~= nil and lastPawnAddress ~= nil and pawnAddress ~= lastPawnAddress then
            resetOutlineCache()
            resetScanState()
            utils.debugLog("Detected world/pawn change, resetting outline cache")
        end
        lastPawnAddress = pawnAddress
    end

    local function getOutlineSubsystem(pawn)
        if utils.isValid(cachedOutlineSubsystem) and utils.isValid(pawn) then
            local pawnWorldAddress = getObjectWorldAddress(pawn)
            local subsystemWorldAddress = getObjectWorldAddress(cachedOutlineSubsystem)
            if pawnWorldAddress ~= nil and subsystemWorldAddress ~= nil and pawnWorldAddress ~= subsystemWorldAddress then
                resetOutlineCache()
            end
        end

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
                lastOutlineWorldAddress = getObjectWorldAddress(obj)
                return obj
            end
        end

        return nil
    end

    local function getOwnershipSubsystem(pawn)
        if utils.isValid(cachedOwnershipSubsystem) and utils.isValid(pawn) then
            local pawnWorldAddress = getObjectWorldAddress(pawn)
            local subsystemWorldAddress = getObjectWorldAddress(cachedOwnershipSubsystem)
            if pawnWorldAddress ~= nil and subsystemWorldAddress == pawnWorldAddress then
                return cachedOwnershipSubsystem
            end
        end

        cachedOwnershipSubsystem = nil
        local pawnWorldAddress = getObjectWorldAddress(pawn)
        local list = FindAllOf("OwnershipSubsystem")
        if not list then
            return nil
        end

        for _, obj in pairs(list) do
            if utils.isValid(obj) then
                local subsystemWorldAddress = getObjectWorldAddress(obj)
                if subsystemWorldAddress ~= nil
                    and (pawnWorldAddress == nil or subsystemWorldAddress == pawnWorldAddress) then
                    cachedOwnershipSubsystem = obj
                    return obj
                end
            end
        end

        return nil
    end

    local function getDefaultOutlineConfig()
        if utils.isValid(cachedDefaultOutlineConfig) then
            return cachedDefaultOutlineConfig
        end

        local ok, configObject = pcall(function()
            return StaticFindObject("/Script/G1R.Default__OutlineSubsystemConfig")
        end)
        if ok and utils.isValid(configObject) then
            cachedDefaultOutlineConfig = configObject
            return configObject
        end

        return nil
    end

    local function getDataModuleLibrary()
        if utils.isValid(cachedDataModuleLibrary) then
            return cachedDataModuleLibrary
        end

        local ok, library = pcall(function()
            return StaticFindObject("/Script/G1R.Default__DataModuleLibrary")
        end)
        if ok and utils.isValid(library) then
            cachedDataModuleLibrary = library
            return library
        end

        return nil
    end

    local function unwrapValue(value)
        if value == nil then
            return nil
        end

        local ok, unwrapped = pcall(function()
            return value:get()
        end)
        if ok and unwrapped ~= nil then
            return unwrapped
        end
        return value
    end

    local function forEachCollection(collection, callback)
        collection = unwrapValue(collection)
        if collection == nil then
            return false
        end

        local ok = pcall(function()
            for _, entry in pairs(collection) do
                callback(unwrapValue(entry))
            end
        end)
        if ok then
            return true
        end

        return pcall(function()
            collection:ForEach(function(_, entry)
                callback(unwrapValue(entry))
            end)
        end)
    end

    local function getItemASClass(definition)
        local ok, fullName = pcall(function()
            return definition:GetFullName()
        end)
        if ok and fullName ~= nil then return tostring(fullName) end
        return nil
    end

    local function getItemIdentity(definition)
        local parts = {}
        local uniqueName = utils.getProp(definition, "m_UniqueName")
        if uniqueName ~= nil then parts[#parts + 1] = tostring(uniqueName) end
        local asClass = getItemASClass(definition)
        if asClass ~= nil then parts[#parts + 1] = asClass end
        return table.concat(parts, " | ")
    end

    local function getItemDefinitionName(definition)
        local identity = getItemIdentity(definition)
        return identity:match("/Script/Angelscript%.([%w_]+)")
            or identity:match("^([%w_]+)$")
    end

    local function addDiscoveredHuntingItem(definition)
        local itemName = getItemDefinitionName(definition)
        if type(itemName) ~= "string" or not itemName:match("^ItAt_") then return false end
        local asClass = getItemASClass(definition)

        local map = config.HUNTING_LOOT_MAP
        local entries = type(map) == "table" and map.items or nil
        if type(entries) ~= "table" then return false end
        local itemNameLower = string.lower(itemName)
        for _, entry in ipairs(entries) do
            if type(entry) == "table"
                and type(entry.pattern) == "string"
                and string.lower(entry.pattern) == itemNameLower then
                return false
            end
        end

        local path = config.HUNTING_LOOT_DISCOVERY_PATH
        if type(path) ~= "string" then return false end
        local input = io.open(path, "r")
        local content
        if input ~= nil then
            content = input:read("*a")
            input:close()
        else
            content = table.concat({
                "-- User-editable hunting loot mappings discovered at runtime.",
                "-- This file is generated separately so mod updates do not overwrite it.",
                "-- Set skill to a value from hunting_loot_map.lua, or false for skill-free loot.",
                "",
                "return {",
                "    items = {",
                "        -- AUTO-DISCOVERED ITEMS END",
                "    },",
                "}",
                "",
            }, "\n")
        end

        local marker = "        -- AUTO-DISCOVERED ITEMS END"
        local startIndex = content:find(marker, 1, true)
        if startIndex == nil then return false end
        local asClassLine = asClass ~= nil
            and ("            as_class = " .. string.format("%q", asClass) .. ",")
            or "            -- as_class was unavailable when discovered"
        local record = table.concat({
            "        {",
            "            pattern = \"" .. itemName .. "\",",
            asClassLine,
            "            skill = nil, -- assign a known skill from hunting_loot_map.lua",
            "        },",
            "",
        }, "\n")
        local updated = content:sub(1, startIndex - 1) .. record .. content:sub(startIndex)
        local output = io.open(path, "w")
        if output == nil then return false end
        output:write(updated)
        output:close()

        entries[#entries + 1] = { pattern = itemName, as_class = asClass, skill = nil }
        utils.log(
            "Added hunting loot mapping placeholder to hunting_loot_discovered.lua for " .. itemName
            .. " as_class=" .. tostring(asClass or "unavailable")
        )
        return true
    end

    local function findHuntingRequirement(definition)
        local map = config.HUNTING_LOOT_MAP
        local entries = type(map) == "table" and map.items or nil
        if type(entries) ~= "table" then return nil end

        local identity = string.lower(getItemIdentity(definition))
        for _, entry in ipairs(entries) do
            local pattern = type(entry) == "table" and entry.pattern or nil
            if type(pattern) == "string"
                and pattern ~= ""
                and string.find(identity, string.lower(pattern), 1, true) then
                return entry
            end
        end
        return nil
    end

    local function getPlayerAbilitySystem(pawn)
        if not utils.isValid(pawn) then return nil end
        local ok, abilitySystem = pcall(function()
            return pawn:GetAbilitySystemComponent()
        end)
        if ok and utils.isValid(abilitySystem) then return abilitySystem end

        local characterState = utils.getProp(pawn, "m_CharacterState")
        abilitySystem = utils.getProp(characterState, "AbilitySystemComponent")
        if utils.isValid(abilitySystem) then return abilitySystem end
        return nil
    end

    local function getGothicGASLibrary()
        if utils.isValid(cachedGothicGASLibrary) then return cachedGothicGASLibrary end
        local ok, library = pcall(function()
            return StaticFindObject("/Script/G1R.Default__GothicGASLibrary")
        end)
        if ok and utils.isValid(library) then
            cachedGothicGASLibrary = library
            return library
        end
        return nil
    end

    local function getGrantedSkillTags(defaultObject, skillName)
        local tagComponent = nil
        local components = utils.getProp(defaultObject, "GEComponents")
        forEachCollection(components, function(component)
            if tagComponent == nil
                and utils.getProp(component, "InheritableGrantedTagsContainer") ~= nil then
                tagComponent = component
            end
        end)
        if tagComponent == nil then
            pcall(function()
                tagComponent = StaticFindObject(
                    "/Script/Angelscript.Default__" .. skillName .. ":TagComponent"
                )
            end)
        end
        if not utils.isValid(tagComponent) then return nil, "tag_component_unavailable" end

        local inherited = utils.getProp(tagComponent, "InheritableGrantedTagsContainer")
        local tags = {}
        local function appendTags(container)
            local gameplayTags = utils.getProp(container, "GameplayTags")
            if gameplayTags == nil then return false end
            return forEachCollection(gameplayTags, function(tag)
                tags[#tags + 1] = tag
            end)
        end
        local readable = appendTags(utils.getProp(inherited, "CombinedTags"))
        if #tags == 0 then
            readable = appendTags(utils.getProp(inherited, "Added")) or readable
        end
        if not readable then return nil, "granted_tags_unreadable" end
        if #tags == 0 then return nil, "granted_tags_empty" end
        return tags, "granted_tags=" .. tostring(#tags)
    end

    local function hasHuntingSkill(abilitySystem, skillName)
        if not utils.isValid(abilitySystem) or type(skillName) ~= "string" or skillName == "" then
            return nil, "ability_system_unavailable"
        end

        local cached = huntingSkillEffectClasses[skillName]
        if cached == nil then
            local effectClass = nil
            local defaultObject = nil
            local reason = "class_not_found"
            local okClass, foundClass = pcall(function()
                return StaticFindObject("/Script/Angelscript." .. skillName)
            end)
            if okClass and utils.isValid(foundClass) then
                effectClass = foundClass
                reason = "class_path"
            end

            -- Read granted tags from the effect default. This avoids
            -- GetGameplayEffectCount, whose UE4SS binding can touch invalid
            -- internal active-effect arrays in this game build.
            local okDefault, foundDefault = pcall(function()
                return StaticFindObject("/Script/Angelscript.Default__" .. skillName)
            end)
            if okDefault and utils.isValid(foundDefault) then
                defaultObject = foundDefault
                if effectClass == nil then
                    local okGetClass, recoveredClass = pcall(function()
                        return foundDefault:GetClass()
                    end)
                    if okGetClass and utils.isValid(recoveredClass) then
                        effectClass = recoveredClass
                        reason = "default_object_class"
                    else
                        reason = "default_get_class_failed:" .. tostring(recoveredClass)
                    end
                end
            elseif not okClass then
                reason = "class_lookup_failed:" .. tostring(foundClass)
            elseif not okDefault then
                reason = "default_lookup_failed:" .. tostring(foundDefault)
            end
            cached = {
                effect_class = effectClass,
                default_object = defaultObject,
                reason = reason,
            }
            huntingSkillEffectClasses[skillName] = cached
        end

        if not utils.isValid(cached.default_object) then
            return nil, cached.reason .. ":default_unavailable"
        end

        local tags, tagReason = getGrantedSkillTags(cached.default_object, skillName)
        if tags == nil then return nil, cached.reason .. ":" .. tagReason end
        local library = getGothicGASLibrary()
        if not utils.isValid(library) then return nil, "gas_library_unavailable" end

        local resolved = false
        local tagNames = {}
        for _, tag in ipairs(tags) do
            tagNames[#tagNames + 1] = tostring(utils.getProp(tag, "TagName") or tag)
            local ok, hasTag = pcall(function()
                return library:HasTag(abilitySystem, tag, true)
            end)
            if ok and type(hasTag) == "boolean" then
                resolved = true
                if hasTag then
                    return true, tagReason .. ":tag=" .. table.concat(tagNames, ",")
                end
            end
        end
        if resolved then
            return false, tagReason .. ":tags=" .. table.concat(tagNames, ",")
        end
        return nil, "tag_probe_failed:tags=" .. table.concat(tagNames, ",")
    end

    local function requirementIsMet(abilitySystem, requirement)
        local skills = requirement.skills
        if type(skills) ~= "table" then skills = { requirement.skill } end

        local resolved = false
        for _, skillName in ipairs(skills) do
            local hasSkill = hasHuntingSkill(abilitySystem, skillName)
            if hasSkill == true then return true end
            if hasSkill ~= nil then resolved = true end
        end
        if resolved then return false end
        return nil
    end

    local function getInventoryType(value)
        value = unwrapValue(value)
        if type(value) == "number" then return value end
        local text = tostring(value)
        local numeric = tonumber(text)
        if numeric ~= nil then return numeric end
        if string.find(text, "MainContainer", 1, true) then return 1 end
        return nil
    end

    local function getContainerLootState(actor, pawn, respectHuntingSkills)
        local library = getDataModuleLibrary()
        if not utils.isValid(library) then
            return nil, nil, "library_unavailable", nil
        end

        local ok, container = pcall(function()
            return library:GetContainerDataModule(actor)
        end)
        if not ok or not utils.isValid(container) then
            return nil, nil, "container_module_unavailable", nil
        end

        local inventory = unwrapValue(utils.getProp(container, "m_Inventory"))
        local values = unwrapValue(utils.getProp(inventory, "m_Values"))
        local inventoryEntries = utils.getProp(values, "Items")
        if inventoryEntries == nil then
            return nil, nil, "inventory_entries_unavailable", nil
        end

        local total = 0
        local accessible = 0
        local details = {}
        local abilitySystem = respectHuntingSkills and getPlayerAbilitySystem(pawn) or nil
        local readable = forEachCollection(inventoryEntries, function(entry)
            local inventoryType = getInventoryType(utils.getProp(entry, "m_InventoryType"))
            local slots = utils.getProp(entry, "m_Slots")
            local slotsReadable = forEachCollection(slots, function(item)
                local slotData = unwrapValue(utils.getProp(item, "m_SlotData"))
                local definition = utils.getProp(slotData, "m_ItemDefinition")
                local count = utils.getProp(slotData, "m_ItemCount")
                local itemInventoryType = getInventoryType(utils.getProp(item, "m_InventoryType"))
                    or inventoryType
                -- Only MainContainer is presented as carried loot. Equipped
                -- weapons, armor, rings, and quick slots remain on the actor
                -- after looting and must not keep the corpse highlighted.
                local isLootInventory = itemInventoryType == nil or itemInventoryType == 1
                if isLootInventory
                    and utils.isValid(definition)
                    and type(count) == "number"
                    and count > 0 then
                    addDiscoveredHuntingItem(definition)
                    total = total + 1
                    local accessibleItem = true
                    local requirement = nil
                    local skillState = "not_mapped"
                    if respectHuntingSkills then
                        requirement = findHuntingRequirement(definition)
                        if requirement ~= nil then
                            local requiresNoSkill = requirement.skill == false
                            local hasAssignedSkill = type(requirement.skill) == "string"
                                or (type(requirement.skills) == "table" and #requirement.skills > 0)
                            if requirement.ignore == true then
                                accessibleItem = false
                                skillState = "ignored"
                            elseif requiresNoSkill then
                                skillState = "free"
                            elseif hasAssignedSkill then
                                local met = requirementIsMet(abilitySystem, requirement)
                                if met == false then accessibleItem = false end
                                skillState = met == true and "unlocked"
                                    or (met == false and "locked" or "unknown")
                            else
                                skillState = "unassigned"
                            end
                        end
                    end
                    if accessibleItem then accessible = accessible + 1 end
                    details[#details + 1] = {
                        identity = getItemIdentity(definition),
                        count = count,
                        inventory_type = itemInventoryType,
                        skill_state = skillState,
                    }
                end
            end)
            if not slotsReadable then
                error("slots_unavailable")
            end
        end)
        if not readable then
            return nil, nil, "inventory_slots_unavailable", nil
        end

        return total, accessible, "live_inventory", details
    end

    local function getContainerLootCount(actor)
        local total, _, source = getContainerLootState(actor, nil, false)
        return total, source
    end

    local function logHuntingSkillState(pawn)
        if not config.LOG_CORPSE_STATE then return end
        local map = config.HUNTING_LOOT_MAP
        local skills = type(map) == "table" and map.known_skills or nil
        if type(skills) ~= "table" then return end

        local abilitySystem = getPlayerAbilitySystem(pawn)
        for _, skillName in ipairs(skills) do
            local learned, reason = hasHuntingSkill(abilitySystem, skillName)
            local state = learned == true and "learned"
                or (learned == false and "not_learned" or "unknown")
            utils.log(
                "HuntingSkill " .. tostring(skillName)
                .. " state=" .. state
                .. " probe=" .. tostring(reason)
            )
        end
    end

    local function unwrapEnumValue(value)
        if type(value) == "number" then
            return value
        end

        local ok, unwrapped = pcall(function()
            return value:get()
        end)
        if ok and type(unwrapped) == "number" then
            return unwrapped
        end

        local text = tostring(ok and unwrapped or value)
        local numeric = tonumber(text)
        if numeric ~= nil then
            return numeric
        end
        if string.find(text, "OutlineInSight", 1, true) then
            return 1
        end
        if string.find(text, "OutlineAction", 1, true) then
            return 2
        end

        return nil
    end

    local function isStealingTarget(actor, pawn, targetKind)
        if not config.USE_STEALING_OUTLINE or not utils.isValid(actor) or not utils.isValid(pawn) then
            return false
        end

        local address = utils.getAddress(actor)
        if address ~= nil and stealingByAddress[address] ~= nil then
            return stealingByAddress[address]
        end

        local ownership = getOwnershipSubsystem(pawn)
        local characterState = utils.getProp(pawn, "m_CharacterState")
        if not utils.isValid(characterState) then
            local okState, state = pcall(function()
                return pawn:BP_GetCharacterState()
            end)
            if okState then
                characterState = state
            end
        end
        if not utils.isValid(ownership) or not utils.isValid(characterState) then
            return false
        end

        local ok, relation = pcall(function()
            if targetKind == "item" or targetKind == "pouch" then
                return ownership:GetOwnershipRelationOfItemInWorld(characterState, actor)
            end
            return ownership:GetOwnershipRelationOfInteractiveObjectInWorld(characterState, actor)
        end)
        if not ok then
            return false
        end

        local flags = unwrapEnumValue(relation)
        local stealing = false
        if flags ~= nil then
            -- OtherGuild (16) and OtherPersonal (32) are the game's stealing flags.
            stealing = math.floor(flags / 16) % 4 ~= 0
        else
            local text = tostring(relation)
            stealing = string.find(text, "OtherGuild", 1, true) ~= nil
                or string.find(text, "OtherPersonal", 1, true) ~= nil
        end

        if address ~= nil then
            stealingByAddress[address] = stealing
        end
        return stealing
    end

    local function applyOutlineConfig(subsystem, pawn)
        subsystem = subsystem or getOutlineSubsystem(pawn)
        if not utils.isValid(subsystem) then
            return
        end

        local configObject = utils.getProp(subsystem, "Config")
        if not utils.isValid(configObject) then
            return
        end

        local subsystemWorldAddress = getObjectWorldAddress(subsystem)
        if subsystemWorldAddress ~= nil and subsystemWorldAddress ~= lastOutlineWorldAddress then
            lastOutlineWorldAddress = subsystemWorldAddress
        end

        -- Unreal may replace the config UObject while retaining its current values.
        -- Read the class defaults rather than the live config so hot-reloading the
        -- Lua mod cannot treat an already multiplied value as the new baseline.
        if type(baseClosestThickness) ~= "number" then
            local defaultConfig = getDefaultOutlineConfig()
            baseClosestThickness = utils.getProp(defaultConfig, "OutlineClosestThickness")
                or utils.getProp(configObject, "OutlineClosestThickness")
        end
        if type(baseFarthestThickness) ~= "number" then
            local defaultConfig = getDefaultOutlineConfig()
            baseFarthestThickness = utils.getProp(defaultConfig, "OutlineFarthestThickness")
                or utils.getProp(configObject, "OutlineFarthestThickness")
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

            local function stencilForEachCallback(keyProxy, valueProxy)
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

                if type(value) == "function" then
                    return
                end

                local color = utils.getProp(value, "Color")
                if color ~= nil then
                    currentFn(keyProxy, color, value)
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

            local function applyStencilColor(keyProxy, color, value)
                local usage = unwrapEnumValue(keyProxy)
                local selectedColor = nil
                if usage == config.STENCIL_USAGE then
                    selectedColor = config.OUTLINE_COLOR
                elseif config.USE_STEALING_OUTLINE and usage == config.STEALING_STENCIL_USAGE then
                    selectedColor = config.STEALING_OUTLINE_COLOR
                end
                if selectedColor == nil then
                    return
                end

                utils.setProp(color, "R", selectedColor[1])
                utils.setProp(color, "G", selectedColor[2])
                utils.setProp(color, "B", selectedColor[3])
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

    function M.refreshOutlineSettings()
        local pawn = utils.getPlayerPawn()
        if utils.isValid(pawn) then
            checkWorldReload(pawn)
        end

        local subsystem = getOutlineSubsystem(pawn)
        if not utils.isValid(subsystem) then
            return false
        end

        applyOutlineConfig(subsystem, pawn)
        pcall(function()
            subsystem:SetIsSystemEnabled(true)
        end)
        return true
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

        if config.SKIP_EMPTY_CORPSES then
            local totalCount, accessibleCount, source, details = getContainerLootState(
                actor,
                pawn,
                config.RESPECT_HUNTING_SKILLS
            )
            local itemCount = config.RESPECT_HUNTING_SKILLS and accessibleCount or totalCount
            utils.debugLog(
                "CorpseInventory " .. tostring(utils.getAddress(actor) or "unknown")
                .. " total=" .. tostring(totalCount)
                .. " accessible=" .. tostring(accessibleCount)
                .. " effective=" .. tostring(itemCount)
                .. " source=" .. tostring(source)
            )
            if config.LOG_CORPSE_STATE then
                for _, detail in ipairs(details or {}) do
                    utils.log(
                        "CorpseItem count=" .. tostring(detail.count)
                        .. " inventory_type=" .. tostring(detail.inventory_type)
                        .. " skill_state=" .. tostring(detail.skill_state)
                        .. " | " .. tostring(detail.identity)
                    )
                end
            end
            if itemCount == 0 then
                return false, nil
            end
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

    local function hasLiveContainerLoot(actor, address, fullName)
        local component = utils.getInteractiveComponent(actor)
        if not utils.isValid(component) then
            return false
        end

        if not config.SKIP_EMPTY_CHESTS then
            return true
        end

        local itemCount, source = getContainerLootCount(actor)
        if config.LOG_CHEST_STATE then
            utils.log(
                "ChestInventory " .. tostring(address or "unknown")
                .. " count=" .. tostring(itemCount)
                .. " source=" .. tostring(source)
                .. " | " .. tostring(fullName or "cached_container")
            )
        end

        return itemCount == nil or itemCount > 0
    end

    local function isLikelyLootContainerType(actor)
        if not config.HIGHLIGHT_CHESTS or not utils.isValid(actor) then
            return false
        end

        local address = utils.getAddress(actor)
        if address ~= nil and chestTypeCache[address] == false then
            return false
        end
        if address ~= nil and chestTypeCache[address] == true then
            return hasLiveContainerLoot(actor, address, nil)
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

        if not result then
            return false
        end
        return hasLiveContainerLoot(actor, address, fullName)
    end

    local function shouldHighlightItem(actor)
        if not utils.isValid(actor) then
            return false
        end

        local ok, fullName = pcall(function()
            return actor:GetFullName()
        end)
        if not ok then
            return false
        end

        local nameLower = string.lower(tostring(fullName or ""))
        for _, keyword in ipairs(ignoredItemKeywords) do
            if string.find(nameLower, keyword, 1, true) then
                return false
            end
        end

        return utils.getInteractiveComponent(actor) ~= nil
    end

    local function getPickpocketPouchComponent(actor)
        if not config.HIGHLIGHT_POUCHES or not utils.isValid(actor) then
            return nil
        end

        local component = utils.getInteractiveComponent(actor)
        if not utils.isValid(component) then
            return nil
        end
        if utils.getProp(component, "m_ForceDisableInteraction") == true then
            return nil
        end

        return component
    end

    local function logItemState(actor, reason, px, py, pz)
        if not config.LOG_ITEM_STATE then
            return
        end

        local address = utils.getAddress(actor)
        if address == nil or itemStateLogged[address] then
            return
        end

        local ix, iy, iz = utils.getLocation(actor)
        if ix == nil or px == nil then
            return
        end

        local dx = ix - px
        local dy = iy - py
        local dz = iz - pz
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        if distance > config.RADIUS then
            return
        end

        itemStateLogged[address] = true
        local name = "unknown"
        pcall(function()
            name = tostring(actor:GetFullName())
        end)

        utils.log(
            "ItemState " .. tostring(address)
            .. " " .. tostring(reason)
            .. " | distance=" .. string.format("%.1f", distance)
            .. " | name=" .. tostring(name)
        )
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

    local function addHighlight(subsystem, actor, component, resolveComponent, stencilUsage)
        local address = utils.getAddress(component)
        if address ~= nil and highlightedByAddress[address] then
            return false
        end

        local ok = pcall(function()
            subsystem:AddOutline(
                component,
                stencilUsage or config.STENCIL_USAGE,
                config.USE_THICK_OUTLINE
            )
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

    local function processScanBatch(subsystem, pawn, px, py, pz, state)
        local processed = 0
        local startingPhase = state.phase

        while processed < scanBatchSize do
            local actor = nil
            local list = nil
            local targetKind = nil

            if state.phase == "items" then
                list = state.itemCandidates
                targetKind = "item"
            elseif state.phase == "pouches" then
                list = state.pouchCandidates
                targetKind = "pouch"
            elseif state.phase == "corpses" then
                list = state.corpseCandidates
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
                    state.phase = "pouches"
                elseif state.phase == "pouches" then
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
                        local component = utils.getInteractiveComponent(actor)
                        if not shouldHighlightItem(actor) then
                            logItemState(actor, "rejected_filtered", px, py, pz)
                        else
                            local stencilUsage = config.STENCIL_USAGE
                            if isStealingTarget(actor, pawn, targetKind) then
                                stencilUsage = config.STEALING_STENCIL_USAGE
                                state.stealingCount = state.stealingCount + 1
                            end
                            if component and addHighlight(
                                subsystem,
                                actor,
                                component,
                                utils.getInteractiveComponent,
                                stencilUsage
                            ) then
                                logItemState(actor, "accepted", px, py, pz)
                                state.count = state.count + 1
                            end
                        end
                    elseif targetKind == "pouch" then
                        local component = getPickpocketPouchComponent(actor)
                        local stencilUsage = config.STENCIL_USAGE
                        if component and isStealingTarget(actor, pawn, targetKind) then
                            stencilUsage = config.STEALING_STENCIL_USAGE
                            state.stealingCount = state.stealingCount + 1
                        end
                        if component and addHighlight(
                            subsystem,
                            actor,
                            component,
                            utils.getInteractiveComponent,
                            stencilUsage
                        ) then
                            state.count = state.count + 1
                            state.pouchCount = state.pouchCount + 1
                        end
                    elseif targetKind == "corpse" then
                        local lootable, component = isLootableCorpse(actor, pawn)
                        if lootable and addHighlight(subsystem, actor, component, resolveCorpseOutlineComponent) then
                            state.count = state.count + 1
                        end
                    else
                        if isLikelyLootContainerType(actor) then
                            local component = utils.getInteractiveComponent(actor)
                            local stencilUsage = config.STENCIL_USAGE
                            if isStealingTarget(actor, pawn, targetKind) then
                                stencilUsage = config.STEALING_STENCIL_USAGE
                                state.stealingCount = state.stealingCount + 1
                            end
                            if component and addHighlight(
                                subsystem,
                                actor,
                                component,
                                utils.getInteractiveComponent,
                                stencilUsage
                            ) then
                                state.count = state.count + 1
                            end
                        end
                    end
                end
            end
        end

        if startingPhase == "items" then
            state.processedItems = state.index
        elseif startingPhase == "pouches" then
            state.processedPouches = state.index
        elseif startingPhase == "corpses" then
            state.processedCorpses = state.index
        elseif startingPhase == "chests" then
            state.processedChests = state.index
        end

        return state.phase == "done"
    end

    function M.scanAndHighlight()
        local scanStartMs = nowMs()
        if scanInProgress then
            utils.debugLog("Scan ignored: previous scan still in progress")
            return
        end
        if scanStartMs - lastScanStartedMs < minimumScanIntervalMs then
            utils.debugLog("Scan ignored: button pressed too quickly")
            return
        end

        local pawn = utils.getPlayerPawn()

        if not utils.isValid(pawn) then
            utils.debugLog("Player pawn not found")
            return
        end

        checkWorldReload(pawn)
        logHuntingSkillState(pawn)
        local subsystem = getOutlineSubsystem(pawn)

        if not utils.isValid(subsystem) then
            utils.debugLog("OutlineSubsystem not found")
            return
        end

        scanInProgress = true
        lastScanStartedMs = scanStartMs

        local queryStartMs = nowMs()
        local nearbyTargets = cache.queryNearbyTargets(pawn, config.RADIUS)
        if nearbyTargets == nil then
            scanInProgress = false
            utils.debugLog("Scan cancelled: native nearby query unavailable")
            return
        end
        utils.debugLog("ScanTiming nearby_query=" .. tostring(elapsedMs(queryStartMs)) .. "ms")

        activeScanId = activeScanId + 1
        local scanId = activeScanId

        local outlineStartMs = nowMs()
        applyOutlineConfig(subsystem, pawn)
        utils.debugLog("ScanTiming outline_config=" .. tostring(elapsedMs(outlineStartMs)) .. "ms")

        pcall(function()
            subsystem:SetIsSystemEnabled(true)
        end)

        local px, py, pz = nil, nil, nil
        if config.LOG_ITEM_STATE then
            px, py, pz = utils.getLocation(pawn)
        end

        local state = {
            phase = "items",
            index = 0,
            count = 0,
            stealingCount = 0,
            pouchCount = 0,
            itemCandidates = nearbyTargets.items,
            pouchCandidates = nearbyTargets.pouches,
            corpseCandidates = nearbyTargets.corpses,
            chestCandidates = nearbyTargets.chests,
            processedItems = 0,
            processedPouches = 0,
            processedCorpses = 0,
            processedChests = 0,
            batchCount = 0,
        }

        local function finishScan()
            scanInProgress = false
            utils.debugLog("Highlighted " .. tostring(state.count) .. " nearby target(s)")
            utils.debugLog(
                "ScanTiming total=" .. tostring(elapsedMs(scanStartMs))
                .. "ms batches=" .. tostring(state.batchCount)
                .. " item_candidates=" .. tostring(#state.itemCandidates)
                .. " pouch_candidates=" .. tostring(#state.pouchCandidates)
                .. " pouches_highlighted=" .. tostring(state.pouchCount)
                .. " corpse_candidates=" .. tostring(#state.corpseCandidates)
                .. " chest_candidates=" .. tostring(#state.chestCandidates)
                .. " stealing_targets=" .. tostring(state.stealingCount)
            )

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

                if not utils.isValid(subsystem) or not utils.isValid(pawn) then
                    activeScanId = activeScanId + 1
                    scanInProgress = false
                    highlighted = {}
                    highlightedByAddress = {}
                    utils.debugLog("Scan cancelled: subsystem or pawn became invalid between batches")
                    return
                end

                state.batchCount = state.batchCount + 1
                local ok, done = pcall(processScanBatch, subsystem, pawn, px, py, pz, state)
                if not ok then
                    activeScanId = activeScanId + 1
                    scanInProgress = false
                    utils.log("Scan cancelled after a Lua error: " .. tostring(done))
                    return
                end
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
