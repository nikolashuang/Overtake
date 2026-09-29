local RepStorage = game:GetService("ReplicatedStorage")
local AnimationFolder = RepStorage.Animations

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

    local trackSpeed = math.min(1.6, speed)

    animationTrack:AdjustSpeed(trackSpeed)
end


return AnimationController