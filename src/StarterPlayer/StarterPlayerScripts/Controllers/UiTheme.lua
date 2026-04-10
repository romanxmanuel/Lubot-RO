--!strict

local UiTheme = {}

local palette = {
    windowBase = Color3.fromRGB(233, 237, 246),
    windowDepth = Color3.fromRGB(186, 195, 214),
    surface = Color3.fromRGB(247, 249, 253),
    surfaceDeep = Color3.fromRGB(223, 229, 241),
    inset = Color3.fromRGB(239, 243, 250),
    parchment = Color3.fromRGB(250, 252, 255),
    text = Color3.fromRGB(43, 54, 79),
    textMuted = Color3.fromRGB(97, 108, 132),
    gold = Color3.fromRGB(214, 183, 102),
    goldSoft = Color3.fromRGB(153, 125, 54),
    azure = Color3.fromRGB(89, 129, 200),
    jade = Color3.fromRGB(101, 167, 138),
    ember = Color3.fromRGB(190, 104, 108),
    violet = Color3.fromRGB(138, 126, 198),
    edge = Color3.fromRGB(89, 111, 166),
    edgeSoft = Color3.fromRGB(151, 166, 203),
    slot = Color3.fromRGB(241, 244, 250),
    slotDark = Color3.fromRGB(201, 210, 229),
    titleTop = Color3.fromRGB(127, 161, 225),
    titleBottom = Color3.fromRGB(66, 96, 164),
}

UiTheme.palette = palette

local function clearThemeChildren(guiObject: GuiObject, childName: string)
    for _, child in ipairs(guiObject:GetChildren()) do
        if child.Name == childName then
            child:Destroy()
        end
    end
end

local function addCorner(guiObject: GuiObject, radius: number)
    clearThemeChildren(guiObject, 'ThemeCorner')
    local corner = Instance.new('UICorner')
    corner.Name = 'ThemeCorner'
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = guiObject
    return corner
end

local function addStroke(guiObject: GuiObject, color: Color3, thickness: number?, transparency: number?)
    clearThemeChildren(guiObject, 'ThemeStroke')
    local stroke = Instance.new('UIStroke')
    stroke.Name = 'ThemeStroke'
    stroke.Color = color
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = guiObject
    return stroke
end

local function addGradient(guiObject: GuiObject, colorA: Color3, colorB: Color3, rotation: number?)
    clearThemeChildren(guiObject, 'ThemeGradient')
    local gradient = Instance.new('UIGradient')
    gradient.Name = 'ThemeGradient'
    gradient.Color = ColorSequence.new(colorA, colorB)
    gradient.Rotation = rotation or 90
    gradient.Parent = guiObject
    return gradient
end

local function addThemeBar(guiObject: GuiObject)
    if not guiObject:IsA('Frame') and not guiObject:IsA('TextButton') and not guiObject:IsA('TextBox') then
        return
    end

    clearThemeChildren(guiObject, 'ThemeTitleBar')
    clearThemeChildren(guiObject, 'ThemeTitleBarLine')

    local bar = Instance.new('Frame')
    bar.Name = 'ThemeTitleBar'
    bar.Size = UDim2.new(1, -8, 0, 18)
    bar.Position = UDim2.fromOffset(4, 4)
    bar.BackgroundColor3 = palette.titleBottom
    bar.BorderSizePixel = 0
    bar.ZIndex = 0
    bar.Parent = guiObject
    addCorner(bar, 2)
    addGradient(bar, palette.titleTop, palette.titleBottom, 90)
    addStroke(bar, Color3.fromRGB(230, 238, 255), 1, 0.48)

    local line = Instance.new('Frame')
    line.Name = 'ThemeTitleBarLine'
    line.Size = UDim2.new(1, -8, 0, 1)
    line.Position = UDim2.fromOffset(4, 22)
    line.BackgroundColor3 = palette.edgeSoft
    line.BorderSizePixel = 0
    line.ZIndex = 0
    line.Parent = guiObject
end

UiTheme.addCorner = addCorner
UiTheme.addStroke = addStroke
UiTheme.addGradient = addGradient

function UiTheme.styleWindow(frame: GuiObject, accentColor: Color3?, baseColor: Color3?)
    local background = baseColor or palette.windowBase
    frame.BackgroundColor3 = background
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    addCorner(frame, 3)
    addGradient(frame, background:Lerp(Color3.new(1, 1, 1), 0.18), background:Lerp(palette.windowDepth, 0.42), 90)
    addStroke(frame, accentColor or palette.edge, 1, 0.04)
    addThemeBar(frame)
end

function UiTheme.styleSection(frame: GuiObject, accentColor: Color3?, baseColor: Color3?)
    local background = baseColor or palette.surface
    frame.BackgroundColor3 = background
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    addCorner(frame, 2)
    addGradient(frame, background:Lerp(Color3.new(1, 1, 1), 0.12), background:Lerp(palette.surfaceDeep, 0.38), 90)
    addStroke(frame, accentColor or palette.edgeSoft, 1, 0.08)
end

function UiTheme.styleInset(frame: GuiObject, accentColor: Color3?, baseColor: Color3?)
    local background = baseColor or palette.inset
    frame.BackgroundColor3 = background
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    addCorner(frame, 2)
    addGradient(frame, background:Lerp(Color3.new(1, 1, 1), 0.12), background:Lerp(palette.windowDepth, 0.18), 90)
    addStroke(frame, accentColor or palette.edgeSoft, 1, 0.16)
end

function UiTheme.styleSlot(frame: GuiObject, accentColor: Color3?, baseColor: Color3?)
    local background = baseColor or palette.slot
    frame.BackgroundColor3 = background
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    addCorner(frame, 2)
    addGradient(frame, background:Lerp(Color3.new(1, 1, 1), 0.18), background:Lerp(palette.slotDark, 0.42), 90)
    addStroke(frame, accentColor or palette.edge, 1, 0.04)
end

function UiTheme.styleScrollFrame(frame: ScrollingFrame, accentColor: Color3?, baseColor: Color3?)
    UiTheme.styleInset(frame, accentColor, baseColor)
    frame.ScrollBarThickness = math.max(frame.ScrollBarThickness, 8)
    frame.ScrollBarImageColor3 = accentColor or palette.azure
end

function UiTheme.styleButton(button: TextButton, variant: string?)
    local theme = variant or 'secondary'
    local top = Color3.fromRGB(251, 253, 255)
    local bottom = Color3.fromRGB(197, 205, 221)
    local stroke = palette.edge
    local textColor = palette.text

    if theme == 'primary' then
        top = Color3.fromRGB(199, 220, 255)
        bottom = Color3.fromRGB(108, 140, 210)
        stroke = Color3.fromRGB(60, 86, 148)
        textColor = Color3.fromRGB(21, 35, 67)
    elseif theme == 'secondary' then
        top = Color3.fromRGB(251, 253, 255)
        bottom = Color3.fromRGB(204, 211, 226)
        stroke = palette.edge
        textColor = palette.text
    elseif theme == 'success' then
        top = Color3.fromRGB(235, 249, 239)
        bottom = Color3.fromRGB(170, 211, 188)
        stroke = Color3.fromRGB(88, 145, 117)
        textColor = Color3.fromRGB(36, 72, 56)
    elseif theme == 'danger' then
        top = Color3.fromRGB(255, 236, 239)
        bottom = Color3.fromRGB(215, 165, 174)
        stroke = Color3.fromRGB(150, 86, 102)
        textColor = Color3.fromRGB(92, 40, 52)
    elseif theme == 'gold' then
        top = Color3.fromRGB(255, 247, 223)
        bottom = Color3.fromRGB(219, 191, 116)
        stroke = Color3.fromRGB(160, 123, 46)
        textColor = Color3.fromRGB(84, 54, 14)
    elseif theme == 'ghost' then
        top = Color3.fromRGB(244, 247, 252)
        bottom = Color3.fromRGB(214, 221, 234)
        stroke = Color3.fromRGB(130, 146, 184)
        textColor = palette.textMuted
    elseif theme == 'admin' then
        top = Color3.fromRGB(244, 238, 255)
        bottom = Color3.fromRGB(186, 168, 225)
        stroke = Color3.fromRGB(118, 96, 182)
        textColor = Color3.fromRGB(56, 43, 103)
    end

    button.BackgroundColor3 = bottom
    button.BackgroundTransparency = 0
    button.BorderSizePixel = 0
    button.Font = Enum.Font.ArialBold
    button.TextColor3 = textColor
    button.TextSize = math.max(button.TextSize, 10)
    addCorner(button, 2)
    addGradient(button, top, bottom, 90)
    addStroke(button, stroke, 1, 0.03)
end

function UiTheme.stylePill(frame: GuiObject, accentColor: Color3?, baseColor: Color3?)
    local background = baseColor or palette.surface
    frame.BackgroundColor3 = background
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    addCorner(frame, 2)
    addGradient(frame, background:Lerp(Color3.new(1, 1, 1), 0.14), background:Lerp(palette.surfaceDeep, 0.34), 90)
    addStroke(frame, accentColor or palette.edgeSoft, 1, 0.08)
end

function UiTheme.styleTextInput(box: TextBox, accentColor: Color3?, baseColor: Color3?)
    UiTheme.styleInset(box, accentColor, baseColor or palette.surface)
    box.TextColor3 = palette.text
    box.PlaceholderColor3 = palette.textMuted
    box.Font = Enum.Font.Arial
    box.TextSize = math.max(box.TextSize, 12)
end

return UiTheme
