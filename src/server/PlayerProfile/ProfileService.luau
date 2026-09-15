local DataStoreService = game:GetService("DataStoreService")
local ProfileTemplate = require(script.Parent.ProfileTemplate)
local PlayerStore = DataStoreService:GetDataStore("PlayerProfiles")
local Profiles = {}
local ProfileService = {}

local function deepCopy(original)
    local copy = {}

    for i, v in pairs(original) do
        if type(v) == "table" then
            copy[i] = deepCopy(v)
        else
            copy[i] = v
        end
    end

    return copy
end

function ProfileService.LoadProfile(player)
    local key = "Profile_" .. player.UserId

    local success, data = pcall(function()
        return PlayerStore:GetAsync(key)
    end)

    if not success then
        warn("Failed to load data for " .. player.Name)
        return nil
    end

    if data == nil then
        data = deepCopy(ProfileTemplate)
    end

    local profile = {
        Data = data
    }

    Profiles[player] = profile

    return profile
end

function ProfileService.GetProfile(player)
    return Profiles[player]
end

function ProfileService.SaveProfile(player)
    local profile = Profiles[player]

    if not profile then
        return false
    end

    local key = "Profile_" .. player.UserId

    local success, err = pcall(function()
        PlayerStore:UpdateAsync(key, function()
            return profile.Data
        end)
    end)

    if not success then
        warn("Failed to save data for", player.Name, err)
        return false
    end

    return true
end

function ProfileService:ReleaseProfile(player)
    self:SaveProfile(player)
    Profiles[player] = nil
end





return ProfileService