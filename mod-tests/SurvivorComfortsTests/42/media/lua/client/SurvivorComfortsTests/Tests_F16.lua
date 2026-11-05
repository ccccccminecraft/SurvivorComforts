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
    local all, craft, build, cook, repair, uncraftable =
        f16.FILTERS[1], f16.FILTERS[2], f16.FILTERS[3], f16.FILTERS[4], f16.FILTERS[5], f16.FILTERS[6]
    local found = f16.findItems(index, SurvivorComforts.search.parse("plank"), all)
    local hasPlank = false
    for _, entry in ipairs(found) do
        if entry.fullType == "Base.Plank" then hasPlank = true end
    end
    t:ok(hasPlank, "'plank' finds planks (English names on)")
    t:equal(#f16.findItems(index, nil, all), #index.order, "no words: every item")
    -- "Cannot be made" overlaps neither craft, cooking nor build; build
    -- overlaps nothing; together with craft and cooking they are all
    -- (hidden cooking recipes counted).
    local function set(filter)
        local result = {}
        for _, entry in ipairs(f16.findItems(index, nil, filter, nil, nil, true)) do
            result[entry.fullType] = true
        end
        return result
    end
    local sets = { craft = set(craft), build = set(build), cook = set(cook), uncraftable = set(uncraftable) }
    local seen, count = {}, 0
    for name, members in pairs(sets) do
        for fullType in pairs(members) do
            if not seen[fullType] then
                seen[fullType] = true
                count = count + 1
            end
            if name ~= "craft" and name ~= "cook" then
                for other, others in pairs(sets) do
                    if other ~= name and others[fullType] then return t:fail(name .. " and " .. other .. ": " .. fullType) end
                end
            end
        end
    end
    t:equal(count, #index.order, "craft + build + cooking + cannot be made = all")
    for _, entry in ipairs(f16.findItems(index, nil, repair)) do
        if #entry.fixes == 0 then return t:fail("no repair, in repair: " .. entry.fullType) end
    end
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

T.add("F16: with can make on, the recipes that cannot be made now are dimmed on the right", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local plank = entryOf(t, index, "Base.Plank")
    if not plank or not t:ok(plank.made[1], "a recipe for planks") then return end
    local function dimOf(rows)
        local recipes, dimmed, inside = 0, 0, 0
        for _, row in ipairs(rows) do
            if row.recipe and row.toggle then
                recipes = recipes + 1
                if row.dim then dimmed = dimmed + 1 end
            elseif row.dim then
                inside = inside + 1
            end
        end
        return recipes, dimmed, inside
    end
    local _, dimmedOff = dimOf(f16.itemRows(plank, {}, nil))
    t:equal(dimmedOff, 0, "can make off: nothing dimmed")
    local recipes, dimmedNone, inside = dimOf(f16.itemRows(plank, {}, {}))
    t:equal(dimmedNone, recipes, "nothing can be made: every recipe dimmed")
    t:ok(inside > 0, "the rows inside an open recipe are dimmed too")
    local made = { [recipeIndex.recipeKey(plank.made[1])] = true }
    local rows = f16.itemRows(plank, {}, made)
    local _, dimmedOne = dimOf(rows)
    t:equal(dimmedOne, recipes - 1, "the one that can be made is not dimmed")
    for _, row in ipairs(rows) do
        if row.title or row.header then
            if row.dim then return t:fail("the item's row or a header is dimmed") end
        end
    end
end)

T.add("F16: opening a used-in recipe adds its rows", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local plank = entryOf(t, index, "Base.Plank")
    if not plank then return end
    local closed = #f16.itemRows(plank, {})
    local opened = #f16.itemRows(plank, { ["c|" .. recipeIndex.recipeKey(plank.consumed[1])] = true })
    t:ok(opened > closed, "more rows when the first used-in recipe is open")
end)

-- Stage 2: a material made by a crafting recipe opens to how it is made.
-- Some item made from a crafted material, found in the index.
local function madeFromCrafted(index)
    for _, entry in ipairs(index.order) do
        if not entry.building then
            for _, recipe in ipairs(entry.made) do
                for _, part in ipairs(recipeIndex.describe(recipe).consumed) do
                    local script = part.items and #part.items == 1 and part.items[1]
                    local material = script and index.items[script:getFullName()]
                    if material and material.fullType ~= entry.fullType and #material.made > 0 then
                        return entry, recipe, material
                    end
                end
            end
        end
    end
end

T.add("F16: a material made by a recipe opens to how it is made", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local entry, recipe, material = madeFromCrafted(index)
    if not t:ok(entry, "an item made from a crafted material") then return end
    local opened = {} -- the ways to make it start open
    local rows = f16.itemRows(entry, opened)
    local materialRow = nil
    for _, row in ipairs(rows) do
        if row.fullType == material.fullType and row.toggle then materialRow = row end
    end
    if not t:ok(materialRow, "the material has [+]: " .. material.fullType) then return end
    t:equal(materialRow.open, false, "closed at first")
    t:ok(materialRow.fullType ~= nil, "still a link")
    opened[materialRow.toggle] = true
    local more = f16.itemRows(entry, opened)
    t:ok(#more > #rows, "opening it adds rows")
    local inner = 0
    for _, row in ipairs(more) do
        if row.recipe and (row.indent or 0) > 0 then inner = inner + 1 end
    end
    t:ok(inner > 0, "a recipe one step in")
    for _, row in ipairs(more) do
        if row.toggle and row.fullType == entry.fullType then return t:fail("the item shown opens") end
    end
end)

T.add("F16: what is at hand comes first", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    -- Items: enough at hand, then too few, then none.
    local plank = entryOf(t, index, "Base.Plank")
    local nails = entryOf(t, index, "Base.Nails")
    local hammer = entryOf(t, index, "Base.Hammer")
    if not plank or not nails or not hammer then return end
    local rows = f16.newRows(nil, {}, nil, { counts = { ["Base.Hammer"] = 3, ["Base.Nails"] = 1 } })
    local sorted = rows:sortItems({ plank.script, nails.script, hammer.script }, 2)
    t:equal(sorted[1]:getFullName(), "Base.Hammer", "enough: first")
    t:equal(sorted[2]:getFullName(), "Base.Nails", "too few: second")
    t:equal(sorted[3]:getFullName(), "Base.Plank", "none: last")
    -- Recipes: those that can be made now first, else as given.
    local many = nil
    for _, entry in ipairs(index.order) do
        if #entry.made >= 2 then many = entry break end
    end
    if not t:ok(many, "an item with two ways to make it") then return end
    local last = many.made[#many.made]
    local order = f16.newRows(nil, {}, nil, { made = { [recipeIndex.recipeKey(last)] = true } }):sortRecipes(many.made)
    t:equal(order[1], last, "the one that can be made first")
    t:equal(#order, #many.made, "none lost")
    t:equal(f16.newRows(nil, {}, nil, {}):sortRecipes(many.made)[1], many.made[1], "else the game's order")
end)

T.add("F16: tools open only with expand tools on", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local toolLabel = getText("UI_SurvivorComforts_F16_Part_Tool")
    local function toolToggles(entry, tools)
        local count = 0
        for _, row in ipairs(f16.itemRows(entry, {}, nil, { tools = tools })) do
            if row.label == toolLabel and row.fullType and row.toggle then count = count + 1 end
        end
        return count
    end
    for _, entry in ipairs(index.order) do
        if not entry.building and toolToggles(entry, true) > 0 then
            t:equal(toolToggles(entry, false), 0, "off: no tool opens (" .. entry.fullType .. ")")
            return
        end
    end
    t:fail("no item with a crafted tool")
end)

T.add("F16: opening stops at the depth limit", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    local entry, recipe, material = madeFromCrafted(index)
    if not t:ok(entry, "an item made from a crafted material") then return end
    local rows = f16.newRows(entry.fullType, {}, nil, {})
    local node = { key = "x", depth = f16.MAX_DEPTH, ancestors = {} }
    t:equal(rows:canOpen(material.fullType, node), false, "at the limit: no [+]")
    node.depth = f16.MAX_DEPTH - 1
    t:equal(rows:canOpen(material.fullType, node), true, "one above: [+]")
    node.ancestors[material.fullType] = true
    t:equal(rows:canOpen(material.fullType, node), false, "already above it: no [+]")
end)

-- Stage 3: cooking (evolved recipes) and repairs (fixing).
T.add("F16: cooking and repairs are in the index", function(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not f16 or not index then return end
    t:ok(#index.cooking > 10, "cooking groups: " .. #index.cooking)
    t:ok(#index.fixes > 5, "repairs: " .. #index.fixes)
    -- Groups by name: no two groups of one name (apart from hidden ones).
    local names = {}
    for _, group in ipairs(index.cooking) do
        if names[group.key] then return t:fail("two groups: " .. group.key) end
        names[group.key] = true
        if #group.bases == 0 or #group.items == 0 then return t:fail("no base or ingredient: " .. group.key) end
    end
    local pot = entryOf(t, index, "Base.Pot")
    if pot then t:ok(#pot.cookBase > 0, "a pot is a base for cooking") end
    local shown = recipeIndex.visibleCooking(index.cooking, false)
    for _, group in ipairs(shown) do
        if group.hidden then return t:fail("a hidden group shown with the option off") end
    end
    t:equal(#recipeIndex.visibleCooking(index.cooking, true), #index.cooking, "all with the option on")
    -- Rows: a cooked item has a [cooking] row, open with its parts.
    for _, entry in ipairs(index.order) do
        if #entry.cooked > 0 then
            local cookRows, inside = 0, 0
            for _, row in ipairs(f16.itemRows(entry, {}, nil, { showHidden = true })) do
                if row.cook then cookRows = cookRows + 1 elseif (row.indent or 0) > 0 then inside = inside + 1 end
            end
            t:ok(cookRows > 0, "a cooking row for " .. entry.fullType)
            t:ok(inside >= 3, "its base, ingredients and result")
            break
        end
    end
    -- An item with a repair has a repair row in its own repairs section.
    for _, entry in ipairs(index.order) do
        if #entry.fixes > 0 then
            local fixRows = 0
            for _, row in ipairs(f16.itemRows(entry, {})) do
                if row.fix then fixRows = fixRows + 1 end
            end
            t:ok(fixRows >= #entry.fixes, "repair rows for " .. entry.fullType)
            break
        end
    end
end)

T.add("F16: cooking and repairs can be done now with what is at hand", function(t)
    local player = H.player(t)
    local index = getIndex(t)
    if not player or not index then return end
    local canMake = SurvivorComforts.recipeCanMake
    -- Some group with a pot as a base: a pot and one ingredient.
    local group = nil
    for _, value in ipairs(index.cooking) do
        for _, base in ipairs(value.bases) do
            if base:getFullName() == "Base.Pot" and not group then group = value end
        end
    end
    if t:ok(group, "a cooking group in a pot") then
        local ingredient = nil
        for _, script in ipairs(group.items) do
            if script:getFullName() ~= "Base.Pot" and not ingredient then ingredient = script end
        end
        H.giveItems(t, player, "Base.Pot", 1)
        H.giveItems(t, player, ingredient:getFullName(), 1)
        t:ok(canMake.check(0)[group.key], "can cook now: " .. group.key)
    end
    -- Some repair with no skills and no item every fixer needs.
    for _, fix in ipairs(index.fixes) do
        local fixer = fix.fixers[1]
        if fixer and #fixer.skills == 0 and not fix.global and fixer.count <= 3 then
            local item = fix.required[1]:getFullName()
            H.giveItems(t, player, item, 1)
            local extra = fixer.script:getFullName() == item and 1 or 0
            H.giveItems(t, player, fixer.script:getFullName(), fixer.count + extra)
            t:ok(canMake.check(0)[fix.key], "can repair now: " .. fix.key)
            return
        end
    end
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

-- Simple crafting recipes to try "can make now" with: made in hand, in the
-- dark, with no tools, skills or learning, from a few items.
local function simpleRecipes(index, max)
    local found, seen = {}, {}
    for _, entry in ipairs(index.order) do
        for _, recipe in ipairs(entry.made) do
            local key = recipeIndex.recipeKey(recipe)
            if not seen[key] and not recipeIndex.isBuild(recipe) then
                seen[key] = true
                local info = recipeIndex.describe(recipe)
                local simple = info.inHand and not info.needLight and not info.needLearn
                    and #info.tools == 0 and #info.skills == 0 and #info.consumed > 0
                for _, part in ipairs(info.consumed) do
                    if not part.items or #part.items == 0 or part.maxAmount or part.amount > 5 then simple = false end
                end
                if simple then
                    table.insert(found, info)
                    if #found >= max then return found end
                end
            end
        end
    end
    return found
end

T.add("F16: can make now: a simple recipe becomes possible with its materials", function(t)
    local player = H.player(t)
    local f16 = internals(t)
    local index = getIndex(t)
    if not player or not f16 or not index then return end
    local canMake = SurvivorComforts.recipeCanMake
    local made = canMake.check(0)
    if not t:ok(made, "checked") then return end
    t:equal(canMake.isDirty(0), false, "the check clears the dirty mark")
    -- With "can make" on, every entry found has a recipe that can be made
    -- now, also together with a filter.
    for _, filter in ipairs(f16.FILTERS) do
        for _, entry in ipairs(f16.findItems(index, nil, filter, made)) do
            if not f16.canMakeNow(entry, made) then return t:fail("cannot be made now: " .. entry.fullType) end
            if not filter.keep(entry) then return t:fail("not in its filter: " .. entry.fullType) end
        end
    end
    t:equal(#f16.findItems(index, nil, f16.FILTERS[6], made), 0, "cannot be made + can make: nothing")
    -- With dim: everything in the filter, what can be made first, the rest dimmed.
    local all = f16.FILTERS[1]
    local found, dimmed = f16.findItems(index, nil, all, made, true)
    t:equal(#found, #index.order, "dim: every entry is listed")
    local seenDimmed = false
    for _, entry in ipairs(found) do
        local isMade = f16.canMakeNow(entry, made)
        if isMade == (dimmed[entry] == true) then return t:fail("dimmed does not match can make: " .. entry.fullType) end
        if dimmed[entry] then
            seenDimmed = true
        elseif seenDimmed then
            return t:fail("can be made, after a dimmed one: " .. entry.fullType)
        end
    end
    -- Some simple recipe becomes possible once its materials are in the inventory.
    local candidates = simpleRecipes(index, 10)
    if not t:ok(#candidates > 0, "some simple recipe") then return end
    for _, info in ipairs(candidates) do
        for _, part in ipairs(info.consumed) do
            H.giveItems(t, player, part.items[1]:getFullName(), part.amount)
        end
        if canMake.check(0)[recipeIndex.recipeKey(info.recipe)] then
            local counts = canMake.counts(0)
            local first = info.consumed[1]
            t:ok((counts[first.items[1]:getFullName()] or 0) >= first.amount, "counted at hand")
            local again, changed = canMake.check(0)
            t:equal(changed, false, "nothing came or went: not changed")
            return
        end
    end
    t:fail("none of " .. #candidates .. " simple recipes became possible with their materials")
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
    local filter = window.filterCombo.selected
    local canMakeOn = window.canMakeBox:isSelected(1)
    window.history = {}
    window.forward = {}
    window.current = nil
    window.filterCombo.selected = 1
    window.canMakeBox:setSelected(1, false)
    t:cleanup(function()
        window.history = history
        window.forward = forward
        window.current = current
        window.filterCombo.selected = filter
        window.canMakeBox:setSelected(1, canMakeOn)
        window:refreshResults()
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
    local index = recipeIndex.get()
    t:equal(#window.itemList.items, #index.order, "an empty search lists everything")
    window.filterCombo.selected = 3
    window:refreshResults()
    t:equal(#window.itemList.items, #f16.findItems(index, nil, f16.FILTERS[3]), "an empty search with build: every building")
    window.filterCombo.selected = 1
    -- With "can make" on: what can be made now, and with the dim option on,
    -- everything else dimmed below.
    window.canMakeBox:setSelected(1, true)
    H.setOption(t, "F16_dim", false)
    window:checkCanMake(false, true)
    t:equal(#window.itemList.items, #f16.findItems(index, nil, f16.FILTERS[1], window.made), "can make, hide: what can be made, with an empty search")
    H.setOption(t, "F16_dim", true)
    window:refreshResults()
    t:equal(#window.itemList.items, #index.order, "can make, dim: everything, with an empty search")
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
