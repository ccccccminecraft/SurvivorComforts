-- F13: hide the user panel button (factions, safehouses, tickets) on the left
-- sidebar.
--
-- Only the button is hidden; factions and the rest keep working. Admins
-- (whoever gets the vanilla admin button) always see it. The buttons below
-- move up into its place (see Sidebar.lua, shared with F10).

require "SurvivorComforts/Core"
require "SurvivorComforts/Sidebar"
require "ISUI/ISEquippedItem"

local FEATURE_ID = "F13"

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F13_Name",
    tooltip = "UI_SurvivorComforts_F13_Tooltip",
})

-- The same check vanilla uses to show the admin button.
local function isAdmin(player)
    local ok, result = pcall(function() return player:getRole():hasAdminTool() end)
    return ok and result == true
end

local original_prerender = ISEquippedItem.prerender
function ISEquippedItem:prerender()
    original_prerender(self)
    -- The button exists only for multiplayer clients, and only for the first local player.
    if not self.clientBtn then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local hide = SurvivorComforts.isEnabled(FEATURE_ID) and not isAdmin(self.chr)
        SurvivorComforts.setVanillaButtonHidden(self, self.clientBtn, hide)
    end)
end
