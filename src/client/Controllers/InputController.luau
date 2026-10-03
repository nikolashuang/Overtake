local UserInput = game:GetService("UserInputService")

local InputController = {}

function InputController.isKeyDown(key)
    return UserInput:IsKeyDown(Enum.KeyCode[key])
end

function InputController.isMovementKeyDown()
    if InputController.isKeyDown("W") or InputController.isKeyDown("A") or InputController.isKeyDown("S") or InputController.isKeyDown("D") then
        return true
    end

    return false
end

function InputController.isCameraLocked()
    return UserInput.MouseBehavior == Enum.MouseBehavior.LockCenter
end

function InputController.MaintainSlideInput()
    if InputController.isCameraLocked() then
        if InputController.isKeyDown("LeftShift") and InputController.isKeyDown("W") then
            return true
        end
    else
        if InputController.isKeyDown("LeftShift") and InputController.isMovementKeyDown() then
            return true
        end
    end

    return false
end


return InputController