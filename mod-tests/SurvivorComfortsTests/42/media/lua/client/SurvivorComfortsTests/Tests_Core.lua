-- Tests for the shared parts: options (Core.lua), recipes (Recipes.lua),
-- skills, player names, the admin check, server commands, the command limit.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/Core"
require "SurvivorComforts/Recipes"
require "SurvivorComforts/RecipeIndex"
require "SurvivorComforts/Commands"
require "SurvivorComforts/Skills"
require "SurvivorComforts/PlayerName"
require "SurvivorComforts/Admin"

local T = SurvivorComfortsTests
local H = T.helpers

local FEATURES = { "F02", "F03", "F04", "F06", "F07", "F08", "F09", "F10", "F12", "F13", "F14", "F15", "F16" }

---------------------------------------------------------------------------
-- A: no world needed
---------------------------------------------------------------------------
T.add("Core: every feature has its options", function(t)
    for _, id in ipairs(FEATURES) do
        t:ok(SurvivorComforts.features[id], id .. " is registered")
        t:ok(SurvivorComforts.options:getOption(id .. "_enabled"), id .. " has an enable tick box")
    end
end)

-- Only the path without an error: in debug mode the game stops on every Lua
-- error, even one caught by pcall, and shows its error screen.
T.add("Core: safeCall passes the arguments and the result", function(t)
    local ok, value = SurvivorComforts.safeCall("Test", function(a, b) return a + b end, 2, 3)
    t:equal(ok, true)
    t:equal(value, 5)
end)

-- A recipe that makes planks, found with forEachRecipeItem itself.
local function plankRecipe()
    local recipes = ScriptManager.instance:getAllCraftRecipes()
    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i)
        local makesPlank = SurvivorComforts.forEachRecipeItem(recipe, "outputs", function(item)
            return item:getFullName() == "Base.Plank"
        end)
        if makesPlank then return recipe end
    end
    return nil
end

T.add("Recipes: forEachRecipeItem goes through inputs and outputs and can stop", function(t)
    local recipe = plankRecipe()
    if not t:ok(recipe, "a recipe makes Base.Plank") then return end
    local inputs = 0
    SurvivorComforts.forEachRecipeItem(recipe, "inputs", function() inputs = inputs + 1 end)
    t:ok(inputs > 0, "the plank recipe has item inputs")
    local seen = 0
    local stopped = SurvivorComforts.forEachRecipeItem(recipe, "inputs", function()
        seen = seen + 1
        return true
    end)
    t:equal(stopped, true, "returns true when fn does")
    t:equal(seen, 1, "stops at the first true")
end)

T.add("Recipes: hasRecipe", function(t)
    t:equal(SurvivorComforts.hasRecipe("Base.Plank"), true, "planks can be made")
    t:equal(SurvivorComforts.hasRecipe("Base.NoSuchItemForTests"), false, "an unknown item")
end)

---------------------------------------------------------------------------
-- B: a game in single player
---------------------------------------------------------------------------
T.add("Skills: collectSkills has every skill at the player's level", function(t)
    local player = H.player(t)
    local skills = SurvivorComforts.collectSkills(player)
    local count = 0
    SurvivorComforts.forEachSkill(function(perkType, perk)
        count = count + 1
        t:equal(skills[perk:getId()], player:getPerkLevel(perkType), perk:getId())
    end)
    t:ok(count > 10, "many skills")
end)

T.add("PlayerName: the username, or else the display name", function(t)
    local player = H.player(t)
    local username = player:getUsername()
    local expected = (username and username ~= "") and username or player:getDisplayName()
    t:equal(SurvivorComforts.playerName(player), expected)
    t:equal(SurvivorComforts.playerName(H.fakePlayer("someone")), "someone")
end)

T.add("Admin: everyone is admin in single player", function(t)
    if isClient() then return t:skip("single player only") end
    t:equal(SurvivorComforts.isAdmin(H.player(t)), true)
end)

-- Single player passes client commands to the server's Lua, and the answer
-- comes straight back (ServerCommands.lua).
local pong = nil
local setUp = false
local function setUpPing()
    if setUp then return end
    setUp = true
    SurvivorComfortsServer.onCommand("Tests", "testPing", function(player, args)
        SurvivorComfortsServer.send(player, "testPong", { value = args.value })
    end)
    SurvivorComforts.onServerCommand("Tests", "testPong", function(args) pong = args.value end)
end

T.add("Commands: a command reaches the server side and the answer comes back", function(t)
    if isClient() then return t:skip("single player only (the test command is not on a real server)") end
    H.player(t)
    setUpPing()
    pong = nil
    SurvivorComforts.sendCommand("testPing", { value = 42 })
    t:waitFor(function() return pong ~= nil end, 3000, function(t2)
        t2:equal(pong, 42)
    end)
end)

T.add("CommandLimit: five a second, then the rest are dropped", function(t)
    if isClient() then return t:skip("single player only (the limit runs on the server)") end
    local player = H.fakePlayer("limitTester" .. getTimestampMs())
    for i = 1, 5 do
        t:equal(SurvivorComfortsServer.allowCommand(player, "Tests"), true, "command " .. i)
    end
    t:equal(SurvivorComfortsServer.allowCommand(player, "Tests"), false, "command 6")
    local resumeAt = getTimestampMs() + 1100
    t:waitFor(function() return getTimestampMs() >= resumeAt end, 3000, function(t2)
        t2:equal(SurvivorComfortsServer.allowCommand(player, "Tests"), true, "after a second")
    end)
end)
