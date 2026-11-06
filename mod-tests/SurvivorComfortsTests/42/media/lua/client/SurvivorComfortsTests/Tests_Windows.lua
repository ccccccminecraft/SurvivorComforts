-- Tests for the windows (Window.lua: F08, F09, F15), the sidebar buttons
-- (Sidebar.lua), the "show recipes" menu line (F12) and the crafting window
-- (F03's back history, F14's English search). Every window opened here is
-- closed again.

require "SurvivorComfortsTests/Runner"
require "SurvivorComfortsTests/Helpers"
require "SurvivorComforts/Window"
require "SurvivorComforts/Recipes"
require "SurvivorComforts/RecipeIndex"
require "SurvivorComforts/Search"

local T = SurvivorComfortsTests
local H = T.helpers

local function windowsOf(t, id)
    local windows = SurvivorComforts.internals.windows and SurvivorComforts.internals.windows[id]
    if not windows then t:fail("no windows for " .. id) end
    return windows
end

local function closeAfter(t, windows)
    t:cleanup(function()
        windows.forEach(function(window) window:close() end)
    end)
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------
T.add("Window: toggle opens and closes (F08)", function(t)
    H.player(t)
    H.setOption(t, "F08_enabled", true)
    local windows = windowsOf(t, "F08")
    closeAfter(t, windows)
    windows.forEach(function(window) window:close() end)
    windows.toggle(0)
    t:equal(windows.isOpen(0), true, "open")
    t:equal(windows.anyOpen(), true, "anyOpen")
    windows.toggle(0)
    t:equal(windows.isOpen(0), false, "closed")
end)

T.add("Window: open keeps an open window open (F08)", function(t)
    H.player(t)
    H.setOption(t, "F08_enabled", true)
    local windows = windowsOf(t, "F08")
    closeAfter(t, windows)
    local first = windows.open(0)
    t:ok(first, "opened")
    t:ok(windows.open(0) == first, "the same window")
    t:equal(windows.isOpen(0), true, "still open")
end)

T.add("Window: nothing opens while the feature is off (F08)", function(t)
    H.player(t)
    local windows = windowsOf(t, "F08")
    closeAfter(t, windows)
    windows.forEach(function(window) window:close() end)
    H.setOption(t, "F08_enabled", false)
    windows.toggle(0)
    t:equal(windows.isOpen(0), false, "toggle")
    t:equal(windows.open(0), nil, "open")
end)

T.add("Window: the multiplayer windows do not open in single player (F09, F15, F17)", function(t)
    if isClient() then return t:fail("single player only") end
    H.player(t)
    for _, id in ipairs({ "F09", "F15", "F17" }) do
        local windows = windowsOf(t, id)
        closeAfter(t, windows)
        t:equal(windows.open(0), nil, id)
    end
end)

---------------------------------------------------------------------------
-- Sidebar
---------------------------------------------------------------------------
local function sidebarButtons(t)
    local sidebar = ISEquippedItem.instance
    if not sidebar or not sidebar.survivorComforts then t:fail("no sidebar with this mod's buttons") end
    return sidebar.survivorComforts.buttons
end

T.add("Sidebar: the buttons are in the order F08, F06, F09, F16, F17", function(t)
    H.player(t)
    local ids = {}
    for _, entry in ipairs(sidebarButtons(t)) do table.insert(ids, entry.def.id) end
    t:equal(table.concat(ids, ","), "F08,F06,F09,F16,F17")
end)

T.add("Sidebar: a button hides when its option is off (F08)", function(t)
    H.player(t)
    H.setOption(t, "F08_enabled", true)
    H.setOption(t, "F08_sidebar", true)
    local button
    for _, entry in ipairs(sidebarButtons(t)) do
        if entry.def.id == "F08" then button = entry.button end
    end
    if not t:ok(button, "the F08 button") then return end
    t:waitFor(function() return button:isVisible() end, 3000, function(t2)
        H.setOption(t2, "F08_sidebar", false)
        t2:waitFor(function() return not button:isVisible() end, 3000)
    end)
end)

---------------------------------------------------------------------------
-- F12: the "show recipes" line in the item menu
---------------------------------------------------------------------------
local function hasShowRecipes(context)
    local text = getText("UI_SurvivorComforts_ShowRecipes")
    for _, option in ipairs(context.options or {}) do
        if option.name == text then return true end
    end
    return false
end

local function menuFor(t, item)
    local context = ISInventoryPaneContextMenu.createMenu(0, true, { item }, 100, 100)
    if not context then t:fail("no menu") end
    t:cleanup(function() context:hideAndChildren() end)
    return context
end

T.add("F12: an item that can be made has \"show recipes\"; one that cannot, has not", function(t)
    local player = H.player(t)
    H.setOption(t, "F12_enabled", true)
    local plank = H.giveItems(t, player, "Base.Plank", 1)[1]
    t:ok(hasShowRecipes(menuFor(t, plank)), "planks")
    local other
    for _, fullType in ipairs(H.itemTypes(400)) do
        if not SurvivorComforts.hasRecipe(fullType) and instanceItem(fullType) then
            other = fullType
            break
        end
    end
    if not t:ok(other, "an item no recipe makes") then return end
    local item = H.giveItems(t, player, other, 1)[1]
    t:ok(not hasShowRecipes(menuFor(t, item)), other)
end)

---------------------------------------------------------------------------
-- The crafting window: F03 (back history) and F14 (English search)
---------------------------------------------------------------------------
local function craftingWindow()
    if not ISEntityUI.IsWindowOpen(0, "HandcraftWindow") then return nil end
    return ISEntityUI.GetWindowInstance(0, "HandcraftWindow")
end

local function closeCraftingAfter(t)
    t:cleanup(function()
        local window = craftingWindow()
        if window then window:close() end
    end)
end

T.add("F03: show recipes twice makes a back step; back goes to it; closing forgets it", function(t)
    H.player(t)
    H.setOption(t, "F03_enabled", true)
    closeCraftingAfter(t)
    SurvivorComforts.showRecipes(0, "Base.Plank")
    t:waitFor(function() return SurvivorComforts.getHandcraftFilterPanel(0) ~= nil end, 5000, function(t2)
        t2:equal(SurvivorComforts.canGoBack(0), false, "nothing to go back to yet")
        SurvivorComforts.showRecipes(0, "Base.Nails")
        t2:equal(SurvivorComforts.canGoBack(0), true, "one step back")
        SurvivorComforts.goBack(0)
        t2:equal(SurvivorComforts.canGoBack(0), false, "back at the start")
        SurvivorComforts.showRecipes(0, "Base.Nails")
        craftingWindow():close()
        t2:waitFor(function() return craftingWindow() == nil end, 3000, function(t3)
            t3:equal(SurvivorComforts.canGoBack(0), false, "the history is forgotten")
        end)
    end)
end)

T.add("F14: an English search in the crafting window keeps the matching recipes", function(t)
    H.player(t)
    H.setOption(t, "F14_enabled", true)
    closeCraftingAfter(t)
    SurvivorComforts.showRecipes(0, "Base.Plank")
    t:waitFor(function() return craftingWindow() ~= nil end, 5000, function(t2)
        local panel = craftingWindow().handCraftPanel
        panel:setRecipeFilter("", nil)
        local all = panel.logic:getRecipeList():getAllRecipes():size()
        panel:setRecipeFilter("plank", "RecipeName")
        local list = panel.logic:getRecipeList():getAllRecipes()
        t2:ok(list:size() > 0, "some recipes are left")
        t2:ok(list:size() < all, "fewer than all")
        local words = SurvivorComforts.search.parse("plank")
        local english = SurvivorComforts.search.useEnglish()
        for i = 0, list:size() - 1 do
            local recipe = list:get(i)
            t2:ok(SurvivorComforts.search.matches(SurvivorComforts.search.recipeText(recipe, english), words),
                "matches: " .. recipe:getName())
        end
        panel:setRecipeFilter("", nil)
    end)
end)
