-- F15: sends the skills of an online player to whoever asks.
--
-- The server keeps every online player's skills up to date, so they are read
-- here instead of being reported by each client, and cannot be faked. Only
-- the asking player gets the answer. Nothing is saved.
--
-- Based on Skill Viewer by itsu07 (MIT License,
-- https://github.com/itsu07/SkillViewer). Multiplayer only, like F09, which
-- the window is opened from.

if not isServer() then return end

-- Each player can ask a few times a second at most (CommandLimit.lua, through ServerCommands.lua).
require "SurvivorComforts/ServerCommands"
require "SurvivorComforts/PlayerName"
require "SurvivorComforts/Skills"

local FEATURE_ID = "F15"

local function findOnline(name)
    local players = getOnlinePlayers()
    if not players then return nil end
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if SurvivorComforts.playerName(player) == name then return player end
    end
    return nil
end

-- args = { username }. The answer is { username, skills = { [perk id] = level } },
-- without skills when that player is not online.
SurvivorComfortsServer.onCommand(FEATURE_ID, "skillsRequest", function(player, args)
    if type(args) ~= "table" or type(args.username) ~= "string" then return end
    local target = findOnline(args.username)
    local skills = target and SurvivorComforts.collectSkills(target) or nil
    SurvivorComfortsServer.send(player, "skills", { username = args.username, skills = skills })
end)
