local RepStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local ParkourPhysics = require(RepStorage.Shared.Parkour.ParkourPhysics)
local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)

local VaultConfig = ParkourConfig.Vault

local CharacterClass = {}

CharacterClass.__index = CharacterClass

function CharacterClass.new(player, profile)
    local self = setmetatable({}, CharacterClass)

    self.Player = player
    self.Profile = profile

    self.Character = nil
    self.Humanoid = nil
    self.RootPart = nil

    self.MomentumUnit = 0

    self.Attributes = {}

    self.Staggered = false
    self.Fatigue = false
    self.Stationary = 0

    self.ableVault = false
    self.vaultObject = nil
    self.traversalType = nil


    return self
end

function CharacterClass:BindCharacter(character)
    self.Character = character
    self.Humanoid = character:WaitForChild("Humanoid")
    self.RootPart = character:WaitForChild("HumanoidRootPart")

    self.MovementAttachment = Instance.new("Attachment")
    self.MovementAttachment.Name = "MovementAttachment"
    self.MovementAttachment.Parent = self.RootPart

end

function CharacterClass:UpdateMomentum(deltaTime)
    local isMoving = self.Humanoid.MoveDirection.Magnitude > 0

    if isMoving then
        self.Stationary = 0
        self.MomentumUnit += 3 * deltaTime
    else
        self.Stationary += 1 * deltaTime
        if self.Stationary >= 3 then
            self.MomentumUnit -= 2 * deltaTime
        end
    end

    return self.MomentumUnit
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

    local forwardSpeed = math.max(currentVelocity:Dot(flatLook), VaultConfig.MIN_VAULT_SPEED)

    if self.traversalType == "Vault" then
        print("Look Y:" .. look.Y)
        lv.VectorVelocity = flatLook * (forwardSpeed + 5) + Vector3.new(0, 3, 0)
        align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
    elseif self.traversalType == "Hurdle" then
        print("Look Y:" .. look.Y)
        lv.VectorVelocity = flatLook * forwardSpeed + Vector3.new(0, 1.5, 0)
        align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
    end

    lv.Parent = root
    align.Parent = root

    Debris:AddItem(lv, 0.15)
    Debris:AddItem(align, 0.15)

end

function CharacterClass:Slide()

end

function CharacterClass:LedgeBoost()

end

function CharacterClass:WallRun()

end


return CharacterClass