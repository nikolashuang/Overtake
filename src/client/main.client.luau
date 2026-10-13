local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local Simulation = require(RepStorage.Shared.Simulation.MovementSimulation)
local Inputs = require(RepStorage.Shared.Simulation.MovementInputs)
local Presentation = require(script.Parent.Controllers.MovementPresentation)
local Diagnostics = require(RepStorage.Shared.Simulation.MovementDiagnostics)
local player = Players.LocalPlayer

Simulation.Initialize()
Diagnostics.Initialize(Simulation)
-- StarterPlayer movement modes are Scriptable in the project. This disables
-- default movement on both server and client while retaining Roblox's camera.
local actions = Inputs.Bind(player)
local moveBinding = actions.Move:WaitForChild("Intent")
local lockBinding = actions.CameraLocked:WaitForChild("Intent")

RunService:BindToRenderStep("OvertakeMovementIntent", Enum.RenderPriority.Input.Value + 1, function()
    local camera = workspace.CurrentCamera
    local focused = UserInput:GetFocusedTextBox() ~= nil
    local x = (actions.Right:GetState() and 1 or 0) - (actions.Left:GetState() and 1 or 0)
    local z = (actions.Forward:GetState() and 1 or 0) - (actions.Back:GetState() and 1 or 0)
    local move = Vector3.zero
    if camera and not focused then
        local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        if forward.Magnitude < 0.0001 then
            forward = Vector3.new(-camera.CFrame.UpVector.X, 0, -camera.CFrame.UpVector.Z)
        end
        if forward.Magnitude > 0.0001 then
            forward = forward.Unit
            move = forward * z + forward:Cross(Vector3.yAxis) * x
            if move.Magnitude > 1 then move = move.Unit end
        end
    end
    moveBinding:Fire(move)
    lockBinding:Fire(UserInput.MouseBehavior == Enum.MouseBehavior.LockCenter)
end)

RunService.PreRender:Connect(function()
    local character = Simulation.GetCharacter(player)
    if character then Presentation.Update(character) end
end)

