-- Going through the skills, for F15 (members' skills) on clients and on the
-- server alike.
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
