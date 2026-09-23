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


-----------------------------------------

local debugWaistBeam = nil
local debugHeadBeam = nil

function ParkourPhysics.DetectObstacle(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")

    if not root or humanoid then return nil end

    local MAX_VAULT_HEIGHT = ParkourConfig.Vault.MAX_VAULT_HEIGHT
    local VAULT_DISTANCE = ParkourConfig.Vault.VAULT_DISTANCE
    local BUFFER_CHECK = ParkourConfig.Vault.BUFFER_CHECK
    local CastHeight = MAX_VAULT_HEIGHT + BUFFER_CHECK

    if humanoid.MoveDirection.Magnitude == 0 then return end

    local params = RaycastParams.new()

    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}

	local stableHeadOffset = Vector3.new(0, 2.29, 0)
	local stableRootOffset = Vector3.new(0, -1, 0)
    local stableHeadPosition = root.CFrame:PointToWorldSpace(stableHeadOffset)
	local stableRootPosition = root.CFrame:PointToWorldSpace(stableRootOffset)

    if not debugWaistBeam and not debugHeadBeam then
        debugWaistBeam = CreateRaycastBeam(root, stableRootOffset)
        debugHeadBeam = CreateRaycastBeam(root, stableHeadOffset)
    end

    local localMoveDirection = Vector3.new(0, 0, -VAULT_DISTANCE)

    debugWaistBeam.Position = localMoveDirection + stableRootOffset
    debugHeadBeam.Position = localMoveDirection + stableHeadOffset


    local waistDetection = workspace:Raycast(stableRootPosition, root.CFrame.LookVector * VAULT_DISTANCE, params)
    local headDetection = workspace:Raycast(stableHeadPosition, root.CFrame.LookVector * VAULT_DISTANCE, params)

    if waistDetection and headDetection then
        if waistDetection.Instance ~= headDetection.Instance then return nil end

        local aboveDetection = waistDetection.Position + root.CFrame.LookVector * 0.5 + Vector3.new(0, CastHeight, 0)
        local downCastResult = workspace:Raycast(aboveDetection, Vector3.new(0, -CastHeight, 0), params)

        if not downCastResult or downCastResult.Instance ~= waistDetection.Instance then return nil end

        return downCastResult.Instance, "Both"
    elseif waistDetection and not headDetection then
        return waistDetection.Instance, "Waist"
    elseif not waistDetection and headDetection then
        return headDetection.Instance, "Head"
    end

    return nil

end


return ParkourPhysics