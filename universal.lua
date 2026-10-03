--[[
    Savior Hub - Universal Framework
    Comprehensive Client Instrumentation & Visual Projection System
    Matte Black & Pure White Edition + Dynamic Live Preview + Player Options + Radar + Rainbow
]]

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    Workspace = game:GetService("Workspace"),
    CoreGui = game:GetService("CoreGui"),
    HttpService = game:GetService("HttpService"),
    Stats = game:GetService("Stats")
}

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera


-- Configuration State
local State = {
    Aimbot = {
        Enabled = false,
        Keybind = Enum.UserInputType.MouseButton2,
        AimMode = "Hold", -- "Hold", "Toggle"
        TeamCheck = false,
        WallCheck = false,
        UsePrediction = false,
        PredictionValue = 0,
        FOVSize = 200,
        SmoothnessX = 5,
        SmoothnessY = 5,
        TargetPart = "Head", -- "Head", "Body", "Torso", "HumanoidRootPart", "Closest"
        BodyPriority = false,
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
        ShowSelf = false,
        Rainbow = false,
        Radar = false,
        RadarRange = 250,
        MaxDistance = 1000,
        Colors = {
            Box = Color3.fromRGB(255, 255, 255),
            Name = Color3.fromRGB(255, 255, 255),
            Distance = Color3.fromRGB(200, 200, 200),
            Skeleton = Color3.fromRGB(255, 255, 255),
            Health = Color3.fromRGB(255, 255, 255),
            Tracer = Color3.fromRGB(255, 255, 255),
            ChamsFill = Color3.fromRGB(255, 255, 255),
            ChamsOutline = Color3.fromRGB(80, 80, 80)
        }
    },
    Player = {
        WalkSpeed = 16,
        JumpPower = 50,
        FieldOfView = 70,
        ModifySpeed = false,
        ModifyJump = false,
        ModifyFOV = false,
        OriginalWalkSpeed = 16,
        OriginalJumpPower = 50,
        OriginalFOV = 70
    },
    UI = {
        Visible = true,
        ToggleKey = Enum.KeyCode.RightShift,
        CurrentTab = "Main",
        Watermark = true,
        UnloadBind = Enum.KeyCode.Unknown
    },
    Links = {
        Discord = "https://discord.gg/saviorhub",
        TikTok = "https://www.tiktok.com/@saviorhub"
    }
}

-- Key Matching Utility
local function IsKeyMatch(bind, input)
    if not bind or bind == Enum.KeyCode.Unknown then return false end
    if typeof(bind) == "EnumItem" then
        if bind.EnumType == Enum.KeyCode then
            return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind
        elseif bind.EnumType == Enum.UserInputType then
            return input.UserInputType == bind
        end
    end
    return false
end

-- Clipboard Utility
local function SafeSetClipboard(text)
    local fn = setclipboard or (syn and syn.write_clipboard) or toclipboard
    if fn then
        pcall(fn, text)
        return true
    end
    return false
end

-- Angle Delta Normalizer (-pi to pi)
local function AngleDelta(a, b)
    local diff = (a - b) % (2 * math.pi)
    if diff > math.pi then diff = diff - 2 * math.pi end
    return diff
end

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
FOVCircle.Transparency = 0.85
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

    data.Box.Thickness = 1.2
    data.Box.Filled = false
    data.Box.Color = State.ESP.Colors.Box
    data.Box.Visible = false

    data.Name.Size = 13
    data.Name.Center = true
    data.Name.Outline = true
    data.Name.Color = State.ESP.Colors.Name
    data.Name.Visible = false

    data.Distance.Size = 12
    data.Distance.Center = true
    data.Distance.Outline = true
    data.Distance.Color = State.ESP.Colors.Distance
    data.Distance.Visible = false

    data.HealthText.Size = 12
    data.HealthText.Center = false
    data.HealthText.Outline = true
    data.HealthText.Color = State.ESP.Colors.Health
    data.HealthText.Visible = false

    data.HealthBarOutline.Thickness = 1
    data.HealthBarOutline.Filled = true
    data.HealthBarOutline.Color = Color3.fromRGB(10, 10, 10)
    data.HealthBarOutline.Transparency = 0.5
    data.HealthBarOutline.Visible = false

    data.HealthBarFill.Thickness = 1
    data.HealthBarFill.Filled = true
    data.HealthBarFill.Color = State.ESP.Colors.Health
    data.HealthBarFill.Visible = false

    data.Tracer.Thickness = 1.2
    data.Tracer.Color = State.ESP.Colors.Tracer
    data.Tracer.Visible = false

    data.Highlight.FillColor = State.ESP.Colors.ChamsFill
    data.Highlight.OutlineColor = State.ESP.Colors.ChamsOutline
    data.Highlight.FillTransparency = 0.6
    data.Highlight.OutlineTransparency = 0.2
    data.Highlight.Enabled = false

    local targetParent = Services.CoreGui or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    pcall(function() data.Highlight.Parent = targetParent end)

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
    if player == LocalPlayer then return false end
    if not State.Aimbot.TeamCheck and not State.ESP.TeamCheck then return false end
    if player.Team and LocalPlayer.Team then
        return player.Team == LocalPlayer.Team
    end
    if player.TeamColor and LocalPlayer.TeamColor then
        return player.TeamColor == LocalPlayer.TeamColor
    end
    return false
end

-- Resolve Target Hitbox Part based on Rig and User Selection
local function GetHitboxPart(char, partSetting)
    if not char then return nil end
    partSetting = partSetting or State.Aimbot.TargetPart
    if State.Aimbot.BodyPriority and partSetting == "Head" then
        partSetting = "Body"
    end

    if partSetting == "Head" then
        return char:FindFirstChild("Head")
    elseif partSetting == "Body" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso") or char:FindFirstChild("HumanoidRootPart")
    elseif partSetting == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")
    elseif partSetting == "HumanoidRootPart" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    elseif partSetting == "Closest" then
        local candidates = {
            char:FindFirstChild("Head"),
            char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),
            char:FindFirstChild("LowerTorso"),
            char:FindFirstChild("HumanoidRootPart"),
            char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"),
            char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm")
        }
        local mousePos = Services.UserInputService:GetMouseLocation()
        local bestP = nil
        local bestD = math.huge
        for _, p in ipairs(candidates) do
            if p and p:IsA("BasePart") then
                local sPos, onScr = Camera:WorldToViewportPoint(p.Position)
                if onScr then
                    local d = (Vector2.new(sPos.X, sPos.Y) - mousePos).Magnitude
                    if d < bestD then
                        bestD = d
                        bestP = p
                    end
                end
            end
        end
        return bestP or char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
end

local LockedTarget = nil

-- Target Acquisition with Target Locking & Custom Radius
local function GetClosestTarget(customRadius)
    local maxDist = customRadius or State.Aimbot.FOVSize

    -- Check if locked target is still valid and tracking
    if LockedTarget and LockedTarget.Player and LockedTarget.Player.Parent then
        local char = LockedTarget.Player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local targetPart = char and GetHitboxPart(char, State.Aimbot.TargetPart)

        if humanoid and humanoid.Health > 0 and targetPart then
            local isTeammate = State.Aimbot.TeamCheck and IsTeammate(LockedTarget.Player)
            local isOccluded = State.Aimbot.WallCheck and not IsVisible(targetPart)

            if not isTeammate and not isOccluded then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                local mousePos = Services.UserInputService:GetMouseLocation()
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

                -- Keep lock if target is on screen and within 1.7x FOV tolerance during jumps
                if onScreen and dist <= (maxDist * 1.7) then
                    return {
                        Player = LockedTarget.Player,
                        Part = targetPart,
                        Position = targetPart.Position,
                        Velocity = targetPart.AssemblyLinearVelocity or Vector3.zero
                    }
                end
            end
        end
    end

    if not customRadius then
        LockedTarget = nil
    end
    local bestTarget = nil
    local shortestDist = maxDist
    local mousePos = Services.UserInputService:GetMouseLocation()

    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local targetPart = GetHitboxPart(char, State.Aimbot.TargetPart)

            if humanoid and humanoid.Health > 0 and targetPart then
                if not (State.Aimbot.TeamCheck and IsTeammate(player)) then
                    if not (State.Aimbot.WallCheck and not IsVisible(targetPart)) then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
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

    if not customRadius then
        LockedTarget = bestTarget
    end
    return bestTarget
end

-- Targeting Execution Step (Smooth, jump-proof, orientation interpolation)
local function StepTargeting()
    local shouldAim = State.Aimbot.Enabled and (
        State.Aimbot.Keybind == Enum.KeyCode.Unknown or State.Aimbot.Active
    )
    if not shouldAim then
        LockedTarget = nil
        return
    end

    local target = GetClosestTarget()
    if target and target.Part then
        local aimPos = target.Part.Position

        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myVel = myRoot and myRoot.AssemblyLinearVelocity or Vector3.zero
        local targetVel = target.Velocity or Vector3.zero

        -- Jump-proof velocity compensation with relative motion
        if State.Aimbot.UsePrediction then
            local pred = State.Aimbot.PredictionValue * 0.015
            local relVelX = targetVel.X - (myVel.X * 0.3)
            local relVelY = math.clamp(targetVel.Y - (myVel.Y * 0.3), -25, 25)
            local relVelZ = targetVel.Z - (myVel.Z * 0.3)
            aimPos = aimPos + Vector3.new(
                relVelX * pred,
                relVelY * (pred * 0.5),
                relVelZ * pred
            )
        end

        local currentCF = Camera.CFrame
        local targetCF = CFrame.lookAt(currentCF.Position, aimPos)

        local currentPitch, currentYaw, _ = currentCF:ToOrientation()
        local targetPitch, targetYaw, _ = targetCF:ToOrientation()

        local deltaYaw = AngleDelta(targetYaw, currentYaw)
        local deltaPitch = targetPitch - currentPitch

        -- Detect jump/airborne state from either local player or target
        local isJumping = (math.abs(myVel.Y) > 3) or (math.abs(targetVel.Y) > 3)

        local smoothX = math.max(State.Aimbot.SmoothnessX, 1)
        local smoothY = math.max(State.Aimbot.SmoothnessY, 1)

        local factorX = math.clamp(1 / smoothX, 0.04, 1)
        -- In airborne/jump states, elevate vertical responsiveness so camera tracks smoothly without lag or overshooting
        local factorY = isJumping and math.clamp((1 / smoothY) * 2.4, 0.12, 1) or math.clamp(1 / smoothY, 0.04, 1)

        local newYaw = currentYaw + (deltaYaw * factorX)
        local newPitch = math.clamp(currentPitch + (deltaPitch * factorY), math.rad(-88), math.rad(88))

        Camera.CFrame = CFrame.new(currentCF.Position) * CFrame.fromOrientation(newPitch, newYaw, 0)
    end
end

-- Radar Blip Storage
local RadarBlips = {}
local RadarFrameInstance = nil

-- Visual Projection Step
local function StepVisuals()
    local mousePos = Services.UserInputService:GetMouseLocation()
    FOVCircle.Position = mousePos
    FOVCircle.Radius = State.Aimbot.FOVSize
    FOVCircle.Visible = State.Aimbot.Enabled

    local viewportSize = Camera.ViewportSize
    local rainbowColor = State.ESP.Rainbow and Color3.fromHSV((tick() * 0.4) % 1, 1, 1) or Color3.fromRGB(255, 255, 255)

    if RadarFrameInstance then
        RadarFrameInstance.Visible = State.ESP.Enabled and State.ESP.Radar
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for player, data in pairs(VisualEntities) do
        local isSelf = (player == LocalPlayer)
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")

        local canRender = State.ESP.Enabled and char and humanoid and humanoid.Health > 0 and rootPart
        if isSelf and not State.ESP.ShowSelf then
            canRender = false
        end
        if canRender and not isSelf and State.ESP.TeamCheck and IsTeammate(player) then
            canRender = false
        end

        local distance = canRender and (rootPart.Position - Camera.CFrame.Position).Magnitude or 999999
        if canRender and distance > State.ESP.MaxDistance then
            canRender = false
        end

        -- Radar Blip Rendering
        if State.ESP.Enabled and State.ESP.Radar and not isSelf and char and rootPart and myRoot and RadarFrameInstance then
            local blip = RadarBlips[player]
            if not blip then
                blip = Instance.new("Frame")
                blip.Size = UDim2.new(0, 6, 0, 6)
                blip.BackgroundColor3 = rainbowColor
                blip.BorderSizePixel = 0
                local bCorner = Instance.new("UICorner")
                bCorner.CornerRadius = UDim.new(1, 0)
                bCorner.Parent = blip
                blip.Parent = RadarFrameInstance
                RadarBlips[player] = blip
            end

            local relPos = rootPart.Position - myRoot.Position
            local camYaw = math.atan2(-Camera.CFrame.LookVector.X, -Camera.CFrame.LookVector.Z)
            local cosY, sinY = math.cos(camYaw), math.sin(camYaw)
            local rx = relPos.X * cosY - relPos.Z * sinY
            local ry = relPos.X * sinY + relPos.Z * cosY

            local radarRadius = 68
            local maxRange = State.ESP.RadarRange
            local dist2D = math.sqrt(rx^2 + ry^2)

            if dist2D <= maxRange and humanoid.Health > 0 then
                local ratio = dist2D / maxRange
                local nx = (rx / (dist2D > 0 and dist2D or 1)) * ratio * radarRadius
                local ny = (ry / (dist2D > 0 and dist2D or 1)) * ratio * radarRadius
                blip.Position = UDim2.new(0.5, nx - 3, 0.5, ny - 3)
                blip.BackgroundColor3 = rainbowColor
                blip.Visible = true
            else
                blip.Visible = false
            end
        else
            if RadarBlips[player] then
                RadarBlips[player].Visible = false
            end
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

                local currentColor = State.ESP.Rainbow and rainbowColor or Color3.fromRGB(255, 255, 255)

                -- 1. 2D Box
                if State.ESP.Box then
                    data.Box.Size = Vector2.new(width, height)
                    data.Box.Position = Vector2.new(boxX, boxY)
                    data.Box.Color = currentColor
                    data.Box.Visible = true
                else
                    data.Box.Visible = false
                end

                -- 2. Name
                if State.ESP.Name then
                    data.Name.Text = (isSelf and "[You] " or "") .. (player.DisplayName or player.Name)
                    data.Name.Position = Vector2.new(rootPos.X, boxY - 16)
                    data.Name.Color = currentColor
                    data.Name.Visible = true
                else
                    data.Name.Visible = false
                end

                -- 3. Distance
                if State.ESP.Distance then
                    data.Distance.Text = math.floor(distance) .. " studs"
                    data.Distance.Position = Vector2.new(rootPos.X, boxY + height + 2)
                    data.Distance.Color = State.ESP.Rainbow and rainbowColor or State.ESP.Colors.Distance
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
                    data.HealthBarFill.Color = State.ESP.Rainbow and rainbowColor or Color3.fromRGB(255, 255, 255)
                    data.HealthBarFill.Visible = true
                else
                    data.HealthBarOutline.Visible = false
                    data.HealthBarFill.Visible = false
                end

                if State.ESP.HealthText then
                    data.HealthText.Text = math.floor(humanoid.Health) .. " HP"
                    data.HealthText.Position = Vector2.new(boxX - 45, boxY)
                    data.HealthText.Color = currentColor
                    data.HealthText.Visible = true
                else
                    data.HealthText.Visible = false
                end

                -- 5. Tracer
                if State.ESP.Tracer then
                    data.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                    data.Tracer.To = Vector2.new(rootPos.X, boxY + height)
                    data.Tracer.Color = currentColor
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
                                line.Color = currentColor
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
                    data.Highlight.FillColor = currentColor
                    data.Highlight.OutlineColor = State.ESP.Rainbow and rainbowColor or State.ESP.Colors.ChamsOutline
                    data.Highlight.Enabled = true
                else
                    data.Highlight.Enabled = false
                end
            else
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

-- Resolve Savior Hub Logo Asset (Safe File / Remote / Built-in Asset Fallback)
local function GetHubLogoAsset()
    local defaultIcon = "rbxassetid://6031075931"
    local assetFn = getcustomasset or (syn and syn.get_custom_asset) or getsynasset
    local isFileFn = isfile or (syn and syn.is_file)
    local writeFn = writefile or (syn and syn.write_file)

    -- 1. Check local file on disk
    if assetFn and isFileFn then
        pcall(function()
            if isFileFn("logo.png") then
                local uri = assetFn("logo.png")
                if uri and typeof(uri) == "string" and #uri > 0 then
                    defaultIcon = uri
                end
            elseif isFileFn("savior_hub_logo.png") then
                local uri = assetFn("savior_hub_logo.png")
                if uri and typeof(uri) == "string" and #uri > 0 then
                    defaultIcon = uri
                end
            end
        end)
    end

    -- 2. Safe remote download if local file is missing
    if defaultIcon == "rbxassetid://6031075931" and assetFn and writeFn and game and game.HttpGet then
        pcall(function()
            local raw = game:HttpGet("https://raw.githubusercontent.com/cylixstudios/unviersal/main/logo.png", true)
            if raw and #raw > 1000 then
                writeFn("logo.png", raw)
                local uri = assetFn("logo.png")
                if uri and typeof(uri) == "string" and #uri > 0 then
                    defaultIcon = uri
                end
            end
        end)
    end

    return defaultIcon
end

-- ==============================================================================
-- GUI CONSTRUCTION: Savior Hub
-- ==============================================================================

local ActiveConnections = {}

local function BuildSaviorInterface()
    local guiParent = Services.CoreGui or LocalPlayer:FindFirstChildOfClass("PlayerGui")

    local existingGui = guiParent:FindFirstChild("SaviorHubScreen")
    if existingGui then existingGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SaviorHubScreen"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Radar Minimap
    local RadarFrame = Instance.new("Frame")
    RadarFrame.Name = "RadarFrame"
    RadarFrame.Size = UDim2.new(0, 150, 0, 150)
    RadarFrame.Position = UDim2.new(0, 24, 0, 24)
    RadarFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    RadarFrame.BorderSizePixel = 0
    RadarFrame.Visible = State.ESP.Enabled and State.ESP.Radar
    RadarFrame.Parent = ScreenGui
    RadarFrameInstance = RadarFrame

    local RCorner = Instance.new("UICorner")
    RCorner.CornerRadius = UDim.new(1, 0)
    RCorner.Parent = RadarFrame

    local RStroke = Instance.new("UIStroke")
    RStroke.Color = Color3.fromRGB(32, 32, 32)
    RStroke.Thickness = 1.2
    RStroke.Parent = RadarFrame

    local RLineH = Instance.new("Frame")
    RLineH.Size = UDim2.new(1, 0, 0, 1)
    RLineH.Position = UDim2.new(0, 0, 0.5, 0)
    RLineH.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    RLineH.BorderSizePixel = 0
    RLineH.Parent = RadarFrame

    local RLineV = Instance.new("Frame")
    RLineV.Size = UDim2.new(0, 1, 1, 0)
    RLineV.Position = UDim2.new(0.5, 0, 0, 0)
    RLineV.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    RLineV.BorderSizePixel = 0
    RLineV.Parent = RadarFrame

    local RCenterDot = Instance.new("Frame")
    RCenterDot.Size = UDim2.new(0, 6, 0, 6)
    RCenterDot.Position = UDim2.new(0.5, -3, 0.5, -3)
    RCenterDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    RCenterDot.BorderSizePixel = 0
    RCenterDot.ZIndex = 5
    RCenterDot.Parent = RadarFrame

    local RCenterCorner = Instance.new("UICorner")
    RCenterCorner.CornerRadius = UDim.new(1, 0)
    RCenterCorner.Parent = RCenterDot

    local rDragging = false
    local rDragStart, rStartPos
    RadarFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            rDragging = true
            rDragStart = input.Position
            rStartPos = RadarFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    rDragging = false
                end
            end)
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if rDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - rDragStart
            RadarFrame.Position = UDim2.new(
                rStartPos.X.Scale,
                rStartPos.X.Offset + delta.X,
                rStartPos.Y.Scale,
                rStartPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Top-Right Watermark Badge
    local WatermarkBadge = Instance.new("Frame")
    WatermarkBadge.Name = "WatermarkBadge"
    WatermarkBadge.Size = UDim2.new(0, 240, 0, 30)
    WatermarkBadge.Position = UDim2.new(1, -255, 0, 16)
    WatermarkBadge.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    WatermarkBadge.BorderSizePixel = 0
    WatermarkBadge.Visible = State.UI.Watermark
    WatermarkBadge.Parent = ScreenGui

    local WCorner = Instance.new("UICorner")
    WCorner.CornerRadius = UDim.new(1, 0)
    WCorner.Parent = WatermarkBadge

    local WStroke = Instance.new("UIStroke")
    WStroke.Color = Color3.fromRGB(32, 32, 32)
    WStroke.Thickness = 1.2
    WStroke.Parent = WatermarkBadge

    local WatermarkLabel = Instance.new("TextLabel")
    WatermarkLabel.Size = UDim2.new(1, 0, 1, 0)
    WatermarkLabel.BackgroundTransparency = 1
    WatermarkLabel.Text = "Savior Hub  |  FPS: 60  |  Ping: 0ms"
    WatermarkLabel.Font = Enum.Font.GothamMedium
    WatermarkLabel.TextSize = 11
    WatermarkLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    WatermarkLabel.Parent = WatermarkBadge

    local frameCount = 0
    local lastFpsUpdate = tick()
    local currentFps = 60

    local WatermarkConn = Services.RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        if now - lastFpsUpdate >= 0.5 then
            currentFps = math.floor(frameCount / (now - lastFpsUpdate))
            frameCount = 0
            lastFpsUpdate = now

            local pingVal = 0
            pcall(function()
                pingVal = math.floor(LocalPlayer:GetNetworkPing() * 1000)
            end)
            if pingVal == 0 then
                pcall(function()
                    pingVal = math.floor(Services.Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                end)
            end

            if WatermarkBadge.Visible then
                WatermarkLabel.Text = string.format("Savior Hub  |  FPS: %d  |  Ping: %dms", currentFps, pingVal)
            end
        end
    end)
    table.insert(ActiveConnections, WatermarkConn)

    -- Main Container Window
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 720, 0, 500)
    MainFrame.Position = UDim2.new(0.5, -360, 0.5, -250)
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = false
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 18)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(30, 30, 30)
    MainStroke.Thickness = 1.2
    MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    MainStroke.Parent = MainFrame

    local InnerBackground = Instance.new("Frame")
    InnerBackground.Size = UDim2.new(1, 0, 1, 0)
    InnerBackground.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    InnerBackground.BorderSizePixel = 0
    InnerBackground.ClipsDescendants = true
    InnerBackground.Parent = MainFrame

    local InnerCorner = Instance.new("UICorner")
    InnerCorner.CornerRadius = UDim.new(0, 18)
    InnerCorner.Parent = InnerBackground

    -- Dragging Logic
    local dragging = false
    local dragInput, dragStart, startPos

    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
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
    Sidebar.Size = UDim2.new(0, 175, 1, 0)
    Sidebar.Position = UDim2.new(0, 0, 0, 0)
    Sidebar.BackgroundTransparency = 1
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = InnerBackground

    local SidebarDivider = Instance.new("Frame")
    SidebarDivider.Size = UDim2.new(0, 1, 1, -28)
    SidebarDivider.Position = UDim2.new(1, -1, 0, 14)
    SidebarDivider.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    SidebarDivider.BorderSizePixel = 0
    SidebarDivider.Parent = Sidebar

    local BrandContainer = Instance.new("Frame")
    BrandContainer.Size = UDim2.new(1, 0, 0, 60)
    BrandContainer.BackgroundTransparency = 1
    BrandContainer.Parent = Sidebar

    local BrandIcon = Instance.new("ImageLabel")
    BrandIcon.Size = UDim2.new(0, 20, 0, 20)
    BrandIcon.Position = UDim2.new(0, 18, 0.5, -10)
    BrandIcon.BackgroundTransparency = 1
    BrandIcon.Image = GetHubLogoAsset()
    BrandIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    BrandIcon.Parent = BrandContainer

    local BrandTitle = Instance.new("TextLabel")
    BrandTitle.Size = UDim2.new(1, -48, 1, 0)
    BrandTitle.Position = UDim2.new(0, 46, 0, 0)
    BrandTitle.BackgroundTransparency = 1
    BrandTitle.Text = "Savior Hub"
    BrandTitle.Font = Enum.Font.GothamBold
    BrandTitle.TextSize = 15
    BrandTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
    BrandTitle.Parent = BrandContainer

    -- Navigation Tabs
    local NavContainer = Instance.new("Frame")
    NavContainer.Size = UDim2.new(1, 0, 0, 160)
    NavContainer.Position = UDim2.new(0, 0, 0, 65)
    NavContainer.BackgroundTransparency = 1
    NavContainer.Parent = Sidebar

    local NavLayout = Instance.new("UIListLayout")
    NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NavLayout.Padding = UDim.new(0, 6)
    NavLayout.Parent = NavContainer

    local NavPadding = Instance.new("UIPadding")
    NavPadding.PaddingLeft = UDim.new(0, 12)
    NavPadding.PaddingRight = UDim.new(0, 12)
    NavPadding.Parent = NavContainer

    local TabButtons = {}
    local function CreateNavTab(name, iconId, tabKey, layoutOrder)
        local TabBtn = Instance.new("TextButton")
        TabBtn.Name = tabKey .. "Nav"
        TabBtn.Size = UDim2.new(1, 0, 0, 36)
        TabBtn.BackgroundColor3 = (State.UI.CurrentTab == tabKey) and Color3.fromRGB(18, 18, 18) or Color3.fromRGB(12, 12, 12)
        TabBtn.BorderSizePixel = 0
        TabBtn.Text = ""
        TabBtn.AutoButtonColor = false
        TabBtn.LayoutOrder = layoutOrder
        TabBtn.Parent = NavContainer

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 10)
        Corner.Parent = TabBtn

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = (State.UI.CurrentTab == tabKey) and Color3.fromRGB(36, 36, 36) or Color3.fromRGB(18, 18, 18)
        Stroke.Thickness = 1
        Stroke.Parent = TabBtn

        local Ind = Instance.new("Frame")
        Ind.Size = UDim2.new(0, 3, 0, 18)
        Ind.Position = UDim2.new(0, 2, 0.5, -9)
        Ind.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Ind.BorderSizePixel = 0
        Ind.Visible = (State.UI.CurrentTab == tabKey)
        Ind.Parent = TabBtn

        local IndCorner = Instance.new("UICorner")
        IndCorner.CornerRadius = UDim.new(1, 0)
        IndCorner.Parent = Ind

        local Icon = Instance.new("ImageLabel")
        Icon.Size = UDim2.new(0, 16, 0, 16)
        Icon.Position = UDim2.new(0, 12, 0.5, -8)
        Icon.BackgroundTransparency = 1
        Icon.Image = iconId
        Icon.ImageColor3 = (State.UI.CurrentTab == tabKey) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
        Icon.Parent = TabBtn

        local Txt = Instance.new("TextLabel")
        Txt.Size = UDim2.new(1, -38, 1, 0)
        Txt.Position = UDim2.new(0, 36, 0, 0)
        Txt.BackgroundTransparency = 1
        Txt.Text = name
        Txt.Font = Enum.Font.GothamMedium
        Txt.TextSize = 12
        Txt.TextColor3 = (State.UI.CurrentTab == tabKey) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
        Txt.TextXAlignment = Enum.TextXAlignment.Left
        Txt.Parent = TabBtn

        TabButtons[tabKey] = {
            Button = TabBtn,
            Indicator = Ind,
            Icon = Icon,
            Text = Txt,
            Stroke = Stroke
        }

        TabBtn.MouseEnter:Connect(function()
            if State.UI.CurrentTab ~= tabKey then
                Services.TweenService:Create(TabBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(16, 16, 16)}):Play()
            end
        end)
        TabBtn.MouseLeave:Connect(function()
            if State.UI.CurrentTab ~= tabKey then
                Services.TweenService:Create(TabBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(12, 12, 12)}):Play()
            end
        end)

        return TabBtn
    end

    local NavMain = CreateNavTab("Aimbot & ESP", "rbxassetid://6031265976", "Main", 1)
    local NavPlayer = CreateNavTab("Player Options", "rbxassetid://6031075931", "Player", 2)
    local NavSettings = CreateNavTab("Settings", "rbxassetid://6031280882", "Settings", 3)

    -- Bottom Left Profile Box
    local ProfileBox = Instance.new("Frame")
    ProfileBox.Name = "ProfileBox"
    ProfileBox.Size = UDim2.new(1, -24, 0, 56)
    ProfileBox.Position = UDim2.new(0, 12, 1, -68)
    ProfileBox.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    ProfileBox.BorderSizePixel = 0
    ProfileBox.Parent = Sidebar

    local ProfileCorner = Instance.new("UICorner")
    ProfileCorner.CornerRadius = UDim.new(0, 14)
    ProfileCorner.Parent = ProfileBox

    local ProfileStroke = Instance.new("UIStroke")
    ProfileStroke.Color = Color3.fromRGB(24, 24, 24)
    ProfileStroke.Thickness = 1
    ProfileStroke.Parent = ProfileBox

    local AvatarImage = Instance.new("ImageLabel")
    AvatarImage.Name = "AvatarImage"
    AvatarImage.Size = UDim2.new(0, 36, 0, 36)
    AvatarImage.Position = UDim2.new(0, 10, 0.5, -18)
    AvatarImage.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    AvatarImage.BorderSizePixel = 0
    AvatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    AvatarImage.Parent = ProfileBox

    local AvatarCorner = Instance.new("UICorner")
    AvatarCorner.CornerRadius = UDim.new(1, 0)
    AvatarCorner.Parent = AvatarImage

    local AvatarStroke = Instance.new("UIStroke")
    AvatarStroke.Color = Color3.fromRGB(36, 36, 36)
    AvatarStroke.Thickness = 1
    AvatarStroke.Parent = AvatarImage

    task.spawn(function()
        local thumb, isReady = Services.Players:GetUserThumbnailAsync(
            LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size48x48
        )
        if thumb and thumb ~= "" then
            AvatarImage.Image = thumb
        end
    end)

    local PlayerNameLabel = Instance.new("TextLabel")
    PlayerNameLabel.Size = UDim2.new(1, -56, 0, 18)
    PlayerNameLabel.Position = UDim2.new(0, 54, 0, 10)
    PlayerNameLabel.BackgroundTransparency = 1
    PlayerNameLabel.Text = LocalPlayer.DisplayName or LocalPlayer.Name
    PlayerNameLabel.Font = Enum.Font.GothamBold
    PlayerNameLabel.TextSize = 12
    PlayerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    PlayerNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    PlayerNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    PlayerNameLabel.Parent = ProfileBox

    local KeyBadgeLabel = Instance.new("TextLabel")
    KeyBadgeLabel.Size = UDim2.new(1, -56, 0, 16)
    KeyBadgeLabel.Position = UDim2.new(0, 54, 0, 28)
    KeyBadgeLabel.BackgroundTransparency = 1
    KeyBadgeLabel.Text = "key : Free"
    KeyBadgeLabel.Font = Enum.Font.GothamMedium
    KeyBadgeLabel.TextSize = 11
    KeyBadgeLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    KeyBadgeLabel.TextXAlignment = Enum.TextXAlignment.Left
    KeyBadgeLabel.Parent = ProfileBox

    -- Right Content Master Area
    local ContentMaster = Instance.new("Frame")
    ContentMaster.Name = "ContentMaster"
    ContentMaster.Size = UDim2.new(1, -175, 1, 0)
    ContentMaster.Position = UDim2.new(0, 175, 0, 0)
    ContentMaster.BackgroundTransparency = 1
    ContentMaster.Parent = InnerBackground

    local function MakePageView(name, visible)
        local pv = Instance.new("Frame")
        pv.Name = name
        pv.Size = UDim2.new(1, 0, 1, 0)
        pv.BackgroundTransparency = 1
        pv.Visible = visible
        pv.Parent = ContentMaster

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 14)
        layout.Parent = pv

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 14)
        pad.PaddingRight = UDim.new(0, 14)
        pad.PaddingTop = UDim.new(0, 14)
        pad.PaddingBottom = UDim.new(0, 14)
        pad.Parent = pv
        return pv
    end

    local MainPageView = MakePageView("MainPageView", State.UI.CurrentTab == "Main")
    local PlayerPageView = MakePageView("PlayerPageView", State.UI.CurrentTab == "Player")
    local SettingsPageView = MakePageView("SettingsPageView", State.UI.CurrentTab == "Settings")

    -- Toast Notification Label
    local ToastLabel = Instance.new("TextLabel")
    ToastLabel.Size = UDim2.new(0, 300, 0, 34)
    ToastLabel.Position = UDim2.new(0.5, -150, 0, -45)
    ToastLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    ToastLabel.BorderSizePixel = 0
    ToastLabel.Text = ""
    ToastLabel.Font = Enum.Font.GothamMedium
    ToastLabel.TextSize = 12
    ToastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToastLabel.ZIndex = 25
    ToastLabel.Parent = MainFrame

    local ToastCorner = Instance.new("UICorner")
    ToastCorner.CornerRadius = UDim.new(0, 10)
    ToastCorner.Parent = ToastLabel

    local ToastStroke = Instance.new("UIStroke")
    ToastStroke.Color = Color3.fromRGB(45, 45, 45)
    ToastStroke.Thickness = 1
    ToastStroke.Parent = ToastLabel

    local function ShowToast(msg)
        ToastLabel.Text = msg
        Services.TweenService:Create(ToastLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -150, 0, 15)
        }):Play()
        task.delay(2.4, function()
            Services.TweenService:Create(ToastLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -150, 0, -45)
            }):Play()
        end)
    end

    local function SwitchTab(newTabKey)
        State.UI.CurrentTab = newTabKey
        for key, tabData in pairs(TabButtons) do
            local isSelected = (key == newTabKey)
            tabData.Indicator.Visible = isSelected
            tabData.Button.BackgroundColor3 = isSelected and Color3.fromRGB(18, 18, 18) or Color3.fromRGB(12, 12, 12)
            tabData.Stroke.Color = isSelected and Color3.fromRGB(36, 36, 36) or Color3.fromRGB(18, 18, 18)
            tabData.Icon.ImageColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
            tabData.Text.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
        end
        MainPageView.Visible = (newTabKey == "Main")
        PlayerPageView.Visible = (newTabKey == "Player")
        SettingsPageView.Visible = (newTabKey == "Settings")
    end

    NavMain.MouseButton1Click:Connect(function() SwitchTab("Main") end)
    NavPlayer.MouseButton1Click:Connect(function() SwitchTab("Player") end)
    NavSettings.MouseButton1Click:Connect(function() SwitchTab("Settings") end)

    -- Helper Component: Card Generator
    local function CreateCard(parentView, title, subtitle, layoutOrder)
        local Card = Instance.new("Frame")
        Card.Name = title .. "Card"
        Card.Size = UDim2.new(0.5, -7, 1, 0)
        Card.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
        Card.BorderSizePixel = 0
        Card.LayoutOrder = layoutOrder
        Card.Parent = parentView

        local CardCorner = Instance.new("UICorner")
        CardCorner.CornerRadius = UDim.new(0, 14)
        CardCorner.Parent = Card

        local CardStroke = Instance.new("UIStroke")
        CardStroke.Color = Color3.fromRGB(26, 26, 26)
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
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = Header

        local SubtitleLabel = Instance.new("TextLabel")
        SubtitleLabel.Size = UDim2.new(1, -24, 0, 14)
        SubtitleLabel.Position = UDim2.new(0, 14, 0, 28)
        SubtitleLabel.BackgroundTransparency = 1
        SubtitleLabel.Text = subtitle
        SubtitleLabel.Font = Enum.Font.Gotham
        SubtitleLabel.TextSize = 11
        SubtitleLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
        SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        SubtitleLabel.Parent = Header

        local HeaderDivider = Instance.new("Frame")
        HeaderDivider.Size = UDim2.new(1, -28, 0, 1)
        HeaderDivider.Position = UDim2.new(0, 14, 0, 48)
        HeaderDivider.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
        HeaderDivider.BorderSizePixel = 0
        HeaderDivider.Parent = Card

        local Scroll = Instance.new("ScrollingFrame")
        Scroll.Size = UDim2.new(1, 0, 1, -52)
        Scroll.Position = UDim2.new(0, 0, 0, 52)
        Scroll.BackgroundTransparency = 1
        Scroll.BorderSizePixel = 0
        Scroll.ScrollBarThickness = 3
        Scroll.ScrollBarImageColor3 = Color3.fromRGB(40, 40, 40)
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

    -- Helper: Keybind & Master Switch Row
    local function CreateMasterRow(parent, defaultKey, onKeybindChanged, defaultActive, onToggleChanged, layoutOrder)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 32)
        Row.BackgroundTransparency = 1
        Row.LayoutOrder = layoutOrder or 1
        Row.Parent = parent

        local KeyBtn = Instance.new("TextButton")
        KeyBtn.Size = UDim2.new(0, 84, 0, 24)
        KeyBtn.Position = UDim2.new(0, 0, 0.5, -12)
        KeyBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        KeyBtn.BorderSizePixel = 0
        KeyBtn.Text = ""
        KeyBtn.AutoButtonColor = false
        KeyBtn.Parent = Row

        local KeyCorner = Instance.new("UICorner")
        KeyCorner.CornerRadius = UDim.new(0, 8)
        KeyCorner.Parent = KeyBtn

        local KeyStroke = Instance.new("UIStroke")
        KeyStroke.Color = Color3.fromRGB(34, 34, 34)
        KeyStroke.Thickness = 1
        KeyStroke.Parent = KeyBtn

        local KeyIcon = Instance.new("ImageLabel")
        KeyIcon.Size = UDim2.new(0, 12, 0, 12)
        KeyIcon.Position = UDim2.new(0, 8, 0.5, -6)
        KeyIcon.BackgroundTransparency = 1
        KeyIcon.Image = "rbxassetid://6031265976"
        KeyIcon.ImageColor3 = Color3.fromRGB(200, 200, 200)
        KeyIcon.Parent = KeyBtn

        local function FormatKeyText(key)
            if not key or key == Enum.KeyCode.Unknown then return "None" end
            if key == Enum.UserInputType.MouseButton1 then return "Mouse1" end
            if key == Enum.UserInputType.MouseButton2 then return "Mouse2" end
            if key == Enum.UserInputType.MouseButton3 then return "Mouse3" end
            return key.Name
        end

        local KeyText = Instance.new("TextLabel")
        KeyText.Size = UDim2.new(1, -26, 1, 0)
        KeyText.Position = UDim2.new(0, 22, 0, 0)
        KeyText.BackgroundTransparency = 1
        KeyText.Text = FormatKeyText(defaultKey)
        KeyText.Font = Enum.Font.GothamMedium
        KeyText.TextSize = 11
        KeyText.TextColor3 = Color3.fromRGB(240, 240, 240)
        KeyText.Parent = KeyBtn

        local listening = false
        KeyBtn.MouseButton1Click:Connect(function()
            listening = true
            KeyText.Text = "..."
            KeyStroke.Color = Color3.fromRGB(255, 255, 255)
        end)

        Services.UserInputService.InputBegan:Connect(function(input)
            if listening then
                local chosen = nil
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
                        chosen = Enum.KeyCode.Unknown
                    else
                        chosen = input.KeyCode
                    end
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                    chosen = Enum.UserInputType.MouseButton1
                elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                    chosen = Enum.UserInputType.MouseButton2
                elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                    chosen = Enum.UserInputType.MouseButton3
                end

                if chosen then
                    listening = false
                    KeyStroke.Color = Color3.fromRGB(34, 34, 34)
                    KeyText.Text = FormatKeyText(chosen)
                    onKeybindChanged(chosen)
                end
            end
        end)

        local Switch = Instance.new("TextButton")
        Switch.Size = UDim2.new(0, 36, 0, 20)
        Switch.Position = UDim2.new(1, -36, 0.5, -10)
        Switch.BackgroundColor3 = defaultActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(24, 24, 24)
        Switch.BorderSizePixel = 0
        Switch.Text = ""
        Switch.AutoButtonColor = false
        Switch.Parent = Row

        local SwitchCorner = Instance.new("UICorner")
        SwitchCorner.CornerRadius = UDim.new(1, 0)
        SwitchCorner.Parent = Switch

        local SwitchStroke = Instance.new("UIStroke")
        SwitchStroke.Color = Color3.fromRGB(36, 36, 36)
        SwitchStroke.Thickness = 1
        SwitchStroke.Parent = Switch

        local Knob = Instance.new("Frame")
        Knob.Size = UDim2.new(0, 14, 0, 14)
        Knob.Position = defaultActive and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        Knob.BackgroundColor3 = defaultActive and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(200, 200, 200)
        Knob.BorderSizePixel = 0
        Knob.Parent = Switch

        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(1, 0)
        KnobCorner.Parent = Knob

        local active = defaultActive
        Switch.MouseButton1Click:Connect(function()
            active = not active
            local targetPos = active and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
            local targetColor = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(24, 24, 24)
            local knobColor = active and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(200, 200, 200)

            Services.TweenService:Create(Knob, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = targetPos,
                BackgroundColor3 = knobColor
            }):Play()
            Services.TweenService:Create(Switch, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = targetColor
            }):Play()
            onToggleChanged(active)
        end)
    end

    -- Helper Component: Hitbox / Part Selector Row (Cycle Pill)
    local function CreateSelectorRow(parent, name, options, defaultSelected, onSelectChanged, layoutOrder)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 30)
        Row.BackgroundTransparency = 1
        Row.LayoutOrder = layoutOrder or 2
        Row.Parent = parent

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -130, 1, 0)
        Label.Position = UDim2.new(0, 0, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 12
        Label.TextColor3 = Color3.fromRGB(230, 230, 230)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Row

        local CycleBtn = Instance.new("TextButton")
        CycleBtn.Size = UDim2.new(0, 120, 0, 24)
        CycleBtn.Position = UDim2.new(1, -120, 0.5, -12)
        CycleBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        CycleBtn.BorderSizePixel = 0
        CycleBtn.Text = ""
        CycleBtn.AutoButtonColor = false
        CycleBtn.Parent = Row

        local CCorner = Instance.new("UICorner")
        CCorner.CornerRadius = UDim.new(0, 6)
        CCorner.Parent = CycleBtn

        local CStroke = Instance.new("UIStroke")
        CStroke.Color = Color3.fromRGB(36, 36, 36)
        CStroke.Thickness = 1
        CStroke.Parent = CycleBtn

        local CycleText = Instance.new("TextLabel")
        CycleText.Size = UDim2.new(1, -22, 1, 0)
        CycleText.Position = UDim2.new(0, 8, 0, 0)
        CycleText.BackgroundTransparency = 1
        CycleText.Text = defaultSelected
        CycleText.Font = Enum.Font.GothamBold
        CycleText.TextSize = 11
        CycleText.TextColor3 = Color3.fromRGB(240, 240, 240)
        CycleText.TextXAlignment = Enum.TextXAlignment.Left
        CycleText.Parent = CycleBtn

        local Arrow = Instance.new("ImageLabel")
        Arrow.Size = UDim2.new(0, 10, 0, 10)
        Arrow.Position = UDim2.new(1, -14, 0.5, -5)
        Arrow.BackgroundTransparency = 1
        Arrow.Image = "rbxassetid://6031091004"
        Arrow.ImageColor3 = Color3.fromRGB(160, 160, 160)
        Arrow.Parent = CycleBtn

        local currentIdx = 1
        for i, opt in ipairs(options) do
            if opt == defaultSelected then
                currentIdx = i
                break
            end
        end

        CycleBtn.MouseEnter:Connect(function()
            Services.TweenService:Create(CycleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
        end)
        CycleBtn.MouseLeave:Connect(function()
            Services.TweenService:Create(CycleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(22, 22, 22)}):Play()
        end)

        CycleBtn.MouseButton1Click:Connect(function()
            currentIdx = currentIdx + 1
            if currentIdx > #options then currentIdx = 1 end
            local selected = options[currentIdx]
            CycleText.Text = selected
            onSelectChanged(selected)
        end)
    end

    -- Helper Component: Toggle Row with Animation Fades
    local function CreateToggleRow(parent, name, hasSubmenu, defaultActive, onToggleChanged, onSubmenuClicked, layoutOrder)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 28)
        Row.BackgroundTransparency = 1
        Row.LayoutOrder = layoutOrder or 3
        Row.Parent = parent

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -80, 1, 0)
        Label.Position = UDim2.new(0, 0, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 12
        Label.TextColor3 = Color3.fromRGB(230, 230, 230)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Row

        if hasSubmenu then
            local SubBtn = Instance.new("TextButton")
            SubBtn.Size = UDim2.new(0, 22, 0, 18)
            SubBtn.Position = UDim2.new(1, -62, 0.5, -9)
            SubBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            SubBtn.BorderSizePixel = 0
            SubBtn.Text = "..."
            SubBtn.Font = Enum.Font.GothamBold
            SubBtn.TextSize = 10
            SubBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
            SubBtn.AutoButtonColor = false
            SubBtn.Parent = Row

            local SubCorner = Instance.new("UICorner")
            SubCorner.CornerRadius = UDim.new(0, 6)
            SubCorner.Parent = SubBtn

            local SubStroke = Instance.new("UIStroke")
            SubStroke.Color = Color3.fromRGB(34, 34, 34)
            SubStroke.Thickness = 1
            SubStroke.Parent = SubBtn

            SubBtn.MouseButton1Click:Connect(function()
                if onSubmenuClicked then onSubmenuClicked() end
            end)
        end

        local Switch = Instance.new("TextButton")
        Switch.Size = UDim2.new(0, 32, 0, 18)
        Switch.Position = UDim2.new(1, -32, 0.5, -9)
        Switch.BackgroundColor3 = defaultActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(24, 24, 24)
        Switch.BorderSizePixel = 0
        Switch.Text = ""
        Switch.AutoButtonColor = false
        Switch.Parent = Row

        local SwitchCorner = Instance.new("UICorner")
        SwitchCorner.CornerRadius = UDim.new(1, 0)
        SwitchCorner.Parent = Switch

        local SwitchStroke = Instance.new("UIStroke")
        SwitchStroke.Color = Color3.fromRGB(36, 36, 36)
        SwitchStroke.Thickness = 1
        SwitchStroke.Parent = Switch

        local Knob = Instance.new("Frame")
        Knob.Size = UDim2.new(0, 12, 0, 12)
        Knob.Position = defaultActive and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        Knob.BackgroundColor3 = defaultActive and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(190, 190, 190)
        Knob.BorderSizePixel = 0
        Knob.Parent = Switch

        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(1, 0)
        KnobCorner.Parent = Knob

        local active = defaultActive
        Switch.MouseButton1Click:Connect(function()
            active = not active
            local targetPos = active and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
            local targetColor = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(24, 24, 24)
            local knobColor = active and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(190, 190, 190)

            Services.TweenService:Create(Knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = targetPos,
                BackgroundColor3 = knobColor
            }):Play()
            Services.TweenService:Create(Switch, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = targetColor
            }):Play()
            onToggleChanged(active)
        end)
    end

    -- Helper Component: Slider Row with Global Dragging
    local function CreateSliderRow(parent, name, minVal, maxVal, defaultVal, onValueChanged, layoutOrder)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, 0, 0, 42)
        Container.BackgroundTransparency = 1
        Container.LayoutOrder = layoutOrder or 4
        Container.Parent = parent

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, -60, 0, 18)
        Title.Position = UDim2.new(0, 0, 0, 0)
        Title.BackgroundTransparency = 1
        Title.Text = name
        Title.Font = Enum.Font.Gotham
        Title.TextSize = 12
        Title.TextColor3 = Color3.fromRGB(230, 230, 230)
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = Container

        local ValueLabel = Instance.new("TextLabel")
        ValueLabel.Size = UDim2.new(0, 50, 0, 18)
        ValueLabel.Position = UDim2.new(1, -50, 0, 0)
        ValueLabel.BackgroundTransparency = 1
        ValueLabel.Text = tostring(defaultVal)
        ValueLabel.Font = Enum.Font.GothamMedium
        ValueLabel.TextSize = 12
        ValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
        ValueLabel.Parent = Container

        local TrackBtn = Instance.new("TextButton")
        TrackBtn.Size = UDim2.new(1, 0, 0, 6)
        TrackBtn.Position = UDim2.new(0, 0, 0, 25)
        TrackBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
        TrackBtn.BorderSizePixel = 0
        TrackBtn.Text = ""
        TrackBtn.AutoButtonColor = false
        TrackBtn.Parent = Container

        local TrackCorner = Instance.new("UICorner")
        TrackCorner.CornerRadius = UDim.new(1, 0)
        TrackCorner.Parent = TrackBtn

        local TrackStroke = Instance.new("UIStroke")
        TrackStroke.Color = Color3.fromRGB(34, 34, 34)
        TrackStroke.Thickness = 1
        TrackStroke.Parent = TrackBtn

        local Fill = Instance.new("Frame")
        local initialRatio = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
        Fill.Size = UDim2.new(initialRatio, 0, 1, 0)
        Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Fill.BorderSizePixel = 0
        Fill.Parent = TrackBtn

        local FillCorner = Instance.new("UICorner")
        FillCorner.CornerRadius = UDim.new(1, 0)
        FillCorner.Parent = Fill

        local Knob = Instance.new("Frame")
        Knob.Size = UDim2.new(0, 12, 0, 12)
        Knob.Position = UDim2.new(1, -6, 0.5, -6)
        Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Knob.BorderSizePixel = 0
        Knob.Parent = Fill

        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(1, 0)
        KnobCorner.Parent = Knob

        local KnobStroke = Instance.new("UIStroke")
        KnobStroke.Color = Color3.fromRGB(15, 15, 15)
        KnobStroke.Thickness = 1.5
        KnobStroke.Parent = Knob

        local isDragging = false

        local function UpdateFromPosition(inputX)
            local trackX = TrackBtn.AbsolutePosition.X
            local trackWidth = TrackBtn.AbsoluteSize.X
            if trackWidth <= 0 then return end
            local ratio = math.clamp((inputX - trackX) / trackWidth, 0, 1)
            local val = math.floor(minVal + ((maxVal - minVal) * ratio) + 0.5)

            Fill.Size = UDim2.new(ratio, 0, 1, 0)
            ValueLabel.Text = tostring(val)
            onValueChanged(val)
        end

        TrackBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = true
                UpdateFromPosition(input.Position.X)
                Services.TweenService:Create(Knob, TweenInfo.new(0.15), {Size = UDim2.new(0, 14, 0, 14)}):Play()
            end
        end)

        Services.UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if isDragging then
                    isDragging = false
                    Services.TweenService:Create(Knob, TweenInfo.new(0.15), {Size = UDim2.new(0, 12, 0, 12)}):Play()
                end
            end
        end)

        Services.UserInputService.InputChanged:Connect(function(input)
            if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateFromPosition(input.Position.X)
            end
        end)
    end

    -- ==============================================================================
    -- LIVE VISUALS PREVIEW WINDOW (Pop-Out Spaced Connected Box)
    -- ==============================================================================

    local PreviewFrame = Instance.new("Frame")
    PreviewFrame.Name = "PreviewFrame"
    PreviewFrame.Size = UDim2.new(0, 250, 0, 500)
    PreviewFrame.Position = UDim2.new(0.5, 374, 0.5, -250)
    PreviewFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    PreviewFrame.BorderSizePixel = 0
    PreviewFrame.ClipsDescendants = false
    PreviewFrame.Visible = State.ESP.Enabled
    PreviewFrame.Parent = ScreenGui

    local PreviewCorner = Instance.new("UICorner")
    PreviewCorner.CornerRadius = UDim.new(0, 18)
    PreviewCorner.Parent = PreviewFrame

    local PreviewStroke = Instance.new("UIStroke")
    PreviewStroke.Color = Color3.fromRGB(30, 30, 30)
    PreviewStroke.Thickness = 1.2
    PreviewStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    PreviewStroke.Parent = PreviewFrame

    local Bridge = Instance.new("Frame")
    Bridge.Name = "Bridge"
    Bridge.Size = UDim2.new(0, 14, 0, 4)
    Bridge.Position = UDim2.new(0, -14, 0.5, -2)
    Bridge.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Bridge.BorderSizePixel = 0
    Bridge.ZIndex = 5
    Bridge.Parent = PreviewFrame

    local BridgeCorner = Instance.new("UICorner")
    BridgeCorner.CornerRadius = UDim.new(1, 0)
    BridgeCorner.Parent = Bridge

    local PrevHeader = Instance.new("Frame")
    PrevHeader.Size = UDim2.new(1, 0, 0, 48)
    PrevHeader.BackgroundTransparency = 1
    PrevHeader.Parent = PreviewFrame

    local PrevTitle = Instance.new("TextLabel")
    PrevTitle.Size = UDim2.new(1, -24, 0, 20)
    PrevTitle.Position = UDim2.new(0, 14, 0, 10)
    PrevTitle.BackgroundTransparency = 1
    PrevTitle.Text = "Visuals Preview"
    PrevTitle.Font = Enum.Font.GothamBold
    PrevTitle.TextSize = 14
    PrevTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrevTitle.TextXAlignment = Enum.TextXAlignment.Left
    PrevTitle.Parent = PrevHeader

    local PrevSubtitle = Instance.new("TextLabel")
    PrevSubtitle.Size = UDim2.new(1, -24, 0, 14)
    PrevSubtitle.Position = UDim2.new(0, 14, 0, 28)
    PrevSubtitle.BackgroundTransparency = 1
    PrevSubtitle.Text = "Real-time preview simulator"
    PrevSubtitle.Font = Enum.Font.Gotham
    PrevSubtitle.TextSize = 11
    PrevSubtitle.TextColor3 = Color3.fromRGB(140, 140, 140)
    PrevSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    PrevSubtitle.Parent = PrevHeader

    local PrevDivider = Instance.new("Frame")
    PrevDivider.Size = UDim2.new(1, -28, 0, 1)
    PrevDivider.Position = UDim2.new(0, 14, 0, 48)
    PrevDivider.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    PrevDivider.BorderSizePixel = 0
    PrevDivider.Parent = PreviewFrame

    local Viewport = Instance.new("ViewportFrame")
    Viewport.Size = UDim2.new(1, -28, 1, -66)
    Viewport.Position = UDim2.new(0, 14, 0, 54)
    Viewport.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    Viewport.BorderSizePixel = 0
    Viewport.Ambient = Color3.fromRGB(180, 180, 180)
    Viewport.LightColor = Color3.fromRGB(255, 255, 255)
    Viewport.LightDirection = Vector3.new(-1, -2, -1)
    Viewport.Parent = PreviewFrame

    local VpCorner = Instance.new("UICorner")
    VpCorner.CornerRadius = UDim.new(0, 14)
    VpCorner.Parent = Viewport

    local VpStroke = Instance.new("UIStroke")
    VpStroke.Color = Color3.fromRGB(24, 24, 24)
    VpStroke.Thickness = 1
    VpStroke.Parent = Viewport

    local VpCamera = Instance.new("Camera")
    VpCamera.FieldOfView = 42
    VpCamera.CFrame = CFrame.new(Vector3.new(0, 0.4, 7.5), Vector3.new(0, 0.2, 0))
    Viewport.CurrentCamera = VpCamera
    VpCamera.Parent = Viewport

    -- Visuals Preview Showcase Container (3D dummy model removed; clean floating showcase preserved)

    local PrevBox = Instance.new("Frame")
    PrevBox.Size = UDim2.new(0, 134, 0, 224)
    PrevBox.Position = UDim2.new(0.5, -67, 0.5, -112)
    PrevBox.BackgroundTransparency = 1
    PrevBox.Visible = State.ESP.Box
    PrevBox.Parent = Viewport

    local PrevBoxStroke = Instance.new("UIStroke")
    PrevBoxStroke.Color = Color3.fromRGB(255, 255, 255)
    PrevBoxStroke.Thickness = 1.2
    PrevBoxStroke.Parent = PrevBox

    local PrevName = Instance.new("TextLabel")
    PrevName.Size = UDim2.new(1, 0, 0, 16)
    PrevName.Position = UDim2.new(0, 0, 0, -20)
    PrevName.BackgroundTransparency = 1
    PrevName.Text = "Target Dummy"
    PrevName.Font = Enum.Font.GothamBold
    PrevName.TextSize = 12
    PrevName.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrevName.Visible = State.ESP.Name
    PrevName.Parent = PrevBox

    local PrevDist = Instance.new("TextLabel")
    PrevDist.Size = UDim2.new(1, 0, 0, 16)
    PrevDist.Position = UDim2.new(0, 0, 1, 4)
    PrevDist.BackgroundTransparency = 1
    PrevDist.Text = "45 studs"
    PrevDist.Font = Enum.Font.GothamMedium
    PrevDist.TextSize = 11
    PrevDist.TextColor3 = Color3.fromRGB(200, 200, 200)
    PrevDist.Visible = State.ESP.Distance
    PrevDist.Parent = PrevBox

    local PrevHealthBar = Instance.new("Frame")
    PrevHealthBar.Size = UDim2.new(0, 3, 1, 0)
    PrevHealthBar.Position = UDim2.new(0, -7, 0, 0)
    PrevHealthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    PrevHealthBar.BorderSizePixel = 0
    PrevHealthBar.Visible = State.ESP.HealthBar
    PrevHealthBar.Parent = PrevBox

    local PrevHealthCorner = Instance.new("UICorner")
    PrevHealthCorner.CornerRadius = UDim.new(1, 0)
    PrevHealthCorner.Parent = PrevHealthBar

    local PrevHealthText = Instance.new("TextLabel")
    PrevHealthText.Size = UDim2.new(0, 44, 0, 16)
    PrevHealthText.Position = UDim2.new(0, -54, 0, 0)
    PrevHealthText.BackgroundTransparency = 1
    PrevHealthText.Text = "100 HP"
    PrevHealthText.Font = Enum.Font.GothamMedium
    PrevHealthText.TextSize = 11
    PrevHealthText.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrevHealthText.TextXAlignment = Enum.TextXAlignment.Right
    PrevHealthText.Visible = State.ESP.HealthText
    PrevHealthText.Parent = PrevBox

    local PrevSkelContainer = Instance.new("Frame")
    PrevSkelContainer.Size = UDim2.new(1, 0, 1, 0)
    PrevSkelContainer.BackgroundTransparency = 1
    PrevSkelContainer.Visible = State.ESP.Skeleton
    PrevSkelContainer.Parent = PrevBox

    local function MakeSkelLine(x1, y1, x2, y2)
        local line = Instance.new("Frame")
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        line.BorderSizePixel = 0
        local length = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
        line.Size = UDim2.new(0, length, 0, 1.5)
        line.Position = UDim2.new(0, (x1 + x2) / 2 - length / 2, 0, (y1 + y2) / 2)
        line.Rotation = math.deg(math.atan2(y2 - y1, x2 - x1))
        line.Parent = PrevSkelContainer
        return line
    end

    MakeSkelLine(67, 30, 67, 112)
    MakeSkelLine(67, 55, 20, 95)
    MakeSkelLine(67, 55, 114, 95)
    MakeSkelLine(67, 112, 40, 198)
    MakeSkelLine(67, 112, 94, 198)

    local PrevTracer = Instance.new("Frame")
    PrevTracer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    PrevTracer.BorderSizePixel = 0
    PrevTracer.Visible = State.ESP.Tracer
    PrevTracer.Parent = Viewport

    local function UpdatePreviewTracer()
        local vpW = Viewport.AbsoluteSize.X
        local vpH = Viewport.AbsoluteSize.Y
        if vpW <= 0 or vpH <= 0 then return end
        local x1 = vpW / 2
        local y1 = vpH
        local x2 = vpW / 2
        local y2 = (vpH / 2) + 112
        local length = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
        PrevTracer.Size = UDim2.new(0, length, 0, 1.2)
        PrevTracer.Position = UDim2.new(0, (x1 + x2)/2 - length/2, 0, (y1 + y2)/2)
        PrevTracer.Rotation = math.deg(math.atan2(y2 - y1, x2 - x1))
    end

    local function RefreshPreview()
        PrevBox.Visible = State.ESP.Box
        PrevName.Visible = State.ESP.Name
        PrevDist.Visible = State.ESP.Distance
        PrevHealthBar.Visible = State.ESP.HealthBar
        PrevHealthText.Visible = State.ESP.HealthText
        PrevSkelContainer.Visible = State.ESP.Skeleton
        PrevTracer.Visible = State.ESP.Tracer
        UpdatePreviewTracer()

        local rainbowCol = State.ESP.Rainbow and Color3.fromHSV((tick() * 0.4) % 1, 1, 1) or Color3.fromRGB(255, 255, 255)
        PrevBoxStroke.Color = rainbowCol
        PrevName.TextColor3 = rainbowCol
        PrevHealthBar.BackgroundColor3 = rainbowCol
        PrevHealthText.TextColor3 = rainbowCol
        PrevTracer.BackgroundColor3 = rainbowCol

        -- 3D mannequin model removed; showcase elements dynamically update below
    end

    local function TogglePreview(visible)
        if visible then
            PreviewFrame.Visible = true
            RefreshPreview()
            Services.TweenService:Create(PreviewFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(MainFrame.Position.X.Scale, MainFrame.Position.X.Offset + 734, MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset)
            }):Play()
        else
            PreviewFrame.Visible = false
        end
    end

    Services.RunService.RenderStepped:Connect(function()
        if PreviewFrame.Visible then
            PreviewFrame.Position = UDim2.new(
                MainFrame.Position.X.Scale,
                MainFrame.Position.X.Offset + 734,
                MainFrame.Position.Y.Scale,
                MainFrame.Position.Y.Offset
            )
            if State.ESP.Rainbow then
                RefreshPreview()
            end
        end
    end)

    -- ==============================================================================
    -- TAB 1: MAIN PAGE (Aimbot Controls & ESP Visuals)
    -- ==============================================================================
    local AimCard = CreateCard(MainPageView, "Aimbot Controls", "Configure aim bot settings", 1)
    local aimOrder = 0
    local function NextAim() aimOrder = aimOrder + 1; return aimOrder end

    CreateMasterRow(AimCard, State.Aimbot.Keybind, function(newKey)
        State.Aimbot.Keybind = newKey
    end, State.Aimbot.Enabled, function(val)
        State.Aimbot.Enabled = val
    end, NextAim())

    CreateSelectorRow(AimCard, "Aim Key Mode", {"Hold", "Toggle"}, State.Aimbot.AimMode, function(selected)
        State.Aimbot.AimMode = selected
        if selected == "Hold" then
            State.Aimbot.Active = false
            LockedTarget = nil
        end
        ShowToast("Aim Mode set to: " .. selected)
    end, NextAim())

    CreateSelectorRow(AimCard, "Target Hitbox", {"Head", "Body", "Torso", "HumanoidRootPart", "Closest"}, State.Aimbot.TargetPart, function(selected)
        State.Aimbot.TargetPart = selected
        ShowToast("Target Hitbox set to: " .. selected)
    end, NextAim())

    CreateToggleRow(AimCard, "Prioritize Body", false, State.Aimbot.BodyPriority, function(val)
        State.Aimbot.BodyPriority = val
        ShowToast(val and "Body targeting prioritized" or "Default hitbox prioritized")
    end, nil, NextAim())

    CreateToggleRow(AimCard, "Team Check", true, State.Aimbot.TeamCheck, function(val)
        State.Aimbot.TeamCheck = val
    end, nil, NextAim())

    CreateToggleRow(AimCard, "Wall Check", true, State.Aimbot.WallCheck, function(val)
        State.Aimbot.WallCheck = val
    end, nil, NextAim())

    CreateToggleRow(AimCard, "Use Prediction", true, State.Aimbot.UsePrediction, function(val)
        State.Aimbot.UsePrediction = val
    end, nil, NextAim())

    CreateSliderRow(AimCard, "Prediction Value", 0, 10, State.Aimbot.PredictionValue, function(val)
        State.Aimbot.PredictionValue = val
    end, NextAim())

    CreateSliderRow(AimCard, "FOV Size", 0, 800, State.Aimbot.FOVSize, function(val)
        State.Aimbot.FOVSize = val
    end, NextAim())

    CreateSliderRow(AimCard, "Horizontal Smoothing", 1, 30, State.Aimbot.SmoothnessX, function(val)
        State.Aimbot.SmoothnessX = val
    end, NextAim())

    CreateSliderRow(AimCard, "Vertical Smoothing", 1, 30, State.Aimbot.SmoothnessY, function(val)
        State.Aimbot.SmoothnessY = val
    end, NextAim())

    local ESPCard = CreateCard(MainPageView, "ESP Visuals", "Configure ESP settings", 2)
    local espOrder = 0
    local function NextESP() espOrder = espOrder + 1; return espOrder end

    CreateMasterRow(ESPCard, State.ESP.Keybind, function(newKey)
        State.ESP.Keybind = newKey
    end, State.ESP.Enabled, function(val)
        State.ESP.Enabled = val
        TogglePreview(val)
    end, NextESP())

    CreateToggleRow(ESPCard, "Box ESP", true, State.ESP.Box, function(val)
        State.ESP.Box = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Name ESP", true, State.ESP.Name, function(val)
        State.ESP.Name = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Distance ESP", true, State.ESP.Distance, function(val)
        State.ESP.Distance = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Skeleton ESP", true, State.ESP.Skeleton, function(val)
        State.ESP.Skeleton = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Health Text ESP", true, State.ESP.HealthText, function(val)
        State.ESP.HealthText = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Health Bar ESP", true, State.ESP.HealthBar, function(val)
        State.ESP.HealthBar = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Tracer ESP", true, State.ESP.Tracer, function(val)
        State.ESP.Tracer = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Chams", true, State.ESP.Chams, function(val)
        State.ESP.Chams = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Team Check", true, State.ESP.TeamCheck, function(val)
        State.ESP.TeamCheck = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Show Self / LocalPlayer", false, State.ESP.ShowSelf, function(val)
        State.ESP.ShowSelf = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Rainbow Visuals", false, State.ESP.Rainbow, function(val)
        State.ESP.Rainbow = val
        RefreshPreview()
    end, nil, NextESP())

    CreateToggleRow(ESPCard, "Radar Minimap", false, State.ESP.Radar, function(val)
        State.ESP.Radar = val
        RadarFrame.Visible = val and State.ESP.Enabled
    end, nil, NextESP())

    CreateSliderRow(ESPCard, "Radar Range", 50, 600, State.ESP.RadarRange, function(val)
        State.ESP.RadarRange = val
    end, NextESP())

    CreateSliderRow(ESPCard, "ESP Distance", 100, 5000, State.ESP.MaxDistance, function(val)
        State.ESP.MaxDistance = val
    end, NextESP())

    -- ==============================================================================
    -- TAB 2: PLAYER OPTIONS (Clean State Management)
    -- ==============================================================================
    local MovementCard = CreateCard(PlayerPageView, "Movement Modifiers", "Local character adjustments", 1)
    local moveOrder = 0
    local function NextMove() moveOrder = moveOrder + 1; return moveOrder end

    CreateToggleRow(MovementCard, "Enable WalkSpeed", false, State.Player.ModifySpeed, function(val)
        State.Player.ModifySpeed = val
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if val then
                hum.WalkSpeed = State.Player.WalkSpeed
            else
                hum.WalkSpeed = 16
            end
        end
    end, nil, NextMove())

    CreateSliderRow(MovementCard, "Walk Speed", 16, 250, State.Player.WalkSpeed, function(val)
        State.Player.WalkSpeed = val
        if State.Player.ModifySpeed and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = val
        end
    end, NextMove())

    CreateToggleRow(MovementCard, "Enable JumpPower", false, State.Player.ModifyJump, function(val)
        State.Player.ModifyJump = val
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if val then
                hum.UseJumpPower = true
                hum.JumpPower = State.Player.JumpPower
            else
                hum.JumpPower = 50
                hum.UseJumpPower = false
            end
        end
    end, nil, NextMove())

    CreateSliderRow(MovementCard, "Jump Power", 50, 300, State.Player.JumpPower, function(val)
        State.Player.JumpPower = val
        if State.Player.ModifyJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            hum.UseJumpPower = true
            hum.JumpPower = val
        end
    end, NextMove())

    CreateToggleRow(MovementCard, "Enable Custom FOV", false, State.Player.ModifyFOV, function(val)
        State.Player.ModifyFOV = val
        if val then
            Camera.FieldOfView = State.Player.FieldOfView
        else
            Camera.FieldOfView = 70
        end
    end, nil, NextMove())

    CreateSliderRow(MovementCard, "Field of View", 60, 120, State.Player.FieldOfView, function(val)
        State.Player.FieldOfView = val
        if State.Player.ModifyFOV then
            Camera.FieldOfView = val
        end
    end, NextMove())

    local PlayerConn = Services.RunService.RenderStepped:Connect(function()
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                if State.Player.ModifySpeed then
                    hum.WalkSpeed = State.Player.WalkSpeed
                end
                if State.Player.ModifyJump then
                    hum.UseJumpPower = true
                    hum.JumpPower = State.Player.JumpPower
                end
            end
        end
        if State.Player.ModifyFOV then
            Camera.FieldOfView = State.Player.FieldOfView
        end
    end)
    table.insert(ActiveConnections, PlayerConn)

    local TeleportCard = CreateCard(PlayerPageView, "Teleport Utility", "Instantly navigate to player", 2)

    local TpContainer = Instance.new("Frame")
    TpContainer.Size = UDim2.new(1, 0, 0, 94)
    TpContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    TpContainer.BorderSizePixel = 0
    TpContainer.LayoutOrder = 1
    TpContainer.Parent = TeleportCard

    local TpCorner = Instance.new("UICorner")
    TpCorner.CornerRadius = UDim.new(0, 10)
    TpCorner.Parent = TpContainer

    local TpStroke = Instance.new("UIStroke")
    TpStroke.Color = Color3.fromRGB(30, 30, 30)
    TpStroke.Thickness = 1
    TpStroke.Parent = TpContainer

    local TpLabel = Instance.new("TextLabel")
    TpLabel.Size = UDim2.new(1, -20, 0, 20)
    TpLabel.Position = UDim2.new(0, 12, 0, 10)
    TpLabel.BackgroundTransparency = 1
    TpLabel.Text = "Teleport to Player"
    TpLabel.Font = Enum.Font.GothamBold
    TpLabel.TextSize = 12
    TpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TpLabel.TextXAlignment = Enum.TextXAlignment.Left
    TpLabel.Parent = TpContainer

    local TpInput = Instance.new("TextBox")
    TpInput.Size = UDim2.new(1, -24, 0, 28)
    TpInput.Position = UDim2.new(0, 12, 0, 34)
    TpInput.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    TpInput.BorderSizePixel = 0
    TpInput.PlaceholderText = "Enter player username..."
    TpInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    TpInput.Text = ""
    TpInput.Font = Enum.Font.Gotham
    TpInput.TextSize = 12
    TpInput.TextColor3 = Color3.fromRGB(240, 240, 240)
    TpInput.ClearTextOnFocus = false
    TpInput.Parent = TpContainer

    local InCorner = Instance.new("UICorner")
    InCorner.CornerRadius = UDim.new(0, 6)
    InCorner.Parent = TpInput

    local InStroke = Instance.new("UIStroke")
    InStroke.Color = Color3.fromRGB(34, 34, 34)
    InStroke.Thickness = 1
    InStroke.Parent = TpInput

    local TpExecBtn = Instance.new("TextButton")
    TpExecBtn.Size = UDim2.new(1, 0, 0, 36)
    TpExecBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TpExecBtn.BorderSizePixel = 0
    TpExecBtn.Text = "Execute Teleport"
    TpExecBtn.Font = Enum.Font.GothamBold
    TpExecBtn.TextSize = 12
    TpExecBtn.TextColor3 = Color3.fromRGB(10, 10, 10)
    TpExecBtn.AutoButtonColor = false
    TpExecBtn.LayoutOrder = 2
    TpExecBtn.Parent = TeleportCard

    local TpBtnCorner = Instance.new("UICorner")
    TpBtnCorner.CornerRadius = UDim.new(0, 10)
    TpBtnCorner.Parent = TpExecBtn

    TpExecBtn.MouseButton1Click:Connect(function()
        local query = string.lower(TpInput.Text)
        if query == "" then
            ShowToast("Please enter a player name!")
            return
        end

        local foundTarget = nil
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local uName = string.lower(p.Name)
                local dName = string.lower(p.DisplayName)
                if string.find(uName, query) or string.find(dName, query) then
                    foundTarget = p
                    break
                end
            end
        end

        if foundTarget and foundTarget.Character and foundTarget.Character:FindFirstChild("HumanoidRootPart") then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local targetCFrame = foundTarget.Character.HumanoidRootPart.CFrame
                LocalPlayer.Character.HumanoidRootPart.CFrame = targetCFrame + Vector3.new(0, 3, 0)
                ShowToast("Teleported to " .. foundTarget.DisplayName .. "!")
            else
                ShowToast("Your character root was not found.")
            end
        else
            ShowToast("Player '" .. TpInput.Text .. "' not found.")
        end
    end)

    -- ==============================================================================
    -- TAB 3: SETTINGS (Open Spot Function Squares + System Management)
    -- ==============================================================================
    local InterfaceCard = CreateCard(SettingsPageView, "Interface & Socials", "Hub customization and official links", 1)
    local SystemCard = CreateCard(SettingsPageView, "Session Management", "Runtime session controls & tools", 2)

    local function CreateFunctionSquare(parent, title, subtitle, iconId, height, layoutOrder)
        local Box = Instance.new("Frame")
        Box.Size = UDim2.new(1, 0, 0, height or 78)
        Box.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        Box.BorderSizePixel = 0
        Box.LayoutOrder = layoutOrder or 1
        Box.Parent = parent

        local BCorner = Instance.new("UICorner")
        BCorner.CornerRadius = UDim.new(0, 10)
        BCorner.Parent = Box

        local BStroke = Instance.new("UIStroke")
        BStroke.Color = Color3.fromRGB(28, 28, 28)
        BStroke.Thickness = 1
        BStroke.Parent = Box

        local IconBadge = Instance.new("Frame")
        IconBadge.Size = UDim2.new(0, 26, 0, 26)
        IconBadge.Position = UDim2.new(0, 12, 0, 10)
        IconBadge.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        IconBadge.BorderSizePixel = 0
        IconBadge.Parent = Box

        local IbCorner = Instance.new("UICorner")
        IbCorner.CornerRadius = UDim.new(0, 6)
        IbCorner.Parent = IconBadge

        local Icon = Instance.new("ImageLabel")
        Icon.Size = UDim2.new(0, 15, 0, 15)
        Icon.Position = UDim2.new(0.5, -7, 0.5, -7)
        Icon.BackgroundTransparency = 1
        Icon.Image = iconId
        Icon.ImageColor3 = Color3.fromRGB(240, 240, 240)
        Icon.Parent = IconBadge

        local TitleL = Instance.new("TextLabel")
        TitleL.Size = UDim2.new(1, -52, 0, 16)
        TitleL.Position = UDim2.new(0, 44, 0, 8)
        TitleL.BackgroundTransparency = 1
        TitleL.Text = title
        TitleL.Font = Enum.Font.GothamBold
        TitleL.TextSize = 12
        TitleL.TextColor3 = Color3.fromRGB(245, 245, 245)
        TitleL.TextXAlignment = Enum.TextXAlignment.Left
        TitleL.Parent = Box

        local SubL = Instance.new("TextLabel")
        SubL.Size = UDim2.new(1, -52, 0, 14)
        SubL.Position = UDim2.new(0, 44, 0, 24)
        SubL.BackgroundTransparency = 1
        SubL.Text = subtitle
        SubL.Font = Enum.Font.Gotham
        SubL.TextSize = 10
        SubL.TextColor3 = Color3.fromRGB(130, 130, 130)
        SubL.TextXAlignment = Enum.TextXAlignment.Left
        SubL.Parent = Box

        return Box
    end

    -- 1. Menu Keybind Square (Button in Open Spot)
    local MenuKeyBox = CreateFunctionSquare(InterfaceCard, "Menu Keybind", "Key to toggle hub visibility", "rbxassetid://6031265976", 78, 1)
    local MKeyBtn = Instance.new("TextButton")
    MKeyBtn.Size = UDim2.new(1, -24, 0, 26)
    MKeyBtn.Position = UDim2.new(0, 12, 0, 44)
    MKeyBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MKeyBtn.BorderSizePixel = 0
    MKeyBtn.Text = "Menu Key: [" .. State.UI.ToggleKey.Name .. "]"
    MKeyBtn.Font = Enum.Font.GothamBold
    MKeyBtn.TextSize = 11
    MKeyBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    MKeyBtn.AutoButtonColor = false
    MKeyBtn.Parent = MenuKeyBox

    local MkCorner = Instance.new("UICorner")
    MkCorner.CornerRadius = UDim.new(0, 6)
    MkCorner.Parent = MKeyBtn

    local MkStroke = Instance.new("UIStroke")
    MkStroke.Color = Color3.fromRGB(38, 38, 38)
    MkStroke.Thickness = 1
    MkStroke.Parent = MKeyBtn

    local mListening = false
    MKeyBtn.MouseEnter:Connect(function()
        if not mListening then
            Services.TweenService:Create(MKeyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(32, 32, 32)}):Play()
        end
    end)
    MKeyBtn.MouseLeave:Connect(function()
        if not mListening then
            Services.TweenService:Create(MKeyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 25)}):Play()
        end
    end)
    MKeyBtn.MouseButton1Click:Connect(function()
        mListening = true
        MKeyBtn.Text = "Press Any Key to Bind..."
        MkStroke.Color = Color3.fromRGB(255, 255, 255)
    end)

    Services.UserInputService.InputBegan:Connect(function(input)
        if mListening and input.UserInputType == Enum.UserInputType.Keyboard then
            local chosen = (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace) and Enum.KeyCode.RightShift or input.KeyCode
            mListening = false
            MkStroke.Color = Color3.fromRGB(38, 38, 38)
            MKeyBtn.Text = "Menu Key: [" .. chosen.Name .. "]"
            State.UI.ToggleKey = chosen
            ShowToast("Menu Key set to: " .. chosen.Name)
        end
    end)

    -- 2. Watermark HUD Square (Toggle in Open Spot)
    local WatermarkBox = CreateFunctionSquare(InterfaceCard, "Watermark HUD", "Top-right hub FPS & Ping display", "rbxassetid://6031075929", 78, 2)
    local WToggleBtn = Instance.new("TextButton")
    WToggleBtn.Size = UDim2.new(1, -24, 0, 26)
    WToggleBtn.Position = UDim2.new(0, 12, 0, 44)
    WToggleBtn.BackgroundColor3 = State.UI.Watermark and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(22, 22, 22)
    WToggleBtn.BorderSizePixel = 0
    WToggleBtn.Text = State.UI.Watermark and "Status: Visible (Click to Hide)" or "Status: Hidden (Click to Show)"
    WToggleBtn.Font = Enum.Font.GothamMedium
    WToggleBtn.TextSize = 11
    WToggleBtn.TextColor3 = State.UI.Watermark and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
    WToggleBtn.AutoButtonColor = false
    WToggleBtn.Parent = WatermarkBox

    local WsCorner = Instance.new("UICorner")
    WsCorner.CornerRadius = UDim.new(0, 6)
    WsCorner.Parent = WToggleBtn

    local WsStroke = Instance.new("UIStroke")
    WsStroke.Color = State.UI.Watermark and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(34, 34, 34)
    WsStroke.Thickness = 1
    WsStroke.Parent = WToggleBtn

    WToggleBtn.MouseButton1Click:Connect(function()
        State.UI.Watermark = not State.UI.Watermark
        WatermarkBadge.Visible = State.UI.Watermark
        local active = State.UI.Watermark
        WToggleBtn.Text = active and "Status: Visible (Click to Hide)" or "Status: Hidden (Click to Show)"
        WToggleBtn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
        Services.TweenService:Create(WToggleBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = active and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(22, 22, 22)
        }):Play()
        Services.TweenService:Create(WsStroke, TweenInfo.new(0.2), {
            Color = active and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(34, 34, 34)
        }):Play()
    end)

    -- 3. Discord Community Square (Button in Open Spot)
    local DiscordBox = CreateFunctionSquare(InterfaceCard, "Discord Community", "discord.gg/saviorhub", "rbxassetid://6031075931", 78, 3)
    local DiscBtn = Instance.new("TextButton")
    DiscBtn.Size = UDim2.new(1, -24, 0, 26)
    DiscBtn.Position = UDim2.new(0, 12, 0, 44)
    DiscBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    DiscBtn.BorderSizePixel = 0
    DiscBtn.Text = "Join Discord Community"
    DiscBtn.Font = Enum.Font.GothamBold
    DiscBtn.TextSize = 11
    DiscBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    DiscBtn.AutoButtonColor = false
    DiscBtn.Parent = DiscordBox

    local DkCorner = Instance.new("UICorner")
    DkCorner.CornerRadius = UDim.new(0, 6)
    DkCorner.Parent = DiscBtn

    local DkStroke = Instance.new("UIStroke")
    DkStroke.Color = Color3.fromRGB(38, 38, 38)
    DkStroke.Thickness = 1
    DkStroke.Parent = DiscBtn

    DiscBtn.MouseEnter:Connect(function()
        Services.TweenService:Create(DiscBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(15, 15, 15)}):Play()
    end)
    DiscBtn.MouseLeave:Connect(function()
        Services.TweenService:Create(DiscBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 25), TextColor3 = Color3.fromRGB(240, 240, 240)}):Play()
    end)
    DiscBtn.MouseButton1Click:Connect(function()
        if SafeSetClipboard(State.Links.Discord) then
            ShowToast("Discord invite copied to clipboard!")
        else
            ShowToast("Invite: " .. State.Links.Discord)
        end
    end)

    -- 4. TikTok Channel Square (Button in Open Spot)
    local TikTokBox = CreateFunctionSquare(InterfaceCard, "TikTok Channel", "@saviorhub official clips", "rbxassetid://6031265976", 78, 4)
    local TkBtn = Instance.new("TextButton")
    TkBtn.Size = UDim2.new(1, -24, 0, 26)
    TkBtn.Position = UDim2.new(0, 12, 0, 44)
    TkBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TkBtn.BorderSizePixel = 0
    TkBtn.Text = "Follow on TikTok"
    TkBtn.Font = Enum.Font.GothamBold
    TkBtn.TextSize = 11
    TkBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    TkBtn.AutoButtonColor = false
    TkBtn.Parent = TikTokBox

    local TkkCorner = Instance.new("UICorner")
    TkkCorner.CornerRadius = UDim.new(0, 6)
    TkkCorner.Parent = TkBtn

    local TkkStroke = Instance.new("UIStroke")
    TkkStroke.Color = Color3.fromRGB(38, 38, 38)
    TkkStroke.Thickness = 1
    TkkStroke.Parent = TkBtn

    TkBtn.MouseEnter:Connect(function()
        Services.TweenService:Create(TkBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(15, 15, 15)}):Play()
    end)
    TkBtn.MouseLeave:Connect(function()
        Services.TweenService:Create(TkBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 25), TextColor3 = Color3.fromRGB(240, 240, 240)}):Play()
    end)
    TkBtn.MouseButton1Click:Connect(function()
        if SafeSetClipboard(State.Links.TikTok) then
            ShowToast("TikTok channel copied to clipboard!")
        else
            ShowToast("TikTok: " .. State.Links.TikTok)
        end
    end)

    local function UnloadSystem()
        pcall(function() Services.RunService:UnbindFromRenderStep("SaviorHubCameraStep") end)
        for _, conn in ipairs(ActiveConnections) do
            pcall(function() conn:Disconnect() end)
        end
        for player, _ in pairs(VisualEntities) do
            CleanupEntity(player)
        end
        for _, blip in pairs(RadarBlips) do
            pcall(function() blip:Destroy() end)
        end
        FOVCircle:Remove()
        ScreenGui:Destroy()
    end

    -- 5. Copy Loadstring Square (Button in Open Spot)
    local LoadstringBox = CreateFunctionSquare(SystemCard, "Script Loadstring", "Raw script loader line for executors", "rbxassetid://6031094678", 78, 1)
    local LsBtn = Instance.new("TextButton")
    LsBtn.Size = UDim2.new(1, -24, 0, 26)
    LsBtn.Position = UDim2.new(0, 12, 0, 44)
    LsBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    LsBtn.BorderSizePixel = 0
    LsBtn.Text = "Copy Script Loadstring"
    LsBtn.Font = Enum.Font.GothamBold
    LsBtn.TextSize = 11
    LsBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    LsBtn.AutoButtonColor = false
    LsBtn.Parent = LoadstringBox

    local LscCorner = Instance.new("UICorner")
    LscCorner.CornerRadius = UDim.new(0, 6)
    LscCorner.Parent = LsBtn

    local LscStroke = Instance.new("UIStroke")
    LscStroke.Color = Color3.fromRGB(38, 38, 38)
    LscStroke.Thickness = 1
    LscStroke.Parent = LsBtn

    LsBtn.MouseEnter:Connect(function()
        Services.TweenService:Create(LsBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(15, 15, 15)}):Play()
    end)
    LsBtn.MouseLeave:Connect(function()
        Services.TweenService:Create(LsBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 25), TextColor3 = Color3.fromRGB(240, 240, 240)}):Play()
    end)
    LsBtn.MouseButton1Click:Connect(function()
        local scriptLine = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/cylixstudios/unviersal/main/universal.lua", true))()'
        if SafeSetClipboard(scriptLine) then
            ShowToast("Loadstring copied to clipboard!")
        else
            ShowToast("Failed to access clipboard")
        end
    end)

    -- 6. Rejoin Server Square (Button in Open Spot)
    local RejoinBox = CreateFunctionSquare(SystemCard, "Rejoin Server", "Reconnect to this exact place instance", "rbxassetid://6031097225", 78, 2)
    local RjBtn = Instance.new("TextButton")
    RjBtn.Size = UDim2.new(1, -24, 0, 26)
    RjBtn.Position = UDim2.new(0, 12, 0, 44)
    RjBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    RjBtn.BorderSizePixel = 0
    RjBtn.Text = "Reconnect to Instance"
    RjBtn.Font = Enum.Font.GothamBold
    RjBtn.TextSize = 11
    RjBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    RjBtn.AutoButtonColor = false
    RjBtn.Parent = RejoinBox

    local RjcCorner = Instance.new("UICorner")
    RjcCorner.CornerRadius = UDim.new(0, 6)
    RjcCorner.Parent = RjBtn

    local RjcStroke = Instance.new("UIStroke")
    RjcStroke.Color = Color3.fromRGB(38, 38, 38)
    RjcStroke.Thickness = 1
    RjcStroke.Parent = RjBtn

    RjBtn.MouseEnter:Connect(function()
        Services.TweenService:Create(RjBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(15, 15, 15)}):Play()
    end)
    RjBtn.MouseLeave:Connect(function()
        Services.TweenService:Create(RjBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 25), TextColor3 = Color3.fromRGB(240, 240, 240)}):Play()
    end)
    RjBtn.MouseButton1Click:Connect(function()
        ShowToast("Rejoining server...")
        task.delay(0.5, function()
            local ts = game:GetService("TeleportService")
            pcall(function()
                ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
        end)
    end)

    -- 7. Server Hop Square (Button in Open Spot)
    local HopBox = CreateFunctionSquare(SystemCard, "Server Hop", "Find and join a different public server", "rbxassetid://6031154871", 78, 3)
    local HopBtn = Instance.new("TextButton")
    HopBtn.Size = UDim2.new(1, -24, 0, 26)
    HopBtn.Position = UDim2.new(0, 12, 0, 44)
    HopBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    HopBtn.BorderSizePixel = 0
    HopBtn.Text = "Find & Hop Server"
    HopBtn.Font = Enum.Font.GothamBold
    HopBtn.TextSize = 11
    HopBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    HopBtn.AutoButtonColor = false
    HopBtn.Parent = HopBox

    local HpcCorner = Instance.new("UICorner")
    HpcCorner.CornerRadius = UDim.new(0, 6)
    HpcCorner.Parent = HopBtn

    local HpcStroke = Instance.new("UIStroke")
    HpcStroke.Color = Color3.fromRGB(38, 38, 38)
    HpcStroke.Thickness = 1
    HpcStroke.Parent = HopBtn

    HopBtn.MouseEnter:Connect(function()
        Services.TweenService:Create(HopBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(15, 15, 15)}):Play()
    end)
    HopBtn.MouseLeave:Connect(function()
        Services.TweenService:Create(HopBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 25), TextColor3 = Color3.fromRGB(240, 240, 240)}):Play()
    end)
    HopBtn.MouseButton1Click:Connect(function()
        ShowToast("Searching for servers...")
        task.spawn(function()
            local ts = game:GetService("TeleportService")
            local hs = Services.HttpService
            local success, res = pcall(function()
                return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
            end)
            if success and res then
                local data = pcall(function() return hs:JSONDecode(res) end) and hs:JSONDecode(res)
                if data and data.data then
                    for _, s in ipairs(data.data) do
                        if s.playing < s.maxPlayers and s.id ~= game.JobId then
                            ShowToast("Teleporting to server...")
                            ts:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                            return
                        end
                    end
                end
            end
            ShowToast("No alternative server found")
        end)
    end)

    -- 8. Unload Savior Hub Square (Buttons in Open Spot)
    local UnloadBox = Instance.new("Frame")
    UnloadBox.Size = UDim2.new(1, 0, 0, 84)
    UnloadBox.BackgroundColor3 = Color3.fromRGB(18, 14, 14)
    UnloadBox.BorderSizePixel = 0
    UnloadBox.LayoutOrder = 4
    UnloadBox.Parent = SystemCard

    local UCorner = Instance.new("UICorner")
    UCorner.CornerRadius = UDim.new(0, 10)
    UCorner.Parent = UnloadBox

    local UStroke = Instance.new("UIStroke")
    UStroke.Color = Color3.fromRGB(50, 24, 24)
    UStroke.Thickness = 1
    UStroke.Parent = UnloadBox

    local UIconBadge = Instance.new("Frame")
    UIconBadge.Size = UDim2.new(0, 26, 0, 26)
    UIconBadge.Position = UDim2.new(0, 12, 0, 10)
    UIconBadge.BackgroundColor3 = Color3.fromRGB(32, 16, 16)
    UIconBadge.BorderSizePixel = 0
    UIconBadge.Parent = UnloadBox

    local UibCorner = Instance.new("UICorner")
    UibCorner.CornerRadius = UDim.new(0, 6)
    UibCorner.Parent = UIconBadge

    local UIcon = Instance.new("ImageLabel")
    UIcon.Size = UDim2.new(0, 15, 0, 15)
    UIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    UIcon.BackgroundTransparency = 1
    UIcon.Image = "rbxassetid://6031094674"
    UIcon.ImageColor3 = Color3.fromRGB(255, 90, 90)
    UIcon.Parent = UIconBadge

    local UTitle = Instance.new("TextLabel")
    UTitle.Size = UDim2.new(1, -52, 0, 16)
    UTitle.Position = UDim2.new(0, 44, 0, 8)
    UTitle.BackgroundTransparency = 1
    UTitle.Text = "Unload Savior Hub"
    UTitle.Font = Enum.Font.GothamBold
    UTitle.TextSize = 12
    UTitle.TextColor3 = Color3.fromRGB(255, 110, 110)
    UTitle.TextXAlignment = Enum.TextXAlignment.Left
    UTitle.Parent = UnloadBox

    local UDesc = Instance.new("TextLabel")
    UDesc.Size = UDim2.new(1, -52, 0, 14)
    UDesc.Position = UDim2.new(0, 44, 0, 24)
    UDesc.BackgroundTransparency = 1
    UDesc.Text = "Detach all camera hooks, overlays & GUI"
    UDesc.Font = Enum.Font.Gotham
    UDesc.TextSize = 10
    UDesc.TextColor3 = Color3.fromRGB(160, 110, 110)
    UDesc.TextXAlignment = Enum.TextXAlignment.Left
    UDesc.Parent = UnloadBox

    local UnloadBtnContainer = Instance.new("Frame")
    UnloadBtnContainer.Size = UDim2.new(1, -24, 0, 28)
    UnloadBtnContainer.Position = UDim2.new(0, 12, 0, 46)
    UnloadBtnContainer.BackgroundTransparency = 1
    UnloadBtnContainer.Parent = UnloadBox

    local UnloadKeyBtn = Instance.new("TextButton")
    UnloadKeyBtn.Size = UDim2.new(0.48, -4, 1, 0)
    UnloadKeyBtn.Position = UDim2.new(0, 0, 0, 0)
    UnloadKeyBtn.BackgroundColor3 = Color3.fromRGB(24, 20, 20)
    UnloadKeyBtn.BorderSizePixel = 0
    UnloadKeyBtn.Text = State.UI.UnloadBind == Enum.KeyCode.Unknown and "Bind: None" or ("Bind: " .. State.UI.UnloadBind.Name)
    UnloadKeyBtn.Font = Enum.Font.GothamMedium
    UnloadKeyBtn.TextSize = 10
    UnloadKeyBtn.TextColor3 = Color3.fromRGB(190, 175, 175)
    UnloadKeyBtn.AutoButtonColor = false
    UnloadKeyBtn.Parent = UnloadBtnContainer

    local UkCorner = Instance.new("UICorner")
    UkCorner.CornerRadius = UDim.new(0, 6)
    UkCorner.Parent = UnloadKeyBtn

    local UkStroke = Instance.new("UIStroke")
    UkStroke.Color = Color3.fromRGB(42, 28, 28)
    UkStroke.Thickness = 1
    UkStroke.Parent = UnloadKeyBtn

    local uListening = false
    UnloadKeyBtn.MouseButton1Click:Connect(function()
        uListening = true
        UnloadKeyBtn.Text = "..."
        UkStroke.Color = Color3.fromRGB(255, 100, 100)
    end)

    Services.UserInputService.InputBegan:Connect(function(input)
        if uListening and input.UserInputType == Enum.UserInputType.Keyboard then
            local chosen = (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace) and Enum.KeyCode.Unknown or input.KeyCode
            uListening = false
            UkStroke.Color = Color3.fromRGB(42, 28, 28)
            UnloadKeyBtn.Text = chosen == Enum.KeyCode.Unknown and "Bind: None" or ("Bind: " .. chosen.Name)
            State.UI.UnloadBind = chosen
            ShowToast("Unload Key: " .. chosen.Name)
        end
    end)

    local UnloadExecBtn = Instance.new("TextButton")
    UnloadExecBtn.Size = UDim2.new(0.52, -4, 1, 0)
    UnloadExecBtn.Position = UDim2.new(0.48, 4, 0, 0)
    UnloadExecBtn.BackgroundColor3 = Color3.fromRGB(215, 45, 45)
    UnloadExecBtn.BorderSizePixel = 0
    UnloadExecBtn.Text = "Unload Hub"
    UnloadExecBtn.Font = Enum.Font.GothamBold
    UnloadExecBtn.TextSize = 11
    UnloadExecBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    UnloadExecBtn.AutoButtonColor = false
    UnloadExecBtn.Parent = UnloadBtnContainer

    local UeCorner = Instance.new("UICorner")
    UeCorner.CornerRadius = UDim.new(0, 6)
    UeCorner.Parent = UnloadExecBtn

    UnloadExecBtn.MouseButton1Click:Connect(UnloadSystem)

    ScreenGui.Parent = guiParent
    return ScreenGui, MainFrame, PreviewFrame, UnloadSystem
end

-- ==============================================================================
-- INITIALIZATION & BINDINGS
-- ==============================================================================

local GuiInstance, MainFrameInstance, PreviewFrameInstance, UnloadFn = BuildSaviorInterface()

-- Visibility / Menu Keybind
local InputBeganConn = Services.UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        if input.KeyCode == State.UI.ToggleKey then
            State.UI.Visible = not State.UI.Visible
            MainFrameInstance.Visible = State.UI.Visible
            if PreviewFrameInstance then
                PreviewFrameInstance.Visible = State.UI.Visible and State.ESP.Enabled
            end
        end
        if State.UI.UnloadBind ~= Enum.KeyCode.Unknown and input.KeyCode == State.UI.UnloadBind then
            UnloadFn()
        end
    end

    -- Targeting Activation (Supports Keyboard and Mouse inputs, Hold or Toggle)
    if IsKeyMatch(State.Aimbot.Keybind, input) then
        if State.Aimbot.AimMode == "Toggle" then
            State.Aimbot.Active = not State.Aimbot.Active
            if not State.Aimbot.Active then
                LockedTarget = nil
            end
        else
            State.Aimbot.Active = true
        end
    end
end)
table.insert(ActiveConnections, InputBeganConn)

local InputEndedConn = Services.UserInputService.InputEnded:Connect(function(input)
    if IsKeyMatch(State.Aimbot.Keybind, input) then
        if State.Aimbot.AimMode == "Hold" then
            State.Aimbot.Active = false
            LockedTarget = nil
        end
    end
end)
table.insert(ActiveConnections, InputEndedConn)

-- Player Tracker Listeners
for _, player in ipairs(Services.Players:GetPlayers()) do
    SetupEntity(player)
end

local PlayerAddedConn = Services.Players.PlayerAdded:Connect(function(player)
    SetupEntity(player)
end)
table.insert(ActiveConnections, PlayerAddedConn)

local PlayerRemovingConn = Services.Players.PlayerRemoving:Connect(function(player)
    CleanupEntity(player)
    if RadarBlips[player] then
        pcall(function() RadarBlips[player]:Destroy() end)
        RadarBlips[player] = nil
    end
end)
table.insert(ActiveConnections, PlayerRemovingConn)

-- Bind Camera Step after Roblox CameraModule (priority 201) to eliminate jump jitter and camera fighting
Services.RunService:BindToRenderStep("SaviorHubCameraStep", Enum.RenderPriority.Camera.Value + 1, StepTargeting)

-- Visuals Pipeline on RenderStepped (Zero-Lag)
local RenderConn = Services.RunService.RenderStepped:Connect(function()
    StepVisuals()
end)
table.insert(ActiveConnections, RenderConn)

print("[Savior Hub] System initialized successfully. Press RightShift to toggle interface.")
