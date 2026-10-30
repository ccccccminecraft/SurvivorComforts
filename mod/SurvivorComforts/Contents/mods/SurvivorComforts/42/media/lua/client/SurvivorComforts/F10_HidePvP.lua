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
require "SurvivorComforts/Sidebar"
require "ISUI/ISEquippedItem"

local FEATURE_ID = "F10"
local CHECK_INTERVAL_MS = 1000
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
-- so it is moved off screen with the buttons below moving up (see
-- Sidebar.lua). The radial timer icon drawn over it goes off screen too.
local original_prerender = ISEquippedItem.prerender
function ISEquippedItem:prerender()
    original_prerender(self)
    -- The button exists only for multiplayer clients, and only for the first local player.
    if not self.safetyBtn then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local hide = isOn()
        SurvivorComforts.setVanillaButtonHidden(self, self.safetyBtn, hide)
        local radial = self.radialIcon
        if radial then
            if hide and not self.survivorComfortsRadialY then
                self.survivorComfortsRadialY = radial:getY()
                radial:setY(OFFSCREEN_Y)
            elseif not hide and self.survivorComfortsRadialY then
                radial:setY(self.survivorComfortsRadialY)
                self.survivorComfortsRadialY = nil
            end
            if hide then radial:setVisible(false) end
        end
    end)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
