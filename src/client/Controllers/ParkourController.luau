local RepStorage = game:GetService("ReplicatedStorage")
local pRemote = RepStorage.Remotes.ParkourRemote

local ParkourController = {}

function ParkourController.AttemptVault(input, processed, characterObject)
    if processed then return end

    if input.KeyCode ~= Enum.KeyCode.Space then return end
    if not characterObject:CanVault() then return end

    characterObject:VaultOrHurdle()
    pRemote:FireServer("Vaulting")
end


return ParkourController