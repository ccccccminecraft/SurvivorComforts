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

require "SurvivorComforts/Core"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "SurvivorComforts/Sidebar"

local FEATURE_ID = "F09"
local LAYOUT_NAME = "survivorcomforts.players"
local MODULE = "SurvivorComforts" -- client/server command module, see the server file
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
        options:addTickBox(FEATURE_ID .. "_sidebar", getText("UI_SurvivorComforts_F09_Sidebar"), true, getText("UI_SurvivorComforts_F09_Sidebar_Tooltip"))
        options:addKeyBind(FEATURE_ID .. "_key", getText("UI_SurvivorComforts_F09_Key"), 0)
    end,
})

local function isAvailable()
    return isClient() and SurvivorComforts.isEnabled(FEATURE_ID)
end

---------------------------------------------------------------------------
-- Who is online (the vanilla user list) and when the others were last seen
-- (this mod's server side)
---------------------------------------------------------------------------
-- Sorted user names, or nil until the first answer.
local online = nil
-- { now = server seconds, receivedAt = local ms, players = { { name, lastSeen }, ... } }
-- newest first, or nil until the first answer.
local lastSeen = nil
local refreshWindows

local function anyWindowOpen()
    for _, window in pairs(SurvivorComforts_PlayerListWindow.instances) do
        if window:getIsVisible() then return true end
    end
    return false
end

local function requestLastSeen()
    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, MODULE, "playersRequest", {})
    end
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
    if anyWindowOpen() then
        requestAll()
    end
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= "players" then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local players = {}
        for _, entry in pairs(args.players or {}) do
            if type(entry) == "table" and type(entry.name) == "string" and tonumber(entry.lastSeen) then
                table.insert(players, { name = entry.name, lastSeen = tonumber(entry.lastSeen) })
            end
        end
        table.sort(players, function(a, b) return a.lastSeen > b.lastSeen end)
        lastSeen = { now = tonumber(args.now) or 0, receivedAt = getTimestampMs(), players = players }
        refreshWindows()
    end)
end

-- "5 minutes ago" under an hour, "3 hours ago" under a day, then "2 days ago".
local function agoText(seconds)
    if seconds < 3600 then
        return getText("UI_SurvivorComforts_F09_MinutesAgo", tostring(math.max(1, math.floor(seconds / 60))))
    elseif seconds < 24 * 3600 then
        return getText("UI_SurvivorComforts_F09_HoursAgo", tostring(math.floor(seconds / 3600)))
    end
    return getText("UI_SurvivorComforts_F09_DaysAgo", tostring(math.floor(seconds / (24 * 3600))))
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

SurvivorComforts_PlayerListWindow = ISCollapsableWindow:derive("SurvivorComforts_PlayerListWindow")
SurvivorComforts_PlayerListWindow.instances = {}

function SurvivorComforts_PlayerListWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local list = SurvivorComforts_PlayerListBox:new(0, th, self.width, 100)
    list:initialise()
    list:instantiate()
    list.font = UIFont.Small
    list.fontHgt = getTextManager():getFontHeight(UIFont.Small)
    list.itemheight = list.fontHgt + 8
    list.drawBorder = true
    self:addChild(list)
    self.list = list
    self:refresh()
end

-- Keep the list filling the window, and ask for the last-seen times again
-- every minute (who is online follows joins and leaves by itself).
function SurvivorComforts_PlayerListWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.list then
        local th = self:titleBarHeight()
        local rh = self:resizeWidgetHeight()
        local h = math.max(0, self.height - th - rh)
        if self.list:getWidth() ~= self.width then self.list:setWidth(self.width) end
        if self.list:getHeight() ~= h then self.list:setHeight(h) end
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
    local isOnline = {}
    for _, name in ipairs(online) do
        isOnline[name] = true
    end
    local now = serverNow()
    local shown = {}
    for _, entry in ipairs(lastSeen.players) do
        local age = math.max(0, now - entry.lastSeen)
        if not isOnline[entry.name] and age < HIDE_AFTER then
            table.insert(shown, { name = entry.name, ago = agoText(age) })
        end
    end
    list:addItem(getText("UI_SurvivorComforts_F09_Online", tostring(#online)), { header = true })
    for _, name in ipairs(online) do
        list:addItem(name, { online = true })
    end
    list:addItem(getText("UI_SurvivorComforts_F09_Offline", tostring(#shown)), { header = true })
    for _, entry in ipairs(shown) do
        list:addItem(entry.name, { online = false, ago = entry.ago })
    end
    list:setYScroll(scroll)
end

function SurvivorComforts_PlayerListWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

function SurvivorComforts_PlayerListWindow:new(x, y, width, height, playerNum)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.playerNum = playerNum
    o.title = getText("UI_SurvivorComforts_F09_Title")
    o.minimumWidth = 200
    o.minimumHeight = 150
    o.visibleOnStartup = false
    return o
end

refreshWindows = function()
    for _, window in pairs(SurvivorComforts_PlayerListWindow.instances) do
        window:refresh()
    end
end

local function createWindow(playerNum)
    local x = getPlayerScreenLeft(playerNum) + 200
    local y = getPlayerScreenTop(playerNum) + 150
    local window = SurvivorComforts_PlayerListWindow:new(x, y, 260, 320, playerNum)
    window:initialise()
    window:setVisible(false)
    SurvivorComforts_PlayerListWindow.instances[playerNum] = window
    -- Only the first local player has a saved layout, like vanilla windows.
    if playerNum == 0 then
        ISLayoutManager.RegisterWindow(LAYOUT_NAME, ISCollapsableWindow, window)
    end
    return window
end

local function isWindowOpen(playerNum)
    local window = SurvivorComforts_PlayerListWindow.instances[playerNum]
    return window ~= nil and window:getIsVisible()
end

local function toggleWindow(playerNum)
    if not isAvailable() then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local window = SurvivorComforts_PlayerListWindow.instances[playerNum] or createWindow(playerNum)
        if window:getIsVisible() then
            window:close()
            return
        end
        window:refresh()
        window:addToUIManager()
        window:setVisible(true)
        window:bringToTop()
        -- Ask right away; the "x minutes ago" texts are also brought up to date.
        window.lastRequest = getTimestampMs()
        requestAll()
    end)
end

SurvivorComforts.addSidebarButton({
    id = FEATURE_ID,
    order = 3,
    icon = "Players",
    tooltip = "UI_SurvivorComforts_F09_Title",
    isShown = function()
        return isAvailable() and SurvivorComforts.getOptionValue(FEATURE_ID .. "_sidebar") == true
    end,
    isActive = isWindowOpen,
    onClick = toggleWindow,
})

local function onKeyPressed(key)
    if key == nil or key == 0 then return end
    if key ~= SurvivorComforts.getOptionValue(FEATURE_ID .. "_key") then return end
    local player = getPlayer()
    if not player then return end
    toggleWindow(player:getPlayerNum())
end

Events.OnKeyPressed.Add(onKeyPressed)
Events.OnServerCommand.Add(onServerCommand)
Events.OnScoreboardUpdate.Add(onScoreboardUpdate)
Events.OnMiniScoreboardUpdate.Add(onMiniScoreboardUpdate)
