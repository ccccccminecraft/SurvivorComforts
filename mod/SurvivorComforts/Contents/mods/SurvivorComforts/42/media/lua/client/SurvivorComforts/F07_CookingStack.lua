-- F07: list each kind of ingredient once in the "add ingredient" menu of
-- evolved recipes (soup, salad, sandwich...), and use the one with the least
-- left.
--
-- Vanilla (ISInventoryPaneContextMenu.doEvorecipeMenu) only merges items of
-- the same type whose use amount is also the same, and never merges spices,
-- so a stocked kitchen gives a long list. This replaces only how the list is
-- built; adding the ingredient still goes through the vanilla
-- onAddItemInEvoRecipe / ISAddItemInRecipe.

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

-- Returns the groups in the order their first item appears, so the menu keeps the vanilla order.
local function groupItems(items, evorecipe, baseItem)
    local groups, order = {}, {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item ~= baseItem then
            local key = groupKey(item, evorecipe)
            local group = groups[key]
            if not group then
                group = { item = item, count = 0 }
                groups[key] = group
                table.insert(order, group)
            elseif remainingAmount(item) < remainingAmount(group.item) then
                group.item = item
            end
            group.count = group.count + 1
        end
    end
    return order
end

-- Same as the vanilla text after the item name: use amount, or "spice".
local function extraInfoFor(item, evorecipe, cookingLvl)
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

-- Follows the vanilla doEvorecipeMenu; only the item list part differs.
local function doEvorecipeMenu(context, items, player, evorecipe, baseItem, containerList)
    local playerObj = getSpecificPlayer(player)
    local cookingLvl = playerObj:getPerkLevel(Perks.Cooking)
    for i = 0, evorecipe:size() - 1 do
        local evorecipe2 = evorecipe:get(i)
        local usable = evorecipe2:getItemsCanBeUse(playerObj, baseItem, containerList)
        -- Vanilla stops at the first recipe with nothing to add; kept the same.
        if usable:size() == 0 then
            break
        end
        local catList = ISInventoryPaneContextMenu.getEvoItemCategories(usable, evorecipe2)
        local isResult = evorecipe2:isResultItem(baseItem)
        local fromName = getText("ContextMenu_EvolvedRecipe_" .. evorecipe2:getUntranslatedName())
        local subOption
        if isResult then
            subOption = context:addOption(fromName, nil)
        else
            subOption = context:addOption(getText("ContextMenu_Create_From_Ingredient", fromName), nil)
        end
        local subMenuRecipe = context:getNew(context)
        context:addSubMenu(subOption, subMenuRecipe)

        for foodType, list in pairs(catList) do
            if getText("ContextMenu_FoodType_" .. foodType) ~= "ContextMenu_FoodType_" .. foodType then
                local txt = getText("ContextMenu_FromRandom", getText("ContextMenu_FoodType_" .. foodType))
                if isResult then
                    txt = getText("ContextMenu_AddRandom", getText("ContextMenu_FoodType_" .. foodType))
                end
                subMenuRecipe:addOption(txt, evorecipe2, ISInventoryPaneContextMenu.onAddItemInEvoRecipe, baseItem, list[ZombRand(1, #list + 1)], player)
            end
        end

        for _, group in ipairs(groupItems(usable, evorecipe2, baseItem)) do
            local evoItem = group.item
            -- Vanilla flags (read elsewhere) for servers that disable poisoning.
            if SandboxVars.EnablePoisoning == 2 then disablePoison = true end
            if SandboxVars.EnablePoisoning == 3 and evoItem:getType() == "Bleach" then disablePoison = true end

            local extraInfo = extraInfoFor(evoItem, evorecipe2, cookingLvl)
            if baseItem:getFullType() == "Base.Chum" then
                extraInfo = ""
            end
            if group.count > 1 then
                extraInfo = extraInfo .. " " .. getText("UI_SurvivorComforts_F07_Count", group.count)
            end
            ISInventoryPaneContextMenu.addItemInEvoRecipe(subMenuRecipe, baseItem, evoItem, extraInfo, evorecipe2, player)
        end
    end
end

local original_doEvorecipeMenu = ISInventoryPaneContextMenu.doEvorecipeMenu
function ISInventoryPaneContextMenu.doEvorecipeMenu(context, items, player, evorecipe, baseItem, containerList)
    if not SurvivorComforts.isEnabled(FEATURE_ID) then
        return original_doEvorecipeMenu(context, items, player, evorecipe, baseItem, containerList)
    end
    -- If this ever breaks after a game update, fall back to the vanilla menu.
    local ok = SurvivorComforts.safeCall(FEATURE_ID, doEvorecipeMenu, context, items, player, evorecipe, baseItem, containerList)
    if not ok then
        return original_doEvorecipeMenu(context, items, player, evorecipe, baseItem, containerList)
    end
end
