-- Shared search rules (F14 crafting and building windows, and F02 inventory
-- search when it is made).
--
-- A search text is split into lower-case words; a name matches when it has
-- every word. Names are matched by the current language's name and, while
-- "search by English name too" (F14's option) is on and the game is not in
-- English, also by the English name (EnglishNames.lua, built by
-- tools/make_english_names.ps1) and the internal name split into words (for
-- recipes and items newer than that table).

require "SurvivorComforts/Core"
require "SurvivorComforts/EnglishNames"

SurvivorComforts.search = SurvivorComforts.search or {}
local search = SurvivorComforts.search

local ENGLISH_OPTION = "F14"

function search.useEnglish()
    if not SurvivorComforts.isEnabled(ENGLISH_OPTION) then return false end
    -- In an English game the game's own names are already English.
    local ok, language = pcall(function() return Translator.getLanguage():name() end)
    return not (ok and language == "EN")
end

function search.hasLatin(text)
    return type(text) == "string" and string.find(text, "%a") ~= nil
end

-- "Saw Logs  plank" -> { "saw", "logs", "plank" }, or nil for an empty text.
function search.parse(text)
    if type(text) ~= "string" then return nil end
    local words = {}
    for word in string.gmatch(string.lower(text), "%S+") do
        table.insert(words, word)
    end
    return #words > 0 and words or nil
end

function search.matches(text, words)
    for _, word in ipairs(words) do
        if not string.find(text, word, 1, true) then return false end
    end
    return true
end

-- "Base.SheetMetal" / "Saw_Logs" -> "sheet metal" / "saw logs"
local function splitId(id)
    id = string.gsub(id, "^[%w_]+%.", "")
    id = string.gsub(id, "_", " ")
    id = string.gsub(id, "(%l)(%u)", "%1 %2")
    id = string.gsub(id, "(%a)(%d)", "%1 %2")
    id = string.gsub(id, "(%d)(%a)", "%1 %2")
    return string.lower(id)
end

local function englishTable(kind)
    local names = SurvivorComforts.englishNames
    return names and names[kind] or {}
end

-- Names do not change while playing, so each part is built once.
local englishParts = { recipes = {}, items = {} }
local localParts = { recipes = {}, items = {} }

local function nameText(kind, key, localName)
    local loc = localParts[kind][key]
    if not loc then
        loc = string.lower(localName or "")
        localParts[kind][key] = loc
    end
    if not search.useEnglish() then return loc end
    local eng = englishParts[kind][key]
    if not eng then
        eng = string.lower(englishTable(kind)[key] or "") .. " " .. splitId(key)
        englishParts[kind][key] = eng
    end
    return eng .. " " .. loc
end

-- fullType = "Base.Nails"; localName = the name in the current language
-- (Item:getDisplayName() or InventoryItem:getName()).
function search.itemText(fullType, localName)
    return nameText("items", fullType, localName)
end

-- recipe = a CraftRecipe script.
function search.recipeText(recipe)
    return nameText("recipes", recipe:getName(), recipe:getTranslationName())
end
