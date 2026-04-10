--!strict

local UserInputService = game:GetService('UserInputService')

local UiDragUtil = {}

function UiDragUtil.makeDraggable(frame: GuiObject, handle: GuiObject?)
    local dragHandle = handle or frame
    local dragging = false
    local dragStart = Vector2.zero
    local startPosition = frame.Position
    local activeInput: InputObject? = nil

    frame.Active = true
    dragHandle.Active = true

    local function updateDrag(input: InputObject)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end

    dragHandle.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        dragStart = input.Position
        startPosition = frame.Position
        activeInput = input

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                activeInput = nil
            end
        end)
    end)

    dragHandle.InputChanged:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            activeInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input: InputObject)
        if not dragging or activeInput ~= input then
            return
        end

        updateDrag(input)
    end)
end

function UiDragUtil.makeResizable(frame: GuiObject, minSize: Vector2?, maxSize: Vector2?)
    local minimum = minSize or Vector2.new(frame.AbsoluteSize.X, frame.AbsoluteSize.Y)
    local maximum = maxSize
    local resizing = false
    local resizeStart = Vector2.zero
    local startSize = frame.Size
    local startPosition = frame.Position
    local startAbsolutePosition = Vector2.zero
    local parentAbsolutePosition = Vector2.zero
    local activeInput: InputObject? = nil

    local handle = Instance.new('TextButton')
    handle.Name = 'ResizeHandle'
    handle.Size = UDim2.fromOffset(14, 14)
    handle.AnchorPoint = Vector2.new(1, 1)
    handle.Position = UDim2.new(1, -3, 1, -3)
    handle.BackgroundColor3 = Color3.fromRGB(72, 84, 104)
    handle.BackgroundTransparency = 1
    handle.BorderSizePixel = 0
    handle.Font = Enum.Font.GothamBold
    handle.TextSize = 8
    handle.TextColor3 = Color3.fromRGB(184, 194, 208)
    handle.TextTransparency = 0.25
    handle.Text = '--'
    handle.AutoButtonColor = false
    handle.ZIndex = math.max(frame.ZIndex + 2, 10)
    handle.Parent = frame

    local function updateResize(input: InputObject)
        local delta = input.Position - resizeStart
        local width = math.max(minimum.X, startSize.X.Offset + delta.X)
        local height = math.max(minimum.Y, startSize.Y.Offset + delta.Y)

        if maximum then
            width = math.min(width, maximum.X)
            height = math.min(height, maximum.Y)
        end

        frame.Size = UDim2.new(startSize.X.Scale, width, startSize.Y.Scale, height)
        frame.Position = UDim2.fromOffset(
            math.floor((startAbsolutePosition.X - parentAbsolutePosition.X) + (width * frame.AnchorPoint.X) + 0.5),
            math.floor((startAbsolutePosition.Y - parentAbsolutePosition.Y) + (height * frame.AnchorPoint.Y) + 0.5)
        )
    end

    handle.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        resizing = true
        resizeStart = input.Position
        startSize = frame.Size
        startPosition = frame.Position
        startAbsolutePosition = frame.AbsolutePosition
        local parent = frame.Parent
        if parent and parent:IsA('GuiObject') then
            parentAbsolutePosition = parent.AbsolutePosition
        else
            parentAbsolutePosition = Vector2.zero
        end
        activeInput = input

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizing = false
                activeInput = nil
            end
        end)
    end)

    handle.InputChanged:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            activeInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input: InputObject)
        if not resizing or activeInput ~= input then
            return
        end

        updateResize(input)
    end)

    return handle
end

function UiDragUtil.snapWindowBesideLeftHalfAnchor(allWindows, rootGui: GuiObject?, targetWindow: GuiObject?, gap: number?)
    if not allWindows or not targetWindow then
        return
    end

    local spacing = gap or 12
    local viewportSize = if rootGui and rootGui.AbsoluteSize.X > 0 and rootGui.AbsoluteSize.Y > 0
        then rootGui.AbsoluteSize
        else (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720))
    local leftHalfBoundary = viewportSize.X * 0.5
    local bestWindow = nil
    local bestRightEdge = -math.huge
    local bestTop = math.huge

    for _, frame in pairs(allWindows) do
        if frame and frame ~= targetWindow and frame.Visible then
            local frameSize = if frame.AbsoluteSize.X > 0 and frame.AbsoluteSize.Y > 0
                then frame.AbsoluteSize
                else Vector2.new(frame.Size.X.Offset, frame.Size.Y.Offset)
            local centerX = frame.AbsolutePosition.X + frameSize.X * 0.5
            if centerX <= leftHalfBoundary then
                local rightEdge = frame.AbsolutePosition.X + frameSize.X
                if rightEdge > bestRightEdge or (math.abs(rightEdge - bestRightEdge) <= 1 and frame.AbsolutePosition.Y < bestTop) then
                    bestWindow = frame
                    bestRightEdge = rightEdge
                    bestTop = frame.AbsolutePosition.Y
                end
            end
        end
    end

    if not bestWindow then
        return
    end

    local anchorSize = if bestWindow.AbsoluteSize.X > 0 and bestWindow.AbsoluteSize.Y > 0
        then bestWindow.AbsoluteSize
        else Vector2.new(bestWindow.Size.X.Offset, bestWindow.Size.Y.Offset)
    local targetSize = if targetWindow.AbsoluteSize.X > 0 and targetWindow.AbsoluteSize.Y > 0
        then targetWindow.AbsoluteSize
        else Vector2.new(targetWindow.Size.X.Offset, targetWindow.Size.Y.Offset)
    local targetX = bestWindow.AbsolutePosition.X + anchorSize.X + spacing
    local targetY = bestWindow.AbsolutePosition.Y
    local clampedX = math.clamp(targetX, 0, math.max(0, viewportSize.X - targetSize.X - spacing))
    local clampedY = math.clamp(targetY, 0, math.max(0, viewportSize.Y - targetSize.Y - spacing))
    local anchoredX = clampedX + targetSize.X * targetWindow.AnchorPoint.X
    local anchoredY = clampedY + targetSize.Y * targetWindow.AnchorPoint.Y

    targetWindow.Position = UDim2.fromOffset(math.floor(anchoredX + 0.5), math.floor(anchoredY + 0.5))
end

return UiDragUtil
