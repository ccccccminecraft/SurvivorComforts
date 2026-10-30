-- F03: follow an ingredient to the recipes that make it, and back.
--
-- In the crafting and building windows, right-clicking an ingredient (its
-- icon, or a row of its "items you can use" list) offers "Show recipes": the
-- crafting window is filtered to the recipes that make it, the same filter as
-- vanilla's Shift+click (see Recipes.lua). A back button next to the search
-- box returns to what the crafting window showed before.

require "SurvivorComforts/Core"
require "SurvivorComforts/Recipes"
require "SurvivorComforts/CraftMenu"
require "ISUI/ISButton"
require "Entity/ISUI/CraftRecipe/ISWidgetRecipeFilterPanel"

local FEATURE_ID = "F03"
local BUTTON_GAP = 5

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F03_Name",
    tooltip = "UI_SurvivorComforts_F03_Tooltip",
})

local function isEnabled()
    return SurvivorComforts.isEnabled(FEATURE_ID)
end

---------------------------------------------------------------------------
-- "Show recipes" on ingredients (see CraftMenu.lua). Results and recipe rows
-- are the recipe being looked at, so they get nothing.
---------------------------------------------------------------------------
local function onShowRecipes(playerNum, fullType)
    SurvivorComforts.safeCall(FEATURE_ID, SurvivorComforts.showRecipes, playerNum, fullType)
end

local function addRecipeOption(menu, text, playerNum, fullType)
    local option = menu:addOption(text, playerNum, onShowRecipes, fullType)
    if not SurvivorComforts.hasRecipe(fullType) then
        option.notAvailable = true
    end
end

SurvivorComforts.addCraftMenuProvider({
    id = FEATURE_ID,
    order = 1,
    isEnabled = isEnabled,
    fill = function(context, playerNum, entries, kind)
        if kind ~= "ingredient" and kind ~= "ingredientList" then return end
        local text = getText("UI_SurvivorComforts_ShowRecipes")
        if #entries == 1 then
            addRecipeOption(context, text, playerNum, entries[1].fullType)
            return
        end
        local option = context:addOption(text, nil)
        local subMenu = context:getNew(context)
        context:addSubMenu(option, subMenu)
        for _, entry in ipairs(entries) do
            addRecipeOption(subMenu, entry.name, playerNum, entry.fullType)
        end
    end,
})

---------------------------------------------------------------------------
-- Back button, left of the search box of the crafting window. Shown only
-- while there is something to go back to.
---------------------------------------------------------------------------
local function panelPlayerNum(filterPanel)
    local target = filterPanel.callbackTarget
    local player = target and target.player
    return player and player.getPlayerNum and player:getPlayerNum() or nil
end

local function onBack(filterPanel)
    local playerNum = panelPlayerNum(filterPanel)
    if playerNum then
        SurvivorComforts.safeCall(FEATURE_ID, SurvivorComforts.goBack, playerNum)
    end
end

-- Places the button and moves the search box right to make room, from the
-- search box position vanilla's layout last set (searchBase).
local function applyBackButton(filterPanel)
    local box = filterPanel.searchEntryBox
    if not box then return end
    local playerNum = panelPlayerNum(filterPanel)
    local isHandcraft = playerNum ~= nil and SurvivorComforts.getHandcraftFilterPanel(playerNum) == filterPanel
    local show = isHandcraft and isEnabled() and SurvivorComforts.canGoBack(playerNum)

    local base = filterPanel.survivorComfortsSearchBase
    if not base then
        base = { x = box:getX(), width = box:getWidth() }
        filterPanel.survivorComfortsSearchBase = base
    end

    local button = filterPanel.survivorComfortsBackButton
    if show and not button then
        local text = getText("UI_SurvivorComforts_F03_Back")
        local width = getTextManager():MeasureStringX(UIFont.NewSmall, text) + 20
        button = ISButton:new(0, 0, width, box:getHeight(), text, filterPanel, onBack)
        button.font = UIFont.NewSmall
        button:initialise()
        button:instantiate()
        filterPanel:addChild(button)
        filterPanel.survivorComfortsBackButton = button
    end

    local x, width = base.x, base.width
    if show then
        button:setX(base.x)
        button:setY(box:getY())
        x = base.x + button:getWidth() + BUTTON_GAP
        width = base.width - button:getWidth() - BUTTON_GAP
    end
    if button and button:getIsVisible() ~= show then button:setVisible(show) end
    if box:getX() ~= x then box:setX(x) end
    if box:getWidth() ~= width then box:setWidth(width) end
end

local original_calculateLayout = ISWidgetRecipeFilterPanel.calculateLayout
function ISWidgetRecipeFilterPanel:calculateLayout(preferredWidth, preferredHeight)
    original_calculateLayout(self, preferredWidth, preferredHeight)
    -- Vanilla just placed the search box; that is the position without the button.
    if self.searchEntryBox then
        self.survivorComfortsSearchBase = { x = self.searchEntryBox:getX(), width = self.searchEntryBox:getWidth() }
    end
    SurvivorComforts.safeCall(FEATURE_ID, applyBackButton, self)
end

-- The history changes without a new layout, so follow it every frame.
local original_prerender = ISWidgetRecipeFilterPanel.prerender
function ISWidgetRecipeFilterPanel:prerender()
    SurvivorComforts.safeCall(FEATURE_ID, applyBackButton, self)
    original_prerender(self)
end
