-- Feature windows opened from a key or a sidebar button (F06, F08, F09).
--
-- Each local player gets their own window, made the first time it is opened.
-- Closing hides it and takes it off the screen; the first player's position
-- and size are saved like vanilla windows (ISLayoutManager).
--
--   SurvivorComforts_PlayerListWindow = SurvivorComforts_Window:derive("SurvivorComforts_PlayerListWindow")
--   function SurvivorComforts_PlayerListWindow:new(x, y, width, height, playerNum)
--       local o = SurvivorComforts_Window.new(self, x, y, width, height, playerNum, "UI_..._Title")
--       ...
--   end
--
--   local windows = SurvivorComforts.addWindow({
--       id = "F09",                       -- the feature; nothing opens while it is off
--       class = SurvivorComforts_PlayerListWindow,
--       title = "UI_SurvivorComforts_F09_Title", -- also the sidebar button's tooltip
--       layout = "survivorcomforts.players", -- the name the position is saved under
--       x = 200, y = 150,                 -- first position, from the player's screen corner
--       width = 260, height = 320,        -- first size
--       sidebar = { order = 3, icon = "Players" }, -- the sidebar button (Sidebar.lua)
--       isAvailable = function() ... end, -- optional; false hides the button and nothing opens
--       canOpen = function(playerNum) ... end, -- optional; false keeps it from opening
--       onOpen = function(window) ... end, -- optional, just before it is shown
--   })
--   windows.toggle(playerNum)  windows.open(playerNum)  windows.isOpen(playerNum)
--   windows.anyOpen()  windows.forEach(fn)  windows.create(playerNum)  windows.destroy(playerNum)
--
-- sidebar is optional; without it there is no button (F15 is opened from F09).
--
-- The sidebar button and the key that open the window come from the
-- feature's options "<id>_sidebar" and "<id>_key", added in its addOptions
-- with SurvivorComforts.addWindowOptions(options, id).

require "SurvivorComforts/Core"
require "SurvivorComforts/Sidebar"
require "ISUI/ISCollapsableWindow"

SurvivorComforts_Window = ISCollapsableWindow:derive("SurvivorComforts_Window")

-- Vanilla only hides the window; it is also taken off the screen here.
function SurvivorComforts_Window:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

function SurvivorComforts_Window:new(x, y, width, height, playerNum, title)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.playerNum = playerNum
    o.title = getText(title)
    o.visibleOnStartup = false
    return o
end

-- "Show a button on the left icons" (on at first) and the key (none at first).
-- The texts are UI_SurvivorComforts_<id>_Sidebar, _Sidebar_Tooltip and _Key.
function SurvivorComforts.addWindowOptions(options, id)
    local prefix = "UI_SurvivorComforts_" .. id
    options:addTickBox(id .. "_sidebar", getText(prefix .. "_Sidebar"), true, getText(prefix .. "_Sidebar_Tooltip"))
    options:addKeyBind(id .. "_key", getText(prefix .. "_Key"), 0)
end

function SurvivorComforts.addWindow(def)
    local windows = { instances = {} }
    local instances = windows.instances

    local function isAvailable()
        return SurvivorComforts.isEnabled(def.id) and (not def.isAvailable or def.isAvailable())
    end

    function windows.destroy(playerNum)
        local window = instances[playerNum]
        if window then
            window:close()
            instances[playerNum] = nil
        end
    end

    -- Makes a new window (in place of the old one, if there is one).
    function windows.create(playerNum)
        windows.destroy(playerNum)
        local x = getPlayerScreenLeft(playerNum) + def.x
        local y = getPlayerScreenTop(playerNum) + def.y
        local window = def.class:new(x, y, def.width, def.height, playerNum)
        window:initialise()
        window:setVisible(false)
        instances[playerNum] = window
        -- Only the first local player has a saved layout, like vanilla windows.
        if playerNum == 0 then
            ISLayoutManager.RegisterWindow(def.layout, ISCollapsableWindow, window)
        end
        return window
    end

    function windows.isOpen(playerNum)
        local window = instances[playerNum]
        return window ~= nil and window:getIsVisible()
    end

    function windows.anyOpen()
        for _, window in pairs(instances) do
            if window:getIsVisible() then return true end
        end
        return false
    end

    function windows.forEach(fn)
        for _, window in pairs(instances) do
            fn(window)
        end
    end

    local function show(window)
        if def.onOpen then def.onOpen(window) end
        window:addToUIManager()
        window:setVisible(true)
        window:bringToTop()
    end

    -- Opens or closes the window; used by the keys and the sidebar buttons.
    function windows.toggle(playerNum)
        if not isAvailable() then return end
        if def.canOpen and not def.canOpen(playerNum) then return end
        SurvivorComforts.safeCall(def.id, function()
            local window = instances[playerNum] or windows.create(playerNum)
            if window:getIsVisible() then
                window:close()
                return
            end
            show(window)
        end)
    end

    -- Opens the window, or brings it to the front when it is open; returns
    -- it, or nil when it cannot be opened (used by F15, opened from F09).
    function windows.open(playerNum)
        if not isAvailable() then return nil end
        if def.canOpen and not def.canOpen(playerNum) then return nil end
        local ok, window = SurvivorComforts.safeCall(def.id, function()
            local window = instances[playerNum] or windows.create(playerNum)
            if window:getIsVisible() then
                window:bringToTop()
            else
                show(window)
            end
            return window
        end)
        return ok and window or nil
    end

    if def.sidebar then
        SurvivorComforts.addSidebarButton({
            id = def.id,
            order = def.sidebar.order,
            icon = def.sidebar.icon,
            tooltip = def.title,
            isShown = function()
                return isAvailable() and SurvivorComforts.getOptionValue(def.id .. "_sidebar") == true
            end,
            isActive = windows.isOpen,
            onClick = windows.toggle,
        })
    end

    Events.OnKeyPressed.Add(function(key)
        if key == nil or key == 0 then return end
        if key ~= SurvivorComforts.getOptionValue(def.id .. "_key") then return end
        local player = getPlayer()
        if not player then return end
        windows.toggle(player:getPlayerNum())
    end)

    return windows
end
