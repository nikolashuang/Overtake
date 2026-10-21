local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Characters = {}
local PlayerInputs = {}
local simulationConnected = nil
local inputContext = RepStorage.Inputs.MovementContext


local Simulation = {}

function Simulation.Init()
    if simulationConnected then return end

    RunService:BindToSimulation(Simulation.Step, Enum.StepFrequency.Hz60, 2000)

    simulationConnected = true
    print("Simulation Registered")
end

function Simulation.PreparePlayer(player, character)
    if not RunService:IsServer() then return end

    local rootPart = character:WaitForChild("HumanoidRootPart")

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

function Simulation.RegisterPlayer(player)
    local context = nil

    if RunService:IsServer() then
        context = player:FindFirstChild("MovementContext")

        if not context then
            context = inputContext:Clone()
            context.Parent = player
        end
    else
        context = player:WaitForChild("MovementContext")
    end

    PlayerInputs[player] = context
end

function Simulation.RegisterCharacter(player, characterObject)
    Characters[player] = characterObject
end

function Simulation.UnregisterPlayer(player)
    PlayerInputs[player] = nil
end

function Simulation.UnregisterCharacter(player)
    Characters[player] = nil
end


function Simulation.Step(deltaTime)
    for player, characterObject in pairs(Characters) do
        local context = PlayerInputs[player]
        if not context then continue end

        local spaceInput = context.SpaceInput:GetState()

        if spaceInput then
            print(player.Name, "Space held")
        end
    end
end


return Simulation