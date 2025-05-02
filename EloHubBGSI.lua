-- EloHub v1.0


-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService") -- Added for JSON encoding/decoding

-- Variables
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Mouse = LocalPlayer:GetMouse()
local dragging = false
local dragInput
local dragStart
local startPos
local autoBubbleLoopActive = false
local isNoClipping = false -- Added for NoClip state
local noclipConnection = nil -- Added for NoClip loop
local originalWalkSpeed = Humanoid.WalkSpeed
local isWalkSpeedEnabled = false
local activeKeybinds = {}
local keybindListeners = {}
local checkboxRegistry = {} -- To help map keybinds on load

-- Create main GUI
local EloHub = Instance.new("ScreenGui")
EloHub.Name = "EloHub"
EloHub.ResetOnSpawn = false
EloHub.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
EloHub.Enabled = true

if test and test.protect_gui then
    test.protect_gui(EloHub)
    EloHub.Parent = game:GetService("CoreGui")
elseif gethui then
    EloHub.Parent = gethui()
else
    EloHub.Parent = game:GetService("CoreGui")
end


local function CreateRoundedFrame(size, position, bgColor, parent)
    local frame = Instance.new("Frame")
    frame.Size = size
    frame.Position = position
    frame.BackgroundColor3 = bgColor
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 5)
    UICorner.Parent = frame

    return frame
end

local function CreateSidebarIcon(iconText, position, parent)
    local iconButton = Instance.new("TextButton")
    iconButton.Size = UDim2.new(0, 50, 0, 50)
    iconButton.Position = position
    iconButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    iconButton.BorderSizePixel = 0
    iconButton.Text = iconText
    iconButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconButton.Font = Enum.Font.GothamSemibold
    iconButton.TextSize = 18
    iconButton.Parent = parent

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 5)
    UICorner.Parent = iconButton

    return iconButton
end

local function CreateCheckbox(text, position, parent, featureId) -- Added featureId
    local checkboxContainer = Instance.new("Frame")
    checkboxContainer.Size = UDim2.new(0, 280, 0, 20)
    checkboxContainer.Position = position
    checkboxContainer.BackgroundTransparency = 1
    checkboxContainer.Parent = parent

    local checkbox = Instance.new("Frame")
    checkbox.Name = "CheckboxFrame"
    checkbox.Size = UDim2.new(0, 16, 0, 16)
    checkbox.Position = UDim2.new(0, 0, 0, 2)
    checkbox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    checkbox.BorderSizePixel = 0
    checkbox.Parent = checkboxContainer

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 3)
    UICorner.Parent = checkbox

    local checkMark = Instance.new("Frame")
    checkMark.Name = "CheckMark"
    checkMark.Size = UDim2.new(0.8, 0, 0.8, 0)
    checkMark.Position = UDim2.new(0.5, 0, 0.5, 0)
    checkMark.AnchorPoint = Vector2.new(0.5, 0.5)
    checkMark.BackgroundColor3 = Color3.fromRGB(170, 0, 255)
    checkMark.BackgroundTransparency = 0
    checkMark.BorderSizePixel = 0
    checkMark.Visible = false
    checkMark.Parent = checkbox

    local UICornerMark = Instance.new("UICorner")
    UICornerMark.CornerRadius = UDim.new(0, 2)
    UICornerMark.Parent = checkMark

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0, 200, 0, 20)
    textLabel.Position = UDim2.new(0, 25, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 13
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = checkboxContainer

    local keybindButton = Instance.new("TextButton")
    keybindButton.Name = "KeybindButton"
    keybindButton.Size = UDim2.new(0, 50, 0, 18)
    keybindButton.Position = UDim2.new(1, -100, 0, 1)
    keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    keybindButton.BorderSizePixel = 0
    keybindButton.Text = "Set Key"
    keybindButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    keybindButton.Font = Enum.Font.Gotham
    keybindButton.TextSize = 10
    keybindButton.Parent = checkboxContainer

    local keybindCorner = Instance.new("UICorner")
    keybindCorner.CornerRadius = UDim.new(0, 3)
    keybindCorner.Parent = keybindButton

    local button = Instance.new("TextButton")
    button.Name = "CheckboxButton"
    button.Size = UDim2.new(0, 16, 0, 16)
    button.Position = UDim2.new(0, 0, 0, 2)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.ZIndex = 2
    button.Parent = checkboxContainer

    local isChecked = false
    local changedSignal = Instance.new("BindableEvent")
    local currentKeybind = nil
    local listeningConnection = nil

    local function ToggleCheckbox()
        isChecked = not isChecked
        checkMark.Visible = isChecked
        changedSignal:Fire(isChecked)
    end

    button.MouseButton1Click:Connect(ToggleCheckbox)

    local function SetKeybind(keyCode)
        if currentKeybind and activeKeybinds[currentKeybind] == ToggleCheckbox then
             activeKeybinds[currentKeybind] = nil
        end

        if keyCode and keyCode ~= Enum.KeyCode.Backspace then
             currentKeybind = keyCode
             keybindButton.Text = keyCode.Name
             activeKeybinds[currentKeybind] = ToggleCheckbox
        else
             currentKeybind = nil
             keybindButton.Text = "Set Key"
        end
         checkboxRegistry[featureId].CurrentKeybind = currentKeybind -- Update registry
    end

    keybindButton.MouseButton1Click:Connect(function()
        keybindButton.Text = "..."
        if listeningConnection then
            listeningConnection:Disconnect()
            listeningConnection = nil
        end

        listeningConnection = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
            if gameProcessedEvent then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                SetKeybind(input.KeyCode)
                if listeningConnection then
                    listeningConnection:Disconnect()
                    listeningConnection = nil
                end
            end
        end)
    end)

    local checkboxData = {
        Container = checkboxContainer,
        Button = button,
        Changed = changedSignal,
        SetValue = function(value)
            isChecked = value
            checkMark.Visible = isChecked
        end,
        Toggle = ToggleCheckbox,
        GetKeybind = function() return currentKeybind end,
        SetKeybind = SetKeybind, -- Expose SetKeybind
        KeybindButton = keybindButton -- Expose KeybindButton to update text
    }

    if featureId then
         checkboxRegistry[featureId] = checkboxData -- Register the checkbox
    end

    return checkboxData
end


local function CreateSlider(text, minVal, maxVal, defaultVal, position, parent)
    local sliderContainer = Instance.new("Frame")
    sliderContainer.Size = UDim2.new(0, 280, 0, 40)
    sliderContainer.Position = position
    sliderContainer.BackgroundTransparency = 1
    sliderContainer.Parent = parent

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -60, 0, 20)
    textLabel.Position = UDim2.new(0, 0, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 13
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = sliderContainer

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.Size = UDim2.new(0, 50, 0, 20)
    valueLabel.Position = UDim2.new(1, -50, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultVal)
    valueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = sliderContainer

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 10)
    sliderFrame.Position = UDim2.new(0, 0, 0, 25)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = sliderContainer

    local UICornerSlider = Instance.new("UICorner")
    UICornerSlider.CornerRadius = UDim.new(0, 3)
    UICornerSlider.Parent = sliderFrame

    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(170, 0, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderFrame

    local UICornerFill = Instance.new("UICorner")
    UICornerFill.CornerRadius = UDim.new(0, 3)
    UICornerFill.Parent = sliderFill

    local sliderButton = Instance.new("TextButton")
    sliderButton.Name = "SliderButton"
    sliderButton.Size = UDim2.new(1, 0, 1, 0)
    sliderButton.BackgroundTransparency = 1
    sliderButton.Text = ""
    sliderButton.ZIndex = 2
    sliderButton.Parent = sliderFrame

    local currentValue = defaultVal
    local changedSignal = Instance.new("BindableEvent")
    local isDragging = false

    local function UpdateSlider(inputPos)
        local relativeX = inputPos.X - sliderFrame.AbsolutePosition.X
        local percentage = math.clamp(relativeX / sliderFrame.AbsoluteSize.X, 0, 1)
        currentValue = minVal + (maxVal - minVal) * percentage
        sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        valueLabel.Text = string.format("%.1f", currentValue)
        changedSignal:Fire(currentValue)
    end

    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            UpdateSlider(input.Position)
        end
    end)

    sliderButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateSlider(input.Position)
        end
    end)

    return {
        Container = sliderContainer,
        Changed = changedSignal,
        GetValue = function() return currentValue end,
        SetValue = function(value)
             currentValue = math.clamp(value, minVal, maxVal)
             local percentage = (currentValue - minVal) / (maxVal - minVal)
             sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
             valueLabel.Text = string.format("%.1f", currentValue)
        end
    }
end

local function CreateDropdownVisual(text, position, options, parent)
    local dropdownContainer = Instance.new("Frame")
    dropdownContainer.Size = UDim2.new(0, 280, 0, 40)
    dropdownContainer.Position = position
    dropdownContainer.BackgroundTransparency = 1
    dropdownContainer.Parent = parent
    dropdownContainer.ZIndex = 2

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0, 280, 0, 20)
    textLabel.Position = UDim2.new(0, 0, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 13
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = dropdownContainer

    local dropdownButton = Instance.new("Frame")
    dropdownButton.Size = UDim2.new(0, 280, 0, 20)
    dropdownButton.Position = UDim2.new(0, 0, 0, 20)
    dropdownButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    dropdownButton.BorderSizePixel = 0
    dropdownButton.Parent = dropdownContainer

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 3)
    UICorner.Parent = dropdownButton

    local selectedText = Instance.new("TextLabel")
    selectedText.Name = "SelectedText"
    selectedText.Size = UDim2.new(1, -25, 1, 0)
    selectedText.Position = UDim2.new(0, 5, 0, 0)
    selectedText.BackgroundTransparency = 1
    selectedText.Text = options[1] or "Select Location"
    selectedText.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectedText.Font = Enum.Font.Gotham
    selectedText.TextSize = 13
    selectedText.TextXAlignment = Enum.TextXAlignment.Left
    selectedText.Parent = dropdownButton

    local arrowLabel = Instance.new("TextLabel")
    arrowLabel.Name = "ArrowLabel"
    arrowLabel.Size = UDim2.new(0, 20, 0, 20)
    arrowLabel.Position = UDim2.new(1, -20, 0, 0)
    arrowLabel.BackgroundTransparency = 1
    arrowLabel.Text = "▼"
    arrowLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    arrowLabel.Font = Enum.Font.Gotham
    arrowLabel.TextSize = 12
    arrowLabel.Parent = dropdownButton

    local clickDetectorButton = Instance.new("TextButton")
    clickDetectorButton.Name = "ClickDetector"
    clickDetectorButton.Size = UDim2.new(1, 0, 1, 0)
    clickDetectorButton.Position = UDim2.new(0, 0, 0, 0)
    clickDetectorButton.BackgroundTransparency = 1
    clickDetectorButton.Text = ""
    clickDetectorButton.ZIndex = 3
    clickDetectorButton.Parent = dropdownButton

    return dropdownContainer, clickDetectorButton, selectedText, arrowLabel
end

local function CreateButton(text, position, size, parent)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.Gotham
    button.TextSize = 14
    button.Parent = parent

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 3)
    UICorner.Parent = button

    return button
end

local function MakeDraggable(topbar, frame)
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local guiObjects = topbar:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
            local onButton = false
            for _, obj in ipairs(guiObjects) do
                if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                    onButton = true
                    break
                end
            end

            if not onButton then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position

                local connection
                connection = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        if connection then
                           connection:Disconnect()
                           connection = nil
                        end
                    end
                end)
            end
        end
    end)

    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end


local MainFrame = CreateRoundedFrame(UDim2.new(0, 600, 0, 350), UDim2.new(0.5, -300, 0.5, -175), Color3.fromRGB(20, 20, 25), EloHub)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local UICornerTitle = Instance.new("UICorner")
UICornerTitle.CornerRadius = UDim.new(0, 5)
UICornerTitle.Parent = TitleBar

local BottomFix = Instance.new("Frame")
BottomFix.Size = UDim2.new(1, 0, 0, 10)
BottomFix.Position = UDim2.new(0, 0, 1, -10)
BottomFix.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
BottomFix.BorderSizePixel = 0
BottomFix.Parent = TitleBar

MakeDraggable(TitleBar, MainFrame)

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(0, 200, 0, 30)
TitleText.Position = UDim2.new(0, 10, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "EloHub"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 16
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -30, 0, 0)
CloseButton.BackgroundTransparency = 1
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 16
CloseButton.Parent = TitleBar

CloseButton.MouseButton1Click:Connect(function()
    EloHub.Enabled = false;
end)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 60, 1, -30)
Sidebar.Position = UDim2.new(0, 0, 0, 30)
Sidebar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local UICornerSidebar = Instance.new("UICorner")
UICornerSidebar.CornerRadius = UDim.new(0, 5)
UICornerSidebar.Parent = Sidebar

local TopLeftFix = Instance.new("Frame")
TopLeftFix.Size = UDim2.new(0, 10, 0, 10)
TopLeftFix.Position = UDim2.new(0, 0, 0, 0)
TopLeftFix.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TopLeftFix.BorderSizePixel = 0
TopLeftFix.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -70, 1, -40)
ContentArea.Position = UDim2.new(0, 65, 0, 35)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local MainIcon = CreateSidebarIcon("🍭", UDim2.new(0, 5, 0, 5), Sidebar)
local TeleportIcon = CreateSidebarIcon("📍", UDim2.new(0, 5, 0, 60), Sidebar)
local SettingsIcon = CreateSidebarIcon("⚙️", UDim2.new(0, 5, 0, 115), Sidebar)


local function CreateTabPanel(name)
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.Parent = ContentArea
    panel.ClipsDescendants = true

    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0.5, -5, 1, 0)
    leftPanel.Position = UDim2.new(0, 0, 0, 0)
    leftPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = panel
    leftPanel.ClipsDescendants = true

    local UICornerLeft = Instance.new("UICorner")
    UICornerLeft.CornerRadius = UDim.new(0, 5)
    UICornerLeft.Parent = leftPanel

    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0.5, -5, 1, 0)
    rightPanel.Position = UDim2.new(0.5, 5, 0, 0)
    rightPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = panel

    local UICornerRight = Instance.new("UICorner")
    UICornerRight.CornerRadius = UDim.new(0, 5)
    UICornerRight.Parent = rightPanel

    local leftPanelTitle = Instance.new("TextLabel")
    leftPanelTitle.Size = UDim2.new(1, -20, 0, 30)
    leftPanelTitle.Position = UDim2.new(0, 10, 0, 5)
    leftPanelTitle.BackgroundTransparency = 1
    leftPanelTitle.Text = "Miscellaneous"
    leftPanelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    leftPanelTitle.Font = Enum.Font.GothamBold
    leftPanelTitle.TextSize = 16
    leftPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
    leftPanelTitle.Parent = leftPanel

    local rightPanelTitle = Instance.new("TextLabel")
    rightPanelTitle.Size = UDim2.new(1, -20, 0, 30)
    rightPanelTitle.Position = UDim2.new(0, 10, 0, 5)
    rightPanelTitle.BackgroundTransparency = 1
    rightPanelTitle.Text = "Settings"
    rightPanelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    rightPanelTitle.Font = Enum.Font.GothamBold
    rightPanelTitle.TextSize = 16
    rightPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
    rightPanelTitle.Parent = rightPanel

    local leftScrollFrame = Instance.new("ScrollingFrame")
    leftScrollFrame.Size = UDim2.new(1, -20, 1, -40)
    leftScrollFrame.Position = UDim2.new(0, 10, 0, 35)
    leftScrollFrame.BackgroundTransparency = 1
    leftScrollFrame.BorderSizePixel = 0
    leftScrollFrame.CanvasSize = UDim2.new(0,0,0,0)
    leftScrollFrame.ScrollBarThickness = 3
    leftScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(170, 0, 255)
    leftScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    leftScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    leftScrollFrame.Parent = leftPanel

    local rightScrollFrame = Instance.new("ScrollingFrame")
    rightScrollFrame.Size = UDim2.new(1, -20, 1, -40)
    rightScrollFrame.Position = UDim2.new(0, 10, 0, 35)
    rightScrollFrame.BackgroundTransparency = 1
    rightScrollFrame.BorderSizePixel = 0
    rightScrollFrame.CanvasSize = UDim2.new(0,0,0,0)
    rightScrollFrame.ScrollBarThickness = 3
    rightScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(170, 0, 255)
    rightScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    rightScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    rightScrollFrame.Parent = rightPanel

    return {
        Panel = panel,
        LeftTitle = leftPanelTitle,
        RightTitle = rightPanelTitle,
        LeftContent = leftScrollFrame,
        RightContent = rightScrollFrame
    }
end

local MainTab = CreateTabPanel("MainTab")
local TeleportTab = CreateTabPanel("TeleportTab")
local SettingsTab = CreateTabPanel("SettingsTab")


MainTab.LeftTitle.Text = "Main"
MainTab.RightTitle.Text = "Settings"

SettingsTab.LeftTitle.Text = "Options"
SettingsTab.RightTitle.Text = "" -- Hide right panel title for settings

TeleportTab.LeftTitle.Text = "Teleport"
TeleportTab.RightTitle.Text = ""

local selectedTab = MainTab
selectedTab.Panel.Visible = true

local function SwitchTab(tabToShow)
    if selectedTab ~= tabToShow then
        selectedTab.Panel.Visible = false
        selectedTab = tabToShow
        selectedTab.Panel.Visible = true
    end
end

MainIcon.MouseButton1Click:Connect(function()
    SwitchTab(MainTab)
end)

SettingsIcon.MouseButton1Click:Connect(function()
    SwitchTab(SettingsTab)
end)

TeleportIcon.MouseButton1Click:Connect(function()
    SwitchTab(TeleportTab)
end)

-- Feature Checkboxes (Assign unique IDs)
local AutoBubble = CreateCheckbox("Auto-Bubble", UDim2.new(0, 0, 0, 0), MainTab.LeftContent, "AutoBubble")
local NoClipCheckbox = CreateCheckbox("NoClip", UDim2.new(0, 0, 0, 25), MainTab.LeftContent, "NoClip") -- Renamed
local ClaimPlaytimesButton = CreateButton("Claim Playtimes", UDim2.new(0, 0, 0, 50), UDim2.new(1, -10, 0, 25), MainTab.LeftContent)
local HatchingZone = CreateButton("HatchingZone TP", UDim2.new(0, 0, 0, 140), UDim2.new(1, -10, 0, 25), TeleportTab.LeftContent)


ClaimPlaytimesButton.MouseButton1Click:Connect(function()
    local FunctionName = 'ClaimPlaytime'
    local remoteFunction = game:GetService('ReplicatedStorage'):FindFirstChild("Shared", true)
                                :FindFirstChild("Framework", true)
                                :FindFirstChild("Network", true)
                                :FindFirstChild("Remote", true)
                                :FindFirstChild("Function")

    if remoteFunction and remoteFunction:IsA("RemoteFunction") then
        for giftIndex = 1, 9 do
            print("Attempting to claim playtime gift index:", giftIndex)
            local success, result = pcall(function()
                return remoteFunction:InvokeServer(FunctionName, giftIndex)
            end)
            if success then
                print("Claimed gift index", giftIndex, "- Result:", result)
            else
                warn("Error claiming gift index", giftIndex, ":", result)
            end
            task.wait(0.2) -- Add a small delay between claims
        end
        print("Finished attempting to claim all playtime gifts.")
    else
        warn("Could not find RemoteFunction for claiming playtime gifts.")
    end
end)


local UnlockAll = CreateButton("Unlock All Islands", UDim2.new(0, 0, 0, 170), UDim2.new(1, -10, 0, 25), TeleportTab.LeftContent)



local teleportLocations = {
    {"Floating Island"},
		{"Outer Space"},
		{"Twilight"},
		{"The Void"},
		{"Zen"}
}

local dropdownContainer, clickDetector, selectedTextLabel, arrowLabel = CreateDropdownVisual(
    "Teleport Locations",
    UDim2.new(0, 0, 0, 0),
    {"Select Location"},
    TeleportTab.LeftContent
)
dropdownContainer.Name = "TeleportDropdownContainer"

local optionsListVisible = false
local optionsListHeight = 150
local optionHeight = 20

local optionsFrame = Instance.new("ScrollingFrame")
optionsFrame.Name = "OptionsList"
optionsFrame.Size = UDim2.new(1, 0, 0, optionsListHeight)
optionsFrame.Position = UDim2.new(0, 0, 1, 0)
optionsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
optionsFrame.BorderSizePixel = 1
optionsFrame.BorderColor3 = Color3.fromRGB(50, 50, 55)
optionsFrame.Visible = false
optionsFrame.Active = true
optionsFrame.ZIndex = 5 -- Consistent ZIndex for lists
optionsFrame.ClipsDescendants = true
optionsFrame.ScrollBarThickness = 5
optionsFrame.ScrollBarImageColor3 = Color3.fromRGB(170, 0, 255)
optionsFrame.CanvasSize = UDim2.new(0, 0, 0, #teleportLocations * optionHeight)
optionsFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
optionsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
optionsFrame.Parent = dropdownContainer

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, 2)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = optionsFrame

-- Modified TeleportPlayer function to use the game event
local function TeleportPlayer(locationName)
    local remoteEvent = game:GetService('ReplicatedStorage'):FindFirstChild("Shared", true)
                        :FindFirstChild("Framework", true)
                        :FindFirstChild("Network", true)
                        :FindFirstChild("Remote", true)
                        :FindFirstChild("Event")
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        local ohString1 = 'Teleport'
        local ohString2 = 'Workspace.Worlds.The Overworld.Islands.' .. locationName .. '.Island.Portal.Spawn'
        remoteEvent:FireServer(ohString1, ohString2)
    end
end


for i, locationData in ipairs(teleportLocations) do
    local locationName = locationData[1]

    local optionButton = Instance.new("TextButton")
    optionButton.Name = locationName
    optionButton.Size = UDim2.new(1, -optionsFrame.ScrollBarThickness, 0, optionHeight)
    optionButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    optionButton.BorderSizePixel = 0
    optionButton.Text = locationName
    optionButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    optionButton.Font = Enum.Font.Gotham
    optionButton.TextSize = 13
    optionButton.TextXAlignment = Enum.TextXAlignment.Left
    optionButton.TextWrapped = true
    optionButton.LayoutOrder = i
    optionButton.Parent = optionsFrame

    optionButton.MouseEnter:Connect(function()
        optionButton.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
    end)
    optionButton.MouseLeave:Connect(function()
        optionButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    end)

    optionButton.MouseButton1Click:Connect(function()
        selectedTextLabel.Text = locationName
        optionsFrame.Visible = false
        optionsListVisible = false
        arrowLabel.Text = "▼"
        dropdownContainer.ZIndex = 2 -- Reset ZIndex on selection
        TeleportPlayer(locationName) -- Pass the location name instead of coordinates
    end)
end

clickDetector.MouseButton1Click:Connect(function()
    optionsListVisible = not optionsListVisible
    optionsFrame.Visible = optionsListVisible

    -- Close other dropdowns
    if riftOptionsListVisible then
        riftOptionsFrame.Visible = false
        riftOptionsListVisible = false
        riftArrowLabel.Text = "▼"
        riftDropdownContainer.ZIndex = 2
    end
    if riftEggOptionsListVisible then
        riftEggOptionsFrame.Visible = false
        riftEggOptionsListVisible = false
        riftEggArrowLabel.Text = "▼"
        riftEggDropdownContainer.ZIndex = 2
    end

    if optionsListVisible then
        arrowLabel.Text = "▲"
        dropdownContainer.ZIndex = 10 -- Bring to front
    else
        arrowLabel.Text = "▼"
        dropdownContainer.ZIndex = 2 -- Reset ZIndex
    end
end)

-- Rift TP Dropdown
local riftDropdownContainer, riftClickDetector, riftSelectedTextLabel, riftArrowLabel = CreateDropdownVisual(
    "Rift TP",
    UDim2.new(0, 0, 0, 45), -- Position below the location dropdown
    {"Select Rift"},
    TeleportTab.LeftContent
)
riftDropdownContainer.ZIndex = 2 -- Ensure consistent starting ZIndex
riftDropdownContainer.Name = "RiftDropdownContainer"

local riftOptionsListVisible = false
local riftOptionsListHeight = 50 -- Adjust height as needed
local riftOptionHeight = 20

local riftOptionsFrame = Instance.new("ScrollingFrame")
riftOptionsFrame.Name = "RiftOptionsList"
riftOptionsFrame.Size = UDim2.new(1, 0, 0, riftOptionsListHeight)
riftOptionsFrame.Position = UDim2.new(0, 0, 1, 0)
riftOptionsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
riftOptionsFrame.BorderSizePixel = 1
riftOptionsFrame.BorderColor3 = Color3.fromRGB(50, 50, 55)
riftOptionsFrame.Visible = false
riftOptionsFrame.Active = true
riftOptionsFrame.ZIndex = 5 -- Increase ZIndex for the list itself
riftOptionsFrame.ClipsDescendants = true
riftOptionsFrame.ScrollBarThickness = 5
riftOptionsFrame.ScrollBarImageColor3 = Color3.fromRGB(170, 0, 255)
riftOptionsFrame.CanvasSize = UDim2.new(0, 0, 0, riftOptionHeight * 2 + 2) -- Adjusted for two items + padding
riftOptionsFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
riftOptionsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
riftOptionsFrame.Parent = riftDropdownContainer

local riftUiListLayout = Instance.new("UIListLayout")
riftUiListLayout.Padding = UDim.new(0, 2)
riftUiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
riftUiListLayout.Parent = riftOptionsFrame

-- Reusable Teleport Function for Rifts (Re-added)
local function TeleportToRift(riftName)
    print("Attempting to find rift:", riftName)
    local renderedFolder = workspace:WaitForChild("Rendered", 5)
    if not renderedFolder then
        print("Could not find 'Rendered' folder in workspace within 5 seconds.")
        return
    end
    print("'Rendered' folder found.")

    local riftFolder = renderedFolder:WaitForChild("Rifts", 5)
    if not riftFolder then
        print("Could not find 'Rifts' folder under 'Rendered' within 5 seconds.")
        return
    end
    print("'Rifts' folder found.")

    local riftObject = riftFolder:WaitForChild(riftName, 5)
    if riftObject then
        print("Found object named '"..riftName.."'. ClassName:", riftObject.ClassName)
        local position = nil
        if riftObject:IsA("BasePart") then
            position = riftObject.WorldPivot.Position
        elseif riftObject:IsA("Model") then
            if riftObject.PrimaryPart then
                position = riftObject.PrimaryPart.WorldPivot.Position
            else
                print("Model '"..riftName.."' has no PrimaryPart. Searching for first BasePart child...")
                for _, child in ipairs(riftObject:GetChildren()) do
                    if child:IsA("BasePart") then
                        print("Found BasePart child:", child.Name)
                        position = child.Position -- Use Position for child parts
                        break
                    end
                end
            end
        end

        if position then
            local player = Players.LocalPlayer
            local char = player.Character or player.CharacterAdded:Wait()
            local root = char:WaitForChild('HumanoidRootPart')
            local target = position
            local stepSize = 1
            local delayPerStep = 0.025

            -- Perform the step teleport (same logic as before)
            local currentPos = root.Position
            local ySafePos = Vector3.new(currentPos.X, target.Y + 10, currentPos.Z) -- Added +10 to Y for safety
            root.CFrame = CFrame.new(ySafePos)

            local function stepTeleport(startPos, endPos)
                local direction = (endPos - startPos).Unit
                local distance = (endPos - startPos).Magnitude
                local steps = math.floor(distance / stepSize)

                for i = 1, steps do
                    local nextPos = startPos + direction * (i * stepSize)
                    nextPos = Vector3.new(nextPos.X, startPos.Y, nextPos.Z) -- Lock Y
                    root.CFrame = CFrame.new(nextPos)
                    task.wait(delayPerStep)
                end
                root.CFrame = CFrame.new(endPos.X, startPos.Y, endPos.Z) -- Final correction
            end

            stepTeleport(root.Position, target)
            print("Teleported to", riftName, "at:", target)
        else
            print("Found '"..riftName.."', but couldn't determine position.")
        end
    else
        print("Could not find '"..riftName.."' under 'Rifts' within 5 seconds.")
    end
end


-- Royal Chest Button (Re-added)
local royalChestButton = Instance.new("TextButton")
royalChestButton.Name = "RoyalChest"
royalChestButton.Size = UDim2.new(1, -riftOptionsFrame.ScrollBarThickness, 0, riftOptionHeight)
royalChestButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
royalChestButton.BorderSizePixel = 0
royalChestButton.Text = "Royal Chest"
royalChestButton.TextColor3 = Color3.fromRGB(220, 220, 220)
royalChestButton.Font = Enum.Font.Gotham
royalChestButton.TextSize = 13
royalChestButton.TextXAlignment = Enum.TextXAlignment.Left
royalChestButton.LayoutOrder = 2 -- Place it after Golden Chest
royalChestButton.Parent = riftOptionsFrame

royalChestButton.MouseEnter:Connect(function() royalChestButton.BackgroundColor3 = Color3.fromRGB(55, 55, 60) end)
royalChestButton.MouseLeave:Connect(function() royalChestButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45) end)

royalChestButton.MouseButton1Click:Connect(function()
    riftSelectedTextLabel.Text = "Royal Chest"
    riftOptionsFrame.Visible = false
    local riftOptionsListVisible = false -- Tracks if the Rift TP dropdown list is open
    riftArrowLabel.Text = "▼"
    riftDropdownContainer.ZIndex = 2 -- Reset ZIndex when an item is selected
    TeleportToRift("royal-chest") -- Call the reusable function
end)


-- Golden Chest Button
local goldenChestButton = Instance.new("TextButton")
goldenChestButton.Name = "GoldenChest"
goldenChestButton.Size = UDim2.new(1, -riftOptionsFrame.ScrollBarThickness, 0, riftOptionHeight)
goldenChestButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
goldenChestButton.BorderSizePixel = 0
goldenChestButton.Text = "Golden Chest"
goldenChestButton.TextColor3 = Color3.fromRGB(220, 220, 220)
goldenChestButton.Font = Enum.Font.Gotham
goldenChestButton.TextSize = 13
goldenChestButton.TextXAlignment = Enum.TextXAlignment.Left
goldenChestButton.LayoutOrder = 1
goldenChestButton.Parent = riftOptionsFrame

goldenChestButton.MouseEnter:Connect(function() goldenChestButton.BackgroundColor3 = Color3.fromRGB(55, 55, 60) end)
goldenChestButton.MouseLeave:Connect(function() goldenChestButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45) end)

goldenChestButton.MouseButton1Click:Connect(function()
    riftSelectedTextLabel.Text = "Golden Chest"
    riftOptionsFrame.Visible = false
    riftOptionsListVisible = false
    riftArrowLabel.Text = "▼"
    
    print("Attempting to find Golden Chest...")
    local renderedFolder = workspace:WaitForChild("Rendered", 5) -- Wait up to 5 seconds for Rendered
    if not renderedFolder then
        print("Could not find 'Rendered' folder in workspace within 5 seconds.")
        return
    end
    print("'Rendered' folder found.")

    local riftFolder = renderedFolder:WaitForChild("Rifts", 5) -- Wait up to 5 seconds for Rifts
    if not riftFolder then
        print("Could not find 'Rifts' folder under 'Rendered' within 5 seconds.")
        return
    end
    print("'Rifts' folder found.")

    local goldenChest = riftFolder:WaitForChild("golden-chest", 5) -- Wait up to 5 seconds for golden-chest
    if goldenChest then
        print("Found object named 'golden-chest'. ClassName:", goldenChest.ClassName)
        local position = nil
        if goldenChest:IsA("BasePart") then
            position = goldenChest.WorldPivot.Position
        elseif goldenChest:IsA("Model") then
            if goldenChest.PrimaryPart then
                position = goldenChest.PrimaryPart.WorldPivot.Position
            else
                print("Model 'golden-chest' has no PrimaryPart. Searching for first BasePart child...")
                for _, child in ipairs(goldenChest:GetChildren()) do
                    if child:IsA("BasePart") then
                        print("Found BasePart child:", child.Name)
                        position = child.Position -- Use Position instead of WorldPivot.Position for child parts
                        break -- Use the first one found
                    end
                end
            end
        end

        if position then
-- Teleport logic starts here
            -- Services (already defined globally, but good practice to have locally if needed)
            -- local Players = game:GetService('Players')
            -- local RunService = game:GetService('RunService')

            -- Player setup (get fresh references)
            local player = Players.LocalPlayer
            local char = player.Character or player.CharacterAdded:Wait()
            local root = char:WaitForChild('HumanoidRootPart')

            -- Target position (using the found golden chest position)
            local target = position
            local stepSize = 1 -- studs per step
            local delayPerStep = 0.025 -- time between steps (slower)

            -- Step 1: Teleport vertically to the target Y height
            local currentPos = root.Position
            local ySafePos = Vector3.new(currentPos.X, target.Y + 10, currentPos.Z)
            root.CFrame = CFrame.new(ySafePos)

            -- Step 2: Move in small steps toward the target position (X/Z), keeping Y fixed
            local function stepTeleport(startPos, endPos)
                local direction = (endPos - startPos).Unit
                local distance = (endPos - startPos).Magnitude
                local steps = math.floor(distance / stepSize)

                for i = 1, steps do
                    local nextPos = startPos + direction * (i * stepSize)
                    nextPos = Vector3.new(nextPos.X, startPos.Y, nextPos.Z) -- Lock Y
                    root.CFrame = CFrame.new(nextPos)
                    task.wait(delayPerStep)
                end

                -- Final correction to exact position (still locks Y)
                root.CFrame = CFrame.new(endPos.X, startPos.Y, endPos.Z)
            end

            -- Start the step teleport to the target
            stepTeleport(root.Position, target)
            print("Teleported to Golden Chest at:", target) -- Optional confirmation print        
        else
            print("Found 'golden-chest', but couldn't determine position (not BasePart, Model has no PrimaryPart or BasePart children).")
        end
    else
        print("Could not find 'golden-chest' under 'Rifts' within 5 seconds.")
    end
end)

-- Rift Egg TP Dropdown
local riftEggDropdownContainer, riftEggClickDetector, riftEggSelectedTextLabel, riftEggArrowLabel = CreateDropdownVisual(
    "Rift Egg TP",
    UDim2.new(0, 0, 0, 90), -- Position below the Rift TP dropdown
    {"Select Egg"},
    TeleportTab.LeftContent
)
riftEggDropdownContainer.ZIndex = 2 -- Ensure consistent starting ZIndex
riftEggDropdownContainer.Name = "RiftEggDropdownContainer"

local riftEggOptionsListVisible = false
local riftEggOptionsListHeight = 100 -- Start height, will adjust
local riftEggOptionHeight = 20

local riftEggOptionsFrame = Instance.new("ScrollingFrame")
riftEggOptionsFrame.Name = "RiftEggOptionsList"
riftEggOptionsFrame.Size = UDim2.new(1, 0, 0, riftEggOptionsListHeight)
riftEggOptionsFrame.Position = UDim2.new(0, 0, 1, 0)
riftEggOptionsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
riftEggOptionsFrame.BorderSizePixel = 1
riftEggOptionsFrame.BorderColor3 = Color3.fromRGB(50, 50, 55)
riftEggOptionsFrame.Visible = false
riftEggOptionsFrame.Active = true
riftEggOptionsFrame.ZIndex = 5
riftEggOptionsFrame.ClipsDescendants = true
riftEggOptionsFrame.ScrollBarThickness = 5
riftEggOptionsFrame.ScrollBarImageColor3 = Color3.fromRGB(170, 0, 255)
riftEggOptionsFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Start empty
riftEggOptionsFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
riftEggOptionsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
riftEggOptionsFrame.Parent = riftEggDropdownContainer

local riftEggUiListLayout = Instance.new("UIListLayout")
riftEggUiListLayout.Padding = UDim.new(0, 2)
riftEggUiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
riftEggUiListLayout.Parent = riftEggOptionsFrame

riftClickDetector.MouseButton1Click:Connect(function()
    -- Close the other dropdown if it's open
    if riftEggOptionsListVisible then
        riftEggOptionsFrame.Visible = false
        riftEggOptionsListVisible = false
        riftEggArrowLabel.Text = "▼"
        
        riftEggDropdownContainer.ZIndex = 2 -- Reset other dropdown's ZIndex
    end

    riftOptionsListVisible = not riftOptionsListVisible
    riftOptionsFrame.Visible = riftOptionsListVisible
    if riftOptionsListVisible then
        riftArrowLabel.Text = "▲"
        riftDropdownContainer.ZIndex = 10
    else
        riftArrowLabel.Text = "▼"
        riftDropdownContainer.ZIndex = 2
    end
end)



local function PopulateRiftEggs()
    -- Clear existing buttons
    for _, child in ipairs(riftEggOptionsFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local riftFolder = workspace.Rendered:FindFirstChild("Rifts")
    if not riftFolder then
        print("Could not find Rifts folder to populate eggs.")
        riftEggOptionsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        return
    end

    local eggCount = 0
    for i, child in ipairs(riftFolder:GetChildren()) do
        if string.sub(child.Name, -4) == "-egg" then
            eggCount = eggCount + 1
            local eggName = child.Name

            local eggButton = Instance.new("TextButton")
            eggButton.Name = eggName
            eggButton.Size = UDim2.new(1, -riftEggOptionsFrame.ScrollBarThickness, 0, riftEggOptionHeight)
            eggButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            eggButton.BorderSizePixel = 0
            eggButton.Text = eggName:gsub("-", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end) -- Nicer formatting
            eggButton.TextColor3 = Color3.fromRGB(220, 220, 220)
            eggButton.Font = Enum.Font.Gotham
            eggButton.TextSize = 13
            eggButton.TextXAlignment = Enum.TextXAlignment.Left
            eggButton.LayoutOrder = eggCount
            eggButton.Parent = riftEggOptionsFrame

            eggButton.MouseEnter:Connect(function() eggButton.BackgroundColor3 = Color3.fromRGB(55, 55, 60) end)
            eggButton.MouseLeave:Connect(function() eggButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45) end)

            eggButton.MouseButton1Click:Connect(function()
                riftEggSelectedTextLabel.Text = eggButton.Text -- Use the formatted text
                riftEggOptionsFrame.Visible = false
                riftEggOptionsListVisible = false
                riftEggArrowLabel.Text = "▼"
                riftEggDropdownContainer.ZIndex = 2 -- Reset ZIndex on selection
                TeleportToRift(eggName) -- Call the existing teleport function with the actual object name
            end)
        end
    end
    -- Adjust CanvasSize based on the number of eggs found
    riftEggOptionsFrame.CanvasSize = UDim2.new(0, 0, 0, eggCount * riftEggOptionHeight + (eggCount > 0 and (eggCount - 1) * riftEggUiListLayout.Padding.Offset or 0))
end

riftEggClickDetector.MouseButton1Click:Connect(function()
    -- Close other dropdowns
    if optionsListVisible then
        optionsFrame.Visible = false
        optionsListVisible = false
        arrowLabel.Text = "▼"
        dropdownContainer.ZIndex = 2
    end
    if riftOptionsListVisible then
        riftOptionsFrame.Visible = false
        riftOptionsListVisible = false
        riftArrowLabel.Text = "▼"
        riftDropdownContainer.ZIndex = 2
    end

    riftEggOptionsListVisible = not riftEggOptionsListVisible
    if riftEggOptionsListVisible then
        PopulateRiftEggs() -- Update the list right before showing
        riftEggArrowLabel.Text = "▲"
        riftEggDropdownContainer.ZIndex = 10 -- Bring to front
    else
        riftEggArrowLabel.Text = "▼"
        riftEggDropdownContainer.ZIndex = 2 -- Reset ZIndex
    end
    riftEggOptionsFrame.Visible = riftEggOptionsListVisible
end)


-- Settings Tab Content

AutoBubble.Changed.Event:Connect(function(newState)
    autoBubbleLoopActive = newState
    if autoBubbleLoopActive then
        while autoBubbleLoopActive do
        game:GetService("ReplicatedStorage").Shared.Framework.Network.Remote.Event:FireServer("BlowBubble")
        task.wait(0.1)
        end
    end
end)

-- NoClip Logic
local function StartNoClip()
    if noclipConnection then noclipConnection:Disconnect() end -- Disconnect previous if any
    isNoClipping = true
    print("NoClip Enabled")
    noclipConnection = RunService.Stepped:Connect(function()
        if not isNoClipping then
            if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
            return
        end
        local currentCharacter = LocalPlayer.Character
        if currentCharacter then
            for _, part in ipairs(currentCharacter:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function StopNoClip()
    isNoClipping = false
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    print("NoClip Disabled")
    -- Note: Collision state is not automatically restored. Player needs to reset/respawn for full collision.
end

NoClipCheckbox.Changed.Event:Connect(function(newState)
    if newState then StartNoClip() else StopNoClip() end
end)

HatchingZone.MouseButton1Click:Connect(function()
   
    local wasNoClipping = isNoClipping -- Check if noclip was already on
    -- Enable NoClip if not already enabled
    if not wasNoClipping then
        StartNoClip()
        NoClipCheckbox.SetValue(true) -- Update checkbox visually
        task.wait(0.1) -- Small delay to ensure noclip takes effect
    end

    -- Teleport Logic (using step teleport)
    local player = Players.LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild('HumanoidRootPart')
    local target = Vector3.new(-71, 9, -21)
    local stepSize = 1
    local delayPerStep = 0.025

    local currentPos = root.Position
    local ySafePos = Vector3.new(currentPos.X, target.Y + 10, currentPos.Z) -- Go slightly above first
    root.CFrame = CFrame.new(ySafePos)

    local function stepTeleport(startPos, endPos)
        local direction = (endPos - startPos).Unit
        local distance = (endPos - startPos).Magnitude
        local steps = math.floor(distance / stepSize)
        for i = 1, steps do
            local nextPos = startPos + direction * (i * stepSize)
            nextPos = Vector3.new(nextPos.X, startPos.Y, nextPos.Z) -- Lock Y
            root.CFrame = CFrame.new(nextPos)
            task.wait(delayPerStep)
        end
        root.CFrame = CFrame.new(endPos.X, startPos.Y, endPos.Z) -- Final correction
    end

    stepTeleport(root.Position, target)
    print("Arrived at secret spot.")

    -- Disable NoClip if it wasn't originally enabled
    if not wasNoClipping then
        task.wait(0.1) -- Small delay before disabling
        StopNoClip()
        NoClipCheckbox.SetValue(false) -- Update checkbox visually
    end
end)


UnlockAll.MouseButton1Click:Connect(function()

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild('HumanoidRootPart')

local unlockAllLocations = {
    {"Floating Island", Vector3.new(-15.85, 422.76, 143.42)},
    {"Outer Space", Vector3.new(41.50, 2662.87, -6.40)},
    {"Twilight", Vector3.new(-77.94, 6862.18, 88.33)},
    {"The Void", Vector3.new(15.98, 10145.70, 151.72)},
    {"Zen", Vector3.new(36.30, 15971.42, 41.87)}
}

-- Function to teleport to each Y coordinate one by one
local function teleportToLocations()

    for _, location in ipairs(unlockAllLocations) do
        local name, position = unpack(location)

        local currentPos = root.Position
        local ySafePos = Vector3.new(currentPos.X, position.Y, currentPos.Z)
        root.CFrame = CFrame.new(ySafePos)
        
        task.wait(0.3)
    end
end
teleportToLocations()

end)

local EjectButton = CreateButton("Eject Script", UDim2.new(0, 0, 0, 0), UDim2.new(1, -10, 0, 25), SettingsTab.LeftContent)

EjectButton.MouseButton1Click:Connect(function()
    if isNoClipping then StopNoClip() end -- Stop noclip on eject
    EloHub.Enabled = false
    for key, listener in pairs(keybindListeners) do
       if listener and listener.Disconnect then listener:Disconnect() end
    end
    keybindListeners = {}
    activeKeybinds = {}
    EloHub:Destroy()
end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    originalWalkSpeed = Humanoid.WalkSpeed
    isWalkSpeedEnabled = false
    if isNoClipping then -- Stop noclip if character respawns
        StopNoClip()
        NoClipCheckbox.SetValue(false) -- Uncheck the box visually
    end
    WalkSpeedCheckbox.SetValue(false)
    WalkSpeedSlider.SetValue(originalWalkSpeed)
end)

local function AdjustCanvasSize(scrollFrame)
    local totalHeight = 0
    local padding = 0
    local uiLayout = scrollFrame:FindFirstChildOfClass("UIListLayout") or scrollFrame:FindFirstChildOfClass("UIGridLayout")

    if scrollFrame:FindFirstChildWhichIsA("UIPadding") then
        padding = scrollFrame.UIPadding.PaddingTop.Offset + scrollFrame.UIPadding.PaddingBottom.Offset
    end

    local elementCount = 0
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("GuiObject") and not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UIScrollBar") then
            elementCount = elementCount + 1
            totalHeight = totalHeight + child.AbsoluteSize.Y
        end
    end

    if uiLayout and elementCount > 1 and uiLayout:IsA("UIListLayout") then
         padding = padding + uiLayout.Padding.Offset * (elementCount - 1)
    end

    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + padding + 5)
end



local function SetupCanvasAdjustmentListener(scrollFrame)
     local function DelayedAdjust()
         task.wait()
         AdjustCanvasSize(scrollFrame)
     end

    scrollFrame.ChildAdded:Connect(DelayedAdjust)
    scrollFrame.ChildRemoved:Connect(DelayedAdjust)

     for _, child in ipairs(scrollFrame:GetChildren()) do
         if child:IsA("GuiObject") and not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UIScrollBar") then
             if keybindListeners[child] then keybindListeners[child]:Disconnect() end
             keybindListeners[child] = child:GetPropertyChangedSignal("AbsoluteSize"):Connect(DelayedAdjust)
         end
     end
end

SetupCanvasAdjustmentListener(MainTab.LeftContent)
SetupCanvasAdjustmentListener(MainTab.RightContent)
SetupCanvasAdjustmentListener(SettingsTab.LeftContent)
SetupCanvasAdjustmentListener(TeleportTab.LeftContent) -- Added for Teleport tab



keybindListeners["GlobalInput"] = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end

    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Insert then
            EloHub.Enabled = not EloHub.Enabled
        else
            local toggleFunc = activeKeybinds[input.KeyCode]
            if toggleFunc then
                toggleFunc()
            end
        end
    end
end)

-- Initial Adjustment
task.wait(0.5) -- Wait for UI to fully load before first adjust
AdjustCanvasSize(MainTab.LeftContent)
AdjustCanvasSize(MainTab.RightContent)
AdjustCanvasSize(SettingsTab.LeftContent)