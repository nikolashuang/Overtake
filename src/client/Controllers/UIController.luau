local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local mainGui = playerGui:WaitForChild("MainGui")

local Modules = {}


local UIController = {}

UIController.debugButton = mainGui.DebugUI.DebugMode

function UIController.Init(modules)
    Modules = modules
end

function UIController.ChangeDebugModeUI(debugMode)
    mainGui.DebugUI.DebugMode.Text = debugMode and "Debug: On" or "Debug: Off"
end



return UIController