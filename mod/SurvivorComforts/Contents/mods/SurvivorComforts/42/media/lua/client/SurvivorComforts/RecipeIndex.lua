-- F16: the index of what makes and uses each item, from every crafting and
-- building recipe the game has loaded (mods' recipes too).
--
--   local index = SurvivorComforts.recipeIndex.get()  -- nil if it could not be built
--   index.items["Base.Plank"] = { fullType, script, name, texture, category,
--                                 made = { recipe, ... }, consumed = { recipe, ... },
--                                 tool = { recipe, ... } }
--   index.order = { entry, ... }  -- every item in some recipe, and every building, by name
--
-- Building recipes make a placed object (a wall, a piece of furniture), not an
-- item, so each one is also an entry of its own, a "building":
--   index.items["build:<recipe name>"] = { fullType = that key, building = true,
--       recipe, name, texture, category, made = { recipe }, consumed = {}, tool = {} }
-- The crafting recipes and the building recipes are two lists in the game
-- (getAllCraftRecipes, getAllBuildableRecipes).
--   SurvivorComforts.recipeIndex.describe(recipe) -- what one recipe takes and makes
--
-- Built once, the first time it is asked for: recipes do not change while
-- playing. Kept apart from the window so the tests can check it.

require "SurvivorComforts/Core"
require "SurvivorComforts/Recipes"

SurvivorComforts.recipeIndex = SurvivorComforts.recipeIndex or {}
local recipeIndex = SurvivorComforts.recipeIndex

-- Tags that say where a recipe is made (compared in lower case); the other
-- tags without a module ("Forge", "Carpentry", ...) are kept as they are.
local IN_HAND = "inhandcraft"
local ANY_SURFACE = "anysurfacecraft"
local IN_DARK = "canbedoneindark"

local index = nil
local failed = false
-- Names of the recipes in the game's building list, so they count as
-- building recipes even if the recipe does not say so itself.
local buildable = {}

local function isItem(part)
    return part:getResourceType() == ResourceType.Item
end

-- Inputs that stay after crafting (tools) are "tool"; the others are used up.
local function inputKind(input)
    return (input:isKeep() or input:isTool()) and "tool" or "consumed"
end

-- The item's category as the inventory shows it, or nil.
local function categoryText(script)
    local category = script:getDisplayCategory()
    if not category or category == "" then return nil end
    return getText("IGUI_ItemCat_" .. category)
end

local function addEntry(items, script)
    local fullType = script:getFullName()
    local entry = items[fullType]
    if not entry then
        entry = { fullType = fullType, script = script, name = script:getDisplayName() or fullType,
                  texture = script:getNormalTexture(), category = categoryText(script),
                  made = {}, consumed = {}, tool = {} }
        items[fullType] = entry
    end
    return entry
end

function recipeIndex.buildingKey(recipe)
    return "build:" .. recipe:getName()
end

local function addBuilding(items, recipe)
    local key = recipeIndex.buildingKey(recipe)
    if items[key] then return end
    items[key] = {
        fullType = key, building = true, recipe = recipe,
        name = recipe:getTranslationName() or recipe:getName(),
        texture = recipe:getIconTexture(), category = getText("IGUI_CraftingWindow_Build"),
        made = { recipe }, consumed = {}, tool = {},
    }
end

-- Adds one recipe to the items it makes and uses. An item listed twice in one
-- recipe (as two inputs) is added once per kind.
local function addRecipe(items, recipe)
    local added = { made = {}, consumed = {}, tool = {} }
    local function add(kind, script)
        local entry = addEntry(items, script)
        if not added[kind][entry.fullType] then
            added[kind][entry.fullType] = true
            table.insert(entry[kind], recipe)
        end
    end
    local inputs = recipe:getInputs()
    for i = 0, inputs:size() - 1 do
        local input = inputs:get(i)
        if isItem(input) then
            local kind = inputKind(input)
            local scripts = input:getPossibleInputItems()
            for j = 0, scripts:size() - 1 do
                add(kind, scripts:get(j))
            end
        end
    end
    SurvivorComforts.forEachRecipeItem(recipe, "outputs", function(script)
        add("made", script)
    end)
end

local function build()
    local items = {}
    -- A recipe found in both lists is added once.
    local seen = {}
    local count = 0
    local function addList(recipes, fromBuildList)
        for i = 0, recipes:size() - 1 do
            local recipe = recipes:get(i)
            if fromBuildList then buildable[recipe:getName()] = true end
            local isBuilding = recipeIndex.isBuild(recipe)
            local key = recipeIndex.recipeKey(recipe)
            if not seen[key] then
                seen[key] = true
                count = count + 1
                addRecipe(items, recipe)
                if isBuilding then addBuilding(items, recipe) end
            end
        end
    end
    addList(ScriptManager.instance:getAllCraftRecipes(), false)
    addList(ScriptManager.instance:getAllBuildableRecipes(), true)
    local order = {}
    for _, entry in pairs(items) do
        table.insert(order, entry)
    end
    table.sort(order, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.fullType < b.fullType
    end)
    return { items = items, order = order, recipeCount = count }
end

-- The index, or nil when it could not be built (logged once).
function recipeIndex.get()
    if index or failed then return index end
    local ok, result = pcall(build)
    if ok then
        index = result
    else
        failed = true
        SurvivorComforts.log("F16 recipe index failed: " .. tostring(result))
    end
    return index
end

-- For the tests: build it again on the next get().
function recipeIndex.reset()
    index = nil
    failed = false
end

function recipeIndex.isBuild(recipe)
    return recipe:isBuildableRecipe() == true or buildable[recipe:getName()] == true
end

-- A key for one recipe: its name, apart for crafting and building (the two
-- lists may use the same name). Also used by RecipeCanMake.lua.
function recipeIndex.recipeKey(recipe)
    return (recipeIndex.isBuild(recipe) and "b:" or "c:") .. recipe:getName()
end

-- part = { items = { script, ... }, amount, maxAmount (when it varies) }
--     or { fluids = { name, ... }, amount (litres) }
local function readPart(part, isInput)
    local result = {}
    if isItem(part) then
        result.items = {}
        local scripts = isInput and part:getPossibleInputItems() or part:getPossibleResultItems()
        for i = 0, scripts:size() - 1 do
            table.insert(result.items, scripts:get(i))
        end
        result.amount = part:getIntAmount()
        if part:isVariableAmount() then
            result.maxAmount = part:getIntMaxAmount()
        end
        return result
    end
    if isInput and part:getResourceType() == ResourceType.Fluid then
        result.fluids = {}
        local fluids = part:getPossibleInputFluids()
        for i = 0, fluids:size() - 1 do
            table.insert(result.fluids, fluids:get(i):getDisplayName())
        end
        result.amount = part:getAmount()
        return result
    end
    return nil -- energy and the rest are not shown
end

-- What one recipe takes, makes and needs:
-- { recipe, name, isBuild, consumed = { part, ... }, tools = { part, ... },
--   outputs = { part, ... }, skills = { { name, level }, ... }, needLearn,
--   needLight, inHand, anySurface, places = { tag, ... } }
function recipeIndex.describe(recipe)
    local info = {
        recipe = recipe,
        name = recipe:getTranslationName(),
        isBuild = recipeIndex.isBuild(recipe),
        consumed = {}, tools = {}, outputs = {}, skills = {}, places = {},
        needLearn = recipe:needToBeLearn() == true,
        needLight = not recipe:canBeDoneInDark(),
    }
    local inputs = recipe:getInputs()
    for i = 0, inputs:size() - 1 do
        local input = inputs:get(i)
        local part = readPart(input, true)
        if part then
            table.insert(inputKind(input) == "tool" and info.tools or info.consumed, part)
        end
    end
    local outputs = recipe:getOutputs()
    for i = 0, outputs:size() - 1 do
        local part = readPart(outputs:get(i), false)
        if part then table.insert(info.outputs, part) end
    end
    for i = 0, recipe:getRequiredSkillCount() - 1 do
        local skill = recipe:getRequiredSkill(i)
        table.insert(info.skills, { name = skill:getPerk():getName(), level = skill:getLevel() })
    end
    local tags = recipe:getTags()
    for i = 0, tags:size() - 1 do
        local tag = tostring(tags:get(i))
        local lower = string.lower(tag)
        if lower == IN_HAND then
            info.inHand = true
        elseif lower == ANY_SURFACE then
            info.anySurface = true
        elseif lower ~= IN_DARK and not string.find(tag, ":", 1, true) then
            table.insert(info.places, tag)
        end
    end
    return info
end
