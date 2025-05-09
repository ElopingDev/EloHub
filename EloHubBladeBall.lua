-- EloHub v1.0

-- Services
local PlayersService = game:GetService("Players") -- Standard way to get the service

-- Ensure LocalPlayer is available, especially important after teleports/reloads
local LocalPlayer = PlayersService.LocalPlayer
if not LocalPlayer then
    repeat
        task.wait() -- Wait a very short moment (typically one frame)
        LocalPlayer = PlayersService.LocalPlayer
    until LocalPlayer
end

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService") or game:FindFirstDescendant("RunService")
local HttpService = game:GetService("HttpService") -- Added for JSON encoding/decoding
local VirtualInputManager = game:GetService("VirtualInputManager") or game:FindFirstDescendant("VirtualInputManager")

-- Clean up old GUI if script is re-run
if game:GetService("CoreGui"):FindFirstChild("EloHub") then
    game:GetService("CoreGui").EloHub:Destroy()
end
-- Use the guaranteed LocalPlayer for cleanup; it's confirmed not to be nil here
if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EloHub") then
    LocalPlayer.PlayerGui.EloHub:Destroy()
end

-- Variables
local Player = LocalPlayer -- 'Player' alias for the already defined and waited-for LocalPlayer
local Character = LocalPlayer.Character
local HRP = Character and Character:FindFirstChild("HumanoidRootPart")
local Humanoid = Character and Character:FindFirstChild("Humanoid")
local Mouse = LocalPlayer:GetMouse()
local dragging = false
local dragInput
local dragStart
local startPos
local isEjected = false -- For handling script ejection cleanly

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart") -- Ensure HRP is from the new character
    Humanoid = char:WaitForChild("Humanoid") -- Ensure Humanoid is from the new character
end)

LocalPlayer.CharacterRemoving:Connect(function(char)
    if Character == char then
        Character = nil
        HRP = nil
        Humanoid = nil
    end
end)

local activeKeybinds = {}
local keybindListeners = {}
local checkboxRegistry = {} -- To help map keybinds on load

local AutoParryActive = false
local CooldownTime = 1
local LastParryTime = 0
local Parried = false
local BallConnection = nil

-- Parry timing settings
local DelayOffset = 0.1        -- Don't parry too early
local IdealParryTime = 0.25    -- Try to parry ~0.25s before impact

-- Settings saving and loading
local BLADE_BALL_GAME_ID = 4777817887 -- Universe ID for Blade Ball

local function LoadSettings()
    if game.GameId ~= BLADE_BALL_GAME_ID then return end

    local success, clipboardContent = pcall(getclipboard)
    if success and type(clipboardContent) == "string" and clipboardContent ~= "" then
        local decodedSuccess, settings = pcall(HttpService.JSONDecode, HttpService, clipboardContent)
        if decodedSuccess and type(settings) == "table" then
            _G.EloHubSettings = settings -- Store in _G temporarily until UI is ready
        else
            warn("EloHub: Failed to decode settings from clipboard or settings are not a table. Content: ", clipboardContent, "Error: ", settings)
        end
    end
end

local function SaveSettings()
    if isEjected or game.GameId ~= BLADE_BALL_GAME_ID then return end

    local settingsToSave = {}
    for id, data in pairs(checkboxRegistry) do
        local keybindName = nil
        if data.GetKeybind and data.GetKeybind() then
            keybindName = data.GetKeybind().Name
        end
        settingsToSave[id] = {
            isChecked = data.Container:FindFirstChild("CheckboxFrame"):FindFirstChild("CheckMark").Visible,
            keybind = keybindName
        }
    end
    local success, encodedSettings = pcall(HttpService.JSONEncode, HttpService, settingsToSave)
    if success then
        pcall(setclipboard, encodedSettings)
    else
        warn("EloHub: Failed to encode settings. Error: ", encodedSettings)
    end
end

LoadSettings() -- Load settings early

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
        if featureId and checkboxRegistry[featureId] then -- Ensure featureId is valid and checkbox is registered
            checkboxRegistry[featureId].CurrentKeybind = currentKeybind -- Update registry
        end
        SaveSettings() -- Save settings whenever a keybind changes
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
            -- SaveSettings() is called by the Changed event now
        end,
        Toggle = ToggleCheckbox,
        GetKeybind = function() return currentKeybind end,
        SetKeybind = SetKeybind, -- Expose SetKeybind
        KeybindButton = keybindButton -- Expose KeybindButton to update text
    }

    if featureId then
         checkboxRegistry[featureId] = checkboxData -- Register the checkbox
    end

    changedSignal.Event:Connect(function()
        SaveSettings() -- Save settings whenever a checkbox state changes
    end)

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
    local dragging = false
    local dragInput
    local dragStart
    local startPos

    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            -- Get the mouse position
            local mousePos = UserInputService:GetMouseLocation()
            
            -- Check if we're clicking on a button
            local clickedOnButton = false
            for _, child in pairs(topbar:GetChildren()) do
                if (child:IsA("TextButton") or child:IsA("ImageButton")) then
                    local buttonPos = child.AbsolutePosition
                    local buttonSize = child.AbsoluteSize
                    
                    -- Check if mouse is within the button's bounds
                    if mousePos.X >= buttonPos.X and mousePos.X <= buttonPos.X + buttonSize.X and
                       mousePos.Y >= buttonPos.Y and mousePos.Y <= buttonPos.Y + buttonSize.Y then
                        clickedOnButton = true
                        break
                    end
                end
            end
            
            if clickedOnButton then
                return -- Don't start dragging if clicked on a button
            end
            
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

local MainIcon = CreateSidebarIcon("🏀", UDim2.new(0, 5, 0, 5), Sidebar)
local SettingsIcon = CreateSidebarIcon("⚙️", UDim2.new(0, 5, 0, 60), Sidebar)


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


MainTab.LeftTitle.Text = "Main"
MainTab.RightTitle.Text = "Settings"

SettingsTab.LeftTitle.Text = "Options"
SettingsTab.RightTitle.Text = "" -- Hide right panel title for settings

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



-- Feature Checkboxes (Assign unique IDs)
local AutoParry = CreateCheckbox("AutoParry", UDim2.new(0, 0, 0, 0), MainTab.LeftContent, "AutoParry")
local Feature2 = CreateCheckbox("Feature2", UDim2.new(0, 0, 0, 25), MainTab.LeftContent, "Feature2")
local Feature3 = CreateButton("Feature3", UDim2.new(0, 0, 0, 75), UDim2.new(1, -10, 0, 25), MainTab.LeftContent)

local function GetBall()
    for _, Ball in ipairs(workspace:WaitForChild("Balls"):GetChildren()) do
        if Ball:GetAttribute("realBall") then
            return Ball
        end
    end
end

local function ResetConnection()
    if BallConnection then
        BallConnection:Disconnect()
        BallConnection = nil
    end
end

workspace.Balls.ChildAdded:Connect(function()
    local Ball = GetBall()
    if not Ball then return end
    ResetConnection()
    BallConnection = Ball:GetAttributeChangedSignal("target"):Connect(function()
        Parried = false
        LastParryTime = 0 -- Reset cooldown
    end)
end)


-- Hooking the AutoParry checkbox change to toggle auto parry
AutoParry.Changed.Event:Connect(function(newState)
    AutoParryActive = newState
end)

RunService.RenderStepped:Connect(function()
    -- Run the auto-parry logic only if AutoParry is active
    if not AutoParryActive then return end
    
    local currentCharacter = Player.Character -- Use a local variable for current character state in this frame
    local currentHRP = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
    if not currentCharacter or not currentHRP then return end -- Essential check: no character/HRP, no parry

    local Ball = GetBall()
    if not Ball then return end

    local Velocity = Ball.AssemblyLinearVelocity
    local Speed = Velocity.Magnitude
    -- local Distance = (currentHRP.Position - Ball.Position).Magnitude -- Distance to current ball pos, not used for TimeToImpact directly
    
    -- If ball speed is very low, don't try to predict or parry.
    if Speed < 1 then return end

    -- Dynamic prediction of ball trajectory based on current velocity
    local FutureBallPosition = Ball.Position + Velocity * 0.25 -- Predicting position 0.25s ahead (adjust if needed)
    local PredictedDistance = (currentHRP.Position - FutureBallPosition).Magnitude

    -- Calculate the time to impact with the predicted position
    local TimeToImpact = (Speed > 0) and (PredictedDistance / Speed) or math.huge

    if Ball:GetAttribute("target") == Player.Name and not Parried and TimeToImpact <= (IdealParryTime + DelayOffset) and TimeToImpact >= DelayOffset then
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        Parried = true
        LastParryTime = tick()
    end

    -- Reset parry after cooldown
    if Parried and (tick() - LastParryTime) >= CooldownTime then
        Parried = false
    end
end)


-- Settings Tab Content
local EjectButton = CreateButton("Eject Script", UDim2.new(0, 0, 0, 0), UDim2.new(1, -10, 0, 25), SettingsTab.LeftContent)

EjectButton.MouseButton1Click:Connect(function()
    isEjected = true -- Set flag to prevent saving settings or queueing teleport
    EloHub.Enabled = false
    for key, listener in pairs(keybindListeners) do
       if listener and listener.Disconnect then listener:Disconnect() end
    end
    keybindListeners = {}
    activeKeybinds = {}
    pcall(setclipboard, "") -- Attempt to clear clipboard settings on eject
    EloHub:Destroy()
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

local function ApplyLoadedSettings()
    if _G.EloHubSettings then
        for id, data in pairs(_G.EloHubSettings) do
            if checkboxRegistry[id] and data then
                checkboxRegistry[id].SetValue(data.isChecked)
                if data.keybind then
                    local success, keyCode = pcall(Enum.KeyCode.fromName, data.keybind)
                    if success then checkboxRegistry[id].SetKeybind(keyCode) end
                end
            end
        end
        _G.EloHubSettings = nil -- Clear after applying
    end
end

-- Apply settings after UI is created and checkboxRegistry is populated
ApplyLoadedSettings()

-- Initial Adjustment
task.wait(0.5) -- Wait for UI to fully load before first adjust
AdjustCanvasSize(MainTab.LeftContent)
AdjustCanvasSize(MainTab.RightContent)
AdjustCanvasSize(SettingsTab.LeftContent)

-- Teleport handling: Save settings when teleportation starts
LocalPlayer.OnTeleport:Connect(function(State)
    if State == Enum.TeleportState.Started then
        SaveSettings() -- This will check for isEjected and GameId internally
    end
end)

if not isEjected and queue_on_teleport and typeof(queue_on_teleport) == 'function' then
    local scriptUrl = "https://raw.githubusercontent.com/ElopingDev/EloHub/refs/heads/main/EloHubBladeBall.lua"
    local loadStringCommand = "loadstring(game:HttpGetAsync('" .. scriptUrl .. "'))()"
    queue_on_teleport(loadStringCommand)
    print("EloHub: Queued for reload from URL on next teleport.")
end
