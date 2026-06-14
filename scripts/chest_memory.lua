return function(config, utils)
    local M = {}

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
    local remembered = {}
    local loaded = false

    local function trim(value)
        return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
    end

    local function lower(value)
        return string.lower(tostring(value or ""))
    end

    local function buildDataPath()
        local rootPath = SCRIPT_ROOT:gsub("/Scripts/$", "/")
        local slot = trim(config.CHEST_MEMORY_SLOT)
        if slot == "" then
            slot = "default"
        end

        slot = slot:gsub("[^%w%-_]+", "_")
        if slot == "" then
            slot = "default"
        end

        return rootPath .. "opened_chests_" .. lower(slot) .. ".txt"
    end

    local DATA_PATH = buildDataPath()

    local function contains(haystack, needle)
        return string.find(lower(haystack), lower(needle), 1, true) ~= nil
    end

    local function valueToString(value)
        if value == nil then
            return ""
        end

        local ok, text = pcall(function()
            return value:ToString()
        end)
        if ok and text then
            return tostring(text)
        end

        return tostring(value)
    end

    local function getStringProp(object, propertyName)
        local value = utils.getProp(object, propertyName)
        local text = trim(valueToString(value))
        if text == "" or text == "None" then
            return nil
        end
        return text
    end

    local function getObjectProp(object, propertyName)
        local value = utils.getProp(object, propertyName)
        if utils.isValid(value) then
            return value
        end
        return nil
    end

    local function isMeaningfulUniqueId(value)
        local text = trim(tostring(value or ""))
        if text == "" or text == "None" then
            return false
        end

        if string.find(text, "UObject:", 1, true) == 1 then
            return false
        end

        return true
    end

    local function getFullName(object)
        if not utils.isValid(object) then
            return nil
        end

        local ok, value = pcall(function()
            return object:GetFullName()
        end)
        if ok and value then
            return tostring(value)
        end

        ok, value = pcall(function()
            return object:GetName()
        end)
        if ok and value then
            return tostring(value)
        end

        return nil
    end

    local function roundToBucket(value, size)
        if type(value) ~= "number" then
            return nil
        end
        return math.floor((value / size) + 0.5)
    end

    local function candidateUniqueId(actor)
        local direct = getStringProp(actor, "m_UniqueNameInteractive")
        if isMeaningfulUniqueId(direct) then
            return direct
        end

        local component = utils.getInteractiveComponent(actor)
        local componentId = getStringProp(component, "m_UniqueNameInteractive")
        if isMeaningfulUniqueId(componentId) then
            return componentId
        end

        local definition = getObjectProp(actor, "m_InteractiveObjectDefinition")
        local definitionId = getStringProp(definition, "m_UniqueNameInteractive")
        if isMeaningfulUniqueId(definitionId) then
            return definitionId
        end

        return nil
    end

    function M.fingerprintFromActor(actor)
        if not utils.isValid(actor) then
            return nil
        end

        local uniqueId = candidateUniqueId(actor)
        if uniqueId ~= nil then
            return "unique:" .. lower(uniqueId)
        end

        local fullName = getFullName(actor)
        local x, y, z = utils.getLocation(actor)
        if fullName ~= nil and x ~= nil then
            local bx = roundToBucket(x, 100.0)
            local by = roundToBucket(y, 100.0)
            local bz = roundToBucket(z, 100.0)
            return "fallback:" .. lower(fullName) .. "@" .. tostring(bx) .. "," .. tostring(by) .. "," .. tostring(bz)
        end

        return nil
    end

    function M.fingerprintFromAbility(ability)
        if not utils.isValid(ability) then
            return nil
        end

        local uniqueId = getStringProp(ability, "m_UniqueNameInteractive")
        if isMeaningfulUniqueId(uniqueId) then
            return "unique:" .. lower(uniqueId)
        end

        local actor = getObjectProp(ability, "m_InteractiveActor")
        if actor then
            return M.fingerprintFromActor(actor)
        end

        return nil
    end

    local function ensureLoaded()
        if loaded then
            return
        end

        loaded = true
        local file = io.open(DATA_PATH, "r")
        if not file then
            return
        end

        for line in file:lines() do
            local fingerprint = trim(line)
            if fingerprint ~= "" then
                remembered[fingerprint] = true
            end
        end

        file:close()
        utils.debugLog("Loaded " .. tostring((function()
            local count = 0
            for _ in pairs(remembered) do
                count = count + 1
            end
            return count
        end)()) .. " remembered chest fingerprint(s)")
    end

    local function appendFingerprint(fingerprint)
        local file = io.open(DATA_PATH, "a")
        if not file then
            utils.log("Failed to write chest memory file: " .. DATA_PATH)
            return false
        end

        file:write(fingerprint .. "\n")
        file:close()
        return true
    end

    local function rememberFingerprint(fingerprint, reason)
        if fingerprint == nil or remembered[fingerprint] then
            return false
        end

        remembered[fingerprint] = true
        local saved = appendFingerprint(fingerprint)
        if saved then
            utils.log("Remembered opened chest: " .. fingerprint .. " (" .. tostring(reason or "unknown") .. ")")
        end
        return saved
    end

    function M.isRemembered(actor)
        if not config.REMEMBER_OPENED_CHESTS then
            return false
        end

        ensureLoaded()
        local fingerprint = M.fingerprintFromActor(actor)
        return fingerprint ~= nil and remembered[fingerprint] == true
    end

    function M.rememberAbility(ability, reason)
        if not config.REMEMBER_OPENED_CHESTS then
            return false
        end

        ensureLoaded()
        local savedAny = false
        savedAny = rememberFingerprint(M.fingerprintFromAbility(ability), reason) or savedAny

        local actor = getObjectProp(ability, "m_InteractiveActor")
        if actor then
            savedAny = rememberFingerprint(M.fingerprintFromActor(actor), (reason or "unknown") .. ":actor") or savedAny
        end

        return savedAny
    end

    local function looksLikeOpenContainerAbility(object)
        local fullName = getFullName(object) or ""
        return contains(fullName, "opencontainer")
            or contains(fullName, "gameplayabilityopencontainer")
    end

    function M.registerHooks()
        if not config.REMEMBER_OPENED_CHESTS then
            return
        end

        local function hookOpenFinished(reason)
            return function(context, success)
                local ability = context
                local okGet = pcall(function()
                    local unwrapped = context:get()
                    if unwrapped ~= nil then
                        ability = unwrapped
                    end
                end)

                if not okGet then
                    ability = context
                end

                if not utils.isValid(ability) or not looksLikeOpenContainerAbility(ability) then
                    return nil
                end

                if success ~= nil then
                    local okSuccess, successValue = pcall(function()
                        return success:get()
                    end)
                    if okSuccess and successValue == false then
                        return nil
                    end
                end

                M.rememberAbility(ability, reason)
                return nil
            end
        end

        pcall(function()
            RegisterHook("/Script/G1R.GameplayAbilityOpen:OnIntroFinished", hookOpenFinished("OnIntroFinished"))
        end)

        pcall(function()
            RegisterHook("/Script/G1R.GameplayAbilityOpen:OnLockSequenceFinished", hookOpenFinished("OnLockSequenceFinished"))
        end)
    end

    ensureLoaded()

    return M
end
