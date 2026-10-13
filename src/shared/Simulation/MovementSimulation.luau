local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CharacterClass = require(script.Parent.Parent.Character.CharacterClass)
local State = require(script.Parent.MovementState)
local Inputs = require(script.Parent.MovementInputs)
local Detection = require(script.Parent.Parent.Parkour.ParkourDetection)
local Config = require(script.Parent.Parent.Parkour.ParkourConfig)
local Simulation = {}
local isServer = RunService:IsServer()
local localPlayer = Players.LocalPlayer
local characters = {}
local connections = {}
local playerConnections = {}
local started = false

function Simulation.CheckFeatures()
    assert(workspace.UseFixedSimulation == Enum.RolloutState.Enabled,
        "Overtake requires Workspace.UseFixedSimulation = Enabled; see NATIVE_AUTHORITY_REPORT.md")
    assert(workspace.NextGenerationReplication == Enum.RolloutState.Enabled and workspace.StreamingEnabled,
        "Enable native replication and streaming before testing Overtake")
    -- These settings have RobloxScriptSecurity in current API metadata. A game
    -- script cannot reliably inspect them; the place file must configure them.
    local readable, mode = pcall(function() return workspace.AuthorityMode end)
    if readable then assert(mode == Enum.AuthorityMode.Server, "Native server authority must be enabled") end
    assert(workspace:GetAttribute("OvertakeNativeAuthority") == true,
        "Use the experimental Rojo project and verify AuthorityMode = Server in Studio")
end

function Simulation.PrepareCharacter(character)
    local root = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.JumpHeight = 2.25
    humanoid.WalkSpeed = Config.Momentum.MIN_MOVE_SPEED
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then part:SetAttribute("OvertakeNormalCollision", part.CanCollide) end
    end
    local attachment = Instance.new("Attachment")
    attachment.Name = "MovementAttachment"
    attachment.Parent = root
    for index = 1, 2 do
        local state = Instance.new("Attachment")
        state.Name = "MovementState" .. index
        state.Parent = root
    end
    local collider = Instance.new("Part")
    collider.Name = "SlideCollider"
    collider.CanCollide = false
    collider.Massless = true
    collider.Transparency = 1
    collider.Size = Vector3.new(3.75, 2, 2.5)
    collider.CFrame = root.CFrame * CFrame.new(0, -2, 0)
    collider.Parent = character
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = collider
    weld.Parent = collider
    for _, name in ipairs(CharacterClass.ConstraintNames) do
        local kind = string.match(name, "_(%a+)_%d+$")
        local constraint = Instance.new(kind)
        constraint.Name = name
        constraint.Attachment0 = attachment
        constraint.Enabled = false
        constraint:SetAttribute("MovementLifetime", true)
        constraint.Parent = root
    end
end

local function space(c)
    c.SpaceAt = time()
    if c.isInLedgeCatch then c:ExitLedgeCatch("Space"); return end
    if c:CanLedgeCatch() then c:LedgeCatch(); return end
    if c:CanWallRun() and not c.isWallRunning then c:StartWallRun(); return end
    if c.isWallRunning then c:EndWallRun(); return end
    if c.isClimbing then
        if time() - c.LeftAt < Config.Climbing.SIDEWAY_INPUT_WINDOW then c:ExtendedClimbBoost("A")
        elseif time() - c.RightAt < Config.Climbing.SIDEWAY_INPUT_WINDOW then c:ExtendedClimbBoost("D") end
        return
    end
    if c:CanClimb() then c:Climb(); return end
    if c:CanLunge() and time() - c.MiddleAt < Config.Boost.LUNGE_WINDOW then c:Lunge(); return end
    if c:CanVault() then c:VaultOrHurdle(); return end
    if c.Humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then c.Humanoid.Jump = true end
end

local function roll(c, timing)
    if not c.RolledLanding and c:CanRecoveryRoll() and timing >= 0 and timing < Config.Recovery.ROLL_WINDOW then
        c:RecoveryRoll(timing)
        c.TempLockSliding = false
        c.RolledLanding = true
        return true
    end
    return false
end

function Simulation.Step(c, input, dt)
    State.Initialize(c.StateParts)
    c.SimulationTick += 1
    if input.Invalid then c.InvalidInputs += 1 end
    c:UpdateConstraintLifetimes()
    local now = time()
    if c.VaultReleaseAt > 0 and now >= c.VaultReleaseAt then
        c.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        c.HaltMomentum = false
        c.VaultReleaseAt = 0
        c.VaultMomentumHold = false
    end
    if c.JumpReleaseAt > 0 and now >= c.JumpReleaseAt then
        c.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        if not c.isClimbing then c.HaltMomentum = false end
        c.JumpReleaseAt = 0
    end
    -- Normal controls are disabled client-side; this is the sole movement writer.
    c.Humanoid:Move(c.isSliding and c.SlideDirection or input.Move, false)
    c:UpdateObject()
    c:UpdateWallRunObj()
    c:CheckOverHang()
    local grounded = c:isGrounded()
    local freefall = c.Humanoid:GetState() == Enum.HumanoidStateType.Freefall
    if freefall and not c.WasFreefall then c.LastUpSpeed = c.RootPart.AssemblyLinearVelocity.Y end
    if grounded and not c.WasGrounded then
        c.ClimbingAConsumed = false
        c.ClimbingDConsumed = false
        c.isClimbing = false
        c.HaltMomentum = false
        c.Landed = now
        c.RolledLanding = false
        c.LandingCheckAt = now + 0.05
        c.SlideUnlockAt = now + 0.75
    end
    c.WasGrounded = grounded
    c.WasFreefall = freefall
    if c.LandingCheckAt > 0 and now >= c.LandingCheckAt then
        roll(c, c.Landed - c.ShiftAt)
        c.LandingCheckAt = 0
    end
    if c.SlideUnlockAt > 0 and now >= c.SlideUnlockAt then
        c.TempLockSliding = false
        c.SlideUnlockAt = 0
    end
    if input.Left and not c.PrevLeft then
        c.LeftAt = now
        if c.isWallRunning then c:WallRedirect("A") end
    end
    if input.Right and not c.PrevRight then
        c.RightAt = now
        if c.isWallRunning then c:WallRedirect("D") end
    end
    if input.Middle and not c.PrevMiddle then c.MiddleAt = now end
    if input.Shift and not c.PrevShift then
        c.ShiftAt = now
        if c.isInLedgeCatch then c:ExitLedgeCatch()
        elseif c.TempLockSliding and grounded and roll(c, now - c.Landed) then
            -- Roll takes priority over a new slide.
        elseif c:CanSlide() then c:Slide() end
    end
    c.Humanoid.Jump = false
    if input.Space and not c.PrevSpace then space(c) end
    if c.isWallRunning then c:UpdateWallRun(input.Forward, dt) end
    if c:CanLedgeCatch() and now - c.SpaceAt < Config.Climbing.LEDGE_CATCH_WINDOW then c:LedgeCatch() end
    c.Humanoid.AutoRotate = not (c.isWallRunning or c.isInLedgeCatch or c.isSliding)
    -- An earlier lunge/vault deadline must not release the momentum hold of
    -- a later wall run, slide, or climb in the same movement chain.
    c.HaltMomentum = c.isSliding or c.isWallRunning or c.isClimbing
        or now < c.JumpReleaseAt or (c.VaultMomentumHold and now < c.VaultReleaseAt)
    c:UpdateMomentum(dt)
    c:UpdateVelocities()
    local maintainSlide = input.Shift and (input.CameraLocked and input.Forward
        or not input.CameraLocked and (input.Forward or input.Left or input.Back or input.Right))
    if c.isSliding then
        if maintainSlide and c.MomentumUnit > 0 then c:SlideDecay(dt) else c:EndSlide() end
    end
    if c.isCrawling and not c.overHangExists then c:CancelCrawl() end
    c.PrevSpace, c.PrevShift, c.PrevMiddle = input.Space, input.Shift, input.Middle
    c.PrevLeft, c.PrevRight = input.Left, input.Right
end

local function refreshIgnored()
    local models = {}
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("Humanoid") and instance.Parent:IsA("Model") then table.insert(models, instance.Parent) end
    end
    Detection.SetIgnoredCharacters(models)
end

local function bindPlayer(player)
    if isServer then Inputs.Create(player) end
    local actions = Inputs.Bind(player)
    local generation = 0
    local function bind(character)
        generation += 1
        local current = generation
        characters[player] = nil
        if isServer then Simulation.PrepareCharacter(character) end
        local c = CharacterClass.new(player, {})
        c:BindCharacter(character)
        if current ~= generation or player.Character ~= character then return end
        if not isServer then
            for _, instance in ipairs(character:GetDescendants()) do
                if instance:IsA("BasePart") or instance:IsA("Constraint") or instance:IsA("Attachment") or instance:IsA("Humanoid") then
                    RunService:SetPredictionMode(instance, Enum.PredictionMode.On)
                end
            end
        end
        characters[player] = {Character = c, Actions = actions}
        refreshIgnored()
    end
    playerConnections[player] = {player.CharacterAdded:Connect(bind), player.CharacterRemoving:Connect(function()
        generation += 1
        characters[player] = nil
    end)}
    if player.Character then task.spawn(bind, player.Character) end
end

function Simulation.GetCharacter(player)
    local entry = characters[player]
    return entry and entry.Character
end

function Simulation.Initialize()
    if started then return end
    Simulation.CheckFeatures()
    started = true
    refreshIgnored()
    table.insert(connections, workspace.DescendantAdded:Connect(function(instance)
        if instance:IsA("Humanoid") then task.defer(refreshIgnored) end
    end))
    if isServer then
        table.insert(connections, Players.PlayerAdded:Connect(bindPlayer))
        table.insert(connections, Players.PlayerRemoving:Connect(function(player)
            characters[player] = nil
            for _, connection in ipairs(playerConnections[player] or {}) do connection:Disconnect() end
            playerConnections[player] = nil
        end))
        for _, player in ipairs(Players:GetPlayers()) do task.spawn(bindPlayer, player) end
    else
        task.spawn(bindPlayer, localPlayer)
    end
    -- No remote state payloads, table snapshots, or custom reconciliation.
    table.insert(connections, RunService:BindToSimulation(function(dt)
        for _, entry in pairs(characters) do Simulation.Step(entry.Character, Inputs.Read(entry.Actions), dt) end
    end, Enum.StepFrequency.Hz60, 2000))
end

function Simulation.Destroy()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, list in pairs(playerConnections) do
        for _, connection in ipairs(list) do connection:Disconnect() end
    end
    table.clear(playerConnections)
    table.clear(connections)
    table.clear(characters)
    started = false
end
return Simulation
