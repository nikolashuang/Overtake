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

function UIController.UpdateVelocities(downwardSpeed, lastSpeed, forwardSpeed)
    mainGui.FallSpeed.Text = "Fall Velocity: " .. math.round(downwardSpeed)
    mainGui.LastFallSpeed.Text = "Last Fall Velocity: " .. math.round(lastSpeed)
    mainGui.ForwardVelocity.Text = "Forward Velocity: " .. math.round(forwardSpeed)
end


return UIController