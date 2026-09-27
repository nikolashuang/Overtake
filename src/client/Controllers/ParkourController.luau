local RepStorage = game:GetService("ReplicatedStorage")

local pRemote = RepStorage.Remotes.ParkourRemote

local ParkourController = {}

local characterObject = nil

function ParkourController.Init(CharInfo)
    characterObject = CharInfo
end

function ParkourController.AttemptVault(input, processed)
    if processed then return end

    if input.KeyCode ~= Enum.KeyCode.Space then return end
    if not characterObject:CanVault() then return end

    characterObject:VaultOrHurdle()
    pRemote:FireServer("Vaulting")
end


return ParkourController