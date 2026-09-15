local CharacterClass = {}

CharacterClass.__index = CharacterClass

function CharacterClass.new()
    local self = setmetatable({}, CharacterClass)


    return self
end


return CharacterClass