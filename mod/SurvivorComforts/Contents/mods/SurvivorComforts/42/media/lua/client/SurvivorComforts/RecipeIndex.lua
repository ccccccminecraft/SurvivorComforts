-- F16: the index of what makes and uses each item, from every crafting and
-- building recipe the game has loaded (mods' recipes too).
--
--   local index = SurvivorComforts.recipeIndex.get()  -- nil if it could not be built
--   index.items["Base.Plank"] = { fullType, script, name, texture, category,
--                                 made = { recipe, ... }, consumed = { recipe, ... },
--                                 tool = { recipe, ... },
--                                 cooked, cookBase, cookIn = { cooking group, ... },
--                                 fixes, fixUse = { repair, ... } }
--   index.order = { entry, ... }  -- every item in some recipe, and every building, by name
--   index.cooking, index.fixes    -- every cooking group and repair (see addCooking, addFixing)
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
-- playing. For the same reason each recipe's description and key are worked
-- out once and kept. Kept apart from the window so the tests can check it.

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
local buildable = nil

-- The building list's names, read once.
local function buildableNames()
    if not buildable then
        buildable = {}
        local recipes = ScriptManager.instance:getAllBuildableRecipes()
        for i = 0, recipes:size() - 1 do
            buildable[recipes:get(i):getName()] = true
        end
    end
    return buildable
end
-- [recipe] = what recipeKey and describe gave for it.
local keys = {}
local described = {}

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
                  made = {}, consumed = {}, tool = {},
                  cooked = {}, cookBase = {}, cookIn = {}, fixes = {}, fixUse = {} }
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
        cooked = {}, cookBase = {}, cookIn = {}, fixes = {}, fixUse = {},
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

---------------------------------------------------------------------------
-- Cooking (evolved recipes: soup, salad... a base with ingredients added)
-- and repairs (fixing), stage 3
---------------------------------------------------------------------------
-- An item script by its name, "Base.Pot" or "Pot"; nil when the game has no
-- such item. A name without a module (fixing scripts may leave it out) is
-- looked for in module first, as vanilla does, then in Base.
local scriptCache = {}
local function scriptOf(name, module)
    if type(name) ~= "string" or name == "" then return nil end
    local plain = not string.find(name, ".", 1, true)
    if plain and module then name = module .. "." .. name end
    local cached = scriptCache[name]
    if cached ~= nil then return cached or nil end
    local script = ScriptManager.instance:getItem(name)
    if not script and plain and module and module ~= "Base" then
        script = ScriptManager.instance:getItem("Base." .. string.sub(name, string.len(module) + 2))
    end
    scriptCache[name] = script or false
    return script
end

-- What a script's name is, kept: the "can make" checks ask often.
local function fullTypes(scripts)
    local types = {}
    for i, script in ipairs(scripts) do
        types[i] = script:getFullName()
    end
    return types
end

-- Adds script to list unless seen[fullType] already.
local function addOnce(list, seen, script)
    if not script then return end
    local fullType = script:getFullName()
    if seen[fullType] then return end
    seen[fullType] = true
    table.insert(list, script)
end

-- Cooking recipes with the same name (a soup in a pot, a soup in a bucket)
-- are one group:
--   { cook = true, key, name, hidden, recipes = { evolved, ... },
--     bases = { script, ... }, results = { script, ... }, items = { script, ... },
--     minItems, maxItems, cookable }
-- Hidden ones are a group of their own, shown only with the option on.
local function addCooking(items, groups, list)
    local byKey = {}
    for i = 0, list:size() - 1 do
        local evolved = list:get(i)
        local name = evolved:getName() or evolved:getUntranslatedName() or "?"
        local hidden = evolved:isHidden() == true
        local key = "e:" .. name .. (hidden and "|h" or "")
        local group = byKey[key]
        if not group then
            group = { cook = true, key = key, name = name, hidden = hidden, recipes = {},
                      bases = {}, results = {}, items = {}, seen = { bases = {}, results = {}, items = {} } }
            byKey[key] = group
            table.insert(groups, group)
        end
        table.insert(group.recipes, evolved)
        local maxItems = evolved:getMaxItems()
        group.minItems = math.min(group.minItems or maxItems, maxItems)
        group.maxItems = math.max(group.maxItems or maxItems, maxItems)
        if evolved:isCookable() then group.cookable = true end
        addOnce(group.bases, group.seen.bases, scriptOf(evolved:getBaseItem()))
        addOnce(group.results, group.seen.results, scriptOf(evolved:getFullResultItem()))
        local possible = evolved:getPossibleItems()
        for j = 0, possible:size() - 1 do
            addOnce(group.items, group.seen.items, scriptOf(possible:get(j):getFullType()))
        end
    end
    for _, group in ipairs(groups) do
        group.seen = nil
        group.baseTypes = fullTypes(group.bases)
        group.itemTypes = fullTypes(group.items)
        local added = {}
        local function add(kind, script)
            local entry = addEntry(items, script)
            if added[entry.fullType .. kind] then return end
            added[entry.fullType .. kind] = true
            table.insert(entry[kind], group)
        end
        for _, script in ipairs(group.results) do add("cooked", script) end
        for _, script in ipairs(group.bases) do add("cookBase", script) end
        for _, script in ipairs(group.items) do add("cookIn", script) end
    end
end

-- One repair: { fix = true, key, name, fixing, required = { script, ... },
--   fixers = { { script, count, skills = { { name, perk, level }, ... } }, ... },
--   global = { script, count } or nil, modifier }
local function readFixer(fixer, module)
    local script = fixer and scriptOf(fixer:getFixerName(), module)
    if not script then return nil end
    local result = { script = script, fullType = script:getFullName(), count = fixer:getNumberOfUse(), skills = {} }
    local skills = fixer:getFixerSkills()
    if skills then
        for i = 0, skills:size() - 1 do
            local skill = skills:get(i)
            local perk = Perks.FromString(skill:getSkillName())
            local perkInfo = perk and PerkFactory.getPerk(perk)
            table.insert(result.skills, {
                name = perkInfo and perkInfo:getName() or skill:getSkillName(),
                perk = perk, level = skill:getSkillLevel(),
            })
        end
    end
    return result
end

local function addFixing(items, fixes, list)
    for i = 0, list:size() - 1 do
        local fixing = list:get(i)
        local name = fixing:getName() or "?"
        local moduleObject = fixing:getModule()
        local module = moduleObject and moduleObject:getName() or "Base"
        -- Told apart by module and name: a mod may add a repair of the same name.
        local fix = { fix = true, key = "f:" .. module .. "." .. name, name = name, fixing = fixing,
                      required = {}, fixers = {}, modifier = fixing:getConditionModifier() }
        local seen = {}
        local required = fixing:getRequiredItem()
        for j = 0, required:size() - 1 do
            addOnce(fix.required, seen, scriptOf(required:get(j), module))
        end
        fix.requiredTypes = fullTypes(fix.required)
        local fixers = fixing:getFixers()
        for j = 0, fixers:size() - 1 do
            local fixer = readFixer(fixers:get(j), module)
            if fixer then table.insert(fix.fixers, fixer) end
        end
        fix.global = readFixer(fixing:getGlobalItem(), module)
        if #fix.required > 0 then
            table.insert(fixes, fix)
            local added = {}
            local function add(kind, script)
                local entry = addEntry(items, script)
                if added[entry.fullType .. kind] then return end
                added[entry.fullType .. kind] = true
                table.insert(entry[kind], fix)
            end
            for _, script in ipairs(fix.required) do add("fixes", script) end
            for _, fixer in ipairs(fix.fixers) do add("fixUse", fixer.script) end
            if fix.global then add("fixUse", fix.global.script) end
        end
    end
end

-- The cooking groups to show: without the hidden ones unless showHidden.
-- Kept for each list (a search asks for thousands of them on each key).
local visibleKept = {}
function recipeIndex.visibleCooking(groups, showHidden)
    if showHidden or #groups == 0 then return groups end
    local shown = visibleKept[groups]
    if shown then return shown end
    shown = {}
    for _, group in ipairs(groups) do
        if not group.hidden then table.insert(shown, group) end
    end
    visibleKept[groups] = shown
    return shown
end

local function build()
    local items = {}
    -- A recipe found in both lists is added once.
    local seen = {}
    local count = 0
    local function addList(recipes)
        for i = 0, recipes:size() - 1 do
            local recipe = recipes:get(i)
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
    addList(ScriptManager.instance:getAllCraftRecipes())
    addList(ScriptManager.instance:getAllBuildableRecipes())
    local cooking, fixes = {}, {}
    addCooking(items, cooking, ScriptManager.instance:getAllEvolvedRecipesList())
    addFixing(items, fixes, ScriptManager.instance:getAllFixing(ArrayList.new()))
    local order = {}
    for _, entry in pairs(items) do
        table.insert(order, entry)
    end
    table.sort(order, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.fullType < b.fullType
    end)
    return { items = items, order = order, recipeCount = count, cooking = cooking, fixes = fixes }
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
    buildable = nil
    keys = {}
    described = {}
    scriptCache = {}
    visibleKept = {}
end

-- The crafting recipes that make the item (items are never the result of
-- building): { recipe, ... }, empty for an item no crafting recipe makes.
function recipeIndex.craftRecipesOf(fullType)
    local index = recipeIndex.get()
    local entry = index and index.items[fullType]
    local recipes = {}
    if not entry or entry.building then return recipes end
    for _, recipe in ipairs(entry.made) do
        if not recipeIndex.isBuild(recipe) then table.insert(recipes, recipe) end
    end
    return recipes
end

-- Whether some crafting recipe makes the item, for "show recipes" (F03, F06,
-- F12, F16). If the index cannot be built, the option is offered anyway.
function SurvivorComforts.hasRecipe(fullType)
    if not recipeIndex.get() then return true end
    return #recipeIndex.craftRecipesOf(fullType) > 0
end

function recipeIndex.isBuild(recipe)
    return recipe:isBuildableRecipe() == true or buildableNames()[recipe:getName()] == true
end

-- A key for one recipe: its name, apart for crafting and building (the two
-- lists may use the same name). Also used by RecipeCanMake.lua.
function recipeIndex.recipeKey(recipe)
    local key = keys[recipe]
    if not key then
        key = (recipeIndex.isBuild(recipe) and "b:" or "c:") .. recipe:getName()
        keys[recipe] = key
    end
    return key
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
-- Kept: the same table each time, not to be changed by the caller.
function recipeIndex.describe(recipe)
    local kept = described[recipe]
    if kept then return kept end
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
    described[recipe] = info
    return info
end
