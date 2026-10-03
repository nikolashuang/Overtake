local UserInput = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local StarterPlr = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ParkourPhysics = require(RepStorage.Shared.Parkour.ParkourPhysics)
local ParkourController = require(script.Parent.Controllers.ParkourController)
local ClientCharacter = require(RepStorage.Shared.Character.CharacterClass)
local AnimationController = require(StarterPlr.StarterPlayerScripts.Controllers.AnimationController)
local UIController = require(script.Parent.Controllers.UIController)
local InputController = require(script.Parent.Controllers.InputController)


local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

AnimationController.BindCharacter(character)
AnimationController.LoadAllTracks()

local characterObject = ClientCharacter.new(player, {AnimationController = AnimationController})
characterObject:BindCharacter(character)

ParkourController.Init(characterObject)
UIController.Init({
    DebugUI = {
        ParkourPhysics = ParkourPhysics
    }
})

local debugUI = UIController.debugButton


player.CharacterAdded:Connect(function(newCharacter)
    characterObject:BindCharacter(newCharacter)
    AnimationController.BindCharacter(newCharacter)
    AnimationController.LoadAllTracks()
end)

UserInput.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.Space then
        ParkourController.HandleSpaceInput()
    else
        ParkourController.HandleInput(input)
    end

end)


RunService.PreRender:Connect(function()
    characterObject:UpdateVaultObject()
    characterObject:UpdateWallRunObj()
    AnimationController.UpdateMovementAnimation(characterObject)
end)

RunService.PostSimulation:Connect(function(deltaTime)
    characterObject:UpdateMomentum(deltaTime)

    if InputController.MaintainSlideInput() and characterObject.isSliding and characterObject.MomentumUnit > 0 then
        characterObject:SlideDecay(deltaTime)
        characterObject.currentMovementAnim = "SlideAnim"
    else
        characterObject:EndSlide()
    end
end)

RunService:BindToRenderStep("LockSlideDirection", Enum.RenderPriority.Character.Value, function()
    if characterObject.isSliding then
        characterObject.Humanoid:Move(characterObject.SlideDirection, false)
    end
end)

debugUI.Activated:Connect(function()
    ParkourPhysics.debugMode = not ParkourPhysics.debugMode
    UIController.ChangeDebugModeUI(ParkourPhysics.debugMode)
    if ParkourPhysics.debugMode == false then
        ParkourPhysics.DestroyRaycastBeams(character)
        characterObject.SlideCollider.Transparency = 1
    else
        characterObject.SlideCollider.Transparency = 0.5
    end
end)


