-- Optional disposable Studio geometry. Existing Overtake places leave this off.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() or workspace:GetAttribute("OvertakeTestCourse") ~= true then return end
local course = Instance.new("Model")
course.Name = "NativeAuthorityTestCourse"

local function part(name, size, position, color)
    local object = Instance.new("Part")
    object.Name, object.Size, object.Position = name, size, position
    object.Anchored = true
    object.Color = color or Color3.fromRGB(110, 120, 135)
    object.Parent = course
    return object
end
local function label(object, text)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromOffset(420, 55)
    gui.StudsOffset = Vector3.new(0, object.Size.Y / 2 + 3, 0)
    gui.AlwaysOnTop = true
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.BackgroundTransparency = 0.25
    textLabel.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextSize = 16
    textLabel.Text = text
    textLabel.Parent = gui
    gui.Parent = object
end
part("Floor", Vector3.new(300, 2, 400), Vector3.new(0, -1, -100))
local spawn = Instance.new("SpawnLocation")
spawn.Name, spawn.Size, spawn.Position = "Start", Vector3.new(12, 1, 12), Vector3.new(0, 0.5, 55)
spawn.Anchored, spawn.Neutral = true, true
spawn.Parent = course
label(spawn, "WASD move | Shift slide/roll | MMB then Space lunge")
label(part("Hurdle", Vector3.new(18, 1.5, 2), Vector3.new(0, 0.75, 0)), "Space: hurdle")
label(part("Vault", Vector3.new(18, 3, 2), Vector3.new(0, 1.5, -35)), "Space: vault")
label(part("TallVault", Vector3.new(18, 4, 2), Vector3.new(0, 2, -70)), "Space: tall vault (7.5 momentum)")
label(part("SlideRoof", Vector3.new(18, 2, 24), Vector3.new(0, 4, -115)), "Shift: slide under; release to crawl")
label(part("ClimbWall", Vector3.new(22, 14, 3), Vector3.new(-50, 7, -30)), "Space: climb | A/Space and D/Space boosts")
label(part("LedgeWall", Vector3.new(22, 5.5, 3), Vector3.new(-50, 2.75, -70)), "Airborne Space: ledge catch | Space up / Shift drop")
label(part("RightWall", Vector3.new(3, 22, 115), Vector3.new(55, 11, -70)), "Jump alongside: Space wall run; W holds; A redirects")
part("LeftWall", Vector3.new(3, 22, 115), Vector3.new(45, 11, -70))
label(part("FallPlatform", Vector3.new(30, 2, 30), Vector3.new(-90, 32, -150)), "Recovery roll: Shift close to landing")
for index = 1, 8 do
    part("FallSteps" .. index, Vector3.new(8, 1, 8), Vector3.new(-90, index * 4 - 0.5, -95 - index * 6))
end
course.Parent = workspace
