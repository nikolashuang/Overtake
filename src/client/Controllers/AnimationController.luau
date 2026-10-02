local RepStorage = game:GetService("ReplicatedStorage")
local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)
local AnimationFolder = RepStorage.Animations
local MomentumConfig = ParkourConfig.Momentum

local AnimationStorage = {
    MovementAnims = {
        LungeAnim = AnimationFolder.Movement:FindFirstChild("Lunge"),
        StartupAnim = AnimationFolder.Movement:FindFirstChild("Startup"),
        SprintAnim = AnimationFolder.Movement:FindFirstChild("Sprint"),
        FullSprintAnim = AnimationFolder.Movement:FindFirstChild("FullSprint")
    },

    ParkourAnims = {
        VaultVariant1 = AnimationFolder.Parkour:FindFirstChild("VaultVariant1"),
        HurdleAnim = AnimationFolder.Parkour:FindFirstChild("Hurdle"),
        SlideAnim = AnimationFolder.Parkour:FindFirstChild("Slide"),
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

function AnimationController.UpdateMovementAnimation(characterObject)
    local characterState = characterObject.Humanoid:GetState()

    if characterObject.Humanoid.MoveDirection.Magnitude <= 0 or characterState == Enum.HumanoidStateType.Jumping or characterState == Enum.HumanoidStateType.Freefall or characterObject.isSliding then
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


return AnimationController