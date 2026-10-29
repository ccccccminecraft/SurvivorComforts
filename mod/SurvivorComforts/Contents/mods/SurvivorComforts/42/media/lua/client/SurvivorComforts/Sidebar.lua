-- Buttons added to the left sidebar (ISEquippedItem, the icon column).
--
-- Features register a button with SurvivorComforts.addSidebarButton(); the
-- buttons are stacked below the vanilla ones in registration order, and a
-- hidden button leaves no gap.

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

-- Bottom of the vanilla buttons. Some (admin, war manager) appear or move while playing.
local function vanillaBottom(sidebar)
    local y = 0
    for _, child in pairs(sidebar:getChildren()) do
        if child.Type == "ISButton" and not isOurs(sidebar, child) and child:isVisible() then
            y = math.max(y, child:getBottom())
        end
    end
    return y
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
    local y = vanillaBottom(sidebar)
    for _, entry in ipairs(sidebar.survivorComforts.buttons) do
        if entry.button:isVisible() then
            entry.button:setY(y + GAP)
            y = entry.button:getBottom()
        end
    end
    fitSidebar(sidebar)
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
    local bottom = vanillaBottom(self)
    if changed or bottom ~= state.lastBottom then
        state.lastBottom = bottom
        layout(self)
    end
end
