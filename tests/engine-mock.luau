-- This is a small math/state test double, NOT a physics or netcode emulator.
local clock = 10
local function time() return clock end
local Enum = setmetatable({}, {__index = function(self, namespace)
    local values = setmetatable({}, {__index = function(_, name) return namespace .. "." .. name end})
    rawset(self, namespace, values)
    return values
end})
local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x, y, z) return setmetatable({X = x, Y = y, Z = z}, vectorMeta) end
vectorMeta.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__unm = function(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
vectorMeta.__mul = function(a,b)
    if type(a) == "number" then a,b=b,a end
    return Vector3.new(a.X*b,a.Y*b,a.Z*b)
end
vectorMeta.__index = function(self,key)
    if key == "Magnitude" then return math.sqrt(self.X*self.X+self.Y*self.Y+self.Z*self.Z) end
    if key == "Unit" then return self*(1/self.Magnitude) end
    if key == "Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
    if key == "Cross" then return function(a,b) return Vector3.new(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end end
end
Vector3.zero,Vector3.xAxis,Vector3.yAxis,Vector3.zAxis = Vector3.new(0,0,0),Vector3.new(1,0,0),Vector3.new(0,1,0),Vector3.new(0,0,1)
local CFrame = {}
function CFrame.lookAt(position, target)
    local look = (target-position).Unit
    return {LookVector = look, RightVector = look:Cross(Vector3.yAxis), UpVector = Vector3.yAxis,
        Position = position, PointToWorldSpace = function(_,offset) return position+offset end}
end
local function typeof(value)
    if getmetatable(value) == vectorMeta then return "Vector3" end
    return type(value)
end
local RaycastParams = {new = function() return {} end}
local rayResults, rayIndex, rayParams = {}, 0, nil
local workspace = {Raycast = function(_,_,_,params)
    rayIndex += 1
    rayParams = params
    return rayResults[rayIndex]
end}
local services = {
    RunService = {IsServer = function() return true end}, Players = {}, ReplicatedStorage = {},
}
local game = {GetService = function(_,name) return services[name] end}
local function attributeInstance()
    local object = {attributes = {}, Enabled = false}
    function object:GetAttribute(key) return self.attributes[key] end
    function object:SetAttribute(key,value) self.attributes[key] = value end
    function object:Clone()
        local copy = table.clone(self)
        copy.attributes = table.clone(self.attributes)
        return setmetatable(copy, {__newindex = function(instance,key,value)
            rawset(instance,key,value)
            if key == "Parent" then value.pool[instance.Name] = instance end
        end})
    end
    return object
end
local passed = 0
local function test(name,body)
    body()
    passed += 1
    print("PASS",name)
end
local function close(a,b)
    assert(math.abs(a-b) < 1e-6, string.format("expected %.9f, got %.9f",b,a))
end
