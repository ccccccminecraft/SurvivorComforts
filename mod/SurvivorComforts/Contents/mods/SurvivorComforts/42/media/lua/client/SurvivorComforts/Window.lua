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
--       layout = "survivorcomforts.players", -- the name the position is saved under
--       x = 200, y = 150,                 -- first position, from the player's screen corner
--       width = 260, height = 320,        -- first size
--       isAvailable = function(playerNum) ... end, -- optional, besides the feature being on
--       onOpen = function(window) ... end, -- optional, just before it is shown
--   })
--   windows.toggle(playerNum)  windows.isOpen(playerNum)  windows.anyOpen()
--   windows.forEach(fn)  windows.create(playerNum)  windows.destroy(playerNum)

require "SurvivorComforts/Core"
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

function SurvivorComforts.addWindow(def)
    local windows = { instances = {} }
    local instances = windows.instances

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

    -- Opens or closes the window; used by the keys and the sidebar buttons.
    function windows.toggle(playerNum)
        if not SurvivorComforts.isEnabled(def.id) then return end
        if def.isAvailable and not def.isAvailable(playerNum) then return end
        SurvivorComforts.safeCall(def.id, function()
            local window = instances[playerNum] or windows.create(playerNum)
            if window:getIsVisible() then
                window:close()
                return
            end
            if def.onOpen then def.onOpen(window) end
            window:addToUIManager()
            window:setVisible(true)
            window:bringToTop()
        end)
    end

    return windows
end
