-- Tests for the shared search rules (client/SurvivorComforts/Search.lua), used
-- by F02 and F14. Japanese text is made from character codes: the game's Lua
-- breaks Japanese written straight into the source.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/Search"

local T = SurvivorComfortsTests
local search = SurvivorComforts.search

local function chars(...)
    local parts = {}
    for i, code in ipairs({ ... }) do
        parts[i] = string.char(code)
    end
    return table.concat(parts)
end

T.add("Search: parse splits on spaces and lowers the case", function(t)
    local words = search.parse("  Saw  LOGS ")
    t:equal(#words, 2, "word count")
    t:equal(words[1], "saw")
    t:equal(words[2], "logs")
    t:equal(search.parse("   "), nil, "empty text")
end)

T.add("Search: hiragana and katakana are the same", function(t)
    local hasami = chars(0x306F, 0x3055, 0x307F)       -- hasami in hiragana
    local HASAMI = chars(0x30CF, 0x30B5, 0x30DF)       -- hasami in katakana
    local gardening = chars(0x5712, 0x82B8, 0x7528) .. HASAMI
    t:equal(search.normalize(hasami), HASAMI)
    t:ok(search.matches(search.itemText("Base.Scissors", gardening, false), search.parse(hasami)),
        "hiragana finds the katakana name")
    -- The full-width space separates words too.
    t:equal(#search.parse(hasami .. chars(0x3000) .. "saw"), 2, "full-width space")
end)

T.add("Search: English and internal names match only with English on", function(t)
    local words = search.parse("sheet metal")
    t:ok(search.matches(search.itemText("Base.SheetMetal", "x", true), words), "with English")
    t:ok(not search.matches(search.itemText("Base.SheetMetal", "x", false), words), "without English")
end)

-- An item whose English name is not in its internal name, so only the table can find it.
T.add("Search: the English name table is used", function(t)
    local names = SurvivorComforts.englishNames and SurvivorComforts.englishNames.items
    if not t:ok(names, "EnglishNames.lua is loaded") then return end
    local found
    for fullType, english in pairs(names) do
        local word = string.match(string.lower(english), "^(%a%a%a%a+)")
        if word and not string.find(string.lower(fullType), word, 1, true) then
            found = { fullType = fullType, word = word }
            break
        end
    end
    if not t:ok(found, "an item whose English name differs from its internal name") then return end
    local words = search.parse(found.word)
    t:ok(search.matches(search.itemText(found.fullType, "x", true), words), found.fullType .. " by " .. found.word)
    t:ok(not search.matches(search.itemText(found.fullType, "x", false), words), "not without English")
end)

T.add("Search: hasLatin", function(t)
    local hasami = chars(0x306F, 0x3055, 0x307F)
    t:ok(search.hasLatin("plank"), "Latin")
    t:ok(search.hasLatin(hasami .. "a"), "mixed")
    t:ok(not search.hasLatin(hasami), "Japanese only")
    t:ok(not search.hasLatin(""), "empty")
    t:ok(not search.hasLatin("123 !"), "digits and signs")
end)

T.add("Search: useEnglish follows F14 and the game language", function(t)
    T.helpers.setOption(t, "F14_enabled", false)
    t:equal(search.useEnglish(), false, "F14 off")
    T.helpers.setOption(t, "F14_enabled", true)
    local english = Translator.getLanguage():name() == "EN"
    t:equal(search.useEnglish(), not english, "F14 on, language " .. Translator.getLanguage():name())
end)

-- In the inventory, items of one kind can have different names.
T.add("Search: one kind of item, different names", function(t)
    local words = search.parse("blue")
    t:ok(search.matches(search.itemText("Base.Bag_Schoolbag", "Blue bag", false), words), "named bag")
    t:ok(not search.matches(search.itemText("Base.Bag_Schoolbag", "School Bag", false), words), "plain bag")
end)
