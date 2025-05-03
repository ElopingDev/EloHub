-- EloHub v1.0


-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Added for RemoteEvent
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
local isFlying = false
local flySpeed = 50
local flyLoopConnection = nil
local FastDrillLoopConnection = nil -- Added for Auto Mine Ore loop
local walkSpeedLoopConnection = nil -- Added for persistent walkspeed
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

local function CreateButton(text, position, size, parent, featureId) -- Added featureId for potential keybinds
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

    local keybindButton = nil
    local currentKeybind = nil
    local listeningConnection = nil

    -- Add keybind button only if featureId is provided
    if featureId then
        keybindButton = Instance.new("TextButton")
        keybindButton.Name = "KeybindButton"
        keybindButton.Size = UDim2.new(0, 50, 0, 18)
        -- Position it relative to the main button or parent frame
        keybindButton.Position = UDim2.new(1, 10, 0.5, -9) -- Adjust as needed
        keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        keybindButton.BorderSizePixel = 0
        keybindButton.Text = "Set Key"
        keybindButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        keybindButton.Font = Enum.Font.Gotham
        keybindButton.TextSize = 10
        keybindButton.Parent = button -- Parent to the main button or parent frame

        local keybindCorner = Instance.new("UICorner")
        keybindCorner.CornerRadius = UDim.new(0, 3)
        keybindCorner.Parent = keybindButton

        keybindButton.MouseButton1Click:Connect(function()
            keybindButton.Text = "..."
            if listeningConnection then listeningConnection:Disconnect() end

            listeningConnection = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
                if gameProcessedEvent then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    local keyCode = input.KeyCode
                    if currentKeybind and activeKeybinds[currentKeybind] then activeKeybinds[currentKeybind] = nil end
                    if keyCode and keyCode ~= Enum.KeyCode.Backspace then
                        currentKeybind = keyCode
                        keybindButton.Text = keyCode.Name
                        activeKeybinds[currentKeybind] = function() button.MouseButton1Click:Fire() end -- Store function to fire click
                    else
                        currentKeybind = nil
                        keybindButton.Text = "Set Key"
                    end
                    if listeningConnection then listeningConnection:Disconnect(); listeningConnection = nil end
                end
            end)
        end)
    end

    return button -- Return the main button instance
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

local MainIcon = CreateSidebarIcon("🐟", UDim2.new(0, 5, 0, 5), Sidebar)
local MovementIcon = CreateSidebarIcon("🏃", UDim2.new(0, 5, 0, 60), Sidebar)
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
local SettingsTab = CreateTabPanel("SettingsTab")
local MovementTab = CreateTabPanel("MovementTab")


MainTab.LeftTitle.Text = "Main"
MainTab.RightTitle.Text = "Settings"

SettingsTab.LeftTitle.Text = "Options"
SettingsTab.RightTitle.Text = "" -- Hide right panel title for settings

MovementTab.LeftTitle.Text = "Movement"
MovementTab.RightTitle.Text = ""


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

MovementIcon.MouseButton1Click:Connect(function()
    SwitchTab(MovementTab)
end)

-- Feature Checkboxes (Assign unique IDs)
local FastDrillCheckbox = CreateCheckbox("Fast Drill", UDim2.new(0, 0, 0, 0), MainTab.LeftContent, "Fast Drill")
local CollectAllButton = CreateButton("Collect All", UDim2.new(0, 0, 0, 25), UDim2.new(1, -70, 0, 25), MainTab.LeftContent, "CollectAll") -- Added featureId, adjusted size
local InstaSellButton = CreateButton("Insta Sell", UDim2.new(0, 0, 0, 55), UDim2.new(1, -70, 0, 25), MainTab.LeftContent, "InstaSell")

local FlyCheckbox = CreateCheckbox("Fly", UDim2.new(0, 0, 0, 0), MovementTab.LeftContent, "Fly")
local FlySpeedSlider = CreateSlider("Fly Speed", 10, 500, flySpeed, UDim2.new(0, 0, 0, 25), MovementTab.LeftContent)
local WalkSpeedCheckbox = CreateCheckbox("Enable Walk Speed", UDim2.new(0, 0, 0, 70), MovementTab.LeftContent, "WalkSpeed")
local WalkSpeedSlider = CreateSlider("Walk Speed", 16, 500, originalWalkSpeed, UDim2.new(0, 0, 0, 95), MovementTab.LeftContent)

InstaSellButton.MouseButton1Click:Connect(function()
    local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end -- Add check
    local originalCFrame = rootPart.CFrame
    local sellPosition = Vector3.new(-382.6591491699219, 92.03533935546875, 282.90802001953125) -- Use full precision
    local sellAllRE = ReplicatedStorage.Packages.Knit.Services.OreService.RE.SellAll

    rootPart.CFrame = CFrame.new(sellPosition)
    task.wait(0.25) -- Reduced wait time slightly
    sellAllRE:FireServer()
    -- task.wait() -- Uncomment if TP back happens too fast
    rootPart.CFrame = originalCFrame
end)


-- Settings Tab Content
local EjectButton = CreateButton("Eject Script", UDim2.new(0, 0, 0, 0), UDim2.new(1, -10, 0, 25), SettingsTab.LeftContent)

EjectButton.MouseButton1Click:Connect(function()
    if flyLoopConnection then
        flyLoopConnection:Disconnect()
        flyLoopConnection = nil
    end
    if isWalkSpeedEnabled and Humanoid then
        Humanoid.WalkSpeed = originalWalkSpeed
    end
    if FastDrillLoopConnection then -- Stop auto-mine loop on eject
        FastDrillLoopConnection:Disconnect()
        FastDrillLoopConnection = nil
    end
    if walkSpeedLoopConnection then -- Stop walkspeed loop on eject
        walkSpeedLoopConnection:Disconnect()
        walkSpeedLoopConnection = nil
    end
    EloHub.Enabled = false
    for key, listener in pairs(keybindListeners) do
       if listener and listener.Disconnect then listener:Disconnect() end
    end
    keybindListeners = {}
    activeKeybinds = {}
    EloHub:Destroy()
end)

local flyVelocity = nil
local flyGyro = nil

local function StartFly()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid")

    if not Humanoid then return end

    local RootPart = Character:FindFirstChild("HumanoidRootPart")
    if not RootPart then return end

    if flyVelocity then flyVelocity:Destroy() end
    if flyGyro then flyGyro:Destroy() end

    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyVelocity.Parent = RootPart

    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyGyro.CFrame = RootPart.CFrame
    flyGyro.Parent = RootPart

    Humanoid.PlatformStand = true

    if flyLoopConnection then flyLoopConnection:Disconnect() end

    flyLoopConnection = RunService.RenderStepped:Connect(function()
        if isFlying and Humanoid and RootPart and Humanoid.Health > 0 then
            local direction = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + workspace.CurrentCamera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - workspace.CurrentCamera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - workspace.CurrentCamera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + workspace.CurrentCamera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.new(0, 1, 0) end

            if direction.Magnitude > 0 then
                flyVelocity.Velocity = direction.Unit * flySpeed
            else
                flyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
            flyGyro.CFrame = workspace.CurrentCamera.CFrame
        elseif isFlying then
            StopFly()
            FlyCheckbox.SetValue(false)
        end
    end)
end

local function StopFly()
    if flyLoopConnection then
        flyLoopConnection:Disconnect()
        flyLoopConnection = nil
    end
    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end
    if flyGyro then
        flyGyro:Destroy()
        flyGyro = nil
    end
    if Humanoid and Humanoid.Parent then
        Humanoid.PlatformStand = false
    end
end

FlyCheckbox.Changed.Event:Connect(function(newState)
    isFlying = newState
    if isFlying then
        StartFly()
    else
        StopFly()
    end
end)

FlySpeedSlider.Changed.Event:Connect(function(value)
    flySpeed = value
    if isFlying and flyVelocity then
        local currentDirection = flyVelocity.Velocity
        if currentDirection.Magnitude > 0 then
             flyVelocity.Velocity = currentDirection.Unit * flySpeed
        end
    end
end)

WalkSpeedSlider.Changed.Event:Connect(function(value)
    if isWalkSpeedEnabled and Humanoid and Humanoid.Parent then
        Humanoid.WalkSpeed = value
    end
end)

WalkSpeedCheckbox.Changed.Event:Connect(function(newState)
    isWalkSpeedEnabled = newState

    if walkSpeedLoopConnection then
        walkSpeedLoopConnection:Disconnect()
        walkSpeedLoopConnection = nil
    end

    if isWalkSpeedEnabled then
        if Humanoid and Humanoid.Parent then
            walkSpeedLoopConnection = RunService.Heartbeat:Connect(function()
                if isWalkSpeedEnabled and Humanoid and Humanoid.Parent and Humanoid.Health > 0 then
                    Humanoid.WalkSpeed = WalkSpeedSlider.GetValue()
                else
                    -- Stop if conditions are no longer met
                    if walkSpeedLoopConnection then
                        walkSpeedLoopConnection:Disconnect()
                        walkSpeedLoopConnection = nil
                    end
                    isWalkSpeedEnabled = false
                    WalkSpeedCheckbox.SetValue(false) -- Uncheck the box visually
                    if Humanoid and Humanoid.Parent then Humanoid.WalkSpeed = originalWalkSpeed end -- Revert speed if humanoid still exists
                end
            end)
        else
            -- If humanoid doesn't exist when enabling, just disable it again
            isWalkSpeedEnabled = false
            WalkSpeedCheckbox.SetValue(false)
        end
    end
end)

-- Auto Mine Ore Logic
local FastDrillTimer = 0 -- Timer for 0.1s interval
FastDrillCheckbox.Changed.Event:Connect(function(isChecked)
    if FastDrillLoopConnection then
        FastDrillLoopConnection:Disconnect()
        FastDrillLoopConnection = nil
        FastDrillTimer = 0 -- Reset timer when loop stops
    end

    if isChecked then
        -- Find the RemoteEvent safely
        local oreServiceRE = ReplicatedStorage:FindFirstChild("Packages", true)
                                and ReplicatedStorage.Packages:FindFirstChild("Knit", true)
                                and ReplicatedStorage.Packages.Knit:FindFirstChild("Services", true)
                                and ReplicatedStorage.Packages.Knit.Services:FindFirstChild("OreService", true)
                                and ReplicatedStorage.Packages.Knit.Services.OreService:FindFirstChild("RE", true)
                                and ReplicatedStorage.Packages.Knit.Services.OreService.RE:FindFirstChild("RequestRandomOre")

        if oreServiceRE and oreServiceRE:IsA("RemoteEvent") then
            FastDrillLoopConnection = RunService.Heartbeat:Connect(function(dt)
                FastDrillTimer = FastDrillTimer + dt
                if FastDrillTimer >= 0.1 then
                    FastDrillTimer = FastDrillTimer - 0.1 -- Subtract interval

                    -- Check if the checkbox UI element still exists and is visually checked
                    local checkMark = FastDrillCheckbox.Container:FindFirstChild("CheckboxFrame"):FindFirstChild("CheckMark")
                    if checkMark and checkMark.Visible and checkMark.Parent and checkMark.Parent.Parent == FastDrillCheckbox.Container then
                        oreServiceRE:FireServer()
                    else
                        -- If checkbox is gone or unchecked, stop the loop
                        if FastDrillLoopConnection then
                            FastDrillLoopConnection:Disconnect()
                            FastDrillLoopConnection = nil
                            FastDrillTimer = 0 -- Reset timer
                        end
                        -- Ensure the checkbox state is false if the loop stops unexpectedly
                        FastDrillCheckbox.SetValue(false)
                    end
                end
            end)
        else
            warn("EloHub: Could not find RequestRandomOre RemoteEvent at ReplicatedStorage.Packages.Knit.Services.OreService.RE.RequestRandomOre. Auto Mine Ore feature disabled.")
            FastDrillCheckbox.SetValue(false) -- Uncheck if the RE doesn't exist
        end
    end
end)

-- Auto Collect All Logic
local function performCollection()
    -- Ensure Knit and PlotService are accessible
    local Knit = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Knit")
    if not Knit then return end -- Exit if Knit not found
    local PlotService = Knit:FindFirstChild("Services") and Knit.Services:FindFirstChild("PlotService")
    if not PlotService then return end -- Exit if PlotService not found
    local CollectDrillRE = PlotService:FindFirstChild("RE") and PlotService.RE:FindFirstChild("CollectDrill")
    if not (CollectDrillRE and CollectDrillRE:IsA("RemoteEvent")) then return end -- Exit if RE not found

    local plotsFolder = workspace:FindFirstChild("Plots")
    if not plotsFolder then return end -- Exit if Plots folder doesn't exist

    for _, plot in ipairs(plotsFolder:GetChildren()) do
        if plot:IsA("Folder") then
            local ownerValue = plot:FindFirstChild("Owner")
            if ownerValue and ownerValue:IsA("ObjectValue") and ownerValue.Value == LocalPlayer then
                -- Collect from Drills
                local drillsFolder = plot:FindFirstChild("Drills")
                if drillsFolder then
                    for _, drill in ipairs(drillsFolder:GetChildren()) do
                        CollectDrillRE:FireServer(drill)
                        task.wait() -- Small delay between fires to avoid potential throttling
                    end
                end

                -- Collect from Storage (Assuming storage uses the same event)
                local storageFolder = plot:FindFirstChild("Storage")
                if storageFolder then
                    for _, storageItem in ipairs(storageFolder:GetChildren()) do
                        CollectDrillRE:FireServer(storageItem)
                        task.wait() -- Small delay between fires
                    end
                end
            end
        end
    end
end

-- Collect All Button Logic
CollectAllButton.MouseButton1Click:Connect(function()
    performCollection() -- Just run the collection function once
end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    originalWalkSpeed = Humanoid.WalkSpeed
    isWalkSpeedEnabled = false
    WalkSpeedCheckbox.SetValue(false)
    WalkSpeedSlider.SetValue(originalWalkSpeed)

    if walkSpeedLoopConnection then -- Stop loop on character respawn
        walkSpeedLoopConnection:Disconnect()
        walkSpeedLoopConnection = nil
    end

    if FastDrillLoopConnection then -- Stop auto-mine loop on respawn
        FastDrillLoopConnection:Disconnect()
        FastDrillCheckbox.SetValue(false) -- Reset checkbox state
        walkSpeedLoopConnection = nil -- This line seems misplaced, should be FastDrillLoopConnection = nil? Correcting below
        FastDrillLoopConnection = nil
    end

    if isFlying then
        task.wait(0.5)
        isFlying = false
        FlyCheckbox.SetValue(false)
        StopFly()
    else
       StopFly()
    end

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
SetupCanvasAdjustmentListener(MovementTab.LeftContent)


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
AdjustCanvasSize(MovementTab.LeftContent)
