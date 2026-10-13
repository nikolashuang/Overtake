local Inputs = {}
Inputs.Keys = {Forward = Enum.KeyCode.W, Back = Enum.KeyCode.S,
    Left = Enum.KeyCode.A, Right = Enum.KeyCode.D, Space = Enum.KeyCode.Space,
    Shift = Enum.KeyCode.LeftShift, Middle = Enum.KeyCode.MouseMiddleButton}

-- The server creates these under each Player so native input ownership/replay
-- applies. Scriptable bindings carry camera-derived intent, never world state.
function Inputs.Create(player)
    local context = Instance.new("InputContext")
    context.Name = "OvertakeInputs"
    context.Priority = 3000
    context.Sink = true
    context.Enabled = true
    for name, key in pairs(Inputs.Keys) do
        local action = Instance.new("InputAction")
        action.Name = name
        action.Type = Enum.InputActionType.Bool
        action.Enabled = true
        local binding = Instance.new("InputBinding")
        binding.KeyCode = key
        binding.Parent = action
        action.Parent = context
    end
    for _, name in ipairs({"Move", "CameraLocked"}) do
        local action = Instance.new("InputAction")
        action.Name = name
        action.Type = name == "Move" and Enum.InputActionType.Direction3D or Enum.InputActionType.Bool
        action.Enabled = true
        local binding = Instance.new("InputBinding")
        binding.Name = "Intent"
        binding.Type = Enum.InputBindingType.Scriptable
        binding.Parent = action
        action.Parent = context
    end
    context.Parent = player
    return context
end

function Inputs.Bind(player)
    local context = player:WaitForChild("OvertakeInputs")
    local actions = {}
    for name in pairs(Inputs.Keys) do actions[name] = context:WaitForChild(name) end
    actions.Move = context:WaitForChild("Move")
    actions.CameraLocked = context:WaitForChild("CameraLocked")
    return actions
end

function Inputs.Read(actions)
    local input = {}
    local invalid = false
    for name in pairs(Inputs.Keys) do
        local value = actions[name]:GetState()
        if type(value) ~= "boolean" then invalid = true end
        input[name] = value == true
    end
    input.CameraLocked = actions.CameraLocked:GetState() == true
    local move = actions.Move:GetState()
    if typeof(move) ~= "Vector3" or move.X ~= move.X or move.Y ~= move.Y or move.Z ~= move.Z
        or math.abs(move.X) == math.huge or math.abs(move.Y) == math.huge or math.abs(move.Z) == math.huge then
        move = Vector3.zero
        invalid = true
    end
    if math.abs(move.Y) > 0.001 or move.Magnitude > 1.001 then
        invalid = true
        move = Vector3.zero
    end
    move = Vector3.new(move.X, 0, move.Z)
    if move.Magnitude > 1 then move = move.Unit end
    input.Move = move
    input.Invalid = invalid
    return input
end
return Inputs
