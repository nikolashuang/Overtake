local ParkourObjectsConfig = {}

local function CreateRaycastBeam(parentPart)
    local startAttachment = Instance.new("Attachment")
    startAttachment.Parent = parentPart

    local endAttachment = Instance.new("Attachment")
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

function ParkourObjectsConfig.DetectVaultObj(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")

    local MAX_VAULT_HEIGHT = 6
    local BUFFER_CHECK = 3
    local CastHeight = MAX_VAULT_HEIGHT + BUFFER_CHECK

    if humanoid.MoveDirection.Magnitude == 0 then return end

    local params = RaycastParams.new()

    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}

    local distance = 5

    if not debugWaistBeam and not debugHeadBeam then
        debugWaistBeam = CreateRaycastBeam(root)
        debugHeadBeam = CreateRaycastBeam(head)
    end

    local currentMoveDirection = root.CFrame.LookVector * distance

    debugWaistBeam.Position = currentMoveDirection
    debugHeadBeam.Position = currentMoveDirection


    local waistDetection = workspace:Raycast(root.Position, root.CFrame.LookVector * distance, params)
    local headDetection = workspace:Raycast(head.Position, root.CFrame.LookVector * distance, params)

    if waistDetection and headDetection then
        if waistDetection.Instance ~= headDetection.Instance then return nil end

        local aboveDetection = waistDetection.Position + humanoid.MoveDirection * 0.5 + Vector3.new(0, CastHeight, 0)
        local downCastResult = workspace:Raycast(aboveDetection, humanoid.MoveDirection.Unit * 1, params)

        if not downCastResult or downCastResult.Instance ~= waistDetection.Instance then
            return nil
        end

        return downCastResult.Instance

    elseif waistDetection and not headDetection then
        return waistDetection.Instance
    end

    return nil

end

return ParkourObjectsConfig