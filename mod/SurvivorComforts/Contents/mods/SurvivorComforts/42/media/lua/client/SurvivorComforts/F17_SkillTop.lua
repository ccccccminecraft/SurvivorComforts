-- F17: a window with the best player at each skill, among the players online
-- on the server, and their level. Players at the same level are all shown.
--
-- Everyone's skills are read on the server
-- (server/SurvivorComforts/F17_SkillTop.lua) in one answer, asked for when the
-- window opens, then every minute while it is open. The best at each skill is
-- worked out here. Skills are listed in the same order as the game's skill
-- screen (Skills.lua). Multiplayer only, like F09 and F15.

require "SurvivorComforts/Core"
require "SurvivorComforts/Window"
require "SurvivorComforts/Commands"
require "SurvivorComforts/Skills"
require "ISUI/ISScrollingListBox"

local FEATURE_ID = "F17"
local LAYOUT_NAME = "survivorcomforts.skilltop"
local REQUEST_INTERVAL = 60 * 1000 -- ms between requests while the window is open

local NAMES_COLOR = { r = 0.45, g = 0.9, b = 0.45 }
local NOBODY_COLOR = { r = 0.6, g = 0.6, b = 0.6 }

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F17_Name",
    tooltip = "UI_SurvivorComforts_F17_Tooltip",
    addOptions = function(options)
        SurvivorComforts.addWindowOptions(options, FEATURE_ID)
    end,
})

---------------------------------------------------------------------------
-- The best at each skill
---------------------------------------------------------------------------
-- players = { [username] = { [perk id] = level } }, as the server sends it.
-- Returns { [perk id] = { level = n, names = { sorted usernames } } } for
-- every skill anyone has. Nobody is the best at level 0 (names is empty
-- then). Broken entries are left out.
local function computeTops(players)
    local tops = {}
    for name, skills in pairs(players or {}) do
        if type(name) == "string" and type(skills) == "table" then
            for perkId, value in pairs(skills) do
                local level = tonumber(value)
                if type(perkId) == "string" and level then
                    local top = tops[perkId]
                    if not top or level > top.level then
                        tops[perkId] = { level = level, names = { name } }
                    elseif level == top.level then
                        table.insert(top.names, name)
                    end
                end
            end
        end
    end
    for _, top in pairs(tops) do
        if top.level <= 0 then
            top.level = 0
            top.names = {}
        end
        table.sort(top.names, function(a, b) return string.lower(a) < string.lower(b) end)
    end
    return tops
end

-- How many players are in the server's answer.
local function countPlayers(players)
    local count = 0
    for name, skills in pairs(players or {}) do
        if type(name) == "string" and type(skills) == "table" then
            count = count + 1
        end
    end
    return count
end

local function request()
    SurvivorComforts.sendCommand("skillTopRequest", {})
end

---------------------------------------------------------------------------
-- The skill list
---------------------------------------------------------------------------
SurvivorComforts_SkillTopList = ISScrollingListBox:derive("SurvivorComforts_SkillTopList")

-- Rows are category headers ({ header = true }) or skills ({ level, names }).
-- Columns: the skill, its best level, then who has it.
function SurvivorComforts_SkillTopList:doDrawItem(y, item, alt)
    local h = self.itemheight
    if (y + self:getYScroll() + h < 0) or (y + self:getYScroll() >= self.height) then
        return y + h
    end
    local row = item.item
    local w = self:getWidth()
    local textY = y + (h - self.fontHgt) / 2
    if row.header then
        self:drawRect(0, y, w, h - 1, 0.3, 0.3, 0.3, 0.3)
        self:drawText(item.text, 6, textY, 1, 0.85, 0.4, 1, self.font)
        return y + h
    end
    local levelRight = 18 + (self.nameWidth or 100) + 34
    self:drawText(item.text, 18, textY, 0.9, 0.9, 0.9, 1, self.font)
    if #row.names == 0 then
        self:drawTextRight("-", levelRight, textY, NOBODY_COLOR.r, NOBODY_COLOR.g, NOBODY_COLOR.b, 1, self.font)
        return y + h
    end
    self:drawTextRight(tostring(row.level), levelRight, textY, 1, 1, 1, 1, self.font)
    self:drawText(table.concat(row.names, ", "), levelRight + 14, textY, NAMES_COLOR.r, NAMES_COLOR.g, NAMES_COLOR.b, 1, self.font)
    return y + h
end

function SurvivorComforts_SkillTopList:render()
    ISScrollingListBox.render(self)
    local window = self.parent
    if window and window.message then
        self:drawTextCentre(window.message, self.width / 2, 10, 0.7, 0.7, 0.7, 1, self.font)
    end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
SurvivorComforts_SkillTopWindow = SurvivorComforts_Window:derive("SurvivorComforts_SkillTopWindow")

function SurvivorComforts_SkillTopWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local list = SurvivorComforts_SkillTopList:new(0, th, self.width, 100)
    list:initialise()
    list:instantiate()
    list.font = UIFont.Small
    list.fontHgt = getTextManager():getFontHeight(UIFont.Small)
    list.itemheight = list.fontHgt + 6
    list.drawBorder = true
    self:addChild(list)
    self.list = list
    self.message = getText("UI_SurvivorComforts_F17_Loading")
end

-- Keep the list filling the window, and ask again every minute.
function SurvivorComforts_SkillTopWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.list then
        local th = self:titleBarHeight()
        local rh = self:resizeWidgetHeight()
        local h = math.max(0, self.height - th - rh)
        if self.list:getWidth() ~= self.width then self.list:setWidth(self.width) end
        if self.list:getHeight() ~= h then self.list:setHeight(h) end
    end
    if getTimestampMs() - (self.lastRequest or 0) >= REQUEST_INTERVAL then
        self.lastRequest = getTimestampMs()
        request()
    end
end

-- players = { [username] = { [perk id] = level } } from the server.
function SurvivorComforts_SkillTopWindow:setPlayers(players)
    local list = self.list
    local scroll = list:getYScroll()
    list:clear()
    if countPlayers(players) == 0 then
        self.message = getText("UI_SurvivorComforts_F17_NoData")
        return
    end
    self.message = nil
    self.title = getText("UI_SurvivorComforts_F17_TitleCount", tostring(countPlayers(players)))

    local tops = computeTops(players)
    -- In the same order as the game's skill screen (Skills.lua).
    local groups = SurvivorComforts.skillGroups(function(perk)
        return tops[perk:getId()] ~= nil
    end)
    local textManager = getTextManager()
    local nameWidth = 0
    for _, group in ipairs(groups) do
        list:addItem(group.name, { header = true })
        for _, row in ipairs(group.rows) do
            local top = tops[row.perk:getId()]
            list:addItem(row.name, { level = top.level, names = top.names })
            nameWidth = math.max(nameWidth, textManager:MeasureStringX(list.font, row.name))
        end
    end
    list.nameWidth = nameWidth
    list:setYScroll(scroll)
end

function SurvivorComforts_SkillTopWindow:new(x, y, width, height, playerNum)
    local o = SurvivorComforts_Window.new(self, x, y, width, height, playerNum, "UI_SurvivorComforts_F17_Title")
    o.minimumWidth = 280
    o.minimumHeight = 150
    return o
end

local windows = SurvivorComforts.addWindow({
    id = FEATURE_ID,
    class = SurvivorComforts_SkillTopWindow,
    title = "UI_SurvivorComforts_F17_Title",
    layout = LAYOUT_NAME,
    x = 520, y = 150, width = 380, height = 460,
    sidebar = { order = 5, icon = "SkillTop" },
    -- Multiplayer only, like F09 and F15.
    isAvailable = function() return isClient() end,
    onOpen = function(window)
        -- Ask right away (prerender then waits a minute).
        window.lastRequest = getTimestampMs()
        request()
    end,
})

SurvivorComforts.onServerCommand(FEATURE_ID, "skillTop", function(args)
    local players = type(args.players) == "table" and args.players or nil
    windows.forEach(function(window) window:setPlayers(players) end)
end)

-- For the tests (Core.lua).
SurvivorComforts.internals.F17 = {
    computeTops = computeTops,
    countPlayers = countPlayers,
}
