local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local mainGui = playerGui:WaitForChild("MainGui")

local UIController = {}

UIController.debugButton = mainGui.DebugUI.DebugMode


function UIController.ChangeDebugModeUI(debugMode)
    mainGui.DebugUI.DebugMode.Text = debugMode and "Debug: On" or "Debug: Off"
end

function UIController.UpdateMomentum(momentumUnit)
    mainGui.MomentumUnit.Text = "MomentumUnit: " .. math.round(momentumUnit)
end

function UIController.UpdateFallSpeed(speed, lastSpeed)
    mainGui.FallSpeed.Text = "Fall Speed: " .. math.round(speed)
    mainGui.LastFallSpeed.Text = "Last Fall Speed: " .. math.round(lastSpeed)
end


return UIController