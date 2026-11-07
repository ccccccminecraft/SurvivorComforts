-- Going through the skills, for F15 (members' skills) and F17 (the best at
-- each skill), on clients and on the server alike.
--
-- Based on Skill Viewer by itsu07 (MIT License,
-- https://github.com/itsu07/SkillViewer).

SurvivorComforts = SurvivorComforts or {}

-- Calls fn(perkType, perk) for every skill, leaving out the categories
-- (perks whose parent is None).
function SurvivorComforts.forEachSkill(fn)
    for i = 0, Perks.getMaxIndex() - 1 do
        local perkType = Perks.fromIndex(i)
        local perk = PerkFactory.getPerk(perkType)
        if perk and perk:getParent() ~= Perks.None then
            fn(perkType, perk)
        end
    end
end

-- { [perk id] = level } for a character.
function SurvivorComforts.collectSkills(character)
    local levels = {}
    SurvivorComforts.forEachSkill(function(perkType, perk)
        levels[perk:getId()] = character:getPerkLevel(perkType)
    end)
    return levels
end

-- Same order as the game's skill screen (ISCharacterInfo): the passive
-- category first, then categories by name, and skills by name in each.
local function sortCategories(a, b)
    if a.perk:isPassiv() and not b.perk:isPassiv() then return true end
    if b.perk:isPassiv() and not a.perk:isPassiv() then return false end
    return not string.sort(a.name, b.name)
end

local function sortSkills(a, b)
    return a.name < b.name
end

-- The skills grouped by category, in the order above (F15, F17):
-- { { name = category name, rows = { { perk, name }, ... } }, ... }.
-- include(perk), when given, leaves out the skills it says false to.
function SurvivorComforts.skillGroups(include)
    local groups, order = {}, {}
    SurvivorComforts.forEachSkill(function(_, perk)
        if include and not include(perk) then return end
        local key = perk:getParent():getId()
        if not groups[key] then
            local parentPerk = PerkFactory.getPerk(perk:getParent())
            groups[key] = { perk = parentPerk, name = parentPerk:getName(), rows = {} }
            table.insert(order, groups[key])
        end
        table.insert(groups[key].rows, { perk = perk, name = perk:getName() })
    end)
    table.sort(order, sortCategories)
    for _, group in ipairs(order) do
        table.sort(group.rows, sortSkills)
    end
    return order
end
