-- F06: a wishlist of item types, and a shared list of the items players share
-- from theirs.
--
-- Right-click an item to add it to (or remove it from) the wishlist, or to
-- share or unshare it; in the crafting and building windows, right-click an
-- ingredient, a result or a recipe in the list. Items on a list are
-- highlighted in the inventory and loot windows, so they stand out when
-- looting. The lists can be opened in a small window.
--
-- The personal list is saved on this PC only
-- (Zomboid/Lua/SurvivorComforts_Wishlist.txt) and is the same for every save
-- and server. The shared list is kept by the server
-- (server/SurvivorComforts/F06_SharedWishlist.lua) and sent to every player;
-- it is only for looking, and each player can unshare only their own share.

require "SurvivorComforts/Core"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISTabPanel"
require "ISUI/ISInventoryPane"
require "SurvivorComforts/Recipes"
require "SurvivorComforts/Sidebar"
require "SurvivorComforts/CraftMenu"

local FEATURE_ID = "F06"
local FILE_NAME = "SurvivorComforts_Wishlist.txt"
local LAYOUT_NAME = "survivorcomforts.wishlist"
local MODULE = "SurvivorComforts" -- client/server command module, see the server file

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F06_Name",
    tooltip = "UI_SurvivorComforts_F06_Tooltip",
    addOptions = function(options)
        options:addTickBox(FEATURE_ID .. "_sidebar", getText("UI_SurvivorComforts_F06_Sidebar"), true, getText("UI_SurvivorComforts_F06_Sidebar_Tooltip"))
        options:addKeyBind(FEATURE_ID .. "_key", getText("UI_SurvivorComforts_F06_Key"), 0)
        options:addTickBox(FEATURE_ID .. "_shared", getText("UI_SurvivorComforts_F06_UseShared"), true, getText("UI_SurvivorComforts_F06_UseShared_Tooltip"))
    end,
})

local function sharedEnabled()
    return SurvivorComforts.getOptionValue(FEATURE_ID .. "_shared") == true
end

---------------------------------------------------------------------------
-- Personal list file: item full types, in the order they were added.
-- With the shared list on, "my list" is this file plus the items this player
-- shares on the server (see myOrder / contains below).
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

local function inFile(fullType)
    return getList().set[fullType] == true
end

local function addToFile(fullTypes)
    local list = getList()
    local changed = false
    for _, fullType in ipairs(fullTypes) do
        if not list.set[fullType] then
            list.set[fullType] = true
            table.insert(list.order, fullType)
            changed = true
        end
    end
    if changed then save() end
end

local function removeFromFile(fullTypes)
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
end

local refreshWindows -- defined with the window below

---------------------------------------------------------------------------
-- Shared list: a copy of what the server sent last. Changes go to the server,
-- which sends the new list back to everyone.
---------------------------------------------------------------------------
-- order = { fullType, ... }, sharers[fullType] = { username, ... } (first sharer first)
local shared = { order = {}, sharers = {} }

local PERSONAL_COLOR = { r = 1, g = 0.65, b = 0.2 }
local SHARED_COLOR = { r = 0.35, g = 0.8, b = 1 }

-- The same name the server records (see playerName in the server file).
local function myName()
    local player = getSpecificPlayer(0)
    if not player then return nil end
    local name = player:getUsername()
    if not name or name == "" then
        name = player:getDisplayName()
    end
    return name
end

-- Admins (anyone who can kick players) may take shared items off for everyone;
-- the server checks again. In single player the only player owns the game.
local function isAdmin()
    if not isClient() then return true end
    local ok, result = pcall(function()
        return getSpecificPlayer(0):getRole():hasCapability(Capability.KickUser)
    end)
    return ok and result == true
end

local function sharedContains(fullType)
    return shared.sharers[fullType] ~= nil
end

local function sharedByMe(fullType)
    local name = myName()
    for _, sharer in ipairs(shared.sharers[fullType] or {}) do
        if sharer == name then return true end
    end
    return false
end

-- "My list": the file, plus the items this player shares here. Those are
-- shown even when the file has lost them (the file is the same for every
-- server), so they can still be unshared or removed.
local function contains(fullType)
    return inFile(fullType) or (sharedEnabled() and sharedByMe(fullType))
end

local function myOrder()
    local order = {}
    for _, fullType in ipairs(getList().order) do
        table.insert(order, fullType)
    end
    if sharedEnabled() then
        for _, fullType in ipairs(shared.order) do
            if not inFile(fullType) and sharedByMe(fullType) then
                table.insert(order, fullType)
            end
        end
    end
    return order
end

local function sendCommand(command, args)
    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, MODULE, command, args)
    end
end

-- The actions on "my list". Sharing and unsharing change the shared list on
-- the server, which sends it back; the window is refreshed then.
local function add(fullTypes)
    addToFile(fullTypes)
    refreshWindows()
end

-- Removing also takes off this player's share of the item.
local function remove(fullTypes)
    removeFromFile(fullTypes)
    for _, fullType in ipairs(fullTypes) do
        if sharedByMe(fullType) then
            sendCommand("wishlistUnshare", { fullType = fullType })
        end
    end
    refreshWindows()
end

-- A shared item is kept in the file too, so it stays on my list when unshared.
local function share(fullTypes)
    addToFile(fullTypes)
    for _, fullType in ipairs(fullTypes) do
        sendCommand("wishlistShare", { fullType = fullType })
    end
    refreshWindows()
end

local function unshare(fullTypes)
    addToFile(fullTypes)
    for _, fullType in ipairs(fullTypes) do
        sendCommand("wishlistUnshare", { fullType = fullType })
    end
    refreshWindows()
end

local function adminRemove(fullTypes)
    for _, fullType in ipairs(fullTypes) do
        sendCommand("wishlistAdminRemove", { fullType = fullType })
    end
end

-- "（A）", "（A、B）", or "（3名以上）" after an item on the shared tab.
local function sharersText(fullType)
    local names = shared.sharers[fullType] or {}
    if #names >= 3 then
        return getText("UI_SurvivorComforts_F06_SharedByMany")
    elseif #names == 2 then
        return getText("UI_SurvivorComforts_F06_SharedByTwo", names[1], names[2])
    end
    return getText("UI_SurvivorComforts_F06_AddedBy", names[1] or "?")
end

local function byOrder(a, b)
    return (tonumber(a.order) or 0) < (tonumber(b.order) or 0)
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= "wishlist" then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        -- Lists lose their order on the way, so sort by the order the server keeps.
        local received = {}
        for _, entry in pairs(args.items or {}) do
            if type(entry) == "table" and type(entry.fullType) == "string" then
                table.insert(received, entry)
            end
        end
        table.sort(received, byOrder)
        shared = { order = {}, sharers = {} }
        for _, entry in ipairs(received) do
            local sharers = {}
            for _, sharer in pairs(entry.sharers or {}) do
                if type(sharer) == "table" and type(sharer.name) == "string" then
                    table.insert(sharers, sharer)
                end
            end
            if #sharers > 0 then
                table.sort(sharers, byOrder)
                local names = {}
                for _, sharer in ipairs(sharers) do
                    table.insert(names, sharer.name)
                end
                shared.sharers[entry.fullType] = names
                table.insert(shared.order, entry.fullType)
            end
        end
        refreshWindows()
    end)
end

local function onGameStart()
    sendCommand("wishlistRequest", {})
end

-- The lines for one item on my list: share or unshare (with the shared list
-- on), then remove. An item not on my list gets the add line.
local function addItemOptions(menu, fullType)
    local fullTypes = { fullType }
    if not contains(fullType) then
        menu:addOption(getText("UI_SurvivorComforts_F06_AddToList"), fullTypes, add)
        return
    end
    if sharedEnabled() then
        if sharedByMe(fullType) then
            menu:addOption(getText("UI_SurvivorComforts_F06_Unshare"), fullTypes, unshare)
        else
            menu:addOption(getText("UI_SurvivorComforts_F06_Share"), fullTypes, share)
        end
    end
    menu:addOption(getText("UI_SurvivorComforts_F06_RemoveFromList"), fullTypes, remove)
end

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
                local fill = mine and PERSONAL_COLOR or SHARED_COLOR
                pane:drawRect(1, y, pane:getWidth() - 1, pane.itemHgt, 0.12, fill.r, fill.g, fill.b)
                local x = 1
                if mine then
                    local c = PERSONAL_COLOR
                    pane:drawRect(x, y, 3, pane.itemHgt, 0.9, c.r, c.g, c.b)
                    x = x + 4
                end
                if theirs then
                    local c = SHARED_COLOR
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
    -- My tab: a light blue mark on the left of the items I share.
    if item.item.sharedByMe then
        self:drawRect(0, y, 3, self.itemheight, 0.9, SHARED_COLOR.r, SHARED_COLOR.g, SHARED_COLOR.b)
    end
    local iconSize = self.itemheight - 4
    local texture = item.item.texture
    if texture then
        self:drawTextureScaledAspect(texture, 4, y + 2, iconSize, iconSize, 1, 1, 1, 1)
    end
    local textY = y + (self.itemheight - self.fontHgt) / 2
    local textX = iconSize + 10
    self:drawText(item.text, textX, textY, 1, 1, 1, 1, self.font)
    -- Shared tab: who shares it, after the name.
    if item.item.by then
        local byX = textX + getTextManager():MeasureStringX(self.font, item.text) + 8
        self:drawText(item.item.by, byX, textY, 0.6, 0.6, 0.6, 1, self.font)
    end
    return y + self.itemheight
end

function SurvivorComforts_WishlistList:onRightMouseUp(x, y)
    local index = self:rowAt(x, y)
    local row = self.items[index]
    if not row then return end
    self.selected = index
    local playerNum = self.window.playerNum
    local fullType = row.item.fullType
    local context = ISContextMenu.get(playerNum, getMouseX(), getMouseY())
    local recipeOption = context:addOption(getText("UI_SurvivorComforts_ShowRecipes"), playerNum, function(num)
        SurvivorComforts.safeCall(FEATURE_ID, SurvivorComforts.showRecipes, num, fullType)
    end)
    if not SurvivorComforts.hasRecipe(fullType) then
        recipeOption.notAvailable = true
    end
    if self.kind == "personal" then
        addItemOptions(context, fullType)
        return
    end
    -- The shared tab is for looking: add to my list (without sharing), and
    -- for admins, take it off for everyone.
    if not contains(fullType) then
        context:addOption(getText("UI_SurvivorComforts_F06_AddToMine"), { fullType }, add)
    end
    if isAdmin() then
        context:addOption(getText("UI_SurvivorComforts_F06_AdminRemove"), { fullType }, adminRemove)
    end
end

local EMPTY_TEXT = {
    personal = "UI_SurvivorComforts_F06_Empty",
    shared = "UI_SurvivorComforts_F06_EmptyShared",
}

function SurvivorComforts_WishlistList:render()
    ISScrollingListBox.render(self)
    if #self.items == 0 then
        self:drawTextCentre(getText(EMPTY_TEXT[self.kind]), self.width / 2, 10, 0.7, 0.7, 0.7, 1, UIFont.Small)
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
    -- Only my tab can be edited; the shared tab is for looking.
    local box = self:currentListBox()
    self.removeButton:setEnable(box.kind == "personal" and box.items[box.selected] ~= nil)
end

function SurvivorComforts_WishlistWindow:currentListBox()
    local active = self.tabPanel and self.tabPanel.activeView
    return active and active.view or self.lists.personal
end

function SurvivorComforts_WishlistWindow:refresh()
    if not self.lists then return end
    local orders = { personal = myOrder(), shared = shared.order }
    for kind, box in pairs(self.lists) do
        local selected = box.selected
        box:clear()
        for _, fullType in ipairs(orders[kind]) do
            local script = ScriptManager.instance:getItem(fullType)
            -- An item from a mod that is no longer loaded still shows, by its type name.
            local name = script and script:getDisplayName() or fullType
            local texture = script and script:getNormalTexture() or nil
            local row = { fullType = fullType, texture = texture }
            if kind == "shared" then
                row.by = sharersText(fullType)
            elseif sharedEnabled() then
                row.sharedByMe = sharedByMe(fullType)
            end
            box:addItem(name, row)
        end
        box.selected = math.min(math.max(selected, 1), math.max(#box.items, 1))
    end
end

function SurvivorComforts_WishlistWindow:onRemove()
    local box = self:currentListBox()
    local row = box.items[box.selected]
    if row and box.kind == "personal" then
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

-- With the shared list: an item not on my list gets a plain add line; one on
-- it gets "Wishlist" > share/unshare and remove. Several kinds of item get
-- "Wishlist" > item name > those lines.
local function addSharingMenu(context, entries)
    if #entries == 1 and not contains(entries[1].fullType) then
        addItemOptions(context, entries[1].fullType)
        return
    end
    local option = context:addOption(getText("UI_SurvivorComforts_F06_Menu"), nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    if #entries == 1 then
        addItemOptions(subMenu, entries[1].fullType)
        return
    end
    for i, entry in ipairs(entries) do
        if i > MAX_MENU_ITEMS then break end
        local itemOption = subMenu:addOption(entry.name, nil)
        local itemMenu = subMenu:getNew(subMenu)
        subMenu:addSubMenu(itemOption, itemMenu)
        addItemOptions(itemMenu, entry.fullType)
    end
end

-- entries = { { fullType = "Base.Hammer", name = "Hammer" }, ... }
-- Without the shared list: one kind of item gets a plain add/remove line;
-- several get a submenu with one add/remove line each.
local function addWishlistMenu(context, entries)
    if #entries == 0 then return end
    if sharedEnabled() then
        addSharingMenu(context, entries)
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
-- Crafting and building windows: the wishlist lines in the shared
-- right-click menu (see CraftMenu.lua).
---------------------------------------------------------------------------
SurvivorComforts.addCraftMenuProvider({
    id = FEATURE_ID,
    order = 2,
    isEnabled = function() return SurvivorComforts.isEnabled(FEATURE_ID) end,
    fill = function(context, playerNum, entries, kind)
        addWishlistMenu(context, entries)
    end,
})

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
