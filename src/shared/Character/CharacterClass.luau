local RepStorage = game:GetService("ReplicatedStorage")
local MovementState = require(RepStorage.Shared.Simulation.MovementState)

local ParkourDetection = require(RepStorage.Shared.Parkour.ParkourDetection)
local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)

local VaultConfig = ParkourConfig.Vault
local MomentumConfig = ParkourConfig.Momentum
local BoostConfig = ParkourConfig.Boost
local WallRunConfig = ParkourConfig.WallRun
local RecoveryConfig = ParkourConfig.Recovery
local ClimbConfig = ParkourConfig.Climbing

local function safeUnit(vector, fallback)
    return vector.Magnitude > 0.0001 and vector.Unit or fallback
end

local CharacterClass = {}
CharacterClass.ConstraintNames = {
    "VaultOrHurdle_AlignOrientation_1",
    "VaultOrHurdle_LinearVelocity_1",
    "Lunge_AlignOrientation_1",
    "Lunge_LinearVelocity_1",
    "StartWallRun_AlignOrientation_1",
    "StartWallRun_AlignOrientation_2",
    "StartWallRun_LinearVelocity_1",
    "WallRedirect_LinearVelocity_1",
    "RecoveryRoll_LinearVelocity_1",
    "Climb_AlignOrientation_1",
    "Climb_LinearVelocity_1",
    "ExtendedClimbBoost_LinearVelocity_1",
    "ExtendedClimbBoost_LinearVelocity_2",
    "LedgeCatch_AlignPosition_1",
    "LedgeCatch_AlignOrientation_1",
    "ExitLedgeCatch_LinearVelocity_1",
}


-- Only immutable character references and per-frame ray results live in Luau tables.
-- MovementState redirects all persistent gameplay fields to predicted attributes.
CharacterClass.__index = function(self, key)
    if MovementState.IsField(key) then return MovementState.Read(self.StateParts, key) end
    return CharacterClass[key]
end
CharacterClass.__newindex = function(self, key, value)
    if MovementState.IsField(key) then
        MovementState.Write(self.StateParts, key, value)
    else
        rawset(self, key, value)
    end
end

function CharacterClass.new(player, system)
    return setmetatable({Player = player, Profile = system and system.Profile}, CharacterClass)
end

function CharacterClass:isGrounded()
    return self.Humanoid.FloorMaterial ~= Enum.Material.Air
end

function CharacterClass:BindCharacter(character)
    self.Character = character
    self.Humanoid = character:WaitForChild("Humanoid")
    self.RootPart = character:WaitForChild("HumanoidRootPart")
    self.MovementAttachment = self.RootPart:WaitForChild("MovementAttachment")
    self.SlideCollider = character:WaitForChild("SlideCollider")
    self.StateParts = {
        self.RootPart:WaitForChild("MovementState1"),
        self.RootPart:WaitForChild("MovementState2"),
    }
    self.Constraints = {}
    for _, name in ipairs(CharacterClass.ConstraintNames) do
        self.Constraints[name] = self.RootPart:WaitForChild(name)
    end
    self.WallRunAlignment = self.Constraints.StartWallRun_AlignOrientation_1
    self.LedgeAlignPosition = self.Constraints.LedgeCatch_AlignPosition_1
    self.LedgeAlignOrientation = self.Constraints.LedgeCatch_AlignOrientation_1
    self.CollisionParts = {}
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part ~= self.SlideCollider then
            table.insert(self.CollisionParts, {Part = part, Normal = part:GetAttribute("OvertakeNormalCollision") == true})
        end
    end
    self.AnimationController = {
        PlayAnimation = function(group, name) self:EmitAnimation(group, name) end,
        StopAnimation = function() end,
        PlayStartWallRun = function()
            self:EmitAnimation("ParkourAnims", self.WallDirection == "Right" and "RightStartWallRunAnim" or "LeftStartWallRunAnim")
        end,
    }
end

function CharacterClass:EmitAnimation(group, name)
    self.AnimationGroup = group
    self.AnimationName = name
    self.AnimationSequence += 1
end

function CharacterClass:GetConstraint(name)
    local constraint = self.Constraints[name]
    local singleton = name == "StartWallRun_AlignOrientation_1"
        or name == "LedgeCatch_AlignPosition_1" or name == "LedgeCatch_AlignOrientation_1"
    if constraint.Enabled and not singleton then
        -- Preserve overlapping activations (rapid redirects/re-entry). The
        -- native engine stitches clones created by this shared simulation code.
        -- Pool identities are looked up afresh, never cached in a Luau table.
        local index = 1
        while true do
            local poolName = name .. "_Pool" .. index
            local pooled = self.RootPart:FindFirstChild(poolName)
            if not pooled then
                pooled = constraint:Clone()
                pooled.Name = poolName
                pooled:SetAttribute("ExpiresAt", 0)
                pooled.Parent = self.RootPart
            end
            if not pooled.Enabled or pooled:GetAttribute("ExpiresAt") == 0 then
                constraint = pooled
                break
            end
            index += 1
        end
    end
    constraint:SetAttribute("ExpiresAt", 0)
    constraint.Enabled = true
    return constraint
end

function CharacterClass:ExpireConstraint(constraint, duration)
    constraint:SetAttribute("ExpiresAt", time() + duration)
end

function CharacterClass:UpdateConstraintLifetimes()
    for _, constraint in ipairs(self.RootPart:GetChildren()) do
        if constraint:GetAttribute("MovementLifetime") ~= true then continue end
        local deadline = constraint:GetAttribute("ExpiresAt")
        if deadline and deadline > 0 and time() >= deadline then
            constraint.Enabled = false
            constraint:SetAttribute("ExpiresAt", 0)
        end
    end
end

function CharacterClass:UpdateMomentum(deltaTime)

    local isMoving = self.Humanoid.MoveDirection.Magnitude > 0 and not self.isInLedgeCatch and not self.isCrawling
    self.Humanoid.WalkSpeed = MomentumConfig.MIN_MOVE_SPEED

    if not self.isCrawling then

        if self.HaltMomentum then
            self.Stationary = 0

        elseif isMoving and math.abs(self.ForwardVelocity) > 10 then
            self.Stationary = 0
            self.MomentumUnit = math.min(MomentumConfig.MAX_MOMENTUM, self.MomentumUnit + self.RisingMomentum * deltaTime)
            self.RisingMomentum = math.min(MomentumConfig.MAX_RISING_MOMENTUM, self.RisingMomentum + 12 * deltaTime)
        else
            self.Stationary += deltaTime
            if self.Stationary >= 1 and self.MomentumUnit > MomentumConfig.MIN_MOMENTUM then
                self.MomentumUnit = math.max(MomentumConfig.MIN_MOMENTUM, self.MomentumUnit - 50 * deltaTime)
                self.RisingMomentum = MomentumConfig.MIN_RISING_MOMENTUM
            end
        end

        self.Humanoid.WalkSpeed += (self.MomentumUnit * 0.25)
        return
    end

    self.Humanoid.WalkSpeed = 5
    self.MomentumUnit = 0
    self.RisingMomentum = 0
end

function CharacterClass:UpdateVelocities()
    local root = self.RootPart
    local humanoid = self.Humanoid

    local velocity = root.AssemblyLinearVelocity
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)

    if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
        self.FreefallSpeed = 0
        self.ForwardVelocity = horizontalVelocity:Dot(humanoid.MoveDirection)
        return
    end

    self.FreefallSpeed = root.AssemblyLinearVelocity.Y
    self.LastFallSpeed = self.FreefallSpeed

    if self.FreefallSpeed < RecoveryConfig.MIN_FALL_SPEED then
        self.TempLockSliding = true
    end
end


function CharacterClass:ConsumeMomentum(value, deltaTime)
    self.RisingMomentum = MomentumConfig.MIN_RISING_MOMENTUM
    self.MomentumUnit = math.max(MomentumConfig.MIN_MOMENTUM, self.MomentumUnit - value * (deltaTime or 1))
end

function CharacterClass:ChangeSlideCollision(enabled)
    for _, entry in ipairs(self.CollisionParts) do
        entry.Part.CanCollide = not enabled and entry.Normal
    end
    self.SlideCollider.CanCollide = enabled
end

function CharacterClass:UpdateObject()
    -- The original momentum-scaled distance also drives climb and ledge detection.
    local momentumPercent = math.clamp((self.MomentumUnit / MomentumConfig.MAX_MOMENTUM), 0, 1)
    local vaultDistance = VaultConfig.MIN_VAULT_DISTANCE + (VaultConfig.MAX_VAULT_DISTANCE - VaultConfig.MIN_VAULT_DISTANCE) * momentumPercent

    local traversalObj, traversalType = ParkourDetection.DetectObstacle(self.Character, vaultDistance)

    self.traversalObj = traversalObj
    self.traversalType = traversalType
end

function CharacterClass:LookForPreciseLedge()
    return ParkourDetection.DetectPreciseLedgeFrame(self.Character, self.traversalObj, self.traversalType == "LedgeCatch")
end


--VAULTING--

function CharacterClass:CanVault()
    if self.traversalType ~= "Vault" and self.traversalType ~= "Hurdle" then return false end
    if self.Staggered then return false end
    if self.isCrawling then return false end
    if not self:isGrounded() then return false end
    if time() - self.LastVault < VaultConfig.VAULT_CD then return false end

    return true
end

function CharacterClass:VaultOrHurdle()
    local root = self.RootPart
    local hum = self.Humanoid

    hum.Jump = false
    self.LastVault = time()
    self.VaultMomentumHold = false

    local align = self:GetConstraint("VaultOrHurdle_AlignOrientation_1")
    align.Attachment0 = self.MovementAttachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.RigidityEnabled = true

    local linVel = self:GetConstraint("VaultOrHurdle_LinearVelocity_1")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    local currentVelocity = root.AssemblyLinearVelocity
    local look = root.CFrame.LookVector
    local flatLook = safeUnit(Vector3.new(look.X, 0, look.Z), Vector3.zAxis)
    local obstalceHeight = self.traversalObj.Instance.Size.Y

    local forwardSpeed = math.max(currentVelocity:Dot(flatLook), VaultConfig.MIN_VAULT_SPEED)

    if self.traversalType == "Vault" then
        if obstalceHeight < VaultConfig.MAX_VAULT_HEIGHT then
            linVel.VectorVelocity = flatLook * (forwardSpeed + 15) + Vector3.new(0, 3, 0)
            self.AnimationController.PlayAnimation("ParkourAnims", "VaultVariant1")
        else
            linVel.VectorVelocity = flatLook * (forwardSpeed + 15) + Vector3.new(0, 18, 0)
            self.AnimationController.PlayAnimation("ParkourAnims", "VaultVariant1")
            self:ConsumeMomentum(VaultConfig.TALL_VAULT_CONSUMPTION)
            self.HaltMomentum = true
            self.VaultMomentumHold = true
        end
        align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    elseif self.traversalType == "Hurdle" then
        linVel.VectorVelocity = flatLook * forwardSpeed + Vector3.new(0, 1.5, 0)
        align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
        self.AnimationController.PlayAnimation("ParkourAnims", "HurdleAnim")
    end


    self:ExpireConstraint(linVel, 0.2)
    self:ExpireConstraint(align, 0.2)

    self.VaultReleaseAt = time() + VaultConfig.VAULT_DURATION

end

---------------------------------------------------------------------------------------------------

--BOOSTING--

function CharacterClass:CanLunge()
    if self.MomentumUnit < 25 then return false end
    if self.Staggered then return false end
    if self.isCrawling  then return false end
    if time() - self.LastLunge < BoostConfig.LUNGE_CD then return false end
    if self.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then return false end

    return true
end

function CharacterClass:Lunge()
    local root = self.RootPart
    local hum = self.Humanoid

    self.LastLunge = time()
    self.HaltMomentum = true

    local align = self:GetConstraint("Lunge_AlignOrientation_1")
    align.Attachment0 = self.MovementAttachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.RigidityEnabled = true

    local linVel = self:GetConstraint("Lunge_LinearVelocity_1")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    local currentVelocity = root.AssemblyLinearVelocity
    local look = root.CFrame.LookVector
    local flatLook = safeUnit(Vector3.new(look.X, 0, look.Z), Vector3.zAxis)
    local forwardSpeed = currentVelocity:Dot(flatLook)

    linVel.VectorVelocity = flatLook * (forwardSpeed + BoostConfig.LUNGE_POWER) + Vector3.new(0, BoostConfig.LUNGE_HEIGHT, 0)
    align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

    self:ConsumeMomentum(BoostConfig.LUNGE_CONSUMPTION)
    self.AnimationController.PlayAnimation("MovementAnims", "LungeAnim")


    self:ExpireConstraint(linVel, 0.3)
    self:ExpireConstraint(align, 0.3)

    self.JumpReleaseAt = time() + 0.5

end

---------------------------------------------------------------------------------------------------

--SLIDING--

function CharacterClass:CanSlide()
    if self.isSliding then return false end
    if self.MomentumUnit < MomentumConfig.MIN_SLIDING_MOMENTUM then return false end
    if self.Staggered then return false end
    if self.TempLockSliding then return false end
    if not self:isGrounded() then return false end

    return true
end

function CharacterClass:Slide()
    self.isSliding = true
    self.SlideDirection = safeUnit(self.Humanoid.MoveDirection, self.RootPart.CFrame.LookVector)
    self.HaltMomentum = true
    self.LastSlide = time()

    self:ChangeSlideCollision(true)

    self.AnimationController.PlayAnimation("ParkourAnims", "SlideAnim")
end

function CharacterClass:EndSlide()
    self.isSliding = false
    self.SlideDirection = nil
    self.HaltMomentum = false

    if not self.overHangExists then
        self:ChangeSlideCollision(false)
    else
        self.isCrawling = true
    end

    self.AnimationController.StopAnimation("ParkourAnims", "SlideAnim")
end

function CharacterClass:SlideDecay(deltaTime)
    self:ConsumeMomentum(MomentumConfig.SLIDING_CONSUMPTION_DECAY, deltaTime)
end

function CharacterClass:CheckOverHang()
    local overHang = ParkourDetection.DetectSlideOverHang(self.Character, 3.5)
    if not overHang then
        self.overHangExists = false
        return
    end

    self.overHangExists = true
end

function CharacterClass:CancelCrawl()
    self.isCrawling = false
    self:ChangeSlideCollision(false)
end

---------------------------------------------------------------------------------------------------

--WALL RUN--

function CharacterClass:UpdateWallRunObj()
    local wallDetectionDistance = WallRunConfig.MAX_WALL_ATTACH_DISTANCE
    local wallobj, direction = ParkourDetection.DetectWallRuns(self.Character, wallDetectionDistance)

    self.WallObject = wallobj
    self.WallDirection = direction
    self.ableWallRun = wallobj ~= nil

end


function CharacterClass:CanWallRun()
    if self.Staggered then return false end
    if self.isCrawling then return false end
    if not self.ableWallRun then return false end
    if self.MomentumUnit < WallRunConfig.MIN_WALLRUN_MOMENTUM then return false end
    if time() - self.LastWallRun < self.WallRunCD then return false end
    if math.abs(self.WallObject.Normal.Y) >= 0.35 then return false end
    if self.FreefallSpeed < -65 then return false end
    if self:isGrounded() then return false end

    return true
end

function CharacterClass:StartWallRun()
    local root = self.RootPart
    local humanoid = self.Humanoid

    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

    self.isWallRunning = true
    self.HaltMomentum = true
    self.WallRunCD = WallRunConfig.WALL_RUN_CD


    self.WallRunAlignment = self:GetConstraint("StartWallRun_AlignOrientation_1")
    self.WallRunAlignment.Attachment0 = self.MovementAttachment
    self.WallRunAlignment.Mode = Enum.OrientationAlignmentMode.OneAttachment
    self.WallRunAlignment.RigidityEnabled = false
    self.WallRunAlignment.Responsiveness = 40
    self.WallRunAlignment.MaxTorque = 50000
    self.WallRunAlignment.MaxAngularVelocity = 12

    local align = self:GetConstraint("StartWallRun_AlignOrientation_2")
    align.Attachment0 = self.MovementAttachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.RigidityEnabled = true

    local linVel = self:GetConstraint("StartWallRun_LinearVelocity_1")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    local currentSpeed = root.AssemblyLinearVelocity
    local look = root.CFrame.LookVector
    local flatLook = safeUnit(Vector3.new(look.X, 0, look.Z), Vector3.zAxis)
    local forwardSpeed = currentSpeed:Dot(flatLook)

    linVel.VectorVelocity = flatLook * forwardSpeed + Vector3.new(0, WallRunConfig.INIT_WALLRUN_HEIGHT_BOOST, 0)
    align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)

    self.AnimationController.PlayStartWallRun(self)

    self:ExpireConstraint(linVel, 0.3)
    self:ExpireConstraint(align, 0.3)

end

function CharacterClass:UpdateWallRun(wInput, deltaTime)
    local root = self.RootPart

    if not self.WallObject or not wInput or self.MomentumUnit < 25 or self:isGrounded() then
        self:EndWallRun()
        return
    end

    self.InWallRunTime += deltaTime

    local currentVelocity = root.AssemblyLinearVelocity
    local verticalVelocity = math.max(currentVelocity.Y, -4)
    local driftVerticalVelocity = -9
    local wallNormal = self.WallObject.Normal
    local pushDirection = -wallNormal
    local attachPressure = WallRunConfig.WALL_ATTACH_PRESSURE

    local tangent = Vector3.yAxis:Cross(wallNormal).Unit
    local horizontalVelocity = safeUnit(Vector3.new(currentVelocity.X, 0, currentVelocity.Z), root.CFrame.LookVector)

    if tangent:Dot(horizontalVelocity) < 0 then
        tangent = -tangent
    end

    if self.WallRunSpeed == nil then self.WallRunSpeed = math.max(currentVelocity:Dot(tangent), WallRunConfig.MIN_WALLRUN_MOMENTUM * 0.25) end

    if self.InWallRunTime > WallRunConfig.WALL_RUN_WINDOW then
        self.nowWallDrifting = true
        self.WallRunSpeed = math.max(10, self.WallRunSpeed - WallRunConfig.WALL_RUN_DECAY * deltaTime)
        root.AssemblyLinearVelocity = (tangent * self.WallRunSpeed) + (pushDirection * attachPressure) + Vector3.new(0, driftVerticalVelocity, 0)
        self:ConsumeMomentum(WallRunConfig.WALL_RUN_DECAY, deltaTime)
    else
        root.AssemblyLinearVelocity = (tangent * self.WallRunSpeed) + (pushDirection * attachPressure) + Vector3.new(0, verticalVelocity, 0)
    end

    self.WallRunAlignment.CFrame = CFrame.lookAt(Vector3.zero, tangent)
end

function CharacterClass:EndWallRun()
    local humanoid = self.Humanoid

    if not self.isWallRunning then
        return
    end

    self.isWallRunning = false
    self.nowWallDrifting = false

    self.HaltMomentum = false
    self.WallObject = nil
    self.WallDirection = nil
    self.WallRunSpeed = nil
    self.InWallRunTime = 0
    self.LastWallRun = time()

    if self.WallRunAlignment then
        self.WallRunAlignment.Enabled = false

    end

    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
end

function CharacterClass:WallRedirect(inputKey)
    if not ((inputKey == "A" and self.WallDirection == "Right")
        or (inputKey == "D" and self.WallDirection == "Left")) then return end
    local root = self.RootPart

    local linVel = self:GetConstraint("WallRedirect_LinearVelocity_1")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    local rightVector = root.CFrame.RightVector

    if inputKey == "A" and self.WallDirection == "Right" then
        linVel.VectorVelocity = -rightVector * WallRunConfig.WALL_REDIRECT_HORIZONTAL_POWER + Vector3.new(0, WallRunConfig.WALL_REDIRECT_UPWARD_POWER, 0)
    elseif inputKey == "D" and self.WallDirection == "Left" then
        linVel.VectorVelocity = rightVector * WallRunConfig.WALL_REDIRECT_HORIZONTAL_POWER + Vector3.new(0, WallRunConfig.WALL_REDIRECT_UPWARD_POWER, 0)
    else
        return
    end

    self.WallRunCD = 0--refresh cd on wallredirect

    self:ExpireConstraint(linVel, 0.3)

end

---------------------------------------------------------------------------------------------------


--RECOVERY--

function CharacterClass:CanRecoveryRoll()
    if self.LastFallSpeed > RecoveryConfig.MIN_FALL_SPEED then return false end
    if self.LastFallSpeed < RecoveryConfig.MAX_FALL_SPEED then return false end

    return true
end

function CharacterClass:RecoveryRoll(timing)
    local root = self.RootPart

    local currentVelocity = root.AssemblyLinearVelocity
    local linVel = self:GetConstraint("RecoveryRoll_LinearVelocity_1")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    local flatLook = safeUnit(Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z), Vector3.zAxis)
    local forwardSpeed = math.max(currentVelocity:Dot(flatLook), RecoveryConfig.MIN_ROLL_SPEED)

    if timing >= RecoveryConfig.PERFECT_ROLL_WINDOW and timing <= RecoveryConfig.ROLL_WINDOW then
        self:ConsumeMomentum(RecoveryConfig.ROLL_CONSUMPTION)
    end

    linVel.VectorVelocity = flatLook * forwardSpeed
    self.AnimationController.PlayAnimation("ParkourAnims", "RecoveryRollAnim")

    self:ExpireConstraint(linVel, 0.3)

end

function CharacterClass:CanClimb()
    if self.traversalType ~= "Climb" then return false end
    if self.LastFallSpeed <= ClimbConfig.MIN_FALL_SPEED_TO_CLIMB then return false end
    if time() - self.LastClimb < ClimbConfig.CLIMB_CD then return false end
    if self.Staggered then return false end
    if self.isCrawling then return false end


    return true
end

function CharacterClass:Climb()
    local root = self.RootPart
    local humanoid = self.Humanoid

    if self.isClimbing then return end

    self.isClimbing = true
    self.HaltMomentum = true

    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

    local wallNoraml = self.traversalObj.Normal

    local align = self:GetConstraint("Climb_AlignOrientation_1")
    align.Attachment0 = self.MovementAttachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.RigidityEnabled = true

    local linVel = self:GetConstraint("Climb_LinearVelocity_1")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    local look = root.CFrame.LookVector
    local flatLook = safeUnit(Vector3.new(look.X, 0, look.Z), Vector3.zAxis)

    linVel.VectorVelocity = (Vector3.yAxis * ClimbConfig.NORMAL_CLIMB_SPEED) + (-wallNoraml * ClimbConfig.SOFT_PUSH_PRESSURE)
    align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)

    self:ExpireConstraint(linVel, 0.85)
    self:ExpireConstraint(align, 0.85)

    self.LastClimb = time()

    self.AnimationController.PlayAnimation("ParkourAnims", "ClimbAnim")

    self.JumpReleaseAt = time() + 0.5

end

function CharacterClass:ExtendedClimbBoost(sidewayInput)
    self.AnimationController.StopAnimation("ParkourAnims", "ClimbAnim")

    local root = self.RootPart

    if self.ClimbingAConsumed and sidewayInput == "A" then
        return
    elseif self.ClimbingDConsumed and sidewayInput == "D" then
        return
    end

    local wallNormal = self.traversalObj.Normal

    local linVel = self:GetConstraint(sidewayInput == "A"
        and "ExtendedClimbBoost_LinearVelocity_1" or "ExtendedClimbBoost_LinearVelocity_2")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    if not self.ClimbingAConsumed and sidewayInput == "A" then
        linVel.VectorVelocity = (root.CFrame.UpVector * ClimbConfig.EXTENDED_BOOST_SPEED) + (wallNormal * ClimbConfig.SOFT_PUSH_PRESSURE) + Vector3.new(-8, 0, 0)
        self.AnimationController.PlayAnimation("ParkourAnims", "ClimbBoostLAnim")
    elseif not self.ClimbingDConsumed and sidewayInput == "D" then
        linVel.VectorVelocity = (root.CFrame.UpVector * ClimbConfig.EXTENDED_BOOST_SPEED) + (wallNormal * ClimbConfig.SOFT_PUSH_PRESSURE) + Vector3.new(8, 0, 0)
        self.AnimationController.PlayAnimation("ParkourAnims", "ClimbBoostRAnim")
    end

    if sidewayInput == "A" then
        self.ClimbingAConsumed = true
    elseif sidewayInput == "D" then
        self.ClimbingDConsumed = true
    end

    self:ExpireConstraint(linVel, 0.25)
end

function CharacterClass:CanLedgeCatch()
    if self.traversalType ~= "LedgeCatch" then return false end
    if self:isGrounded() then return false end
    if self.isInLedgeCatch then return false end
    if self.Staggered then return false end

    return true
end

function CharacterClass:LedgeCatch()
    local root = self.RootPart
    local precisePosition = self:LookForPreciseLedge()

    if precisePosition == nil then return end

    self.isInLedgeCatch = true

    self.LedgeAlignPosition = self:GetConstraint("LedgeCatch_AlignPosition_1")
    self.LedgeAlignPosition.Attachment0 = self.MovementAttachment
    self.LedgeAlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
    self.LedgeAlignPosition.RigidityEnabled = true

    self.LedgeAlignOrientation = self:GetConstraint("LedgeCatch_AlignOrientation_1")
    self.LedgeAlignOrientation.Attachment0 = self.MovementAttachment
    self.LedgeAlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    self.LedgeAlignOrientation.RigidityEnabled = true

    local look = self.traversalObj.Normal
    local flatLook = safeUnit(Vector3.new(look.X, 0, look.Z), Vector3.zAxis)


    root.CFrame = precisePosition
    self.LedgeAlignPosition.Position = root.Position
    self.LedgeAlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, -flatLook)

    if self.FreefallSpeed < RecoveryConfig.MIN_FALL_SPEED then
        self:ConsumeMomentum(self.MomentumUnit * 0.75)
    end

    self.AnimationController.PlayAnimation("ParkourAnims", "LedgeHangAnim")

end

function CharacterClass:ExitLedgeCatch(input)
    local root = self.RootPart

    self.LedgeAlignOrientation.Enabled = false
    self.LedgeAlignPosition.Enabled = false

    if input == "Space" then
        local linVel = self:GetConstraint("ExitLedgeCatch_LinearVelocity_1")

        linVel.Attachment0 = self.MovementAttachment
        linVel.RelativeTo = Enum.ActuatorRelativeTo.World
        linVel.ForceLimitsEnabled = false

        local look = root.CFrame.LookVector
        local flatLook = safeUnit(Vector3.new(look.X, 0, look.Z), Vector3.zAxis)


        linVel.VectorVelocity = flatLook * 20 + Vector3.new(0, 15, 0)
        self:ExpireConstraint(linVel, 0.2)
    end

    self.isInLedgeCatch = false

    self.AnimationController.StopAnimation("ParkourAnims", "LedgeHangAnim")
    self.AnimationController.PlayAnimation("ParkourAnims", "MantleAnim")

end




return CharacterClass
