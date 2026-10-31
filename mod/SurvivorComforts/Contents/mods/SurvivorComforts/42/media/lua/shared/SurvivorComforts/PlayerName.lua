-- The name a player is known by, for every feature (F06, F09, the command
-- limit), on clients and on the server alike, so a client finds itself in
-- what the server records.
--
-- The username, which stays the same when the character dies and a new one
-- is made; the character's display name when there is none.
-- nil when neither can be read.

SurvivorComforts = SurvivorComforts or {}

function SurvivorComforts.playerName(player)
    local name = player:getUsername()
    if not name or name == "" then
        name = player:getDisplayName()
    end
    return name
end
