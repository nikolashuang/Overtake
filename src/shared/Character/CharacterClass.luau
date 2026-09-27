local RepStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local ParkourPhysics = require(RepStorage.Shared.Parkour.ParkourPhysics)
local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)

local VaultConfig = ParkourConfig.Vault
local MomentumConfig = ParkourConfig.Momentum

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

    self.MomentumUnit = 0
    self.RisingMomentum = 5

    self.Attributes = {}

    self.Staggered = false
    self.Fatigue = false
    self.Stationary = 0

    self.ableVault = false
    self.vaultObject = nil
    self.traversalType = nil

    self.currentMovementAnim = nil


    return self
end

function CharacterClass:BindCharacter(character)
    self.Character = character
    self.Humanoid = character:WaitForChild("Humanoid")
    self.RootPart = character:WaitForChild("HumanoidRootPart")
    self.Humanoid.WalkSpeed = MomentumConfig.MIN_MOVE_SPEED

    self.MovementAttachment = Instance.new("Attachment")
    self.MovementAttachment.Name = "MovementAttachment"
    self.MovementAttachment.Parent = self.RootPart

end

function CharacterClass:UpdateMomentum(deltaTime)
    local isMoving = self.Humanoid.MoveDirection.Magnitude > 0
    self.Humanoid.WalkSpeed = MomentumConfig.MIN_MOVE_SPEED


    if isMoving then
        if self.MomentumUnit < MomentumConfig.MAX_MOMENTUM then
            self.Stationary = 0
            self.MomentumUnit += self.RisingMomentum * deltaTime
            self.RisingMomentum = math.min(MomentumConfig.MAX_RISING_MOMENTUM, self.RisingMomentum + 0.2)
        elseif self.MomentumUnit >= MomentumConfig.MAX_MOMENTUM then
            self.MomentumUnit = MomentumConfig.MAX_MOMENTUM
        end
    else
        self.Stationary += 1 * deltaTime
        if self.Stationary >= 3 and self.MomentumUnit > MomentumConfig.MIN_MOMENTUM then
            self.MomentumUnit -= 50 * deltaTime
            self.RisingMomentum = 5
        end
    end

    print(self.MomentumUnit)
    self.Humanoid.WalkSpeed += (self.MomentumUnit * 0.3)
end

--VAULTING--

function CharacterClass:UpdateVaultObject()
    local vaultObjData, traversalType = ParkourPhysics.DetectObstacle(self.Character)
    
    self.vaultObject = vaultObjData
    self.traversalType = traversalType
    self.ableVault = vaultObjData ~= nil
end

function CharacterClass:CanVault()
    if not self.ableVault then return false end
    if self.Staggered then return false end
    
    return true
end

function CharacterClass:VaultOrHurdle()
    if not self:CanVault() then return end

    local root = self.RootPart
    local hum = self.Humanoid

    hum.Jump = false

    local align = Instance.new("AlignOrientation")
    align.Attachment0 = self.MovementAttachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.RigidityEnabled = true

    local lv = Instance.new("LinearVelocity")
    lv.Attachment0 = self.MovementAttachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.ForceLimitsEnabled = false

    local currentVelocity = root.AssemblyLinearVelocity
    local look = root.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z).Unit
    local obstalceHeight = self.vaultObject.Size.Y

    local forwardSpeed = math.max(currentVelocity:Dot(flatLook), VaultConfig.MIN_VAULT_SPEED)

    if self.traversalType == "Vault" then
        if obstalceHeight < VaultConfig.MAX_VAULT_HEIGHT then
            lv.VectorVelocity = flatLook * (forwardSpeed + 15) + Vector3.new(0, 3, 0)
            self.AnimationController.PlayAnimation("ParkourAnims", "VaultVariant1")
        else
            lv.VectorVelocity = flatLook * (forwardSpeed + 15) + Vector3.new(0, 9, 0)
            self.AnimationController.PlayAnimation("ParkourAnims", "VaultVariant1")
        end
        align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    elseif self.traversalType == "Hurdle" then
        lv.VectorVelocity = flatLook * forwardSpeed + Vector3.new(0, 1.5, 0)
        align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    end

    lv.Parent = root
    align.Parent = root

    Debris:AddItem(lv, 0.2)
    Debris:AddItem(align, 0.2)

    task.delay(VaultConfig.VAULT_DURATION, function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end)

end

function CharacterClass:Slide()

end

function CharacterClass:LedgeBoost()

end

function CharacterClass:WallRun()

end


return CharacterClass