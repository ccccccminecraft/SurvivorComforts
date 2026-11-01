-- Tests for F02 (inventory search) on the player's own inventory list, and
-- F07 (cooking ingredients) on its grouping. Items are added for the test
-- and taken out again; nothing is moved for real.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/Search"
require "SurvivorComforts/F02_InventorySearch"
require "SurvivorComforts/F07_CookingStack"

local T = SurvivorComfortsTests
local H = T.helpers
local search = SurvivorComforts.search

---------------------------------------------------------------------------
-- F02
---------------------------------------------------------------------------
local function inventoryPane(t)
    local page = getPlayerInventory(0)
    if not page or not page.inventoryPane then t:fail("no inventory window") end
    return page.inventoryPane
end

local function rowMatches(row, words, player)
    local item = row.items[1]
    return item ~= nil and search.matches(search.itemText(item:getFullType(), item:getName(player), search.useEnglish()), words)
end

-- Hammers to find, with English on (the game may be in another language).
local function setUp(t)
    local player = H.player(t)
    H.setOption(t, "F02_enabled", true)
    H.setOption(t, "F14_enabled", true)
    H.giveItems(t, player, "Base.Hammer", 2)
    local pane = inventoryPane(t)
    pane.survivorComfortsSearchWords = nil
    pane:refreshContainer()
    local allRows = #pane.itemslist
    t:cleanup(function()
        pane.survivorComfortsSearchWords = nil
        pane:refreshContainer()
    end)
    return player, pane, allRows
end

T.add("F02: matching rows first, the others dimmed below", function(t)
    local player, pane, allRows = setUp(t)
    H.setOption(t, "F02_dim", true)
    local words = search.parse("hammer")
    pane.survivorComfortsSearchWords = words
    pane:refreshContainer()
    local rows = pane.itemslist
    t:equal(#rows, allRows, "every row is still there")
    local matched, others = 0, 0
    for _, row in ipairs(rows) do
        if rowMatches(row, words, player) then
            t:equal(others, 0, "a matching row after the others")
            t:ok(not pane.survivorComfortsDimmed[row], "matching rows are not dimmed")
            matched = matched + 1
        else
            t:ok(pane.survivorComfortsDimmed[row], "other rows are dimmed")
            others = others + 1
        end
    end
    t:ok(matched >= 1, "the hammers are found")
    t:ok(others >= 1, "something else is in the inventory")
end)

T.add("F02: with dimming off, other rows are hidden", function(t)
    local player, pane = setUp(t)
    H.setOption(t, "F02_dim", false)
    local words = search.parse("hammer")
    pane.survivorComfortsSearchWords = words
    pane:refreshContainer()
    t:ok(#pane.itemslist >= 1, "the hammers are found")
    for _, row in ipairs(pane.itemslist) do
        t:ok(rowMatches(row, words, player), "only matching rows")
    end
end)

T.add("F02: an empty search and the feature off give the whole list back", function(t)
    local _, pane, allRows = setUp(t)
    H.setOption(t, "F02_dim", false)
    pane.survivorComfortsSearchWords = search.parse("hammer")
    pane:refreshContainer()
    pane.survivorComfortsSearchWords = nil
    pane:refreshContainer()
    t:equal(#pane.itemslist, allRows, "empty search")
    pane.survivorComfortsSearchWords = search.parse("hammer")
    H.setOption(t, "F02_enabled", false)
    pane:refreshContainer()
    t:equal(#pane.itemslist, allRows, "feature off")
end)

-- Records what "transfer all" would move, without moving anything.
local function recordTransfers(t)
    local moved = {}
    local oldAdd, oldDrop = ISTimedActionQueue.add, ISInventoryPaneContextMenu.dropItem
    ISTimedActionQueue.add = function(action)
        if action and action.item then table.insert(moved, action.item) end
    end
    ISInventoryPaneContextMenu.dropItem = function(item) table.insert(moved, item) end
    t:cleanup(function()
        ISTimedActionQueue.add = oldAdd
        ISInventoryPaneContextMenu.dropItem = oldDrop
    end)
    return moved
end

T.add("F02: transfer all moves only the matching items while searching", function(t)
    local player, pane = setUp(t)
    local words = search.parse("hammer")
    pane.survivorComfortsSearchWords = words
    local moved = recordTransfers(t)
    pane:transferAll()
    t:ok(#moved >= 2, "the hammers are moved")
    for _, item in ipairs(moved) do
        t:ok(search.matches(search.itemText(item:getFullType(), item:getName(player), search.useEnglish()), words),
            "only matching items: " .. item:getFullType())
    end
end)

T.add("F02: transfer all moves everything without a search", function(t)
    local player, pane = setUp(t)
    local words = search.parse("hammer")
    local moved = recordTransfers(t)
    pane:transferAll()
    local others = 0
    for _, item in ipairs(moved) do
        if not search.matches(search.itemText(item:getFullType(), item:getName(player), search.useEnglish()), words) then
            others = others + 1
        end
    end
    t:ok(#moved >= 2, "something is moved")
    t:ok(others >= 1, "items that are not hammers too")
end)

T.add("F02: the magnifier button follows the feature switch", function(t)
    local _, pane = setUp(t)
    local button = pane.survivorComfortsSearchButton
    if not t:ok(button, "the inventory list has the button") then return end
    t:ok(button:getIsVisible(), "shown while the feature is on")
    H.setOption(t, "F02_enabled", false)
    t:waitFor(function() return not button:getIsVisible() end, 3000, function(t2)
        H.setOption(t2, "F02_enabled", true)
        t2:waitFor(function() return button:getIsVisible() end, 3000)
    end)
end)

---------------------------------------------------------------------------
-- F07
---------------------------------------------------------------------------
-- A stand-in for an evolved recipe: nothing needs cooking first.
local soup = { needToBeCooked = function() return false end }

local function carrot(hunger, cooked)
    local item = instanceItem("Base.Carrots")
    item:setHungChange(hunger)
    if cooked then item:setCooked(true) end
    return item
end

T.add("F07: the same food is one line, using the one with least left first", function(t)
    local groupItems = SurvivorComforts.internals.F07.groupItems
    local items = ArrayList.new()
    local least = carrot(-0.05)
    items:add(carrot(-0.10))
    items:add(least)
    items:add(carrot(-0.08))
    items:add(carrot(-0.10, true))
    local groups = groupItems(items, soup, nil)
    local lines, raw = 0, nil
    for _, group in pairs(groups) do
        lines = lines + 1
        if not group.item:isCooked() then raw = group end
    end
    t:equal(lines, 2, "raw and cooked carrots are separate lines")
    if not t:ok(raw, "a line for the raw carrots") then return end
    t:equal(raw.count, 3, "three raw carrots")
    t:ok(raw.item == least, "the one with least left is used first")
end)

T.add("F07: the base item is not counted", function(t)
    local groupItems = SurvivorComforts.internals.F07.groupItems
    local items = ArrayList.new()
    local base = carrot(-0.10)
    items:add(base)
    items:add(carrot(-0.10))
    local count = 0
    for _, group in pairs(groupItems(items, soup, base)) do count = count + group.count end
    t:equal(count, 1)
end)
