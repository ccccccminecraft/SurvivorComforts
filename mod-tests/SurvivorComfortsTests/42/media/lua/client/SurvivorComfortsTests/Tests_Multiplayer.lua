-- Multiplayer tests (stage C in docs/testing.md): the answers of the real
-- server. They run in a game connected to the test server
-- (tools\test_server.ps1 -Debug -Test) and are skipped in single player.
-- In debug mode only admins can join, so the player here is always an admin.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/PlayerName"
require "SurvivorComforts/Skills"
require "SurvivorComforts/Admin"

local T = SurvivorComfortsTests
local H = T.helpers

local MODULE = "SurvivorComforts"

local function multiplayerOnly(t)
    if not isClient() then
        t:skip("multiplayer only")
        return false
    end
    return H.player(t) ~= nil
end

-- Collects every answer "command" from the server while the test runs, next
-- to the feature's own listener (Commands.lua keeps one per command).
local function listen(t, command)
    local got = {}
    local function onServerCommand(module, name, args)
        if module == MODULE and name == command then
            table.insert(got, args or {})
        end
    end
    Events.OnServerCommand.Add(onServerCommand)
    t:cleanup(function() Events.OnServerCommand.Remove(onServerCommand) end)
    return got
end

local function myName()
    return SurvivorComforts.playerName(getSpecificPlayer(0))
end

-- The names of the other players online, as this game sees them.
local function otherNames()
    local names = {}
    local players = getOnlinePlayers()
    if not players then return names end
    for i = 0, players:size() - 1 do
        local name = SurvivorComforts.playerName(players:get(i))
        if name and name ~= myName() then table.insert(names, name) end
    end
    return names
end

-- Waits ms, then runs after (for the command limit's one second window).
local function waitMs(t, ms, after)
    local at = getTimestampMs() + ms
    t:waitFor(function() return getTimestampMs() >= at end, ms + 2000, after)
end

T.add("MP Admin: an admin on the server is an admin", function(t)
    if not multiplayerOnly(t) then return end
    t:equal(SurvivorComforts.isAdmin(getSpecificPlayer(0)), true)
end)

T.add("MP F15: the server sends my skills as my game has them", function(t)
    if not multiplayerOnly(t) then return end
    local got = listen(t, "skills")
    local name = myName()
    SurvivorComforts.sendCommand("skillsRequest", { username = name })
    t:waitFor(function() return #got > 0 end, 5000, function(t2)
        local answer = got[1]
        t2:equal(answer.username, name, "username")
        if not t2:ok(type(answer.skills) == "table", "skills sent") then return end
        local mine = SurvivorComforts.collectSkills(getSpecificPlayer(0))
        local count = 0
        for perk, level in pairs(mine) do
            t2:equal(answer.skills[perk], level, perk)
            count = count + 1
        end
        t2:ok(count > 0, "some skills")
    end)
end)

T.add("MP F15: the other players' skills are sent, a name not online gets none", function(t)
    if not multiplayerOnly(t) then return end
    local got = listen(t, "skills")
    local names = otherNames()
    local missing = "NobodyOnline" .. getTimestampMs()
    for _, name in ipairs(names) do
        SurvivorComforts.sendCommand("skillsRequest", { username = name })
    end
    SurvivorComforts.sendCommand("skillsRequest", { username = missing })
    t:waitFor(function() return #got >= #names + 1 end, 5000, function(t2)
        local byName = {}
        for _, answer in ipairs(got) do byName[answer.username] = answer end
        for _, name in ipairs(names) do
            t2:ok(byName[name] and type(byName[name].skills) == "table", name .. " has skills")
        end
        t2:ok(byName[missing] ~= nil, "an answer for the missing name")
        t2:equal(byName[missing] and byName[missing].skills, nil, "no skills for the missing name")
    end)
end)

T.add("MP F09: the server lists me and everyone online, with its time", function(t)
    if not multiplayerOnly(t) then return end
    local got = listen(t, "players")
    SurvivorComforts.sendCommand("playersRequest", {})
    t:waitFor(function() return #got > 0 end, 5000, function(t2)
        local answer = got[1]
        if not t2:ok(type(answer.now) == "number", "server time") then return end
        t2:ok(math.abs(answer.now - getTimestamp()) < 300, "server time is now (same PC)")
        local seen = {}
        for _, entry in pairs(answer.players or {}) do
            seen[entry.name] = entry.lastSeen
        end
        t2:equal(seen[myName()], answer.now, "I was seen just now")
        for _, name in ipairs(otherNames()) do
            t2:equal(seen[name], answer.now, name .. " was seen just now")
        end
    end)
end)

T.add("MP CommandLimit: five requests a second reach the server, the sixth is dropped", function(t)
    if not multiplayerOnly(t) then return end
    local got = listen(t, "players")
    -- Start from an empty window: other tests may have asked within the last second.
    waitMs(t, 1100, function(t2)
        for _ = 1, 6 do
            SurvivorComforts.sendCommand("playersRequest", {})
        end
        waitMs(t2, 2000, function(t3)
            t3:equal(#got, 5, "answers")
        end)
    end)
end)

T.add("MP F06: a shared item comes back from the server to everyone's list", function(t)
    if not multiplayerOnly(t) then return end
    local fullType = "Base.Pencil"
    local name = myName()
    local got = listen(t, "wishlist")
    local function sharedByMe(args)
        for _, entry in pairs(args.items or {}) do
            if entry.fullType == fullType then
                for _, sharer in pairs(entry.sharers or {}) do
                    if sharer.name == name then return true end
                end
            end
        end
        return false
    end
    t:cleanup(function() SurvivorComforts.sendCommand("wishlistUnshare", { fullType = fullType }) end)
    -- The command limit of the F06 group: start from an empty window.
    waitMs(t, 1100, function(t2)
        SurvivorComforts.sendCommand("wishlistShare", { fullType = fullType })
        -- Lists to everyone are sent at most once a second (F06_SharedWishlist.lua).
        t2:waitFor(function()
            for _, args in ipairs(got) do
                if sharedByMe(args) then return true end
            end
            return false
        end, 5000)
    end)
end)
