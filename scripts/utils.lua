return function(modName, debugMode)
    local M = {}
    local debugEnabled = debugMode == true

    function M.log(msg)
        print("[" .. modName .. "] " .. msg .. "\n")
    end

    function M.debugLog(msg)
        if debugEnabled then
            M.log(msg)
        end
    end

    function M.setDebugMode(enabled)
        debugEnabled = enabled == true
    end

    function M.isValid(obj)
        if obj == nil then
            return false
        end

        local ok, valid = pcall(function()
            return obj:IsValid()
        end)

        return ok and valid
    end

    function M.getProp(obj, prop)
        local ok, value = pcall(function()
            return obj[prop]
        end)

        if ok then
            return value
        end

        return nil
    end

    function M.setProp(obj, prop, value)
        local ok = pcall(function()
            obj[prop] = value
        end)

        return ok
    end

    function M.getNumber(value)
        if type(value) == "number" then
            return value
        end
        return nil
    end

    function M.getAddress(obj)
        if not M.isValid(obj) then
            return nil
        end

        local ok, address = pcall(function()
            return obj:GetAddress()
        end)

        if ok then
            return address
        end

        return nil
    end

    function M.getLocation(actor)
        if not M.isValid(actor) then
            return nil
        end

        local ok, loc = pcall(function()
            return actor:K2_GetActorLocation()
        end)

        if ok and loc then
            local x = M.getNumber(loc.X)
            local y = M.getNumber(loc.Y)
            local z = M.getNumber(loc.Z)
            if x ~= nil and y ~= nil and z ~= nil then
                return x, y, z
            end
        end

        local root = M.getProp(actor, "RootComponent")
        if root then
            local loc = M.getProp(root, "RelativeLocation")
            if loc then
                local x = M.getNumber(loc.X)
                local y = M.getNumber(loc.Y)
                local z = M.getNumber(loc.Z)
                if x ~= nil and y ~= nil and z ~= nil then
                    return x, y, z
                end
            end
        end

        return nil
    end

    function M.getInteractiveComponent(actor)
        local component = M.getProp(actor, "m_InteractiveComponent")
        if M.isValid(component) then
            return component
        end
        return nil
    end

    function M.getPlayerPawn()
        local controller = M.getPlayerController()
        if not controller then
            return nil
        end

        local pawn = M.getProp(controller, "Pawn")
        if M.isValid(pawn) then
            return pawn
        end

        return nil
    end

    function M.getPlayerController()
        local controllers = FindAllOf("PlayerController")
        if not controllers then
            return nil
        end

        for _, pc in pairs(controllers) do
            if M.isValid(pc) then
                return pc
            end
        end

        return nil
    end

    return M
end
