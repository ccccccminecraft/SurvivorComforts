-- F12: right-click an item to see the recipes that make it.
--
-- Opens the vanilla crafting window filtered to those recipes (see Recipes.lua).
-- Shown only for items that some crafting recipe makes.

require "SurvivorComforts/Core"
require "SurvivorComforts/Recipes"
require "ISUI/ISInventoryPane"

local FEATURE_ID = "F12"

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F12_Name",
    tooltip = "UI_SurvivorComforts_F12_Tooltip",
})

local function onShowRecipes(playerNum, fullType)
    SurvivorComforts.safeCall(FEATURE_ID, SurvivorComforts.showRecipes, playerNum, fullType)
end

local function fillContextMenu(playerNum, context, items)
    local entries, seen = {}, {}
    for _, item in ipairs(ISInventoryPane.getActualItems(items)) do
        local fullType = item:getFullType()
        if not seen[fullType] then
            seen[fullType] = true
            if SurvivorComforts.hasRecipe(fullType) then
                table.insert(entries, { fullType = fullType, name = item:getName() })
            end
        end
    end
    if #entries == 0 then return end

    local text = getText("UI_SurvivorComforts_ShowRecipes")
    if #entries == 1 then
        context:addOption(text, playerNum, onShowRecipes, entries[1].fullType)
        return
    end
    -- Several kinds of item: one line per kind.
    local option = context:addOption(text, nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    for _, entry in ipairs(entries) do
        subMenu:addOption(entry.name, playerNum, onShowRecipes, entry.fullType)
    end
end

local function onFillContextMenu(playerNum, context, items)
    if not SurvivorComforts.isEnabled(FEATURE_ID) then return end
    SurvivorComforts.safeCall(FEATURE_ID, fillContextMenu, playerNum, context, items)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillContextMenu)
