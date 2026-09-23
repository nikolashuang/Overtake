local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerProfile = require(ServerScriptService.PlayerProfile.ProfileService)
local CharacterClass = require(ReplicatedStorage.Shared.Character.CharacterClass)

local Characters = {}

Players.PlayerAdded:Connect(function(player)
    local profile = PlayerProfile.LoadProfile(player)

    if not profile then
        player:Kick("Failed to load your progress. Please rejoin.")
        return
    end

    local plrCharacter = CharacterClass.new(player, profile)

    Characters[player] = plrCharacter

    if player.Character then
        plrCharacter:BindCharacter(player.Character)
    end

    player.CharacterAdded:Connect(function(character)
        plrCharacter:BindCharacter(character)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    PlayerProfile.SaveProfile(player)
    PlayerProfile:ReleaseProfile(player)
    Characters[player] = nil
end)