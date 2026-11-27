Track(UIS.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then A.adsBtnHeld = true end
    if input.UserInputType == Enum.UserInputType.Touch then
        if input.Position and not OnOwnGui(input.Position) then
            local cam = A.cam
            local vw = cam and cam.ViewportSize.X or 1000
            if input.Position.X >= vw * 0.5 then
                A.fireTouch = input
                A.fireTouchPos = Vector2.new(input.Position.X, input.Position.Y)
                MarkFire()
            end
        end
        return
    end
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MarkFire()
    end
end))
pcall(function()
    Track(UIS.InputChanged:Connect(function(input)
        if A.fireTouch and input == A.fireTouch and A.fireTouchPos and input.Position then
            local moved = (Vector2.new(input.Position.X, input.Position.Y) - A.fireTouchPos).Magnitude
            if moved > 70 then
                A.fireTouch = nil
                A.fireTouchPos = nil
                A.fireHeld = false
            end
        end
    end))
end)
Track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then A.adsBtnHeld = false end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        A.fireHeld = false
    elseif input.UserInputType == Enum.UserInputType.Touch then
        if A.fireTouch and input == A.fireTouch then
            A.fireHeld = false
            A.fireTouch = nil
            A.fireTouchPos = nil
        end
    end
end))

