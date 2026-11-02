-- Tests for F16 (recipe finder): the index of what makes and uses each item
-- (RecipeIndex.lua), the search and filter, the rows of the right side, and
-- the window. Vanilla items only: planks are made by sawing logs and used up
-- in many recipes, nails are used up in building, a hammer is a tool.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/RecipeIndex"
require "SurvivorComforts/Search"
require "SurvivorComforts/F16_RecipeFinder"

local T = SurvivorComfortsTests
local H = T.helpers
local recipeIndex = SurvivorComforts.recipeIndex

local function getIndex(t)
    local index = recipeIndex.get()
    if not t:ok(index, "the index was built") then return nil end
    return index
end

local function entryOf(t, index, fullType)
    local entry = index.items[fullType]
    t:ok(entry, fullType .. " is in the index")
    return entry
end

local function internals(t)
    local f16 = SurvivorComforts.internals.F16
    t:ok(f16, "F16 internals")
    return f16
end

T.add("F16: the index has the recipes that make and use planks", function(t)
    local index = getIndex(t)
    if not index then return end
    t:ok(#index.order > 100, "more than 100 items")
    local plank = entryOf(t, index, "Base.Plank")
    if not plank then return end
    t:ok(#plank.made > 0, "planks are made by a recipe")
    t:ok(#plank.consumed > 0, "planks are used up in recipes")
    local makesPlanks = false
    for _, recipe in ipairs(plank.made) do
        SurvivorComforts.forEachRecipeItem(recipe, "outputs", function(script)
            if script:getFullName() == "Base.Plank" then makesPlanks = true end
        end)
    end
    t:ok(makesPlanks, "every 'made' recipe makes planks")
end)

T.add("F16: nails are used up in building, a hammer is a tool", function(t)
    local index = getIndex(t)
    if not index then return end
    local nails = entryOf(t, index, "Base.Nails")
    local hammer = entryOf(t, index, "Base.Hammer")
    if not nails or not hammer then return end
    local inBuilding = false
    for _, recipe in ipairs(nails.consumed) do
        if recipeIndex.isBuild(recipe) then inBuilding = true end
    end
    t:ok(inBuilding, "a building recipe uses up nails")
    t:ok(#hammer.tool > 0, "a hammer is a tool in some recipe")
end)

-- The first building in the index, or nil.
local function firstBuilding(index)
    for _, entry in ipairs(index.order) do
        if entry.building then return entry end
    end
    return nil
end

T.add("F16: building recipes are in the index, each as a building", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local building = firstBuilding(index)
    if not t:ok(building, "some building") then return end
    t:ok(building.recipe and recipeIndex.isBuild(building.recipe), "made by a building recipe")
    t:equal(#building.made, 1, "one way to make it")
    t:ok(type(building.name) == "string" and building.name ~= "", "a name")
    local filter = f16.FILTERS[3]
    for _, entry in ipairs(f16.findItems(index, nil, filter)) do
        if not entry.building then return t:fail("not a building in the buildings filter: " .. entry.fullType) end
    end
    local rows = f16.itemRows(building, {})
    local recipeRows = 0
    for _, row in ipairs(rows) do
        if row.recipe then recipeRows = recipeRows + 1 end
    end
    t:equal(recipeRows, 1, "its building recipe, and no uses")
end)

T.add("F16: the order is by name, each item once", function(t)
    local index = getIndex(t)
    if not index then return end
    local seen = {}
    for i, entry in ipairs(index.order) do
        if seen[entry.fullType] then return t:fail("twice: " .. entry.fullType) end
        seen[entry.fullType] = true
        local before = index.order[i - 1]
        if before and before.name > entry.name then
            return t:fail("out of order: " .. before.fullType .. " before " .. entry.fullType)
        end
    end
end)

T.add("F16: describe tells used up, tools, outputs and conditions", function(t)
    local index = getIndex(t)
    if not index then return end
    local plank = entryOf(t, index, "Base.Plank")
    if not plank or not t:ok(plank.made[1], "a recipe for planks") then return end
    local info = recipeIndex.describe(plank.made[1])
    t:ok(type(info.name) == "string" and info.name ~= "", "a name")
    t:ok(#info.consumed > 0, "something is used up")
    t:ok(#info.outputs > 0, "an output")
    local withTool = false
    for _, recipe in ipairs(plank.made) do
        if #recipeIndex.describe(recipe).tools > 0 then withTool = true end
    end
    t:ok(withTool, "some way to make planks needs a tool (a saw)")
    for _, part in ipairs(info.consumed) do
        if part.items then
            t:ok(#part.items > 0, "a used-up part has items")
            t:ok(part.amount and part.amount > 0, "a used-up part has an amount")
        end
    end
end)

T.add("F16: search and filter", function(t)
    H.setOption(t, "F14_enabled", true)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local all, craft, build, uncraftable = f16.FILTERS[1], f16.FILTERS[2], f16.FILTERS[3], f16.FILTERS[4]
    local found = f16.findItems(index, SurvivorComforts.search.parse("plank"), all)
    local hasPlank = false
    for _, entry in ipairs(found) do
        if entry.fullType == "Base.Plank" then hasPlank = true end
    end
    t:ok(hasPlank, "'plank' finds planks (English names on)")
    t:equal(#f16.findItems(index, nil, all), #index.order, "no words: every item")
    -- Craft, build and "cannot be made" do not overlap and together are all.
    local seen = {}
    for _, filter in ipairs({ craft, build, uncraftable }) do
        for _, entry in ipairs(f16.findItems(index, nil, filter)) do
            if seen[entry.fullType] then return t:fail("in two filters: " .. entry.fullType) end
            seen[entry.fullType] = true
        end
    end
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    t:equal(count, #index.order, "craft + build + cannot be made = all")
    for _, entry in ipairs(f16.findItems(index, nil, craft)) do
        if entry.building or #entry.made == 0 then return t:fail("not a crafted item in craft: " .. entry.fullType) end
    end
    for _, entry in ipairs(f16.findItems(index, nil, uncraftable)) do
        if entry.building or #entry.made > 0 then return t:fail("can be made, in cannot be made: " .. entry.fullType) end
    end
end)

T.add("F16: rows for planks: title, open recipes, links, closed uses", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local plank = entryOf(t, index, "Base.Plank")
    if not plank then return end
    local rows = f16.itemRows(plank, {})
    t:ok(rows[1] and rows[1].title, "the first row is the item")
    local recipes, links, closedUses, selfLinks = 0, 0, 0, 0
    for _, row in ipairs(rows) do
        if row.recipe then
            recipes = recipes + 1
            if not row.open then closedUses = closedUses + 1 end
        end
        if row.fullType then links = links + 1 end
        if row.fullType == "Base.Plank" then selfLinks = selfLinks + 1 end
    end
    t:equal(recipes, #plank.made + #plank.consumed + #plank.tool, "one row per recipe")
    t:equal(closedUses, #plank.consumed + #plank.tool, "uses start closed, ways to make start open")
    t:ok(links > 0, "other items can be clicked")
    t:equal(selfLinks, 0, "planks themselves are not a link")
end)

T.add("F16: opening a used-in recipe adds its rows", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local plank = entryOf(t, index, "Base.Plank")
    if not plank then return end
    local closed = #f16.itemRows(plank, {})
    local opened = #f16.itemRows(plank, { c1 = true })
    t:ok(opened > closed, "more rows when the first used-in recipe is open")
end)

T.add("F16: the item's own row has the category and the item for the menu", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local plank = entryOf(t, index, "Base.Plank")
    if not plank then return end
    local title = f16.itemRows(plank, {})[1]
    t:ok(title and title.title, "the first row is the item")
    t:ok(title.item and title.item.fullType == "Base.Plank", "the menu's item")
    t:ok(type(title.sub) == "string" and string.find(title.sub, "Base.Plank", 1, true) ~= nil, "the type under the name")
end)

-- A stand-in for a context menu: records the lines added at the top.
local function fakeMenu()
    local menu = { texts = {} }
    function menu:addOption(text)
        table.insert(self.texts, text)
        return {}
    end
    function menu:getNew() return fakeMenu() end
    function menu:addSubMenu() end
    return menu
end

local function hasText(menu, text)
    for _, line in ipairs(menu.texts) do
        if line == text then return true end
    end
    return false
end

T.add("F16: right-click lines: craft for items and crafting recipes, build for building recipes", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local plank = entryOf(t, index, "Base.Plank")
    local nails = entryOf(t, index, "Base.Nails")
    if not plank or not nails then return end
    local craft = getText("UI_SurvivorComforts_F16_Craft")
    local build = getText("UI_SurvivorComforts_F16_Build")

    local menu = fakeMenu()
    f16.fillMenu(menu, 0, { item = { fullType = "Base.Plank", name = plank.name } })
    t:ok(hasText(menu, craft), "planks: craft")
    t:ok(not hasText(menu, build), "planks: no build")

    local buildRecipe, craftRecipe = nil, nil
    for _, recipe in ipairs(nails.consumed) do
        if recipeIndex.isBuild(recipe) then buildRecipe = buildRecipe or recipe else craftRecipe = craftRecipe or recipe end
    end
    if t:ok(buildRecipe, "a building recipe that uses nails") then
        menu = fakeMenu()
        f16.fillMenu(menu, 0, { recipe = buildRecipe })
        t:ok(hasText(menu, build), "building recipe: build")
    end
    menu = fakeMenu()
    f16.fillMenu(menu, 0, { recipe = plank.made[1] })
    t:ok(hasText(menu, craft), "recipe for planks: craft")

    local building = firstBuilding(index)
    if t:ok(building, "some building") then
        menu = fakeMenu()
        f16.fillMenu(menu, 0, { item = { fullType = building.fullType, name = building.name } })
        t:ok(hasText(menu, build), "a building: build")
        t:ok(not hasText(menu, craft), "a building: no craft")
    end
end)

T.add("F16: the window opens, finds and shows an item", function(t)
    H.player(t)
    H.setOption(t, "F16_enabled", true)
    local f16 = internals(t)
    if not f16 then return end
    local windows = f16.windows
    t:cleanup(function() windows.forEach(function(window) window:close() end) end)
    local window = windows.open(0)
    if not t:ok(window, "opened") then return end
    -- The window may have been used by hand before: start with no history,
    -- and put back what it showed afterwards.
    local history, forward, current = window.history, window.forward, window.current
    window.history = {}
    window.forward = {}
    window.current = nil
    t:cleanup(function()
        window.history = history
        window.forward = forward
        window.current = current
    end)
    window.searchBox:setText("plank")
    window:refreshResults()
    t:ok(#window.itemList.items > 0, "items found")
    window:showItem("Base.Plank")
    t:equal(window.current, "Base.Plank", "planks shown")
    t:ok(#window.detail.items > 0, "rows on the right")
    window:showItem("Base.Nails")
    t:equal(#window.history, 1, "planks in the history")
    window:onBack()
    t:equal(window.current, "Base.Plank", "back to planks")
    t:equal(#window.history, 0, "history empty again")
    t:equal(#window.forward, 1, "nails to go forward to")
    window:onForward()
    t:equal(window.current, "Base.Nails", "forward to nails")
    t:equal(#window.history, 1, "planks to go back to again")
    t:equal(#window.forward, 0, "nothing more to go forward to")
    window:onBack()
    window:showItem("Base.Hammer")
    t:equal(#window.forward, 0, "going to another item after going back clears forward")
    t:equal(window.history[#window.history], "Base.Plank", "planks to go back to")
    window.searchBox:setText("")
    window:refreshResults()
    t:equal(#window.itemList.items, 0, "an empty search lists nothing")
end)

T.add("F16: nothing opens while the feature is off", function(t)
    H.player(t)
    local f16 = internals(t)
    if not f16 then return end
    local windows = f16.windows
    t:cleanup(function() windows.forEach(function(window) window:close() end) end)
    windows.forEach(function(window) window:close() end)
    H.setOption(t, "F16_enabled", false)
    t:equal(windows.open(0), nil, "open")
end)
