local RepStorage = game:GetService("ReplicatedStorage")
local ParkourPhysics = require(RepStorage.Shared.Parkour.ParkourPhysics)
local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)

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


    self.VaultObject = nil


    return self
end

function CharacterClass:BindCharacter(character)
    self.Character = character
    self.Humanoid = character:WaitForChild("Humanoid")
    self.RootPart = character:WaitForChild("HumanoidRootPart")

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

function CharacterClass:CanVault()
    local vaultObjData, detectedArea = ParkourPhysics.DetectObstacle(self.Character)

    if not vaultObjData then return false end

    return true, vaultObjData, detectedArea
end

function CharacterClass:Vault()
    local canVault, vaultData, detectedArea = self:CanVault()

    if not canVault then return end

    if detectedArea == "Waist" then
        
    elseif detectedArea == "Head" or detectedArea == "Both" then
        
    end


end

function CharacterClass:WallRun()

end


return CharacterClass