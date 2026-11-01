-- Talking to the clients (F06, F09); the clients' part is
-- client/SurvivorComforts/Commands.lua.
--
--   SurvivorComfortsServer.onCommand("F09", "playersRequest", function(player, args) ... end)
--   SurvivorComfortsServer.send(player, "players", args)  -- player nil: everyone
--
-- Each command goes through the limit of the feature's group
-- (CommandLimit.lua) before it reaches the feature, and errors are logged.

-- Only on the server (or in single player), never on a multiplayer client.
if isClient() then return end

require "SurvivorComforts/CommandLimit"

SurvivorComfortsServer = SurvivorComfortsServer or {}

local MODULE = "SurvivorComforts" -- the same as in the clients' Commands.lua

-- [command] = { featureId, fn }
local handlers = {}

function SurvivorComfortsServer.onCommand(featureId, command, fn)
    handlers[command] = { featureId = featureId, fn = fn }
end

-- In single player sendServerCommand does nothing (only a dedicated or
-- hosting server sends it), so the answer is handed to the client side
-- directly; both run in the same Lua there.
function SurvivorComfortsServer.send(player, command, args)
    if not isServer() then
        triggerEvent("OnServerCommand", MODULE, command, args)
    elseif player then
        sendServerCommand(player, MODULE, command, args)
    else
        sendServerCommand(MODULE, command, args)
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE then return end
    local handler = handlers[command]
    if not handler or not player then return end
    if not SurvivorComfortsServer.allowCommand(player, handler.featureId) then return end
    local ok, err = pcall(handler.fn, player, args)
    if not ok then
        print("[SurvivorComforts] " .. handler.featureId .. " server: " .. command .. " failed: " .. tostring(err))
    end
end

Events.OnClientCommand.Add(onClientCommand)
