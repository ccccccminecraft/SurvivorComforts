-- F04: while reading, show under the character how long until the book is
-- finished, in game time and in real time.
--
-- The time is measured from how fast the reading progress actually moves
-- (over the last few seconds) instead of recomputing ISReadABook's duration
-- formula, so it stays right with traits, glasses, sitting, day length and
-- game speed. Nothing is changed in the reading action itself.

require "SurvivorComforts/Core"
require "ISUI/ISUIElement"

local FEATURE_ID = "F04"
local SAMPLE_INTERVAL_MS = 500
local WINDOW_MS = 6000      -- progress rate is taken over this much real time
local MIN_SPAN_MS = 1500    -- no estimate until this much has been observed

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F04_Name",
    tooltip = "UI_SurvivorComforts_F04_Tooltip",
    addOptions = function(options)
        options:addTickBox(FEATURE_ID .. "_game", getText("UI_SurvivorComforts_F04_ShowGame"), true)
        options:addTickBox(FEATURE_ID .. "_real", getText("UI_SurvivorComforts_F04_ShowReal"), true)
    end,
})

-- playerNum -> { action, samples = { {delta, gameHours, ms}, ... }, lastSampleMs, gameMinutes, realSeconds }
-- gameMinutes / realSeconds stay nil until the first estimate.
local trackers = {}

local function currentReadAction(player)
    -- Look the queue up without ISTimedActionQueue.getTimedActionQueue, which creates one.
    local queue = ISTimedActionQueue.queues[player]
    local action = queue and queue.queue and queue.queue[1]
    if action and action.Type == "ISReadABook" and action.action then
        return action
    end
    return nil
end

-- Game time as HH:MM.
local function formatGameMinutes(minutes)
    if not minutes then return "--:--" end
    local m = math.max(1, math.ceil(minutes))
    return string.format("%02d:%02d", math.floor(m / 60), m % 60)
end

-- Real time as MM:SS (H:MM:SS from an hour), since it is usually minutes.
local function formatRealSeconds(seconds)
    if not seconds then return "--:--" end
    local s = math.max(1, math.ceil(seconds))
    if s >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
    end
    return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

-- Game time is orange and real time green, so a single time needs no "(real)" label.
local TEXT_COLOR = { 1, 1, 1 }
local GAME_COLOR = { 1, 0.65, 0.2 }
local REAL_COLOR = { 0.45, 0.9, 0.45 }

-- Splits a translation like "残り %1（現実 %2）" into parts, each with its color.
-- getText must get every argument (without them it warns and mangles %1), so
-- markers are passed in and looked up afterwards.
local function buildParts(key, values)
    local template
    if #values == 2 then
        template = getText(key, "@@1@@", "@@2@@")
    else
        template = getText(key, "@@1@@")
    end
    local parts = {}
    local pos = 1
    while true do
        local s, e, n = string.find(template, "@@(%d)@@", pos)
        if not s then break end
        if s > pos then
            table.insert(parts, { text = string.sub(template, pos, s - 1), color = TEXT_COLOR })
        end
        local value = values[tonumber(n)]
        if value then
            table.insert(parts, value)
        end
        pos = e + 1
    end
    if pos <= string.len(template) then
        table.insert(parts, { text = string.sub(template, pos), color = TEXT_COLOR })
    end
    return parts
end

-- Returns nil when both times are turned off.
local function labelParts(tracker)
    local showGame = SurvivorComforts.getOptionValue(FEATURE_ID .. "_game") == true
    local showReal = SurvivorComforts.getOptionValue(FEATURE_ID .. "_real") == true
    local game = { text = formatGameMinutes(tracker.gameMinutes), color = GAME_COLOR }
    local real = { text = formatRealSeconds(tracker.realSeconds), color = REAL_COLOR }
    if showGame and showReal then
        return buildParts("UI_SurvivorComforts_F04_GameAndReal", { game, real })
    elseif showGame then
        return buildParts("UI_SurvivorComforts_F04_One", { game })
    elseif showReal then
        return buildParts("UI_SurvivorComforts_F04_One", { real })
    end
    return nil
end

local function updateTracker(player)
    local playerNum = player:getPlayerNum()
    local action = currentReadAction(player)
    if not action then
        trackers[playerNum] = nil
        return
    end

    local tracker = trackers[playerNum]
    if not tracker or tracker.action ~= action then
        tracker = { action = action, samples = {}, lastSampleMs = 0 }
        trackers[playerNum] = tracker
    end

    local now = getTimestampMs()
    if now - tracker.lastSampleMs < SAMPLE_INTERVAL_MS then return end
    tracker.lastSampleMs = now

    local delta = action:getJobDelta()
    local gameHours = getGameTime():getWorldAgeHours()
    local samples = tracker.samples
    table.insert(samples, { delta = delta, gameHours = gameHours, ms = now })
    while #samples > 2 and now - samples[1].ms > WINDOW_MS do
        table.remove(samples, 1)
    end

    local first = samples[1]
    local progressed = delta - first.delta
    -- While paused nothing moves; keep the last estimate.
    if progressed <= 0 or now - first.ms < MIN_SPAN_MS then return end

    local left = 1 - delta
    tracker.gameMinutes = left * (gameHours - first.gameHours) * 60 / progressed
    tracker.realSeconds = left * (now - first.ms) / 1000 / progressed
end

local function onPlayerUpdate(player)
    if not player:isLocalPlayer() then return end
    if not SurvivorComforts.isEnabled(FEATURE_ID) then
        trackers[player:getPlayerNum()] = nil
        return
    end
    SurvivorComforts.safeCall(FEATURE_ID, updateTracker, player)
end

---------------------------------------------------------------------------
-- Label drawn under the character. One tiny (1x1, so it never catches the
-- mouse) element per player; the text is drawn at the character's screen position.
---------------------------------------------------------------------------
SurvivorComforts_ReadingTimeLabel = ISUIElement:derive("SurvivorComforts_ReadingTimeLabel")
local labels = {}

function SurvivorComforts_ReadingTimeLabel:render()
    local tracker = trackers[self.playerNum]
    local player = getSpecificPlayer(self.playerNum)
    if not tracker or not player then return end
    local parts = labelParts(tracker)
    if not parts then return end
    local font = UIFont.Small
    local textManager = getTextManager()
    local width = 0
    for _, part in ipairs(parts) do
        part.width = textManager:MeasureStringX(font, part.text)
        width = width + part.width
    end
    local sx = isoToScreenX(self.playerNum, player:getX(), player:getY(), player:getZ())
    local sy = isoToScreenY(self.playerNum, player:getX(), player:getY(), player:getZ())
    local x = sx - self:getAbsoluteX() - width / 2
    local y = sy - self:getAbsoluteY() + 8
    for _, part in ipairs(parts) do
        local c = part.color
        self:drawText(part.text, x + 1, y + 1, 0, 0, 0, 0.8, font)
        self:drawText(part.text, x, y, c[1], c[2], c[3], 1, font)
        x = x + part.width
    end
end

function SurvivorComforts_ReadingTimeLabel:new(playerNum)
    local o = ISUIElement.new(self, 0, 0, 1, 1)
    o.playerNum = playerNum
    return o
end

local function onCreatePlayer(playerNum, player)
    if labels[playerNum] then return end
    local label = SurvivorComforts_ReadingTimeLabel:new(playerNum)
    label:initialise()
    label:addToUIManager()
    label:setAlwaysOnTop(false)
    labels[playerNum] = label
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
