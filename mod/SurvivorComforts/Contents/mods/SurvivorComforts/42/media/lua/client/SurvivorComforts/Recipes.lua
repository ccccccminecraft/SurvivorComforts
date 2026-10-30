-- Shared "show recipes" helpers (F03 crafting menu, F06 wishlist window, F12
-- item menu).
--
-- Opens the vanilla crafting window filtered to the recipes that make an item,
-- the same filter vanilla uses for Shift+click on an ingredient. When the
-- window is already open, what it showed before (the search text and type,
-- "show all recipes" and the selected recipe) is remembered, so F03's back
-- button can go back to it. The history is forgotten when the window closes.

require "SurvivorComforts/Core"
require "Entity/ISEntityUI"
require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"

local MAX_HISTORY = 10

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

-- [playerNum] = { state, ... }, oldest first
local histories = {}

local function getWindow(playerNum)
    if not ISEntityUI.IsWindowOpen(playerNum, "HandcraftWindow") then return nil end
    return ISEntityUI.GetWindowInstance(playerNum, "HandcraftWindow")
end

local function getFilterPanel(panel)
    return panel and panel.recipesPanel and panel.recipesPanel.recipeFilterPanel
end

local function captureState(panel)
    local filterPanel = getFilterPanel(panel)
    if not filterPanel then return nil end
    local combo = filterPanel.filterTypeCombo
    local option = combo and combo.options[combo.selected]
    local tickBox = filterPanel.showAllRecipeTickBox
    return {
        text = filterPanel.searchEntryBox:getInternalText(),
        filterType = option and option.text,
        showAll = tickBox and tickBox:isSelected(1) or false,
        recipe = panel:getSelectedRecipe(),
    }
end

local function restoreState(panel, state)
    local filterPanel = getFilterPanel(panel)
    if not filterPanel then return end
    -- The rebuilt recipe list keeps the logic's recipe selected when it is in the list.
    if state.recipe then
        panel.logic:setRecipe(state.recipe)
    end
    if filterPanel.showAllRecipeTickBox then
        filterPanel.showAllRecipeTickBox:setSelected(1, state.showAll)
    end
    panel:setSeeAllRecipe(state.showAll)
    if filterPanel.filterTypeCombo and state.filterType then
        filterPanel.filterTypeCombo:selectOptionFromText(state.filterType)
    end
    filterPanel.searchEntryBox:setText(state.text or "")
    filterPanel.searchEntryBox:onTextChange()
    if state.recipe then
        local recipesPanel = panel.recipesPanel
        if recipesPanel.recipeListPanel then recipesPanel.recipeListPanel:setSelectedData(state.recipe) end
        if recipesPanel.recipeIconPanel then recipesPanel.recipeIconPanel:setSelectedData(state.recipe) end
    end
end

function SurvivorComforts.showRecipes(playerNum, fullType)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local window = getWindow(playerNum)
    if window then
        -- Remember what the open window showed, for the back button.
        local state = captureState(window.handCraftPanel)
        if state then
            local history = histories[playerNum] or {}
            table.insert(history, state)
            if #history > MAX_HISTORY then table.remove(history, 1) end
            histories[playerNum] = history
        end
    else
        histories[playerNum] = nil
        ISEntityUI.OpenHandcraftWindow(player, nil)
        window = ISEntityUI.GetWindowInstance(playerNum, "HandcraftWindow")
    end
    local filterPanel = getFilterPanel(window and window.handCraftPanel)
    if not filterPanel then return end
    filterPanel:filter("!" .. fullType, getText("IGUI_FilterType_OutputName"))
    window:bringToTop()
end

-- The search panel of the crafting window "show recipes" uses (crafting
-- benches have their own, which the history does not cover).
function SurvivorComforts.getHandcraftFilterPanel(playerNum)
    local window = getWindow(playerNum)
    return getFilterPanel(window and window.handCraftPanel)
end

function SurvivorComforts.canGoBack(playerNum)
    local history = histories[playerNum]
    return history ~= nil and #history > 0 and getWindow(playerNum) ~= nil
end

-- Shows what the crafting window showed before the last "show recipes".
function SurvivorComforts.goBack(playerNum)
    local history = histories[playerNum]
    local window = getWindow(playerNum)
    if not history or #history == 0 or not window then return end
    restoreState(window.handCraftPanel, table.remove(history))
end

-- Forget the history when the crafting window closes.
local original_onCloseWindow = ISHandCraftPanel.OnCloseWindow
function ISHandCraftPanel:OnCloseWindow()
    local player = self.player
    if player and player.getPlayerNum then
        histories[player:getPlayerNum()] = nil
    end
    return original_onCloseWindow(self)
end
