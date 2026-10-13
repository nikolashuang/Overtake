local Detection = {}
local ignoredCharacters = {}

-- Humanoid-model identities are collected outside simulation. Ancestry/class
-- inspection is not simulation-access; the ray geometry itself is recomputed.
function Detection.SetIgnoredCharacters(characters)
    ignoredCharacters = characters
end
local function paramsFor(character)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excluded = table.clone(ignoredCharacters)
    table.insert(excluded, character)
    params.FilterDescendantsInstances = excluded
    return params
end

function Detection.DetectObstacle(character, vaultDistance)
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not root or not humanoid or humanoid.MoveDirection.Magnitude == 0 then return nil end
    local params = paramsFor(character)
    local function cast(offset, distance)
        return workspace:Raycast(root.CFrame:PointToWorldSpace(offset), root.CFrame.LookVector * distance, params)
    end
    local waist = cast(Vector3.new(0, -0.6, 0), vaultDistance)
    local head = cast(Vector3.new(0, 1.8, 0), vaultDistance)
    local knee = cast(Vector3.new(0, -2, 0), vaultDistance)
    local climb = cast(Vector3.new(0, 3, 0), 5)
    if waist and head and climb then return climb, "Climb" end
    if waist and head and not climb then return head, "LedgeCatch" end
    if waist then return waist, "Vault" end
    if knee then return knee, "Hurdle" end
    return nil
end

function Detection.DetectWallRuns(character, attachDistance)
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not root or not humanoid or humanoid.MoveDirection.Magnitude == 0 then return nil end
    local params = paramsFor(character)
    local waist = root.CFrame:PointToWorldSpace(Vector3.new(0, 0.6, 0))
    local knee = root.CFrame:PointToWorldSpace(Vector3.new(0, -2, 0))
    local right = root.CFrame.RightVector * attachDistance
    local rw = workspace:Raycast(waist, right, params)
    local rk = workspace:Raycast(knee, right, params)
    local lw = workspace:Raycast(waist, -right, params)
    local lk = workspace:Raycast(knee, -right, params)
    if rw and rk and rw.Instance == rk.Instance then return rw, "Right" end
    if lw and lk and lw.Instance == lk.Instance then return lw, "Left" end
    return nil
end

function Detection.DetectSlideOverHang(character, distance)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local origin = root.CFrame:PointToWorldSpace(Vector3.new(0, -1.7, 0))
    return workspace:Raycast(origin, root.CFrame.UpVector * distance, paramsFor(character)) ~= nil
end

function Detection.DetectPreciseLedgeFrame(character, hit, isNearLedge)
    if not isNearLedge or not hit then return nil end
    local origin = hit.Position - hit.Normal * 0.2 + Vector3.new(0, 4, 0)
    local top = workspace:Raycast(origin, Vector3.new(0, -6, 0), paramsFor(character))
    if not top or top.Normal.Y <= 0.85 then return nil end
    local position = Vector3.new(hit.Position.X, top.Position.Y, hit.Position.Z)
        + hit.Normal * 1.2 + Vector3.new(0, -2, 0)
    return CFrame.lookAt(position, position - hit.Normal)
end
return Detection
