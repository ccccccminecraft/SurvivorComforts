-- Tests for F17 (the best at each skill, a tab in the F09 player list): the
-- best worked out from the server's answer, without a world, the skills in
-- the game's order, and in multiplayer the tab and the real server's answer.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/Skills"
require "SurvivorComforts/PlayerName"
require "SurvivorComforts/F09_PlayerList"
require "SurvivorComforts/F17_SkillTop"

local T = SurvivorComfortsTests
local H = T.helpers

T.add("F17: the highest level wins, and players at the same level are all shown", function(t)
    local tops = SurvivorComforts.internals.F17.computeTops({
        bob = { Cooking = 3, Fitness = 5 },
        Alice = { Cooking = 7, Fitness = 5 },
        carol = { Cooking = 7, Fitness = 2 },
    })
    t:equal(tops.Cooking.level, 7)
    t:equal(table.concat(tops.Cooking.names, ","), "Alice,carol", "both at 7, sorted without case")
    t:equal(tops.Fitness.level, 5)
    t:equal(table.concat(tops.Fitness.names, ","), "Alice,bob")
end)

T.add("F17: nobody is the best at level 0", function(t)
    local tops = SurvivorComforts.internals.F17.computeTops({
        bob = { Cooking = 0 },
        alice = { Cooking = 0 },
    })
    t:equal(tops.Cooking.level, 0)
    t:equal(#tops.Cooking.names, 0)
end)

T.add("F17: broken entries are left out", function(t)
    local F17 = SurvivorComforts.internals.F17
    local players = {
        good = { Cooking = "4" },
        [5] = { Cooking = 9 },
        noSkills = "x",
        badLevel = { Cooking = "high" },
    }
    local tops = F17.computeTops(players)
    t:equal(tops.Cooking.level, 4, "a level sent as text is read")
    t:equal(table.concat(tops.Cooking.names, ","), "good")
    t:equal(F17.countPlayers(players), 2, "good and badLevel")
    t:equal(F17.countPlayers(nil), 0)
    -- (the game's Lua has no next())
    local empty = true
    for _ in pairs(F17.computeTops(nil)) do empty = false end
    t:ok(empty, "no answer, no tops")
end)

-- The order F15 and F17 share (Skills.lua): the same as the game's skill
-- screen (ISCharacterInfo). The category perks themselves are not passive
-- (only the skills in it are), so this is the order by name in practice.
T.add("Skills: skillGroups has every skill once, in the skill screen's order", function(t)
    local groups = SurvivorComforts.skillGroups()
    if not t:ok(#groups > 1, "several categories") then return end
    local function before(a, b)
        if a:isPassiv() and not b:isPassiv() then return true end
        if b:isPassiv() and not a:isPassiv() then return false end
        return not string.sort(a:getName(), b:getName())
    end
    for i = 2, #groups do
        t:ok(not before(groups[i].perk, groups[i - 1].perk), groups[i].name .. " after " .. groups[i - 1].name)
    end
    local seen, count = {}, 0
    for _, group in ipairs(groups) do
        for _, row in ipairs(group.rows) do
            t:ok(not seen[row.perk:getId()], row.perk:getId() .. " once")
            seen[row.perk:getId()] = true
            count = count + 1
        end
    end
    local all = 0
    SurvivorComforts.forEachSkill(function() all = all + 1 end)
    t:equal(count, all, "every skill")
    local onlyCooking = SurvivorComforts.skillGroups(function(perk) return perk:getId() == "Cooking" end)
    t:equal(#onlyCooking, 1, "include leaves the others out")
end)

-- Multiplayer (stage C): the real server's answer. In single player the test
-- is skipped (t:skip comes with the multiplayer tests; before that it just
-- ends without checks).
T.add("MP F17: the server sends the skills of everyone online, mine as my game has them", function(t)
    if not isClient() then
        if t.skip then return t:skip("multiplayer only") end
        return
    end
    local player = H.player(t)
    if not player then return end
    local got = {}
    local function onServerCommand(module, command, args)
        if module == "SurvivorComforts" and command == "skillTop" then table.insert(got, args or {}) end
    end
    Events.OnServerCommand.Add(onServerCommand)
    t:cleanup(function() Events.OnServerCommand.Remove(onServerCommand) end)
    SurvivorComforts.sendCommand("skillTopRequest", {})
    t:waitFor(function() return #got > 0 end, 5000, function(t2)
        local players = got[1].players
        if not t2:ok(type(players) == "table", "players sent") then return end
        local online = getOnlinePlayers()
        t2:equal(SurvivorComforts.internals.F17.countPlayers(players), online and online:size() or 0, "everyone online")
        local mine = players[SurvivorComforts.playerName(player)]
        if not t2:ok(type(mine) == "table", "my skills sent") then return end
        for perk, level in pairs(SurvivorComforts.collectSkills(player)) do
            t2:equal(mine[perk], level, perk)
        end
    end)
end)

T.add("F17: no tab in single player, even while F17 is on", function(t)
    if isClient() then
        if t.skip then return t:skip("single player only") end
        return
    end
    H.setOption(t, "F17_enabled", true)
    t:equal(SurvivorComforts.skillTop.isAvailable(), false)
end)

-- The tab in the player list: there while F17 is on, filled from the server,
-- and gone (the players' list straight in the window again) when it is off.
T.add("MP F17: the player list has the tab, which shows the best at each skill", function(t)
    if not isClient() then
        if t.skip then return t:skip("multiplayer only") end
        return
    end
    if not H.player(t) then return end
    H.setOption(t, "F17_enabled", true)
    local windows = SurvivorComforts.internals.windows.F09
    t:cleanup(function() windows.forEach(function(window) window:close() end) end)
    local window = windows.open(0)
    if not t:ok(window and window.tabs, "the window has tabs") then return end
    t:equal(#window.tabs.viewList, 2, "two tabs")
    t:equal(window.tabs:getActiveView(), window.list, "the players first")
    window.tabs:activateView(getText("UI_SurvivorComforts_F17_Tab"))
    t:equal(window.tabs:getActiveView(), window.skillTop, "the best at each skill")
    t:waitFor(function() return #window.skillTop.items > 0 end, 10000, function(t2)
        t2:equal(window.skillTop.message, nil, "no message")
        t2:ok(window.skillTop.items[1].item.header, "a category first")
        H.setOption(t2, "F17_enabled", false)
        t2:waitFor(function() return window.tabs == nil end, 5000, function(t3)
            t3:equal(window.list.parent, window, "the players' list straight in the window")
            t3:ok(window.list:isVisible(), "and shown")
            t3:equal(window.skillTop, nil, "no list for F17")
        end)
    end)
end)
