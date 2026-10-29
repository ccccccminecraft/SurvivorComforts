-- F06: a personal wishlist of item types.
--
-- Right-click an item to add it to (or remove it from) the wishlist; in the
-- crafting and building windows, right-click an ingredient, a result or a
-- recipe in the list. Items on
-- the list are highlighted in the inventory and loot windows, so they stand
-- out when looting. The list itself can be opened in a small window.
--
-- The list is saved on this PC only (Zomboid/Lua/SurvivorComforts_Wishlist.txt),
-- never in the world, and is the same for every save and server.

require "SurvivorComforts/Core"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISInventoryPane"
require "Entity/ISUI/CraftRecipe/ISWidgetInput"
require "Entity/ISUI/CraftRecipe/ISWidgetOutput"
require "Entity/ISUI/CraftRecipe/ISRecipeScrollingListBox"
require "Entity/ISUI/CraftRecipe/ISTiledIconListBox"
require "Entity/ISUI/CraftRecipe/ISCraftInventoryPanel"
require "Entity/ISEntityUI"
require "SurvivorComforts/Sidebar"

local FEATURE_ID = "F06"
local FILE_NAME = "SurvivorComforts_Wishlist.txt"
local LAYOUT_NAME = "survivorcomforts.wishlist"
local HIGHLIGHT_COLOR = { r = 1, g = 0.65, b = 0.2 }

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F06_Name",
    tooltip = "UI_SurvivorComforts_F06_Tooltip",
})
SurvivorComforts.options:addKeyBind(FEATURE_ID .. "_key", getText("UI_SurvivorComforts_F06_Key"), 0)
SurvivorComforts.options:addTickBox(FEATURE_ID .. "_sidebar", getText("UI_SurvivorComforts_F06_Sidebar"), true, getText("UI_SurvivorComforts_F06_Sidebar_Tooltip"))

---------------------------------------------------------------------------
-- The list: item full types, in the order they were added.
---------------------------------------------------------------------------
local wishlist = nil  -- { set = { [fullType] = true }, order = { fullType, ... } }

local function load()
    wishlist = { set = {}, order = {} }
    local reader = getFileReader(FILE_NAME, true)
    if not reader then return end
    while true do
        local line = reader:readLine()
        if line == nil then break end
        line = string.trim(line)
        if line ~= "" and not wishlist.set[line] then
            wishlist.set[line] = true
            table.insert(wishlist.order, line)
        end
    end
    reader:close()
end

local function save()
    local writer = getFileWriter(FILE_NAME, true, false)
    for _, fullType in ipairs(wishlist.order) do
        writer:write(fullType .. "\r\n")
    end
    writer:close()
end

local function getList()
    if not wishlist then load() end
    return wishlist
end

local function contains(fullType)
    return getList().set[fullType] == true
end

local refreshWindows -- defined with the window below

local function add(fullTypes)
    local list = getList()
    for _, fullType in ipairs(fullTypes) do
        if not list.set[fullType] then
            list.set[fullType] = true
            table.insert(list.order, fullType)
        end
    end
    save()
    refreshWindows()
end

local function remove(fullTypes)
    local list = getList()
    for _, fullType in ipairs(fullTypes) do
        list.set[fullType] = nil
    end
    local order = {}
    for _, fullType in ipairs(list.order) do
        if list.set[fullType] then
            table.insert(order, fullType)
        end
    end
    list.order = order
    save()
    refreshWindows()
end

---------------------------------------------------------------------------
-- Highlight in the inventory / loot windows (details view).
-- Drawn after vanilla, over the rows whose item is on the list.
---------------------------------------------------------------------------
local function drawHighlights(pane)
    if not pane.items then return end
    local c = HIGHLIGHT_COLOR
    for i, entry in ipairs(pane.items) do
        -- A stack header is a table with .items; a row inside an open stack is the item itself.
        local item = entry.items and entry.items[1] or entry
        if item and item.getFullType and contains(item:getFullType()) then
            local y = (i - 1) * pane.itemHgt + pane.headerHgt
            pane:drawRect(1, y, pane:getWidth() - 1, pane.itemHgt, 0.12, c.r, c.g, c.b)
            pane:drawRect(1, y, 3, pane.itemHgt, 0.9, c.r, c.g, c.b)
        end
    end
end

local original_renderdetails = ISInventoryPane.renderdetails
function ISInventoryPane:renderdetails(doDragged)
    original_renderdetails(self, doDragged)
    -- The row list (self.items) is rebuilt only in the pass that is not for dragged items.
    if doDragged == false and SurvivorComforts.isEnabled(FEATURE_ID) then
        SurvivorComforts.safeCall(FEATURE_ID, drawHighlights, self)
    end
end

---------------------------------------------------------------------------
-- Window listing the wishlist
---------------------------------------------------------------------------
SurvivorComforts_WishlistList = ISScrollingListBox:derive("SurvivorComforts_WishlistList")

function SurvivorComforts_WishlistList:doDrawItem(y, item, alt)
    if (y + self:getYScroll() + self.itemheight < 0) or (y + self:getYScroll() >= self.height) then
        return y + self.itemheight
    end
    if self.selected == item.index then
        self:drawSelection(0, y, self:getWidth(), self.itemheight - 1)
    elseif self.mouseoverselected == item.index and self:isMouseOver() and not self:isMouseOverScrollBar() then
        self:drawMouseOverHighlight(0, y, self:getWidth(), self.itemheight - 1)
    end
    self:drawRectBorder(0, y, self:getWidth(), self.itemheight, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local iconSize = self.itemheight - 4
    local texture = item.item.texture
    if texture then
        self:drawTextureScaledAspect(texture, 4, y + 2, iconSize, iconSize, 1, 1, 1, 1)
    end
    local textY = y + (self.itemheight - self.fontHgt) / 2
    self:drawText(item.text, iconSize + 10, textY, 1, 1, 1, 1, self.font)
    return y + self.itemheight
end

-- Opens the vanilla crafting window filtered to the recipes that make the item,
-- the same filter vanilla uses for Shift+click on an ingredient.
local function showRecipes(playerNum, fullType)
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

function SurvivorComforts_WishlistList:onRightMouseUp(x, y)
    local index = self:rowAt(x, y)
    local row = self.items[index]
    if not row then return end
    self.selected = index
    local playerNum = self.parent.playerNum
    local fullTypes = { row.item.fullType }
    local context = ISContextMenu.get(playerNum, getMouseX(), getMouseY())
    context:addOption(getText("UI_SurvivorComforts_F06_ShowRecipes"), playerNum, function(num)
        SurvivorComforts.safeCall(FEATURE_ID, showRecipes, num, row.item.fullType)
    end)
    context:addOption(getText("UI_SurvivorComforts_F06_RemoveFromList"), fullTypes, remove)
end

function SurvivorComforts_WishlistList:render()
    ISScrollingListBox.render(self)
    if #self.items == 0 then
        self:drawTextCentre(getText("UI_SurvivorComforts_F06_Empty"), self.width / 2, 10, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

SurvivorComforts_WishlistWindow =ISCollapsableWindow:derive("SurvivorComforts_WishlistWindow")
SurvivorComforts_WishlistWindow.instances = {}

function SurvivorComforts_WishlistWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local buttonHgt = getTextManager():getFontHeight(UIFont.Small) + 6

    self.list = SurvivorComforts_WishlistList:new(0, th, self.width, 100)
    self.list:initialise()
    self.list:instantiate()
    self.list.font = UIFont.Small
    self.list.fontHgt = getTextManager():getFontHeight(UIFont.Small)
    self.list.itemheight = math.max(self.list.fontHgt, 24) + 4
    self.list.drawBorder = true
    self:addChild(self.list)

    local removeText = getText("UI_SurvivorComforts_F06_Remove")
    local buttonWid = getTextManager():MeasureStringX(UIFont.Small, removeText) + 20
    self.removeButton = ISButton:new(10, 0, buttonWid, buttonHgt, removeText, self, SurvivorComforts_WishlistWindow.onRemove)
    self.removeButton:initialise()
    self.removeButton:instantiate()
    self:addChild(self.removeButton)

    self:refresh()
end

-- Keep the list and the button fitting the window whenever it is resized.
function SurvivorComforts_WishlistWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if not self.list then return end
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local buttonHgt = self.removeButton:getHeight()
    local listHgt = math.max(0, self.height - th - rh - buttonHgt - 10)
    if self.list:getWidth() ~= self.width then self.list:setWidth(self.width) end
    if self.list:getHeight() ~= listHgt then self.list:setHeight(listHgt) end
    self.removeButton:setY(th + listHgt + 5)
    self.removeButton:setEnable(self.list.items[self.list.selected] ~= nil)
end


function SurvivorComforts_WishlistWindow:refresh()
    if not self.list then return end
    local selected = self.list.selected
    self.list:clear()
    for _, fullType in ipairs(getList().order) do
        local script = ScriptManager.instance:getItem(fullType)
        -- An item from a mod that is no longer loaded still shows, by its type name.
        local name = script and script:getDisplayName() or fullType
        local texture = script and script:getNormalTexture() or nil
        self.list:addItem(name, { fullType = fullType, texture = texture })
    end
    self.list.selected = math.min(math.max(selected, 1), math.max(#self.list.items, 1))
end

function SurvivorComforts_WishlistWindow:onRemove()
    local row = self.list.items[self.list.selected]
    if row then
        remove({ row.item.fullType })
    end
end

function SurvivorComforts_WishlistWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

function SurvivorComforts_WishlistWindow:new(x, y, width, height, playerNum)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.playerNum = playerNum
    o.title = getText("UI_SurvivorComforts_F06_Title")
    o.minimumWidth = 200
    o.minimumHeight = 150
    o.visibleOnStartup = false
    return o
end

refreshWindows = function()
    for _, window in pairs(SurvivorComforts_WishlistWindow.instances) do
        window:refresh()
    end
end

local function createWindow(playerNum)
    local x = getPlayerScreenLeft(playerNum) + 150
    local y = getPlayerScreenTop(playerNum) + 150
    local window = SurvivorComforts_WishlistWindow:new(x, y, 260, 320, playerNum)
    window:initialise()
    window:setVisible(false)
    SurvivorComforts_WishlistWindow.instances[playerNum] = window
    -- Only the first local player has a saved layout, like vanilla windows.
    if playerNum == 0 then
        ISLayoutManager.RegisterWindow(LAYOUT_NAME, ISCollapsableWindow, window)
    end
    return window
end

local function showWindow(playerNum, toggle)
    if not SurvivorComforts.isEnabled(FEATURE_ID) then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local window = SurvivorComforts_WishlistWindow.instances[playerNum] or createWindow(playerNum)
        if toggle and window:getIsVisible() then
            window:close()
            return
        end
        window:refresh()
        window:addToUIManager()
        window:setVisible(true)
        window:bringToTop()
    end)
end

SurvivorComforts.addSidebarButton({
    id = FEATURE_ID,
    order = 2,
    icon = "Wishlist",
    tooltip = "UI_SurvivorComforts_F06_Title",
    isShown = function()
        return SurvivorComforts.isEnabled(FEATURE_ID) and SurvivorComforts.getOptionValue(FEATURE_ID .. "_sidebar") == true
    end,
    isActive = function(playerNum)
        local window = SurvivorComforts_WishlistWindow.instances[playerNum]
        return window ~= nil and window:getIsVisible()
    end,
    onClick = function(playerNum)
        showWindow(playerNum, true)
    end,
})

---------------------------------------------------------------------------
-- Right-click menu
---------------------------------------------------------------------------
local MAX_MENU_ITEMS = 20

-- entries = { { fullType = "Base.Hammer", name = "Hammer" }, ... }
-- One kind of item gets a plain add/remove line; several get a submenu with
-- one add/remove line each.
local function addWishlistMenu(context, entries)
    if #entries == 0 then return end
    if #entries == 1 then
        local fullTypes = { entries[1].fullType }
        if contains(entries[1].fullType) then
            context:addOption(getText("UI_SurvivorComforts_F06_RemoveFromList"), fullTypes, remove)
        else
            context:addOption(getText("UI_SurvivorComforts_F06_AddToList"), fullTypes, add)
        end
        return
    end
    local option = context:addOption(getText("UI_SurvivorComforts_F06_Menu"), nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    for i, entry in ipairs(entries) do
        if i > MAX_MENU_ITEMS then break end
        local fullTypes = { entry.fullType }
        if contains(entry.fullType) then
            subMenu:addOption(getText("UI_SurvivorComforts_F06_RemoveItem", entry.name), fullTypes, remove)
        else
            subMenu:addOption(getText("UI_SurvivorComforts_F06_AddItem", entry.name), fullTypes, add)
        end
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

-- Items, from the inventory and loot windows.
local function onFillContextMenu(playerNum, context, items)
    if not SurvivorComforts.isEnabled(FEATURE_ID) then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local entries, seen = {}, {}
        for _, item in ipairs(ISInventoryPane.getActualItems(items)) do
            local fullType = item:getFullType()
            if not seen[fullType] then
                seen[fullType] = true
                table.insert(entries, { fullType = fullType, name = item:getName() })
            end
        end
        addWishlistMenu(context, entries)
    end)
end

---------------------------------------------------------------------------
-- Crafting and building windows. Vanilla has no right-click there, so a
-- right-click opens a menu with only the wishlist entries.
---------------------------------------------------------------------------
local function showMenu(player, entries)
    if #entries == 0 then return end
    local context = ISContextMenu.get(player:getPlayerNum(), getMouseX(), getMouseY())
    addWishlistMenu(context, entries)
end

local function showMenuForScripts(player, scriptLists)
    local entries, seen = {}, {}
    for _, list in ipairs(scriptLists) do
        for i = 0, list:size() - 1 do
            addScriptEntry(entries, seen, list:get(i))
        end
    end
    showMenu(player, entries)
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
local function openCraftMenu(fn, ...)
    if not SurvivorComforts.isEnabled(FEATURE_ID) then return end
    local now = getTimestampMs()
    if now - lastMenuMs < 100 then return end
    lastMenuMs = now
    SurvivorComforts.safeCall(FEATURE_ID, fn, ...)
end

local function hookRightClick(class, handler)
    if not class then return end
    local original_up = class.onRightMouseUp
    function class:onRightMouseUp(x, y)
        openCraftMenu(handler, self, x, y)
        if original_up then return original_up(self, x, y) end
    end
    local original_outside = class.onRightMouseUpOutside
    function class:onRightMouseUpOutside(x, y)
        if self:isMouseOver() then
            openCraftMenu(handler, self, x, y)
        end
        if original_outside then return original_outside(self, x, y) end
    end
end

-- Ingredient and result of the selected recipe: the item the icon shows.
local function onIconRightClick(self)
    local entry = shownItemEntry(self.primary)
    if entry then
        showMenu(self.player, { entry })
    end
end
hookRightClick(ISWidgetInput, onIconRightClick)
hookRightClick(ISWidgetOutput, onIconRightClick)

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
        showMenu(listBox.survivorComfortsPlayer, entries)
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
                openCraftMenu(onInventoryListRightClick, _self, x, y)
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
        showMenuForScripts(self.player, recipeResultLists(recipe))
    end
end)

-- Recipe list (icon view). The same tile list is used elsewhere, so only recipes are handled.
hookRightClick(ISTiledIconListBox, function(self, x, y)
    local recipe = self:getTileForCoordinate(x, y)
    if recipe and instanceof(recipe, "CraftRecipe") then
        local player = getSpecificPlayer(0)
        local panel = self.parent
        if panel and panel.player then player = panel.player end
        showMenuForScripts(player, recipeResultLists(recipe))
    end
end)

local function onKeyPressed(key)
    if key == nil or key == 0 then return end
    if key ~= SurvivorComforts.getOptionValue(FEATURE_ID .. "_key") then return end
    local player = getPlayer()
    if not player then return end
    showWindow(player:getPlayerNum(), true)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillContextMenu)
Events.OnKeyPressed.Add(onKeyPressed)
