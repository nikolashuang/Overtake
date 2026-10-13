local RepStorage = game:GetService("ReplicatedStorage")
local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)
local AnimationFolder = RepStorage.Animations
local MomentumConfig = ParkourConfig.Momentum

local AnimationStorage = {
    MovementAnims = {
        LungeAnim = AnimationFolder.Movement:FindFirstChild("Lunge"),
        StartupAnim = AnimationFolder.Movement:FindFirstChild("Startup"),
        SprintAnim = AnimationFolder.Movement:FindFirstChild("Sprint"),
        FullSprintAnim = AnimationFolder.Movement:FindFirstChild("FullSprint"),
        CrouchIdleAnim = AnimationFolder.Movement:FindFirstChild("Crouch"),
        CrouchMoveAnim = AnimationFolder.Movement:FindFirstChild("CrouchMove")
    },

    ParkourAnims = {
        VaultVariant1 = AnimationFolder.Parkour:FindFirstChild("VaultVariant1"),
        HurdleAnim = AnimationFolder.Parkour:FindFirstChild("Hurdle"),
        SlideAnim = AnimationFolder.Parkour:FindFirstChild("Slide"),
        RightStartWallRunAnim = AnimationFolder.Parkour:FindFirstChild("StartWallRun[Right]"),
        LeftStartWallRunAnim = AnimationFolder.Parkour:FindFirstChild("StartWallRun[Left]"),
        RightWallRunAnim = AnimationFolder.Parkour:FindFirstChild("RightWallRun"),
        LeftWallRunAnim = AnimationFolder.Parkour:FindFirstChild("LeftWallRun"),
        RightWallDriftAnim = AnimationFolder.Parkour:FindFirstChild("RightWallDrift"),
        LeftWallDriftAnim = AnimationFolder.Parkour:FindFirstChild("LeftWallDrift"),
        RecoveryRollAnim = AnimationFolder.Parkour:FindFirstChild("RecoveryRoll"),
        LedgeHangAnim = AnimationFolder.Parkour:FindFirstChild("LedgeHang"),
        MantleAnim = AnimationFolder.Parkour:FindFirstChild("Mantle"),
        ClimbAnim = AnimationFolder.Parkour:FindFirstChild("Climb"),
        ClimbBoostLAnim = AnimationFolder.Parkour:FindFirstChild("ClimbBoostLeft"),
        ClimbBoostRAnim = AnimationFolder.Parkour:FindFirstChild("ClimbBoostRight"),
    }

}

local LoadedTracks = {}

local humanoid = nil
local animator = nil

local AnimationController = {}

function AnimationController.BindCharacter(character)
    humanoid = character:FindFirstChild("Humanoid")
    animator = humanoid:FindFirstChild("Animator")
end

function AnimationController.LoadAllTracks()
    for storageName, storage in pairs(AnimationStorage) do
        LoadedTracks[storageName] = {}

        for animName, animation in pairs(storage) do
            LoadedTracks[storageName][animName] = animator:LoadAnimation(animation)
        end
    end

end

--HELPER ANIMATION FUNCTIONS--

function AnimationController.PlayAnimation(storage, anim)
    if not storage or not anim then return end

    local storageTable = LoadedTracks[storage]
    if not storageTable then return end

    local animationTrack = storageTable[anim]
    if not animationTrack then return end

    animationTrack:Play()
end

function AnimationController.StopAnimation(storage, anim)
    if not storage or not anim then return end

    local storageTable = LoadedTracks[storage]
    if not storageTable then return end

    local animationTrack = storageTable[anim]
    if not animationTrack then return end

    animationTrack:Stop()
end

function AnimationController.AdjustAnimationSpeed(storage, anim, speed)
    if not storage or not anim then return end
    if type(speed) ~= "number" then return end

    local storageTable = LoadedTracks[storage]
    if not storageTable then return end

    local animationTrack = storageTable[anim]
    if not animationTrack then return end

    local trackSpeed = math.min(1.5, speed)

    animationTrack:AdjustSpeed(trackSpeed)
end

---------------------------------------------------------------------------------------------------


--ANIMATION MISCELLANEOUS--

local function otherActions(characterObject)
    if characterObject.isSliding then return true end
    if characterObject.isInLedgeCatch then return true end
    if characterObject.ForwardVelocity < 12 and not characterObject.isCrawling then return true end

    return false
end

function AnimationController.UpdateMovementAnimation(characterObject)
    local characterState = characterObject.Humanoid:GetState()

    if (characterObject.Humanoid.MoveDirection.Magnitude <= 0 and not characterObject.isCrawling) or characterState == Enum.HumanoidStateType.Jumping or characterState == Enum.HumanoidStateType.Freefall or otherActions(characterObject) then
        AnimationController.StopAnimation("MovementAnims", "StartupAnim")
        AnimationController.StopAnimation("MovementAnims", "FullSprintAnim")
        AnimationController.StopAnimation("MovementAnims", "SprintAnim")
        characterObject.currentMovementAnim = nil
        return
    end

    if characterObject.isCrawling then
        if characterObject.Humanoid.MoveDirection.Magnitude > 0 then
            if not characterObject.isPlayingCrouchMove then
                characterObject.isPlayingCrouch = false
                characterObject.isPlayingCrouchMove = true
                AnimationController.StopAnimation("MovementAnims", "CrouchIdleAnim")
                AnimationController.PlayAnimation("MovementAnims", "CrouchMoveAnim")
            end
        else
            if not characterObject.isPlayingCrouch then
                characterObject.isPlayingCrouch = true
                characterObject.isPlayingCrouchMove = false
                AnimationController.StopAnimation("MovementAnims", "CrouchMoveAnim")
                AnimationController.PlayAnimation("MovementAnims", "CrouchIdleAnim")
            end
        end
        return
    else
        characterObject.isPlayingCrouchMove = false
        characterObject.isPlayingCrouch = false
        AnimationController.StopAnimation("MovementAnims", "CrouchMoveAnim")
        AnimationController.StopAnimation("MovementAnims", "CrouchIdleAnim")
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
            AnimationController.AdjustAnimationSpeed("MovementAnims", characterObject.currentMovementAnim, math.min((characterObject.MomentumUnit / adjustment) * 2, 1))
        elseif characterObject.currentMovementAnim == "SprintAnim" then
            adjustment = MomentumConfig.MAX_MOMENTUM / 2
            AnimationController.AdjustAnimationSpeed("MovementAnims", characterObject.currentMovementAnim, math.max((characterObject.MomentumUnit / adjustment), 0.85))
        else
            return
        end

        return
    end

    if characterObject.currentMovementAnim then
        AnimationController.StopAnimation("MovementAnims", characterObject.currentMovementAnim)
    end

    AnimationController.PlayAnimation("MovementAnims", newAnim)
    characterObject.currentMovementAnim = newAnim

end

function AnimationController.PlayStartWallRun(characterObject)
    local track = nil
    local wallDirection = characterObject.WallDirection

    if wallDirection == "Right" then
        track = LoadedTracks.ParkourAnims.RightStartWallRunAnim
    else
        track = LoadedTracks.ParkourAnims.LeftStartWallRunAnim
    end
    track:Play()

    track.Stopped:Once(function()
        if not characterObject.isWallRunning then return end

        if wallDirection == "Right" then
            AnimationController.PlayAnimation("ParkourAnims", "RightWallRunAnim")
        else
            AnimationController.PlayAnimation("ParkourAnims", "LeftWallRunAnim")
        end
    end)


end

function AnimationController.UpdateWallMovementAnimation(characterObject)
    local characterState = characterObject.Humanoid:GetState()

    if characterState ~= Enum.HumanoidStateType.Freefall or not characterObject.isWallRunning then
        AnimationController.StopAnimation("ParkourAnims", "RightWallRunAnim")
        AnimationController.StopAnimation("ParkourAnims", "LeftWallRunAnim")
        AnimationController.StopAnimation("ParkourAnims", "RightWallDriftAnim")
        AnimationController.StopAnimation("ParkourAnims", "LeftWallDriftAnim")
        characterObject.currWallMovementAnim = nil
        return
    end

    if characterObject.nowWallDrifting and not characterObject.isPlayingWallDrift then
        AnimationController.StopAnimation("ParkourAnims", "RightWallRunAnim")
        AnimationController.StopAnimation("ParkourAnims", "LeftWallRunAnim")
        characterObject.isPlayingWallDrift = true
        if characterObject.WallDirection == "Right" then
            AnimationController.PlayAnimation("ParkourAnims", "RightWallDriftAnim")
        else
            AnimationController.PlayAnimation("ParkourAnims", "LeftWallDriftAnim")
        end
        return
    end

end


return AnimationController