local UserInput = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local StarterPlr = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ParkourDetection = require(RepStorage.Shared.Parkour.ParkourDetection)
local ParkourController = require(script.Parent.Controllers.ParkourController)
local ClientCharacter = require(RepStorage.Shared.CharacterClass)
local AnimationController = require(StarterPlr.StarterPlayerScripts.Controllers.AnimationController)
local UIController = require(script.Parent.Controllers.UIController)
local InputController = require(script.Parent.Controllers.InputController)
local HumanoidController = require(script.Parent.Controllers.HumanoidController)
local MovementSimulation = require(RepStorage.Shared.Simulation.MovementSimulation)


local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

AnimationController.BindCharacter(character)
AnimationController.LoadAllTracks()
HumanoidController.BindLandingListener(character)

local characterObject = ClientCharacter.new(player, {AnimationController = AnimationController})
characterObject:BindCharacter(character)

ParkourController.Init(characterObject)
HumanoidController.Init(ParkourController)

UIController.ChangeDebugModeUI(ParkourDetection.debugMode)


local debugUI = UIController.debugButton


player.CharacterAdded:Connect(function(newCharacter)
    characterObject:BindCharacter(newCharacter)
    HumanoidController.BindLandingListener(newCharacter)
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
    UIController.UpdateMomentum(characterObject.MomentumUnit)
    UIController.UpdateVelocities(characterObject.FreefallSpeed, characterObject.LastFallSpeed, math.abs(characterObject.ForwardVelocity), characterObject.LastUpSpeed)
end)

RunService.PreSimulation:Connect(function(deltaTime)
    characterObject:UpdateObject()
    characterObject:UpdateWallRunObj()
    characterObject:CheckOverHang()

    local rotationLocked = characterObject.isWallRunning or characterObject.isInLedgeCatch or characterObject.isSliding
    characterObject.Humanoid.AutoRotate = not rotationLocked

    if characterObject.isWallRunning then
        characterObject:UpdateWallRun(InputController.isKeyDown("W"), deltaTime)
    end

    if characterObject:CanLedgeCatch() and not characterObject.isInLedgeCatch and (time() - ParkourController.spaceInputBuffer < ParkourController.ledgeWindow) then
        ParkourController.AttemptLedgeCatch()
    end

    AnimationController.UpdateMovementAnimation(characterObject)
    AnimationController.UpdateWallMovementAnimation(characterObject)
end)

RunService.PostSimulation:Connect(function(deltaTime)
    characterObject:UpdateMomentum(deltaTime)
    characterObject:UpdateVelocities()

    if InputController.MaintainSlideInput() and characterObject.isSliding and characterObject.MomentumUnit > 0 then
        characterObject:SlideDecay(deltaTime)
        characterObject.currentMovementAnim = "SlideAnim"
    elseif (not InputController.MaintainSlideInput() or characterObject.MomentumUnit <= 0) and characterObject.isSliding then
        characterObject:EndSlide()
    end

    if not characterObject.overHangExists and characterObject.isCrawling then
        characterObject:CancelCrawl()
    end
end)

RunService:BindToRenderStep("LockSlideDirection", Enum.RenderPriority.Character.Value, function()
    if characterObject.isSliding then
        characterObject.Humanoid:Move(characterObject.SlideDirection, false)
    end
end)


--MISCELLANEOUS--

debugUI.Activated:Connect(function()
    ParkourDetection.debugMode = not ParkourDetection.debugMode
    UIController.ChangeDebugModeUI(ParkourDetection.debugMode)
    if ParkourDetection.debugMode == false then
        ParkourDetection.DestroyRaycastBeams(character)
        characterObject.SlideCollider.Transparency = 1
    else
        characterObject.SlideCollider.Transparency = 0.5
    end
end)

