local Config = require(script.Parent.Parent.Parkour.ParkourConfig)
local State = {}

-- Two dedicated predicted attachments reserve attribute space independently of
-- other character systems. Optional values use absence, never a false sentinel.
local defaults = {
    MomentumUnit = 0, RisingMomentum = Config.Momentum.MIN_RISING_MOMENTUM,
    FreefallSpeed = 0, ForwardVelocity = 0, Staggered = false, Fatigue = false,
    HaltMomentum = false, Stationary = 0, overHangExists = false,
    isSliding = false, TempLockSliding = false, isCrawling = false,
    ableWallRun = false, isWallRunning = false, nowWallDrifting = false,
    InWallRunTime = 0, WallRunCD = Config.WallRun.WALL_RUN_CD,
    isClimbing = false, isInLedgeCatch = false,
    ClimbingAConsumed = false, ClimbingDConsumed = false,
    LastLunge = 0, LastVault = 0, LastWallRun = 0, LastSlide = 0,
    LastClimb = 0, LastFallSpeed = 0, LastUpSpeed = 0, Landed = 0,
    VaultReleaseAt = 0, VaultMomentumHold = false, JumpReleaseAt = 0, LandingCheckAt = 0,
    SlideUnlockAt = 0, WasGrounded = true, WasFreefall = false,
    MiddleAt = -100, LeftAt = -100, RightAt = -100, ShiftAt = -100,
    SpaceAt = -100, AnimationSequence = 0,
    PrevSpace = false, PrevShift = false, PrevMiddle = false,
    PrevLeft = false, PrevRight = false, InvalidInputs = 0,
    SimulationTick = 0, RolledLanding = false,
}
local keys = {}
for key in pairs(defaults) do table.insert(keys, key) end
for _, key in ipairs({"SlideDirection", "WallRunSpeed", "WallDirection", "AnimationGroup", "AnimationName"}) do
    table.insert(keys, key)
end
table.sort(keys)
local shard = {}
for index, key in ipairs(keys) do
    assert(#key <= 50)
    shard[key] = math.floor((index - 1) / 32) + 1
end
assert(#keys <= 64, "Add a state shard before extending movement state")

function State.IsField(key) return shard[key] ~= nil end
function State.Read(parts, key)
    local value = parts[shard[key]]:GetAttribute(key)
    if value == nil then return defaults[key] end
    return value
end
function State.Write(parts, key, value)
    parts[shard[key]]:SetAttribute(key, value)
end
function State.Initialize(parts)
    for _, key in ipairs(keys) do
        if defaults[key] ~= nil and parts[shard[key]]:GetAttribute(key) == nil then
            State.Write(parts, key, defaults[key])
        end
    end
end
State.Keys = keys
return State
