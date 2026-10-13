local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Profiles = require(script.Parent.PlayerProfile.ProfileService)
local Simulation = require(RepStorage.Shared.Simulation.MovementSimulation)
local Diagnostics = require(RepStorage.Shared.Simulation.MovementDiagnostics)

Simulation.Initialize()
Diagnostics.Initialize(Simulation)

local function loadProfile(player)
    -- A disposable Studio movement test does not need live DataStore access.
    if RunService:IsStudio() then return end
    if not Profiles.LoadProfile(player) then player:Kick("Failed to load your progress. Please rejoin.") end
end
Players.PlayerAdded:Connect(loadProfile)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadProfile, player) end
Players.PlayerRemoving:Connect(function(player)
    if not RunService:IsStudio() then Profiles:ReleaseProfile(player) end
end)
-- ParkourRemote is deliberately unbound. Native inputs carry intent only;
-- no client traversal/momentum/physics payload is accepted.
