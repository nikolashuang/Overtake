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

function CharacterClass:Vault()

end


return CharacterClass