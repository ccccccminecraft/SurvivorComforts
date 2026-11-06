-- Tests for F17 (the best at each skill): the best worked out from the
-- server's answer, without a world, and the skills in the game's order.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/Skills"
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
