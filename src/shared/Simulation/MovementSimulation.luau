local RepStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CharacterClass = require(RepStorage.Shared.Character.CharacterClass)

local isServer = RunService:IsServer()
local LocalPlayer = Players.LocalPlayer


local Characters = {}
local Simulation = {}

function Simulation.Init()
    RunService:BindToSimulation(Simulation.Step, Enum.StepFrequency.Hz60, 2000)
    print("Simulation Registered")
end

function Simulation.Step(deltaTime)

end

function Simulation.RegisterPlayer(player, character)

end





return Simulation