-- Tests for F06 (wishlist): my list, the highlight colours, and the shared
-- list's server side. In single player the server's Lua runs in the same
-- game, so its handlers are called directly, with stand-in players.
-- Everything is put back afterwards: my list file and the shared list data.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/F06_Wishlist"

local T = SurvivorComfortsTests
local H = T.helpers

local function F06() return SurvivorComforts.internals.F06 end

local function server(t)
    local s = SurvivorComforts.internals.F06Server
    if not s then t:fail("single player only (the server's Lua is not in this game)") end
    return s
end

-- Saves my list and puts it back in the same order after the test.
local function keepMyList(t)
    local f = F06()
    local saved = {}
    for _, fullType in ipairs(f.getList().order) do table.insert(saved, fullType) end
    t:cleanup(function()
        f.removeFromFile(f.getList().order)
        f.addToFile(saved)
    end)
end

-- Saves the shared list data and puts it back (and sends it out) after the test.
local function keepSharedList(t, s)
    local data = s.getData()
    local savedItems, savedOrder = H.copy(data.items), data.nextOrder
    t:cleanup(function()
        local now = s.getData()
        now.items = savedItems
        now.nextOrder = savedOrder
        s.handlers.wishlistRequest(getSpecificPlayer(0), {})
    end)
end

local function sharers(s, fullType)
    local entry = s.getData().items[fullType]
    if not entry then return {} end
    local names = {}
    for name in pairs(entry.sharers) do names[name] = true end
    return names
end

---------------------------------------------------------------------------
-- My list (B)
---------------------------------------------------------------------------
T.add("F06: my list adds once, removes, and is saved to the file", function(t)
    H.player(t)
    local f = F06()
    keepMyList(t)
    f.removeFromFile({ "Base.Hammer" })
    f.add({ "Base.Hammer" })
    f.add({ "Base.Hammer" })
    local count = 0
    for _, fullType in ipairs(f.getList().order) do
        if fullType == "Base.Hammer" then count = count + 1 end
    end
    t:equal(count, 1, "added once")
    t:ok(f.contains("Base.Hammer"), "contains")
    f.remove({ "Base.Hammer" })
    t:ok(not f.contains("Base.Hammer"), "removed")
end)

T.add("F06: my list holds at most 100", function(t)
    H.player(t)
    local f = F06()
    keepMyList(t)
    f.removeFromFile(f.getList().order)
    local types = H.itemTypes(f.MAX_PERSONAL + 5)
    f.add(types)
    t:equal(#f.myOrder(), f.MAX_PERSONAL, "stops at the limit")
    t:equal(f.personalFull(), true, "full")
end)

T.add("F06: colours for my list, the shared list and both", function(t)
    local player = H.player(t)
    local s = server(t)
    local f = F06()
    H.setOption(t, "F06_shared", true)
    keepMyList(t)
    keepSharedList(t, s)
    local mine, theirs, both = "Base.Hammer", "Base.Saw", "Base.Nails"
    f.removeFromFile({ mine, theirs, both })
    f.addToFile({ mine, both })
    local other = H.fakePlayer("colourTester")
    s.handlers.wishlistShare(other, { fullType = theirs })
    s.handlers.wishlistShare(other, { fullType = both })
    -- The list goes out at most once a second; wait for it.
    t:waitFor(function() return f.sharedContains(theirs) and f.sharedContains(both) end, 3000, function(t2)
        local colors = f.getColorMap()
        t2:equal(colors[mine], f.colors.personal, "mine: orange")
        t2:equal(colors[theirs], f.colors.shared, "shared: light blue")
        t2:equal(colors[both], f.colors.both, "both: red")
    end)
end)

T.add("F06: my order and share count follow the lists", function(t)
    local player = H.player(t)
    local s = server(t)
    local f = F06()
    H.setOption(t, "F06_shared", true)
    keepMyList(t)
    keepSharedList(t, s)
    local before = f.sharedByMeCount()
    f.removeFromFile({ "Base.Hammer" })
    f.addToFile({ "Base.Hammer" })
    t:ok(f.contains("Base.Hammer"), "the order is worked out again after adding")
    s.handlers.wishlistShare(player, { fullType = "Base.Hammer" })
    t:waitFor(function() return f.sharedByMe("Base.Hammer") end, 3000, function(t2)
        t2:equal(f.sharedByMeCount(), before + 1, "one more share counted")
    end)
end)

---------------------------------------------------------------------------
-- The shared list on the server side (B in single player)
---------------------------------------------------------------------------
T.add("F06 server: one share per player, unknown items refused", function(t)
    local s = server(t)
    keepSharedList(t, s)
    local a = H.fakePlayer("shareA")
    s.getData().items["Base.Hammer"] = nil
    s.handlers.wishlistShare(a, { fullType = "Base.Hammer" })
    s.handlers.wishlistShare(a, { fullType = "Base.Hammer" })
    t:ok(sharers(s, "Base.Hammer").shareA, "shared")
    s.handlers.wishlistShare(a, { fullType = "Base.NoSuchItemForTests" })
    t:equal(s.getData().items["Base.NoSuchItemForTests"], nil, "unknown item refused")
end)

T.add("F06 server: 30 kinds per player", function(t)
    local s = server(t)
    keepSharedList(t, s)
    s.getData().items = {}
    local a = H.fakePlayer("limitA")
    for _, fullType in ipairs(H.itemTypes(s.MAX_PER_PLAYER + 3)) do
        s.handlers.wishlistShare(a, { fullType = fullType })
    end
    local count = 0
    for _, entry in pairs(s.getData().items) do
        if entry.sharers.limitA then count = count + 1 end
    end
    t:equal(count, s.MAX_PER_PLAYER)
end)

T.add("F06 server: 300 kinds in all", function(t)
    local s = server(t)
    keepSharedList(t, s)
    s.getData().items = {}
    local types = H.itemTypes(s.MAX_ITEMS + 10)
    t:ok(#types > s.MAX_ITEMS, "enough item types")
    local player, perPlayer = 0, 0
    for _, fullType in ipairs(types) do
        if perPlayer == 0 then player = player + 1 end
        s.handlers.wishlistShare(H.fakePlayer("many" .. player), { fullType = fullType })
        perPlayer = (perPlayer + 1) % s.MAX_PER_PLAYER
    end
    local count = 0
    for _ in pairs(s.getData().items) do count = count + 1 end
    t:equal(count, s.MAX_ITEMS)
end)

T.add("F06 server: unsharing takes off only your own share", function(t)
    local s = server(t)
    keepSharedList(t, s)
    local a, b = H.fakePlayer("unshareA"), H.fakePlayer("unshareB")
    s.getData().items["Base.Hammer"] = nil
    s.handlers.wishlistShare(a, { fullType = "Base.Hammer" })
    s.handlers.wishlistShare(b, { fullType = "Base.Hammer" })
    s.handlers.wishlistUnshare(a, { fullType = "Base.Hammer" })
    local names = sharers(s, "Base.Hammer")
    t:ok(not names.unshareA and names.unshareB, "only A's share is gone")
    s.handlers.wishlistUnshare(b, { fullType = "Base.Hammer" })
    t:equal(s.getData().items["Base.Hammer"], nil, "gone when nobody shares it")
end)

T.add("F06 server: an admin takes an item off for everyone", function(t)
    local s = server(t)
    keepSharedList(t, s)
    s.getData().items["Base.Hammer"] = nil
    s.handlers.wishlistShare(H.fakePlayer("adminA"), { fullType = "Base.Hammer" })
    s.handlers.wishlistShare(H.fakePlayer("adminB"), { fullType = "Base.Hammer" })
    -- In single player everyone is admin (Admin.lua).
    s.handlers.wishlistAdminRemove(H.fakePlayer("admin"), { fullType = "Base.Hammer" })
    t:equal(s.getData().items["Base.Hammer"], nil)
end)

T.add("F06 server: old data (one sharer in 'by') becomes a list of sharers", function(t)
    local s = server(t)
    keepSharedList(t, s)
    s.getData().items["Base.Hammer"] = { by = "oldPlayer", order = 7 }
    local entry = s.getData().items["Base.Hammer"]
    t:ok(entry.sharers, "has sharers")
    t:equal(entry.sharers.oldPlayer, 7, "the old sharer keeps the order")
    t:equal(entry.by, nil, "'by' is gone")
end)

-- Joining a server, the request for the shared list at game start may not
-- get through: it is sent again until a list arrives (2026-11-06).
T.add("F06: the shared list is asked for again until it arrives", function(t)
    H.player(t)
    local f = F06()
    -- Afterwards: ask for the real list again (in single player it comes back
    -- from this game's server side).
    t:cleanup(function() SurvivorComforts.sendCommand("wishlistRequest", {}) end)
    f.startAsking()
    local state = f.asking()
    t:equal(state.received, false, "nothing received yet")
    t:equal(state.retrying, true, "asking on each tick")
    f.retryTick()
    state = f.asking()
    t:equal(state.tries, 1, "one try")
    t:ok(state.requestedAt ~= nil, "sent (the player exists)")
    -- A list arrives: no more retries.
    triggerEvent("OnServerCommand", "SurvivorComforts", "wishlist", { items = {} })
    t:equal(f.asking().received, true, "received")
    f.retryTick()
    t:equal(f.asking().retrying, false, "stopped asking")
    t:equal(f.asking().tries, 1, "no more tries")
end)
