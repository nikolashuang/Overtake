local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Characters = {}
local Simulation = {}

local simulationConnected = nil

function Simulation.Init()
    if simulationConnected then return end

    RunService:BindToSimulation(Simulation.Step, Enum.StepFrequency.Hz60, 2000)
    print("Simulation Registered")
end

function Simulation.Step(deltaTime)
    for player, characterObject in pairs(Characters) do

    end
end

function Simulation.PreparePlayer(player, character)
    if not RunService:IsServer() then return end

    local rootPart = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")

    local movementAttachment = Instance.new("Attachment")
    movementAttachment.Name = "MovementAttachment"
    movementAttachment.Parent = rootPart

    local SlideCollider = Instance.new("Part")
    SlideCollider.Name = "SlideCollider"
    SlideCollider.Parent = character
    SlideCollider.CanCollide = false
    SlideCollider.CanTouch = false
    SlideCollider.Massless = true
    SlideCollider.Position = rootPart.Position + Vector3.new(0, -2, 0)
    SlideCollider.Size = Vector3.new(3.75, 2, 2.5)
    SlideCollider.Transparency = 0.5

    local Weld = Instance.new("WeldConstraint")
    Weld.Part0 = rootPart
    Weld.Part1 = SlideCollider
    Weld.Parent = SlideCollider

    for index = 1, 2 do
        local stateAttachment = Instance.new("Attachment")
        stateAttachment.Name = "MovementState" .. index
        stateAttachment.Parent = rootPart
    end
end

function Simulation.RegisterCharacter(player, characterObject)
    Characters[player] = characterObject
end

function Simulation.UnregisterCharacter(player)
    Characters[player] = nil
end


return Simulation