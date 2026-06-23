-- Optional SharedModMenu consumer bridge. This file is self-contained so
-- SimpleItemScan never needs to load code from another mod's directory.

local M = {}
local GS, RS, FS = "\29", "\30", "\31"
local PFX = "SMM:"
local registry = {}
local started = false

local function sharedSet(key, value)
    local modRef = rawget(_G, "ModRef")
    if modRef == nil then return false end
    return pcall(function() modRef:SetSharedVariable(key, value) end)
end

local function sharedGet(key)
    local modRef = rawget(_G, "ModRef")
    if modRef == nil then return nil end
    local value = nil
    if pcall(function() value = modRef:GetSharedVariable(key) end) then
        return value
    end
    return nil
end

local function split(value, separator)
    local result = {}
    local start = 1
    if type(value) ~= "string" or value == "" then return result end
    while true do
        local index = value:find(separator, start, true)
        if index == nil then
            result[#result + 1] = value:sub(start)
            return result
        end
        result[#result + 1] = value:sub(start, index - 1)
        start = index + 1
    end
end

local function encodeValue(value, kind)
    if kind == "bool" then return value and "b1" or "b0" end
    if kind == "num" then return "n" .. tostring(tonumber(value) or 0) end
    return "x"
end

local function decodeValue(value)
    if type(value) ~= "string" or value == "" then return nil end
    local tag = value:sub(1, 1)
    if tag == "b" then return value:sub(2) == "1" end
    if tag == "n" then return tonumber(value:sub(2)) end
    return nil
end

local function normalize(spec)
    local sectioned = type(spec[1]) == "table" and type(spec[1].items) == "table"
    local source = sectioned and spec or { { items = spec } }
    local sections, flat = {}, {}
    for _, section in ipairs(source) do
        local items = {}
        for _, item in ipairs(section.items or {}) do
            items[#items + 1] = item
            flat[#flat + 1] = item
        end
        sections[#sections + 1] = { title = section.title, items = items }
    end
    return sections, flat
end

local function serializeSchema(sections)
    local serializedSections = {}
    for _, section in ipairs(sections) do
        local records = { section.title or "" }
        for _, item in ipairs(section.items) do
            records[#records + 1] = table.concat({
                tostring(item.name or "?"),
                tostring(item.kind or "num"),
                type(item.min) == "number" and tostring(item.min) or "",
                type(item.max) == "number" and tostring(item.max) or "",
                type(item.step) == "number" and tostring(item.step) or "",
            }, FS)
        end
        serializedSections[#serializedSections + 1] = table.concat(records, RS)
    end
    return table.concat(serializedSections, GS)
end

local function serializeValues(items)
    local values = {}
    for _, item in ipairs(items) do
        local value = item.val
        if type(item.get) == "function" then
            local ok, current = pcall(item.get)
            if ok then value = current end
        end
        values[#values + 1] = encodeValue(value, item.kind)
    end
    return table.concat(values, RS)
end

local function indexContains(index, name)
    for _, current in ipairs(split(index, ",")) do
        if current == name then return true end
    end
    return false
end

local function applyCommands(name, items)
    local key = PFX .. "cmd:" .. name
    local commands = sharedGet(key)
    if type(commands) ~= "string" or commands == "" then return end
    sharedSet(key, "")
    for _, command in ipairs(split(commands, RS)) do
        local fields = split(command, FS)
        local item = items[tonumber(fields[1])]
        if item and type(item.set) == "function" then
            pcall(item.set, decodeValue(fields[2]))
        end
    end
end

function M.pump()
    for name, items in pairs(registry) do
        applyCommands(name, items)
        sharedSet(PFX .. "values:" .. name, serializeValues(items))
    end
end

local function startPump()
    if started then return end
    started = true
    local loopAsync = rawget(_G, "LoopAsync")
    if type(loopAsync) ~= "function" then return end

    local generation = (tonumber(rawget(_G, "__simpleItemScanMenuGeneration")) or 0) + 1
    rawset(_G, "__simpleItemScanMenuGeneration", generation)
    local busy = false
    loopAsync(250, function()
        if rawget(_G, "__simpleItemScanMenuGeneration") ~= generation then return true end
        if busy then return false end
        busy = true
        local function work()
            pcall(M.pump)
            busy = false
        end
        local executeInGameThread = rawget(_G, "ExecuteInGameThread")
        if type(executeInGameThread) == "function" then executeInGameThread(work) else work() end
        return false
    end)
end

function M.register(name, spec)
    if type(name) ~= "string" or type(spec) ~= "table" then return false end
    local sections, items = normalize(spec)
    registry[name] = items

    local indexKey = PFX .. "index"
    local index = sharedGet(indexKey) or ""
    if not indexContains(index, name) then
        sharedSet(indexKey, index == "" and name or (index .. "," .. name))
    end
    sharedSet(PFX .. "schema:" .. name, serializeSchema(sections))
    sharedSet(PFX .. "values:" .. name, serializeValues(items))
    startPump()
    return true
end

return M
