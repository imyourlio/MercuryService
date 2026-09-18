--[[
    WA Universal ESP
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {}
ESP.__index = ESP

local Settings = {
    Enabled = false,
    TeamCheck = true,          
    ShowTeam = false,          

    BoxESP = true,
    BoxStyle = "Corner",       
    BoxThickness = 1.5,

    TracerESP = false,
    TracerOrigin = "Bottom",   -- "Bottom" | "Top" | "Mouse" | "Center"
    TracerThickness = 1.2,

    HealthESP = true,
    HealthStyle = "Bar",

    NameESP = true,
    ShowDistance = true,
    TextSize = 14,

    SkeletonESP = false,
    SkeletonThickness = 1.4,

    ChamsEnabled = false,
    ChamsFillColor = Color3.fromRGB(255, 40, 40),
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsFillTransparency = 0.55,
    ChamsOutlineTransparency = 0,

    MaxDistance = 1500,
    RefreshRate = 1/144,
}

local Colors = {
    Enemy = Color3.fromRGB(255, 50, 50),
    Ally  = Color3.fromRGB(50, 255, 100),
    Health = Color3.fromRGB(0, 255, 80),
}

local Drawings = {
    ESP = {},
    Skeleton = {},
}
local Highlights = {}

local function GetPlayerColor(player)
    if player.Team and player.Team == LocalPlayer.Team then
        return Colors.Ally
    end
    return Colors.Enemy
end

local function GetTracerOrigin()
    local origin = Settings.TracerOrigin
    if origin == "Bottom" then
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    elseif origin == "Top" then
        return Vector2.new(Camera.ViewportSize.X / 2, 0)
    elseif origin == "Mouse" then
        return UserInputService:GetMouseLocation()
    else
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
end

local function HideAll(esp, skeleton)
    if esp then
        for _, v in pairs(esp.Box) do v.Visible = false end
        esp.Tracer.Visible = false
        for _, v in pairs(esp.HealthBar) do v.Visible = false end
        for _, v in pairs(esp.Info) do v.Visible = false end
    end
    if skeleton then
        for _, v in pairs(skeleton) do v.Visible = false end
    end
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    if Drawings.ESP[player] then return end

    local box = {
        TopLeft = Drawing.new("Line"),
        TopRight = Drawing.new("Line"),
        BottomLeft = Drawing.new("Line"),
        BottomRight = Drawing.new("Line"),
        Left = Drawing.new("Line"),
        Right = Drawing.new("Line"),
        Top = Drawing.new("Line"),
        Bottom = Drawing.new("Line"),
        C1 = Drawing.new("Line"),
        C2 = Drawing.new("Line"),
        C3 = Drawing.new("Line"),
        C4 = Drawing.new("Line"),
    }

    for _, line in pairs(box) do
        line.Visible = false
        line.Thickness = Settings.BoxThickness
        line.Color = Colors.Enemy
    end

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = Settings.TracerThickness

    local healthBar = {
        Outline = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Text = Drawing.new("Text"),
    }

    healthBar.Outline.Filled = false
    healthBar.Outline.Thickness = 1
    healthBar.Outline.Color = Color3.new(0, 0, 0)
    healthBar.Fill.Filled = true
    healthBar.Text.Center = true
    healthBar.Text.Outline = true
    healthBar.Text.Size = Settings.TextSize

    local info = {
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
    }

    for _, t in pairs(info) do
        t.Visible = false
        t.Center = true
        t.Size = Settings.TextSize
        t.Outline = true
        t.Font = 2
    end

    local skeleton = {
        Head = Drawing.new("Line"),
        UpperSpine = Drawing.new("Line"),
        LowerSpine = Drawing.new("Line"),
        LeftShoulder = Drawing.new("Line"),
        LeftUpperArm = Drawing.new("Line"),
        LeftLowerArm = Drawing.new("Line"),
        RightShoulder = Drawing.new("Line"),
        RightUpperArm = Drawing.new("Line"),
        RightLowerArm = Drawing.new("Line"),
        LeftHip = Drawing.new("Line"),
        LeftUpperLeg = Drawing.new("Line"),
        LeftLowerLeg = Drawing.new("Line"),
        RightHip = Drawing.new("Line"),
        RightUpperLeg = Drawing.new("Line"),
        RightLowerLeg = Drawing.new("Line"),
    }

    for _, line in pairs(skeleton) do
        line.Visible = false
        line.Thickness = Settings.SkeletonThickness
        line.Color = Color3.new(1, 1, 1)
    end

    local highlight = Instance.new("Highlight")
    highlight.FillColor = Settings.ChamsFillColor
    highlight.OutlineColor = Settings.ChamsOutlineColor
    highlight.FillTransparency = Settings.ChamsFillTransparency
    highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false

    Highlights[player] = highlight
    Drawings.Skeleton[player] = skeleton
    Drawings.ESP[player] = {
        Box = box,
        Tracer = tracer,
        HealthBar = healthBar,
        Info = info,
    }
end

local function RemoveESP(player)
    local esp = Drawings.ESP[player]
    if esp then
        for _, v in pairs(esp.Box) do v:Remove() end
        esp.Tracer:Remove()
        for _, v in pairs(esp.HealthBar) do v:Remove() end
        for _, v in pairs(esp.Info) do v:Remove() end
        Drawings.ESP[player] = nil
    end

    local skeleton = Drawings.Skeleton[player]
    if skeleton then
        for _, v in pairs(skeleton) do v:Remove() end
        Drawings.Skeleton[player] = nil
    end

    local hl = Highlights[player]
    if hl then
        hl:Destroy()
        Highlights[player] = nil
    end
end

local function UpdateESP(player)
    local esp = Drawings.ESP[player]
    local skeleton = Drawings.Skeleton[player]
    if not esp then return end

    if not Settings.Enabled then
        HideAll(esp, skeleton)
        return
    end

    if Settings.TeamCheck and player.Team == LocalPlayer.Team and not Settings.ShowTeam then
        HideAll(esp, skeleton)
        if Highlights[player] then Highlights[player].Enabled = false end
        return
    end

    local character = player.Character
    if not character then
        HideAll(esp, skeleton)
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid or humanoid.Health <= 0 then
        HideAll(esp, skeleton)
        return
    end

    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude

    if not onScreen or distance > Settings.MaxDistance then
        HideAll(esp, skeleton)
        return
    end

    local color = GetPlayerColor(player)
    local size = character:GetExtentsSize()
    local cf = rootPart.CFrame

    local top = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y/2, 0)).Position)
    local bottom = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y/2, 0)).Position)

    local screenSize = bottom.Y - top.Y
    local boxWidth = screenSize * 0.65
    local boxPos = Vector2.new(top.X - boxWidth/2, top.Y)
    local boxSize = Vector2.new(boxWidth, screenSize)

    for _, v in pairs(esp.Box) do v.Visible = false end

    if Settings.BoxESP then
        if Settings.BoxStyle == "Corner" then
            local c = boxWidth * 0.22

            esp.Box.TopLeft.From = boxPos
            esp.Box.TopLeft.To = boxPos + Vector2.new(c, 0)
            esp.Box.TopLeft.Visible = true

            esp.Box.TopRight.From = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.TopRight.To = boxPos + Vector2.new(boxSize.X - c, 0)
            esp.Box.TopRight.Visible = true

            esp.Box.BottomLeft.From = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.BottomLeft.To = boxPos + Vector2.new(c, boxSize.Y)
            esp.Box.BottomLeft.Visible = true

            esp.Box.BottomRight.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.BottomRight.To = boxPos + Vector2.new(boxSize.X - c, boxSize.Y)
            esp.Box.BottomRight.Visible = true

            esp.Box.Left.From = boxPos
            esp.Box.Left.To = boxPos + Vector2.new(0, c)
            esp.Box.Left.Visible = true

            esp.Box.Right.From = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPos + Vector2.new(boxSize.X, c)
            esp.Box.Right.Visible = true

            esp.Box.Top.From = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.Top.To = boxPos + Vector2.new(0, boxSize.Y - c)
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y - c)
            esp.Box.Bottom.Visible = true

        elseif Settings.BoxStyle == "Full" then
            esp.Box.Left.From = boxPos
            esp.Box.Left.To = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.Left.Visible = true

            esp.Box.Right.From = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Right.Visible = true

            esp.Box.Top.From = boxPos
            esp.Box.Top.To = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.Visible = true

        elseif Settings.BoxStyle == "ThreeD" then
            local function wp(offset)
                local p, vis = Camera:WorldToViewportPoint((cf * offset).Position)
                return Vector2.new(p.X, p.Y), vis and p.Z > 0
            end

            local tl, v1 = wp(CFrame.new(-size.X/2, size.Y/2, -size.Z/2))
            local tr, v2 = wp(CFrame.new(size.X/2, size.Y/2, -size.Z/2))
            local bl, v3 = wp(CFrame.new(-size.X/2, -size.Y/2, -size.Z/2))
            local br, v4 = wp(CFrame.new(size.X/2, -size.Y/2, -size.Z/2))
            local tlb, v5 = wp(CFrame.new(-size.X/2, size.Y/2, size.Z/2))
            local trb, v6 = wp(CFrame.new(size.X/2, size.Y/2, size.Z/2))
            local blb, v7 = wp(CFrame.new(-size.X/2, -size.Y/2, size.Z/2))
            local brb, v8 = wp(CFrame.new(size.X/2, -size.Y/2, size.Z/2))

            if v1 and v2 and v3 and v4 and v5 and v6 and v7 and v8 then
                local function set(line, a, b)
                    line.From = a
                    line.To = b
                    line.Visible = true
                end

                set(esp.Box.TopLeft, tl, tr)
                set(esp.Box.TopRight, tr, br)
                set(esp.Box.BottomLeft, bl, br)
                set(esp.Box.BottomRight, tl, bl)

                set(esp.Box.Left, tlb, trb)
                set(esp.Box.Right, trb, brb)
                set(esp.Box.Top, blb, brb)
                set(esp.Box.Bottom, tlb, blb)

                set(esp.Box.C1, tl, tlb)
                set(esp.Box.C2, tr, trb)
                set(esp.Box.C3, bl, blb)
                set(esp.Box.C4, br, brb)
            end
        end

        for _, v in pairs(esp.Box) do
            if v.Visible then
                v.Color = color
                v.Thickness = Settings.BoxThickness
            end
        end
    end

    if Settings.TracerESP then
        esp.Tracer.From = GetTracerOrigin()
        esp.Tracer.To = Vector2.new(pos.X, pos.Y)
        esp.Tracer.Color = color
        esp.Tracer.Thickness = Settings.TracerThickness
        esp.Tracer.Visible = true
    else
        esp.Tracer.Visible = false
    end

    if Settings.HealthESP then
        local hp = humanoid.Health
        local maxHp = humanoid.MaxHealth
        local percent = math.clamp(hp / maxHp, 0, 1)

        local barH = screenSize * 0.8
        local barW = 4
        local barPos = Vector2.new(boxPos.X - barW - 4, boxPos.Y + (screenSize - barH) / 2)

        esp.HealthBar.Outline.Size = Vector2.new(barW, barH)
        esp.HealthBar.Outline.Position = barPos
        esp.HealthBar.Outline.Visible = true

        esp.HealthBar.Fill.Size = Vector2.new(barW - 2, barH * percent)
        esp.HealthBar.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barH * (1 - percent))
        esp.HealthBar.Fill.Color = Color3.fromRGB(255 * (1 - percent), 255 * percent, 40)
        esp.HealthBar.Fill.Visible = true

        if Settings.HealthStyle == "Text" or Settings.HealthStyle == "Both" then
            esp.HealthBar.Text.Text = math.floor(hp)
            esp.HealthBar.Text.Position = Vector2.new(barPos.X - 10, barPos.Y + barH / 2)
            esp.HealthBar.Text.Color = Color3.new(1, 1, 1)
            esp.HealthBar.Text.Visible = true
        else
            esp.HealthBar.Text.Visible = false
        end
    else
        for _, v in pairs(esp.HealthBar) do v.Visible = false end
    end

    if Settings.NameESP then
        local nameText = player.DisplayName
        if Settings.ShowDistance then
            nameText = nameText .. " [" .. math.floor(distance) .. "m]"
        end
        esp.Info.Name.Text = nameText
        esp.Info.Name.Position = Vector2.new(boxPos.X + boxWidth / 2, boxPos.Y - 18)
        esp.Info.Name.Color = color
        esp.Info.Name.Size = Settings.TextSize
        esp.Info.Name.Visible = true
    else
        esp.Info.Name.Visible = false
    end

    local hl = Highlights[player]
    if hl then
        if Settings.ChamsEnabled then
            hl.Parent = character
            hl.FillColor = Settings.ChamsFillColor
            hl.OutlineColor = Settings.ChamsOutlineColor
            hl.FillTransparency = Settings.ChamsFillTransparency
            hl.OutlineTransparency = Settings.ChamsOutlineTransparency
            hl.Enabled = true
        else
            hl.Enabled = false
        end
    end

    if Settings.SkeletonESP and skeleton then
        local function getPart(name1, name2)
            return character:FindFirstChild(name1) or character:FindFirstChild(name2)
        end

        local function bone(fromPart, toPart, line)
            if not (fromPart and toPart) then
                line.Visible = false
                return
            end

            local a, va = Camera:WorldToViewportPoint(fromPart.Position)
            local b, vb = Camera:WorldToViewportPoint(toPart.Position)

            if va and vb and a.Z > 0 and b.Z > 0 then
                line.From = Vector2.new(a.X, a.Y)
                line.To = Vector2.new(b.X, b.Y)
                line.Color = color
                line.Thickness = Settings.SkeletonThickness
                line.Visible = true
            else
                line.Visible = false
            end
        end

        local head      = getPart("Head", "Head")
        local upper     = getPart("UpperTorso", "Torso")
        local lower     = getPart("LowerTorso", "Torso")

        local lUpperArm = getPart("LeftUpperArm", "Left Arm")
        local lLowerArm = getPart("LeftLowerArm", "Left Arm")
        local rUpperArm = getPart("RightUpperArm", "Right Arm")
        local rLowerArm = getPart("RightLowerArm", "Right Arm")

        local lUpperLeg = getPart("LeftUpperLeg", "Left Leg")
        local lLowerLeg = getPart("LeftLowerLeg", "Left Leg")
        local rUpperLeg = getPart("RightUpperLeg", "Right Leg")
        local rLowerLeg = getPart("RightLowerLeg", "Right Leg")

        bone(head, upper, skeleton.Head)
        bone(upper, lower, skeleton.UpperSpine)

        bone(upper, lUpperArm, skeleton.LeftShoulder)
        bone(lUpperArm, lLowerArm, skeleton.LeftUpperArm)
        bone(upper, rUpperArm, skeleton.RightShoulder)
        bone(rUpperArm, rLowerArm, skeleton.RightUpperArm)

        bone(lower, lUpperLeg, skeleton.LeftHip)
        bone(lUpperLeg, lLowerLeg, skeleton.LeftUpperLeg)
        bone(lower, rUpperLeg, skeleton.RightHip)
        bone(rUpperLeg, rLowerLeg, skeleton.RightUpperLeg)
    else
        if skeleton then
            for _, v in pairs(skeleton) do
                v.Visible = false
            end
        end
    end
end

function ESP:Init()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateESP(player)
        end
    end

    Players.PlayerAdded:Connect(CreateESP)
    Players.PlayerRemoving:Connect(RemoveESP)

    local last = 0
    RunService.RenderStepped:Connect(function()
        if not Settings.Enabled then return end
        local now = tick()
        if now - last < Settings.RefreshRate then return end
        last = now

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not Drawings.ESP[player] then
                    CreateESP(player)
                end
                UpdateESP(player)
            end
        end
    end)
end

function ESP:SetEnabled(state)
    Settings.Enabled = state
    if not state then
        for _, player in ipairs(Players:GetPlayers()) do
            HideAll(Drawings.ESP[player], Drawings.Skeleton[player])
            if Highlights[player] then Highlights[player].Enabled = false end
        end
    end
end

function ESP:Toggle()
    self:SetEnabled(not Settings.Enabled)
end

function ESP:GetSettings()
    return Settings
end

function ESP:GetColors()
    return Colors
end

function ESP:Unload()
    Settings.Enabled = false
    for _, player in ipairs(Players:GetPlayers()) do
        RemoveESP(player)
    end
    Drawings.ESP = {}
    Drawings.Skeleton = {}
    Highlights = {}
end

ESP:Init()

return ESP
