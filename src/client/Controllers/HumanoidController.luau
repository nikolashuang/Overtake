local listener = nil
local ParkourController = nil

local HumanoidController = {}

function HumanoidController.Init(controller)
    ParkourController = controller
end

function HumanoidController.BindLandingListener(character)
    local humanoid = character:WaitForChild("Humanoid")

    if listener then
        listener:Disconnect()
    end

    local wasAirborne = humanoid.FloorMaterial == Enum.Material.Air

    listener = humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
        local isAirborne = humanoid.FloorMaterial == Enum.Material.Air

        if isAirborne then
            wasAirborne = true
            return
        end

        if wasAirborne then
            wasAirborne = false
            ParkourController.HandleLanding()
        end
    end)
end


return HumanoidController