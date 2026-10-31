-- Who counts as an admin, for every feature (F06, F13), on clients and on
-- the server alike.
--
-- Admins are players who can kick others: with the default roles, admin and
-- moderator. Vanilla's hasAdminTool() also covers gm and observer, who only
-- watch or help; they are not admins here. In single player the only player
-- owns the game.

SurvivorComforts = SurvivorComforts or {}

function SurvivorComforts.isAdmin(player)
    if not isClient() and not isServer() then return true end
    local ok, result = pcall(function()
        return player:getRole():hasCapability(Capability.KickUser)
    end)
    return ok and result == true
end
