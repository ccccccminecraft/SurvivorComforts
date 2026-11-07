-- F17: sends the skills of every online player to whoever asks, so the
-- client can show the best at each skill.
--
-- Read on the server like F15, so they cannot be faked. Only the asking
-- player gets the answer. Nothing is saved, so only players online now are
-- counted. Multiplayer only, like F09 and F15.

if not isServer() then return end

-- Each player can ask a few times a second at most (CommandLimit.lua, through ServerCommands.lua).
require "SurvivorComforts/ServerCommands"
require "SurvivorComforts/PlayerName"
require "SurvivorComforts/Skills"

local FEATURE_ID = "F17"

-- The answer is { players = { [username] = { [perk id] = level } } }.
SurvivorComfortsServer.onCommand(FEATURE_ID, "skillTopRequest", function(player, args)
    local players = {}
    local online = getOnlinePlayers()
    if online then
        for i = 0, online:size() - 1 do
            local target = online:get(i)
            local name = SurvivorComforts.playerName(target)
            if name then
                players[name] = SurvivorComforts.collectSkills(target)
            end
        end
    end
    SurvivorComfortsServer.send(player, "skillTop", { players = players })
end)
