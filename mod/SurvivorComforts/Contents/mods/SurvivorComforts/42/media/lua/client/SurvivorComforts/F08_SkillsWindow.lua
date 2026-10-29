-- F08: show the skill list in its own resizable window.
--
-- The vanilla skills tab (ISCharacterInfo) resizes its parent window to fit
-- every skill (up to 800px) on every frame, which pushes the window around.
-- Here the same panel is hosted in a window whose size the player controls;
-- the panel scrolls instead of growing.
--
-- The window can also be opened from a button on the left sidebar, and the
-- skills tab can be removed from the vanilla character info window (the
-- vanilla skills key then opens this window instead).

require "SurvivorComforts/Core"
require "XpSystem/ISUI/ISCharacterInfo"
require "XpSystem/ISUI/ISCharacterInfoWindow"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISEquippedItem"

local FEATURE_ID = "F08"
local LAYOUT_NAME = "survivorcomforts.skills"
local MIN_HEIGHT = 150

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F08_Name",
    tooltip = "UI_SurvivorComforts_F08_Tooltip",
})
SurvivorComforts.options:addKeyBind(FEATURE_ID .. "_key", getText("UI_SurvivorComforts_F08_Key"), Keyboard.KEY_K)
SurvivorComforts.options:addTickBox(FEATURE_ID .. "_sidebar", getText("UI_SurvivorComforts_F08_Sidebar"), true, getText("UI_SurvivorComforts_F08_Sidebar_Tooltip"))
SurvivorComforts.options:addTickBox(FEATURE_ID .. "_hideTab", getText("UI_SurvivorComforts_F08_HideTab"), false, getText("UI_SurvivorComforts_F08_HideTab_Tooltip"))

local function showSidebarButton()
    return SurvivorComforts.isEnabled(FEATURE_ID) and SurvivorComforts.getOptionValue(FEATURE_ID .. "_sidebar") == true
end

local function hideVanillaTab()
    return SurvivorComforts.isEnabled(FEATURE_ID) and SurvivorComforts.getOptionValue(FEATURE_ID .. "_hideTab") == true
end

---------------------------------------------------------------------------
-- Skills panel: vanilla ISCharacterInfo that never resizes its parent.
---------------------------------------------------------------------------
SurvivorComforts_SkillsPanel = ISCharacterInfo:derive("SurvivorComforts_SkillsPanel")

-- Width the vanilla rows need (same formula as ISCharacterInfo:render).
function SurvivorComforts_SkillsPanel:getContentWidth()
    local UI_BORDER_SPACING = 10
    local SCROLL_BAR_WIDTH = 13
    local fontHgtSmall = getTextManager():getFontHeight(UIFont.Small)
    local buttonHgt = fontHgtSmall + 6
    local left = UI_BORDER_SPACING * 2 + buttonHgt + 1
    local skillPointSize = math.floor(buttonHgt / 2)
    local skillPointSpacing = getCore():getOptionFontSizeReal()
    return left + UI_BORDER_SPACING * 4 + self.txtLen + skillPointSize * 10 + skillPointSpacing * 9 + SCROLL_BAR_WIDTH + 1
end

-- Vanilla grows the window to the widest row on every frame. Here the content
-- width only sets the window's minimum, so the player can still resize it.
-- (The argument is max(current width, content width), so it is not used.)
function SurvivorComforts_SkillsPanel:setWidthAndParentWidth(_width)
    local window = self.parent
    local needed = self:getContentWidth()
    if not window then
        ISPanel.setWidth(self, needed)
        return
    end
    window.minimumWidth = needed
    if window:getWidth() < needed then
        window:setWidth(needed)
    end
end

-- Vanilla grows the window to the content height; the window keeps its own height here.
function SurvivorComforts_SkillsPanel:setHeightAndParentHeight(height)
end

function SurvivorComforts_SkillsPanel:new(x, y, width, height, playerNum)
    local previous = ISCharacterInfo.instance
    local o = ISCharacterInfo.new(self, x, y, width, height, playerNum)
    -- ISCharacterInfo.new stores itself as the global instance (used by the tutorial); keep vanilla's.
    ISCharacterInfo.instance = previous
    return o
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
SurvivorComforts_SkillsWindow = ISCollapsableWindow:derive("SurvivorComforts_SkillsWindow")
SurvivorComforts_SkillsWindow.instances = {}

function SurvivorComforts_SkillsWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    self.skillsPanel = SurvivorComforts_SkillsPanel:new(0, th, self.width, self.height - th - rh, self.playerNum)
    self.skillsPanel:initialise()
    self:addChild(self.skillsPanel)
end

-- Keep the panel filling the window whenever the player resizes it.
function SurvivorComforts_SkillsWindow:prerender()
    ISCollapsableWindow.prerender(self)
    local panel = self.skillsPanel
    if panel then
        local th = self:titleBarHeight()
        local rh = self:resizeWidgetHeight()
        local w, h = self.width, math.max(0, self.height - th - rh)
        if panel:getWidth() ~= w then ISPanel.setWidth(panel, w) end
        if panel:getHeight() ~= h then ISPanel.setHeight(panel, h) end
    end
end

function SurvivorComforts_SkillsWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

function SurvivorComforts_SkillsWindow:toggle()
    if self:getIsVisible() then
        self:close()
    else
        self:addToUIManager()
        self:setVisible(true)
        self:bringToTop()
    end
end

function SurvivorComforts_SkillsWindow:new(x, y, width, height, playerNum)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.playerNum = playerNum
    o.title = getText("UI_SurvivorComforts_F08_Title")
    o.minimumHeight = MIN_HEIGHT
    o.visibleOnStartup = false
    return o
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function destroyWindow(playerNum)
    local window = SurvivorComforts_SkillsWindow.instances[playerNum]
    if window then
        window:setVisible(false)
        window:removeFromUIManager()
        SurvivorComforts_SkillsWindow.instances[playerNum] = nil
    end
end

-- A new IsoPlayer is created on respawn, so the window is rebuilt for it.
local function createWindow(playerNum)
    destroyWindow(playerNum)
    local x = getPlayerScreenLeft(playerNum) + 100
    local y = getPlayerScreenTop(playerNum) + 100
    local window = SurvivorComforts_SkillsWindow:new(x, y, 300, 400, playerNum)
    window:initialise()
    window:setVisible(false)
    SurvivorComforts_SkillsWindow.instances[playerNum] = window
    -- Only the first local player has a saved layout, like vanilla windows.
    if playerNum == 0 then
        ISLayoutManager.RegisterWindow(LAYOUT_NAME, ISCollapsableWindow, window)
    end
    return window
end

local function isWindowOpen(playerNum)
    local window = SurvivorComforts_SkillsWindow.instances[playerNum]
    return window ~= nil and window:getIsVisible()
end

-- Opens or closes the window; used by the key, the sidebar button and the vanilla skills key.
local function toggleWindow(playerNum)
    if not SurvivorComforts.isEnabled(FEATURE_ID) then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local window = SurvivorComforts_SkillsWindow.instances[playerNum] or createWindow(playerNum)
        window:toggle()
    end)
end

local function onCreatePlayer(playerNum, player)
    if not SurvivorComforts.isEnabled(FEATURE_ID) then return end
    SurvivorComforts.safeCall(FEATURE_ID, createWindow, playerNum)
end

local function onKeyPressed(key)
    if key == nil or key == 0 then return end
    if key ~= SurvivorComforts.getOptionValue(FEATURE_ID .. "_key") then return end
    local player = getPlayer()
    if not player then return end
    toggleWindow(player:getPlayerNum())
end

local function onPlayerDeath(player)
    if player and player:isLocalPlayer() then
        destroyWindow(player:getPlayerNum())
    end
end

---------------------------------------------------------------------------
-- Sidebar button (ISEquippedItem, the icon column on the left)
---------------------------------------------------------------------------
local ICON_SIZES = { 48, 64, 80, 96, 128 }

-- The sidebar size option picks the button width; use the icon made for that width.
local function getIcon(state, buttonWidth)
    local size = ICON_SIZES[1]
    for _, s in ipairs(ICON_SIZES) do
        if s <= buttonWidth then size = s end
    end
    return getTexture("media/ui/SurvivorComforts/Skills_" .. state .. "_" .. size .. ".png")
end

-- Same as ISEquippedItem:shrinkWrap, but leaves out the skills button while it is hidden.
local function fitSidebar(sidebar)
    local xMax, yMax = 0, 0
    for _, child in pairs(sidebar:getChildren()) do
        if child.Type == "ISButton" and (child ~= sidebar.survivorComfortsSkillsBtn or child:isVisible()) then
            xMax = math.max(xMax, child:getRight())
            yMax = math.max(yMax, child:getBottom())
        end
    end
    sidebar:setWidth(xMax)
    sidebar:setHeight(yMax)
end

local function onSidebarButton(sidebar, button)
    toggleWindow(sidebar.chr:getPlayerNum())
end

-- Adds the button below the last vanilla button. The sidebar is rebuilt when
-- the sidebar size option changes, which runs this again.
local function addSidebarButton(sidebar)
    local UI_BORDER_SPACING = 10
    local w, h = sidebar.invBtn:getWidth(), sidebar.invBtn:getHeight()
    local y = 0
    for _, child in pairs(sidebar:getChildren()) do
        if child.Type == "ISButton" then
            y = math.max(y, child:getBottom())
        end
    end
    y = y + UI_BORDER_SPACING + 5

    local btn = ISButton:new(0, y, w, h, "", sidebar, onSidebarButton)
    btn.skillsIconOn = getIcon("On", w)
    btn.skillsIconOff = getIcon("Off", w)
    btn:setImage(btn.skillsIconOff)
    btn:initialise()
    btn:instantiate()
    btn:setDisplayBackground(false)
    btn:ignoreWidthChange()
    btn:ignoreHeightChange()
    sidebar:addChild(btn)
    sidebar.survivorComfortsSkillsBtn = btn

    -- The vanilla tooltip list only needs getX/getY/getWidth/getHeight; report
    -- zero size while hidden so no tooltip shows over the empty space.
    local tooltipArea = {
        getX = function() return btn:getX() end,
        getY = function() return btn:getY() end,
        getWidth = function() return btn:isVisible() and btn:getWidth() or 0 end,
        getHeight = function() return btn:isVisible() and btn:getHeight() or 0 end,
    }
    sidebar:addMouseOverToolTipItem(tooltipArea, getText("UI_SurvivorComforts_F08_Title"))

    btn:setVisible(showSidebarButton())
    fitSidebar(sidebar)
end

local original_sidebarInitialise = ISEquippedItem.initialise
function ISEquippedItem:initialise()
    original_sidebarInitialise(self)
    -- Vanilla only gives the first local player the sidebar buttons.
    if self.invBtn then
        SurvivorComforts.safeCall(FEATURE_ID, addSidebarButton, self)
    end
end

local original_sidebarPrerender = ISEquippedItem.prerender
function ISEquippedItem:prerender()
    original_sidebarPrerender(self)
    local btn = self.survivorComfortsSkillsBtn
    if not btn then return end
    -- Follow option changes made while playing.
    local show = showSidebarButton()
    if btn:isVisible() ~= show then
        btn:setVisible(show)
        fitSidebar(self)
    end
    if show then
        btn:setImage(isWindowOpen(self.chr:getPlayerNum()) and btn.skillsIconOn or btn.skillsIconOff)
    end
end

---------------------------------------------------------------------------
-- Hiding the skills tab of the vanilla character info window
---------------------------------------------------------------------------
-- The tab entry is kept so it can be put back at the same place with the same
-- id (ISTabPanel:addView would number it after the last tab and clash).
-- ISTabPanel:removeView leaves view.parent pointing at the tab panel, so the
-- vanilla SaveLayout still saves the tab as docked and never restores it as a
-- separate window.
local function applySkillsTab(infoWindow)
    local panel, view = infoWindow.panel, infoWindow.characterView
    if not panel or not view then return end
    local hide = hideVanillaTab()

    if hide and not infoWindow.survivorComfortsHiddenTab then
        for index, entry in ipairs(panel.viewList) do
            if entry.view == view then
                local wasActive = panel.activeView == entry
                panel:removeView(view)
                view:setVisible(false)
                infoWindow.survivorComfortsHiddenTab = { entry = entry, index = index }
                if wasActive and panel.activeView then
                    panel:activateView(panel.activeView.name)
                end
                return
            end
        end
    elseif not hide and infoWindow.survivorComfortsHiddenTab then
        local hidden = infoWindow.survivorComfortsHiddenTab
        infoWindow.survivorComfortsHiddenTab = nil
        -- A restored layout may have moved the view into a separate window meanwhile.
        if view.parent ~= panel then return end
        table.insert(panel.viewList, math.min(hidden.index, #panel.viewList + 1), hidden.entry)
        view:setY(panel.tabHeight)
        panel:addChild(view)
        view.parent = panel
        view:setVisible(false)
    end
end

local original_infoCreateChildren = ISCharacterInfoWindow.createChildren
function ISCharacterInfoWindow:createChildren()
    original_infoCreateChildren(self)
    SurvivorComforts.safeCall(FEATURE_ID, applySkillsTab, self)
end

-- Follow option changes made while playing (only matters while the window is shown).
local original_infoPrerender = ISCharacterInfoWindow.prerender
function ISCharacterInfoWindow:prerender()
    SurvivorComforts.safeCall(FEATURE_ID, applySkillsTab, self)
    original_infoPrerender(self)
end

-- The vanilla skills key (and gamepad) toggles the skills tab; open this window instead while the tab is hidden.
local original_infoToggleView = ISCharacterInfoWindow.toggleView
function ISCharacterInfoWindow:toggleView(viewName)
    if viewName == xpSystemText.skills and hideVanillaTab() then
        SurvivorComforts.safeCall(FEATURE_ID, applySkillsTab, self)
        toggleWindow(self.playerNum)
        return
    end
    return original_infoToggleView(self, viewName)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnKeyPressed.Add(onKeyPressed)
Events.OnPlayerDeath.Add(onPlayerDeath)
