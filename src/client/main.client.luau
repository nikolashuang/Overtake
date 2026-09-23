local UserInput = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local StarterPlr = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ParkourPhysics = require(RepStorage.Shared.Parkour.ParkourPhysics)
local ClientCharacter = require(RepStorage.Shared.Character.CharacterClass)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local characterObject = ClientCharacter.new(player)
characterObject:BindCharacter(character)


RunService.PreRender:Connect(function()
    characterObject.VaultObject = ParkourPhysics.DetectObstacle(characterObject.Character)
end)

