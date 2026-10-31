-- F07: list each kind of ingredient once in the "add ingredient" menu of
-- evolved recipes (soup, salad, sandwich...), and use the one with the least
-- left.
--
-- Vanilla (ISInventoryPaneContextMenu.doEvorecipeMenu) only merges items of
-- the same type whose use amount is also the same, and never merges spices,
-- so a stocked kitchen gives a long list. The vanilla menu is still built by
-- the vanilla function (and whatever other mods added to it); while it runs,
-- ISInventoryPaneContextMenu.addItemInEvoRecipe, which adds one line per
-- item, is wrapped so that only the first item of each kind gets a line.

require "SurvivorComforts/Core"
require "ISUI/ISInventoryPaneContextMenu"

local FEATURE_ID = "F07"

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F07_Name",
    tooltip = "UI_SurvivorComforts_F07_Tooltip",
})

-- How much is left in the item; the smallest one is used first.
local function remainingAmount(item)
    if instanceof(item, "Food") then
        return math.abs(item:getHungerChange())
    end
    if item:IsDrainable() then
        return item:getCurrentUsesFloat()
    end
    return 1
end

-- Items are merged only when they look the same to the player and can be added
-- the same way (a frozen or uncooked one is never picked in place of a usable one).
local function groupKey(item, evorecipe)
    local key = item:getFullType() .. "|" .. item:getName()
    if instanceof(item, "Food") then
        key = key .. "|" .. tostring(item:isFrozen()) .. tostring(item:isRotten()) .. tostring(item:isFresh())
            .. tostring(item:isCooked()) .. tostring(item:isBurnt())
    end
    return key .. "|" .. tostring(evorecipe:needToBeCooked(item))
end

-- key -> { item = the one with the least left, count = how many }.
-- Counted from every usable item, since vanilla already drops some of them
-- before adding the lines.
local function groupItems(items, evorecipe, baseItem)
    local groups = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item ~= baseItem then
            local key = groupKey(item, evorecipe)
            local group = groups[key]
            if not group then
                groups[key] = { item = item, count = 1 }
            else
                if remainingAmount(item) < remainingAmount(group.item) then
                    group.item = item
                end
                group.count = group.count + 1
            end
        end
    end
    return groups
end

-- Same as the vanilla text after the item name: use amount, or "spice".
-- Only needed when the item vanilla passed is swapped for another one.
local function extraInfoFor(item, evorecipe, cookingLvl, baseItem)
    if baseItem:getFullType() == "Base.Chum" then
        return ""
    end
    if instanceof(item, "Food") then
        if item:isSpice() then
            return getText("ContextMenu_EvolvedRecipe_Spice")
        end
        local use = ISInventoryPaneContextMenu.getRealEvolvedItemUse(item, evorecipe, cookingLvl)
        if use then
            return "(" .. use .. ")"
        end
        return ""
    end
    if item:getScriptItem():isSpice() then
        return getText("ContextMenu_EvolvedRecipe_Spice")
    end
    return ""
end

-- Decides what one vanilla line becomes: nil to skip it (its kind already has
-- a line), or the item and text to add instead.
local function pickLine(state, baseItem, evoItem, extraInfo, evorecipe2)
    -- Vanilla goes through the recipes one at a time.
    if state.recipe ~= evorecipe2 then
        state.recipe = evorecipe2
        local usable = evorecipe2:getItemsCanBeUse(state.playerObj, baseItem, state.containerList)
        state.groups = groupItems(usable, evorecipe2, baseItem)
        state.shown = {}
    end
    local key = groupKey(evoItem, evorecipe2)
    if state.shown[key] then
        return nil
    end
    state.shown[key] = true
    local group = state.groups[key]
    if not group then
        return evoItem, extraInfo
    end
    if group.item ~= evoItem then
        evoItem = group.item
        extraInfo = extraInfoFor(evoItem, evorecipe2, state.playerObj:getPerkLevel(Perks.Cooking), baseItem)
    end
    if group.count > 1 then
        extraInfo = extraInfo .. " " .. getText("UI_SurvivorComforts_F07_Count", group.count)
    end
    return evoItem, extraInfo
end

local original_doEvorecipeMenu = ISInventoryPaneContextMenu.doEvorecipeMenu
function ISInventoryPaneContextMenu.doEvorecipeMenu(context, items, player, evorecipe, baseItem, containerList)
    if not SurvivorComforts.isEnabled(FEATURE_ID) then
        return original_doEvorecipeMenu(context, items, player, evorecipe, baseItem, containerList)
    end

    local state = { playerObj = getSpecificPlayer(player), containerList = containerList }
    local previous_add = ISInventoryPaneContextMenu.addItemInEvoRecipe
    ISInventoryPaneContextMenu.addItemInEvoRecipe = function(subMenuRecipe, base, evoItem, extraInfo, evorecipe2, plr)
        -- If this ever breaks after a game update, add the vanilla line as it is.
        local ok, item, info = pcall(pickLine, state, base, evoItem, extraInfo, evorecipe2)
        if not ok then
            SurvivorComforts.log(FEATURE_ID .. " failed: " .. tostring(item))
            item, info = evoItem, extraInfo
        end
        if item then
            return previous_add(subMenuRecipe, base, item, info, evorecipe2, plr)
        end
    end

    -- Put the vanilla function back even if the menu fails to build.
    local ok, err = pcall(original_doEvorecipeMenu, context, items, player, evorecipe, baseItem, containerList)
    ISInventoryPaneContextMenu.addItemInEvoRecipe = previous_add
    if not ok then
        error(err)
    end
end
