-- Shared right-click menu for the crafting and building windows (F03, F06).
--
-- Vanilla has no right-click there. A right-click on an ingredient or result
-- icon, a row of an ingredient's "items you can use" list, or a recipe in the
-- recipe list opens one menu, and every feature that registered with
-- SurvivorComforts.addCraftMenuProvider adds its lines to it.
--
--   SurvivorComforts.addCraftMenuProvider({
--       id = "F06", order = 2,
--       isEnabled = function() return ... end,
--       fill = function(context, playerNum, entries, kind) ... end,
--   })
--
-- entries = { { fullType = "Base.Plank", name = "Plank" }, ... }, the items
-- the click was on. kind is where the click was:
--   "ingredient"     an ingredient icon (the item it shows right now)
--   "result"         a result icon
--   "ingredientList" a row of the list of items that can be used for an ingredient
--   "recipe"         a recipe in the recipe list (entries are its results)

require "SurvivorComforts/Core"
require "ISUI/ISContextMenu"
require "Entity/ISUI/CraftRecipe/ISWidgetInput"
require "Entity/ISUI/CraftRecipe/ISWidgetOutput"
require "Entity/ISUI/CraftRecipe/ISRecipeScrollingListBox"
require "Entity/ISUI/CraftRecipe/ISTiledIconListBox"
require "Entity/ISUI/CraftRecipe/ISCraftInventoryPanel"

local providers = {}

function SurvivorComforts.addCraftMenuProvider(def)
    table.insert(providers, def)
    table.sort(providers, function(a, b) return (a.order or 0) < (b.order or 0) end)
end

local function anyEnabled()
    for _, def in ipairs(providers) do
        if def.isEnabled() then return true end
    end
    return false
end

local function showMenu(player, entries, kind)
    if #entries == 0 or not player then return end
    local playerNum = player:getPlayerNum()
    local context = ISContextMenu.get(playerNum, getMouseX(), getMouseY())
    for _, def in ipairs(providers) do
        if def.isEnabled() then
            SurvivorComforts.safeCall(def.id, def.fill, context, playerNum, entries, kind)
        end
    end
    if context:isEmpty() then
        context:hideAndChildren()
        context:setVisible(false)
    end
end

-- Adds a script item (scripts.Item) to entries once.
local function addScriptEntry(entries, seen, script)
    local fullType = script and script:getFullName()
    if fullType and not seen[fullType] then
        seen[fullType] = true
        table.insert(entries, { fullType = fullType, name = script:getDisplayName() })
    end
end

local function showMenuForScripts(player, scriptLists, kind)
    local entries, seen = {}, {}
    for _, list in ipairs(scriptLists) do
        for i = 0, list:size() - 1 do
            addScriptEntry(entries, seen, list:get(i))
        end
    end
    showMenu(player, entries, kind)
end

-- The item an ingredient or result icon is showing right now. An ingredient
-- that several items can be used for cycles through them (or shows the one
-- the player has).
local function shownItemEntry(values)
    if not values or not values.script or values.script:getResourceType() ~= ResourceType.Item then return nil end
    local fullType = values.inputFullName
    if not fullType then return nil end
    local script = ScriptManager.instance:getItem(fullType)
    return { fullType = fullType, name = values.iconText or (script and script:getDisplayName()) or fullType }
end

-- Item results of a recipe (fluids and energy are skipped; build recipes have none).
local function recipeResultLists(recipe)
    local lists = {}
    local outputs = recipe:getOutputs()
    for i = 0, outputs:size() - 1 do
        local output = outputs:get(i)
        if output:getResourceType() == ResourceType.Item then
            table.insert(lists, output:getPossibleResultItems())
        end
    end
    return lists
end

-- Clicks on a child (the icon, the label) reach the widget through either
-- onRightMouseUp or onRightMouseUpOutside, so the menu is opened only once per click.
local lastMenuMs = 0
local function openMenu(fn, ...)
    if not anyEnabled() then return end
    local now = getTimestampMs()
    if now - lastMenuMs < 100 then return end
    lastMenuMs = now
    SurvivorComforts.safeCall("CraftMenu", fn, ...)
end

local function hookRightClick(class, handler)
    if not class then return end
    local original_up = class.onRightMouseUp
    function class:onRightMouseUp(x, y)
        openMenu(handler, self, x, y)
        if original_up then return original_up(self, x, y) end
    end
    local original_outside = class.onRightMouseUpOutside
    function class:onRightMouseUpOutside(x, y)
        if self:isMouseOver() then
            openMenu(handler, self, x, y)
        end
        if original_outside then return original_outside(self, x, y) end
    end
end

-- Ingredient and result of the selected recipe: the item the icon shows.
local function iconHandler(kind)
    return function(self)
        local entry = shownItemEntry(self.primary)
        if entry then
            showMenu(self.player, { entry }, kind)
        end
    end
end
hookRightClick(ISWidgetInput, iconHandler("ingredient"))
hookRightClick(ISWidgetOutput, iconHandler("result"))

-- The list of items that can be used for an ingredient (opened by clicking an
-- ingredient). Its list box is a plain ISScrollingListBox, so the handler is
-- set on the instance.
local function onInventoryListRightClick(listBox, x, y)
    local row = listBox.items[listBox:rowAt(x, y)]
    local data = row and row.item
    -- Headers have no script; fluid rows have no item script.
    if data and data.script then
        local entries = {}
        addScriptEntry(entries, {}, data.script)
        showMenu(listBox.survivorComfortsPlayer, entries, "ingredientList")
    end
end

if ISCraftInventoryPanel then
    local original_createChildren = ISCraftInventoryPanel.createChildren
    function ISCraftInventoryPanel:createChildren()
        original_createChildren(self)
        local listBox = self.itemListBox
        if listBox then
            listBox.survivorComfortsPlayer = self.player
            local original_up = listBox.onRightMouseUp
            listBox.onRightMouseUp = function(_self, x, y)
                openMenu(onInventoryListRightClick, _self, x, y)
                if original_up then return original_up(_self, x, y) end
            end
        end
    end
end

-- Recipe list (list view).
hookRightClick(ISRecipeScrollingListBox, function(self, x, y)
    local row = self.items[self:rowAt(x, y)]
    local recipe = row and not row.groupNode and row.item
    if recipe then
        showMenuForScripts(self.player, recipeResultLists(recipe), "recipe")
    end
end)

-- Recipe list (icon view). The same tile list is used elsewhere, so only recipes are handled.
hookRightClick(ISTiledIconListBox, function(self, x, y)
    local recipe = self:getTileForCoordinate(x, y)
    if recipe and instanceof(recipe, "CraftRecipe") then
        local player = getSpecificPlayer(0)
        local panel = self.parent
        if panel and panel.player then player = panel.player end
        showMenuForScripts(player, recipeResultLists(recipe), "recipe")
    end
end)
