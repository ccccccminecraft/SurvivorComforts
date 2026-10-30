-- Limits how many client commands one player can send (F06, F09).
--
-- A modified client could send commands as fast as it likes; each one costs
-- the server work (and for F06, a list sent to everyone). Normal play sends a
-- few at a time, so anything over the limit is dropped.
--
--   if not SurvivorComfortsServer.allowCommand(player, "F06") then return end

if isClient() then return end

SurvivorComfortsServer = SurvivorComfortsServer or {}

local MAX_PER_WINDOW = 5
local WINDOW_MS = 1000

-- [group][username] = { start = ms, count = n }
local windows = {}

local function playerKey(player)
    local name = player:getUsername()
    if not name or name == "" then
        name = player:getDisplayName()
    end
    return name or "?"
end

function SurvivorComfortsServer.allowCommand(player, group)
    local now = getTimestampMs()
    local byPlayer = windows[group]
    if not byPlayer then
        byPlayer = {}
        windows[group] = byPlayer
    end
    local key = playerKey(player)
    local window = byPlayer[key]
    if not window or now - window.start >= WINDOW_MS then
        byPlayer[key] = { start = now, count = 1 }
        return true
    end
    if window.count >= MAX_PER_WINDOW then
        return false
    end
    window.count = window.count + 1
    return true
end
