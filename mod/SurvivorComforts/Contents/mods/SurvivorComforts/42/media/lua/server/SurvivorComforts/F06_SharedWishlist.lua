-- F06 (shared): keeps the server-wide wishlist and sends it to every player.
--
-- Players share items from their own wishlist. Each item keeps the list of
-- players sharing it; unsharing takes only that player's name off, and the
-- item leaves the shared list when nobody shares it any more. Admins can take
-- an item off for everyone.
--
-- Stored in the world's Global ModData. If the mod is removed, the data just
-- stays unused. Clients ask with sendClientCommand; every change is sent to
-- all players with sendServerCommand. In single player the game passes the
-- client commands on locally, and the list goes back through sendList below.

-- Only on the server (or in single player), never on a multiplayer client.
if isClient() then return end

local MODULE = "SurvivorComforts"
local DATA_KEY = "SurvivorComforts_SharedWishlist"
local MAX_ITEMS = 300
local MAX_TYPE_LENGTH = 128

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

-- In single player sendServerCommand does nothing (only a dedicated or
-- hosting server sends it), so the list is handed to the client side
-- directly; both run in the same Lua there.
local function sendList(player)
    if not isServer() then
        triggerEvent("OnServerCommand", MODULE, "wishlist", listArgs())
    elseif player then
        sendServerCommand(player, MODULE, "wishlist", listArgs())
    else
        sendServerCommand(MODULE, "wishlist", listArgs())
    end
end

local function sendToAll()
    sendList(nil)
end

local function isValidType(fullType)
    return type(fullType) == "string"
        and string.len(fullType) <= MAX_TYPE_LENGTH
        and ScriptManager.instance:getItem(fullType) ~= nil
end

local function playerName(player)
    local name = player:getUsername()
    if not name or name == "" then
        name = player:getDisplayName()
    end
    return name or "?"
end

-- Admins (anyone who can kick players) may take items off for everyone.
-- In single player the only player owns the game.
local function isAdmin(player)
    if not isServer() then return true end
    local ok, result = pcall(function()
        return player:getRole():hasCapability(Capability.KickUser)
    end)
    return ok and result == true
end

local handlers = {}

function handlers.wishlistRequest(player, args)
    sendList(player)
end

function handlers.wishlistShare(player, args)
    local fullType = args and args.fullType
    if not isValidType(fullType) then return end
    local data = getData()
    local entry = data.items[fullType]
    if not entry then
        if count(data.items) >= MAX_ITEMS then return end
        entry = { order = data.nextOrder, sharers = {} }
        data.items[fullType] = entry
    end
    local name = playerName(player)
    if entry.sharers[name] then return end
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
    if type(fullType) ~= "string" or not isAdmin(player) then return end
    local data = getData()
    if not data.items[fullType] then return end
    data.items[fullType] = nil
    sendToAll()
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE then return end
    local handler = handlers[command]
    if not handler or not player then return end
    local ok, err = pcall(handler, player, args)
    if not ok then
        print("[SurvivorComforts] F06 server: " .. command .. " failed: " .. tostring(err))
    end
end

Events.OnClientCommand.Add(onClientCommand)
