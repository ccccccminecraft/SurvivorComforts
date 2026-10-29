-- F06 (shared): keeps the server-wide wishlist and sends it to every player.
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

-- { items = { [fullType] = { by = username, order = n } }, nextOrder = n }
local function getData()
    local data = ModData.getOrCreate(DATA_KEY)
    data.items = data.items or {}
    data.nextOrder = data.nextOrder or 1
    return data
end

local function count(items)
    local n = 0
    for _ in pairs(items) do n = n + 1 end
    return n
end

-- The list as sent to clients; they sort it by order.
local function listArgs()
    local items = {}
    for fullType, entry in pairs(getData().items) do
        table.insert(items, { fullType = fullType, by = entry.by, order = entry.order })
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

local handlers = {}

function handlers.wishlistRequest(player, args)
    sendList(player)
end

function handlers.wishlistAdd(player, args)
    local fullType = args and args.fullType
    if not isValidType(fullType) then return end
    local data = getData()
    if data.items[fullType] or count(data.items) >= MAX_ITEMS then return end
    data.items[fullType] = { by = playerName(player), order = data.nextOrder }
    data.nextOrder = data.nextOrder + 1
    sendToAll()
end

function handlers.wishlistRemove(player, args)
    local fullType = args and args.fullType
    if type(fullType) ~= "string" then return end
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
