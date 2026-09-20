local UserInput = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local StarterPlr = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ParkourConfig = require(RepStorage.Shared.ParkourObjectsConfig)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()


RunService.PostSimulation:Connect(function()
    ParkourConfig.DetectVaultObj(character)
end)