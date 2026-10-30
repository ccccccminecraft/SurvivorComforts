-- F09: remembers when each player was last online and sends the player list
-- to anyone who asks.
--
-- There is no Lua event for players joining or leaving, so every in-game
-- minute the time is written for everyone online; the last time written is
-- when a player left. Times are real time (Unix seconds) from the server's
-- clock, kept in the world's Global ModData. If the mod is removed, the data
-- just stays unused.
--
-- Multiplayer only: a hosted game runs its own server process, so this works
-- the same there as on a dedicated server. Nothing is recorded in single
-- player.

if not isServer() then return end

local MODULE = "SurvivorComforts"
local DATA_KEY = "SurvivorComforts_PlayerList"
local WRITE_INTERVAL = 30          -- seconds between writes
local FORGET_AFTER = 30 * 24 * 3600 -- players not seen for this long are dropped

local lastWrite = 0

-- { lastSeen = { [username] = unix seconds } }
local function getData()
    local data = ModData.getOrCreate(DATA_KEY)
    data.lastSeen = data.lastSeen or {}
    return data
end

local function playerName(player)
    local name = player:getUsername()
    if not name or name == "" then
        name = player:getDisplayName()
    end
    return name
end

local function onlineNames()
    local names = {}
    local players = getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local name = playerName(players:get(i))
            if name then names[name] = true end
        end
    end
    return names
end

local function record(now)
    local lastSeen = getData().lastSeen
    for name in pairs(onlineNames()) do
        lastSeen[name] = now
    end
    for name, time in pairs(lastSeen) do
        if now - time > FORGET_AFTER then
            lastSeen[name] = nil
        end
    end
    lastWrite = now
end

local function onEveryOneMinute()
    local now = getTimestamp()
    if now - lastWrite < WRITE_INTERVAL then return end
    local ok, err = pcall(record, now)
    if not ok then
        print("[SurvivorComforts] F09 server: record failed: " .. tostring(err))
    end
end

-- players = { { name = username, lastSeen = seconds }, ... } for everyone recorded.
-- Who is online now the client takes from the vanilla user list, and leaves
-- those out; it also sorts the list (order is lost on the way).
local function listArgs()
    local now = getTimestamp()
    record(now)
    local players = {}
    for name, time in pairs(getData().lastSeen) do
        table.insert(players, { name = name, lastSeen = time })
    end
    return { now = now, players = players }
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or command ~= "playersRequest" or not player then return end
    local ok, err = pcall(function()
        sendServerCommand(player, MODULE, "players", listArgs())
    end)
    if not ok then
        print("[SurvivorComforts] F09 server: " .. command .. " failed: " .. tostring(err))
    end
end

Events.EveryOneMinute.Add(onEveryOneMinute)
Events.OnClientCommand.Add(onClientCommand)
