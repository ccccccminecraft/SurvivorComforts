-- Tests for F18 (distance to a point): the direction, the text under the
-- character, and the right-click menu.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/F18_Distance"

local T = SurvivorComfortsTests
local H = T.helpers

---------------------------------------------------------------------------
-- A: no world needed
---------------------------------------------------------------------------
T.add("F18: the 8 directions (north is -y, east is +x)", function(t)
    local key = SurvivorComforts.internals.F18.directionKey
    t:equal(key(0, -10), "N")
    t:equal(key(10, -10), "NE")
    t:equal(key(10, 0), "E")
    t:equal(key(10, 10), "SE")
    t:equal(key(0, 10), "S")
    t:equal(key(-10, 10), "SW")
    t:equal(key(-10, 0), "W")
    t:equal(key(-10, -10), "NW")
    t:equal(key(10, -3), "E", "a little north of east is still east")
end)

T.add("F18: the text has the distance in metres, the direction and the floors", function(t)
    local labelText = SurvivorComforts.internals.F18.labelText
    local point = { x = 100, y = 100, z = 0 }
    -- Standing 30 tiles west of the middle of the point's square, on its floor.
    t:equal(labelText(70.5, 100.5, 0, point),
        getText("UI_SurvivorComforts_F18_Label", "30", getText("UI_SurvivorComforts_F18_Dir_E")))
    t:equal(labelText(103.5, 104.5, 0, point),
        getText("UI_SurvivorComforts_F18_Label", "5", getText("UI_SurvivorComforts_F18_Dir_NW")), "3-4-5")
    t:equal(labelText(100.6, 100.4, 0, point), getText("UI_SurvivorComforts_F18_Here"), "on the square")
    t:equal(labelText(100.5, 100.5, 2, point),
        getText("UI_SurvivorComforts_F18_Here") .. getText("UI_SurvivorComforts_F18_FloorsDown", "2"))
    t:equal(labelText(70.5, 100.5, 0, { x = 100, y = 100, z = 1 }),
        getText("UI_SurvivorComforts_F18_Label", "30", getText("UI_SurvivorComforts_F18_Dir_E"))
            .. getText("UI_SurvivorComforts_F18_FloorsUp", "1"))
end)

---------------------------------------------------------------------------
-- B: a game in single player
---------------------------------------------------------------------------
-- A context menu that only records the options added.
local function fakeContext(x, y)
    local context = { x = x, y = y, options = {} }
    function context:addOption(name, target, fn, ...)
        table.insert(self.options, { name = name, target = target, fn = fn, args = { ... } })
    end
    return context
end

T.add("F18: the right-click menu sets and clears the point", function(t)
    local player = H.player(t)
    local F18 = SurvivorComforts.internals.F18
    local playerNum = player:getPlayerNum()
    local old = F18.points[playerNum]
    t:cleanup(function() F18.points[playerNum] = old end)
    F18.points[playerNum] = nil

    -- Right-click under the character.
    local sx = isoToScreenX(playerNum, player:getX(), player:getY(), player:getZ())
    local sy = isoToScreenY(playerNum, player:getX(), player:getY(), player:getZ())
    local context = fakeContext(sx, sy)
    F18.onFillWorldObjectContextMenu(playerNum, context, {}, false)
    if not t:equal(#context.options, 1, "only Set while there is no point") then return end
    local set = context.options[1]
    t:equal(set.name, getText("UI_SurvivorComforts_F18_Set"))
    set.fn(set.target, set.args[1])
    local point = F18.points[playerNum]
    if not t:ok(point, "the point is set") then return end
    t:ok(math.abs(point.x - player:getX()) <= 2 and math.abs(point.y - player:getY()) <= 2, "near the character")

    context = fakeContext(sx, sy)
    F18.onFillWorldObjectContextMenu(playerNum, context, {}, false)
    t:equal(#context.options, 2, "Set and Clear")
    local clear = context.options[2]
    t:equal(clear.name, getText("UI_SurvivorComforts_F18_Clear"))
    clear.fn(clear.target)
    t:equal(F18.points[playerNum], nil, "cleared")

    context = fakeContext(sx, sy)
    F18.onFillWorldObjectContextMenu(playerNum, context, {}, true)
    t:equal(#context.options, 0, "nothing while the game only tests the menu")
end)
