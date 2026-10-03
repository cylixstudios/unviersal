--[[
    Azure Universal Framework
    Comprehensive Client Instrumentation & Visual Overlay System
    Self-contained Luau / Loadstring Ready
]]

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    Workspace = game:GetService("Workspace"),
    CoreGui = game:GetService("CoreGui"),
    HttpService = game:GetService("HttpService")
}

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- Configuration State
local State = {
    Aimbot = {
        Enabled = false,
        Keybind = Enum.UserInputType.MouseButton2,
        TeamCheck = false,
        WallCheck = false,
        UsePrediction = false,
        PredictionValue = 0,
        FOVSize = 200,
        Smoothness = 0.25,
        TargetPart = "Head",
        Active = false
    },
    ESP = {
        Enabled = false,
        Keybind = Enum.KeyCode.Unknown,
        Box = false,
        Name = false,
        Distance = false,
        Skeleton = false,
        HealthText = false,
        HealthBar = false,
        Tracer = false,
        Chams = false,
        TeamCheck = false,
        MaxDistance = 1000,
        Colors = {
            Box = Color3.fromRGB(255, 255, 255),
            Name = Color3.fromRGB(255, 255, 255),
            Distance = Color3.fromRGB(200, 200, 200),
            Skeleton = Color3.fromRGB(255, 255, 255),
            Health = Color3.fromRGB(0, 255, 120),
            Tracer = Color3.fromRGB(255, 255, 255),
            ChamsFill = Color3.fromRGB(60, 130, 246),
            ChamsOutline = Color3.fromRGB(255, 255, 255)
        }
    },
    UI = {
        Visible = true,
        ToggleKey = Enum.KeyCode.RightShift
    }
}

-- Target Bone Definitions
local BonesR15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local BonesR6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

-- FOV Circle Visualizer
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Radius = State.Aimbot.FOVSize
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Transparency = 0.75
FOVCircle.Visible = false

-- Storage for Rendered Entities
local VisualEntities = {}

local function CleanupEntity(player)
    if VisualEntities[player] then
        local data = VisualEntities[player]
        if data.Box then data.Box:Remove() end
        if data.Name then data.Name:Remove() end
        if data.Distance then data.Distance:Remove() end
        if data.HealthText then data.HealthText:Remove() end
        if data.HealthBarOutline then data.HealthBarOutline:Remove() end
        if data.HealthBarFill then data.HealthBarFill:Remove() end
        if data.Tracer then data.Tracer:Remove() end
        if data.Highlight then data.Highlight:Destroy() end
        if data.Skeletons then
            for _, line in ipairs(data.Skeletons) do
                line:Remove()
            end
        end
        VisualEntities[player] = nil
    end
end

local function SetupEntity(player)
    if player == LocalPlayer then return end
    CleanupEntity(player)

    local data = {
        Player = player,
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthText = Drawing.new("Text"),
        HealthBarOutline = Drawing.new("Square"),
        HealthBarFill = Drawing.new("Square"),
        Tracer = Drawing.new("Line"),
        Highlight = Instance.new("Highlight"),
        Skeletons = {}
    }

    -- Box setup
    data.Box.Thickness = 1.2
    data.Box.Filled = false
    data.Box.Color = State.ESP.Colors.Box
    data.Box.Visible = false

    -- Name setup
    data.Name.Size = 13
    data.Name.Center = true
    data.Name.Outline = true
    data.Name.Color = State.ESP.Colors.Name
    data.Name.Visible = false

    -- Distance setup
    data.Distance.Size = 12
    data.Distance.Center = true
    data.Distance.Outline = true
    data.Distance.Color = State.ESP.Colors.Distance
    data.Distance.Visible = false

    -- Health Text setup
    data.HealthText.Size = 12
    data.HealthText.Center = false
    data.HealthText.Outline = true
    data.HealthText.Color = State.ESP.Colors.Health
    data.HealthText.Visible = false

    -- Health Bar Setup
    data.HealthBarOutline.Thickness = 1
    data.HealthBarOutline.Filled = true
    data.HealthBarOutline.Color = Color3.fromRGB(10, 10, 10)
    data.HealthBarOutline.Transparency = 0.5
    data.HealthBarOutline.Visible = false

    data.HealthBarFill.Thickness = 1
    data.HealthBarFill.Filled = true
    data.HealthBarFill.Color = State.ESP.Colors.Health
    data.HealthBarFill.Visible = false

    -- Tracer setup
    data.Tracer.Thickness = 1.2
    data.Tracer.Color = State.ESP.Colors.Tracer
    data.Tracer.Visible = false

    -- Highlight setup
    data.Highlight.FillColor = State.ESP.Colors.ChamsFill
    data.Highlight.OutlineColor = State.ESP.Colors.ChamsOutline
    data.Highlight.FillTransparency = 0.5
    data.Highlight.OutlineTransparency = 0.1
    data.Highlight.Enabled = false

    local targetParent = Services.CoreGui or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    pcall(function() data.Highlight.Parent = targetParent end)

    -- Allocate up to 14 skeleton lines
    for i = 1, 14 do
        local line = Drawing.new("Line")
        line.Thickness = 1.2
        line.Color = State.ESP.Colors.Skeleton
        line.Visible = false
        table.insert(data.Skeletons, line)
    end

    VisualEntities[player] = data
end

-- Raycasting Visibility Check
local function IsVisible(targetPart)
    if not targetPart then return false end
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = {Camera, LocalPlayer.Character}
    if targetPart.Parent then
        table.insert(ignoreList, targetPart.Parent)
    end
    params.FilterDescendantsInstances = ignoreList
    params.IgnoreWater = true

    local result = Services.Workspace:Raycast(origin, direction, params)
    return result == nil
end

-- Team Verification
local function IsTeammate(player)
    if not State.Aimbot.TeamCheck and not State.ESP.TeamCheck then return false end
    if player.Team and LocalPlayer.Team then
        return player.Team == LocalPlayer.Team
    end
    if player.TeamColor and LocalPlayer.TeamColor then
        return player.TeamColor == LocalPlayer.TeamColor
    end
    return false
end

-- Acquire Best Target for Targeting Logic
local function GetClosestTarget()
    local bestTarget = nil
    local shortestDist = State.Aimbot.FOVSize

    local mousePos = Services.UserInputService:GetMouseLocation()
    local screenCenter = Vector2.new(mousePos.X, mousePos.Y)

    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local targetPart = char:FindFirstChild(State.Aimbot.TargetPart) or char:FindFirstChild("HumanoidRootPart")

            if humanoid and humanoid.Health > 0 and targetPart then
                if not (State.Aimbot.TeamCheck and IsTeammate(player)) then
                    if not (State.Aimbot.WallCheck and not IsVisible(targetPart)) then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                            if dist < shortestDist then
                                shortestDist = dist
                                bestTarget = {
                                    Player = player,
                                    Part = targetPart,
                                    Position = targetPart.Position,
                                    Velocity = targetPart.AssemblyLinearVelocity or Vector3.zero
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

-- Targeting Execution Step
local function StepTargeting()
    if not State.Aimbot.Enabled or not State.Aimbot.Active then return end

    local target = GetClosestTarget()
    if target then
        local aimPos = target.Position
        if State.Aimbot.UsePrediction and target.Velocity then
            aimPos = aimPos + (target.Velocity * (State.Aimbot.PredictionValue * 0.015))
        end

        local targetCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
        if State.Aimbot.Smoothness > 0 then
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, math.clamp(1 - State.Aimbot.Smoothness, 0.05, 1))
        else
            Camera.CFrame = targetCFrame
        end
    end
end

-- Visual Projection Step
local function StepVisuals()
    local mousePos = Services.UserInputService:GetMouseLocation()
    FOVCircle.Position = mousePos
    FOVCircle.Radius = State.Aimbot.FOVSize
    FOVCircle.Visible = State.Aimbot.Enabled

    local viewportSize = Camera.ViewportSize

    for player, data in pairs(VisualEntities) do
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")

        local canRender = State.ESP.Enabled and char and humanoid and humanoid.Health > 0 and rootPart
        if canRender and State.ESP.TeamCheck and IsTeammate(player) then
            canRender = false
        end

        local distance = canRender and (rootPart.Position - Camera.CFrame.Position).Magnitude or 999999
        if canRender and distance > State.ESP.MaxDistance then
            canRender = false
        end

        if canRender then
            local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            if onScreen then
                local head = char:FindFirstChild("Head")
                local headPos = head and head.Position or (rootPart.Position + Vector3.new(0, 2, 0))
                local topPos = Camera:WorldToViewportPoint(headPos + Vector3.new(0, 0.6, 0))
                local bottomPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

                local height = math.abs(bottomPos.Y - topPos.Y)
                local width = height * 0.6
                local boxX = rootPos.X - (width / 2)
                local boxY = topPos.Y

                -- 1. 2D Box
                if State.ESP.Box then
                    data.Box.Size = Vector2.new(width, height)
                    data.Box.Position = Vector2.new(boxX, boxY)
                    data.Box.Visible = true
                else
                    data.Box.Visible = false
                end

                -- 2. Name
                if State.ESP.Name then
                    data.Name.Text = player.DisplayName or player.Name
                    data.Name.Position = Vector2.new(rootPos.X, boxY - 16)
                    data.Name.Visible = true
                else
                    data.Name.Visible = false
                end

                -- 3. Distance
                if State.ESP.Distance then
                    data.Distance.Text = math.floor(distance) .. " studs"
                    data.Distance.Position = Vector2.new(rootPos.X, boxY + height + 2)
                    data.Distance.Visible = true
                else
                    data.Distance.Visible = false
                end

                -- 4. Health Bar & Text
                local healthPct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                if State.ESP.HealthBar then
                    local barWidth = 3
                    local barX = boxX - barWidth - 3
                    data.HealthBarOutline.Size = Vector2.new(barWidth, height)
                    data.HealthBarOutline.Position = Vector2.new(barX, boxY)
                    data.HealthBarOutline.Visible = true

                    local fillHeight = height * healthPct
                    data.HealthBarFill.Size = Vector2.new(barWidth - 2, fillHeight)
                    data.HealthBarFill.Position = Vector2.new(barX + 1, boxY + (height - fillHeight))
                    data.HealthBarFill.Color = Color3.fromHSV(healthPct * 0.33, 1, 1)
                    data.HealthBarFill.Visible = true
                else
                    data.HealthBarOutline.Visible = false
                    data.HealthBarFill.Visible = false
                end

                if State.ESP.HealthText then
                    data.HealthText.Text = math.floor(humanoid.Health) .. " HP"
                    data.HealthText.Position = Vector2.new(boxX - 45, boxY)
                    data.HealthText.Visible = true
                else
                    data.HealthText.Visible = false
                end

                -- 5. Tracer
                if State.ESP.Tracer then
                    data.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                    data.Tracer.To = Vector2.new(rootPos.X, boxY + height)
                    data.Tracer.Visible = true
                else
                    data.Tracer.Visible = false
                end

                -- 6. Skeleton Projection
                if State.ESP.Skeleton then
                    local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
                    local bonePairs = isR15 and BonesR15 or BonesR6
                    local lineIdx = 1

                    for _, pair in ipairs(bonePairs) do
                        local partA = char:FindFirstChild(pair[1])
                        local partB = char:FindFirstChild(pair[2])

                        if partA and partB and lineIdx <= #data.Skeletons then
                            local posA, visA = Camera:WorldToViewportPoint(partA.Position)
                            local posB, visB = Camera:WorldToViewportPoint(partB.Position)

                            if visA and visB then
                                local line = data.Skeletons[lineIdx]
                                line.From = Vector2.new(posA.X, posA.Y)
                                line.To = Vector2.new(posB.X, posB.Y)
                                line.Visible = true
                                lineIdx = lineIdx + 1
                            end
                        end
                    end

                    for i = lineIdx, #data.Skeletons do
                        data.Skeletons[i].Visible = false
                    end
                else
                    for _, line in ipairs(data.Skeletons) do
                        line.Visible = false
                    end
                end

                -- 7. Chams (Highlight)
                if State.ESP.Chams then
                    data.Highlight.Adornee = char
                    data.Highlight.Enabled = true
                else
                    data.Highlight.Enabled = false
                end
            else
                -- Offscreen
                data.Box.Visible = false
                data.Name.Visible = false
                data.Distance.Visible = false
                data.HealthText.Visible = false
                data.HealthBarOutline.Visible = false
                data.HealthBarFill.Visible = false
                data.Tracer.Visible = false
                data.Highlight.Enabled = false
                for _, line in ipairs(data.Skeletons) do
                    line.Visible = false
                end
            end
        else
            -- Disabled or Inactive
            data.Box.Visible = false
            data.Name.Visible = false
            data.Distance.Visible = false
            data.HealthText.Visible = false
            data.HealthBarOutline.Visible = false
            data.HealthBarFill.Visible = false
            data.Tracer.Visible = false
            data.Highlight.Enabled = false
            for _, line in ipairs(data.Skeletons) do
                line.Visible = false
            end
        end
    end
end

-- ==============================================================================
-- GUI CONSTRUCTION: Exact Azure Theme Implementation matching image (1).webp
-- ==============================================================================

local function BuildAzureInterface()
    local guiParent = Services.CoreGui or LocalPlayer:FindFirstChildOfClass("PlayerGui")

    local existingGui = guiParent:FindFirstChild("AzureUniversalScreen")
    if existingGui then existingGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AzureUniversalScreen"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Main Container Window
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 680, 0, 480)
    MainFrame.Position = UDim2.new(0.5, -340, 0.5, -240)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(28, 35, 50)
    MainStroke.Thickness = 1
    MainStroke.Parent = MainFrame

    -- Dragging Logic
    local dragging = false
    local dragInput, dragStart, startPos

    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    Services.UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Left Navigation Sidebar
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 160, 1, 0)
    Sidebar.Position = UDim2.new(0, 0, 0, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(11, 14, 20)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame

    local SidebarBorder = Instance.new("Frame")
    SidebarBorder.Size = UDim2.new(0, 1, 1, 0)
    SidebarBorder.Position = UDim2.new(1, -1, 0, 0)
    SidebarBorder.BackgroundColor3 = Color3.fromRGB(28, 35, 50)
    SidebarBorder.BorderSizePixel = 0
    SidebarBorder.Parent = Sidebar

    -- Logo / Brand Header
    local BrandContainer = Instance.new("Frame")
    BrandContainer.Size = UDim2.new(1, 0, 0, 56)
    BrandContainer.BackgroundTransparency = 1
    BrandContainer.Parent = Sidebar

    local BrandIcon = Instance.new("ImageLabel")
    BrandIcon.Size = UDim2.new(0, 18, 0, 18)
    BrandIcon.Position = UDim2.new(0, 18, 0.5, -9)
    BrandIcon.BackgroundTransparency = 1
    BrandIcon.Image = "rbxassetid://6031265976" -- Minimalist viewfinder / reticle icon
    BrandIcon.ImageColor3 = Color3.fromRGB(160, 175, 200)
    BrandIcon.Parent = BrandContainer

    local BrandTitle = Instance.new("TextLabel")
    BrandTitle.Size = UDim2.new(1, -44, 1, 0)
    BrandTitle.Position = UDim2.new(0, 44, 0, 0)
    BrandTitle.BackgroundTransparency = 1
    BrandTitle.Text = "Azure"
    BrandTitle.Font = Enum.Font.GothamMedium
    BrandTitle.TextSize = 15
    BrandTitle.TextColor3 = Color3.fromRGB(215, 225, 245)
    BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
    BrandTitle.Parent = BrandContainer

    -- Sidebar Tab Navigation Button
    local TabButton = Instance.new("Frame")
    TabButton.Size = UDim2.new(1, -20, 0, 40)
    TabButton.Position = UDim2.new(0, 10, 0, 70)
    TabButton.BackgroundColor3 = Color3.fromRGB(19, 24, 34)
    TabButton.BorderSizePixel = 0
    TabButton.Parent = Sidebar

    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 6)
    TabCorner.Parent = TabButton

    local ActiveIndicator = Instance.new("Frame")
    ActiveIndicator.Size = UDim2.new(0, 3, 0, 20)
    ActiveIndicator.Position = UDim2.new(0, 0, 0.5, -10)
    ActiveIndicator.BackgroundColor3 = Color3.fromRGB(70, 140, 255)
    ActiveIndicator.BorderSizePixel = 0
    ActiveIndicator.Parent = TabButton

    local IndCorner = Instance.new("UICorner")
    IndCorner.CornerRadius = UDim.new(0, 2)
    IndCorner.Parent = ActiveIndicator

    local TabIcon = Instance.new("ImageLabel")
    TabIcon.Size = UDim2.new(0, 16, 0, 16)
    TabIcon.Position = UDim2.new(0, 14, 0.5, -8)
    TabIcon.BackgroundTransparency = 1
    TabIcon.Image = "rbxassetid://6031075931"
    TabIcon.ImageColor3 = Color3.fromRGB(220, 230, 250)
    TabIcon.Parent = TabButton

    local TabText = Instance.new("TextLabel")
    TabText.Size = UDim2.new(1, -40, 1, 0)
    TabText.Position = UDim2.new(0, 38, 0, 0)
    TabText.BackgroundTransparency = 1
    TabText.Text = "Aimbot & ESP"
    TabText.Font = Enum.Font.GothamMedium
    TabText.TextSize = 13
    TabText.TextColor3 = Color3.fromRGB(230, 238, 255)
    TabText.TextXAlignment = Enum.TextXAlignment.Left
    TabText.Parent = TabButton

    -- Right Content Area (Two Columns)
    local ContentArea = Instance.new("Frame")
    ContentArea.Size = UDim2.new(1, -160, 1, 0)
    ContentArea.Position = UDim2.new(0, 160, 0, 0)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Parent = MainFrame

    local CardsLayout = Instance.new("UIListLayout")
    CardsLayout.FillDirection = Enum.FillDirection.Horizontal
    CardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    CardsLayout.Padding = UDim.new(0, 14)
    CardsLayout.Parent = ContentArea

    local CardsPadding = Instance.new("UIPadding")
    CardsPadding.PaddingLeft = UDim.new(0, 14)
    CardsPadding.PaddingRight = UDim.new(0, 14)
    CardsPadding.PaddingTop = UDim.new(0, 14)
    CardsPadding.PaddingBottom = UDim.new(0, 14)
    CardsPadding.Parent = ContentArea

    -- Helper Component: Card Generator
    local function CreateCard(title, subtitle, layoutOrder)
        local Card = Instance.new("Frame")
        Card.Name = title .. "Card"
        Card.Size = UDim2.new(0.5, -7, 1, 0)
        Card.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
        Card.BorderSizePixel = 0
        Card.LayoutOrder = layoutOrder
        Card.Parent = ContentArea

        local CardCorner = Instance.new("UICorner")
        CardCorner.CornerRadius = UDim.new(0, 8)
        CardCorner.Parent = Card

        local CardStroke = Instance.new("UIStroke")
        CardStroke.Color = Color3.fromRGB(28, 35, 52)
        CardStroke.Thickness = 1
        CardStroke.Parent = Card

        local Header = Instance.new("Frame")
        Header.Size = UDim2.new(1, 0, 0, 48)
        Header.BackgroundTransparency = 1
        Header.Parent = Card

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Size = UDim2.new(1, -24, 0, 20)
        TitleLabel.Position = UDim2.new(0, 14, 0, 10)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = title
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextSize = 14
        TitleLabel.TextColor3 = Color3.fromRGB(220, 230, 250)
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = Header

        local SubtitleLabel = Instance.new("TextLabel")
        SubtitleLabel.Size = UDim2.new(1, -24, 0, 14)
        SubtitleLabel.Position = UDim2.new(0, 14, 0, 28)
        SubtitleLabel.BackgroundTransparency = 1
        SubtitleLabel.Text = subtitle
        SubtitleLabel.Font = Enum.Font.Gotham
        SubtitleLabel.TextSize = 11
        SubtitleLabel.TextColor3 = Color3.fromRGB(115, 130, 160)
        SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        SubtitleLabel.Parent = Header

        local HeaderDivider = Instance.new("Frame")
        HeaderDivider.Size = UDim2.new(1, -28, 0, 1)
        HeaderDivider.Position = UDim2.new(0, 14, 0, 48)
        HeaderDivider.BackgroundColor3 = Color3.fromRGB(28, 35, 50)
        HeaderDivider.BorderSizePixel = 0
        HeaderDivider.Parent = Card

        local Scroll = Instance.new("ScrollingFrame")
        Scroll.Size = UDim2.new(1, 0, 1, -52)
        Scroll.Position = UDim2.new(0, 0, 0, 52)
        Scroll.BackgroundTransparency = 1
        Scroll.BorderSizePixel = 0
        Scroll.ScrollBarThickness = 3
        Scroll.ScrollBarImageColor3 = Color3.fromRGB(45, 55, 80)
        Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        Scroll.Parent = Card

        local ScrollLayout = Instance.new("UIListLayout")
        ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ScrollLayout.Padding = UDim.new(0, 8)
        ScrollLayout.Parent = Scroll

        local ScrollPadding = Instance.new("UIPadding")
        ScrollPadding.PaddingLeft = UDim.new(0, 14)
        ScrollPadding.PaddingRight = UDim.new(0, 14)
        ScrollPadding.PaddingTop = UDim.new(0, 10)
        ScrollPadding.PaddingBottom = UDim.new(0, 14)
        ScrollPadding.Parent = Scroll

        return Scroll
    end

    -- Helper Component: Master Row with Keybind Button & Master Toggle
    local function CreateMasterRow(parent, defaultKey, onKeybindChanged, defaultActive, onToggleChanged)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 32)
        Row.BackgroundTransparency = 1
        Row.LayoutOrder = 1
        Row.Parent = parent

        -- Keybind button
        local KeyBtn = Instance.new("TextButton")
        KeyBtn.Size = UDim2.new(0, 80, 0, 24)
        KeyBtn.Position = UDim2.new(0, 0, 0.5, -12)
        KeyBtn.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
        KeyBtn.BorderSizePixel = 0
        KeyBtn.Text = ""
        KeyBtn.AutoButtonColor = false
        KeyBtn.Parent = Row

        local KeyCorner = Instance.new("UICorner")
        KeyCorner.CornerRadius = UDim.new(0, 5)
        KeyCorner.Parent = KeyBtn

        local KeyStroke = Instance.new("UIStroke")
        KeyStroke.Color = Color3.fromRGB(38, 48, 70)
        KeyStroke.Thickness = 1
        KeyStroke.Parent = KeyBtn

        local KeyIcon = Instance.new("ImageLabel")
        KeyIcon.Size = UDim2.new(0, 12, 0, 12)
        KeyIcon.Position = UDim2.new(0, 8, 0.5, -6)
        KeyIcon.BackgroundTransparency = 1
        KeyIcon.Image = "rbxassetid://6031265976"
        KeyIcon.ImageColor3 = Color3.fromRGB(150, 165, 195)
        KeyIcon.Parent = KeyBtn

        local KeyText = Instance.new("TextLabel")
        KeyText.Size = UDim2.new(1, -26, 1, 0)
        KeyText.Position = UDim2.new(0, 22, 0, 0)
        KeyText.BackgroundTransparency = 1
        KeyText.Text = typeof(defaultKey) == "EnumItem" and defaultKey.Name or "None"
        KeyText.Font = Enum.Font.GothamMedium
        KeyText.TextSize = 11
        KeyText.TextColor3 = Color3.fromRGB(190, 205, 235)
        KeyText.Parent = KeyBtn

        local listening = false
        KeyBtn.MouseButton1Click:Connect(function()
            listening = true
            KeyText.Text = "..."
        end)

        Services.UserInputService.InputBegan:Connect(function(input)
            if listening then
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                    listening = false
                    KeyText.Text = input.KeyCode.Name
                    onKeybindChanged(input.KeyCode)
                elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                    listening = false
                    KeyText.Text = "Mouse2"
                    onKeybindChanged(Enum.UserInputType.MouseButton2)
                end
            end
        end)

        -- Master Switch
        local Switch = Instance.new("TextButton")
        Switch.Size = UDim2.new(0, 36, 0, 20)
        Switch.Position = UDim2.new(1, -36, 0.5, -10)
        Switch.BackgroundColor3 = defaultActive and Color3.fromRGB(70, 140, 255) or Color3.fromRGB(32, 40, 58)
        Switch.BorderSizePixel = 0
        Switch.Text = ""
        Switch.AutoButtonColor = false
        Switch.Parent = Row

        local SwitchCorner = Instance.new("UICorner")
        SwitchCorner.CornerRadius = UDim.new(1, 0)
        SwitchCorner.Parent = Switch

        local Knob = Instance.new("Frame")
        Knob.Size = UDim2.new(0, 14, 0, 14)
        Knob.Position = defaultActive and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        Knob.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
        Knob.BorderSizePixel = 0
        Knob.Parent = Switch

        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(1, 0)
        KnobCorner.Parent = Knob

        local active = defaultActive
        Switch.MouseButton1Click:Connect(function()
            active = not active
            local targetPos = active and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
            local targetColor = active and Color3.fromRGB(70, 140, 255) or Color3.fromRGB(32, 40, 58)

            Services.TweenService:Create(Knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
            Services.TweenService:Create(Switch, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
            onToggleChanged(active)
        end)
    end

    -- Helper Component: Toggle Row with optional Sub-Menu Button (...)
    local function CreateToggleRow(parent, name, hasSubmenu, defaultActive, onToggleChanged, onSubmenuClicked)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 28)
        Row.BackgroundTransparency = 1
        Row.Parent = parent

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -80, 1, 0)
        Label.Position = UDim2.new(0, 0, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 12
        Label.TextColor3 = Color3.fromRGB(195, 210, 235)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Row

        -- Submenu button (...)
        if hasSubmenu then
            local SubBtn = Instance.new("TextButton")
            SubBtn.Size = UDim2.new(0, 22, 0, 18)
            SubBtn.Position = UDim2.new(1, -62, 0.5, -9)
            SubBtn.BackgroundColor3 = Color3.fromRGB(26, 32, 46)
            SubBtn.BorderSizePixel = 0
            SubBtn.Text = "..."
            SubBtn.Font = Enum.Font.GothamBold
            SubBtn.TextSize = 10
            SubBtn.TextColor3 = Color3.fromRGB(130, 145, 175)
            SubBtn.AutoButtonColor = false
            SubBtn.Parent = Row

            local SubCorner = Instance.new("UICorner")
            SubCorner.CornerRadius = UDim.new(0, 4)
            SubCorner.Parent = SubBtn

            SubBtn.MouseButton1Click:Connect(function()
                if onSubmenuClicked then onSubmenuClicked() end
            end)
        end

        -- Switch toggle
        local Switch = Instance.new("TextButton")
        Switch.Size = UDim2.new(0, 32, 0, 18)
        Switch.Position = UDim2.new(1, -32, 0.5, -9)
        Switch.BackgroundColor3 = defaultActive and Color3.fromRGB(70, 140, 255) or Color3.fromRGB(30, 38, 54)
        Switch.BorderSizePixel = 0
        Switch.Text = ""
        Switch.AutoButtonColor = false
        Switch.Parent = Row

        local SwitchCorner = Instance.new("UICorner")
        SwitchCorner.CornerRadius = UDim.new(1, 0)
        SwitchCorner.Parent = Switch

        local Knob = Instance.new("Frame")
        Knob.Size = UDim2.new(0, 12, 0, 12)
        Knob.Position = defaultActive and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        Knob.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
        Knob.BorderSizePixel = 0
        Knob.Parent = Switch

        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(1, 0)
        KnobCorner.Parent = Knob

        local active = defaultActive
        Switch.MouseButton1Click:Connect(function()
            active = not active
            local targetPos = active and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
            local targetColor = active and Color3.fromRGB(70, 140, 255) or Color3.fromRGB(30, 38, 54)

            Services.TweenService:Create(Knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
            Services.TweenService:Create(Switch, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
            onToggleChanged(active)
        end)
    end

    -- Helper Component: Slider Row
    local function CreateSliderRow(parent, name, minVal, maxVal, defaultVal, onValueChanged)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, 0, 0, 42)
        Container.BackgroundTransparency = 1
        Container.Parent = parent

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, -60, 0, 18)
        Title.Position = UDim2.new(0, 0, 0, 0)
        Title.BackgroundTransparency = 1
        Title.Text = name
        Title.Font = Enum.Font.Gotham
        Title.TextSize = 12
        Title.TextColor3 = Color3.fromRGB(195, 210, 235)
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = Container

        local ValueLabel = Instance.new("TextLabel")
        ValueLabel.Size = UDim2.new(0, 50, 0, 18)
        ValueLabel.Position = UDim2.new(1, -50, 0, 0)
        ValueLabel.BackgroundTransparency = 1
        ValueLabel.Text = tostring(defaultVal)
        ValueLabel.Font = Enum.Font.GothamMedium
        ValueLabel.TextSize = 12
        ValueLabel.TextColor3 = Color3.fromRGB(175, 190, 220)
        ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
        ValueLabel.Parent = Container

        local Track = Instance.new("Frame")
        Track.Size = UDim2.new(1, 0, 0, 4)
        Track.Position = UDim2.new(0, 0, 0, 26)
        Track.BackgroundColor3 = Color3.fromRGB(30, 38, 54)
        Track.BorderSizePixel = 0
        Track.Parent = Container

        local TrackCorner = Instance.new("UICorner")
        TrackCorner.CornerRadius = UDim.new(1, 0)
        TrackCorner.Parent = Track

        local Fill = Instance.new("Frame")
        local initialRatio = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
        Fill.Size = UDim2.new(initialRatio, 0, 1, 0)
        Fill.BackgroundColor3 = Color3.fromRGB(70, 140, 255)
        Fill.BorderSizePixel = 0
        Fill.Parent = Track

        local FillCorner = Instance.new("UICorner")
        FillCorner.CornerRadius = UDim.new(1, 0)
        FillCorner.Parent = Fill

        local Knob = Instance.new("Frame")
        Knob.Size = UDim2.new(0, 10, 0, 10)
        Knob.Position = UDim2.new(1, -5, 0.5, -5)
        Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Knob.BorderSizePixel = 0
        Knob.Parent = Fill

        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(1, 0)
        KnobCorner.Parent = Knob

        local isDragging = false
        local function UpdateValue(inputPos)
            local trackX = Track.AbsolutePosition.X
            local trackWidth = Track.AbsoluteSize.X
            local ratio = math.clamp((inputPos.X - trackX) / trackWidth, 0, 1)
            local value = math.floor(minVal + ((maxVal - minVal) * ratio))

            Fill.Size = UDim2.new(ratio, 0, 1, 0)
            ValueLabel.Text = tostring(value)
            onValueChanged(value)
        end

        Track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDragging = true
                UpdateValue(input.Position)
            end
        end)

        Services.UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDragging = false
            end
        end)

        Services.UserInputService.InputChanged:Connect(function(input)
            if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                UpdateValue(input.Position)
            end
        end)
    end

    -- Populate Column 1: Aimbot Controls
    local AimCard = CreateCard("Aimbot Controls", "Configure aim bot settings", 1)
    CreateMasterRow(AimCard, State.Aimbot.Keybind, function(newKey)
        State.Aimbot.Keybind = newKey
    end, State.Aimbot.Enabled, function(val)
        State.Aimbot.Enabled = val
    end)

    CreateToggleRow(AimCard, "Team Check", true, State.Aimbot.TeamCheck, function(val)
        State.Aimbot.TeamCheck = val
    end)

    CreateToggleRow(AimCard, "Wall Check", true, State.Aimbot.WallCheck, function(val)
        State.Aimbot.WallCheck = val
    end)

    CreateToggleRow(AimCard, "Use Prediction", true, State.Aimbot.UsePrediction, function(val)
        State.Aimbot.UsePrediction = val
    end)

    CreateSliderRow(AimCard, "Prediction Value", 0, 10, State.Aimbot.PredictionValue, function(val)
        State.Aimbot.PredictionValue = val
    end)

    CreateSliderRow(AimCard, "FOV Size", 0, 800, State.Aimbot.FOVSize, function(val)
        State.Aimbot.FOVSize = val
    end)

    -- Populate Column 2: ESP Visuals
    local ESPCard = CreateCard("ESP Visuals", "Configure ESP settings", 2)
    CreateMasterRow(ESPCard, State.ESP.Keybind, function(newKey)
        State.ESP.Keybind = newKey
    end, State.ESP.Enabled, function(val)
        State.ESP.Enabled = val
    end)

    CreateToggleRow(ESPCard, "Box ESP", true, State.ESP.Box, function(val)
        State.ESP.Box = val
    end)

    CreateToggleRow(ESPCard, "Name ESP", true, State.ESP.Name, function(val)
        State.ESP.Name = val
    end)

    CreateToggleRow(ESPCard, "Distance ESP", true, State.ESP.Distance, function(val)
        State.ESP.Distance = val
    end)

    CreateToggleRow(ESPCard, "Skeleton ESP", true, State.ESP.Skeleton, function(val)
        State.ESP.Skeleton = val
    end)

    CreateToggleRow(ESPCard, "Health Text ESP", true, State.ESP.HealthText, function(val)
        State.ESP.HealthText = val
    end)

    CreateToggleRow(ESPCard, "Health Bar ESP", true, State.ESP.HealthBar, function(val)
        State.ESP.HealthBar = val
    end)

    CreateToggleRow(ESPCard, "Tracer ESP", true, State.ESP.Tracer, function(val)
        State.ESP.Tracer = val
    end)

    CreateToggleRow(ESPCard, "Chams", true, State.ESP.Chams, function(val)
        State.ESP.Chams = val
    end)

    CreateToggleRow(ESPCard, "Team Check", true, State.ESP.TeamCheck, function(val)
        State.ESP.TeamCheck = val
    end)

    CreateSliderRow(ESPCard, "ESP Distance", 100, 5000, State.ESP.MaxDistance, function(val)
        State.ESP.MaxDistance = val
    end)

    ScreenGui.Parent = guiParent
    return ScreenGui, MainFrame
end

-- ==============================================================================
-- INITIALIZATION & BINDINGS
-- ==============================================================================

local GuiInstance, MainFrameInstance = BuildAzureInterface()

-- Visibility / Menu Keybind
Services.UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == State.UI.ToggleKey then
        State.UI.Visible = not State.UI.Visible
        MainFrameInstance.Visible = State.UI.Visible
    end

    -- Aimbot Key Activation
    if State.Aimbot.Keybind ~= Enum.KeyCode.Unknown then
        if (typeof(State.Aimbot.Keybind) == "EnumItem" and input.KeyCode == State.Aimbot.Keybind) or
           (input.UserInputType == State.Aimbot.Keybind) then
            State.Aimbot.Active = true
        end
    end
end)

Services.UserInputService.InputEnded:Connect(function(input)
    if State.Aimbot.Keybind ~= Enum.KeyCode.Unknown then
        if (typeof(State.Aimbot.Keybind) == "EnumItem" and input.KeyCode == State.Aimbot.Keybind) or
           (input.UserInputType == State.Aimbot.Keybind) then
            State.Aimbot.Active = false
        end
    end
end)

-- Player Tracker Listeners
for _, player in ipairs(Services.Players:GetPlayers()) do
    SetupEntity(player)
end

Services.Players.PlayerAdded:Connect(function(player)
    SetupEntity(player)
end)

Services.Players.PlayerRemoving:Connect(function(player)
    CleanupEntity(player)
end)

-- Render Stepped Pipeline
Services.RunService.RenderStepped:Connect(function()
    StepTargeting()
    StepVisuals()
end)

print("[Azure Universal] System initialized successfully. Press RightShift to toggle interface.")
