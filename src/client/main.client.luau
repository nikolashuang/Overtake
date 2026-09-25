local UserInput = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local StarterPlr = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--local ParkourPhysics = require(RepStorage.Shared.Parkour.ParkourPhysics)
local ParkourController = require(script.Parent.Controllers.ParkourController)
local ClientCharacter = require(RepStorage.Shared.Character.CharacterClass)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local characterObject = ClientCharacter.new(player)
characterObject:BindCharacter(character)


UserInput.InputBegan:Connect(function(input, processed)
    ParkourController.AttemptVault(input, processed, characterObject)
end)


RunService.PreRender:Connect(function()
    characterObject:UpdateVaultObject()
end)

