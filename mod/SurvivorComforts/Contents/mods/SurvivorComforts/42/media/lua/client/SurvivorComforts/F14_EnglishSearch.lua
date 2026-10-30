-- F14: search by English name too. The option ("enable") decides whether this
-- mod's searches include English names (see Search.lua, shared with F02's
-- inventory search). This file adds it to the crafting and building windows.
--
-- The game compares the search text with translated names only, so in a
-- Japanese game English finds nothing. When the text has Latin letters (and
-- is not one of vanilla's ! @ $ searches), vanilla is run with an empty
-- filter, so learned-only, favourites and categories still apply, and the
-- result is then cut down to the recipes that match (Search.lua).

require "SurvivorComforts/Core"
require "SurvivorComforts/Search"
require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"
require "Entity/ISUI/BuildRecipe/ISBuildPanel"

local FEATURE_ID = "F14"
local search = SurvivorComforts.search

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F14_Name",
    tooltip = "UI_SurvivorComforts_F14_Tooltip",
})

---------------------------------------------------------------------------
-- Matching a recipe
---------------------------------------------------------------------------
-- Calls fn with each item script of a recipe's inputs ("InputName") or
-- results ("OutputName"); true as soon as fn is.
local function anyItem(recipe, mode, fn)
    if mode == "InputName" then
        local inputs = recipe:getInputs()
        for i = 0, inputs:size() - 1 do
            local input = inputs:get(i)
            if input:getResourceType() == ResourceType.Item then
                local items = input:getPossibleInputItems()
                for j = 0, items:size() - 1 do
                    if fn(items:get(j)) then return true end
                end
            end
        end
    else
        local outputs = recipe:getOutputs()
        for i = 0, outputs:size() - 1 do
            local output = outputs:get(i)
            if output:getResourceType() == ResourceType.Item then
                local items = output:getPossibleResultItems()
                for j = 0, items:size() - 1 do
                    if fn(items:get(j)) then return true end
                end
            end
        end
    end
    return false
end

local function matches(recipe, words, mode)
    if mode == "InputName" or mode == "OutputName" then
        return anyItem(recipe, mode, function(item)
            return search.matches(search.itemText(item:getFullName(), item:getDisplayName()), words)
        end)
    end
    return search.matches(search.recipeText(recipe), words)
end

---------------------------------------------------------------------------
-- Filtering
---------------------------------------------------------------------------
-- The words of the search text, or nil when vanilla should search alone.
-- Vanilla appends "-@-<mode>" to the panel's filter string; it is cut off here.
local function englishWords(panel)
    local text = panel._filterString
    if type(text) ~= "string" or not search.useEnglish() then return nil end
    text = string.gsub(text, "%-@%-.*$", "")
    if not search.hasLatin(text) then return nil end
    local first = string.sub(text, 1, 1)
    if first == "!" or first == "@" or first == "$" then return nil end
    return search.parse(text)
end

-- Runs vanilla's filter with no text. The third argument makes Java filter
-- again even when the text and category are the same as last time (it skips
-- the work otherwise, which would leave the previous narrowed list).
local function filterAll(panel)
    panel.logic:filterRecipeList("", panel._categoryString, true, panel.player)
end

-- Keeps only the matching recipes in vanilla's filtered list.
local function narrow(panel, words)
    local list = panel.logic:getRecipeList()
    if not list then return end
    local all = list:getAllRecipes()
    local keep = ArrayList.new()
    for i = 0, all:size() - 1 do
        local recipe = all:get(i)
        if matches(recipe, words, panel._filterMode) then
            keep:add(recipe)
        end
    end
    list:clear()
    list:addAll(keep)
    local player = panel.player
    local buildCheat = player and player.isBuildCheat and player:isBuildCheat() or false
    list:setInitialExpandedStates(panel.logic, buildCheat)
    panel.survivorComfortsNarrowedCount = keep:size()
end

-- True when vanilla has filtered again since narrow() (the list is no longer
-- the size narrow() left).
local function needsNarrowing(panel)
    local list = panel.logic and panel.logic:getRecipeList()
    return list ~= nil and list:getAllRecipes():size() ~= panel.survivorComfortsNarrowedCount
end

local function hookPanel(class)
    if not class then return end

    local original_filter = class.filterRecipeList
    function class:filterRecipeList()
        local words = englishWords(self)
        if not words then
            -- Leaving an English search: when vanilla's text is the same as
            -- the empty one given last, Java would skip filtering and keep
            -- the narrowed list, so bring the full list back first.
            if self.survivorComfortsNarrowedCount then
                self.survivorComfortsNarrowedCount = nil
                SurvivorComforts.safeCall(FEATURE_ID, filterAll, self)
            end
            return original_filter(self)
        end
        local ok = SurvivorComforts.safeCall(FEATURE_ID, function()
            filterAll(self)
            narrow(self, words)
        end)
        if not ok then
            return original_filter(self)
        end
        -- The list on screen was filled from the event Java sent while
        -- filtering, before narrow(); fill it again from the narrowed list.
        self:onUpdateRecipeList()
        self.recipesPanel:filterRecipeList()
    end

    -- Vanilla filters again inside these when it sorts or swaps the recipe
    -- list (with the empty text given above), which brings the full list
    -- back; cut it down again when that happened.
    for _, name in ipairs({ "sortRecipeList", "refreshRecipeList", "setRecipeList", "setRecipes", "setSeeAllRecipe" }) do
        local original = class[name]
        if original then
            class[name] = function(self, ...)
                local result = original(self, ...)
                if englishWords(self) and needsNarrowing(self) then
                    self:filterRecipeList()
                end
                return result
            end
        end
    end
end

hookPanel(ISHandCraftPanel)
hookPanel(ISBuildPanel)
