local function character()
    local c = CharacterClass.new({}, {})
    c.StateParts = {attributeInstance(), attributeInstance()}
    State.Initialize(c.StateParts)
    c.RootPart = {AssemblyLinearVelocity = Vector3.new(0,0,-37), Position = Vector3.zero,
        CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(0,0,-1))}
    c.Humanoid = {MoveDirection = Vector3.new(0,0,-1), FloorMaterial = Enum.Material.Concrete,
        state = Enum.HumanoidStateType.Running, jumpEnabled = true}
    function c.Humanoid:GetState() return self.state end
    function c.Humanoid:SetStateEnabled(_, enabled) self.jumpEnabled = enabled end
    function c.Humanoid:GetStateEnabled() return self.jumpEnabled end
    function c.Humanoid:Move(direction) self.MoveDirection = direction end
    c.Character = {FindFirstChild = function(_,name)
        if name == "HumanoidRootPart" then return c.RootPart elseif name == "Humanoid" then return c.Humanoid end
    end}
    c.Constraints = {}
    c.RootPart.pool = {}
    function c.RootPart:FindFirstChild(name) return self.pool[name] or c.Constraints[name] end
    function c.RootPart:GetChildren()
        local children = {}
        for _,constraint in pairs(c.Constraints) do table.insert(children,constraint) end
        for _,constraint in pairs(self.pool) do table.insert(children,constraint) end
        return children
    end
    for _, name in ipairs(CharacterClass.ConstraintNames) do
        c.Constraints[name] = attributeInstance()
        c.Constraints[name]:SetAttribute("MovementLifetime",true)
    end
    c.WallRunAlignment = c.Constraints.StartWallRun_AlignOrientation_1
    c.LedgeAlignPosition = c.Constraints.LedgeCatch_AlignPosition_1
    c.LedgeAlignOrientation = c.Constraints.LedgeCatch_AlignOrientation_1
    c.SlideCollider = {CanCollide = false}
    c.CollisionParts = {{Part = {CanCollide = true}, Normal = true}, {Part = {CanCollide = false}, Normal = false}}
    c.AnimationController = {PlayAnimation = function(group,name) c:EmitAnimation(group,name) end,
        StopAnimation = function() end, PlayStartWallRun = function() c:EmitAnimation("ParkourAnims","RightStartWallRunAnim") end}
    c.ForwardVelocity = 37
    return c
end
local function input(values)
    local result = {Move = Vector3.new(0,0,-1), Forward = true, Back = false,
        Left = false, Right = false, Shift = false, Space = false, Middle = false,
        CameraLocked = false, Invalid = false}
    for key,value in pairs(values or {}) do result[key] = value end
    return result
end
local function step(c,values,dt)
    clock += dt or 1/60
    rayResults,rayIndex = {},0
    Simulation.Step(c,input(values),dt or 1/60)
end
local function snapshot(c)
    local result = {parts = {}, constraints = {}, velocity = c.RootPart.AssemblyLinearVelocity,
        grounded = c.Humanoid.FloorMaterial, state = c.Humanoid.state, jumpEnabled = c.Humanoid.jumpEnabled,
        collider = c.SlideCollider.CanCollide, collision = {}}
    for i,part in ipairs(c.StateParts) do result.parts[i] = table.clone(part.attributes) end
    for name,object in pairs(c.Constraints) do
        result.constraints[name] = {attributes = table.clone(object.attributes), Enabled = object.Enabled,
            VectorVelocity = object.VectorVelocity, CFrame = object.CFrame, Position = object.Position}
    end
    for i,entry in ipairs(c.CollisionParts) do result.collision[i] = entry.Part.CanCollide end
    return result
end
local function restore(c,saved)
    for i,part in ipairs(c.StateParts) do part.attributes = table.clone(saved.parts[i]) end
    for name,values in pairs(saved.constraints) do
        local object = c.Constraints[name]
        object.attributes = table.clone(values.attributes)
        object.Enabled,object.VectorVelocity,object.CFrame,object.Position = values.Enabled,values.VectorVelocity,values.CFrame,values.Position
    end
    c.RootPart.AssemblyLinearVelocity = saved.velocity
    c.Humanoid.FloorMaterial,c.Humanoid.state,c.Humanoid.jumpEnabled = saved.grounded,saved.state,saved.jumpEnabled
    c.SlideCollider.CanCollide = saved.collider
    for i,entry in ipairs(c.CollisionParts) do entry.Part.CanCollide = saved.collision[i] end
end

test("momentum ramp uses unchanged 60 Hz formulas", function()
    local c = character()
    for _=1,60 do c:UpdateMomentum(1/60) end
    close(c.MomentumUnit,10.9)
    close(c.RisingMomentum,17)
    close(c.Humanoid.WalkSpeed,14.725)
end)
test("stationary grace and consumption", function()
    local c = character()
    c.MomentumUnit,c.Stationary = 80,0.5
    c.Humanoid.MoveDirection = Vector3.zero
    c:UpdateMomentum(0.25)
    close(c.MomentumUnit,80)
    c:UpdateMomentum(0.25)
    close(c.MomentumUnit,67.5)
    c:ConsumeMomentum(35)
    close(c.MomentumUnit,32.5)
    close(c.RisingMomentum,5)
end)
test("lunge preserves high forward velocity without cap", function()
    local c = character()
    c.MomentumUnit = 100
    c.RootPart.AssemblyLinearVelocity = Vector3.new(0,0,-120)
    assert(c:CanLunge())
    c:Lunge()
    close(c.Constraints.Lunge_LinearVelocity_1.VectorVelocity.Z,-150)
    close(c.Constraints.Lunge_LinearVelocity_1.VectorVelocity.Y,15)
    close(c.MomentumUnit,65)
    assert(not c:CanLunge())
    clock += Config.Boost.LUNGE_CD
    assert(c:CanLunge())
end)
test("lunge to wall run transfers full tangent speed", function()
    local c = character()
    c.MomentumUnit = 100
    c.RootPart.AssemblyLinearVelocity = Vector3.new(0,0,-120)
    c:Lunge()
    c.RootPart.AssemblyLinearVelocity = c.Constraints.Lunge_LinearVelocity_1.VectorVelocity
    c.Humanoid.FloorMaterial,c.Humanoid.state = Enum.Material.Air,Enum.HumanoidStateType.Freefall
    c.WallObject,c.WallDirection,c.ableWallRun = {Normal = Vector3.xAxis},"Right",true
    assert(c:CanWallRun())
    c:StartWallRun()
    c:UpdateWallRun(true,1/60)
    close(c.WallRunSpeed,150)
    close(c.RootPart.AssemblyLinearVelocity.Z,-150)
    c.InWallRunTime = Config.WallRun.WALL_RUN_WINDOW
    c:UpdateWallRun(true,1/60)
    assert(c.nowWallDrifting)
    close(c.MomentumUnit,65-33/60)
end)
test("slide and crawl restore normal collision", function()
    local c = character()
    c.MomentumUnit = 100
    step(c,{Shift = true})
    assert(c.isSliding and c.SlideCollider.CanCollide)
    close(c.MomentumUnit,100-50/60)
    c.overHangExists = true
    c:EndSlide()
    assert(c.isCrawling and c.SlideCollider.CanCollide)
    c:UpdateMomentum(1/60)
    close(c.Humanoid.WalkSpeed,5)
    close(c.MomentumUnit,0)
    c:CancelCrawl()
    assert(not c.isCrawling and not c.SlideCollider.CanCollide)
    assert(c.CollisionParts[1].Part.CanCollide and not c.CollisionParts[2].Part.CanCollide)
end)
test("slide direction remains locked after steering", function()
    local c = character()
    c.MomentumUnit = 100
    step(c,{Shift = true})
    step(c,{Shift = true,Move = Vector3.xAxis})
    close(c.Humanoid.MoveDirection.Z,-1)
    close(c.Humanoid.MoveDirection.X,0)
    step(c,{Shift = false})
    assert(not c.isSliding)
end)
test("vault and hurdle detection keeps original ray classification", function()
    local c = character()
    local hit = {Instance = {Size = Vector3.new(3,3,3)}, Normal = Vector3.zAxis,Position = Vector3.zero}
    rayResults,rayIndex = {[1]=hit},0
    local _,kind = Detection.DetectObstacle(c.Character,8)
    assert(kind == "Vault")
    c.traversalObj,c.traversalType = hit,kind
    c:VaultOrHurdle()
    close(c.Constraints.VaultOrHurdle_LinearVelocity_1.VectorVelocity.Z,-52)
    rayResults,rayIndex = {[3]=hit},0
    _,kind = Detection.DetectObstacle(c.Character,8)
    assert(kind == "Hurdle")
    rayResults,rayIndex = {[1]=hit,[2]=hit,[4]=hit},0
    _,kind = Detection.DetectObstacle(c.Character,8)
    assert(kind == "Climb")
    rayResults,rayIndex = {[1]=hit,[2]=hit},0
    _,kind = Detection.DetectObstacle(c.Character,8)
    assert(kind == "LedgeCatch")
end)
test("humanoid models excluded before raycasting", function()
    local c = character()
    local npc = {}
    Detection.SetIgnoredCharacters({npc})
    rayResults,rayIndex = {},0
    Detection.DetectObstacle(c.Character,8)
    assert(rayParams.FilterDescendantsInstances[1] == npc)
    assert(rayParams.FilterDescendantsInstances[2] == c.Character)
end)
test("extended climbing consumes each side once", function()
    local c = character()
    c.traversalObj,c.traversalType = {Normal = Vector3.zAxis},"Climb"
    assert(c:CanClimb())
    c:Climb()
    c:ExtendedClimbBoost("A")
    local count = c.AnimationSequence
    assert(c.ClimbingAConsumed)
    c:ExtendedClimbBoost("A")
    assert(c.AnimationSequence == count)
    c:ExtendedClimbBoost("D")
    assert(c.ClimbingDConsumed)
    close(c.Constraints.ExtendedClimbBoost_LinearVelocity_2.VectorVelocity.Y,40)
    assert(c.Constraints.ExtendedClimbBoost_LinearVelocity_1.Enabled)
    assert(c.Constraints.ExtendedClimbBoost_LinearVelocity_2.Enabled)
end)
test("recovery roll windows and repeated landing protection", function()
    local c = character()
    c.MomentumUnit,c.LastFallSpeed,c.WasGrounded = 100,-100,false
    c.ShiftAt = clock-0.05
    step(c)
    for _=1,4 do step(c) end
    assert(c.RolledLanding)
    local count = c.AnimationSequence
    c.MomentumUnit = 20 -- prevent a legitimate new slide from replacing the roll animation
    step(c,{Shift=true})
    assert(c.AnimationSequence == count)
    c.MomentumUnit = 100
    c:RecoveryRoll(0.1)
    close(c.MomentumUnit,70)
    c.LastFallSpeed = -191
    assert(not c:CanRecoveryRoll())
end)
test("invalid redirect never enables a constraint", function()
    local c = character()
    c.WallDirection = "Right"
    c:WallRedirect("D")
    assert(not c.Constraints.WallRedirect_LinearVelocity_1.Enabled)
    c:WallRedirect("A")
    assert(c.Constraints.WallRedirect_LinearVelocity_1.Enabled)
end)
test("constraint expiry follows simulation time", function()
    local c = character()
    c.MomentumUnit = 100
    c:Lunge()
    clock += 0.31
    c:UpdateConstraintLifetimes()
    assert(not c.Constraints.Lunge_LinearVelocity_1.Enabled)
    assert(not c.Constraints.Lunge_AlignOrientation_1.Enabled)
end)
test("rewind and replay reproduces edges, cooldowns, momentum, and expiry", function()
    local c = character()
    c.MomentumUnit = 100
    local saved,origin = snapshot(c),clock
    local function run()
        step(c,{Middle=true})
        step(c,{Space=true})
        for _=1,40 do step(c) end
        return snapshot(c)
    end
    local first = run()
    restore(c,saved)
    clock = origin
    local replay = run()
    for _,key in ipairs(State.Keys) do
        local index = c.StateParts[1].attributes[key] ~= nil and 1 or 2
        assert(first.parts[index][key] == replay.parts[index][key],key .. " differs on replay")
    end
    assert(first.constraints.Lunge_LinearVelocity_1.Enabled == replay.constraints.Lunge_LinearVelocity_1.Enabled)
    close(c.MomentumUnit,66.1) -- gain resumes and RisingMomentum ramps after the lunge hold
    close(c.LastLunge,origin+2/60)
end)
test("native input sanitization rejects nonfinite and oversized vectors", function()
    local actions = {}
    for name in pairs(Inputs.Keys) do actions[name] = {GetState = function() return false end} end
    actions.CameraLocked = {GetState = function() return false end}
    actions.Move = {GetState = function() return Vector3.new(0/0,0,0) end}
    local read = Inputs.Read(actions)
    assert(read.Invalid and read.Move.Magnitude == 0)
    actions.Move.GetState = function() return Vector3.new(4,0,0) end
    read = Inputs.Read(actions)
    assert(read.Invalid and read.Move.Magnitude == 0)
    actions.Move.GetState = function() return Vector3.new(0.6,0,0.8) end
    read = Inputs.Read(actions)
    assert(not read.Invalid)
    close(read.Move.Magnitude,1)
end)
test("ledge catch cost and exit constraint lifecycle", function()
    local c = character()
    c.MomentumUnit,c.FreefallSpeed = 100,-100
    c.Humanoid.FloorMaterial = Enum.Material.Air
    c.traversalObj,c.traversalType = {Normal = Vector3.zAxis,Position = Vector3.zero},"LedgeCatch"
    rayResults,rayIndex = {{Normal = Vector3.yAxis,Position = Vector3.new(0,5,0)}},0
    assert(c:CanLedgeCatch())
    c:LedgeCatch()
    close(c.MomentumUnit,25)
    assert(c.isInLedgeCatch and c.LedgeAlignPosition.Enabled and c.LedgeAlignOrientation.Enabled)
    c:ExitLedgeCatch("Space")
    assert(not c.isInLedgeCatch and not c.LedgeAlignPosition.Enabled and not c.LedgeAlignOrientation.Enabled)
    assert(c.Constraints.ExitLedgeCatch_LinearVelocity_1.Enabled)
    close(c.Constraints.ExitLedgeCatch_LinearVelocity_1.VectorVelocity.Y,15)
end)
test("new character has no cooldown or input state from a prior life", function()
    local first = character()
    first.LastLunge,first.PrevSpace,first.MomentumUnit,first.isSliding = clock,true,90,true
    local nextCharacter = character()
    close(nextCharacter.LastLunge,0)
    close(nextCharacter.MomentumUnit,0)
    assert(not nextCharacter.PrevSpace and not nextCharacter.isSliding)
end)
test("ordinary vault keeps momentum gain; tall vault holds it", function()
    local c = character()
    c.MomentumUnit = 50
    c.traversalObj,c.traversalType = {Instance = {Size = Vector3.new(3,3,3)}},"Vault"
    c:VaultOrHurdle()
    step(c)
    assert(not c.HaltMomentum)
    assert(c.MomentumUnit > 50)
    c.traversalObj,c.traversalType = {Instance = {Size = Vector3.new(3,4,3)}},"Vault"
    c:VaultOrHurdle()
    local momentum = c.MomentumUnit
    step(c)
    assert(c.HaltMomentum)
    close(c.MomentumUnit,momentum)
end)
test("lunge deadline cannot clear a subsequent wall-run hold", function()
    local c = character()
    c.MomentumUnit = 100
    c:Lunge()
    c.RootPart.AssemblyLinearVelocity = c.Constraints.Lunge_LinearVelocity_1.VectorVelocity
    c.Humanoid.FloorMaterial,c.Humanoid.state = Enum.Material.Air,Enum.HumanoidStateType.Freefall
    c.WallObject,c.WallDirection,c.ableWallRun = {Normal = Vector3.xAxis},"Right",true
    c:StartWallRun()
    c.UpdateWallRunObj = function(self)
        self.WallObject,self.WallDirection,self.ableWallRun = {Normal = Vector3.xAxis},"Right",true
    end
    for _=1,40 do step(c) end
    assert(c.isWallRunning and c.HaltMomentum)
    close(c.MomentumUnit,65)
end)
test("overlapping redirects use native clone slots and reuse them after expiry", function()
    local c = character()
    c.WallDirection = "Right"
    c:WallRedirect("A")
    c:WallRedirect("A")
    local pooled = c.RootPart:FindFirstChild("WallRedirect_LinearVelocity_1_Pool1")
    assert(pooled and pooled.Enabled and c.Constraints.WallRedirect_LinearVelocity_1.Enabled)
    clock += 0.31
    c:UpdateConstraintLifetimes()
    assert(not pooled.Enabled)
    c:WallRedirect("A")
    c:WallRedirect("A")
    assert(c.RootPart:FindFirstChild("WallRedirect_LinearVelocity_1_Pool1") == pooled)
    assert(c.RootPart:FindFirstChild("WallRedirect_LinearVelocity_1_Pool2") == nil)
end)
test("rollback of the instance graph does not retain a speculative pool handle", function()
    local c = character()
    c.WallDirection = "Right"
    c:WallRedirect("A")
    local saved = snapshot(c)
    c:WallRedirect("A")
    local speculative = c.RootPart:FindFirstChild("WallRedirect_LinearVelocity_1_Pool1")
    restore(c,saved)
    c.RootPart.pool = {} -- model native graph rollback of an unconfirmed clone
    c:WallRedirect("A")
    local replayed = c.RootPart:FindFirstChild("WallRedirect_LinearVelocity_1_Pool1")
    assert(replayed and replayed ~= speculative and replayed.Enabled)
end)
print(string.format("%d movement regression tests passed (engine test doubles; no Roblox physics/network execution)",passed))






