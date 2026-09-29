local RepStorage = game:GetService("ReplicatedStorage")

local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)
local BoostConfig = ParkourConfig.Boost

local pRemote = RepStorage.Remotes.ParkourRemote
local characterObject = nil
local mb3 = nil


local ParkourController = {}

function ParkourController.Init(CharInfo)
    characterObject = CharInfo
end

function ParkourController.HandleInput(input)
    if input.UserInputType == Enum.UserInputType.MouseButton3 then
        mb3 = time()
        return
    end
end

function ParkourController.HandleSpaceInput()
    print(time() - mb3)
    if characterObject:CanLunge() and time() - mb3 < BoostConfig.LUNGE_WINDOW then
        ParkourController.AttemptLunge()
        mb3 = nil
        return
    end

    if characterObject:CanVault() then
        ParkourController.AttemptVault()
        return
    end
end



function ParkourController.AttemptVault()
    characterObject:VaultOrHurdle()
    pRemote:FireServer("Vaulting")
end


function ParkourController.AttemptLunge()
    characterObject:Lunge()
    pRemote:FireServer("Lunging")
end



return ParkourController