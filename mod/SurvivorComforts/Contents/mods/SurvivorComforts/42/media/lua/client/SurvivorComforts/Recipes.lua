-- Shared "show recipes" helpers (F06 wishlist window, F12 item menu).
--
-- Opens the vanilla crafting window filtered to the recipes that make an item,
-- the same filter vanilla uses for Shift+click on an ingredient.

require "SurvivorComforts/Core"
require "Entity/ISEntityUI"

-- fullType -> true for every item some crafting recipe makes. Recipes do not
-- change while playing, so this is built once, on first use.
local craftable = nil

local function buildIndex()
    craftable = {}
    local recipes = ScriptManager.instance:getAllCraftRecipes()
    for i = 0, recipes:size() - 1 do
        local outputs = recipes:get(i):getOutputs()
        for j = 0, outputs:size() - 1 do
            local output = outputs:get(j)
            if output:getResourceType() == ResourceType.Item then
                local items = output:getPossibleResultItems()
                for k = 0, items:size() - 1 do
                    craftable[items:get(k):getFullName()] = true
                end
            end
        end
    end
end

function SurvivorComforts.hasRecipe(fullType)
    if not craftable then
        local ok, err = pcall(buildIndex)
        if not ok then
            -- If the index cannot be built, offer the option anyway.
            SurvivorComforts.log("recipe index failed: " .. tostring(err))
            craftable = setmetatable({}, { __index = function() return true end })
        end
    end
    return craftable[fullType] == true
end

function SurvivorComforts.showRecipes(playerNum, fullType)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    if not ISEntityUI.IsWindowOpen(playerNum, "HandcraftWindow") then
        ISEntityUI.OpenHandcraftWindow(player, nil)
    end
    local window = ISEntityUI.GetWindowInstance(playerNum, "HandcraftWindow")
    local panel = window and window.handCraftPanel
    local filterPanel = panel and panel.recipesPanel and panel.recipesPanel.recipeFilterPanel
    if not filterPanel then return end
    filterPanel:filter("!" .. fullType, getText("IGUI_FilterType_OutputName"))
    window:bringToTop()
end
