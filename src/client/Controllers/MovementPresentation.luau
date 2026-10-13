local RepStorage = game:GetService("ReplicatedStorage")
local Config = require(RepStorage.Shared.Parkour.ParkourConfig).Momentum
local Presentation = {}
local model
local animations = {}
local animator
local sequence = -1
local locomotion
local debugConnection

-- Native rollback can replace AnimationTrack handles. Resolve by animation ID
-- on every use; only replicated Animation definitions are cached.
local function trackFor(name, load)
    local animation = animations[name]
    if not animator or not animation then return nil end
    local track = animator:GetTrackByAnimationId(animation.AnimationId)
    if not track and load then track = animator:LoadAnimation(animation) end
    return track
end
local function stop(name)
    local track = trackFor(name, false)
    if track and track.IsPlaying then track:Stop() end
end
local function play(name)
    local track = trackFor(name, true)
    if track and not track.IsPlaying then track:Play() end
end
local aliases = {
    LungeAnim = "Lunge", StartupAnim = "Startup", SprintAnim = "Sprint", FullSprintAnim = "FullSprint",
    CrouchIdleAnim = "Crouch", CrouchMoveAnim = "CrouchMove",
    VaultVariant1 = "VaultVariant1", HurdleAnim = "Hurdle", SlideAnim = "Slide",
    RightStartWallRunAnim = "StartWallRun[Right]", LeftStartWallRunAnim = "StartWallRun[Left]",
    RightWallRunAnim = "RightWallRun", LeftWallRunAnim = "LeftWallRun",
    RightWallDriftAnim = "RightWallDrift", LeftWallDriftAnim = "LeftWallDrift",
    RecoveryRollAnim = "RecoveryRoll", LedgeHangAnim = "LedgeHang", MantleAnim = "Mantle",
    ClimbAnim = "Climb", ClimbBoostLAnim = "ClimbBoostLeft", ClimbBoostRAnim = "ClimbBoostRight",
}

local function bind(c)
    if debugConnection then debugConnection:Disconnect(); debugConnection = nil end
    for name in pairs(animations) do stop(name) end
    table.clear(animations)
    model, sequence, locomotion = c.Character, -1, nil
    animator = c.Humanoid:FindFirstChildOfClass("Animator")
    local folder = RepStorage:FindFirstChild("Animations")
    if animator and folder then
        for alias, name in pairs(aliases) do
            local animation = folder:FindFirstChild(name, true)
            if animation and animation:IsA("Animation") then
                animations[alias] = animation
            end
        end
    end
    local gui = c.Player:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("MainGui")
    local debugUI = main and main:FindFirstChild("DebugUI")
    local button = debugUI and debugUI:FindFirstChild("DebugMode")
    if button and button:IsA("GuiButton") then
        debugConnection = button.Activated:Connect(function()
            local enabled = workspace:GetAttribute("OvertakeDiagnostics") ~= true
            workspace:SetAttribute("OvertakeDiagnostics", enabled)
            if button:IsA("TextButton") then button.Text = enabled and "Debug: On" or "Debug: Off" end
        end)
    end
end

function Presentation.Update(c)
    if model ~= c.Character then bind(c) end
    -- Cosmetic playback reads current predicted state after replay. It cannot
    -- consume momentum, move the root, or complete an ability.
    if sequence ~= c.AnimationSequence then
        sequence = c.AnimationSequence
        if c.AnimationName then play(c.AnimationName) end
    end
    local freefall = c.Humanoid:GetState() == Enum.HumanoidStateType.Freefall
    local running = c.Humanoid.MoveDirection.Magnitude > 0 and not freefall
        and c.Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
        and c.ForwardVelocity >= 12 and not c.isSliding and not c.isInLedgeCatch and not c.isCrawling
    local nextLocomotion = running and (c.MomentumUnit < Config.STARTUP_MOMENTUM and "StartupAnim" or "SprintAnim") or nil
    if locomotion ~= nextLocomotion then
        if locomotion then stop(locomotion) end
        locomotion = nextLocomotion
        if locomotion then play(locomotion) end
    end
    local locomotionTrack = locomotion and trackFor(locomotion, true)
    if locomotionTrack then
        if not locomotionTrack.IsPlaying then locomotionTrack:Play() end
        locomotionTrack:AdjustSpeed(locomotion == "StartupAnim"
            and math.min(c.MomentumUnit / (Config.STARTUP_MOMENTUM / 2) * 2, 1)
            or math.min(1.5, math.max(c.MomentumUnit / (Config.MAX_MOMENTUM / 2), 0.85)))
    end
    local wallSide = c.WallDirection == "Right" and "Right" or "Left"
    local wanted = {
        SlideAnim = c.isSliding, LedgeHangAnim = c.isInLedgeCatch,
        CrouchIdleAnim = c.isCrawling and c.Humanoid.MoveDirection.Magnitude == 0,
        CrouchMoveAnim = c.isCrawling and c.Humanoid.MoveDirection.Magnitude > 0,
        ClimbAnim = c.isClimbing and c.AnimationName == "ClimbAnim",
    }
    wanted[wallSide .. (c.nowWallDrifting and "WallDriftAnim" or "WallRunAnim")] = c.isWallRunning
    for _, name in ipairs({"SlideAnim", "LedgeHangAnim", "CrouchIdleAnim", "CrouchMoveAnim", "ClimbAnim",
        "RightWallRunAnim", "LeftWallRunAnim", "RightWallDriftAnim", "LeftWallDriftAnim"}) do
        if wanted[name] then play(name) else stop(name) end
    end
    local gui = c.Player:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("MainGui")
    if main then
        local values = {MomentumUnit = c.MomentumUnit, FallSpeed = c.FreefallSpeed,
            LastFallSpeed = c.LastFallSpeed, ForwardVelocity = math.abs(c.ForwardVelocity), LastUpSpeed = c.LastUpSpeed}
        for name, value in pairs(values) do
            local label = main:FindFirstChild(name)
            if label and label:IsA("TextLabel") then label.Text = name .. ": " .. math.round(value) end
        end
    end
end
return Presentation

