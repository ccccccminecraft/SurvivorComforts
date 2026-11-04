-- F16: which recipes a player can make right now, with what is in their
-- inventory and the containers and floor around them.
--
-- The game decides it, the same way the vanilla crafting and building
-- windows grey out the recipes that cannot be made
-- (ISRecipeScrollingListBox:isCraftable): a crafting logic is given the
-- containers and the recipes, and each recipe's cached info says whether it
-- is valid (known, the workstation is there) and can be performed (the
-- materials and tools are there). The build cheat is not followed (see
-- canMake.check).
--
--   local made, changed = SurvivorComforts.recipeCanMake.check(playerNum, fresh)
--   made[SurvivorComforts.recipeIndex.recipeKey(recipe)] == true
--   SurvivorComforts.recipeCanMake.counts(playerNum)["Base.Nails"] -- how many at hand
--
-- When to check again is up to the caller: the vanilla windows do it when
-- the inventory window refreshes its containers (refreshBackpacks), which
-- SurvivorComforts.recipeCanMake.isDirty(playerNum) follows.
--
-- The logics are kept for each player and given the recipes once, as the
-- vanilla windows do. A check gives them the containers again
-- (setContainers): the game looks again only when an item came or went, so
-- while nothing did, a check costs little and gives back the same table
-- (changed = false). fresh = true makes new logics, for what the items do not
-- tell (a recipe learnt, a skill level up).

require "SurvivorComforts/Core"
require "SurvivorComforts/RecipeIndex"
require "Entity/ISEntityUI"
require "ISUI/ISInventoryPage"
require "ISUI/ISInventoryPaneContextMenu"

SurvivorComforts.recipeCanMake = SurvivorComforts.recipeCanMake or {}
local canMake = SurvivorComforts.recipeCanMake
local recipeIndex = SurvivorComforts.recipeIndex

-- The vanilla crafting window looks this far for a surface to craft on.
local SURFACE_RADIUS = 2

-- [playerNum] = true when the containers may have changed since the last check.
local dirty = {}
-- [playerNum] = { player, craftLogic, buildLogic, surface, containers,
--                 made, counts = { [fullType] = count } or nil (not counted yet) }
local states = {}

-- The vanilla crafting and building windows are told to look again here, so
-- this follows the same moments: items moved, picked up, dropped, used, the
-- player moving to another square, a container placed or removed.
local original_refreshBackpacks = ISInventoryPage.refreshBackpacks
function ISInventoryPage:refreshBackpacks(...)
    if self.player then dirty[self.player] = true end
    return original_refreshBackpacks(self, ...)
end

function canMake.isDirty(playerNum)
    return dirty[playerNum] == true
end

function canMake.markDirty(playerNum)
    dirty[playerNum] = true
end

function canMake.findSurface(player)
    return ISEntityUI.FindCraftSurface(player, SURFACE_RADIUS)
end

-- Adds the recipes in the list that the logic says can be made now.
local function addMade(made, logic, recipes)
    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i)
        local info = logic:getCachedRecipeInfo(recipe)
        if info and info:isValid() and info:isCanPerform() then
            made[recipeIndex.recipeKey(recipe)] = true
        end
    end
end

-- { [recipe key] = true } for the recipes the player can make now, or nil
-- when there is no such player, and whether it changed since the last check
-- (true the first time). Clears the player's dirty mark.
function canMake.check(playerNum, fresh)
    local player = getSpecificPlayer(playerNum)
    if not player then return nil end
    dirty[playerNum] = false
    local state = states[playerNum]
    if not state or state.player ~= player then
        state = { player = player }
        states[playerNum] = state
        fresh = true
    end
    local changed = fresh == true
    -- Unlike the vanilla list, the build cheat is not looked at: it stays on
    -- once the debug "force build" button or the admin panel turns it on,
    -- and "can make" is about the materials at hand.
    local surface = canMake.findSurface(player)
    if fresh or surface ~= state.surface or not state.craftLogic then
        -- The crafting surface is given when the logic is made.
        state.surface = surface
        state.craftLogic = HandcraftLogic.new(player, nil, surface)
        state.craftLogic:setRecipes(ScriptManager.instance:getAllCraftRecipes())
        changed = true
    end
    if fresh or not state.buildLogic then
        state.buildLogic = BuildLogic.new(player, nil, nil)
        state.buildLogic:setRecipes(ScriptManager.instance:getAllBuildableRecipes())
        changed = true
    end
    local containers = ISInventoryPaneContextMenu.getContainers(player)
    state.containers = containers
    -- Both are told, each keeps its own list of the items.
    local craftChanged = state.craftLogic:setContainers(containers)
    local buildChanged = state.buildLogic:setContainers(containers)
    if craftChanged or buildChanged then changed = true end
    if not changed and state.made then return state.made, false end
    local made = {}
    addMade(made, state.craftLogic, ScriptManager.instance:getAllCraftRecipes())
    addMade(made, state.buildLogic, ScriptManager.instance:getAllBuildableRecipes())
    state.made = made
    state.counts = nil
    return made, true
end

-- { [fullType] = count } of the items at hand: the same items the check
-- looks at (each container's own items, as the game's crafting does), as of
-- the last check. Counted once after each check that found a change.
function canMake.counts(playerNum)
    local state = states[playerNum]
    if not state or not state.containers then return {} end
    if not state.counts then
        local counts = {}
        local containers = state.containers
        for i = 0, containers:size() - 1 do
            local items = containers:get(i):getItems()
            for j = 0, items:size() - 1 do
                local fullType = items:get(j):getFullType()
                counts[fullType] = (counts[fullType] or 0) + 1
            end
        end
        state.counts = counts
    end
    return state.counts
end
