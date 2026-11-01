-- Talking to this mod's server side (F06, F09); the server's part is
-- server/SurvivorComforts/ServerCommands.lua.
--
--   SurvivorComforts.sendCommand("playersRequest", {})
--   SurvivorComforts.onServerCommand("F09", "players", function(args) ... end)
--
-- In single player the game passes client commands to the server side
-- locally, and ServerCommands.lua hands the answers back directly.

require "SurvivorComforts/Core"

local MODULE = "SurvivorComforts" -- the same as in ServerCommands.lua

-- [command] = { featureId, fn }
local listeners = {}

-- Sent as the first local player.
function SurvivorComforts.sendCommand(command, args)
    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, MODULE, command, args or {})
    end
end

-- fn(args) is called for every "command" the server sends; errors are logged.
function SurvivorComforts.onServerCommand(featureId, command, fn)
    listeners[command] = { featureId = featureId, fn = fn }
end

local function onServerCommand(module, command, args)
    if module ~= MODULE then return end
    local listener = listeners[command]
    if not listener then return end
    SurvivorComforts.safeCall(listener.featureId, listener.fn, args or {})
end

Events.OnServerCommand.Add(onServerCommand)
