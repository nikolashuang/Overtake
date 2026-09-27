local UserInput = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local StarterPlr = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--local ParkourPhysics = require(RepStorage.Shared.Parkour.ParkourPhysics)
local ParkourController = require(script.Parent.Controllers.ParkourController)
local ClientCharacter = require(RepStorage.Shared.Character.CharacterClass)
local AnimationController = require(StarterPlr.StarterPlayerScripts.Controllers.AnimationController)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

AnimationController.BindCharacter(character)
AnimationController.LoadAllTracks()

local characterObject = ClientCharacter.new(player, {AnimationController = AnimationController})
characterObject:BindCharacter(character)
ParkourController.Init(characterObject)

player.CharacterAdded:Connect(function(newCharacter)
    AnimationController.BindCharacter(newCharacter)
end)

UserInput.InputBegan:Connect(function(input, processed)
    ParkourController.AttemptVault(input, processed)
end)


RunService.PreRender:Connect(function()
    characterObject:UpdateVaultObject()

    if characterObject.Humanoid.MoveDirection.Magnitude <= 0 then
        AnimationController.StopAnimation("MovementAnims", "StartupAnim")
        AnimationController.StopAnimation("MovementAnims", "FullSprintAnim")
        AnimationController.StopAnimation("MovementAnims", "SprintAnim")
        characterObject.currentMovementAnim = nil
        return
    end

    local newAnim = nil

    if characterObject.MomentumUnit < 5 then
        newAnim = "StartupAnim"
    elseif characterObject.MomentumUnit > 90 then
        newAnim = "FullSprintAnim"
    else
        newAnim = "SprintAnim"
    end

    if characterObject.currentMovementAnim == newAnim then return end

    if characterObject.currentMovementAnim then
        AnimationController.StopAnimation("MovementAnims", characterObject.currentMovementAnim)
    end

    AnimationController.PlayAnimation("MovementAnims", newAnim)
    characterObject.currentMovementAnim = newAnim
end)

RunService.PostSimulation:Connect(function(deltaTime)
    characterObject:UpdateMomentum(deltaTime)
end)

