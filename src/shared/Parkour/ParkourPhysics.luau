local RepStorage = game:GetService("ReplicatedStorage")
local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)

local ParkourPhysics = {}

-- DEBUG TOOLS --
local function CreateRaycastBeam(parentPart, startPosition)
    local startAttachment = Instance.new("Attachment")
    startAttachment.Position = startPosition or Vector3.zero
    startAttachment.Parent = parentPart

    local endAttachment = Instance.new("Attachment")
    endAttachment.Position = startPosition or Vector3.zero
    endAttachment.Parent = parentPart

    local beam = Instance.new("Beam")
    beam.Attachment0 = startAttachment
    beam.Attachment1 = endAttachment
    beam.Width0 = 0.08
    beam.Width1 = 0.08
    beam.Parent = parentPart

    return endAttachment
end

local debugWaistBeam = nil
local debugHeadBeam = nil
local debugKneeBeam = nil
-----------------------------------------

function ParkourPhysics.DetectObstacle(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")

    if not root or not humanoid then return nil end

    local VAULT_DISTANCE = ParkourConfig.Vault.VAULT_DISTANCE

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

    if not debugWaistBeam and not debugHeadBeam and not debugKneeBeam then
        debugWaistBeam = CreateRaycastBeam(root, stableRootOffset)
        debugHeadBeam = CreateRaycastBeam(root, stableHeadOffset)
        debugKneeBeam = CreateRaycastBeam(root, stableKneeOffset)
    end

    local localMoveDirection = Vector3.new(0, 0, -VAULT_DISTANCE)

    debugWaistBeam.Position = localMoveDirection + stableRootOffset
    debugHeadBeam.Position = localMoveDirection + stableHeadOffset
    debugKneeBeam.Position = localMoveDirection + stableKneeOffset


    local waistDetection = workspace:Raycast(stableRootPosition, root.CFrame.LookVector * VAULT_DISTANCE, params)
    local headDetection = workspace:Raycast(stableHeadPosition, root.CFrame.LookVector * VAULT_DISTANCE, params)
    local kneeDetection = workspace:Raycast(stableKneePosition, root.CFrame.LookVector * VAULT_DISTANCE, params)

    if headDetection then return nil end

    if waistDetection then
        return waistDetection.Instance, "Vault"
    elseif not waistDetection and kneeDetection then
        return kneeDetection.Instance, "Hurdle"
    end

    return nil

end


return ParkourPhysics