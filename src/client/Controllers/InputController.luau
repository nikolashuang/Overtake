local UserInput = game:GetService("UserInputService")

local InputController = {}

function InputController.isKeyDown(key)
    return UserInput:IsKeyDown(Enum.KeyCode[key])
end

function InputController.ifWASD()
    if InputController.isKeyDown("W") or InputController.isKeyDown("A") or InputController.isKeyDown("S") or InputController.isKeyDown("D") then
        return true
    end

    return false
end

function InputController.isCameraLocked()
    return UserInput.MouseBehavior == Enum.MouseBehavior.LockCenter
end

function InputController.SlidingLocked()
    if InputController.isCameraLocked() and InputController.isKeyDown("LeftShift") and InputController.isKeyDown("W") then
        return true
    end

    return false
end

function InputController.SlidingUnlocked()
    if not InputController.isCameraLocked() and InputController.isKeyDown("LeftShift") and InputController.ifWASD() then
        return true
    end

    return false
end



return InputController