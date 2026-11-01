-- Survivor Comforts tests: a "Survivor Comforts" tab in the debug menu's unit
-- tests window (Dev > Unit tests), next to the game's own timed action tests.
-- Same layout as the game's tab: "Run all", "Stop", then one row per test
-- with a "Run" button and the result.

require "DebugUIs/DebugMenu/Base/ISDebugSubPanelBase"
require "DebugUIs/DebugMenu/UnitTests/UnitTestsDebug"
require "SurvivorComfortsTests/Runner"

local T = SurvivorComfortsTests

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local GREY = { r = 0.4, g = 0.4, b = 0.4 }
local YELLOW = { r = 1.0, g = 1.0, b = 0.2 }

SurvivorComfortsTestsPanel = ISDebugSubPanelBase:derive("SurvivorComfortsTestsPanel")

function SurvivorComfortsTestsPanel:createChildren()
    ISPanel.createChildren(self)
    SurvivorComfortsTestsPanel.instance = self

    local x, y, w = UI_BORDER_SPACING + 1, UI_BORDER_SPACING + 1, self.width - UI_BORDER_SPACING * 3 - 13
    local _, runAll = ISDebugUtils.addButton(self, { id = "runAll" }, x, y, (w - UI_BORDER_SPACING) / 2, BUTTON_HGT,
        getText("IGUI_UnitTests_RunAllTests"), SurvivorComfortsTestsPanel.onRunAll)
    y = ISDebugUtils.addButton(self, { id = "stop" }, runAll:getRight() + UI_BORDER_SPACING, y, (w + UI_BORDER_SPACING) / 2, BUTTON_HGT,
        getText("IGUI_UnitTests_Stop"), SurvivorComfortsTestsPanel.onStop)
    y = y + UI_BORDER_SPACING
    y, self.summary = ISDebugUtils.addLabel(self, { id = "summary" }, x, y, "", UIFont.Small)
    y = y + UI_BORDER_SPACING

    local names = T.names()
    local nameWidth = 0
    for _, name in ipairs(names) do
        nameWidth = math.max(nameWidth, UI_BORDER_SPACING + getTextManager():MeasureStringX(UIFont.Small, name))
    end
    local runText = getText("IGUI_UnitTests_Run")
    local runWidth = UI_BORDER_SPACING * 2 + getTextManager():MeasureStringX(UIFont.Small, runText)

    self.resultLabels = {}
    for _, name in ipairs(names) do
        local y2, runButton
        ISDebugUtils.addLabel(self, { id = "name", name = name }, x, y, name, UIFont.Small)
        y2, runButton = ISDebugUtils.addButton(self, { id = "run", name = name }, x + nameWidth, y, runWidth, BUTTON_HGT,
            runText, SurvivorComfortsTestsPanel.onRunOne)
        local _, result = ISDebugUtils.addLabel(self, { id = "result", name = name }, runButton:getRight() + UI_BORDER_SPACING, y + 3, "", UIFont.Small)
        self.resultLabels[name] = result
        y = y2 + UI_BORDER_SPACING
    end

    self:setScrollHeight(y + UI_BORDER_SPACING + 1)
    self:refresh()
end

local function setLabel(label, text, color)
    label.name = text
    label.r, label.g, label.b = color.r, color.g, color.b
end

-- Shows the latest results (called by the runner after every change).
function SurvivorComfortsTestsPanel:refresh()
    if not self.resultLabels then return end
    local good, bad = getCore():getGoodHighlitedColor(), getCore():getBadHighlitedColor()
    local goodColor = { r = good:getR(), g = good:getG(), b = good:getB() }
    local badColor = { r = bad:getR(), g = bad:getG(), b = bad:getB() }
    for name, label in pairs(self.resultLabels) do
        local result = T.results[name]
        if not result then
            setLabel(label, getText("IGUI_UnitTests_Untested"), GREY)
        elseif result.status == "running" then
            setLabel(label, "...", YELLOW)
        elseif result.status == "pass" then
            setLabel(label, getText("IGUI_UnitTests_Success") .. " (" .. result.ms .. " ms)", goodColor)
        else
            setLabel(label, getText("IGUI_UnitTests_Fail") .. ": " .. tostring(result.message), badColor)
        end
    end
    local passed, failed = T.counts()
    local text = #T.names() .. " test(s)"
    if T.isRunning() then
        text = text .. " - running"
    elseif passed + failed > 0 then
        text = text .. " - last run: " .. passed .. " passed, " .. failed .. " failed"
    end
    setLabel(self.summary, text, (failed > 0) and badColor or { r = 1, g = 1, b = 1 })
end

function SurvivorComfortsTestsPanel:onRunAll()
    T.runAll()
end

function SurvivorComfortsTestsPanel:onStop()
    T.stop()
end

function SurvivorComfortsTestsPanel:onRunOne(button)
    if button.customData and button.customData.name then
        T.runOne(button.customData.name)
    end
end

function SurvivorComfortsTestsPanel:new(x, y, width, height, doStencil)
    local o = ISDebugSubPanelBase.new(self, x, y, width, height, doStencil)
    return o
end

table.insert(T.listeners, function()
    local panel = SurvivorComfortsTestsPanel.instance
    if panel then panel:refresh() end
end)

-- Our tab, after the game's own.
local original_initialise = UnitTestsDebug.initialise
function UnitTestsDebug:initialise()
    original_initialise(self)
    self:registerPanel("Survivor Comforts", SurvivorComfortsTestsPanel)
end
