-- F09: a window listing the players on the server: who is online now, and who
-- was online in the last 7 days with how long ago.
--
-- Who is online comes from the server the same way as the vanilla user list
-- (scoreboardUpdate -> OnScoreboardUpdate), and is asked again whenever
-- someone joins or leaves (OnMiniScoreboardUpdate). When the others were last
-- online comes from this mod's server side
-- (server/SurvivorComforts/F09_PlayerList.lua), asked when the window opens,
-- then every minute while it is open. Multiplayer only; in single player
-- there is no button.
--
-- While F17 (the best at each skill) is on, the window has two tabs: the
-- players, and F17's list (client/SurvivorComforts/F17_SkillTop.lua).

require "SurvivorComforts/Core"
require "SurvivorComforts/Window"
require "SurvivorComforts/Commands"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTabPanel"

local FEATURE_ID = "F09"
local LAYOUT_NAME = "survivorcomforts.players"
local REQUEST_INTERVAL = 60 * 1000 -- ms between requests while the window is open
local REQUEST_GAP = 5 * 1000       -- ms at least between asking for both lists
local HIDE_AFTER = 7 * 24 * 3600   -- players not seen for this long are not shown

local ONLINE_COLOR = { r = 0.45, g = 0.9, b = 0.45 }
local OFFLINE_COLOR = { r = 0.6, g = 0.6, b = 0.6 }

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F09_Name",
    tooltip = "UI_SurvivorComforts_F09_Tooltip",
    addOptions = function(options)
        SurvivorComforts.addWindowOptions(options, FEATURE_ID)
    end,
})

---------------------------------------------------------------------------
-- Who is online (the vanilla user list) and when the others were last seen
-- (this mod's server side)
---------------------------------------------------------------------------
-- Sorted user names, or nil until the first answer.
local online = nil
-- { now = server seconds, receivedAt = local ms, players = { { name, lastSeen }, ... } }
-- newest first, or nil until the first answer.
local lastSeen = nil
local windows -- made with the window below

local function refreshWindows()
    windows.forEach(function(window) window:refresh() end)
end

local function requestLastSeen()
    SurvivorComforts.sendCommand("playersRequest", {})
end

-- Opening and closing the window quickly, or players joining one after
-- another, would ask the server every time; the vanilla user list
-- (scoreboardUpdate) has no limit on the server side. Ask at most once every
-- REQUEST_GAP; a request in between is sent when the gap has passed, while a
-- window is open (see prerender).
local lastAllRequest = nil
local allPending = false

local function requestAll()
    local now = getTimestampMs()
    if lastAllRequest and now - lastAllRequest < REQUEST_GAP then
        allPending = true
        return
    end
    lastAllRequest = now
    allPending = false
    scoreboardUpdate()
    requestLastSeen()
end

-- Seconds since the server's "now", counted on this PC since the answer came.
local function serverNow()
    return lastSeen.now + math.floor((getTimestampMs() - lastSeen.receivedAt) / 1000)
end

-- Also comes when a vanilla window (user list, map sharing) asked; kept all the same.
local function onScoreboardUpdate(usernames, displayNames, steamIDs)
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local names = {}
        for i = 0, usernames:size() - 1 do
            table.insert(names, usernames:get(i))
        end
        table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
        online = names
        refreshWindows()
    end)
end

-- Someone joined or left: ask again, so they move between the two lists.
local function onMiniScoreboardUpdate()
    if windows.anyOpen() then
        requestAll()
    end
end

-- The players in the server's answer, newest first; broken entries are left out.
local function readPlayers(args)
    local players = {}
    for _, entry in pairs(args.players or {}) do
        if type(entry) == "table" and type(entry.name) == "string" and tonumber(entry.lastSeen) then
            table.insert(players, { name = entry.name, lastSeen = tonumber(entry.lastSeen) })
        end
    end
    table.sort(players, function(a, b) return a.lastSeen > b.lastSeen end)
    return players
end

SurvivorComforts.onServerCommand(FEATURE_ID, "players", function(args)
    lastSeen = { now = tonumber(args.now) or 0, receivedAt = getTimestampMs(), players = readPlayers(args) }
    refreshWindows()
end)

-- "5 minutes ago" under an hour, "3 hours ago" under a day, then "2 days ago".
local function agoText(seconds)
    if seconds < 3600 then
        return getText("UI_SurvivorComforts_F09_MinutesAgo", tostring(math.max(1, math.floor(seconds / 60))))
    elseif seconds < 24 * 3600 then
        return getText("UI_SurvivorComforts_F09_HoursAgo", tostring(math.floor(seconds / 3600)))
    end
    return getText("UI_SurvivorComforts_F09_DaysAgo", tostring(math.floor(seconds / (24 * 3600))))
end

-- The offline rows: players (newest first) who are not online and were seen
-- in the last HIDE_AFTER, with their "... ago" text.
local function offlineRows(onlineNames, players, now)
    local isOnline = {}
    for _, name in ipairs(onlineNames) do
        isOnline[name] = true
    end
    local shown = {}
    for _, entry in ipairs(players) do
        local age = math.max(0, now - entry.lastSeen)
        if not isOnline[entry.name] and age < HIDE_AFTER then
            table.insert(shown, { name = entry.name, ago = agoText(age) })
        end
    end
    return shown
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
SurvivorComforts_PlayerListBox = ISScrollingListBox:derive("SurvivorComforts_PlayerListBox")

-- Rows are headers ({ header = true }) or players ({ online = bool, lastSeen = seconds }).
function SurvivorComforts_PlayerListBox:doDrawItem(y, item, alt)
    if (y + self:getYScroll() + self.itemheight < 0) or (y + self:getYScroll() >= self.height) then
        return y + self.itemheight
    end
    local row = item.item
    local textY = y + (self.itemheight - self.fontHgt) / 2
    if row.header then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.3, 0.3, 0.3, 0.3)
        self:drawText(item.text, 6, textY, 1, 1, 1, 1, self.font)
        return y + self.itemheight
    end
    local color = row.online and ONLINE_COLOR or OFFLINE_COLOR
    local dot = math.floor(self.fontHgt / 2)
    self:drawRect(12, y + (self.itemheight - dot) / 2, dot, dot, 1, color.r, color.g, color.b)
    self:drawText(item.text, 12 + dot + 8, textY, 1, 1, 1, 1, self.font)
    if row.ago then
        local right = self:getWidth() - 10 - (self:isVScrollBarVisible() and 13 or 0)
        local width = getTextManager():MeasureStringX(self.font, row.ago)
        self:drawText(row.ago, right - width, textY, OFFLINE_COLOR.r, OFFLINE_COLOR.g, OFFLINE_COLOR.b, 1, self.font)
    end
    return y + self.itemheight
end

function SurvivorComforts_PlayerListBox:render()
    ISScrollingListBox.render(self)
    if not online or not lastSeen then
        self:drawTextCentre(getText("UI_SurvivorComforts_F09_Loading"), self.width / 2, 10, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

SurvivorComforts_PlayerListWindow = SurvivorComforts_Window:derive("SurvivorComforts_PlayerListWindow")

function SurvivorComforts_PlayerListWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local list = SurvivorComforts_PlayerListBox:new(0, self:titleBarHeight(), self.width, 100)
    list:initialise()
    list:instantiate()
    list.font = UIFont.Small
    list.fontHgt = getTextManager():getFontHeight(UIFont.Small)
    list.itemheight = list.fontHgt + 8
    list.drawBorder = true
    list:setOnMouseDownFunction(self, SurvivorComforts_PlayerListWindow.onClickRow)
    self.list = list
    self:arrange()
    self:refresh()
end

-- Whether F17's tab should be there.
local function hasSkillTop()
    return SurvivorComforts.skillTop ~= nil and SurvivorComforts.skillTop.isAvailable()
end

-- The players' list straight in the window, or, while F17 is on, two tabs:
-- the players and the best at each skill. Done again when F17 is switched
-- on or off (see prerender).
function SurvivorComforts_PlayerListWindow:arrange()
    local withTabs = hasSkillTop()
    if self.tabs then
        self.tabs:removeView(self.list)
        if self.skillTop then
            self.tabs:removeView(self.skillTop)
            SurvivorComforts.skillTop.removeList(self.skillTop)
            self.skillTop = nil
        end
        self:removeChild(self.tabs)
        self.tabs = nil
    elseif self.list.parent == self then
        self:removeChild(self.list)
    end
    self.list:setVisible(true)
    local th = self:titleBarHeight()
    if withTabs then
        local tabs = ISTabPanel:new(0, th, self.width, 100)
        tabs:initialise()
        tabs:setEqualTabWidth(false)
        tabs.target = self
        tabs.onActivateView = SurvivorComforts_PlayerListWindow.onTab
        self:addChild(tabs)
        tabs:addView(getText("UI_SurvivorComforts_F09_TabPlayers"), self.list)
        self.skillTop = SurvivorComforts.skillTop.newList(self.width, 100)
        tabs:addView(getText("UI_SurvivorComforts_F17_Tab"), self.skillTop)
        self.tabs = tabs
    else
        self.list:setY(th)
        self:addChild(self.list)
    end
    self.withTabs = withTabs
    self:fitChildren()
end

function SurvivorComforts_PlayerListWindow:onTab(tabs)
    if tabs:getActiveView() == self.skillTop then
        self.skillTop:onShown()
    end
end

-- Keep the lists (or the tabs) filling the window.
function SurvivorComforts_PlayerListWindow:fitChildren()
    local th = self:titleBarHeight()
    local h = math.max(0, self.height - th - self:resizeWidgetHeight())
    local w = self.width
    local function fit(child, height)
        if child:getWidth() ~= w then child:setWidth(w) end
        if child:getHeight() ~= height then child:setHeight(height) end
    end
    if self.tabs then
        fit(self.tabs, h)
        local viewHeight = math.max(0, h - self.tabs.tabHeight)
        fit(self.list, viewHeight)
        fit(self.skillTop, viewHeight)
    else
        fit(self.list, h)
    end
end

-- An online player opens their skills (F15, when it is on).
function SurvivorComforts_PlayerListWindow:onClickRow(row)
    if row and row.online and row.name and SurvivorComforts.showMemberSkills then
        SurvivorComforts.showMemberSkills(self.playerNum, row.name)
    end
end

-- Keep the list filling the window, and ask for the last-seen times again
-- every minute (who is online follows joins and leaves by itself).
function SurvivorComforts_PlayerListWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.list then
        if hasSkillTop() ~= self.withTabs then
            self:arrange()
        end
        self:fitChildren()
    end
    if allPending then
        requestAll()
    end
    if getTimestampMs() - (self.lastRequest or 0) >= REQUEST_INTERVAL then
        self.lastRequest = getTimestampMs()
        requestLastSeen()
    end
end

function SurvivorComforts_PlayerListWindow:refresh()
    local list = self.list
    if not list then return end
    local scroll = list:getYScroll()
    list:clear()
    if not online or not lastSeen then return end
    local shown = offlineRows(online, lastSeen.players, serverNow())
    list:addItem(getText("UI_SurvivorComforts_F09_Online", tostring(#online)), { header = true })
    for _, name in ipairs(online) do
        list:addItem(name, { online = true, name = name })
    end
    list:addItem(getText("UI_SurvivorComforts_F09_Offline", tostring(#shown)), { header = true })
    for _, entry in ipairs(shown) do
        list:addItem(entry.name, { online = false, ago = entry.ago })
    end
    list:setYScroll(scroll)
end

function SurvivorComforts_PlayerListWindow:new(x, y, width, height, playerNum)
    local o = SurvivorComforts_Window.new(self, x, y, width, height, playerNum, "UI_SurvivorComforts_F09_Title")
    o.minimumWidth = 200
    o.minimumHeight = 150
    return o
end

windows = SurvivorComforts.addWindow({
    id = FEATURE_ID,
    class = SurvivorComforts_PlayerListWindow,
    title = "UI_SurvivorComforts_F09_Title",
    layout = LAYOUT_NAME,
    x = 200, y = 150, width = 260, height = 320,
    sidebar = { order = 3, icon = "Players" },
    -- Multiplayer only: no button in single player.
    isAvailable = function() return isClient() end,
    onOpen = function(window)
        window:refresh()
        -- Ask right away; the "x minutes ago" texts are also brought up to date.
        window.lastRequest = getTimestampMs()
        requestAll()
    end,
})

Events.OnScoreboardUpdate.Add(onScoreboardUpdate)
Events.OnMiniScoreboardUpdate.Add(onMiniScoreboardUpdate)

-- For the tests (Core.lua).
SurvivorComforts.internals.F09 = {
    agoText = agoText,
    readPlayers = readPlayers,
    offlineRows = offlineRows,
    requestAll = requestAll,
    isRequestPending = function() return allPending end,
    hasSkillTop = hasSkillTop,
    HIDE_AFTER = HIDE_AFTER,
    REQUEST_GAP = REQUEST_GAP,
}
