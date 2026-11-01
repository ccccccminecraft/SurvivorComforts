-- F02: a search box for the inventory and container windows. A magnifier
-- button in the list header (left of "Type") opens a box under the title bar;
-- the list then shows only the rows whose name matches (Search.lua, the same
-- rules as F14, with English names under F14's option).
--
-- Based on Inventory Search by itsu07 (MIT License,
-- https://github.com/itsu07/pz-inventory-search), changed to fit this mod:
-- a feature switch in this mod's options, the shared search rules, no debug
-- log option and no client-only loader.
--
-- Vanilla functions are not replaced: the original runs first, and the list
-- it made is then reordered (matching rows first, the others dimmed below) or
-- cut down to the matching rows (the "dim" option off). The search text
-- stays when the window switches to another container. Only the rows shown are searched, not the inside of
-- bags. While there is a search text, "loot all" and "transfer all" move only
-- the matching items.

require "SurvivorComforts/Core"
require "SurvivorComforts/Search"
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPage"

local FEATURE_ID = "F02"
local search = SurvivorComforts.search

-- The game's own magnifier pictures.
local ICON_OFF = getTexture("media/ui/Search_Icon_Off.png")
local ICON_ON = getTexture("media/ui/Search_Icon_On.png")

-- How dark the rows that do not match are drawn over (0 to 1).
local DIM_ALPHA = 0.6

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F02_Name",
    tooltip = "UI_SurvivorComforts_F02_Tooltip",
    addOptions = function(options)
        options:addTickBox(FEATURE_ID .. "_dim", getText("UI_SurvivorComforts_F02_Dim"), true, getText("UI_SurvivorComforts_F02_Dim_Tooltip"))
    end,
})

local function isEnabled()
    return SurvivorComforts.isEnabled(FEATURE_ID)
end

local function dimOthers()
    return SurvivorComforts.getOptionValue(FEATURE_ID .. "_dim") == true
end

-- The words the pane is searching for, or nil when nothing is searched.
local function activeWords(pane)
    local words = pane.survivorComfortsSearchWords
    if not words or not isEnabled() then return nil end
    return words
end

local function itemMatches(item, words, player, english)
    return search.matches(search.itemText(item:getFullType(), item:getName(player), english), words)
end

---------------------------------------------------------------------------
-- The list (ISInventoryPane): the magnifier button and the narrowing
---------------------------------------------------------------------------
-- Moves the name column header right by the button's width while the button
-- is shown (the rows stay where they are).
local function layoutHeader(pane)
    local button = pane.survivorComfortsSearchButton
    if not button or not pane.nameHeader then return end
    local x = pane.column2
    if button:getIsVisible() then x = x + button:getWidth() end
    pane.nameHeader:setX(x)
    pane.nameHeader:setWidth(math.max(pane.nameHeader.minimumWidth, pane.column3 - x))
end

local showSearch, hideSearch -- the search box, below

local function onToggleButton(pane)
    local page = pane.inventoryPage
    local box = page and page.survivorComfortsSearchBox
    if not box then return end
    if box:getIsVisible() then
        hideSearch(page)
    else
        showSearch(page)
    end
end

local function addButton(pane)
    local button = ISButton:new(pane.column2, 0, pane.headerHgt, pane.headerHgt, "", pane, function(target)
        SurvivorComforts.safeCall(FEATURE_ID, onToggleButton, target)
    end)
    button:initialise()
    button.borderColor.a = 0.0
    button.backgroundColor.a = 0.0
    button:setImage(ICON_OFF)
    button:setTooltip(getText("UI_SurvivorComforts_F02_Toggle"))
    button:setVisible(isEnabled())
    pane:addChild(button)
    pane.survivorComfortsSearchButton = button
    pane.survivorComfortsSearchWords = nil
    layoutHeader(pane)
end

local original_paneCreateChildren = ISInventoryPane.createChildren
function ISInventoryPane:createChildren()
    original_paneCreateChildren(self)
    SurvivorComforts.safeCall(FEATURE_ID, addButton, self)
end

for _, name in ipairs({ "onResizeColumn", "onResize", "RestoreLayout" }) do
    local original = ISInventoryPane[name]
    ISInventoryPane[name] = function(self, ...)
        local result = original(self, ...)
        SurvivorComforts.safeCall(FEATURE_ID, layoutHeader, self)
        return result
    end
end

-- Puts the matching rows first and the others after them, marked to be drawn
-- dimmed (or leaves the others out, with the "dim" option off). Each part
-- keeps vanilla's order. Vanilla brings the selection back by row number, so
-- it is brought back again afterwards.
local function narrow(pane, words, selected)
    local player = getSpecificPlayer(pane.player)
    local english = search.useEnglish()
    local dim = dimOthers()
    local matched, others = {}, {}
    local dimmed = {} -- stack rows and the items in them
    for _, row in ipairs(pane.itemslist) do
        local item = row.items[1]
        if item and itemMatches(item, words, player, english) then
            table.insert(matched, row)
        elseif dim then
            table.insert(others, row)
            dimmed[row] = true
            for _, inStack in ipairs(row.items) do
                dimmed[inStack] = true
            end
        end
    end
    for _, row in ipairs(others) do
        table.insert(matched, row)
    end
    pane.itemslist = matched
    pane.survivorComfortsDimmed = dimmed
    table.wipe(pane.selected)
    pane:restoreSelection(selected)
    pane:updateScrollbars()
    if pane:isMouseOver() then
        pane:onMouseMove(0, 0)
    end
end

local original_refreshContainer = ISInventoryPane.refreshContainer
function ISInventoryPane:refreshContainer()
    self.survivorComfortsDimmed = nil
    local words = activeWords(self)
    if not words then
        return original_refreshContainer(self)
    end
    local selected = self:saveSelection({})
    local result = original_refreshContainer(self)
    SurvivorComforts.safeCall(FEATURE_ID, narrow, self, words, selected)
    return result
end

-- Darkens the rows that do not match. The row list (self.items) is rebuilt
-- only in the pass that is not for dragged items (as in F06).
local function drawDimmed(pane)
    local dimmed = pane.survivorComfortsDimmed
    if not dimmed or not pane.items then return end
    for i, entry in ipairs(pane.items) do
        if dimmed[entry] then
            local y = (i - 1) * pane.itemHgt + pane.headerHgt
            pane:drawRect(1, y, pane:getWidth() - 1, pane.itemHgt, DIM_ALPHA, 0, 0, 0)
        end
    end
end

local original_renderdetails = ISInventoryPane.renderdetails
function ISInventoryPane:renderdetails(doDragged)
    local result = original_renderdetails(self, doDragged)
    if doDragged == false and self.survivorComfortsDimmed then
        SurvivorComforts.safeCall(FEATURE_ID, drawDimmed, self)
    end
    return result
end

---------------------------------------------------------------------------
-- "Loot all" and "transfer all": only the matching items while searching
---------------------------------------------------------------------------
-- Vanilla picks the items from the whole container and hands them to
-- transferItemsByWeight; while one of these runs, the items that do not match
-- are left out there.
for _, name in ipairs({ "lootAll", "transferAll" }) do
    local original = ISInventoryPane[name]
    ISInventoryPane[name] = function(self, ...)
        self.survivorComfortsTransferWords = activeWords(self)
        local ok, result = pcall(original, self, ...)
        self.survivorComfortsTransferWords = nil
        if not ok then error(result, 0) end
        return result
    end
end

local function matchingItems(pane, items, words)
    local player = getSpecificPlayer(pane.player)
    local english = search.useEnglish()
    local kept = {}
    for _, item in ipairs(items) do
        if itemMatches(item, words, player, english) then
            table.insert(kept, item)
        end
    end
    return kept
end

local original_transferItemsByWeight = ISInventoryPane.transferItemsByWeight
function ISInventoryPane:transferItemsByWeight(items, container)
    local words = self.survivorComfortsTransferWords
    if words then
        local ok, kept = SurvivorComforts.safeCall(FEATURE_ID, matchingItems, self, items, words)
        if ok then items = kept end
    end
    return original_transferItemsByWeight(self, items, container)
end

---------------------------------------------------------------------------
-- The window (ISInventoryPage): a search box row under the title bar
---------------------------------------------------------------------------
-- Called on typing, deleting, pasting and the clear button (not on setText).
local function onSearchTextChange(page, box)
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local pane = page.inventoryPane
        pane.survivorComfortsSearchWords = search.parse(box:getInternalText())
        pane:refreshContainer()
    end)
end

local function addSearchBox(page)
    local font = UIFont.Small
    local height = getTextManager():getFontHeight(font) + 4
    local box = ISTextEntryBox:new("", 1, page:titleBarHeight() + 1, page.inventoryPane:getWidth() - 2, height)
    box.font = font
    box:initialise()
    box:instantiate()
    box:setClearButton(true)
    box:setPlaceholderText(getText("UI_SurvivorComforts_F02_Placeholder"))
    box.onTextChangeFunction = onSearchTextChange
    box.target = page
    box:setVisible(false)
    page:addChild(box)
    page.survivorComfortsSearchBox = box
end

local original_pageCreateChildren = ISInventoryPage.createChildren
function ISInventoryPage:createChildren()
    original_pageCreateChildren(self)
    SurvivorComforts.safeCall(FEATURE_ID, addSearchBox, self)
end

showSearch = function(page)
    local box = page.survivorComfortsSearchBox
    box:setText("")
    box:setVisible(true)
    box:focus()
    page.inventoryPane.survivorComfortsSearchButton:setImage(ICON_ON)
end

hideSearch = function(page)
    local box = page.survivorComfortsSearchBox
    local pane = page.inventoryPane
    box:unfocus()
    box:setText("")
    box:setVisible(false)
    pane.survivorComfortsSearchButton:setImage(ICON_OFF)
    if pane.survivorComfortsSearchWords then
        pane.survivorComfortsSearchWords = nil
        pane:refreshContainer()
    end
end

-- Follows the option (it may be changed while playing), and keeps the list
-- below the search box: vanilla's update puts the list back every frame.
local function updatePage(page)
    local box = page.survivorComfortsSearchBox
    local pane = page.inventoryPane
    local button = pane and pane.survivorComfortsSearchButton
    if not box or not button then return end

    local enabled = isEnabled()
    if button:getIsVisible() ~= enabled then
        button:setVisible(enabled)
        layoutHeader(pane)
    end
    if not enabled and box:getIsVisible() then
        hideSearch(page)
    end
    if not box:getIsVisible() then return end

    -- The "dim" option may be changed while searching.
    local dim = dimOthers()
    if pane.survivorComfortsDimMode ~= dim then
        pane.survivorComfortsDimMode = dim
        if pane.survivorComfortsSearchWords then pane:refreshContainer() end
    end

    local top = page:titleBarHeight()
    box:setY(top + 1)
    box:setWidth(pane:getWidth() - 2)
    pane:setY(top + box:getHeight() + 2)
    pane:setHeight(page.height - pane.y - page.resizeWidget.height - page.controlsUI.height)
    page.containerButtonPanel:setY(pane.y)
    page.containerButtonPanel:setHeight(pane.height)
end

local original_pageUpdate = ISInventoryPage.update
function ISInventoryPage:update()
    original_pageUpdate(self)
    SurvivorComforts.safeCall(FEATURE_ID, updatePage, self)
end
