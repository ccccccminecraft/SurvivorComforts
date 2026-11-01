-- Survivor Comforts tests: helpers shared by the test files.

require "SurvivorComfortsTests/Runner"

local T = SurvivorComfortsTests
local H = {}
T.helpers = H

-- The local player; the test fails when there is none (no game started).
function H.player(t)
    local player = getSpecificPlayer(0)
    if not player then t:fail("needs a game: start or load one first") end
    return player
end

-- Sets one of the mod's options for this test and puts it back afterwards.
function H.setOption(t, id, value)
    local option = SurvivorComforts.options:getOption(id)
    if not option then return t:fail("no option " .. id) end
    local old = option:getValue()
    option:setValue(value)
    t:cleanup(function() option:setValue(old) end)
end

-- A stand-in for another player, for the server's handlers in single
-- player: only what PlayerName.lua and Admin.lua look at.
function H.fakePlayer(name)
    return {
        getUsername = function() return name end,
        getDisplayName = function() return name end,
    }
end

-- The first n item types the game knows, in a fixed order.
function H.itemTypes(n)
    local types = {}
    local items = ScriptManager.instance:getAllItems()
    for i = 0, items:size() - 1 do
        table.insert(types, items:get(i):getFullName())
    end
    table.sort(types)
    local first = {}
    for i = 1, math.min(n, #types) do
        first[i] = types[i]
    end
    return first
end

-- A copy of a table and the tables in it (for saving data before a test).
function H.copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = H.copy(v)
    end
    return copy
end

-- Adds new items to the player's inventory and takes them out again after the test.
function H.giveItems(t, player, fullType, count)
    local inventory = player:getInventory()
    local items = {}
    for i = 1, count or 1 do
        local item = instanceItem(fullType)
        if not item then t:fail("no item " .. fullType) end
        inventory:AddItem(item)
        table.insert(items, item)
    end
    t:cleanup(function()
        for _, item in ipairs(items) do
            if item:getContainer() then item:getContainer():DoRemoveItem(item) end
        end
    end)
    return items
end
