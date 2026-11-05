-- F13: hide the user panel button (factions, safehouses, tickets) on the left
-- sidebar.
--
-- While it is hidden, players who are not admins cannot open the screens in
-- the user panel either (factions, safehouses, tickets...): there is no
-- other way in. Admins (SurvivorComforts.isAdmin) always see it. The buttons below
-- move up into its place (see Sidebar.lua, shared with F10).

require "SurvivorComforts/Core"
require "SurvivorComforts/Admin"
require "SurvivorComforts/Sidebar"
require "ISUI/ISEquippedItem"

local FEATURE_ID = "F13"

SurvivorComforts.registerFeature({
    id = FEATURE_ID,
    name = "UI_SurvivorComforts_F13_Name",
    tooltip = "UI_SurvivorComforts_F13_Tooltip",
})

local original_prerender = ISEquippedItem.prerender
function ISEquippedItem:prerender()
    original_prerender(self)
    -- The button exists only for multiplayer clients, and only for the first local player.
    if not self.clientBtn then return end
    SurvivorComforts.safeCall(FEATURE_ID, function()
        local hide = SurvivorComforts.isEnabled(FEATURE_ID) and not SurvivorComforts.isAdmin(self.chr)
        SurvivorComforts.setVanillaButtonHidden(self, self.clientBtn, hide)
    end)
end
