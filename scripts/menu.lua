return function(scriptRoot, config, scanner, utils)
    local okBridge, modmenu = pcall(dofile, scriptRoot .. "modmenu.lua")
    if not okBridge or type(modmenu) ~= "table" or type(modmenu.register) ~= "function" then
        utils.debugLog("SharedModMenu bridge unavailable")
        return
    end

    local configPath = scriptRoot .. "config.lua"

    local function persist(name, encoded, isColor)
        local input = io.open(configPath, "r")
        if input == nil then return false end
        local content = input:read("*a")
        input:close()

        local valuePattern = isColor and "%b{}" or "[^,\r\n]+"
        local pattern = "([ \t]*" .. name .. "%s*=%s*)" .. valuePattern .. "(,)"
        local updated, count = content:gsub(pattern, "%1" .. encoded .. "%2", 1)
        if count ~= 1 then return false end

        local output = io.open(configPath, "w")
        if output == nil then return false end
        output:write(updated)
        output:close()
        return true
    end

    local function clamp(value, minimum, maximum)
        value = tonumber(value)
        if value == nil then return nil end
        return math.max(minimum, math.min(maximum, value))
    end

    local function save(name, encoded, isColor)
        if not persist(name, encoded, isColor) then
            utils.log("Could not save menu setting '" .. name .. "' to config.lua")
        end
    end

    local function setBool(field, fileName, value, afterSet)
        value = value == true
        config[field] = value
        save(fileName, value and "true" or "false", false)
        if type(afterSet) == "function" then afterSet(value) end
    end

    local function setNumber(field, fileName, value, minimum, maximum, format, refresh)
        value = clamp(value, minimum, maximum)
        if value == nil then return end
        config[field] = value
        save(fileName, string.format(format, value), false)
        if refresh then pcall(scanner.refreshOutlineSettings) end
    end

    local function setColorComponent(field, fileName, index, value)
        value = clamp(value, 0.0, 1.0)
        if value == nil then return end
        local color = config[field]
        if type(color) ~= "table" then color = { 1.0, 1.0, 1.0 } end
        color[index] = value
        config[field] = color
        save(fileName, string.format("{ %.2f, %.2f, %.2f }", color[1], color[2], color[3]), true)
        pcall(scanner.refreshOutlineSettings)
    end

    local function boolItem(name, field, fileName, afterSet)
        return {
            name = name,
            kind = "bool",
            get = function() return config[field] end,
            set = function(value) setBool(field, fileName, value, afterSet) end,
        }
    end

    local function numberItem(name, field, fileName, minimum, maximum, step, format, refresh)
        return {
            name = name,
            kind = "num",
            min = minimum,
            max = maximum,
            step = step,
            get = function() return config[field] end,
            set = function(value) setNumber(field, fileName, value, minimum, maximum, format, refresh) end,
        }
    end

    local function colorItem(name, field, fileName, index)
        return {
            name = name,
            kind = "num",
            min = 0.0,
            max = 1.0,
            step = 0.05,
            get = function() return config[field][index] end,
            set = function(value) setColorComponent(field, fileName, index, value) end,
        }
    end

    local registered = modmenu.register("Simple Item Scan", {
        { title = "Scan", items = {
            numberItem("Radius", "RADIUS", "radius", 500, 10000, 250, "%.0f", false),
            numberItem("Duration", "DURATION", "duration", 1, 60, 1, "%.1f", false),
            boolItem("Highlight Corpses", "HIGHLIGHT_CORPSES", "highlight_corpses"),
            boolItem("Skip Empty Corpses", "SKIP_EMPTY_CORPSES", "skip_empty_corpses"),
            boolItem("Highlight Chests", "HIGHLIGHT_CHESTS", "highlight_chests"),
            boolItem("Skip Empty Chests", "SKIP_EMPTY_CHESTS", "skip_empty_chests"),
            boolItem("Highlight Pouches", "HIGHLIGHT_POUCHES", "highlight_pouches"),
        } },
        { title = "Outline", items = {
            boolItem("Thick Outline", "USE_THICK_OUTLINE", "use_thick_outline"),
            numberItem("Opacity", "OUTLINE_ALPHA", "outline_alpha", 0.0, 1.0, 0.05, "%.2f", true),
            numberItem("Thickness", "THICKNESS_MULTIPLIER", "thickness_multiplier", 0.5, 4.0, 0.1, "%.2f", true),
            colorItem("Colour R", "OUTLINE_COLOR", "outline_color", 1),
            colorItem("Colour G", "OUTLINE_COLOR", "outline_color", 2),
            colorItem("Colour B", "OUTLINE_COLOR", "outline_color", 3),
        } },
        { title = "Stealing", items = {
            boolItem("Warning Outline", "USE_STEALING_OUTLINE", "use_stealing_outline"),
            colorItem("Warning R", "STEALING_OUTLINE_COLOR", "stealing_outline_color", 1),
            colorItem("Warning G", "STEALING_OUTLINE_COLOR", "stealing_outline_color", 2),
            colorItem("Warning B", "STEALING_OUTLINE_COLOR", "stealing_outline_color", 3),
        } },
        { title = "Experimental", items = {
            boolItem("Hunting Skills", "RESPECT_HUNTING_SKILLS", "respect_hunting_skills"),
        } },
        { title = "Debug", items = {
            boolItem("Debug Mode", "DEBUG_MODE", "debug_mode", function(value)
                utils.setDebugMode(value)
            end),
            boolItem("Log Chest State", "LOG_CHEST_STATE", "log_chest_state"),
            boolItem("Log Corpse State", "LOG_CORPSE_STATE", "log_corpse_state"),
            boolItem("Log Item State", "LOG_ITEM_STATE", "log_item_state"),
        } },
    })

    if registered then utils.debugLog("Registered SharedModMenu settings") end
end
