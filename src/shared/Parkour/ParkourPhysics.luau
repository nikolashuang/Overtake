local ParkourPhysics = {}

-- DEBUG TOOLS --

ParkourPhysics.debugMode = true

local debugVaultBeams = {
    debugWaistBeam = nil,
    debugHeadBeam = nil,
    debugKneeBeam = nil,
}

local debugWallRunBeams = {
    debugWaistRightBeam = nil,
    debugWaistLeftBeam = nil,
    debugKneeRightBeam = nil,
    debugKneeLeftBeam = nil
}



local function CreateRaycastBeam(parentPart, startPosition)
    local startAttachment = Instance.new("Attachment")
    startAttachment.Name = "DebugAttachment"
    startAttachment.Position = startPosition or Vector3.zero
    startAttachment.Parent = parentPart

    local endAttachment = Instance.new("Attachment")
    endAttachment.Name = "DebugAttachment"
    endAttachment.Position = startPosition or Vector3.zero
    endAttachment.Parent = parentPart

    local beam = Instance.new("Beam")
    beam.Name = "DebugBeam"
    beam.Attachment0 = startAttachment
    beam.Attachment1 = endAttachment
    beam.Width0 = 0.08
    beam.Width1 = 0.08
    beam.Parent = parentPart

    return endAttachment
end

function ParkourPhysics.DestroyRaycastBeams(character)
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    for _, child in pairs(rootPart:GetChildren()) do
        if child.Name == "DebugBeam" or child.Name == "DebugAttachment" then
            child:Destroy()
        end
    end

    for i in pairs(debugVaultBeams) do
        debugVaultBeams[i] = nil
    end

    for i in pairs(debugWallRunBeams) do
        debugWallRunBeams[i] = nil
    end
end
-----------------------------------------

local function validateHit(result)
    if not result then return nil end

    local model = result.Instance:FindFirstAncestorOfClass("Model")

    if model and model:FindFirstChildOfClass("Humanoid") then
        return nil
    end

    return result
end


function ParkourPhysics.DetectObstacle(character, vaultDistance)
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")

    if not root or not humanoid then return nil end

    local VAULT_DISTANCE = vaultDistance

    if humanoid.MoveDirection.Magnitude == 0 then return end

    local params = RaycastParams.new()

    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}

	local stableHeadOffset = Vector3.new(0, 1.8, 0)
	local stableRootOffset = Vector3.new(0, -0.6, 0)
    local stableKneeOffset = Vector3.new(0, -2, 0)
    local stableHeadPosition = root.CFrame:PointToWorldSpace(stableHeadOffset)
	local stableRootPosition = root.CFrame:PointToWorldSpace(stableRootOffset)
    local stableKneePosition = root.CFrame:PointToWorldSpace(stableKneeOffset)


    if ParkourPhysics.debugMode and next(debugVaultBeams) == nil then
        debugVaultBeams.debugWaistBeam = CreateRaycastBeam(root, stableRootOffset)
        debugVaultBeams.debugHeadBeam = CreateRaycastBeam(root, stableHeadOffset)
        debugVaultBeams.debugKneeBeam = CreateRaycastBeam(root, stableKneeOffset)
    end

    local localMoveDirection = Vector3.new(0, 0, -VAULT_DISTANCE)

    if next(debugVaultBeams) ~= nil then
        debugVaultBeams.debugWaistBeam.Position = localMoveDirection + stableRootOffset
        debugVaultBeams.debugHeadBeam.Position = localMoveDirection + stableHeadOffset
        debugVaultBeams.debugKneeBeam.Position = localMoveDirection + stableKneeOffset
    end


    local waistDetection = validateHit(workspace:Raycast(stableRootPosition, root.CFrame.LookVector * VAULT_DISTANCE, params))
    local headDetection = validateHit(workspace:Raycast(stableHeadPosition, root.CFrame.LookVector * VAULT_DISTANCE, params))
    local kneeDetection = validateHit(workspace:Raycast(stableKneePosition, root.CFrame.LookVector * VAULT_DISTANCE, params))

    if headDetection then return nil end

    if waistDetection then
        return waistDetection.Instance, "Vault"
    elseif not waistDetection and kneeDetection then
        return kneeDetection.Instance, "Hurdle"
    end

    return nil

end


function ParkourPhysics.DetectWallRuns(character, attachDistance)
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")

    if not humanoid or not root then return end

    local WALL_ATTACH_DISTANCE = attachDistance

    if humanoid.MoveDirection.Magnitude == 0 then return end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}

	local stableRootOffset = Vector3.new(0, 0.6, 0)
    local stableKneeOffset = Vector3.new(0, -2, 0)
	local stableRootPosition = root.CFrame:PointToWorldSpace(stableRootOffset)
    local stableKneePosition = root.CFrame:PointToWorldSpace(stableKneeOffset)

    if ParkourPhysics.debugMode and next(debugWallRunBeams) == nil then
        debugWallRunBeams.debugWaistRightBeam = CreateRaycastBeam(root, stableRootOffset)
        debugWallRunBeams.debugWaistLeftBeam = CreateRaycastBeam(root, stableRootOffset)
        debugWallRunBeams.debugKneeRightBeam = CreateRaycastBeam(root, stableKneeOffset)
        debugWallRunBeams.debugKneeLeftBeam = CreateRaycastBeam(root, stableKneeOffset)
    end

    local localRightDirection = Vector3.new(4, 0, 0)
    local localLeftDirection = Vector3.new(-4, 0, 0)

    if next(debugWallRunBeams) ~= nil then
        debugWallRunBeams.debugWaistRightBeam.Position = localRightDirection + stableRootOffset
        debugWallRunBeams.debugWaistLeftBeam.Position = localLeftDirection + stableRootOffset
        debugWallRunBeams.debugKneeRightBeam.Position = localRightDirection + stableKneeOffset
        debugWallRunBeams.debugKneeLeftBeam.Position = localLeftDirection + stableKneeOffset
    end

    local rightWaistDetection = validateHit(workspace:Raycast(stableRootPosition, root.CFrame.RightVector * WALL_ATTACH_DISTANCE, params))
    local rightKneeDetection = validateHit(workspace:Raycast(stableKneePosition, root.CFrame.RightVector * WALL_ATTACH_DISTANCE, params))

    local leftWaistDetection = validateHit(workspace:Raycast(stableRootPosition, root.CFrame.RightVector * -WALL_ATTACH_DISTANCE, params))
    local leftKneeDetection = validateHit(workspace:Raycast(stableKneePosition, root.CFrame.RightVector * -WALL_ATTACH_DISTANCE, params))
    
    local rightWall = rightKneeDetection and rightWaistDetection and rightKneeDetection.Instance == rightWaistDetection.Instance
    local leftWall = leftKneeDetection and leftWaistDetection and leftKneeDetection.Instance == leftWaistDetection.Instance

    if rightWall then
        return rightWaistDetection, "Right"
    elseif leftWall then
        return leftWaistDetection, "Left"
    end


    return nil
end

return ParkourPhysics