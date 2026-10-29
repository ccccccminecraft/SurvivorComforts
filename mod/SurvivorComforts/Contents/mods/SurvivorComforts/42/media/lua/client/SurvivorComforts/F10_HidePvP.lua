-- F10: hide the PvP (safety) button and keep PvP off.
--
-- While the feature is on:
--   * the skull button on the left sidebar is hidden and the vanilla buttons
--     below it move up into its place;
--   * the safety is kept on (PvP off). When it is off, it is switched back the
--     vanilla way (Safety:toggleSafety, which asks the server in multiplayer),
--     once the server's toggle and cooldown timers allow it;
--   * the button and the toggle key (G by default) do nothing. In split-screen
--     single player the key toggles co-op PvP instead; that is kept off too.
-- Turning the feature off puts everything back.

require "SurvivorComforts/Core"
require "ISUI/ISEquippedItem"

local FEATURE_ID = "F10"
local CHECK_INTERVAL_MS = 1000
local UI_BORDER_SPACING = 10
local OFFSCREEN_Y = -10000

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F10_Name",
    tooltip = "UI_SurvivorComforts_F10_Tooltip",
})

local function isOn()
    return SurvivorComforts.isEnabled(FEATURE_ID)
end

---------------------------------------------------------------------------
-- Toggling
---------------------------------------------------------------------------
local original_toggleSafety = ISEquippedItem.toggleSafety
function ISEquippedItem:toggleSafety()
    if isOn() then return end
    return original_toggleSafety(self)
end

-- The key handler is registered as a function value, so it is swapped in the event list.
local original_onKeyPressed = ISEquippedItem.onKeyPressed
Events.OnKeyPressed.Remove(original_onKeyPressed)
ISEquippedItem.onKeyPressed = function(key)
    if isOn() and getCore():isKey(KeybindId.TOGGLE_SAFETY, key) then return end
    return original_onKeyPressed(key)
end
Events.OnKeyPressed.Add(ISEquippedItem.onKeyPressed)

---------------------------------------------------------------------------
-- Keeping PvP off
---------------------------------------------------------------------------
local lastCheckMs = 0

local function keepPvpOff(player)
    if isClient() then
        if not getServerOptions():getBoolean("SafetySystem") then return end
        local safety = player:getSafety()
        -- isToggleAllowed is false while a toggle is already pending, so this asks only once.
        if safety and not safety:isEnabled() and safety:isToggleAllowed() then
            safety:toggleSafety()
        end
    elseif IsoPlayer.getCoopPVP() then
        IsoPlayer.setCoopPVP(false)
    end
end

local function onPlayerUpdate(player)
    if not player:isLocalPlayer() or not isOn() then return end
    local now = getTimestampMs()
    if now - lastCheckMs < CHECK_INTERVAL_MS then return end
    lastCheckMs = now
    SurvivorComforts.safeCall(FEATURE_ID, keepPvpOff, player)
end

---------------------------------------------------------------------------
-- Hiding the button
---------------------------------------------------------------------------
-- Vanilla shows the button and draws its outline in prerender on every frame,
-- so hiding is not enough: the button (and its outline and timer, drawn at the
-- button's position) is moved off screen as well.
local function isOurButton(sidebar, child)
    return sidebar.survivorComforts and sidebar.survivorComforts.isOurs[child] == true
end

local function hideButton(sidebar)
    local btn = sidebar.safetyBtn
    local state = { safetyY = btn:getY(), radialY = sidebar.radialIcon and sidebar.radialIcon:getY(), moved = {} }
    local gap = btn:getHeight() + UI_BORDER_SPACING + 5
    for _, child in pairs(sidebar:getChildren()) do
        if child.Type == "ISButton" and child ~= btn and not isOurButton(sidebar, child) and child:getY() > state.safetyY then
            state.moved[child] = child:getY()
            child:setY(child:getY() - gap)
        end
    end
    btn:setY(OFFSCREEN_Y)
    if sidebar.radialIcon then sidebar.radialIcon:setY(OFFSCREEN_Y) end
    sidebar.survivorComfortsSafetyHidden = state
end

local function showButton(sidebar)
    local state = sidebar.survivorComfortsSafetyHidden
    sidebar.survivorComfortsSafetyHidden = nil
    sidebar.safetyBtn:setY(state.safetyY)
    if sidebar.radialIcon and state.radialY then sidebar.radialIcon:setY(state.radialY) end
    for child, y in pairs(state.moved) do
        child:setY(y)
    end
end

local original_prerender = ISEquippedItem.prerender
function ISEquippedItem:prerender()
    original_prerender(self)
    -- The button exists only for multiplayer clients, and only for the first local player.
    if not self.safetyBtn then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local hide = isOn()
        if hide and not self.survivorComfortsSafetyHidden then
            hideButton(self)
        elseif not hide and self.survivorComfortsSafetyHidden then
            showButton(self)
        end
        if hide then
            self.safetyBtn:setVisible(false)
            if self.radialIcon then self.radialIcon:setVisible(false) end
        end
    end)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
