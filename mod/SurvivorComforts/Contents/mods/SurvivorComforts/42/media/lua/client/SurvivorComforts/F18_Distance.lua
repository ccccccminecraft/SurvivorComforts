-- F18: right-click the ground and choose "Set as reference point"; from then
-- on, the distance to that point and its direction are shown under the
-- character, like F04's reading time. "Clear reference point" takes it away.
--
-- One tile is counted as one metre, as in the game. The point is kept only
-- while the game runs (nothing is written to the world or to a file), one per
-- local player.

require "SurvivorComforts/Core"
require "ISUI/ISUIElement"

local FEATURE_ID = "F18"

-- The 8 directions, counter-clockwise from east (see directionKey), and
-- their texts (written out in full so check.ps1 finds the keys).
local DIRECTIONS = { "E", "NE", "N", "NW", "W", "SW", "S", "SE" }
local DIRECTION_TEXTS = {
    E = "UI_SurvivorComforts_F18_Dir_E", NE = "UI_SurvivorComforts_F18_Dir_NE",
    N = "UI_SurvivorComforts_F18_Dir_N", NW = "UI_SurvivorComforts_F18_Dir_NW",
    W = "UI_SurvivorComforts_F18_Dir_W", SW = "UI_SurvivorComforts_F18_Dir_SW",
    S = "UI_SurvivorComforts_F18_Dir_S", SE = "UI_SurvivorComforts_F18_Dir_SE",
}
local TEXT_COLOR = { 0.55, 0.85, 1 }

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F18_Name",
    tooltip = "UI_SurvivorComforts_F18_Tooltip",
})

-- playerNum -> { x, y, z } of the point's square.
local points = {}

---------------------------------------------------------------------------
-- Distance and direction
---------------------------------------------------------------------------
-- In the world, north is -y and east is +x. Returns "N", "NE", ... for the
-- direction from (0, 0) to (dx, dy).
local function directionKey(dx, dy)
    local angle = math.deg(math.atan2(-dy, dx)) -- 0 = east, 90 = north
    -- 0 to 360: the game's Lua keeps the sign in %, so -1 % 8 is -1 there, not 7
    if angle < 0 then angle = angle + 360 end
    local index = math.floor((angle + 22.5) / 45) % 8
    return DIRECTIONS[index + 1]
end

-- The text under the character for a player standing at (px, py, pz), with
-- the point at the square (x, y, z). The distance is to the middle of the
-- square, rounded to whole metres; floors are told apart when they differ.
local function labelText(px, py, pz, point)
    local dx = point.x + 0.5 - px
    local dy = point.y + 0.5 - py
    local metres = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
    local floors = point.z - math.floor(pz)
    local text
    if metres == 0 then
        text = getText("UI_SurvivorComforts_F18_Here")
    else
        local direction = getText(DIRECTION_TEXTS[directionKey(dx, dy)])
        text = getText("UI_SurvivorComforts_F18_Label", tostring(metres), direction)
    end
    if floors > 0 then
        text = text .. getText("UI_SurvivorComforts_F18_FloorsUp", tostring(floors))
    elseif floors < 0 then
        text = text .. getText("UI_SurvivorComforts_F18_FloorsDown", tostring(-floors))
    end
    return text
end

---------------------------------------------------------------------------
-- Right-click menu on the ground
---------------------------------------------------------------------------
local function setPoint(playerNum, square)
    points[playerNum] = { x = square:getX(), y = square:getY(), z = square:getZ() }
end

local function clearPoint(playerNum)
    points[playerNum] = nil
end

-- The square under the right-click, on the character's floor (the same way
-- the game's foraging menu finds it).
local function clickedSquare(playerNum, context)
    local player = getSpecificPlayer(playerNum)
    if not player or not context then return nil end
    local z = math.floor(player:getZ())
    local x = math.floor(screenToIsoX(playerNum, context.x, context.y, z))
    local y = math.floor(screenToIsoY(playerNum, context.x, context.y, z))
    return getCell():getGridSquare(x, y, z)
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test or not SurvivorComforts.isEnabled(FEATURE_ID) then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local square = clickedSquare(playerNum, context)
        if square then
            context:addOption(getText("UI_SurvivorComforts_F18_Set"), playerNum, setPoint, square)
        end
        if points[playerNum] then
            context:addOption(getText("UI_SurvivorComforts_F18_Clear"), playerNum, clearPoint)
        end
    end)
end

---------------------------------------------------------------------------
-- Label drawn under the character (the same way as F04). It goes one line
-- lower while F04's reading time is shown, so the two do not overlap.
---------------------------------------------------------------------------
SurvivorComforts_DistanceLabel = ISUIElement:derive("SurvivorComforts_DistanceLabel")
local labels = {}

function SurvivorComforts_DistanceLabel:render()
    local point = points[self.playerNum]
    local player = getSpecificPlayer(self.playerNum)
    if not point or not player or not SurvivorComforts.isEnabled(FEATURE_ID) then return end
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local text = labelText(px, py, pz, point)
    if text ~= self.text then
        self.text = text
        self.textWidth = getTextManager():MeasureStringX(UIFont.Small, text)
    end
    local sx = isoToScreenX(self.playerNum, px, py, pz)
    local sy = isoToScreenY(self.playerNum, px, py, pz)
    local x = sx - self:getAbsoluteX() - self.textWidth / 2
    local y = sy - self:getAbsoluteY() + 8
    if SurvivorComforts.isReadingTimeShown and SurvivorComforts.isReadingTimeShown(self.playerNum) then
        y = y + getTextManager():getFontHeight(UIFont.Small) + 2
    end
    local c = TEXT_COLOR
    self:drawText(text, x + 1, y + 1, 0, 0, 0, 0.8, UIFont.Small)
    self:drawText(text, x, y, c[1], c[2], c[3], 1, UIFont.Small)
end

function SurvivorComforts_DistanceLabel:new(playerNum)
    local o = ISUIElement.new(self, 0, 0, 1, 1)
    o.playerNum = playerNum
    return o
end

local function onCreatePlayer(playerNum, player)
    -- A new character (after dying) starts without a point.
    points[playerNum] = nil
    if labels[playerNum] then return end
    local label = SurvivorComforts_DistanceLabel:new(playerNum)
    label:initialise()
    label:addToUIManager()
    label:setAlwaysOnTop(false)
    labels[playerNum] = label
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- For the tests (Core.lua).
SurvivorComforts.internals.F18 = {
    directionKey = directionKey,
    labelText = labelText,
    points = points,
    setPoint = setPoint,
    clearPoint = clearPoint,
    onFillWorldObjectContextMenu = onFillWorldObjectContextMenu,
}
