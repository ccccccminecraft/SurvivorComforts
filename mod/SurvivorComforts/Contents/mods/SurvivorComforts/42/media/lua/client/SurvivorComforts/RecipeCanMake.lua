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
--   local made = SurvivorComforts.recipeCanMake.check(playerNum)
--   made[SurvivorComforts.recipeIndex.recipeKey(recipe)] == true
--
-- When to check again is up to the caller: the vanilla windows do it when
-- the inventory window refreshes its containers (refreshBackpacks), which
-- SurvivorComforts.recipeCanMake.isDirty(playerNum) follows.

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
-- when there is no such player. Clears the player's dirty mark.
function canMake.check(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player then return nil end
    -- The recipe keys need the index (which recipes are building ones).
    recipeIndex.get()
    dirty[playerNum] = false
    local containers = ISInventoryPaneContextMenu.getContainers(player)
    local craftRecipes = ScriptManager.instance:getAllCraftRecipes()
    local buildRecipes = ScriptManager.instance:getAllBuildableRecipes()
    local made = {}
    -- Unlike the vanilla list, the build cheat is not looked at: it stays on
    -- once the debug "force build" button or the admin panel turns it on,
    -- and "can make" is about the materials at hand.
    local craftLogic = HandcraftLogic.new(player, nil, canMake.findSurface(player))
    craftLogic:setContainers(containers)
    craftLogic:setRecipes(craftRecipes)
    addMade(made, craftLogic, craftRecipes)

    local buildLogic = BuildLogic.new(player, nil, nil)
    buildLogic:setContainers(containers)
    buildLogic:setRecipes(buildRecipes)
    addMade(made, buildLogic, buildRecipes)
    return made
end
