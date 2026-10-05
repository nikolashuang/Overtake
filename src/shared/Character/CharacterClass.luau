local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local ParkourPhysics = require(RepStorage.Shared.Parkour.ParkourPhysics)
local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)

local VaultConfig = ParkourConfig.Vault
local MomentumConfig = ParkourConfig.Momentum
local BoostConfig = ParkourConfig.Boost
local WallRunConfig = ParkourConfig.WallRun

local CharacterClass = {}

CharacterClass.__index = CharacterClass

function CharacterClass.new(player, system)
    local self = setmetatable({}, CharacterClass)

    self.Player = player
    self.Profile = system.Profile
    self.AnimationController = system.AnimationController

    self.Character = nil
    self.Humanoid = nil
    self.RootPart = nil
    self.SlideCollider = nil

    self.MomentumUnit = 0
    self.FreefallSpeed = 0
    self.RisingMomentum = MomentumConfig.MIN_RISING_MOMENTUM

    self.Attributes = {}
    self.Modifiers = {}

    self.Staggered = false
    self.Fatigue = false
    self.HaltMomentum = false
    self.Stationary = 0
    self.traversalType = nil


    self.ableVault = false
    self.vaultObject = nil
    self.SlideDirection = nil
    self.isSliding = false

    self.ableWallRun = false
    self.WallObject = nil
    self.WallDirection = nil
    self.isWallRunning = false
    self.nowWallDrifting = false
    self.WallRunAlignment = nil
    self.WallRunSpeed = nil
    self.InWallRunTime = 0
    self.isPlayingWallDrift = false

    self.LastLunge = 0
    self.LastVault = 0
    self.LastWallRun = 0
    self.LastSlide = 0
    self.LastFallSpeed = 0

    self.currentMovementAnim = nil


    return self
end

local function isGrounded(self)
    return self.Humanoid.FloorMaterial ~= Enum.Material.Air
end


function CharacterClass:BindCharacter(character)
    self.Character = character
    self.Humanoid = character:WaitForChild("Humanoid")
    self.RootPart = character:WaitForChild("HumanoidRootPart")
    self.Humanoid.WalkSpeed = MomentumConfig.MIN_MOVE_SPEED
    self.Humanoid.JumpHeight = 3

    self.MovementAttachment = Instance.new("Attachment")
    self.MovementAttachment.Name = "MovementAttachment"
    self.MovementAttachment.Parent = self.RootPart
    
    if RunService:IsServer() then

        self.SlideCollider = Instance.new("Part")

        local WeldConstraint = Instance.new("WeldConstraint")
        WeldConstraint.Part0 = self.RootPart
        WeldConstraint.Part1 = self.SlideCollider
        WeldConstraint.Parent = self.RootPart

        self.SlideCollider.Name = "SlideCollider"
        self.SlideCollider.Parent = self.Character
        self.SlideCollider.CanCollide = false
        self.SlideCollider.Massless = true
        self.SlideCollider.Position = self.RootPart.Position + Vector3.new(0, -2, 0)
        self.SlideCollider.Size = Vector3.new(3.75, 2, 2.5)

        if ParkourPhysics.debugMode == false then
            self.SlideCollider.Transparency = 1
        else
            self.SlideCollider.Transparency = 0.5
        end

    else
        self.SlideCollider = self.Character:WaitForChild("SlideCollider")
    end
end

function CharacterClass:UpdateMomentum(deltaTime)

    local isMoving = self.Humanoid.MoveDirection.Magnitude > 0
    self.Humanoid.WalkSpeed = MomentumConfig.MIN_MOVE_SPEED

    if self.HaltMomentum then
        self.Stationary = 0

    elseif isMoving then
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
end

function CharacterClass:UpdateFreefall()
    local root = self.RootPart
    local humanoid = self.Humanoid

    if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
        self.FreefallSpeed = 0
        return 
    end

    self.FreefallSpeed = root.AssemblyLinearVelocity.Y
    self.LastFallSpeed = self.FreefallSpeed
end


function CharacterClass:ConsumeMomentum(value, deltaTime)
    self.RisingMomentum = MomentumConfig.MIN_RISING_MOMENTUM
    self.MomentumUnit = math.max(MomentumConfig.MIN_MOMENTUM, self.MomentumUnit - value * (deltaTime or 1))
end

local slidePartsCollision = {
    UpperRightLeg = false,
    UpperLeftLeg = false,
    LowerRightLeg = false,
    LowerLeftLeg = false
}

function CharacterClass:ChangeSlideCollision()
    for _, part in pairs(self.Character:GetChildren()) do
        if part:IsA("Part") and part ~= self.SlideCollider and not slidePartsCollision[part.Name] then
            part.CanCollide = not self.isSliding
        end
    end

    self.SlideCollider.CanCollide = self.isSliding
end

--VAULTING--

function CharacterClass:UpdateVaultObject()
    local momentumPercent = math.clamp((self.MomentumUnit / MomentumConfig.MAX_MOMENTUM), 0, 1)
    local vaultDistance = VaultConfig.MIN_VAULT_DISTANCE + (VaultConfig.MAX_VAULT_DISTANCE - VaultConfig.MIN_VAULT_DISTANCE) * momentumPercent

    local vaultObjData, traversalType = ParkourPhysics.DetectObstacle(self.Character, vaultDistance)
    
    self.vaultObject = vaultObjData
    self.traversalType = traversalType
    self.ableVault = vaultObjData ~= nil
end

function CharacterClass:CanVault()
    if not self.ableVault then return false end
    if self.Staggered then return false end
    if time() - self.LastVault < VaultConfig.VAULT_CD then return false end
    
    return true
end

function CharacterClass:VaultOrHurdle()
    local root = self.RootPart
    local hum = self.Humanoid

    hum.Jump = false
    self.LastVault = time()

    local align = Instance.new("AlignOrientation")
    align.Attachment0 = self.MovementAttachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.RigidityEnabled = true

    local linVel = Instance.new("LinearVelocity")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    local currentVelocity = root.AssemblyLinearVelocity
    local look = root.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z).Unit
    local obstalceHeight = self.vaultObject.Size.Y

    local forwardSpeed = math.max(currentVelocity:Dot(flatLook), VaultConfig.MIN_VAULT_SPEED)

    if self.traversalType == "Vault" then
        if obstalceHeight < VaultConfig.MAX_VAULT_HEIGHT then
            linVel.VectorVelocity = flatLook * (forwardSpeed + 15) + Vector3.new(0, 3, 0)
            self.AnimationController.PlayAnimation("ParkourAnims", "VaultVariant1")
        else
            linVel.VectorVelocity = flatLook * (forwardSpeed + 15) + Vector3.new(0, 12, 0)
            self.AnimationController.PlayAnimation("ParkourAnims", "VaultVariant1")
            self:ConsumeMomentum(VaultConfig.TALL_VAULT_CONSUMPTION)
            self.HaltMomentum = true
        end
        align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    elseif self.traversalType == "Hurdle" then
        linVel.VectorVelocity = flatLook * forwardSpeed + Vector3.new(0, 1.5, 0)
        align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
        self.AnimationController.PlayAnimation("ParkourAnims", "HurdleAnim")
    end

    linVel.Parent = root
    align.Parent = root

    Debris:AddItem(linVel, 0.2)
    Debris:AddItem(align, 0.2)

    task.delay(VaultConfig.VAULT_DURATION, function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        if self.HaltMomentum then self.HaltMomentum = false end
    end)

end

---------------------------------------------------------------------------------------------------

--BOOSTING--

function CharacterClass:CanLunge()
    if self.MomentumUnit < 25 then return end
    if self.Staggered then return end
    if time() - self.LastLunge < BoostConfig.LUNGE_CD then return end
    if self.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then return end

    return true
end

function CharacterClass:Lunge()
    local root = self.RootPart
    local hum = self.Humanoid

    self.LastLunge = time()
    self.HaltMomentum = true

    local align = Instance.new("AlignOrientation")
    align.Attachment0 = self.MovementAttachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.RigidityEnabled = true

    local linVel = Instance.new("LinearVelocity")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    local currentVelocity = root.AssemblyLinearVelocity
    local look = root.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z).Unit
    local forwardSpeed = currentVelocity:Dot(flatLook)

    linVel.VectorVelocity = flatLook * (forwardSpeed + BoostConfig.LUNGE_POWER) + Vector3.new(0, BoostConfig.LUNGE_HEIGHT, 0)
    align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

    self:ConsumeMomentum(BoostConfig.LUNGE_CONSUMPTION)
    self.AnimationController.PlayAnimation("MovementAnims", "LungeAnim")

    linVel.Parent = root
    align.Parent = root

    Debris:AddItem(linVel, 0.3)
    Debris:AddItem(align, 0.3)

    task.delay(0.5, function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        self.HaltMomentum = false
    end)

end

---------------------------------------------------------------------------------------------------

--SLIDING--

function CharacterClass:CanSlide()
    if self.isSliding then return false end
    if self.MomentumUnit < MomentumConfig.MIN_SLIDING_MOMENTUM then return false end
    if self.Staggered then return false end
    if not isGrounded(self) then return false end

    return true
end

function CharacterClass:Slide()
    self.isSliding = true
    self.Humanoid.AutoRotate = false
    self.SlideDirection = self.Humanoid.MoveDirection.Unit
    self.HaltMomentum = true
    self.LastSlide = time()

    self:ChangeSlideCollision()

    self.AnimationController.PlayAnimation("ParkourAnims", "SlideAnim")
end

function CharacterClass:EndSlide()
    if time() - self.LastSlide < 0.4 then
        task.wait(0.7)
    end
    
    self.isSliding = false
    self.Humanoid.AutoRotate = true
    self.SlideDirection = nil
    self.HaltMomentum = false

    self:ChangeSlideCollision()

    self.AnimationController.StopAnimation("ParkourAnims", "SlideAnim")
end

function CharacterClass:SlideDecay(deltaTime)
    self:ConsumeMomentum(MomentumConfig.SLIDING_CONSUMPTION_DECAY, deltaTime)
end

---------------------------------------------------------------------------------------------------

function CharacterClass:UpdateWallRunObj()
    local wallDetectionDistance = WallRunConfig.MAX_WALL_ATTACH_DISTANCE
    local wallobj, direction = ParkourPhysics.DetectWallRuns(self.Character, wallDetectionDistance)

    self.WallObject = wallobj
    self.WallDirection = direction
    self.ableWallRun = wallobj ~= nil

end


function CharacterClass:CanWallRun()
    if self.Staggered then return false end
    if not self.ableWallRun then return false end
    if self.MomentumUnit < WallRunConfig.MIN_WALLRUN_MOMENTUM then return false end
    if time() - self.LastWallRun < WallRunConfig.WALL_RUN_CD then return false end
    if math.abs(self.WallObject.Normal.Y) >= 0.35 then return false end  
    if isGrounded(self) then return false end


    return true
end

function CharacterClass:StartWallRun()
    local root = self.RootPart
    local humanoid = self.Humanoid

    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    humanoid.AutoRotate = false

    self.isWallRunning = true
    self.HaltMomentum = true

    self.WallRunAlignment = Instance.new("AlignOrientation")
    self.WallRunAlignment.Attachment0 = self.MovementAttachment
    self.WallRunAlignment.Mode = Enum.OrientationAlignmentMode.OneAttachment
    self.WallRunAlignment.RigidityEnabled = false
    self.WallRunAlignment.Responsiveness = 40
    self.WallRunAlignment.MaxTorque = 50000
    self.WallRunAlignment.MaxAngularVelocity = 12

    local align = Instance.new("AlignOrientation")
    align.Attachment0 = self.MovementAttachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.RigidityEnabled = true

    local linVel = Instance.new("LinearVelocity")
    linVel.Attachment0 = self.MovementAttachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.ForceLimitsEnabled = false

    local currentSpeed = root.AssemblyLinearVelocity
    local look = root.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z).Unit
    local forwardSpeed = currentSpeed:Dot(flatLook)

    linVel.VectorVelocity = flatLook * forwardSpeed + Vector3.new(0, WallRunConfig.INIT_WALLRUN_HEIGHT_BOOST, 0)
    align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)

    self.AnimationController.PlayStartWallRun(self)

    linVel.Parent = root
    align.Parent = root
    self.WallRunAlignment.Parent = root

    Debris:AddItem(linVel, 0.3)
    Debris:AddItem(align, 0.3)

end

function CharacterClass:UpdateWallRun(wInput, deltaTime)
    local root = self.RootPart

    if not self.WallObject or not wInput or self.MomentumUnit < 25 then
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
    local horizontalVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z).Unit

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
    self.Humanoid.AutoRotate = false
end

function CharacterClass:EndWallRun()
    local humanoid = self.Humanoid

    if not self.isWallRunning then
        return 
    end
    
    self.isWallRunning = false
    self.nowWallDrifting = false
    self.isPlayingWallDrift = false
    self.HaltMomentum = false
    self.WallObject = nil
    self.WallDirection = nil
    self.WallRunSpeed = nil
    self.InWallRunTime = 0
    self.LastWallRun = time()

    if self.WallRunAlignment then
        self.WallRunAlignment:Destroy()
        self.WallRunAlignment = nil
    end

    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    humanoid.AutoRotate = true
end

function CharacterClass:WallRedirect(inputKey)
    local root = self.RootPart

    local linVel = Instance.new("LinearVelocity")
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

    WallRunConfig.WALL_RUN_CD = 0 --refresh cd on wallredirect
    linVel.Parent = root

    Debris:AddItem(linVel, 0.3)

end


--RECOVERY--

function CharacterClass:CanRecoveryRoll()
    local root = self.RootPart

    if root.AssemblyLinearVelocity.Y > -80 then return false end

    return true
end


function CharacterClass:CanLedgeCatch()

end




return CharacterClass