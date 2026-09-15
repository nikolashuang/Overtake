local ParkourObjectsConfig = {}

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

    local waistDetection = workspace:Raycast(root.Position, humanoid.MoveDirection.Unit * distance, params)
    local headDetection = workspace:Raycast(head.Position, humanoid.MoveDirection.Unit * distance, params)

    if waistDetection and headDetection then
        if waistDetection.Instance ~= headDetection.Instance then return nil end

        local aboveDetection = waistDetection.Position + humanoid.MoveDirection * 0.5 + Vector3.new(0, -CastHeight, 0)
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