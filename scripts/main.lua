local MOD_NAME = "SimpleItemScan"

local HIGHLIGHT_KEY = Key.F6
local ITEM_CLASS = "ItemVisualWorld"

local RADIUS = 2500.0       -- 25 metres, Gothic/UE units
local DURATION = 5.0        -- seconds
local STENCIL_USAGE = 2
local USE_THICK_OUTLINE = false

local highlighted = {}

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

local function getProp(obj, prop)
    local ok, value = pcall(function()
        return obj[prop]
    end)
    if ok then return value end
    return nil
end

local function getOutlineSubsystem()
    local list = FindAllOf("OutlineSubsystem")
    if not list then return nil end

    for _, obj in pairs(list) do
        if isValid(obj) then
            return obj
        end
    end

    return nil
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

local function removeHighlights()
    local subsystem = getOutlineSubsystem()
    if not isValid(subsystem) then return end

    for _, component in pairs(highlighted) do
        if isValid(component) then
            pcall(function()
                subsystem:QueueRemoveOutline(component)
            end)
        end
    end

    highlighted = {}
    log("Removed temporary outlines")
end

local function scanAndHighlight()
    local subsystem = getOutlineSubsystem()
    local pawn = getPlayerPawn()

    if not isValid(subsystem) then
        log("OutlineSubsystem not found")
        return
    end

    if not isValid(pawn) then
        log("Player pawn not found")
        return
    end

    removeHighlights()

    pcall(function()
        subsystem:SetIsSystemEnabled(true)
    end)

    local px, py, pz = getLocation(pawn)
    if not px then
        log("Player location not found")
        return
    end

    local radiusSquared = RADIUS * RADIUS
    local count = 0

    local items = FindAllOf(ITEM_CLASS)

    if items then
        for _, item in pairs(items) do
            if isValid(item) then
                local ix, iy, iz = getLocation(item)

                if ix then
                    local dx = ix - px
                    local dy = iy - py
                    local dz = iz - pz
                    local distanceSquared = dx * dx + dy * dy + dz * dz

                    if distanceSquared <= radiusSquared then
                        local component = getProp(item, "m_InteractiveComponent")

                        if isValid(component) then
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
    end

    log("Highlighted " .. tostring(count) .. " nearby item(s)")

    ExecuteWithDelay(math.floor(DURATION * 1000), function()
        ExecuteInGameThread(function()
            removeHighlights()
        end)
    end)
end

log("Loaded. Press F6 to temporarily highlight nearby items.")

RegisterKeyBind(HIGHLIGHT_KEY, function()
    ExecuteInGameThread(function()
        scanAndHighlight()
    end)
end)