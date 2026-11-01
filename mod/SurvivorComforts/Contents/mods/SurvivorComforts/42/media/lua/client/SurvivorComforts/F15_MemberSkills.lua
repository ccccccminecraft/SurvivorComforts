-- F15: a window with the skills of another player on the server, opened by
-- clicking an online player in F09's player list.
--
-- The skills are read on the server (server/SurvivorComforts/F15_MemberSkills.lua),
-- asked for when the window opens or shows another player. They are listed
-- in the same order as the game's skill screen, with levels 0-10 as boxes and
-- a number. Multiplayer only, like F09.
--
-- Based on Skill Viewer by itsu07 (MIT License,
-- https://github.com/itsu07/SkillViewer), changed to fit this mod: opened
-- from F09 instead of its own player list and key, the shared window and
-- server commands, a feature switch in this mod's options.

require "SurvivorComforts/Core"
require "SurvivorComforts/Window"
require "SurvivorComforts/Commands"
require "SurvivorComforts/Skills"
require "ISUI/ISScrollingListBox"

local FEATURE_ID = "F15"
local LAYOUT_NAME = "survivorcomforts.memberskills"
local MAX_LEVEL = 10
local BOX = 8
local BOX_GAP = 2

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F15_Name",
    tooltip = "UI_SurvivorComforts_F15_Tooltip",
})

---------------------------------------------------------------------------
-- The skill list
---------------------------------------------------------------------------
SurvivorComforts_MemberSkillsList = ISScrollingListBox:derive("SurvivorComforts_MemberSkillsList")

-- Rows are category headers ({ header = true }) or skills ({ level }).
function SurvivorComforts_MemberSkillsList:doDrawItem(y, item, alt)
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
    self:drawText(item.text, 18, textY, 0.9, 0.9, 0.9, 1, self.font)
    local right = w - 10 - (self:isVScrollBarVisible() and 13 or 0)
    self:drawTextRight(tostring(row.level), right, textY, 1, 1, 1, 1, self.font)
    local boxesX = right - 24 - MAX_LEVEL * (BOX + BOX_GAP)
    local boxY = y + (h - BOX) / 2
    for i = 1, MAX_LEVEL do
        local x = boxesX + (i - 1) * (BOX + BOX_GAP)
        if i <= row.level then
            self:drawRect(x, boxY, BOX, BOX, 0.9, 0.95, 0.8, 0.3)
        else
            self:drawRectBorder(x, boxY, BOX, BOX, 0.6, 0.5, 0.5, 0.5)
        end
    end
    return y + h
end

function SurvivorComforts_MemberSkillsList:render()
    ISScrollingListBox.render(self)
    local window = self.parent
    if window and window.message then
        self:drawTextCentre(window.message, self.width / 2, 10, 0.7, 0.7, 0.7, 1, self.font)
    end
end

-- Same order as the game's skill screen (ISCharacterInfo): the passive
-- category first, then categories by name, and skills by name in each.
local function sortCategories(a, b)
    if a.perk:isPassiv() and not b.perk:isPassiv() then return true end
    if b.perk:isPassiv() and not a.perk:isPassiv() then return false end
    return not string.sort(a.name, b.name)
end

local function sortSkills(a, b)
    return a.name < b.name
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
SurvivorComforts_MemberSkillsWindow = SurvivorComforts_Window:derive("SurvivorComforts_MemberSkillsWindow")

function SurvivorComforts_MemberSkillsWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local list = SurvivorComforts_MemberSkillsList:new(0, th, self.width, 100)
    list:initialise()
    list:instantiate()
    list.font = UIFont.Small
    list.fontHgt = getTextManager():getFontHeight(UIFont.Small)
    list.itemheight = list.fontHgt + 6
    list.drawBorder = true
    self:addChild(list)
    self.list = list
end

-- Keep the list filling the window whenever the player resizes it.
function SurvivorComforts_MemberSkillsWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.list then
        local th = self:titleBarHeight()
        local rh = self:resizeWidgetHeight()
        local h = math.max(0, self.height - th - rh)
        if self.list:getWidth() ~= self.width then self.list:setWidth(self.width) end
        if self.list:getHeight() ~= h then self.list:setHeight(h) end
    end
end

-- Shows a player: clears the list and asks the server for their skills.
function SurvivorComforts_MemberSkillsWindow:showPlayer(username)
    self.username = username
    self.title = getText("UI_SurvivorComforts_F15_Title", username)
    self.message = getText("UI_SurvivorComforts_F15_Loading")
    self.list:clear()
    SurvivorComforts.sendCommand("skillsRequest", { username = username })
end

-- skills = { [perk id] = level }, or nil when the player is not online.
function SurvivorComforts_MemberSkillsWindow:setSkills(username, skills)
    if username ~= self.username then return end
    self.list:clear()
    if not skills then
        self.message = getText("UI_SurvivorComforts_F15_NoData")
        return
    end
    self.message = nil

    local groups, order = {}, {}
    SurvivorComforts.forEachSkill(function(_, perk)
        local level = tonumber(skills[perk:getId()])
        if not level then return end
        local parent = perk:getParent()
        local key = parent:getId()
        if not groups[key] then
            local parentPerk = PerkFactory.getPerk(parent)
            groups[key] = { perk = parentPerk, name = parentPerk:getName(), rows = {} }
            table.insert(order, groups[key])
        end
        table.insert(groups[key].rows, { name = perk:getName(), level = level })
    end)
    table.sort(order, sortCategories)
    for _, group in ipairs(order) do
        table.sort(group.rows, sortSkills)
        self.list:addItem(group.name, { header = true })
        for _, row in ipairs(group.rows) do
            self.list:addItem(row.name, { level = row.level })
        end
    end
end

function SurvivorComforts_MemberSkillsWindow:new(x, y, width, height, playerNum)
    local o = SurvivorComforts_Window.new(self, x, y, width, height, playerNum, "UI_SurvivorComforts_F15_Name")
    o.minimumWidth = 280
    o.minimumHeight = 150
    return o
end

local windows = SurvivorComforts.addWindow({
    id = FEATURE_ID,
    class = SurvivorComforts_MemberSkillsWindow,
    title = "UI_SurvivorComforts_F15_Name",
    layout = LAYOUT_NAME,
    x = 480, y = 150, width = 340, height = 460,
    -- Multiplayer only, like F09.
    isAvailable = function() return isClient() end,
})

-- Opens (or switches) the window to a player; called from F09's player list.
function SurvivorComforts.showMemberSkills(playerNum, username)
    local window = windows.open(playerNum)
    if window then
        SurvivorComforts.safeCall(FEATURE_ID, window.showPlayer, window, username)
    end
end

SurvivorComforts.onServerCommand(FEATURE_ID, "skills", function(args)
    if type(args.username) ~= "string" then return end
    local skills = type(args.skills) == "table" and args.skills or nil
    windows.forEach(function(window) window:setSkills(args.username, skills) end)
end)
