-- F06 (shared): keeps the server-wide wishlist and sends it to every player.
--
-- Players share items from their own wishlist. Each item keeps the list of
-- players sharing it; unsharing takes only that player's name off, and the
-- item leaves the shared list when nobody shares it any more. Admins can take
-- an item off for everyone.
--
-- Stored in the world's Global ModData. If the mod is removed, the data just
-- stays unused. Clients ask with commands; every change is sent to all
-- players (ServerCommands.lua, which also covers single player).

-- Safety limits against flooding: each player can share at most
-- MAX_PER_PLAYER kinds, send a few commands a second (CommandLimit.lua), and
-- the list goes to everyone at most once a second; changes in between are
-- sent together.

-- Only on the server (or in single player), never on a multiplayer client.
if isClient() then return end

require "SurvivorComforts/ServerCommands"
require "SurvivorComforts/Admin"
require "SurvivorComforts/PlayerName"

local FEATURE_ID = "F06"
local DATA_KEY = "SurvivorComforts_SharedWishlist"
local MAX_ITEMS = 300
local MAX_PER_PLAYER = 30
local MAX_TYPE_LENGTH = 128
local BROADCAST_INTERVAL_MS = 1000

-- { items = { [fullType] = { order = n, sharers = { [username] = n } } }, nextOrder = n }
-- The numbers keep the order items were first shared and players joined in.
-- Data saved before sharing per player had { by = username, order = n }; it
-- becomes shared by that player.
local function getData()
    local data = ModData.getOrCreate(DATA_KEY)
    data.items = data.items or {}
    data.nextOrder = data.nextOrder or 1
    for _, entry in pairs(data.items) do
        if not entry.sharers then
            entry.sharers = {}
            if entry.by then
                entry.sharers[entry.by] = entry.order or 0
            end
            entry.by = nil
        end
    end
    return data
end

local function count(items)
    local n = 0
    for _ in pairs(items) do n = n + 1 end
    return n
end

-- The list as sent to clients: { items = { { fullType, order, sharers = { { name, order }, ... } }, ... } }.
-- Order is lost on the way, so the client sorts both levels by order.
local function listArgs()
    local items = {}
    for fullType, entry in pairs(getData().items) do
        local sharers = {}
        for name, order in pairs(entry.sharers) do
            table.insert(sharers, { name = name, order = order })
        end
        table.insert(items, { fullType = fullType, order = entry.order, sharers = sharers })
    end
    return { items = items }
end

-- player nil: everyone.
local function sendList(player)
    SurvivorComfortsServer.send(player, "wishlist", listArgs())
end

-- At most one list to everyone per BROADCAST_INTERVAL_MS. A change inside
-- that time is sent by flushBroadcast once it has passed.
local lastBroadcastMs = 0
local broadcastPending = false

local function broadcastNow()
    lastBroadcastMs = getTimestampMs()
    broadcastPending = false
    sendList(nil)
end

local function sendToAll()
    if getTimestampMs() - lastBroadcastMs >= BROADCAST_INTERVAL_MS then
        broadcastNow()
    else
        broadcastPending = true
    end
end

local function flushBroadcast()
    if broadcastPending and getTimestampMs() - lastBroadcastMs >= BROADCAST_INTERVAL_MS then
        local ok, err = pcall(broadcastNow)
        if not ok then
            print("[SurvivorComforts] F06 server: broadcast failed: " .. tostring(err))
        end
    end
end

local function sharedByCount(items, name)
    local n = 0
    for _, entry in pairs(items) do
        if entry.sharers[name] then n = n + 1 end
    end
    return n
end

local function isValidType(fullType)
    return type(fullType) == "string"
        and string.len(fullType) <= MAX_TYPE_LENGTH
        and ScriptManager.instance:getItem(fullType) ~= nil
end

local function playerName(player)
    return SurvivorComforts.playerName(player) or "?"
end

local handlers = {}

function handlers.wishlistRequest(player, args)
    sendList(player)
end

function handlers.wishlistShare(player, args)
    local fullType = args and args.fullType
    if not isValidType(fullType) then return end
    local data = getData()
    local name = playerName(player)
    local entry = data.items[fullType]
    if entry and entry.sharers[name] then return end
    if sharedByCount(data.items, name) >= MAX_PER_PLAYER then return end
    if not entry then
        if count(data.items) >= MAX_ITEMS then return end
        entry = { order = data.nextOrder, sharers = {} }
        data.items[fullType] = entry
    end
    entry.sharers[name] = data.nextOrder
    data.nextOrder = data.nextOrder + 1
    sendToAll()
end

-- Takes off only the sender's share.
function handlers.wishlistUnshare(player, args)
    local fullType = args and args.fullType
    if type(fullType) ~= "string" then return end
    local data = getData()
    local entry = data.items[fullType]
    local name = playerName(player)
    if not entry or not entry.sharers[name] then return end
    entry.sharers[name] = nil
    if count(entry.sharers) == 0 then
        data.items[fullType] = nil
    end
    sendToAll()
end

-- Takes the item off for everyone (admins only).
function handlers.wishlistAdminRemove(player, args)
    local fullType = args and args.fullType
    if type(fullType) ~= "string" or not SurvivorComforts.isAdmin(player) then return end
    local data = getData()
    if not data.items[fullType] then return end
    data.items[fullType] = nil
    sendToAll()
end

for command, handler in pairs(handlers) do
    SurvivorComfortsServer.onCommand(FEATURE_ID, command, handler)
end

-- OnTick sends a held-back list quickly; EveryOneMinute (every few seconds of
-- real time) covers a server that does not run OnTick.
Events.OnTick.Add(flushBroadcast)
Events.EveryOneMinute.Add(flushBroadcast)
