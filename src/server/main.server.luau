local Players = game:GetService("Players")
local ServerService = game:GetService("ServerScriptService")
local RepStorage = game:GetService("ReplicatedStorage")

local PlayerProfile = require(ServerService.PlayerProfile.ProfileService)
local CharacterClass = require(RepStorage.Shared.Character.CharacterClass)
local MovementSimulation = require(RepStorage.Shared.Simulation.MovementSimulation)

local Characters = {}

MovementSimulation.Init()

local function setUpPlayer(player)
    local profile = PlayerProfile.LoadProfile(player)

    if not profile then
        player:Kick("Failed to load your progress. Please rejoin")
    end

    local function setUpCharacter(character)
        MovementSimulation.UnregisterPlayer(player)
        MovementSimulation.PreparePlayer(player, character)

        local characterObject = CharacterClass.new(player, profile)
        characterObject:BindCharacter(character)

        Characters[player] = characterObject
        MovementSimulation.RegisterCharacter(player, characterObject)
    end

    player.CharacterAdded:Connect(setUpCharacter)

    player.CharacterRemoving:Connect(function()
        MovementSimulation.UnregisterCharacter(player)
        Characters[player] = nil
    end)

    if player.Character then
        setUpCharacter(player.Character)
    end
end

Players.PlayerAdded:Connect(setUpPlayer)

for _, player in pairs(Players:GetPlayers()) do
    task.spawn(setUpPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
    MovementSimulation.UnregisterPlayer(player)
    Characters[player] = nil

    PlayerProfile.SaveProfile(player)
    PlayerProfile:ReleaseProfile(player)

end)