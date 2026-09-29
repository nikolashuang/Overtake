local UserInput = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local StarterPlr = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--local ParkourPhysics = require(RepStorage.Shared.Parkour.ParkourPhysics)
local ParkourController = require(script.Parent.Controllers.ParkourController)
local ClientCharacter = require(RepStorage.Shared.Character.CharacterClass)
local AnimationController = require(StarterPlr.StarterPlayerScripts.Controllers.AnimationController)
local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)

local MomentumConfig = ParkourConfig.Momentum

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
    if processed then return end

    

end)


RunService.PreRender:Connect(function()
    characterObject:UpdateVaultObject()

    local characterState = characterObject.Humanoid:GetState()

    if characterObject.Humanoid.MoveDirection.Magnitude <= 0 or characterState == Enum.HumanoidStateType.Jumping or characterState == Enum.HumanoidStateType.Freefall then
        AnimationController.StopAnimation("MovementAnims", "StartupAnim")
        AnimationController.StopAnimation("MovementAnims", "FullSprintAnim")
        AnimationController.StopAnimation("MovementAnims", "SprintAnim")
        characterObject.currentMovementAnim = nil
        return
    end

    local newAnim = nil

    if characterObject.MomentumUnit < MomentumConfig.STARTUP_MOMENTUM then
        newAnim = "StartupAnim"
    else
        newAnim = "SprintAnim"
    end

    if characterObject.currentMovementAnim == newAnim then 
        local adjustment
        if characterObject.currentMovementAnim == "StartupAnim" then
            adjustment = MomentumConfig.STARTUP_MOMENTUM / 2
        elseif characterObject.currentMovementAnim == "SprintAnim" then
            adjustment = MomentumConfig.MAX_MOMENTUM / 10
        else
            return
        end

        AnimationController.AdjustAnimationSpeed("MovementAnims", characterObject.currentMovementAnim, (characterObject.MomentumUnit / adjustment) * 2)
        return 
    end

    if characterObject.currentMovementAnim then
        AnimationController.StopAnimation("MovementAnims", characterObject.currentMovementAnim)
    end

    AnimationController.PlayAnimation("MovementAnims", newAnim)
    characterObject.currentMovementAnim = newAnim
end)

RunService.PostSimulation:Connect(function(deltaTime)
    characterObject:UpdateMomentum(deltaTime)
end)

