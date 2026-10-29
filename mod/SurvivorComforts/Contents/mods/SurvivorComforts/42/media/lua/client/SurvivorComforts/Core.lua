-- SurvivorComforts: shared helpers and Mod Options for every feature.
-- Each feature registers itself with SurvivorComforts.registerFeature() and is
-- guarded by a tick box in Options > Mods, so one broken feature can be
-- switched off without touching the others.

SurvivorComforts = SurvivorComforts or {}
SurvivorComforts.MOD_ID = "SurvivorComforts"
SurvivorComforts.features = SurvivorComforts.features or {}

local options = PZAPI.ModOptions:create(SurvivorComforts.MOD_ID, getText("UI_SurvivorComforts_Title"))
SurvivorComforts.options = options

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

-- def = { id = "F08", name = "UI_..._Name", tooltip = "UI_..._Tooltip", default = true }
-- Returns the tick box option so the feature can add its own options below it.
function SurvivorComforts.registerFeature(def)
    options:addSeparator()
    options:addTitle(getText(def.name))
    local enabled = options:addTickBox(def.id .. "_enabled", getText("UI_SurvivorComforts_Enable"), def.default ~= false, getText(def.tooltip))
    SurvivorComforts.features[def.id] = def
    return enabled
end

function SurvivorComforts.isEnabled(featureId)
    local opt = options:getOption(featureId .. "_enabled")
    return opt ~= nil and opt:getValue() == true
end

function SurvivorComforts.getOptionValue(id)
    local opt = options:getOption(id)
    return opt and opt:getValue()
end
