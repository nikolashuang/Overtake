local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")
local Diagnostics = {}

function Diagnostics.Initialize(simulation)
    if not RunService:IsStudio() then return end
    local server = RunService:IsServer()
    local samples, resimulated, corrections = {}, 0, 0
    local sampledCharacter
    local remote
    if server then
        remote = Instance.new("RemoteEvent")
        remote.Name = "OvertakeAuthorityDiagnostics"
        remote.Parent = RepStorage
    else
        remote = RepStorage:WaitForChild("OvertakeAuthorityDiagnostics")
        -- Misprediction access can depend on script capabilities/Studio build.
        local success, err = pcall(function()
            RunService.Misprediction:Connect(function(frameTime, instances, stats)
                corrections += 1
                if workspace:GetAttribute("OvertakeDiagnostics") == true then
                    print("[Overtake correction]", frameTime, "instances", #instances, "stats", stats)
                    for _, entry in ipairs(instances) do
                        for name, values in pairs(entry.Attributes or {}) do
                            print("[Overtake attribute correction]", name, "predicted", values.Predicted, "server", values.Authoritative)
                        end
                    end
                end
            end)
        end)
        if not success then warn("[Overtake] Misprediction signal unavailable; use Ctrl+Shift+F6:", err) end
        RunService.Rollback:Connect(function(frameTime)
            if workspace:GetAttribute("OvertakeDiagnostics") == true then print("[Overtake rollback]", frameTime) end
        end)
        remote.OnClientEvent:Connect(function(snapshot)
            if workspace:GetAttribute("OvertakeDiagnostics") ~= true then return end
            local predicted = samples[snapshot.Tick]
            print("[Overtake state] authoritative tick", snapshot.Tick, "momentum", snapshot.Momentum,
                "predicted at same tick", predicted, "delta", predicted and predicted - snapshot.Momentum,
                "resimulated callbacks", resimulated, "corrections", corrections,
                "invalid input frames", snapshot.Invalid, "wall run", snapshot.WallRun, "slide", snapshot.Slide)
        end)
    end
    if not server then
        RunService:BindToSimulation(function()
            local c = simulation.GetCharacter(Players.LocalPlayer)
            if not c then return end
            if sampledCharacter ~= c.Character then
                sampledCharacter = c.Character
                table.clear(samples)
            end
            if RunService:IsResimulating() then resimulated += 1 end
            -- Diagnostic memory is intentionally NOT gameplay state. Preserve
            -- the first prediction to compare against later server snapshots.
            if samples[c.SimulationTick] == nil then samples[c.SimulationTick] = c.MomentumUnit end
            samples[c.SimulationTick - 600] = nil
        end, Enum.StepFrequency.Hz60, 2100)
    else
        local elapsed = 0
        RunService.Heartbeat:Connect(function(dt)
            elapsed += dt
            if elapsed < 0.25 then return end
            elapsed = 0
            for _, player in ipairs(Players:GetPlayers()) do
                local c = simulation.GetCharacter(player)
                if c then
                    remote:FireClient(player, {Tick = c.SimulationTick, Momentum = c.MomentumUnit,
                        Invalid = c.InvalidInputs, WallRun = c.isWallRunning, Slide = c.isSliding})
                end
            end
        end)
    end
    -- Simulation exceptions remain visible in Studio Output with their full
    -- stack; they are never swallowed or converted into accepted gameplay.
end
return Diagnostics
