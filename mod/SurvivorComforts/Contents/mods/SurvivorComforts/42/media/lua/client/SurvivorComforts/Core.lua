-- SurvivorComforts: shared helpers and Mod Options for every feature.
-- Each feature registers itself with SurvivorComforts.registerFeature() and is
-- guarded by a tick box in Options > Mods, so one broken feature can be
-- switched off without touching the others.
--
-- The options page is built once every file is loaded (just before the game
-- reads the saved values), in OPTIONS_ORDER rather than file order, so related
-- features sit together. Option ids stay "<feature>_<name>", so saved
-- settings do not depend on the order.

SurvivorComforts = SurvivorComforts or {}
SurvivorComforts.MOD_ID = "SurvivorComforts"
SurvivorComforts.features = SurvivorComforts.features or {}

local options = PZAPI.ModOptions:create(SurvivorComforts.MOD_ID, getText("UI_SurvivorComforts_Title"))
SurvivorComforts.options = options

-- Grouped by where the feature is used:
--   left sidebar buttons, in the same order as the buttons (F08, F06, F09)
--   recipes (F12, F03)
--   everyday actions (F07, F04)
--   multiplayer (F10)
-- Features not listed come last, in file order.
local OPTIONS_ORDER = { "F08", "F06", "F09", "F12", "F03", "F07", "F04", "F10" }

function SurvivorComforts.log(msg)
    print("[SurvivorComforts] " .. tostring(msg))
end

-- Run fn and log instead of propagating errors, so one feature cannot break the rest.
function SurvivorComforts.safeCall(featureId, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        SurvivorComforts.log(featureId .. " failed: " .. tostring(err))
    end
    return ok, err
end

local pending = {}
local built = false

-- A separator, the feature's title, its "enable" tick box, then its own options.
local function addFeatureOptions(def)
    options:addSeparator()
    options:addTitle(getText(def.name))
    options:addTickBox(def.id .. "_enabled", getText("UI_SurvivorComforts_Enable"), def.default ~= false, getText(def.tooltip))
    if def.addOptions then
        SurvivorComforts.safeCall(def.id, def.addOptions, options)
    end
end

function SurvivorComforts.buildOptions()
    if built then return end
    built = true
    local rank = {}
    for i, id in ipairs(OPTIONS_ORDER) do rank[id] = i end
    for i, def in ipairs(pending) do def.fileOrder = i end
    table.sort(pending, function(a, b)
        local ra, rb = rank[a.id] or 1000, rank[b.id] or 1000
        if ra ~= rb then return ra < rb end
        return a.fileOrder < b.fileOrder
    end)
    for _, def in ipairs(pending) do
        addFeatureOptions(def)
    end
    pending = {}
end

-- def = { id = "F08", name = "UI_..._Name", tooltip = "UI_..._Tooltip", default = true,
--         addOptions = function(options) ... end }
-- addOptions adds the feature's own options below its "enable" tick box, in
-- this order: the sidebar button, the key, then anything else.
function SurvivorComforts.registerFeature(def)
    SurvivorComforts.features[def.id] = def
    if built then
        addFeatureOptions(def)
    else
        table.insert(pending, def)
    end
end

-- The game reads the saved values when it builds the options screen; the
-- page has to be complete by then.
local original_load = PZAPI.ModOptions.load
function PZAPI.ModOptions:load(...)
    SurvivorComforts.buildOptions()
    return original_load(self, ...)
end

function SurvivorComforts.isEnabled(featureId)
    SurvivorComforts.buildOptions()
    local opt = options:getOption(featureId .. "_enabled")
    return opt ~= nil and opt:getValue() == true
end

function SurvivorComforts.getOptionValue(id)
    SurvivorComforts.buildOptions()
    local opt = options:getOption(id)
    return opt and opt:getValue()
end
