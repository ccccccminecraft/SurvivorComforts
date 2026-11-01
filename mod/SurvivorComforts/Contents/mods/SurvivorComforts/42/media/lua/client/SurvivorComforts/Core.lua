-- SurvivorComforts: shared helpers and Mod Options for every feature.
-- Each feature registers itself with SurvivorComforts.registerFeature() and is
-- guarded by a tick box in Options > Mods, so one broken feature can be
-- switched off without touching the others.
--
-- The options page is built once every file is loaded (just before the game
-- reads the saved values), in OPTION_GROUPS rather than file order, so related
-- features sit together under one heading. Option ids stay "<feature>_<name>", so saved
-- settings do not depend on the order.

SurvivorComforts = SurvivorComforts or {}
SurvivorComforts.MOD_ID = "SurvivorComforts"
SurvivorComforts.features = SurvivorComforts.features or {}
-- Functions the features keep to themselves, handed out for the tests in the
-- test mod (mod-tests, docs/testing.md). Not for other mods: they may change.
SurvivorComforts.internals = SurvivorComforts.internals or {}

local options = PZAPI.ModOptions:create(SurvivorComforts.MOD_ID, getText("UI_SurvivorComforts_Title"))
SurvivorComforts.options = options

-- The options page, one heading per group, with a line between groups.
-- Without a title, the group's heading is its first feature's name, and that
-- feature's tick box is "Enable". Every other feature in a group is one tick
-- box with the feature's name (its own options follow it), so a feature that
-- is only a switch needs no heading of its own. Features not listed come
-- last, each under its own heading, in file order.
local OPTION_GROUPS = {
    { features = { "F08" } },                -- skills window
    { features = { "F06" } },                -- wishlist
    { features = { "F09", "F15" } },         -- player list, and members' skills opened from it
    { title = "UI_SurvivorComforts_Group_Search", features = { "F02", "F14" } }, -- F14's option also covers F02
    { features = { "F04" } },                -- reading time
    { title = "UI_SurvivorComforts_Group_Recipes", features = { "F12", "F03", "F07" } },
    { title = "UI_SurvivorComforts_Group_HideButtons", features = { "F10", "F13" } },
}

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

-- The feature's "enable" tick box (labelled "Enable" or with the feature's
-- name), then its own options.
local function addFeatureOptions(def, label)
    options:addTickBox(def.id .. "_enabled", getText(label), def.default ~= false, getText(def.tooltip))
    if def.addOptions then
        SurvivorComforts.safeCall(def.id, def.addOptions, options)
    end
end

-- One heading and its features (defs of registered features, in order).
local function addGroup(title, defs, first)
    if not first then options:addSeparator() end
    if title then
        options:addTitle(getText(title))
    else
        options:addTitle(getText(defs[1].name))
    end
    for i, def in ipairs(defs) do
        local label = (not title and i == 1) and "UI_SurvivorComforts_Enable" or def.name
        SurvivorComforts.safeCall(def.id, addFeatureOptions, def, label)
    end
end

local function buildAll()
    local byId = {}
    for _, def in ipairs(pending) do byId[def.id] = def end
    local first = true
    for _, group in ipairs(OPTION_GROUPS) do
        local defs = {}
        for _, id in ipairs(group.features) do
            if byId[id] then
                table.insert(defs, byId[id])
                byId[id] = nil
            end
        end
        if #defs > 0 then
            SurvivorComforts.safeCall("Options", addGroup, group.title, defs, first)
            first = false
        end
    end
    for _, def in ipairs(pending) do
        if byId[def.id] then
            SurvivorComforts.safeCall("Options", addGroup, nil, { def }, first)
            first = false
        end
    end
end

-- Never raises: it runs inside the game's ModOptions:load, and an error there
-- would stop every other mod's options from loading. A feature whose options
-- failed to build has no tick box, so isEnabled() treats it as off.
function SurvivorComforts.buildOptions()
    if built then return end
    built = true
    SurvivorComforts.safeCall("Options", buildAll)
    pending = {}
end

-- def = { id = "F08", name = "UI_..._Name", tooltip = "UI_..._Tooltip", default = true,
--         addOptions = function(options) ... end }
-- addOptions adds the feature's own options below its "enable" tick box, in
-- this order: the sidebar button, the key, then anything else.
function SurvivorComforts.registerFeature(def)
    SurvivorComforts.features[def.id] = def
    if built then
        -- Too late for its group: it gets a heading of its own at the end.
        SurvivorComforts.safeCall(def.id, addGroup, nil, { def }, false)
    else
        table.insert(pending, def)
    end
end

-- The game reads the saved values when it builds the options screen; the
-- page has to be complete by then. Only our part is guarded; errors from the
-- original load still reach the game as before.
local original_load = PZAPI.ModOptions.load
function PZAPI.ModOptions:load(...)
    pcall(SurvivorComforts.buildOptions)
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
