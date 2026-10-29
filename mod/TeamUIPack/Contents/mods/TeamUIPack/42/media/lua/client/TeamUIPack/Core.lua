-- TeamUIPack: shared helpers and Mod Options for every feature.
-- Each feature registers itself with TeamUIPack.registerFeature() and is
-- guarded by a tick box in Options > Mods, so one broken feature can be
-- switched off without touching the others.

TeamUIPack = TeamUIPack or {}
TeamUIPack.MOD_ID = "TeamUIPack"
TeamUIPack.features = TeamUIPack.features or {}

local options = PZAPI.ModOptions:create(TeamUIPack.MOD_ID, getText("UI_TeamUIPack_Title"))
TeamUIPack.options = options

function TeamUIPack.log(msg)
    print("[TeamUIPack] " .. tostring(msg))
end

-- Run fn and log instead of propagating errors, so one feature cannot break the rest.
function TeamUIPack.safeCall(featureId, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        TeamUIPack.log(featureId .. " failed: " .. tostring(err))
    end
    return ok, err
end

-- def = { id = "F08", name = "UI_..._Name", tooltip = "UI_..._Tooltip", default = true }
-- Returns the tick box option so the feature can add its own options below it.
function TeamUIPack.registerFeature(def)
    options:addSeparator()
    options:addTitle(getText(def.name))
    local enabled = options:addTickBox(def.id .. "_enabled", getText("UI_TeamUIPack_Enable"), def.default ~= false, getText(def.tooltip))
    TeamUIPack.features[def.id] = def
    return enabled
end

function TeamUIPack.isEnabled(featureId)
    local opt = options:getOption(featureId .. "_enabled")
    return opt ~= nil and opt:getValue() == true
end

function TeamUIPack.getOptionValue(id)
    local opt = options:getOption(id)
    return opt and opt:getValue()
end
