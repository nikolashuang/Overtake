local RepStorage = game:GetService("ReplicatedStorage")

local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)
local BoostConfig = ParkourConfig.Boost

local pRemote = RepStorage.Remotes.ParkourRemote

local ParkourController = {}

local characterObject = nil

function ParkourController.Init(CharInfo)
    characterObject = CharInfo
end

function ParkourController.AttemptVault()
    if not characterObject:CanVault() then return end

    characterObject:VaultOrHurdle()
    pRemote:FireServer("Vaulting")
end


function ParkourController.AttemptLunge()
    characterObject:Lunge()
    pRemote:FireServer("Lunging")
end



return ParkourController