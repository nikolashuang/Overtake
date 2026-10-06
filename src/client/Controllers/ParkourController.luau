local RepStorage = game:GetService("ReplicatedStorage")

local ParkourConfig = require(RepStorage.Shared.Parkour.ParkourConfig)
local BoostConfig = ParkourConfig.Boost
local RecoveryConfg = ParkourConfig.Recovery

local pRemote = RepStorage.Remotes.ParkourRemote
local characterObject = nil
local mb3 = 0
local ShiftRollInput = 0


local ParkourController = {}

function ParkourController.Init(CharInfo)
    characterObject = CharInfo
end

function ParkourController.HandleInput(input)
    if characterObject.isWallRunning then
        if input.KeyCode == Enum.KeyCode.A then
            ParkourController.AttemptWallRedirect("A")
        elseif input.KeyCode == Enum.KeyCode.D then
            ParkourController.AttemptWallRedirect("D")
        end
    end
    
    
    if input.KeyCode == Enum.KeyCode.LeftShift then
        ShiftRollInput = time()
        local timingWindow = ShiftRollInput - characterObject.Landed
        if characterObject:CanRecoveryRoll() and timingWindow < RecoveryConfg.ROLL_WINDOW  then
            ParkourController.AttemptRoll(timingWindow)
        elseif characterObject:CanSlide() then
            ParkourController.AttemptSlide()
        end
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton3 then
        mb3 = time()
        return
    end
end

function ParkourController.HandleSpaceInput()
    if characterObject:CanWallRun() and not characterObject.isWallRunning then 
        ParkourController.AttemptWallRun()
        return
    elseif characterObject.isWallRunning then
        characterObject:EndWallRun()
        return
    end

    if characterObject:CanLunge() and time() - mb3 < BoostConfig.LUNGE_WINDOW then
        ParkourController.AttemptLunge()
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

function ParkourController.AttemptSlide()
    characterObject:Slide()
    pRemote:FireServer("Sliding")
end

function ParkourController.AttemptWallRun()
    characterObject:StartWallRun()
    pRemote:FireServer("WallRun")
end

function ParkourController.AttemptWallRedirect(input)
    characterObject:WallRedirect(input)
    pRemote:FireServer("WallRedirect")
end

function ParkourController.AttemptRoll(timing)
    characterObject:RecoveryRoll(timing)
    pRemote:FireServer("RecoveryRoll")
end


return ParkourController