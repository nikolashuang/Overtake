local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CharacterClass = require(ReplicatedStorage.Shared.Character.CharacterClass)
local MovementSimulation = require(ReplicatedStorage.Shared.Simulation.MovementSimulation)

local player = Players.LocalPlayer

MovementSimulation.Init()

local function setupCharacter(character)
    MovementSimulation.UnregisterCharacter(player)

    character:WaitForChild("HumanoidRootPart")
    character:WaitForChild("Humanoid")
    character:WaitForChild("HumanoidRootPart"):WaitForChild("MovementAttachment")

    local characterObject = CharacterClass.new(player, nil)
    characterObject:BindCharacter(character)

    MovementSimulation.RegisterCharacter(player, characterObject)
end

MovementSimulation.RegisterPlayer(player)
player.CharacterAdded:Connect(setupCharacter)

player.CharacterRemoving:Connect(function()
    MovementSimulation.UnregisterCharacter(player)
end)

if player.Character then
    task.spawn(setupCharacter, player.Character)
end
