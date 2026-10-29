-- F06: wishlists of item types, a personal one and one shared by everyone on
-- the server.
--
-- Right-click an item to add it to (or remove it from) a wishlist; in the
-- crafting and building windows, right-click an ingredient, a result or a
-- recipe in the list. Items on a list are highlighted in the inventory and
-- loot windows, so they stand out when looting. The lists can be opened in a
-- small window.
--
-- The personal list is saved on this PC only
-- (Zomboid/Lua/SurvivorComforts_Wishlist.txt) and is the same for every save
-- and server. The shared list is kept by the server
-- (server/SurvivorComforts/F06_SharedWishlist.lua) and sent to every player.

require "SurvivorComforts/Core"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISTabPanel"
require "ISUI/ISInventoryPane"
require "Entity/ISUI/CraftRecipe/ISWidgetInput"
require "Entity/ISUI/CraftRecipe/ISWidgetOutput"
require "Entity/ISUI/CraftRecipe/ISRecipeScrollingListBox"
require "Entity/ISUI/CraftRecipe/ISTiledIconListBox"
require "Entity/ISUI/CraftRecipe/ISCraftInventoryPanel"
require "SurvivorComforts/Recipes"
require "SurvivorComforts/Sidebar"

local FEATURE_ID = "F06"
local FILE_NAME = "SurvivorComforts_Wishlist.txt"
local LAYOUT_NAME = "survivorcomforts.wishlist"
local MODULE = "SurvivorComforts" -- client/server command module, see the server file

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F06_Name",
    tooltip = "UI_SurvivorComforts_F06_Tooltip",
})
SurvivorComforts.options:addKeyBind(FEATURE_ID .. "_key", getText("UI_SurvivorComforts_F06_Key"), 0)
SurvivorComforts.options:addTickBox(FEATURE_ID .. "_sidebar", getText("UI_SurvivorComforts_F06_Sidebar"), true, getText("UI_SurvivorComforts_F06_Sidebar_Tooltip"))
SurvivorComforts.options:addTickBox(FEATURE_ID .. "_shared", getText("UI_SurvivorComforts_F06_UseShared"), true, getText("UI_SurvivorComforts_F06_UseShared_Tooltip"))

local function sharedEnabled()
    return SurvivorComforts.getOptionValue(FEATURE_ID .. "_shared") == true
end

---------------------------------------------------------------------------
-- Personal list: item full types, in the order they were added.
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
-- Shared list: a copy of what the server sent last. Changes go to the server,
-- which sends the new list back to everyone.
---------------------------------------------------------------------------
local shared = { set = {}, order = {} } -- set[fullType] = name of who added it

local function sharedContains(fullType)
    return shared.set[fullType] ~= nil
end

local function sendCommand(command, args)
    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, MODULE, command, args)
    end
end

local function sharedAdd(fullTypes)
    for _, fullType in ipairs(fullTypes) do
        sendCommand("wishlistAdd", { fullType = fullType })
    end
end

local function sharedRemove(fullTypes)
    for _, fullType in ipairs(fullTypes) do
        sendCommand("wishlistRemove", { fullType = fullType })
    end
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= "wishlist" then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        -- Lists lose their order on the way, so sort by the order the server keeps.
        local received = {}
        for _, entry in pairs(args.items or {}) do
            if type(entry) == "table" and entry.fullType then
                table.insert(received, entry)
            end
        end
        table.sort(received, function(a, b) return (a.order or 0) < (b.order or 0) end)
        shared = { set = {}, order = {} }
        for _, entry in ipairs(received) do
            shared.set[entry.fullType] = entry.by or "?"
            table.insert(shared.order, entry.fullType)
        end
        refreshWindows()
    end)
end

local function onGameStart()
    sendCommand("wishlistRequest", {})
end

-- The two lists, so the menus and the window can treat them the same way.
local LISTS = {
    personal = {
        contains = contains, add = add, remove = remove,
        getOrder = function() return getList().order end,
        color = { r = 1, g = 0.65, b = 0.2 },
        addText = "UI_SurvivorComforts_F06_AddToPersonal",
        removeText = "UI_SurvivorComforts_F06_RemoveFromPersonal",
        emptyText = "UI_SurvivorComforts_F06_Empty",
    },
    shared = {
        contains = sharedContains, add = sharedAdd, remove = sharedRemove,
        getOrder = function() return shared.order end,
        color = { r = 0.35, g = 0.8, b = 1 },
        addText = "UI_SurvivorComforts_F06_AddToShared",
        removeText = "UI_SurvivorComforts_F06_RemoveFromShared",
        emptyText = "UI_SurvivorComforts_F06_EmptyShared",
    },
}

---------------------------------------------------------------------------
-- Highlight in the inventory / loot windows (details view).
-- Drawn after vanilla, over the rows whose item is on a list. The fill uses
-- the personal colour when the item is on both lists; the mark on the left
-- edge shows each list.
---------------------------------------------------------------------------
local function drawHighlights(pane)
    if not pane.items then return end
    local useShared = sharedEnabled()
    for i, entry in ipairs(pane.items) do
        -- A stack header is a table with .items; a row inside an open stack is the item itself.
        local item = entry.items and entry.items[1] or entry
        if item and item.getFullType then
            local fullType = item:getFullType()
            local mine = contains(fullType)
            local theirs = useShared and sharedContains(fullType)
            if mine or theirs then
                local y = (i - 1) * pane.itemHgt + pane.headerHgt
                local fill = mine and LISTS.personal.color or LISTS.shared.color
                pane:drawRect(1, y, pane:getWidth() - 1, pane.itemHgt, 0.12, fill.r, fill.g, fill.b)
                local x = 1
                if mine then
                    local c = LISTS.personal.color
                    pane:drawRect(x, y, 3, pane.itemHgt, 0.9, c.r, c.g, c.b)
                    x = x + 4
                end
                if theirs then
                    local c = LISTS.shared.color
                    pane:drawRect(x, y, 3, pane.itemHgt, 0.9, c.r, c.g, c.b)
                end
            end
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

-- One list box per list (self.kind is "personal" or "shared"), shown in the
-- window's tabs. self.window is the wishlist window.
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
    local textX = iconSize + 10
    self:drawText(item.text, textX, textY, 1, 1, 1, 1, self.font)
    -- Shared list: who added it, after the name.
    if item.item.by then
        local byX = textX + getTextManager():MeasureStringX(self.font, item.text) + 8
        self:drawText(getText("UI_SurvivorComforts_F06_AddedBy", item.item.by), byX, textY, 0.6, 0.6, 0.6, 1, self.font)
    end
    return y + self.itemheight
end

function SurvivorComforts_WishlistList:onRightMouseUp(x, y)
    local index = self:rowAt(x, y)
    local row = self.items[index]
    if not row then return end
    self.selected = index
    local playerNum = self.window.playerNum
    local list = LISTS[self.kind]
    local fullType = row.item.fullType
    local context = ISContextMenu.get(playerNum, getMouseX(), getMouseY())
    local recipeOption = context:addOption(getText("UI_SurvivorComforts_ShowRecipes"), playerNum, function(num)
        SurvivorComforts.safeCall(FEATURE_ID, SurvivorComforts.showRecipes, num, fullType)
    end)
    if not SurvivorComforts.hasRecipe(fullType) then
        recipeOption.notAvailable = true
    end
    -- Without the shared list there is only one list, so no "personal" in the text.
    local removeText = sharedEnabled() and list.removeText or "UI_SurvivorComforts_F06_RemoveFromList"
    context:addOption(getText(removeText), { fullType }, list.remove)
end

function SurvivorComforts_WishlistList:render()
    ISScrollingListBox.render(self)
    if #self.items == 0 then
        self:drawTextCentre(getText(LISTS[self.kind].emptyText), self.width / 2, 10, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

SurvivorComforts_WishlistWindow = ISCollapsableWindow:derive("SurvivorComforts_WishlistWindow")
SurvivorComforts_WishlistWindow.instances = {}

local TAB_TEXT = {
    personal = "UI_SurvivorComforts_F06_TabPersonal",
    shared = "UI_SurvivorComforts_F06_TabShared",
}

function SurvivorComforts_WishlistWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local buttonHgt = getTextManager():getFontHeight(UIFont.Small) + 6

    -- The vanilla tab panel, with one list per tab.
    self.tabPanel = ISTabPanel:new(0, th, self.width, 100)
    self.tabPanel:initialise()
    self.tabPanel:setEqualTabWidth(false)
    self:addChild(self.tabPanel)

    self.lists = {}
    for _, kind in ipairs({ "personal", "shared" }) do
        local list = SurvivorComforts_WishlistList:new(0, 0, self.width, 100)
        list:initialise()
        list:instantiate()
        list.font = UIFont.Small
        list.fontHgt = getTextManager():getFontHeight(UIFont.Small)
        list.itemheight = math.max(list.fontHgt, 24) + 4
        list.drawBorder = true
        list.kind = kind
        list.window = self
        self.lists[kind] = list
    end
    self.tabPanel:addView(getText(TAB_TEXT.personal), self.lists.personal)
    self.sharedTabShown = false
    self:syncSharedTab()

    local removeText = getText("UI_SurvivorComforts_F06_Remove")
    local buttonWid = getTextManager():MeasureStringX(UIFont.Small, removeText) + 20
    self.removeButton = ISButton:new(10, 0, buttonWid, buttonHgt, removeText, self, SurvivorComforts_WishlistWindow.onRemove)
    self.removeButton:initialise()
    self.removeButton:instantiate()
    self:addChild(self.removeButton)

    self:refresh()
end

-- Shows the shared tab only while the shared list option is on (it may be
-- changed while the window is open).
function SurvivorComforts_WishlistWindow:syncSharedTab()
    local show = sharedEnabled()
    if show == self.sharedTabShown then return end
    self.sharedTabShown = show
    local shared = self.lists.shared
    if show then
        self.tabPanel:addView(getText(TAB_TEXT.shared), shared)
    else
        self.tabPanel:removeView(shared)
        shared:setVisible(false)
        self.lists.personal:setVisible(true)
    end
end

-- Keep the tabs, lists and the button fitting the window whenever it is resized.
function SurvivorComforts_WishlistWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if not self.tabPanel then return end
    self:syncSharedTab()
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local buttonHgt = self.removeButton:getHeight()
    local panel = self.tabPanel
    local panelHgt = math.max(panel.tabHeight, self.height - th - rh - buttonHgt - 10)
    if panel:getWidth() ~= self.width then panel:setWidth(self.width) end
    if panel:getHeight() ~= panelHgt then panel:setHeight(panelHgt) end
    local listHgt = panelHgt - panel.tabHeight
    for _, list in pairs(self.lists) do
        if list:getY() ~= panel.tabHeight then list:setY(panel.tabHeight) end
        if list:getWidth() ~= self.width then list:setWidth(self.width) end
        if list:getHeight() ~= listHgt then list:setHeight(listHgt) end
    end
    self.removeButton:setY(th + panelHgt + 5)
    local box = self:currentListBox()
    self.removeButton:setEnable(box.items[box.selected] ~= nil)
end

function SurvivorComforts_WishlistWindow:currentListBox()
    local active = self.tabPanel and self.tabPanel.activeView
    return active and active.view or self.lists.personal
end

function SurvivorComforts_WishlistWindow:refresh()
    if not self.lists then return end
    for kind, box in pairs(self.lists) do
        local selected = box.selected
        box:clear()
        for _, fullType in ipairs(LISTS[kind].getOrder()) do
            local script = ScriptManager.instance:getItem(fullType)
            -- An item from a mod that is no longer loaded still shows, by its type name.
            local name = script and script:getDisplayName() or fullType
            local texture = script and script:getNormalTexture() or nil
            local by = kind == "shared" and shared.set[fullType] or nil
            box:addItem(name, { fullType = fullType, texture = texture, by = by })
        end
        box.selected = math.min(math.max(selected, 1), math.max(#box.items, 1))
    end
end

function SurvivorComforts_WishlistWindow:onRemove()
    local box = self:currentListBox()
    local row = box.items[box.selected]
    if row then
        LISTS[box.kind].remove({ row.item.fullType })
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

-- Add or remove line for one list.
local function addToggleOption(menu, list, fullType)
    if list.contains(fullType) then
        menu:addOption(getText(list.removeText), { fullType }, list.remove)
    else
        menu:addOption(getText(list.addText), { fullType }, list.add)
    end
end

-- With the shared list: "Wishlist" > personal/shared lines, or for several
-- kinds of item, "Wishlist" > item name > personal/shared lines.
local function addBothListsMenu(context, entries)
    local option = context:addOption(getText("UI_SurvivorComforts_F06_Menu"), nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    if #entries == 1 then
        addToggleOption(subMenu, LISTS.personal, entries[1].fullType)
        addToggleOption(subMenu, LISTS.shared, entries[1].fullType)
        return
    end
    for i, entry in ipairs(entries) do
        if i > MAX_MENU_ITEMS then break end
        local itemOption = subMenu:addOption(entry.name, nil)
        local itemMenu = subMenu:getNew(subMenu)
        subMenu:addSubMenu(itemOption, itemMenu)
        addToggleOption(itemMenu, LISTS.personal, entry.fullType)
        addToggleOption(itemMenu, LISTS.shared, entry.fullType)
    end
end

-- entries = { { fullType = "Base.Hammer", name = "Hammer" }, ... }
-- Without the shared list: one kind of item gets a plain add/remove line;
-- several get a submenu with one add/remove line each.
local function addWishlistMenu(context, entries)
    if #entries == 0 then return end
    if sharedEnabled() then
        addBothListsMenu(context, entries)
        return
    end
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
Events.OnServerCommand.Add(onServerCommand)
Events.OnGameStart.Add(onGameStart)
