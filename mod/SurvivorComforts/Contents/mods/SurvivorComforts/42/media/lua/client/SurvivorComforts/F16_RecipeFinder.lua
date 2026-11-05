-- F16: a window to look items up: what makes them and what they are used for,
-- from every crafting and building recipe (RecipeIndex.lua). Based on
-- itsu07's HTML app "PZ レシピ検索"; written again in Lua for the game.
--
-- Top: search box and filter. Left: the items found. Right: back and forward
-- buttons, then the chosen item, one row per line: the recipes that make it
-- (open), and the recipes that use it up or use it as a tool (closed; a
-- click opens one). A material made by a recipe opens with [+] to show how
-- it is made, one step in each time. Clicking an item's name shows that
-- item; back and forward move through the items shown, as in a web browser.
-- What is at hand comes first: the recipes that can be made now, and the
-- items that can stand in for each other that are there in the amount
-- needed (RecipeCanMake.lua, checked again when the inventory changes).
-- A right-click on an item or a recipe opens the vanilla crafting or building
-- window on it, and has the wishlist lines (F06, see CraftMenu.lua).

require "SurvivorComforts/Core"
require "SurvivorComforts/Window"
require "SurvivorComforts/Search"
require "SurvivorComforts/RecipeIndex"
require "SurvivorComforts/RecipeCanMake"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISTickBox"
require "ISUI/ISButton"
require "ISUI/ISContextMenu"
require "Entity/ISEntityUI"

local FEATURE_ID = "F16"
local LAYOUT_NAME = "survivorcomforts.recipefinder"
local MAX_HISTORY = 50
local INDENT = 16
local TITLE_HEIGHT = 56 -- the item's own row at the top of the right side
local RECHECK_GAP = 500   -- ms at least between two "can make now" checks
local SURFACE_GAP = 1000  -- ms between looks for a crafting surface nearby
local DIM_ALPHA = 0.4     -- rows that cannot be made now, with "can make" on
local MAX_DEPTH = 20      -- materials opened one inside another, at most (a stop for mistakes)

local search = SurvivorComforts.search
local recipeIndex = SurvivorComforts.recipeIndex
local recipeCanMake = SurvivorComforts.recipeCanMake

local LINK_COLOR = { r = 0.55, g = 0.9, b = 0.55 }    -- an item name that can be clicked
local TEXT_COLOR = { r = 1, g = 1, b = 1 }
local LABEL_COLOR = { r = 0.6, g = 0.6, b = 0.6 }
local BUILD_COLOR = { r = 0.95, g = 0.75, b = 0.4 }
local CRAFT_COLOR = { r = 0.55, g = 0.75, b = 1 }
local COOK_COLOR = { r = 0.95, g = 0.6, b = 0.6 }
local FIX_COLOR = { r = 0.7, g = 0.85, b = 0.7 }

-- Some recipe that makes the entry can be made now (made: RecipeCanMake.lua).
-- The cooking groups that make the entry (stage 3), without the hidden ones
-- unless showHidden (the option).
local function cookedOf(entry, showHidden)
    return recipeIndex.visibleCooking(entry.cooked or {}, showHidden)
end

local function canMakeNow(entry, made, showHidden)
    if not made then return false end
    for _, recipe in ipairs(entry.made) do
        if made[recipeIndex.recipeKey(recipe)] then return true end
    end
    for _, group in ipairs(cookedOf(entry, showHidden)) do
        if made[group.key] then return true end
    end
    return false
end

-- Some repair of the entry can be done now.
local function canFixNow(entry, made)
    if not made then return false end
    for _, fix in ipairs(entry.fixes or {}) do
        if made[fix.key] then return true end
    end
    return false
end

-- The filter's choices, in the combo box's order. Craft, build and
-- "cannot be made" do not overlap and together are all: items are made only
-- by crafting recipes, buildings only by building recipes. "Craft" and
-- "Build" are the game's own words. Whether it can be made now is another
-- axis: the "can make" tick box, used together with these.
-- Cooking and repair (stage 3) may overlap the others: an item can be
-- crafted and cooked, and repaired too. "Cannot be made" is neither crafted
-- nor cooked. With "can make", "repair" means what can be repaired now
-- (canDo); the others, what can be made now.
local FILTERS = {
    { text = "UI_SurvivorComforts_F16_Filter_All", keep = function(entry) return true end },
    { text = "IGUI_CraftingWindow_Craft", keep = function(entry) return not entry.building and #entry.made > 0 end },
    { text = "IGUI_CraftingWindow_Build", keep = function(entry) return entry.building == true end },
    { text = "UI_SurvivorComforts_F16_Filter_Cook", keep = function(entry, showHidden) return #cookedOf(entry, showHidden) > 0 end },
    { text = "UI_SurvivorComforts_F16_Filter_Repair", keep = function(entry) return #(entry.fixes or {}) > 0 end, canDo = canFixNow },
    { text = "UI_SurvivorComforts_F16_Filter_Uncraftable", keep = function(entry, showHidden)
        return not entry.building and #entry.made == 0 and #cookedOf(entry, showHidden) == 0
    end },
}

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F16_Name",
    tooltip = "UI_SurvivorComforts_F16_Tooltip",
    addOptions = function(options)
        SurvivorComforts.addWindowOptions(options, FEATURE_ID)
        options:addTickBox(FEATURE_ID .. "_dim", getText("UI_SurvivorComforts_F16_Dim"), true, getText("UI_SurvivorComforts_F16_Dim_Tooltip"))
        options:addTickBox(FEATURE_ID .. "_hidden", getText("UI_SurvivorComforts_F16_Hidden"), false, getText("UI_SurvivorComforts_F16_Hidden_Tooltip"))
    end,
})

-- Hidden cooking recipes are shown too (true) or not.
local function hiddenOption()
    return SurvivorComforts.getOptionValue(FEATURE_ID .. "_hidden") == true
end

-- "Can make" on: what cannot be made now is listed dimmed below (true) or hidden.
local function dimOption()
    return SurvivorComforts.getOptionValue(FEATURE_ID .. "_dim") ~= false
end

-- What a search compares: the item's names, or a building's recipe names.
local function entryText(entry, english)
    if entry.building then return search.recipeText(entry.recipe, english) end
    return search.itemText(entry.fullType, entry.name, english)
end

-- The items and buildings in the index that pass the filter and match the
-- search words (all of them for no words), by name. made is the result of
-- the "can make now" check while the "can make" tick box is on (nil: off):
-- what cannot be made now is left out, or, with dim, put after the rest
-- (each part still by name) and returned in the second result,
-- { [entry] = true }, to draw dimmed.
-- showHidden: hidden cooking recipes count too.
local function findItems(index, words, filter, made, dim, showHidden)
    local found, others = {}, {}
    local english = words and search.useEnglish()
    for _, entry in ipairs(index.order) do
        if filter.keep(entry, showHidden) and (not words or search.matches(entryText(entry, english), words)) then
            local canDo = false
            if made then
                if filter.canDo then
                    canDo = filter.canDo(entry, made)
                else
                    canDo = canMakeNow(entry, made, showHidden)
                end
            end
            if not made or canDo then
                table.insert(found, entry)
            elseif dim then
                table.insert(others, entry)
            end
        end
    end
    local dimmed = {}
    for _, entry in ipairs(others) do
        table.insert(found, entry)
        dimmed[entry] = true
    end
    return found, dimmed
end

-- The game's own words, so the window reads like the crafting and building
-- windows in every language: craft, build, what is used up, what is made.
local function kindText(isBuild)
    return "[" .. getText(isBuild and "IGUI_CraftingWindow_Build" or "IGUI_CraftingWindow_Craft") .. "]"
end

---------------------------------------------------------------------------
-- The rows of the right side
---------------------------------------------------------------------------
-- row = { indent, label = text before, texture, text, color,
--         fullType = an item to show on click, toggle = a key to open/close on click,
--         open = (rows that open) whether it is open, title = the item's own row,
--         item = { fullType, name } and recipe = a recipe, for the right-click menu }

local function round(value)
    return math.floor(value * 100 + 0.5) / 100
end

-- nil for a part with no amount (a cooking recipe's bases and ingredients).
local function amountText(part)
    if not part.amount then return nil end
    if part.fluids then return tostring(round(part.amount)) .. "L" end
    local result = "x" .. tostring(part.amount)
    if part.maxAmount and part.maxAmount ~= part.amount then
        result = result .. "-" .. tostring(part.maxAmount)
    end
    return result
end

local function itemName(script)
    return script:getDisplayName() or script:getFullName()
end

local Rows = {}
Rows.__index = Rows

-- current = the item shown (its name is not a link); opened = keys clicked
-- open or closed, against each row's default.
-- dimMade: the "can make now" check while "can make" is on (nil: off); the
-- recipes that cannot be made now are dimmed, with their rows.
-- extra = { made = the last "can make now" check (whatever the tick box),
--           counts = { [fullType] = count at hand }, tools = open tools too,
--           showHidden = hidden cooking recipes too }:
-- what is at hand comes first (see sortRecipes and sortItems).
local function newRows(current, opened, dimMade, extra)
    extra = extra or {}
    return setmetatable({
        list = {}, current = current, opened = opened, dimMade = dimMade,
        made = extra.made or {}, counts = extra.counts or {}, tools = extra.tools == true,
        showHidden = extra.showHidden == true,
    }, Rows)
end

function Rows:add(row)
    if self.dimming then row.dim = true end
    table.insert(self.list, row)
    return row
end

function Rows:isOpen(key, default)
    if self.opened[key] then return not default end
    return default
end

-- The recipes that can be made now first, the rest after, each part in the
-- order given.
function Rows:sortRecipes(recipes)
    local first, rest = {}, {}
    for _, recipe in ipairs(recipes) do
        table.insert(self.made[recipeIndex.recipeKey(recipe)] and first or rest, recipe)
    end
    for _, recipe in ipairs(rest) do
        table.insert(first, recipe)
    end
    return first
end

-- Cooking groups or repairs: those that can be done now first.
function Rows:sortByKey(list)
    local first, rest = {}, {}
    for _, value in ipairs(list) do
        table.insert(self.made[value.key] and first or rest, value)
    end
    for _, value in ipairs(rest) do
        table.insert(first, value)
    end
    return first
end

-- Items that can stand in for each other: those at hand in the amount
-- needed first, then those at hand but too few, then the rest, each part in
-- the game's order.
function Rows:sortItems(items, amount)
    local parts = { {}, {}, {} }
    for _, script in ipairs(items) do
        local count = self.counts[script:getFullName()] or 0
        local part = (count >= math.max(amount or 1, 1)) and 1 or (count > 0 and 2 or 3)
        table.insert(parts[part], script)
    end
    local sorted = parts[1]
    for i = 2, 3 do
        for _, script in ipairs(parts[i]) do
            table.insert(sorted, script)
        end
    end
    return sorted
end

-- node = { key, depth, ancestors } for a material that can be opened to show
-- how it is made (stage 2): not the item shown, not one already above it on
-- the way (it would go round), not deeper than MAX_DEPTH, and only when a
-- crafting recipe makes it.
function Rows:canOpen(fullType, node)
    if not node or fullType == self.current or node.ancestors[fullType] then return false end
    if node.depth >= MAX_DEPTH then return false end
    return #recipeIndex.craftRecipesOf(fullType) > 0
end

function Rows:addItem(script, indent, label, suffix, node)
    local fullType = script:getFullName()
    local isCurrent = fullType == self.current
    local row = self:add({
        indent = indent, label = label, texture = script:getNormalTexture(),
        text = itemName(script) .. (suffix and (" " .. suffix) or ""),
        color = isCurrent and TEXT_COLOR or LINK_COLOR,
        fullType = (not isCurrent) and fullType or nil,
        item = { fullType = fullType, name = itemName(script) },
    })
    if not self:canOpen(fullType, node) then return end
    local key = node.key .. ">" .. fullType
    row.toggle = key
    row.open = self:isOpen(key, false)
    if not row.open then return end
    -- How it is made, one step in.
    local recipes = self:sortRecipes(recipeIndex.craftRecipesOf(fullType))
    local ancestors = {}
    for above in pairs(node.ancestors) do
        ancestors[above] = true
    end
    ancestors[fullType] = true
    for _, recipe in ipairs(recipes) do
        -- With a single way to make it, that way is shown open.
        self:addRecipe(recipe, key .. "/" .. recipeIndex.recipeKey(recipe), #recipes == 1,
            indent + 1, node.depth + 1, ancestors)
    end
end

-- One input, tool or output: a single item, a group of items that can stand
-- in for each other ("hammer and 4 more", opened by a click), or fluids.
-- node: see canOpen (nil: its items are not opened).
function Rows:addPart(part, indent, label, key, node)
    local amount = amountText(part)
    if part.fluids then
        self:add({ indent = indent, label = label, text = table.concat(part.fluids, " / ") .. " " .. amount, color = TEXT_COLOR })
        return
    end
    local items = part.items
    if #items == 0 then return end
    local itemNode = node and { key = key, depth = node.depth, ancestors = node.ancestors }
    if #items == 1 then
        self:addItem(items[1], indent, label, amount, itemNode)
        return
    end
    items = self:sortItems(items, part.amount)
    -- The item being shown is named first when it is one of them.
    local first = items[1]
    for _, script in ipairs(items) do
        if script:getFullName() == self.current then first = script end
    end
    local open = self:isOpen(key, false)
    self:add({
        indent = indent, label = label, texture = first:getNormalTexture(),
        text = getText("UI_SurvivorComforts_F16_Group", itemName(first), tostring(#items)) .. (amount and (" " .. amount) or ""),
        color = TEXT_COLOR, toggle = key, open = open,
    })
    if open then
        for _, script in ipairs(items) do
            self:addItem(script, indent + 1, nil, nil, itemNode)
        end
    end
end

local function conditionsText(info)
    local parts = {}
    for _, skill in ipairs(info.skills) do
        table.insert(parts, getText("UI_SurvivorComforts_F16_Skill", tostring(skill.name), tostring(skill.level)))
    end
    if info.needLearn then table.insert(parts, getText("UI_SurvivorComforts_F16_NeedLearn")) end
    if info.needLight then table.insert(parts, getText("UI_SurvivorComforts_F16_NeedLight")) end
    if info.inHand then
        table.insert(parts, getText("UI_SurvivorComforts_F16_InHand"))
    elseif info.anySurface then
        table.insert(parts, getText("UI_SurvivorComforts_F16_AnySurface"))
    elseif #info.places > 0 then
        table.insert(parts, getText("UI_SurvivorComforts_F16_Places", table.concat(info.places, ", ")))
    end
    return table.concat(parts, " / ")
end

-- A recipe: its name row (a click opens or closes it), then, when open, what
-- it uses up, the tools, what it makes and what it needs. indent and depth:
-- 0 and 1 at the top; a recipe shown under an opened material is one step
-- in and one deeper. ancestors: the items above it on the way (see canOpen).
function Rows:addRecipe(recipe, key, openByDefault, indent, depth, ancestors)
    indent = indent or 0
    depth = depth or 1
    ancestors = ancestors or { [self.current] = true }
    local info = recipeIndex.describe(recipe)
    local open = self:isOpen(key, openByDefault)
    -- Every row of a recipe that cannot be made now is dimmed; a recipe shown
    -- inside it goes by its own.
    local outer = self.dimming
    self.dimming = self.dimMade ~= nil and not self.dimMade[recipeIndex.recipeKey(recipe)]
    local summary = nil
    if not open and info.outputs[1] and info.outputs[1].items and info.outputs[1].items[1] then
        summary = "-> " .. itemName(info.outputs[1].items[1]) .. " " .. amountText(info.outputs[1])
    end
    self:add({
        indent = indent, text = info.name, summary = summary,
        kind = kindText(info.isBuild),
        kindColor = info.isBuild and BUILD_COLOR or CRAFT_COLOR,
        toggle = key, open = open, recipe = recipe,
    })
    if open then
        local node = { depth = depth, ancestors = ancestors }
        for i, part in ipairs(info.consumed) do
            self:addPart(part, indent + 1, getText("IGUI_CraftingWindow_Requires"), key .. ":c" .. i, node)
        end
        for i, part in ipairs(info.tools) do
            self:addPart(part, indent + 1, getText("UI_SurvivorComforts_F16_Part_Tool"), key .. ":t" .. i, self.tools and node or nil)
        end
        for i, part in ipairs(info.outputs) do
            self:addPart(part, indent + 1, getText("IGUI_CraftingWindow_Creates"), key .. ":o" .. i, nil)
        end
        local conditions = conditionsText(info)
        if conditions ~= "" then
            self:add({ indent = indent + 1, label = getText("UI_SurvivorComforts_F16_Part_Needs"), text = conditions, color = TEXT_COLOR })
        end
    end
    self.dimming = outer
end

-- A cooking group (stage 3): its name row, then, when open, the bases, the
-- ingredients that can be added, what it makes and how many can go in.
function Rows:addCook(group, key, openByDefault)
    local open = self:isOpen(key, openByDefault)
    local outer = self.dimming
    self.dimming = self.dimMade ~= nil and not self.dimMade[group.key]
    local summary = nil
    if not open and group.results[1] then
        summary = "-> " .. itemName(group.results[1])
    end
    self:add({
        indent = 0, text = group.name, summary = summary,
        kind = "[" .. getText("UI_SurvivorComforts_F16_Filter_Cook") .. "]", kindColor = COOK_COLOR,
        toggle = key, open = open, cook = group,
    })
    if open then
        self:addPart({ items = group.bases }, 1, getText("UI_SurvivorComforts_F16_Part_Base"), key .. ":b")
        self:addPart({ items = group.items }, 1, getText("IGUI_CraftingWindow_Requires"), key .. ":i")
        self:addPart({ items = group.results }, 1, getText("IGUI_CraftingWindow_Creates"), key .. ":o")
        local most = tostring(group.maxItems or 0)
        if group.minItems and group.minItems ~= group.maxItems then
            most = tostring(group.minItems) .. "-" .. most
        end
        local needs = getText("UI_SurvivorComforts_F16_MaxItems", most)
        if group.cookable then needs = needs .. " / " .. getText("UI_SurvivorComforts_F16_Cookable") end
        self:add({ indent = 1, label = getText("UI_SurvivorComforts_F16_Part_Needs"), text = needs, color = TEXT_COLOR })
    end
    self.dimming = outer
end

-- A repair (stage 3): its name row (the game's name, as it is), then, when
-- open, what it repairs, each fixer (one of them is used) with its number and
-- skills, what every fixer needs, and how much it repairs.
function Rows:addFix(fix, key, openByDefault)
    local open = self:isOpen(key, openByDefault)
    local outer = self.dimming
    self.dimming = self.dimMade ~= nil and not self.dimMade[fix.key]
    local summary = nil
    if not open and fix.required[1] then
        summary = "-> " .. itemName(fix.required[1])
    end
    self:add({
        indent = 0, text = fix.name, summary = summary,
        kind = "[" .. getText("UI_SurvivorComforts_F16_Filter_Repair") .. "]", kindColor = FIX_COLOR,
        toggle = key, open = open, fix = fix,
    })
    if open then
        self:addPart({ items = fix.required }, 1, getText("UI_SurvivorComforts_F16_Part_Repairs"), key .. ":r")
        for _, fixer in ipairs(fix.fixers) do
            local suffix = "x" .. tostring(fixer.count)
            for _, skill in ipairs(fixer.skills) do
                suffix = suffix .. "  " .. getText("UI_SurvivorComforts_F16_Skill", tostring(skill.name), tostring(skill.level))
            end
            self:addItem(fixer.script, 1, getText("UI_SurvivorComforts_F16_Part_Fixer"), suffix)
        end
        if fix.global then
            self:addItem(fix.global.script, 1, getText("UI_SurvivorComforts_F16_Part_Global"), "x" .. tostring(fix.global.count))
        end
        if fix.modifier then
            self:add({ indent = 1, label = getText("UI_SurvivorComforts_F16_Part_Needs"),
                text = getText("UI_SurvivorComforts_F16_Modifier", tostring(round(fix.modifier))), color = TEXT_COLOR })
        end
    end
    self.dimming = outer
end

-- A section of recipes, what can be made now first. Each recipe's key is
-- the section's and the recipe's, so it stays open when the order changes.
function Rows:addSection(title, recipes, key, openByDefault)
    if #recipes == 0 then return end
    self:add({ header = true, text = getText(title, tostring(#recipes)) })
    for _, recipe in ipairs(self:sortRecipes(recipes)) do
        self:addRecipe(recipe, key .. "|" .. recipeIndex.recipeKey(recipe), openByDefault)
    end
end

-- A section of cooking groups or repairs (add: Rows.addCook or Rows.addFix).
function Rows:addSectionOf(title, list, key, openByDefault, add)
    if #list == 0 then return end
    self:add({ header = true, text = getText(title, tostring(#list)) })
    for _, value in ipairs(self:sortByKey(list)) do
        add(self, value, key .. "|" .. value.key, openByDefault)
    end
end

-- Every row for one item of the index (dimMade and extra: see newRows).
local function itemRows(entry, opened, dimMade, extra)
    local rows = newRows(entry.fullType, opened, dimMade, extra)
    -- A building shows its category ("Build") only; its key is not a name to show.
    local sub = entry.building and entry.category
        or (entry.category and (entry.category .. "   " .. entry.fullType) or entry.fullType)
    rows:add({
        title = true, texture = entry.texture, text = entry.name, sub = sub,
        item = { fullType = entry.fullType, name = entry.name },
    })
    -- How it is made: crafting or building recipes, then cooking.
    local cooked = cookedOf(entry, rows.showHidden)
    rows:add({ header = true, text = getText("UI_SurvivorComforts_F16_Made", tostring(#entry.made + #cooked)) })
    if #entry.made + #cooked == 0 then
        rows:add({ indent = 0, text = getText("UI_SurvivorComforts_F16_NotMade"), color = LABEL_COLOR })
    end
    for _, recipe in ipairs(rows:sortRecipes(entry.made)) do
        rows:addRecipe(recipe, "m|" .. recipeIndex.recipeKey(recipe), true)
    end
    for _, group in ipairs(rows:sortByKey(cooked)) do
        rows:addCook(group, "m|" .. group.key, true)
    end
    -- A building is not an item, so it is never used or repaired.
    if entry.building then return rows.list end
    rows:addSectionOf("UI_SurvivorComforts_F16_Fixes", entry.fixes, "f", false, Rows.addFix)
    local cookIn = recipeIndex.visibleCooking(entry.cookIn, rows.showHidden)
    local cookBase = recipeIndex.visibleCooking(entry.cookBase, rows.showHidden)
    rows:addSection("UI_SurvivorComforts_F16_Consumed", entry.consumed, "c", false)
    rows:addSection("UI_SurvivorComforts_F16_Tool", entry.tool, "t", false)
    rows:addSectionOf("UI_SurvivorComforts_F16_CookIn", cookIn, "ci", false, Rows.addCook)
    rows:addSectionOf("UI_SurvivorComforts_F16_CookBase", cookBase, "cb", false, Rows.addCook)
    rows:addSectionOf("UI_SurvivorComforts_F16_FixUse", entry.fixUse, "fu", false, Rows.addFix)
    if #entry.consumed + #entry.tool + #cookIn + #cookBase + #entry.fixUse == 0 then
        rows:add({ header = true, text = getText("UI_SurvivorComforts_F16_Uses") })
        rows:add({ indent = 0, text = getText("UI_SurvivorComforts_F16_NoUse"), color = LABEL_COLOR })
    end
    return rows.list
end

---------------------------------------------------------------------------
-- Lists
---------------------------------------------------------------------------
local function isRowShown(list, y, height)
    return not ((y + list:getYScroll() + height < 0) or (y + list:getYScroll() >= list.height))
end

local function drawHighlight(list, item, y)
    if list.selected == item.index then
        list:drawSelection(0, y, list:getWidth(), list.itemheight - 1)
    elseif list.mouseoverselected == item.index and list:isMouseOver() and not list:isMouseOverScrollBar() then
        list:drawMouseOverHighlight(0, y, list:getWidth(), list.itemheight - 1)
    end
end

-- The items found (left).
SurvivorComforts_RecipeFinderItems = ISScrollingListBox:derive("SurvivorComforts_RecipeFinderItems")

function SurvivorComforts_RecipeFinderItems:doDrawItem(y, item, alt)
    if not isRowShown(self, y, self.itemheight) then return y + self.itemheight end
    drawHighlight(self, item, y)
    local iconSize = self.itemheight - 4
    local texture = item.item.texture
    local alpha = (self.dimmed and self.dimmed[item.item]) and DIM_ALPHA or 1
    if texture then
        self:drawTextureScaledAspect(texture, 4, y + 2, iconSize, iconSize, alpha, 1, 1, 1)
    end
    self:drawText(item.text, iconSize + 10, y + (self.itemheight - self.fontHgt) / 2, 1, 1, 1, alpha, self.font)
    return y + self.itemheight
end

function SurvivorComforts_RecipeFinderItems:render()
    ISScrollingListBox.render(self)
    if #self.items == 0 and self.emptyText then
        self:drawTextCentre(self.emptyText, self.width / 2, 10, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

-- The chosen item (right).
SurvivorComforts_RecipeFinderDetail = ISScrollingListBox:derive("SurvivorComforts_RecipeFinderDetail")

function SurvivorComforts_RecipeFinderDetail:doDrawItem(y, item, alt)
    local h = item.height or self.itemheight
    if not isRowShown(self, y, h) then return y + h end
    local row = item.item
    local textY = y + (h - self.fontHgt) / 2
    if row.title then
        -- A larger icon, the name in a larger font, and the category and type under it.
        local iconSize = h - 8
        if row.texture then
            self:drawTextureScaledAspect(row.texture, 6, y + 4, iconSize, iconSize, 1, 1, 1, 1)
        end
        local x = 6 + iconSize + 10
        local nameHgt = getTextManager():getFontHeight(UIFont.Medium)
        local nameY = y + (h - nameHgt - self.fontHgt - 2) / 2
        self:drawText(row.text, x, nameY, 1, 1, 1, 1, UIFont.Medium)
        self:drawText(row.sub, x, nameY + nameHgt + 2, LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, 1, self.font)
        return y + h
    end
    if row.header then
        self:drawRect(0, y, self:getWidth(), h, 0.3, 0.3, 0.3, 0.3)
        self:drawText(row.text, 6, textY, 1, 1, 1, 1, self.font)
        return y + h
    end
    if (row.fullType or row.toggle) and self.mouseoverselected == item.index and self:isMouseOver() and not self:isMouseOverScrollBar() then
        self:drawMouseOverHighlight(0, y, self:getWidth(), h - 1)
    end
    local a = row.dim and DIM_ALPHA or 1
    local x = 6 + (row.indent or 0) * INDENT
    if row.toggle then
        self:drawText(row.open and "[-]" or "[+]", x, textY, LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, a, self.font)
        x = x + getTextManager():MeasureStringX(self.font, "[+]") + 4
    end
    if row.kind then
        self:drawText(row.kind, x, textY, row.kindColor.r, row.kindColor.g, row.kindColor.b, a, self.font)
        x = x + getTextManager():MeasureStringX(self.font, row.kind) + 6
    end
    if row.label then
        self:drawText(row.label, x, textY, LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, a, self.font)
        x = x + getTextManager():MeasureStringX(self.font, row.label) + 6
    end
    if row.texture then
        local iconSize = h - 4
        self:drawTextureScaledAspect(row.texture, x, y + 2, iconSize, iconSize, a, 1, 1, 1)
        x = x + iconSize + 4
    end
    local color = row.color or TEXT_COLOR
    self:drawText(row.text, x, textY, color.r, color.g, color.b, a, self.font)
    if row.sub or row.summary then
        x = x + getTextManager():MeasureStringX(self.font, row.text) + 8
        self:drawText(row.sub or row.summary, x, textY, LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, a, self.font)
    end
    return y + h
end

-- Where the mouse went down, for a row that both opens ([+]) and links.
function SurvivorComforts_RecipeFinderDetail:onMouseDown(x, y)
    self.downX = x
    return ISScrollingListBox.onMouseDown(self, x, y)
end

-- The right end of a row's [+], in the list.
local function toggleRight(list, row)
    return 6 + (row.indent or 0) * INDENT + getTextManager():MeasureStringX(list.font, "[+]") + 4
end

function SurvivorComforts_RecipeFinderDetail:render()
    ISScrollingListBox.render(self)
    if #self.items == 0 and self.emptyText then
        self:drawTextCentre(self.emptyText, self.width / 2, 10, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
SurvivorComforts_RecipeFinderWindow = SurvivorComforts_Window:derive("SurvivorComforts_RecipeFinderWindow")

local function newList(class, window)
    local list = class:new(0, 0, 100, 100)
    list:initialise()
    list:instantiate()
    list.font = UIFont.Small
    list.fontHgt = getTextManager():getFontHeight(UIFont.Small)
    list.itemheight = math.max(list.fontHgt, 20) + 4
    list.drawBorder = true
    list.window = window
    window:addChild(list)
    return list
end

function SurvivorComforts_RecipeFinderWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local font = UIFont.Small
    local h = getTextManager():getFontHeight(font) + 6
    self.controlHeight = h

    -- Back and forward, above the chosen item on the right.
    local function addButton(text, onClick)
        local button = ISButton:new(0, 0, getTextManager():MeasureStringX(font, text) + 20, h, text, self, onClick)
        button:initialise()
        button:instantiate()
        self:addChild(button)
        return button
    end
    self.backButton = addButton("< " .. getText("UI_SurvivorComforts_F16_Back"), SurvivorComforts_RecipeFinderWindow.onBack)
    self.forwardButton = addButton(getText("UI_SurvivorComforts_F16_Forward") .. " >", SurvivorComforts_RecipeFinderWindow.onForward)

    self.searchBox = ISTextEntryBox:new("", 0, 0, 100, h)
    self.searchBox.font = font
    self.searchBox:initialise()
    self.searchBox:instantiate()
    self.searchBox:setClearButton(true)
    self.searchBox:setPlaceholderText(getText("UI_SurvivorComforts_F16_Placeholder"))
    self.searchBox.onTextChangeFunction = SurvivorComforts_RecipeFinderWindow.onSearchChange
    self.searchBox.target = self
    self:addChild(self.searchBox)

    self.filterCombo = ISComboBox:new(0, 0, 150, h, self, SurvivorComforts_RecipeFinderWindow.onFilterChange)
    self.filterCombo:initialise()
    for _, filter in ipairs(FILTERS) do
        self.filterCombo:addOption(getText(filter.text))
    end
    self.filterCombo.selected = 1
    self:addChild(self.filterCombo)

    -- "Can make": on/off, apart from the filter (another axis).
    local tickHeight = getTextManager():getFontHeight(font)
    self.canMakeBox = ISTickBox:new(0, 0, 100, tickHeight, "", self, SurvivorComforts_RecipeFinderWindow.onCanMakeChange)
    self.canMakeBox:initialise()
    self.canMakeBox:instantiate()
    self.canMakeBox:addOption(getText("UI_SurvivorComforts_F16_CanMake"))
    self.canMakeBox:setWidthToFit()
    self:addChild(self.canMakeBox)

    -- "Open tools too": tools are not opened to how they are made unless on.
    self.toolsBox = ISTickBox:new(0, 0, 100, tickHeight, "", self, SurvivorComforts_RecipeFinderWindow.onToolsChange)
    self.toolsBox:initialise()
    self.toolsBox:instantiate()
    self.toolsBox:addOption(getText("UI_SurvivorComforts_F16_ExpandTools"))
    self.toolsBox:setWidthToFit()
    self:addChild(self.toolsBox)

    self.itemList = newList(SurvivorComforts_RecipeFinderItems, self)
    self.itemList:setOnMouseDownFunction(self, SurvivorComforts_RecipeFinderWindow.onPickItem)
    self.detail = newList(SurvivorComforts_RecipeFinderDetail, self)
    self.detail:setOnMouseDownFunction(self, SurvivorComforts_RecipeFinderWindow.onClickRow)
    self.detail.emptyText = getText("UI_SurvivorComforts_F16_Select")

    self.history = {} -- items to go back to, the previous one last
    self.forward = {} -- items to go forward to, the next one last
    self.opened = {}
    self.openedBy = {} -- [fullType] = what was opened on that item, kept for going back
    self:layout()
end

local function place(child, x, y, width, height)
    if child:getX() ~= x then child:setX(x) end
    if child:getY() ~= y then child:setY(y) end
    if child:getWidth() ~= width then child:setWidth(width) end
    if height and child:getHeight() ~= height then child:setHeight(height) end
end

function SurvivorComforts_RecipeFinderWindow:layout()
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local h = self.controlHeight
    local gap = 6
    local top = th + gap
    local comboWidth = self.filterCombo:getWidth()
    local tickWidth = self.canMakeBox:getWidth()
    local tickX = self.width - tickWidth - gap
    local comboX = tickX - comboWidth - gap * 2
    place(self.searchBox, gap, top, math.max(50, comboX - gap * 2))
    place(self.filterCombo, comboX, top, comboWidth)
    place(self.canMakeBox, tickX, top + math.floor((h - self.canMakeBox:getHeight()) / 2), tickWidth)
    local listTop = top + h + gap
    local listHeight = math.max(20, self.height - listTop - rh)
    local leftWidth = math.max(160, math.floor(self.width * 0.36))
    place(self.itemList, 0, listTop, leftWidth, listHeight)
    -- The right side: the buttons' row, then the chosen item's rows.
    place(self.backButton, leftWidth + gap, listTop, self.backButton:getWidth())
    local forwardX = leftWidth + gap * 2 + self.backButton:getWidth()
    place(self.forwardButton, forwardX, listTop, self.forwardButton:getWidth())
    place(self.toolsBox, forwardX + self.forwardButton:getWidth() + gap * 2,
        listTop + math.floor((h - self.toolsBox:getHeight()) / 2), self.toolsBox:getWidth())
    local detailTop = listTop + h + gap
    place(self.detail, leftWidth, detailTop, self.width - leftWidth, math.max(20, self.height - detailTop - rh))
end

function SurvivorComforts_RecipeFinderWindow:currentFilter()
    return FILTERS[self.filterCombo.selected] or FILTERS[1]
end

function SurvivorComforts_RecipeFinderWindow:isCanMakeOn()
    return self.canMakeBox ~= nil and self.canMakeBox:isSelected(1)
end

function SurvivorComforts_RecipeFinderWindow:isToolsOn()
    return self.toolsBox ~= nil and self.toolsBox:isSelected(1)
end

-- "Can make now": check again when the containers may have changed (the
-- same moments the vanilla windows look again, see RecipeCanMake.lua) or a
-- crafting surface came or went nearby; at most once every RECHECK_GAP.
-- Only while the window is shown (prerender), with the tick box on or not:
-- the right side puts what is at hand first either way.
function SurvivorComforts_RecipeFinderWindow:updateCanMake()
    local now = getTimestampMs()
    local player = getSpecificPlayer(self.playerNum)
    if player and now - (self.surfaceCheckedAt or 0) >= SURFACE_GAP then
        self.surfaceCheckedAt = now
        local surface = recipeCanMake.findSurface(player)
        if surface ~= self.surface then
            self.surface = surface
            recipeCanMake.markDirty(self.playerNum)
        end
    end
    if self.made and not recipeCanMake.isDirty(self.playerNum) then return end
    if self.made and now - (self.checkedAt or 0) < RECHECK_GAP then return end
    self:checkCanMake()
end

local function sameKeys(a, b)
    if not a or not b then return a == b end
    for key in pairs(a) do
        if not b[key] then return false end
    end
    for key in pairs(b) do
        if not a[key] then return false end
    end
    return true
end

-- fresh: new logics (see RecipeCanMake.lua). force: draw both sides again
-- even when nothing changed (the tick box was changed). Otherwise nothing is
-- drawn again when no item came or went, and the left list only when what
-- can be made changed while "can make" is on.
function SurvivorComforts_RecipeFinderWindow:checkCanMake(fresh, force)
    self.checkedAt = getTimestampMs()
    local made, changed = recipeCanMake.check(self.playerNum, fresh)
    if not changed and not force then return end
    local before = self.made
    self.made = made
    if force or (self:isCanMakeOn() and not sameKeys(before, made)) then
        self:refreshResults(true)
    end
    self:refreshDetail()
end

function SurvivorComforts_RecipeFinderWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.itemList then
        SurvivorComforts.safeCall(FEATURE_ID, self.updateCanMake, self)
        -- The dim option changed while the window is open.
        if self:isCanMakeOn() and self.shownDim ~= nil and self.shownDim ~= dimOption() then
            SurvivorComforts.safeCall(FEATURE_ID, self.refreshResults, self, true)
        end
        -- The hidden recipes option changed while the window is open.
        if self.shownHidden ~= nil and self.shownHidden ~= hiddenOption() then
            SurvivorComforts.safeCall(FEATURE_ID, self.refreshResults, self, true)
            SurvivorComforts.safeCall(FEATURE_ID, self.refreshDetail, self)
        end
        self:layout()
        self.backButton:setEnable(#self.history > 0)
        self.forwardButton:setEnable(#self.forward > 0)
    end
end

-- The left list, from the search box, the filter and the "can make" tick
-- box. keepScroll keeps the list where it was (when "can make" was checked
-- again).
function SurvivorComforts_RecipeFinderWindow:refreshResults(keepScroll)
    local list = self.itemList
    if not list then return end
    local scroll = list:getYScroll()
    list:clear()
    local index = recipeIndex.get()
    if not index then
        list.emptyText = getText("UI_SurvivorComforts_F16_Failed")
        return
    end
    local words = search.parse(self.searchBox:getInternalText())
    list:setYScroll(keepScroll and scroll or 0)
    local filter = self:currentFilter()
    local canMakeOn = self:isCanMakeOn()
    -- With no words, everything in the filter is listed.
    list.selected = -1 -- only the item shown on the right is highlighted
    local dim = dimOption()
    self.shownDim = dim
    local showHidden = hiddenOption()
    self.shownHidden = showHidden
    local found, dimmed = findItems(index, words, filter, canMakeOn and (self.made or {}) or nil, dim, showHidden)
    list.dimmed = dimmed
    for _, entry in ipairs(found) do
        list:addItem(entry.name, entry)
        if entry.fullType == self.current then list.selected = #list.items end
    end
    list.emptyText = getText("UI_SurvivorComforts_F16_NotFound")
    if keepScroll then list:setYScroll(scroll) end
end

local function push(list, fullType)
    table.insert(list, fullType)
    if #list > MAX_HISTORY then table.remove(list, 1) end
end

-- Shows one item on the right. how is how it was reached, as in a web browser:
--   "new"     (picked or clicked; the default) the one shown now goes into
--             the back history and the forward history is cleared
--   "back"    the one shown now goes into the forward history
--   "forward" the one shown now goes into the back history
function SurvivorComforts_RecipeFinderWindow:showItem(fullType, how)
    local index = recipeIndex.get()
    local entry = index and index.items[fullType]
    if not entry then return end
    how = how or "new"
    if self.current and self.current ~= fullType then
        if how == "back" then
            push(self.forward, self.current)
        else
            push(self.history, self.current)
        end
        if how == "new" then self.forward = {} end
    end
    self.current = fullType
    self.opened = self.openedBy[fullType] or {}
    self.openedBy[fullType] = self.opened
    self:refreshDetail()
    self.detail:setYScroll(0)
    -- Select it on the left too, when it is in the list.
    local list = self.itemList
    list.selected = -1
    for i, item in ipairs(list.items) do
        if item.item.fullType == fullType then
            list.selected = i
            break
        end
    end
end

function SurvivorComforts_RecipeFinderWindow:refreshDetail()
    local detail = self.detail
    local scroll = detail:getYScroll()
    detail:clear()
    local index = recipeIndex.get()
    local entry = index and self.current and index.items[self.current]
    if not entry then return end
    local dimMade = self:isCanMakeOn() and (self.made or {}) or nil
    local extra = {
        made = self.made or {},
        counts = recipeCanMake.counts(self.playerNum),
        tools = self:isToolsOn(),
        showHidden = hiddenOption(),
    }
    for _, row in ipairs(itemRows(entry, self.opened, dimMade, extra)) do
        local item = detail:addItem(row.text or "", row)
        if row.title then
            detail:setScrollHeight(detail:getScrollHeight() + TITLE_HEIGHT - item.height)
            item.height = TITLE_HEIGHT
        end
    end
    detail:setYScroll(scroll)
end

function SurvivorComforts_RecipeFinderWindow:onSearchChange()
    SurvivorComforts.safeCall(FEATURE_ID, self.refreshResults, self)
end

function SurvivorComforts_RecipeFinderWindow:onFilterChange()
    SurvivorComforts.safeCall(FEATURE_ID, self.refreshResults, self)
end

-- "Can make" is checked again from new each time it is turned on (a recipe
-- learnt, a skill level up meanwhile).
function SurvivorComforts_RecipeFinderWindow:onCanMakeChange(index, selected)
    SurvivorComforts.safeCall(FEATURE_ID, function()
        if selected then
            self:checkCanMake(true, true)
        else
            self:refreshResults()
            self:refreshDetail()
        end
    end)
end

function SurvivorComforts_RecipeFinderWindow:onToolsChange()
    SurvivorComforts.safeCall(FEATURE_ID, self.refreshDetail, self)
end

function SurvivorComforts_RecipeFinderWindow:onPickItem(entry)
    if not entry then return end
    SurvivorComforts.safeCall(FEATURE_ID, self.showItem, self, entry.fullType, "new")
end

function SurvivorComforts_RecipeFinderWindow:onClickRow(row)
    if not row then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local onToggle = row.toggle and (not row.fullType
            or (self.detail.downX or 0) < toggleRight(self.detail, row))
        if row.fullType and not onToggle then
            self:showItem(row.fullType, "new")
        elseif row.toggle then
            self.opened[row.toggle] = not self.opened[row.toggle] or nil
            self:refreshDetail()
        end
    end)
end

---------------------------------------------------------------------------
-- Right-click menu
---------------------------------------------------------------------------
-- The vanilla crafting or building window, with this recipe chosen (the
-- same way the vanilla literature window opens a recipe).
local function openRecipeWindow(playerNum, recipe)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    if recipeIndex.isBuild(recipe) then
        ISEntityUI.OpenBuildWindow(player, nil, "*", false, recipe)
    else
        ISEntityUI.OpenHandcraftWindow(player, nil, "*", false, recipe)
    end
end

local function addRecipeOption(context, playerNum, recipe)
    local text = recipeIndex.isBuild(recipe) and getText("UI_SurvivorComforts_F16_Build") or getText("UI_SurvivorComforts_F16_Craft")
    context:addOption(text, playerNum, function(num)
        SurvivorComforts.safeCall(FEATURE_ID, openRecipeWindow, num, recipe)
    end)
end

-- The lines for a row: { item = { fullType, name } } or { recipe = recipe }.
--   An item: "craft" (the crafting window filtered to the recipes that make
--   it, as F12 does), when a crafting recipe makes it. Items are never the
--   result of building, so they have no "build".
--   A building: "build", opening the building window on its recipe.
--   A recipe: "craft" or "build", opening the vanilla window on it.
-- Then the wishlist lines (F06) for the item, or the recipe's results (not
-- for a building: it is not an item).
local function fillMenu(context, playerNum, row)
    local entries = {}
    local index = recipeIndex.get()
    local entry = row.item and index and index.items[row.item.fullType]
    if entry and entry.building then
        addRecipeOption(context, playerNum, entry.recipe)
    elseif row.recipe then
        local recipe = row.recipe
        addRecipeOption(context, playerNum, recipe)
        local seen = {}
        SurvivorComforts.forEachRecipeItem(recipe, "outputs", function(script)
            local fullType = script:getFullName()
            if not seen[fullType] then
                seen[fullType] = true
                table.insert(entries, { fullType = fullType, name = itemName(script) })
            end
        end)
    elseif row.cook or row.fix then
        -- No vanilla window for cooking or repairs (both are right-click menus).
        for _, script in ipairs(row.cook and row.cook.results or row.fix.required) do
            table.insert(entries, { fullType = script:getFullName(), name = itemName(script) })
        end
    elseif row.item then
        local fullType = row.item.fullType
        if SurvivorComforts.hasRecipe(fullType) then
            context:addOption(getText("UI_SurvivorComforts_F16_Craft"), playerNum, function(num)
                SurvivorComforts.safeCall(FEATURE_ID, SurvivorComforts.showRecipes, num, fullType)
            end)
        end
        table.insert(entries, row.item)
    end
    if #entries > 0 and SurvivorComforts.fillCraftMenu then
        SurvivorComforts.fillCraftMenu(context, playerNum, entries, "finder")
    end
end

function SurvivorComforts_RecipeFinderWindow:showMenu(row)
    if not row or not (row.item or row.recipe or row.cook or row.fix) then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local context = ISContextMenu.get(self.playerNum, getMouseX(), getMouseY())
        fillMenu(context, self.playerNum, row)
        if context:isEmpty() then
            context:hideAndChildren()
            context:setVisible(false)
        end
    end)
end

function SurvivorComforts_RecipeFinderItems:onRightMouseUp(x, y)
    local item = self.items[self:rowAt(x, y)]
    if item then
        local entry = item.item
        self.window:showMenu({ item = { fullType = entry.fullType, name = entry.name } })
    end
    return true
end

function SurvivorComforts_RecipeFinderDetail:onRightMouseUp(x, y)
    local item = self.items[self:rowAt(x, y)]
    if item then self.window:showMenu(item.item) end
    return true
end

function SurvivorComforts_RecipeFinderWindow:onBack()
    local fullType = table.remove(self.history)
    if fullType then
        SurvivorComforts.safeCall(FEATURE_ID, self.showItem, self, fullType, "back")
    end
end

function SurvivorComforts_RecipeFinderWindow:onForward()
    local fullType = table.remove(self.forward)
    if fullType then
        SurvivorComforts.safeCall(FEATURE_ID, self.showItem, self, fullType, "forward")
    end
end

function SurvivorComforts_RecipeFinderWindow:new(x, y, width, height, playerNum)
    -- The first size is large; on a small screen it is cut down to fit.
    width = math.max(480, math.min(width, getCore():getScreenWidth() - x - 20))
    height = math.max(300, math.min(height, getCore():getScreenHeight() - y - 20))
    local o = SurvivorComforts_Window.new(self, x, y, width, height, playerNum, "UI_SurvivorComforts_F16_Title")
    o.minimumWidth = 480
    o.minimumHeight = 300
    return o
end

local windows = SurvivorComforts.addWindow({
    id = FEATURE_ID,
    class = SurvivorComforts_RecipeFinderWindow,
    title = "UI_SurvivorComforts_F16_Title",
    layout = LAYOUT_NAME,
    x = 100, y = 80, width = 1200, height = 800,
    sidebar = { order = 4, icon = "Recipes" },
    onOpen = function(window)
        -- The first open builds the index (once, see RecipeIndex.lua). What
        -- can be made is checked from new on each open (a recipe learnt, a
        -- skill level up while it was closed).
        SurvivorComforts.safeCall(FEATURE_ID, window.checkCanMake, window, true, true)
        window.searchBox:focus()
    end,
})

-- For the tests (Core.lua).
SurvivorComforts.internals.F16 = {
    findItems = findItems,
    itemRows = itemRows,
    newRows = newRows,
    MAX_DEPTH = MAX_DEPTH,
    fillMenu = fillMenu,
    canMakeNow = canMakeNow,
    canFixNow = canFixNow,
    FILTERS = FILTERS,
    windows = windows,
}
