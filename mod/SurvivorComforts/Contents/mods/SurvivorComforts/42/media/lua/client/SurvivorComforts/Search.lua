-- Shared search rules (F14 crafting and building windows, F02 inventory
-- search).
--
-- A search text is split into words; a name matches when it has every word.
-- Upper and lower case, and hiragana and katakana, are not told apart. Names
-- are matched by the current language's name and, while "search by English
-- name too" (F14's option) is on and the game is not in English, also by the
-- English name (EnglishNames.lua, built by tools/make_english_names.ps1) and
-- the internal name split into words (for recipes and items newer than that
-- table).
--
-- The game's Lua (Kahlua) gets Japanese wrong in two ways (found by the author
-- of Inventory Search, whose code F02 is based on): Japanese written straight
-- into the source is broken when it is loaded, and the string functions that
-- take a pattern (gsub, find, match, gmatch) go wrong on text with Japanese.
-- So Japanese characters are made from their codes with string.char (one
-- character is one UTF-16 unit in Kahlua), and text that may hold Japanese is
-- read one character at a time with string.sub.

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

-- Hiragana -> katakana (katakana is hiragana + 0x60): U+3041..U+3096 and
-- U+309D..U+309E (the repeat marks).
local KANA = {}
for _, range in ipairs({ { 0x3041, 0x3096 }, { 0x309D, 0x309E } }) do
    for code = range[1], range[2] do
        KANA[string.char(code)] = string.char(code + 0x60)
    end
end
local SPACES = { [" "] = true, ["\t"] = true, [string.char(0x3000)] = true } -- with the full-width space

-- Names repeat a lot, so each text is worked out once.
local normalized = {}

-- Lower case, and hiragana as katakana.
function search.normalize(text)
    if text == nil then return "" end
    local cached = normalized[text]
    if cached then return cached end
    local lower = string.lower(text)
    local chars = {}
    for i = 1, #lower do
        local c = string.sub(lower, i, i)
        chars[i] = KANA[c] or c
    end
    local result = table.concat(chars)
    normalized[text] = result
    return result
end

function search.hasLatin(text)
    if type(text) ~= "string" then return false end
    for i = 1, #text do
        local b = string.byte(text, i)
        if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then return true end
    end
    return false
end

-- "Saw Logs  plank" -> { "saw", "logs", "plank" }, or nil for an empty text.
function search.parse(text)
    if type(text) ~= "string" then return nil end
    text = search.normalize(text)
    local words = {}
    local start = nil
    for i = 1, #text + 1 do
        local c = i <= #text and string.sub(text, i, i) or " "
        if SPACES[c] then
            if start then
                table.insert(words, string.sub(text, start, i - 1))
                start = nil
            end
        elseif not start then
            start = i
        end
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

-- English names do not change while playing, so each is built once per kind
-- of item or recipe. The current language's name is kept by its text instead
-- (search.normalize): in the inventory, items of one kind can have different
-- names (a named bag, for example).
local englishParts = { recipes = {}, items = {} }

-- english = search.useEnglish(). One search compares thousands of names, so
-- callers check it once per search and pass it; nil checks it here.
local function nameText(kind, key, localName, english)
    local loc = search.normalize(localName or "")
    if english == nil then english = search.useEnglish() end
    if not english then return loc end
    local eng = englishParts[kind][key]
    if not eng then
        eng = string.lower(englishTable(kind)[key] or "") .. " " .. splitId(key)
        englishParts[kind][key] = eng
    end
    return eng .. " " .. loc
end

-- fullType = "Base.Nails"; localName = the name in the current language
-- (Item:getDisplayName() or InventoryItem:getName()).
function search.itemText(fullType, localName, english)
    return nameText("items", fullType, localName, english)
end

-- recipe = a CraftRecipe script.
function search.recipeText(recipe, english)
    return nameText("recipes", recipe:getName(), recipe:getTranslationName(), english)
end
