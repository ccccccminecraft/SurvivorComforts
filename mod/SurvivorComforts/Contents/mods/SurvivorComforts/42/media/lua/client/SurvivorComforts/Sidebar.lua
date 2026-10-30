-- Buttons added to the left sidebar (ISEquippedItem, the icon column).
--
-- Features register a button with SurvivorComforts.addSidebarButton(); the
-- buttons are stacked below the vanilla ones in registration order, and a
-- hidden button leaves no gap. When the next button would come within one
-- icon of the bottom of the screen, the buttons go on in a new column to the
-- right, from the top of the icons.

require "SurvivorComforts/Core"
require "ISUI/ISEquippedItem"

local UI_BORDER_SPACING = 10
local GAP = UI_BORDER_SPACING + 5 -- same spacing as between the vanilla buttons
local ICON_SIZES = { 48, 64, 80, 96, 128 }

-- def = {
--   id = "F08",                        -- feature id, used for safeCall
--   order = 1,                         -- smaller is higher up
--   icon = "Skills",                   -- media/ui/SurvivorComforts/<icon>_<On|Off>_<size>.png
--   tooltip = "UI_..._Title",
--   isShown = function() end,          -- false hides the button
--   isActive = function(playerNum) end,-- true shows the "On" icon
--   onClick = function(playerNum) end,
-- }
local buttonDefs = {}

function SurvivorComforts.addSidebarButton(def)
    table.insert(buttonDefs, def)
    -- Features load in file name order; def.order keeps the buttons in a fixed order.
    table.sort(buttonDefs, function(a, b) return (a.order or 0) < (b.order or 0) end)
end

-- The sidebar size option picks the button width; use the icon made for that width.
local function getIcon(name, state, buttonWidth)
    local size = ICON_SIZES[1]
    for _, s in ipairs(ICON_SIZES) do
        if s <= buttonWidth then size = s end
    end
    return getTexture("media/ui/SurvivorComforts/" .. name .. "_" .. state .. "_" .. size .. ".png")
end

local function isOurs(sidebar, child)
    return sidebar.survivorComforts and sidebar.survivorComforts.isOurs[child] == true
end

-- Top and bottom of the vanilla buttons. Some (admin, war manager) appear or move while playing.
local function vanillaExtent(sidebar)
    local top, bottom = nil, 0
    for _, child in pairs(sidebar:getChildren()) do
        -- F10 parks the PvP button far above the sidebar; skip anything above it.
        if child.Type == "ISButton" and not isOurs(sidebar, child) and child:isVisible() and child:getY() >= 0 then
            top = math.min(top or child:getY(), child:getY())
            bottom = math.max(bottom, child:getBottom())
        end
    end
    return top or 0, bottom
end

local function vanillaBottom(sidebar)
    local _, bottom = vanillaExtent(sidebar)
    return bottom
end

-- Lowest a button may reach, in sidebar coordinates: one icon above the
-- bottom of this player's part of the screen.
local function bottomLimit(sidebar)
    local playerNum = sidebar.chr:getPlayerNum()
    local screenBottom = getPlayerScreenTop(playerNum) + getPlayerScreenHeight(playerNum)
    return screenBottom - sidebar:getAbsoluteY() - sidebar.invBtn:getHeight()
end

-- Same as ISEquippedItem:shrinkWrap, but leaves out hidden buttons.
local function fitSidebar(sidebar)
    local xMax, yMax = 0, 0
    for _, child in pairs(sidebar:getChildren()) do
        if child.Type == "ISButton" and child:isVisible() then
            xMax = math.max(xMax, child:getRight())
            yMax = math.max(yMax, child:getBottom())
        end
    end
    sidebar:setWidth(xMax)
    sidebar:setHeight(yMax)
end

local function layout(sidebar)
    local top, bottom = vanillaExtent(sidebar)
    local limit = bottomLimit(sidebar)
    local left = sidebar.invBtn:getX()
    local x, y = left, bottom
    for _, entry in ipairs(sidebar.survivorComforts.buttons) do
        local btn = entry.button
        if btn:isVisible() then
            local nextY = y + GAP
            -- Start a new column, unless this column is still empty.
            if nextY + btn:getHeight() > limit and y > top then
                x = x + btn:getWidth() + left
                nextY = top
            end
            btn:setX(x)
            btn:setY(nextY)
            y = btn:getBottom()
        end
    end
    sidebar.survivorComforts.lastLimit = limit
    fitSidebar(sidebar)
end

---------------------------------------------------------------------------
-- Hiding vanilla buttons (F10 PvP, F13 user panel)
---------------------------------------------------------------------------
-- A hidden vanilla button is moved off screen (vanilla draws some outlines
-- and timers at a button's position even while it is hidden), and the vanilla
-- buttons below it move up by its height. Positions are worked out from where
-- vanilla first put the buttons, so several features can hide buttons in any
-- order without leaving gaps.
local OFFSCREEN_Y = -10000

local function applyVanillaHidden(sidebar)
    local vanilla = sidebar.survivorComfortsVanilla
    for btn, y in pairs(vanilla.y) do
        if vanilla.hidden[btn] then
            btn:setY(OFFSCREEN_Y)
            btn:setVisible(false)
        else
            local shift = 0
            for hiddenBtn in pairs(vanilla.hidden) do
                if vanilla.y[hiddenBtn] < y then
                    shift = shift + hiddenBtn:getHeight() + GAP
                end
            end
            btn:setY(y - shift)
        end
    end
end

-- Call every frame from the feature's prerender: vanilla may show the button again.
function SurvivorComforts.setVanillaButtonHidden(sidebar, btn, hidden)
    local vanilla = sidebar.survivorComfortsVanilla
    if not vanilla then
        vanilla = { y = {}, hidden = {} }
        for _, child in pairs(sidebar:getChildren()) do
            if child.Type == "ISButton" and not isOurs(sidebar, child) and child:getY() >= 0 then
                vanilla.y[child] = child:getY()
            end
        end
        sidebar.survivorComfortsVanilla = vanilla
    end
    if not vanilla.y[btn] then return end
    if (vanilla.hidden[btn] == true) == hidden then
        if hidden then btn:setVisible(false) end
        return
    end
    vanilla.hidden[btn] = hidden or nil
    if not hidden then btn:setVisible(true) end
    applyVanillaHidden(sidebar)
end

local function isShown(def)
    local ok, shown = pcall(def.isShown)
    return ok and shown == true
end

local function createButtons(sidebar)
    local state = { buttons = {}, isOurs = {} }
    sidebar.survivorComforts = state
    local w, h = sidebar.invBtn:getWidth(), sidebar.invBtn:getHeight()
    for _, def in ipairs(buttonDefs) do
        local onClick = function()
            SurvivorComforts.safeCall(def.id, def.onClick, sidebar.chr:getPlayerNum())
        end
        local btn = ISButton:new(0, 0, w, h, "", sidebar, onClick)
        btn.survivorComfortsIconOn = getIcon(def.icon, "On", w)
        btn.survivorComfortsIconOff = getIcon(def.icon, "Off", w)
        btn:setImage(btn.survivorComfortsIconOff)
        btn:initialise()
        btn:instantiate()
        btn:setDisplayBackground(false)
        btn:ignoreWidthChange()
        btn:ignoreHeightChange()
        btn:setVisible(isShown(def))
        sidebar:addChild(btn)
        state.isOurs[btn] = true
        table.insert(state.buttons, { def = def, button = btn })

        -- The vanilla tooltip list only needs getX/getY/getWidth/getHeight; report
        -- zero size while hidden so no tooltip shows over the empty space.
        local tooltipArea = {
            getX = function() return btn:getX() end,
            getY = function() return btn:getY() end,
            getWidth = function() return btn:isVisible() and btn:getWidth() or 0 end,
            getHeight = function() return btn:isVisible() and btn:getHeight() or 0 end,
        }
        sidebar:addMouseOverToolTipItem(tooltipArea, getText(def.tooltip))
    end
    state.lastBottom = vanillaBottom(sidebar)
    layout(sidebar)
end

-- The sidebar is rebuilt when the sidebar size option changes, which runs this again.
local original_initialise = ISEquippedItem.initialise
function ISEquippedItem:initialise()
    original_initialise(self)
    -- Vanilla only gives the first local player the sidebar buttons.
    if self.invBtn and #buttonDefs > 0 then
        SurvivorComforts.safeCall("Sidebar", createButtons, self)
    end
end

local original_prerender = ISEquippedItem.prerender
function ISEquippedItem:prerender()
    original_prerender(self)
    local state = self.survivorComforts
    if not state then return end
    -- Follow option changes and vanilla buttons appearing while playing.
    local changed = false
    local playerNum = self.chr:getPlayerNum()
    for _, entry in ipairs(state.buttons) do
        local btn = entry.button
        local show = isShown(entry.def)
        if btn:isVisible() ~= show then
            btn:setVisible(show)
            changed = true
        end
        if show then
            local ok, active = pcall(entry.def.isActive, playerNum)
            btn:setImage(ok and active and btn.survivorComfortsIconOn or btn.survivorComfortsIconOff)
        end
    end
    -- Also lay out again when the screen (or the sidebar's place on it) changes.
    local bottom = vanillaBottom(self)
    if changed or bottom ~= state.lastBottom or bottomLimit(self) ~= state.lastLimit then
        state.lastBottom = bottom
        layout(self)
    end
end
