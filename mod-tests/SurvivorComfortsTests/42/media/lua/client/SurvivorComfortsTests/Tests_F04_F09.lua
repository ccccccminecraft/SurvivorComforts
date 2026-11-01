-- Tests for F04 (reading time left) and F09 (player list): the texts shown,
-- worked out without a world.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/F04_ReadingTime"
require "SurvivorComforts/F09_PlayerList"

local T = SurvivorComfortsTests
local H = T.helpers

---------------------------------------------------------------------------
-- F04
---------------------------------------------------------------------------
T.add("F04: game time as HH:MM", function(t)
    local F04 = SurvivorComforts.internals.F04
    t:equal(F04.formatGameMinutes(nil), "--:--", "not measured yet")
    t:equal(F04.formatGameMinutes(0.2), "00:01", "under a minute shows a minute")
    t:equal(F04.formatGameMinutes(5), "00:05")
    t:equal(F04.formatGameMinutes(90.5), "01:31", "rounded up")
    t:equal(F04.formatGameMinutes(600), "10:00")
end)

T.add("F04: real time as MM:SS, H:MM:SS from an hour", function(t)
    local F04 = SurvivorComforts.internals.F04
    t:equal(F04.formatRealSeconds(nil), "--:--", "not measured yet")
    t:equal(F04.formatRealSeconds(0.3), "00:01", "under a second shows a second")
    t:equal(F04.formatRealSeconds(75), "01:15")
    t:equal(F04.formatRealSeconds(3600), "1:00:00")
    t:equal(F04.formatRealSeconds(3725), "1:02:05")
end)

-- The parts of the label hold the times in their colours; nil with both off.
local function texts(parts)
    local byText = {}
    for _, part in ipairs(parts) do byText[part.text] = part.color end
    return byText
end

T.add("F04: the label follows the game and real time options", function(t)
    local F04 = SurvivorComforts.internals.F04
    local tracker = { gameMinutes = 5, realSeconds = 75 }

    H.setOption(t, "F04_game", true)
    H.setOption(t, "F04_real", true)
    local both = texts(F04.labelParts(tracker))
    t:equal(both["00:05"], F04.GAME_COLOR, "game time in orange")
    t:equal(both["01:15"], F04.REAL_COLOR, "real time in green")

    H.setOption(t, "F04_real", false)
    local gameOnly = texts(F04.labelParts(tracker))
    t:ok(gameOnly["00:05"] and not gameOnly["01:15"], "game time only")

    H.setOption(t, "F04_game", false)
    H.setOption(t, "F04_real", true)
    local realOnly = texts(F04.labelParts(tracker))
    t:ok(realOnly["01:15"] and not realOnly["00:05"], "real time only")

    H.setOption(t, "F04_real", false)
    t:equal(F04.labelParts(tracker), nil, "both off: no label")
end)

T.add("F04: the label is kept while the text stays the same", function(t)
    local F04 = SurvivorComforts.internals.F04
    H.setOption(t, "F04_game", true)
    H.setOption(t, "F04_real", true)
    local tracker = { gameMinutes = 5, realSeconds = 75 }
    local first = F04.labelParts(tracker)
    t:ok(F04.labelParts(tracker) == first, "same text: the same parts")
    tracker.realSeconds = 74
    t:ok(F04.labelParts(tracker) ~= first, "new text: new parts")
end)

---------------------------------------------------------------------------
-- F09
---------------------------------------------------------------------------
T.add("F09: minutes, hours and days ago, rounded down", function(t)
    local agoText = SurvivorComforts.internals.F09.agoText
    t:equal(agoText(10), getText("UI_SurvivorComforts_F09_MinutesAgo", "1"), "under a minute")
    t:equal(agoText(59 * 60 + 59), getText("UI_SurvivorComforts_F09_MinutesAgo", "59"))
    t:equal(agoText(3600), getText("UI_SurvivorComforts_F09_HoursAgo", "1"))
    t:equal(agoText(23 * 3600 + 3599), getText("UI_SurvivorComforts_F09_HoursAgo", "23"))
    t:equal(agoText(24 * 3600), getText("UI_SurvivorComforts_F09_DaysAgo", "1"))
    t:equal(agoText(6 * 24 * 3600 + 5), getText("UI_SurvivorComforts_F09_DaysAgo", "6"))
end)

T.add("F09: the server's answer is read newest first, broken entries left out", function(t)
    local players = SurvivorComforts.internals.F09.readPlayers({ players = {
        { name = "old", lastSeen = 100 },
        { name = "new", lastSeen = 300 },
        { name = 5, lastSeen = 200 },
        { name = "noTime" },
        { name = "middle", lastSeen = "200" },
    } })
    t:equal(#players, 3, "three good entries")
    t:equal(players[1].name, "new")
    t:equal(players[2].name, "middle")
    t:equal(players[3].name, "old")
end)

T.add("F09: offline rows leave out online players and those gone 7 days", function(t)
    local F09 = SurvivorComforts.internals.F09
    local now = 1000000
    local rows = F09.offlineRows({ "online" }, {
        { name = "online", lastSeen = now - 10 },
        { name = "recent", lastSeen = now - 120 },
        { name = "week", lastSeen = now - F09.HIDE_AFTER },
        { name = "almostWeek", lastSeen = now - F09.HIDE_AFTER + 1 },
    }, now)
    t:equal(#rows, 2, "recent and almostWeek")
    t:equal(rows[1].name, "recent")
    t:equal(rows[1].ago, F09.agoText(120))
    t:equal(rows[2].name, "almostWeek")
end)

-- Asking again within REQUEST_GAP is held back, and sent once afterwards.
T.add("F09: asks the server at most once every 5 seconds", function(t)
    local F09 = SurvivorComforts.internals.F09
    local asked = 0
    local oldScoreboard, oldSend = scoreboardUpdate, SurvivorComforts.sendCommand
    scoreboardUpdate = function() asked = asked + 1 end
    SurvivorComforts.sendCommand = function() end
    t:cleanup(function()
        scoreboardUpdate = oldScoreboard
        SurvivorComforts.sendCommand = oldSend
    end)

    -- Start after any earlier request has run out.
    local startAt = getTimestampMs() + F09.REQUEST_GAP + 100
    t:waitFor(function() return getTimestampMs() >= startAt end, F09.REQUEST_GAP + 2000, function(t2)
        F09.requestAll()
        t2:equal(asked, 1, "the first request is sent")
        F09.requestAll()
        F09.requestAll()
        t2:equal(asked, 1, "the next ones are held back")
        t2:equal(F09.isRequestPending(), true, "one is waiting")
        local againAt = getTimestampMs() + F09.REQUEST_GAP + 100
        t2:waitFor(function() return getTimestampMs() >= againAt end, F09.REQUEST_GAP + 2000, function(t3)
            F09.requestAll()
            t3:equal(asked, 2, "sent again after the gap")
            t3:equal(F09.isRequestPending(), false)
        end)
    end)
end)
