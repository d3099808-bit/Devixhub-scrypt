--[[
    Devix hub UPDATE #1 | Monochrome Cyber-Minimalist UI (Full Script)
    Upgrades:
    - Real AI Reasoning Brain for Crystal Aura (State Machine + Cell Memory -> 0 Obsidian Spam)
    - Live AI Thought Status in Watermark HUD
    - SafeWorldToScreen (0 boolean.Z errors)
    - Fixed ScreenGui Parent + Jumpable WalkSpeed + SkinChanger + Resource Pack Painter
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local Config = {
    MenuOpen = true,
    ToggleKey = Enum.KeyCode.RightShift,
    Plan = "UPDATE #1",

    -- HUD & Visuals
    Watermark = true,
    TargetESP = true,
    TargetRing = true,
    HitSparks = true,
    CrystalPreview = true,
    SmartFPSBoost = false,

    -- Atmosphere & Colors
    RichColors = false,
    Saturation = 0.45,
    CustomSky = false,
    SkyPreset = "Galaxy",

    -- Removals
    RemovalsEnabled = false,

    -- Movement
    SpeedEnabled = false,
    WalkSpeed = 24,
    FlyEnabled = false,
    FlySpeed = 42,

    -- Combat: AttackAura
    AttackAura = false,
    CameraAimLock = false,
    OnlyCrits = true,
    AutoJumpCrits = true,
    CritCooldown = 0.60,
    AuraRange = 16,
    TargetFollow = false,
    FollowDistance = 4.5,

    -- Combat: AI Reasoning Crystal Aura
    CrystalAura = false,
    CrystalRange = 22,
    CrystalDelay = 0.05,
    AutoHitPop = true,
    HitPopPower = 50,
    AutoMineUnder = true,
    CombatStrafe = true,
    ObsidianSlot = 2,
    CrystalSlot = 3,

    -- Combat: Upback & Manual Crystal
    FastCrystal = false,
    CrystalsPerCycle = 4,
    SuperUpback = false,
    KnockbackPower = 45,
    UpbackBlocks = 1.0,
    HitRange = 14,

    -- SkinChanger
    ActiveSkin = "None",

    -- Resource Pack Painter
    BrushColor = Color3.fromHex("#FFFFFF"),
}

local Connections = {}
local Unloaded = false
local CustomPackInstances = {}
local SavedLighting = {}
local CurrentTargetPlayer = nil
local AI_ThoughtText = "IDLE"

local Keybinds = {}
local ListeningBindTarget = nil

-- Безопасная проекция 3D -> 2D (исключает ошибку boolean.Z)
local function SafeWorldToScreen(worldPos)
    if typeof(worldPos) ~= "Vector3" or not Camera then
        return nil, false
    end
    local ok, screenPos, onScreen = pcall(function()
        return Camera:WorldToViewportPoint(worldPos)
    end)
    if ok and typeof(screenPos) == "Vector3" and onScreen == true and screenPos.Z > 0 then
        return screenPos, true
    end
    return nil, false
end

-- ==========================================
-- КЭШ ИГРОВЫХ REMOTEEVENT
-- ==========================================
local CachedRemotes = { Place = {}, Break = {}, Attack = {} }

local function RegisterRemote(rem)
    if not rem:IsA("RemoteEvent") then return end
    local n = string.lower(rem.Name)
    if string.find(n, "place") or string.find(n, "build") or string.find(n, "block") or string.find(n, "crystal") then
        table.insert(CachedRemotes.Place, rem)
    end
    if string.find(n, "mine") or string.find(n, "break") or string.find(n, "dig") or string.find(n, "destroy") then
        table.insert(CachedRemotes.Break, rem)
    end
    if string.find(n, "attack") or string.find(n, "hit") or string.find(n, "damage") or string.find(n, "swing") or string.find(n, "crystal") then
        table.insert(CachedRemotes.Attack, rem)
    end
end

task.spawn(function()
    for _, rem in ipairs(ReplicatedStorage:GetDescendants()) do
        RegisterRemote(rem)
    end
    table.insert(Connections, ReplicatedStorage.DescendantAdded:Connect(RegisterRemote))
end)

-- Контейнер GUI
local function GetGuiParent()
    if typeof(gethui) == "function" then return gethui() end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local ParentGui = GetGuiParent()
if ParentGui:FindFirstChild("DevixHub_UI") then
    ParentGui:FindFirstChild("DevixHub_UI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DevixHub_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentGui

-- Палитра (#030303 / #080808 / #111111 / #262626 / #FFFFFF)
local Theme = {
    Bg = Color3.fromHex("#030303"),
    Header = Color3.fromHex("#080808"),
    Sidebar = Color3.fromHex("#060606"),
    Card = Color3.fromHex("#111111"),
    CardHover = Color3.fromHex("#1A1A1A"),
    Border = Color3.fromHex("#262626"),
    BorderActive = Color3.fromHex("#525252"),
    Text = Color3.fromHex("#FFFFFF"),
    SubText = Color3.fromHex("#8A8A8A"),
    Accent = Color3.fromHex("#FFFFFF"),
    AccentOff = Color3.fromHex("#1E1E1E"),
}

local FontMain = Enum.Font.GothamBold
local FontBody = Enum.Font.GothamMedium
local FontMono = Enum.Font.RobotoMono

local function Tween(obj, props, duration)
    local t = TweenService:Create(obj, TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function AddCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
    return c
end

local function AddStroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

-- ==========================================
-- 1. WATERMARK HUD (с отображением мыслей ИИ)
-- ==========================================
local WatermarkFrame = Instance.new("Frame")
WatermarkFrame.Name = "Watermark"
WatermarkFrame.Size = UDim2.new(0, 380, 0, 30)
WatermarkFrame.Position = UDim2.new(0, 16, 0, 16)
WatermarkFrame.BackgroundColor3 = Theme.Bg
WatermarkFrame.BackgroundTransparency = 0.04
WatermarkFrame.Parent = ScreenGui
AddCorner(WatermarkFrame, 8)
AddStroke(WatermarkFrame, Theme.BorderActive, 1.2)

local WatermarkDot = Instance.new("Frame")
WatermarkDot.Size = UDim2.new(0, 6, 0, 6)
WatermarkDot.Position = UDim2.new(0, 12, 0.5, -3)
WatermarkDot.BackgroundColor3 = Theme.Accent
WatermarkDot.BorderSizePixel = 0
WatermarkDot.Parent = WatermarkFrame
AddCorner(WatermarkDot, 3)

local WatermarkLabel = Instance.new("TextLabel")
WatermarkLabel.Size = UDim2.new(1, -28, 1, 0)
WatermarkLabel.Position = UDim2.new(0, 24, 0, 0)
WatermarkLabel.BackgroundTransparency = 1
WatermarkLabel.Font = FontMono
WatermarkLabel.TextSize = 12
WatermarkLabel.TextColor3 = Theme.Text
WatermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
WatermarkLabel.Text = "DEVIX HUB UPDATE #1  |  0 MS  |  AI: IDLE"
WatermarkLabel.Parent = WatermarkFrame

-- ==========================================
-- 2. TARGET ESP BOX
-- ==========================================
local TargetBox = Instance.new("Frame")
TargetBox.Name = "TargetESPBox"
TargetBox.BackgroundTransparency = 1
TargetBox.Visible = false
TargetBox.Parent = ScreenGui
AddStroke(TargetBox, Theme.Accent, 1.5)

local TargetInfoTag = Instance.new("TextLabel")
TargetInfoTag.Size = UDim2.new(0, 180, 0, 20)
TargetInfoTag.Position = UDim2.new(0.5, -90, 0, -26)
TargetInfoTag.BackgroundColor3 = Theme.Bg
TargetInfoTag.BackgroundTransparency = 0.1
TargetInfoTag.Font = FontMono
TargetInfoTag.TextSize = 11
TargetInfoTag.TextColor3 = Theme.Text
TargetInfoTag.Text = ""
TargetInfoTag.Parent = TargetBox
AddCorner(TargetInfoTag, 5)
AddStroke(TargetInfoTag, Theme.BorderActive, 1)

-- ==========================================
-- 3. ВИЗУАЛЬНЫЕ ЭФФЕКТЫ
-- ==========================================
local VisualFolder = Instance.new("Folder")
VisualFolder.Name = "DevixVisualFX"
VisualFolder.Parent = Workspace

local TargetRingPart = Instance.new("Part")
TargetRingPart.Name = "DevixTargetRing"
TargetRingPart.Shape = Enum.PartType.Cylinder
TargetRingPart.Size = Vector3.new(0.08, 4.4, 4.4)
TargetRingPart.Anchored = true
TargetRingPart.CanCollide = false
TargetRingPart.CanQuery = false
TargetRingPart.Material = Enum.Material.Neon
TargetRingPart.Color = Color3.fromHex("#FFFFFF")
TargetRingPart.Transparency = 1
TargetRingPart.Parent = VisualFolder

local TargetInnerRing = Instance.new("Part")
TargetInnerRing.Name = "DevixTargetInnerRing"
TargetInnerRing.Shape = Enum.PartType.Cylinder
TargetInnerRing.Size = Vector3.new(0.1, 4.0, 4.0)
TargetInnerRing.Anchored = true
TargetInnerRing.CanCollide = false
TargetInnerRing.CanQuery = false
TargetInnerRing.Material = Enum.Material.SmoothPlastic
TargetInnerRing.Color = Color3.fromHex("#030303")
TargetInnerRing.Transparency = 1
TargetInnerRing.Parent = VisualFolder

local GhostSurfaceRing = Instance.new("Part")
GhostSurfaceRing.Name = "DevixGhostRing"
GhostSurfaceRing.Size = Vector3.new(3.6, 0.05, 3.6)
GhostSurfaceRing.Anchored = true
GhostSurfaceRing.CanCollide = false
GhostSurfaceRing.CanQuery = false
GhostSurfaceRing.Transparency = 1
GhostSurfaceRing.Parent = VisualFolder

local GhostSurfaceOutline = Instance.new("SelectionBox")
GhostSurfaceOutline.Adornee = GhostSurfaceRing
GhostSurfaceOutline.Color3 = Color3.fromHex("#FFFFFF")
GhostSurfaceOutline.LineThickness = 0.03
GhostSurfaceOutline.SurfaceTransparency = 1
GhostSurfaceOutline.Visible = false
GhostSurfaceOutline.Parent = GhostSurfaceRing

local function HideGhostPrediction()
    GhostSurfaceOutline.Visible = false
end

local function UpdateGhostPrediction(surfacePos, readyForCrystal)
    if not Config.CrystalPreview or not Config.CrystalAura or Unloaded then
        HideGhostPrediction()
        return
    end
    GhostSurfaceRing.CFrame = CFrame.new(surfacePos + Vector3.new(0, 0.03, 0))
    GhostSurfaceOutline.Color3 = readyForCrystal and Color3.fromHex("#FFFFFF") or Color3.fromHex("#7A7A7A")
    GhostSurfaceOutline.Visible = true
end

local function SpawnHitSparks(position, isCrit)
    if not Config.HitSparks or Unloaded then return end
    local count = isCrit and 8 or 4
    for i = 1, count do
        local spark = Instance.new("Part")
        spark.Size = isCrit and Vector3.new(0.18, 0.18, 0.18) or Vector3.new(0.14, 0.14, 0.14)
        spark.Position = position
        spark.Anchored = true
        spark.CanCollide = false
        spark.CanQuery = false
        spark.Material = Enum.Material.Neon
        spark.Color = (i % 2 == 0) and Color3.fromHex("#FFFFFF") or Color3.fromHex("#7A7A7A")
        spark.Transparency = 0.05
        spark.Parent = VisualFolder

        local dir = Vector3.new(math.random(-10, 10) / 10, math.random(2, 14) / 10, math.random(-10, 10) / 10).Unit * math.random(2, 5)
        local t = TweenService:Create(spark, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = position + dir,
            Size = Vector3.new(0.02, 0.02, 0.02),
            Transparency = 1
        })
        t:Play()
        t.Completed:Connect(function() spark:Destroy() end)
    end
end

-- ==========================================
-- 4. ГЛАВНОЕ ОКНО (DEVIX HUB UPDATE #1)
-- ==========================================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 640, 0, 460)
MainFrame.Position = UDim2.new(0.5, -320, 0.5, -230)
MainFrame.BackgroundColor3 = Theme.Bg
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
AddCorner(MainFrame, 12)
AddStroke(MainFrame, Theme.BorderActive, 1.2)

local Topbar = Instance.new("Frame")
Topbar.Size = UDim2.new(1, 0, 0, 46)
Topbar.BackgroundColor3 = Theme.Header
Topbar.BorderSizePixel = 0
Topbar.Parent = MainFrame

local TopDivider = Instance.new("Frame")
TopDivider.Size = UDim2.new(1, 0, 0, 1)
TopDivider.Position = UDim2.new(0, 0, 1, -1)
TopDivider.BackgroundColor3 = Theme.Border
TopDivider.BorderSizePixel = 0
TopDivider.Parent = Topbar

local LogoIcon = Instance.new("TextLabel")
LogoIcon.Size = UDim2.new(0, 28, 0, 24)
LogoIcon.Position = UDim2.new(0, 14, 0.5, -12)
LogoIcon.BackgroundColor3 = Theme.Accent
LogoIcon.Font = FontMono
LogoIcon.TextSize = 12
LogoIcon.TextColor3 = Theme.Bg
LogoIcon.Text = "D/"
LogoIcon.Parent = Topbar
AddCorner(LogoIcon, 6)

local BrandTitle = Instance.new("TextLabel")
BrandTitle.Size = UDim2.new(0, 260, 1, 0)
BrandTitle.Position = UDim2.new(0, 52, 0, 0)
BrandTitle.BackgroundTransparency = 1
BrandTitle.Font = FontMain
BrandTitle.TextSize = 14
BrandTitle.TextColor3 = Theme.Text
BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
BrandTitle.Text = "DEVIX HUB UPDATE #1"
BrandTitle.Parent = Topbar

local PlanBadge = Instance.new("TextLabel")
PlanBadge.Size = UDim2.new(0, 58, 0, 20)
PlanBadge.Position = UDim2.new(0, 218, 0.5, -10)
PlanBadge.BackgroundColor3 = Theme.Card
PlanBadge.Font = FontMono
PlanBadge.TextSize = 10
PlanBadge.TextColor3 = Theme.Text
PlanBadge.Text = "UPD #1"
PlanBadge.Parent = Topbar
AddCorner(PlanBadge, 5)
AddStroke(PlanBadge, Theme.BorderActive, 1)

local KeyHint = Instance.new("TextLabel")
KeyHint.Size = UDim2.new(0, 260, 1, 0)
KeyHint.Position = UDim2.new(1, -274, 0, 0)
KeyHint.BackgroundTransparency = 1
KeyHint.Font = FontMono
KeyHint.TextSize = 11
KeyHint.TextColor3 = Theme.SubText
KeyHint.TextXAlignment = Enum.TextXAlignment.Right
KeyHint.Text = "[MMB] BIND  |  [RSHIFT] UI"
KeyHint.Parent = Topbar

do
    local dragging, dragInput, dragStart, startPos
    Topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    Topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 156, 1, -46)
Sidebar.Position = UDim2.new(0, 0, 0, 46)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SideDivider = Instance.new("Frame")
SideDivider.Size = UDim2.new(0, 1, 1, 0)
SideDivider.Position = UDim2.new(1, -1, 0, 0)
SideDivider.BackgroundColor3 = Theme.Border
SideDivider.BorderSizePixel = 0
SideDivider.Parent = Sidebar

local TabList = Instance.new("Frame")
TabList.Size = UDim2.new(1, -16, 1, -20)
TabList.Position = UDim2.new(0, 8, 0, 12)
TabList.BackgroundTransparency = 1
TabList.Parent = Sidebar

local TabLayout = Instance.new("UIListLayout")
TabLayout.Padding = UDim.new(0, 6)
TabLayout.Parent = TabList

local ContentHolder = Instance.new("Frame")
ContentHolder.Size = UDim2.new(1, -174, 1, -60)
ContentHolder.Position = UDim2.new(0, 166, 0, 52)
ContentHolder.BackgroundTransparency = 1
ContentHolder.Parent = MainFrame

local Pages, TabButtons = {}, {}

local function SelectTab(tabName)
    for name, page in pairs(Pages) do page.Visible = (name == tabName) end
    for name, data in pairs(TabButtons) do
        if name == tabName then
            Tween(data.Btn, {BackgroundColor3 = Theme.Accent, TextColor3 = Theme.Bg}, 0.16)
            data.Bar.Visible = true
        else
            Tween(data.Btn, {BackgroundColor3 = Theme.Sidebar, TextColor3 = Theme.SubText}, 0.16)
            data.Bar.Visible = false
        end
    end
end

local function CreateTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Theme.Sidebar
    btn.Font = FontMain
    btn.TextSize = 12
    btn.TextColor3 = Theme.SubText
    btn.Text = name
    btn.AutoButtonColor = false
    btn.Parent = TabList
    AddCorner(btn, 7)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0, 16)
    bar.Position = UDim2.new(0, 4, 0.5, -8)
    bar.BackgroundColor3 = Theme.Bg
    bar.BorderSizePixel = 0
    bar.Visible = false
    bar.Parent = btn
    AddCorner(bar, 2)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Theme.BorderActive
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = ContentHolder

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent = page

    btn.MouseButton1Click:Connect(function() SelectTab(name) end)
    Pages[name] = page
    TabButtons[name] = {Btn = btn, Bar = bar}
    return page
end

local function CreateSectionLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -4, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Font = FontMono
    lbl.TextSize = 10
    lbl.TextColor3 = Theme.SubText
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = "— " .. string.upper(text)
    lbl.Parent = parent
end

local function CreateToggle(parent, title, subtitle, defaultState, callback)
    local card = Instance.new("TextButton")
    card.Size = UDim2.new(1, -4, 0, 50)
    card.BackgroundColor3 = Theme.Card
    card.Text = ""
    card.AutoButtonColor = false
    card.Parent = parent
    AddCorner(card, 8)
    local stroke = AddStroke(card, defaultState and Theme.BorderActive or Theme.Border, 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -135, 0, 18)
    lbl.Position = UDim2.new(0, 12, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Font = FontMain
    lbl.TextSize = 13
    lbl.TextColor3 = Theme.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = title
    lbl.Parent = card

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -64, 0, 15)
    sub.Position = UDim2.new(0, 12, 0, 26)
    sub.BackgroundTransparency = 1
    sub.Font = FontBody
    sub.TextSize = 11
    sub.TextColor3 = Theme.SubText
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = subtitle
    sub.Parent = card

    local bindBadge = Instance.new("TextLabel")
    bindBadge.Size = UDim2.new(0, 68, 0, 18)
    bindBadge.Position = UDim2.new(1, -124, 0, 8)
    bindBadge.BackgroundColor3 = Theme.Bg
    bindBadge.Font = FontMono
    bindBadge.TextSize = 9
    bindBadge.TextColor3 = Theme.SubText
    bindBadge.Text = "[NONE]"
    bindBadge.Parent = card
    AddCorner(bindBadge, 5)
    AddStroke(bindBadge, Theme.Border, 1)

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 40, 0, 22)
    switch.Position = UDim2.new(1, -50, 0.5, -11)
    switch.BackgroundColor3 = defaultState and Theme.Accent or Theme.AccentOff
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Parent = card
    AddCorner(switch, 11)
    AddStroke(switch, Theme.BorderActive, 1)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = defaultState and Theme.Bg or Theme.Text
    knob.Parent = switch
    AddCorner(knob, 8)

    local state, boundKey = defaultState, nil

    local function SetState(newState)
        if state == newState then return end
        state = newState
        stroke.Color = state and Theme.BorderActive or Theme.Border
        Tween(switch, {BackgroundColor3 = state and Theme.Accent or Theme.AccentOff}, 0.14)
        Tween(knob, {
            Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = state and Theme.Bg or Theme.Text
        }, 0.14)
        callback(state)
    end

    local function ToggleState() SetState(not state) end
    switch.MouseButton1Click:Connect(ToggleState)

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton3 then
            if ListeningBindTarget and ListeningBindTarget.Badge then
                ListeningBindTarget.Badge.Text = ListeningBindTarget.OldText
                ListeningBindTarget.Badge.TextColor3 = Theme.SubText
            end
            if boundKey then
                Keybinds[boundKey] = nil
                boundKey = nil
                bindBadge.Text = "[NONE]"
                bindBadge.TextColor3 = Theme.SubText
                ListeningBindTarget = nil
                return
            end
            ListeningBindTarget = {
                Badge = bindBadge,
                OldText = "[NONE]",
                OnBind = function(keyCode)
                    boundKey = keyCode
                    bindBadge.Text = "[" .. keyCode.Name .. "]"
                    bindBadge.TextColor3 = Theme.Text
                    Keybinds[keyCode] = { Toggle = ToggleState, Title = title }
                end
            }
            bindBadge.Text = "[KEY...]"
            bindBadge.TextColor3 = Theme.Text
        end
    end)

    return SetState
end

local function CreateSlider(parent, title, minVal, maxVal, defaultVal, isInteger, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -4, 0, 54)
    card.BackgroundColor3 = Theme.Card
    card.Parent = parent
    AddCorner(card, 8)
    AddStroke(card, Theme.Border, 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7, 0, 0, 18)
    lbl.Position = UDim2.new(0, 12, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Font = FontMain
    lbl.TextSize = 12
    lbl.TextColor3 = Theme.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = title
    lbl.Parent = card

    local valBox = Instance.new("TextLabel")
    valBox.Size = UDim2.new(0, 54, 0, 18)
    valBox.Position = UDim2.new(1, -66, 0, 8)
    valBox.BackgroundColor3 = Theme.Bg
    valBox.Font = FontMono
    valBox.TextSize = 11
    valBox.TextColor3 = Theme.Text
    valBox.Text = tostring(defaultVal)
    valBox.Parent = card
    AddCorner(valBox, 5)
    AddStroke(valBox, Theme.Border, 1)

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, -24, 0, 6)
    bar.Position = UDim2.new(0, 12, 0, 36)
    bar.BackgroundColor3 = Theme.AccentOff
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.Parent = card
    AddCorner(bar, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.Parent = bar
    AddCorner(fill, 3)

    local dragging = false
    local function UpdateSlider(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local raw = minVal + (maxVal - minVal) * rel
        local value = isInteger and math.floor(raw + 0.5) or (math.floor(raw * 100) / 100)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valBox.Text = tostring(value)
        callback(value)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; UpdateSlider(input) end
    end)
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider(input) end
    end))
    table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end

local function CreateButton(parent, title, subtitle, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -4, 0, 50)
    btn.BackgroundColor3 = Theme.Card
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = parent
    AddCorner(btn, 8)
    AddStroke(btn, Theme.Border, 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 0, 18)
    lbl.Position = UDim2.new(0, 12, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Font = FontMain
    lbl.TextSize = 13
    lbl.TextColor3 = Theme.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = title
    lbl.Parent = btn

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -24, 0, 15)
    sub.Position = UDim2.new(0, 12, 0, 26)
    sub.BackgroundTransparency = 1
    sub.Font = FontBody
    sub.TextSize = 11
    sub.TextColor3 = Theme.SubText
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = subtitle
    sub.Parent = btn

    btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = Theme.CardHover}, 0.12) end)
    btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = Theme.Card}, 0.12) end)
    btn.MouseButton1Click:Connect(callback)
    return btn, lbl, sub
end

-- ==========================================
-- ЛОГИКА: SKINCHANGER
-- ==========================================
local SwordSkins = {
    { Name = "Bloodfang", Rarity = "RELIC! (2%)", AccentHex = "#FF2A2A", BladeColor = Color3.fromHex("#9E0B0B"), EdgeColor = Color3.fromHex("#FF3B3B"), Neon = true },
    { Name = "Void Edge", Rarity = "EPIC (7%)", AccentHex = "#A855F7", BladeColor = Color3.fromHex("#4C1D95"), EdgeColor = Color3.fromHex("#38BDF8"), Neon = true },
    { Name = "Frost Sword", Rarity = "RARE (19%)", AccentHex = "#38BDF8", BladeColor = Color3.fromHex("#7DD3FC"), EdgeColor = Color3.fromHex("#E0F2FE"), Neon = false },
    { Name = "Ember Blade", Rarity = "UNCOMMON (21%)", AccentHex = "#FB923C", BladeColor = Color3.fromHex("#EA580C"), EdgeColor = Color3.fromHex("#FDE047"), Neon = true },
    { Name = "Heavy Mace", Rarity = "LEGENDARY (5%)", AccentHex = "#EAB308", BladeColor = Color3.fromHex("#9CA3AF"), EdgeColor = Color3.fromHex("#F3F4F6"), Neon = false },
}

local ActiveSkinData = nil
local BodyPartNames = {
    Head=true, Torso=true, UpperTorso=true, LowerTorso=true, HumanoidRootPart=true,
    ["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true,
    LeftUpperArm=true, LeftLowerArm=true, LeftHand=true, RightUpperArm=true, RightLowerArm=true, RightHand=true,
    LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true, RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
}

local function ApplySkinTo3DPart(part, skin)
    if not part or not part:IsA("BasePart") then return end
    part.Color = skin.EdgeColor
    part.Material = skin.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
    if part:IsA("MeshPart") then part.TextureID = "" end
    local sm = part:FindFirstChildOfClass("SpecialMesh")
    if sm then sm.TextureId = ""; sm.VertexColor = Vector3.new(skin.EdgeColor.R, skin.EdgeColor.G, skin.EdgeColor.B) end
    local sel = part:FindFirstChild("DevixSkinBox") or Instance.new("SelectionBox")
    sel.Name = "DevixSkinBox"
    sel.Adornee = part
    sel.LineThickness = 0.02
    sel.SurfaceTransparency = 0.65
    sel.Color3 = skin.EdgeColor
    sel.SurfaceColor3 = skin.BladeColor
    sel.Parent = part
end

local function ApplySwordSkinToCharacter()
    if not ActiveSkinData or Unloaded then return end
    local char = LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") or (child:IsA("Model") and child.Name ~= "DevixVisualFX") then
                for _, part in ipairs(child:GetDescendants()) do
                    if part:IsA("BasePart") then ApplySkinTo3DPart(part, ActiveSkinData) end
                end
            elseif child:IsA("BasePart") and not BodyPartNames[child.Name] then
                ApplySkinTo3DPart(child, ActiveSkinData)
            end
        end
    end
    for _, desc in ipairs(Camera:GetDescendants()) do
        if desc:IsA("BasePart") and not BodyPartNames[desc.Name] then
            local n = string.lower(desc.Name)
            if not string.find(n, "arm") and not string.find(n, "hand") then
                ApplySkinTo3DPart(desc, ActiveSkinData)
            end
        end
    end
end

local function ClearSwordSkin()
    ActiveSkinData = nil
    local char = LocalPlayer.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do if d.Name == "DevixSkinBox" then d:Destroy() end end
    end
    for _, d in ipairs(Camera:GetDescendants()) do if d.Name == "DevixSkinBox" then d:Destroy() end end
end

-- ==========================================
-- ЛОГИКА: ПЛАВНЫЙ FLY
-- ==========================================
local FlyAttachment, FlyLinearVel = nil, nil

local function StopSmoothFly()
    if FlyLinearVel then FlyLinearVel:Destroy(); FlyLinearVel = nil end
    if FlyAttachment then FlyAttachment:Destroy(); FlyAttachment = nil end
end

local function UpdateSmoothFly()
    if not Config.FlyEnabled or Unloaded then StopSmoothFly(); return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if not FlyAttachment or FlyAttachment.Parent ~= hrp then
        if FlyAttachment then FlyAttachment:Destroy() end
        FlyAttachment = Instance.new("Attachment", hrp)
    end
    if not FlyLinearVel or FlyLinearVel.Parent ~= hrp then
        if FlyLinearVel then FlyLinearVel:Destroy() end
        FlyLinearVel = Instance.new("LinearVelocity")
        FlyLinearVel.Attachment0 = FlyAttachment
        FlyLinearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        FlyLinearVel.MaxForce = math.huge
        FlyLinearVel.RelativeTo = Enum.ActuatorRelativeTo.World
        FlyLinearVel.Parent = hrp
    end

    local moveDir = Vector3.zero
    local camCF = Camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end

    FlyLinearVel.VectorVelocity = moveDir.Magnitude > 0 and (moveDir.Unit * Config.FlySpeed) or Vector3.new(0, 0.01, 0)
end

-- ==========================================
-- ЛОГИКА: ПОИСК ЦЕЛИ & ATTACKAURA
-- ==========================================
local LastAuraHit, LastCritJump = 0, 0

local function GetNearestEnemyInAura(maxRange)
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil, math.huge end

    local bestTarget, bestDist = nil, maxRange
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local dist = (hrp.Position - myHrp.Position).Magnitude
                if dist <= bestDist then
                    bestDist = dist
                    bestTarget = plr
                end
            end
        end
    end
    return bestTarget, bestDist
end

local function ProcessAttackAura(dt)
    if not Config.AttackAura or Unloaded then return end
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not myHum or myHum.Health <= 0 then return end

    local targetPlr = GetNearestEnemyInAura(Config.AuraRange)
    if not targetPlr or not targetPlr.Character then return end
    local targetHrp = targetPlr.Character:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end

    local predictedPos = targetHrp.Position + (targetHrp.AssemblyLinearVelocity * 0.055)
    local flatTargetPos = Vector3.new(predictedPos.X, myHrp.Position.Y, predictedPos.Z)
    if (flatTargetPos - myHrp.Position).Magnitude > 0.1 then
        myHrp.CFrame = myHrp.CFrame:Lerp(CFrame.lookAt(myHrp.Position, flatTargetPos), math.clamp(dt * 18, 0, 1))
    end
    if Config.CameraAimLock then
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, predictedPos), math.clamp(dt * 24, 0, 1))
    end
    if Config.TargetFollow and not Config.FlyEnabled then
        local dir = flatTargetPos - myHrp.Position
        if dir.Magnitude > Config.FollowDistance then myHum:Move(dir.Unit, false) end
    end

    local isGrounded = myHum.FloorMaterial ~= Enum.Material.Air
    local isFalling = (not isGrounded and myHrp.AssemblyLinearVelocity.Y < -2.0)

    if Config.OnlyCrits and Config.AutoJumpCrits and not Config.FlyEnabled and isGrounded and (tick() - LastCritJump) > 0.48 then
        LastCritJump = tick()
        myHum.Jump = true
    end

    if ((not Config.OnlyCrits) or isFalling or Config.FlyEnabled) and (tick() - LastAuraHit) >= Config.CritCooldown then
        LastAuraHit = tick()
        local tool = myChar:FindFirstChildOfClass("Tool")
        if tool then tool:Activate() end
        local sp, onScreen = SafeWorldToScreen(predictedPos)
        local cx = onScreen and sp.X or (Camera.ViewportSize.X / 2)
        local cy = onScreen and sp.Y or (Camera.ViewportSize.Y / 2)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.delay(0.02, function() VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1) end)
        SpawnHitSparks(predictedPos, true)
    end
end

-- ==========================================
-- ЛОГИКА: РАССУЖДАЮЩИЙ ИИ-МОЗГ CRYSTAL AURA (UPDATE #1)
-- ==========================================
local CrystalOverlapParams = OverlapParams.new()
CrystalOverlapParams.FilterType = Enum.RaycastFilterType.Exclude

local NumberKeyCodes = {
    [1]=Enum.KeyCode.One, [2]=Enum.KeyCode.Two, [3]=Enum.KeyCode.Three,
    [4]=Enum.KeyCode.Four, [5]=Enum.KeyCode.Five, [6]=Enum.KeyCode.Six,
    [7]=Enum.KeyCode.Seven, [8]=Enum.KeyCode.Eight, [9]=Enum.KeyCode.Nine,
}

local CurrentEquippedType = ""
local LastSlotSwitchTime = 0

local function EquipItemSmart(itemType, keywords, fallbackSlot)
    local char = LocalPlayer.Character
    if not char then return nil end

    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then
        local low = string.lower(currentTool.Name)
        for _, kw in ipairs(keywords) do
            if string.find(low, kw) then
                CurrentEquippedType = itemType
                return currentTool
            end
        end
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if backpack and hum then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local low = string.lower(item.Name)
                for _, kw in ipairs(keywords) do
                    if string.find(low, kw) then
                        hum:EquipTool(item)
                        CurrentEquippedType = itemType
                        return item
                    end
                end
            end
        end
    end

    if fallbackSlot and (CurrentEquippedType ~= itemType or (tick() - LastSlotSwitchTime) > 0.12) then
        LastSlotSwitchTime = tick()
        CurrentEquippedType = itemType
        local kc = NumberKeyCodes[fallbackSlot]
        if kc then
            VirtualInputManager:SendKeyEvent(true, kc, false, game)
            task.defer(function() VirtualInputManager:SendKeyEvent(false, kc, false, game) end)
        end
    end
    return nil
end

-- Умное распознавание обсидиана (по имени, родителю, материалу ИЛИ тёмно-фиолетовому цвету)
local function IsObsidianBlock(part)
    if not part or not part:IsA("BasePart") or not part.Anchored or not part.CanCollide then return false end
    local n = string.lower(part.Name)
    local pName = part.Parent and string.lower(part.Parent.Name) or ""
    if string.find(n, "obsidian") or string.find(n, "обсидиан") or string.find(n, "bedrock") or string.find(pName, "obsidian") then
        return true
    end
    if part.Material == Enum.Material.Basalt then return true end
    -- Проверка тёмного цвета обсидиана для воксельных блоков (~3-4 стада)
    if part.Size.X >= 2.5 and part.Size.X <= 4.5 and math.abs(part.Size.X - part.Size.Y) < 0.2 then
        local c = part.Color
        if c.R < 0.22 and c.G < 0.16 and c.B < 0.30 then
            return true
        end
    end
    return false
end

local function ClickScreenPoint(worldPos, mouseBtn)
    local sp, onScreen = SafeWorldToScreen(worldPos)
    if onScreen and sp then
        VirtualInputManager:SendMouseButtonEvent(sp.X, sp.Y, mouseBtn, true, game, 1)
        task.defer(function()
            VirtualInputManager:SendMouseButtonEvent(sp.X, sp.Y, mouseBtn, false, game, 1)
        end)
        return true
    end
    return false
end

-- Память и состояние ИИ-мозга
local AI_Brain = {
    State = "IDLE",
    -- Память поставленных клеток обсидиана: { Pos = Vector3, TopPos = Vector3, Time = number, CrystalAttempts = number }
    ActiveObsidian = nil,
    LastPopTime = 0,
    LastActionTime = 0,
    LastMineTime = 0,
    StrafeAngle = 0,
}

local function DetonateCrystal(crystalPart)
    if not crystalPart or not crystalPart.Parent then return false end
    AI_ThoughtText = "DETONATE"
    EquipItemSmart("sword", {"sword", "blade", "mace", "меч", "клинок"}, 1)

    local cd = crystalPart:FindFirstChildOfClass("ClickDetector")
        or (crystalPart.Parent and crystalPart.Parent:FindFirstChildWhichIsA("ClickDetector", true))
    if cd and typeof(fireclickdetector) == "function" then
        fireclickdetector(cd)
    end

    for _, rem in ipairs(CachedRemotes.Attack) do
        if rem and rem.Parent then
            pcall(function() rem:FireServer(crystalPart.Position, crystalPart) end)
        end
    end

    ClickScreenPoint(crystalPart.Position, 0)
    SpawnHitSparks(crystalPart.Position, true)
    return true
end

-- Мгновенный рефлекс ИИ: увидел спавн кристалла рядом с врагом -> взорвал за 0 мс!
table.insert(Connections, Workspace.DescendantAdded:Connect(function(desc)
    if not Config.CrystalAura or Unloaded then return end
    if not (desc:IsA("BasePart") or desc:IsA("Model")) then return end
    local n = string.lower(desc.Name)
    local pName = desc.Parent and string.lower(desc.Parent.Name) or ""
    if not (string.find(n, "crystal") or string.find(pName, "crystal")) then return end

    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetPlr = GetNearestEnemyInAura(Config.CrystalRange)
    local targetHrp = targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp or not targetHrp then return end

    task.defer(function()
        if not desc or not desc.Parent then return end
        local part = desc:IsA("BasePart") and desc or desc:FindFirstChildWhichIsA("BasePart")
        if not part then return end
        if (part.Position - targetHrp.Position).Magnitude <= 9.5 and (part.Position - myHrp.Position).Magnitude >= 2.2 then
            DetonateCrystal(part)
        end
    end)
end))

-- Главный цикл рассуждений ИИ (Decision Engine)
local function TickAIBrain(dt)
    if not Config.CrystalAura or Unloaded then
        AI_ThoughtText = "OFF"
        HideGhostPrediction()
        return
    end

    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not myHum or myHum.Health <= 0 then
        AI_ThoughtText = "NO CHAR"
        HideGhostPrediction()
        return
    end

    local targetPlr = GetNearestEnemyInAura(Config.CrystalRange)
    if not targetPlr or not targetPlr.Character then
        AI_ThoughtText = "SCANNING"
        AI_Brain.ActiveObsidian = nil
        HideGhostPrediction()
        return
    end

    local targetHrp = targetPlr.Character:FindFirstChild("HumanoidRootPart")
    local targetHum = targetPlr.Character:FindFirstChildOfClass("Humanoid")
    if not targetHrp or not targetHum or targetHum.Health <= 0 then
        AI_ThoughtText = "SCANNING"
        HideGhostPrediction()
        return
    end

    local now = tick()
    local distToEnemy = (targetHrp.Position - myHrp.Position).Magnitude

    -- [ДВИЖЕНИЕ] Тактический стрейф и удержание дистанции
    if not Config.FlyEnabled then
        local flat = Vector3.new(targetHrp.Position.X - myHrp.Position.X, 0, targetHrp.Position.Z - myHrp.Position.Z)
        if flat.Magnitude > 0.1 then
            local fwd = flat.Unit
            if distToEnemy > 7.5 then
                myHum:Move(fwd, false)
            elseif Config.CombatStrafe and distToEnemy < 4.2 then
                AI_Brain.StrafeAngle += dt * 4
                local right = Vector3.new(-fwd.Z, 0, fwd.X)
                local sign = math.sin(AI_Brain.StrafeAngle) >= 0 and 1 or -1
                myHum:Move((-fwd * 0.7 + right * sign * 0.7).Unit, false)
            elseif Config.CombatStrafe then
                AI_Brain.StrafeAngle += dt * 3.5
                local right = Vector3.new(-fwd.Z, 0, fwd.X)
                local sign = math.sin(AI_Brain.StrafeAngle) >= 0 and 1 or -1
                myHum:Move(right * sign, false)
            end
        end
    end

    -- [МЫСЛЬ 1] Есть ли УЖЕ кристалл рядом с врагом? Если да -> немедленно взорвать!
    CrystalOverlapParams.FilterDescendantsInstances = {myChar, targetPlr.Character, VisualFolder}
    local nearTarget = Workspace:GetPartBoundsInRadius(targetHrp.Position, 7.5, CrystalOverlapParams)
    for _, obj in ipairs(nearTarget) do
        local n = string.lower(obj.Name)
        local pName = obj.Parent and string.lower(obj.Parent.Name) or ""
        if string.find(n, "crystal") or string.find(pName, "crystal") then
            if (now - AI_Brain.LastActionTime) >= 0.03 then
                AI_Brain.LastActionTime = now
                DetonateCrystal(obj)
            end
            return
        end
    end

    -- [МЫСЛЬ 2] Враг стоит на земле? Нужно подбросить его вертикально (Vector3(0, 50, 0))!
    if Config.AutoHitPop and (now - AI_Brain.LastPopTime) >= 0.80 and distToEnemy <= 12.0 then
        if math.abs(targetHrp.AssemblyLinearVelocity.Y) < 1.5 then
            AI_Brain.LastPopTime = now
            AI_ThoughtText = "HIT-POP"
            myHrp.AssemblyLinearVelocity = Vector3.new(0, Config.HitPopPower, 0)
            targetHrp.AssemblyLinearVelocity = Vector3.new(0, Config.HitPopPower, 0)
            EquipItemSmart("sword", {"sword", "blade", "mace", "меч", "клинок"}, 1)
            for _, rem in ipairs(CachedRemotes.Attack) do
                if rem and rem.Parent then pcall(function() rem:FireServer(targetHrp.Position, targetHrp) end) end
            end
            ClickScreenPoint(targetHrp.Position, 0)
            return
        end
    end

    -- [МЫСЛЬ 3] Проверяем память ИИ: если мы УЖЕ поставили обсидиан рядом с врагом — НЕ СПАМИМ обсидианом, а ставим КРИСТАЛЛ!
    if AI_Brain.ActiveObsidian then
        local mem = AI_Brain.ActiveObsidian
        local distMemToEnemy = (mem.Pos - targetHrp.Position).Magnitude
        -- Забываем клетку, только если враг убежал далеко (> 8.5 стадов) или прошло > 1.5 сек и 4 попытки кристалла
        if distMemToEnemy > 8.5 or (now - mem.Time) > 1.5 or mem.CrystalAttempts >= 4 then
            AI_Brain.ActiveObsidian = nil
        else
            UpdateGhostPrediction(mem.TopPos, true)
            if (now - AI_Brain.LastActionTime) >= Config.CrystalDelay then
                AI_Brain.LastActionTime = now
                mem.CrystalAttempts += 1
                AI_ThoughtText = "CRYSTAL #" .. tostring(mem.CrystalAttempts)

                local crysTool = EquipItemSmart("crystal", {"crystal", "кристалл"}, Config.CrystalSlot)
                if crysTool then crysTool:Activate() end

                for _, rem in ipairs(CachedRemotes.Place) do
                    if rem and rem.Parent then
                        pcall(function() rem:FireServer(mem.TopPos, mem.Block, Vector3.new(0, 1, 0)) end)
                    end
                end
                ClickScreenPoint(mem.TopPos, 1)
            end
            return
        end
    end

    -- [МЫСЛЬ 4] Ищем реальный обсидиан рядом с ногами врага
    local predPos = targetHrp.Position + Vector3.new(targetHrp.AssemblyLinearVelocity.X * 0.1, 0, targetHrp.AssemblyLinearVelocity.Z * 0.1)
    local feetParts = Workspace:GetPartBoundsInRadius(predPos - Vector3.new(0, 2, 0), 5.5, CrystalOverlapParams)
    for _, part in ipairs(feetParts) do
        if IsObsidianBlock(part) then
            local topPos = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
            AI_Brain.ActiveObsidian = { Pos = part.Position, TopPos = topPos, Block = part, Time = now, CrystalAttempts = 0 }
            AI_ThoughtText = "FOUND OBSIDIAN"
            UpdateGhostPrediction(topPos, true)
            return
        end
    end

    -- [МЫСЛЬ 5] Обсидиана нет -> ищем опору под врагом, ставим ОДИН обсидиан и запоминаем клетку!
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {targetPlr.Character, myChar, VisualFolder}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local floorHit = Workspace:Raycast(predPos + Vector3.new(0, 1, 0), Vector3.new(0, -10, 0), rayParams)

    if floorHit and floorHit.Instance and floorHit.Instance:IsA("BasePart") and floorHit.Instance.Anchored then
        local floorBlock = floorHit.Instance
        local gridStep = floorBlock.Size.Y
        local obsCenter = floorBlock.Position + Vector3.new(0, gridStep, 0)
        local obsTop = obsCenter + Vector3.new(0, gridStep / 2, 0)

        UpdateGhostPrediction(obsTop, false)

        if (now - AI_Brain.LastActionTime) >= 0.08 then
            AI_Brain.LastActionTime = now
            AI_ThoughtText = "PLACE OBSIDIAN"

            if Config.AutoMineUnder and not IsObsidianBlock(floorBlock) and (now - AI_Brain.LastMineTime) >= 0.25 then
                AI_Brain.LastMineTime = now
                EquipItemSmart("pickaxe", {"pickaxe", "pick", "кирк"}, 4)
                for _, rem in ipairs(CachedRemotes.Break) do
                    if rem and rem.Parent then pcall(function() rem:FireServer(floorBlock.Position, floorBlock) end) end
                end
            end

            local obsTool = EquipItemSmart("obsidian", {"obsidian", "обсидиан"}, Config.ObsidianSlot)
            if obsTool then obsTool:Activate() end

            for _, rem in ipairs(CachedRemotes.Place) do
                if rem and rem.Parent then
                    pcall(function() rem:FireServer(obsCenter, floorBlock, Vector3.new(0, 1, 0)) end)
                end
            end

            local floorTop = floorBlock.Position + Vector3.new(0, gridStep / 2, 0)
            ClickScreenPoint(floorTop, 1)

            -- ЗАПОМИНАЕМ КЛЕТКУ: на следующем тике ИИ сразу перейдёт к КРИСТАЛЛУ и не будет спамить обсидианом!
            AI_Brain.ActiveObsidian = { Pos = obsCenter, TopPos = obsTop, Block = floorBlock, Time = now, CrystalAttempts = 0 }
        end
    else
        AI_ThoughtText = "NO FLOOR"
        HideGhostPrediction()
    end
end

-- ==========================================
-- АТМОСФЕРА, REMOVALS & SMART FPS BOOST
-- ==========================================
local ColorFx = Instance.new("ColorCorrectionEffect")
ColorFx.Name = "DevixRichColors"
ColorFx.Enabled = false
ColorFx.Saturation = Config.Saturation
ColorFx.Contrast = 0.14
ColorFx.Brightness = 0.03
ColorFx.Parent = Lighting

local BloomFx = Instance.new("BloomEffect")
BloomFx.Name = "DevixRichBloom"
BloomFx.Enabled = false
BloomFx.Intensity = 0.35
BloomFx.Size = 24
BloomFx.Threshold = 1.1
BloomFx.Parent = Lighting

local SkyPresets = {
    Galaxy = { SkyboxBk="rbxassetid://159454299", SkyboxDn="rbxassetid://159454296", SkyboxFt="rbxassetid://159454293", SkyboxLf="rbxassetid://159454286", SkyboxRt="rbxassetid://159454300", SkyboxUp="rbxassetid://159454288", Ambient=Color3.fromRGB(145,130,190), OutdoorAmbient=Color3.fromRGB(160,145,210) },
    Sunset = { SkyboxBk="rbxassetid://458016711", SkyboxDn="rbxassetid://458016826", SkyboxFt="rbxassetid://458016532", SkyboxLf="rbxassetid://458016655", SkyboxRt="rbxassetid://458016782", SkyboxUp="rbxassetid://458016792", Ambient=Color3.fromRGB(210,155,130), OutdoorAmbient=Color3.fromRGB(225,170,140) },
    Cyber  = { SkyboxBk="rbxassetid://271042516", SkyboxDn="rbxassetid://271077243", SkyboxFt="rbxassetid://271042556", SkyboxLf="rbxassetid://271042310", SkyboxRt="rbxassetid://271042467", SkyboxUp="rbxassetid://271077958", Ambient=Color3.fromRGB(130,175,200), OutdoorAmbient=Color3.fromRGB(145,190,215) },
}

local SavedOldSky = nil

local function ApplyCustomSky(enabled)
    if enabled then
        local existing = Lighting:FindFirstChildOfClass("Sky")
        if existing and existing.Name ~= "DevixSky" then SavedOldSky = existing:Clone(); existing:Destroy() end
        local sky = Lighting:FindFirstChild("DevixSky") or Instance.new("Sky")
        sky.Name = "DevixSky"
        local p = SkyPresets[Config.SkyPreset] or SkyPresets.Galaxy
        sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt, sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = p.SkyboxBk, p.SkyboxDn, p.SkyboxFt, p.SkyboxLf, p.SkyboxRt, p.SkyboxUp
        sky.StarCount = 3000
        sky.Parent = Lighting
        Lighting.Ambient, Lighting.OutdoorAmbient = p.Ambient, p.OutdoorAmbient
    else
        local s = Lighting:FindFirstChild("DevixSky")
        if s then s:Destroy() end
        if SavedOldSky then SavedOldSky.Parent = Lighting; SavedOldSky = nil end
    end
end

local function ApplyRemovalsSweep()
    if not Config.RemovalsEnabled or Unloaded then return end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.CameraOffset = Vector3.zero end
        for _, obj in ipairs(char:GetDescendants()) do if obj:IsA("Fire") or obj:IsA("Smoke") then obj.Enabled = false end end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Fire") or obj:IsA("Smoke") then obj.Enabled = false end
    end
end

local function ApplySmartFPSBoost(enabled)
    if enabled then
        SavedLighting.GlobalShadows = Lighting.GlobalShadows
        Lighting.GlobalShadows = false
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Trail") then obj.Enabled = false
            elseif obj:IsA("BasePart") then obj.CastShadow = false end
        end
    else
        if SavedLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = SavedLighting.GlobalShadows end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Trail") then obj.Enabled = true
            elseif obj:IsA("BasePart") then obj.CastShadow = true end
        end
    end
end

-- ==========================================
-- СОЗДАНИЕ ВКЛАДОК
-- ==========================================
local TabMovement    = CreateTab("Movement")
local TabCombat      = CreateTab("Combat")
local TabSkinChanger = CreateTab("SkinChanger")
local TabVisuals     = CreateTab("Visuals / Pack")
local TabInfo        = CreateTab("INFO")
local TabPanic       = CreateTab("Panic/Clear")

-- [1. MOVEMENT]
CreateSectionLabel(TabMovement, "Smooth Flight (WASD + Space / Ctrl)")
CreateToggle(TabMovement, "Fly Mode (LinearVelocity)", "Плавный полёт (нажмите колёсиком для Toggle-бинда)", false, function(v)
    Config.FlyEnabled = v
    if not v then StopSmoothFly() end
end)
CreateSlider(TabMovement, "Fly Speed", 16, 150, 42, true, function(v) Config.FlySpeed = v end)

CreateSectionLabel(TabMovement, "WalkSpeed (Прыжки работают)")
CreateToggle(TabMovement, "Custom WalkSpeed", "Высокая скорость без блокировки прыжков", false, function(v)
    Config.SpeedEnabled = v
    if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
    end
end)
CreateSlider(TabMovement, "WalkSpeed Value (16 - 350)", 16, 350, 24, true, function(v) Config.WalkSpeed = v end)

-- [2. COMBAT]
CreateSectionLabel(TabCombat, "AI Reasoning Crystal Aura (UPDATE #1)")
CreateToggle(TabCombat, "Crystal Aura (AI Brain)", "Рассуждающий ИИ с памятью клеток (0 спама обсидианом)", false, function(v)
    Config.CrystalAura = v
    AI_Brain.ActiveObsidian = nil
    if not v then HideGhostPrediction() end
end)
CreateToggle(TabCombat, "Surface Target Outline", "Рамка на грани блока куда ИИ поставит кристалл", true, function(v)
    Config.CrystalPreview = v
    if not v then HideGhostPrediction() end
end)
CreateToggle(TabCombat, "Combat Strafe", "Держит дистанцию 5-7 блоков и мансит вокруг врага", true, function(v) Config.CombatStrafe = v end)
CreateToggle(TabCombat, "Vertical Hit-Pop (Подброс Y)", "Подбрасывает вверх (Vector3.new(0, Y, 0))", true, function(v) Config.AutoHitPop = v end)
CreateSlider(TabCombat, "Vertical Pop Velocity (Y)", 25, 90, 50, true, function(v) Config.HitPopPower = v end)
CreateToggle(TabCombat, "Auto Mine Under Enemy", "Ломает блок под игроком для установки обсидиана", true, function(v) Config.AutoMineUnder = v end)
CreateSlider(TabCombat, "Crystal Aura Range", 6, 32, 22, true, function(v) Config.CrystalRange = v end)
CreateSlider(TabCombat, "Crystal Delay (sec)", 0.02, 0.25, 0.05, false, function(v) Config.CrystalDelay = v end)
CreateSlider(TabCombat, "Obsidian Hotbar Slot (1-9)", 1, 9, 2, true, function(v) Config.ObsidianSlot = v end)
CreateSlider(TabCombat, "Crystal Hotbar Slot (1-9)", 1, 9, 3, true, function(v) Config.CrystalSlot = v end)

CreateSectionLabel(TabCombat, "AttackAura (Mace / Crits)")
CreateToggle(TabCombat, "AttackAura", "Умная аура с упреждением и критами в падении", false, function(v) Config.AttackAura = v end)
CreateToggle(TabCombat, "Camera Hitbox Lock", "Доводит камеру в центр хитбокса врага", false, function(v) Config.CameraAimLock = v end)
CreateToggle(TabCombat, "Only Crits / Mace Fall", "Бьёт строго в падении", true, function(v) Config.OnlyCrits = v end)
CreateToggle(TabCombat, "Auto Jump for Crits", "Автоматически подпрыгивает для крита", true, function(v) Config.AutoJumpCrits = v end)
CreateToggle(TabCombat, "Target Follow", "Плавное преследование противника", false, function(v) Config.TargetFollow = v end)
CreateSlider(TabCombat, "Crit Cooldown (sec)", 0.45, 0.90, 0.60, false, function(v) Config.CritCooldown = v end)
CreateSlider(TabCombat, "AttackAura Range", 6, 25, 16, true, function(v) Config.AuraRange = v end)

CreateSectionLabel(TabCombat, "Super Upback & Manual Crystal")
CreateToggle(TabCombat, "Super Upback", "Усиленная отдача и подброс при ручном ударе", false, function(v) Config.SuperUpback = v end)
CreateSlider(TabCombat, "Knockback Power", 15, 100, 45, true, function(v) Config.KnockbackPower = v end)
CreateSlider(TabCombat, "Upback Height", 0.5, 4.0, 1.0, false, function(v) Config.UpbackBlocks = v end)
CreateToggle(TabCombat, "Fast Crystal (Hold RMB)", "Ручной спам кристаллами при зажатии ПКМ по обсидиану", false, function(v) Config.FastCrystal = v end)

-- [3. SKINCHANGER]
CreateSectionLabel(TabSkinChanger, "Weapon Crate Skins")
local SkinStatusLbl = Instance.new("TextLabel")
SkinStatusLbl.Size = UDim2.new(1, -4, 0, 22)
SkinStatusLbl.BackgroundColor3 = Theme.Card
SkinStatusLbl.Font = FontMono
SkinStatusLbl.TextSize = 11
SkinStatusLbl.TextColor3 = Theme.Text
SkinStatusLbl.Text = "ACTIVE SKIN: NONE"
SkinStatusLbl.Parent = TabSkinChanger
AddCorner(SkinStatusLbl, 5)
AddStroke(SkinStatusLbl, Theme.Border, 1)

for _, skin in ipairs(SwordSkins) do
    CreateButton(TabSkinChanger, skin.Name, skin.Rarity, function()
        ActiveSkinData = skin
        Config.ActiveSkin = skin.Name
        SkinStatusLbl.Text = "ACTIVE SKIN: " .. string.upper(skin.Name)
        ApplySwordSkinToCharacter()
    end)
end

CreateButton(TabSkinChanger, "RESET TO DEFAULT SKIN", "Убрать скин с оружия", function()
    ClearSwordSkin()
    Config.ActiveSkin = "None"
    SkinStatusLbl.Text = "ACTIVE SKIN: NONE"
end)

-- [4. VISUALS]
CreateSectionLabel(TabVisuals, "Atmosphere & Visuals")
CreateToggle(TabVisuals, "Rich Colors", "Повышает насыщенность и контраст", false, function(v) Config.RichColors = v; ColorFx.Enabled = v; BloomFx.Enabled = v end)
CreateSlider(TabVisuals, "Color Saturation", 0.1, 1.2, 0.45, false, function(v) Config.Saturation = v; ColorFx.Saturation = v end)
CreateToggle(TabVisuals, "Custom Sky", "Заменяет небо на выбранный пресет", false, function(v) Config.CustomSky = v; ApplyCustomSky(v) end)
local _, skyBtnTitle = CreateButton(TabVisuals, "Sky Preset: Galaxy", "Нажмите для смены (Galaxy / Sunset / Cyber)", function()
    Config.SkyPreset = (Config.SkyPreset == "Galaxy" and "Sunset") or (Config.SkyPreset == "Sunset" and "Cyber") or "Galaxy"
    skyBtnTitle.Text = "Sky Preset: " .. Config.SkyPreset
    if Config.CustomSky then ApplyCustomSky(true) end
end)
CreateToggle(TabVisuals, "Removals (Clean Screen)", "Убирает огонь и тряску камеры", false, function(v) Config.RemovalsEnabled = v; if v then ApplyRemovalsSweep() end end)
CreateToggle(TabVisuals, "Smart FPS Boost", "Буст FPS без порчи текстур", false, function(v) Config.SmartFPSBoost = v; ApplySmartFPSBoost(v) end)
CreateToggle(TabVisuals, "Target ESP Box", "Квадрат и инфо на ближайшей цели", true, function(v) Config.TargetESP = v; if not v then TargetBox.Visible = false end end)
CreateToggle(TabVisuals, "Target Aura Ring", "Светящееся кольцо вокруг цели", true, function(v) Config.TargetRing = v; if not v then TargetRingPart.Transparency = 1; TargetInnerRing.Transparency = 1 end end)
CreateToggle(TabVisuals, "Hit Sparks Effect", "Вспышка искр при ударе", true, function(v) Config.HitSparks = v end)

-- [5. INFO]
CreateSectionLabel(TabInfo, "Client Info")
local InfoCard = Instance.new("TextLabel")
InfoCard.Size = UDim2.new(1, -4, 0, 140)
InfoCard.BackgroundColor3 = Theme.Card
InfoCard.Font = FontMono
InfoCard.TextSize = 11
InfoCard.TextColor3 = Theme.Text
InfoCard.TextXAlignment = Enum.TextXAlignment.Left
InfoCard.TextYAlignment = Enum.TextYAlignment.Top
InfoCard.TextWrapped = true
InfoCard.Text = string.format(
    "  CLIENT :: Devix hub UPDATE #1\n  USER   :: %s\n\n  [MMB] по функции — назначить Toggle-бинд\n  [RShift] — скрыть / показать меню",
    LocalPlayer.Name
)
InfoCard.Parent = TabInfo
AddCorner(InfoCard, 8)
AddStroke(InfoCard, Theme.Border, 1)

CreateToggle(TabInfo, "Watermark HUD", "Верхняя панель с пингом и мыслями ИИ", true, function(v) Config.Watermark = v; WatermarkFrame.Visible = v end)

-- [6. PANIC / CLEAR]
CreateSectionLabel(TabPanic, "Emergency Unload")
CreateButton(TabPanic, "PANIC / CLEAR UNLOAD", "Выключить все функции, вернуть небо и закрыть меню", function()
    if Unloaded then return end
    Unloaded = true
    StopSmoothFly()
    ClearSwordSkin()
    ApplyCustomSky(false)
    if Config.SmartFPSBoost then ApplySmartFPSBoost(false) end
    if ColorFx then ColorFx:Destroy() end
    if BloomFx then BloomFx:Destroy() end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 end
    if VisualFolder then VisualFolder:Destroy() end
    for _, conn in ipairs(Connections) do if conn.Connected then conn:Disconnect() end end
    if ScreenGui then ScreenGui:Destroy() end
end)

SelectTab("Combat")

-- ==========================================
-- ЛОГИКА: SUPER UPBACK, INPUT & MANUAL FAST CRYSTAL
-- ==========================================
local LastUpbackTime, IsHoldingRMB, CrystalBusy = 0, false, false

local function ExecuteSuperUpback(targetPlr)
    if not Config.SuperUpback or Unloaded or (tick() - LastUpbackTime) < 0.25 then return end
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetHrp = targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp or not targetHrp or (targetHrp.Position - myHrp.Position).Magnitude > Config.HitRange then return end
    LastUpbackTime = tick()
    local dir = ((targetHrp.Position - myHrp.Position) * Vector3.new(1, 0, 1))
    dir = dir.Magnitude > 0.01 and dir.Unit or myHrp.CFrame.LookVector
    local upVel = math.sqrt(2 * Workspace.Gravity * (Config.UpbackBlocks * 4.2))
    myHrp.AssemblyLinearVelocity = (dir * Config.KnockbackPower) + Vector3.new(0, upVel * 0.45, 0)
    targetHrp.AssemblyLinearVelocity = (dir * Config.KnockbackPower) + Vector3.new(0, upVel, 0)
    SpawnHitSparks(targetHrp.Position, false)
end

table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gp)
    if ListeningBindTarget and input.UserInputType == Enum.UserInputType.Keyboard then
        local t = ListeningBindTarget; ListeningBindTarget = nil; t.OnBind(input.KeyCode); return
    end
    if input.KeyCode == Config.ToggleKey then Config.MenuOpen = not Config.MenuOpen; MainFrame.Visible = Config.MenuOpen end
    if not gp and input.UserInputType == Enum.UserInputType.Keyboard and Keybinds[input.KeyCode] then
        Keybinds[input.KeyCode].Toggle()
    end
    if not gp then
        if input.UserInputType == Enum.UserInputType.MouseButton2 then IsHoldingRMB = true
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 and Config.SuperUpback and CurrentTargetPlayer then
            ExecuteSuperUpback(CurrentTargetPlayer)
        end
    end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then IsHoldingRMB = false end
end))

local function TriggerCrystalCycle()
    if CrystalBusy or Unloaded then return end
    local target = Mouse.Target
    if not target or not IsObsidianBlock(target) then return end
    CrystalBusy = true
    local mousePos = UserInputService:GetMouseLocation()
    for _ = 1, Config.CrystalsPerCycle do
        if not IsHoldingRMB or not Config.FastCrystal or Unloaded then break end
        VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, true, game, 1)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, false, game, 1)
        task.wait(Config.CrystalDelay)
        VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 1)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 1)
        task.wait(Config.CrystalDelay)
    end
    CrystalBusy = false
end

-- ==========================================
-- ОСНОВНЫЕ ЦИКЛЫ (HEARTBEAT & RENDERSTEPPED)
-- ==========================================
local function GetClosestTargetToCursor()
    local mouseLoc = UserInputService:GetMouseLocation()
    local best, bestDist = nil, 350
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local sp, on = SafeWorldToScreen(hrp.Position)
                if on and sp then
                    local d = (Vector2.new(sp.X, sp.Y) - mouseLoc).Magnitude
                    if d < bestDist then bestDist = d; best = plr end
                end
            end
        end
    end
    return best
end

local RingAngle, RemovalTimer, SkinRefreshTimer = 0, 0, 0

table.insert(Connections, RunService.Heartbeat:Connect(function(dt)
    if Unloaded then return end
    if Config.FlyEnabled then UpdateSmoothFly() end
    if Config.AttackAura then ProcessAttackAura(dt) end
    TickAIBrain(dt)
end))

table.insert(Connections, RunService.RenderStepped:Connect(function(dt)
    if Unloaded then return end

    if Config.SpeedEnabled and not Config.FlyEnabled then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.CameraOffset = Vector3.zero; hum.WalkSpeed = Config.WalkSpeed end
    end

    if Config.Watermark then
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        WatermarkLabel.Text = string.format("DEVIX HUB UPDATE #1  |  %d MS  |  AI: %s", ping, AI_ThoughtText)
        WatermarkFrame.Size = UDim2.new(0, WatermarkLabel.TextBounds.X + 34, 0, 30)
    end

    local auraTarget = (Config.AttackAura and GetNearestEnemyInAura(Config.AuraRange)) or (Config.CrystalAura and GetNearestEnemyInAura(Config.CrystalRange)) or nil
    CurrentTargetPlayer = auraTarget or GetClosestTargetToCursor()

    if CurrentTargetPlayer and CurrentTargetPlayer.Character then
        local hrp = CurrentTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
        local head = CurrentTargetPlayer.Character:FindFirstChild("Head")
        local hum = CurrentTargetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hrp and head and hum then
            if Config.TargetESP then
                local topPos, onTop = SafeWorldToScreen(head.Position + Vector3.new(0, 0.6, 0))
                local botPos, onBot = SafeWorldToScreen(hrp.Position - Vector3.new(0, 3, 0))
                if onTop and onBot and topPos and botPos then
                    local h = math.abs(botPos.Y - topPos.Y)
                    local w = h * 0.65
                    TargetBox.Size = UDim2.new(0, w, 0, h)
                    TargetBox.Position = UDim2.new(0, topPos.X - w / 2, 0, topPos.Y)
                    TargetBox.Visible = true
                    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local dist = myHrp and math.floor((myHrp.Position - hrp.Position).Magnitude) or 0
                    TargetInfoTag.Text = string.format("%s [%d HP] • %dm", CurrentTargetPlayer.Name, math.floor(hum.Health), dist)
                    TargetInfoTag.Size = UDim2.new(0, TargetInfoTag.TextBounds.X + 14, 0, 20)
                    TargetInfoTag.Position = UDim2.new(0.5, -TargetInfoTag.Size.X.Offset / 2, 0, -26)
                else
                    TargetBox.Visible = false
                end
            else
                TargetBox.Visible = false
            end

            if Config.TargetRing then
                RingAngle += dt * 3
                local ringCF = CFrame.new(hrp.Position - Vector3.new(0, 2.7 - math.sin(RingAngle * 1.5) * 0.25, 0)) * CFrame.Angles(0, RingAngle, math.rad(90))
                TargetRingPart.CFrame, TargetInnerRing.CFrame = ringCF, ringCF
                TargetRingPart.Transparency, TargetInnerRing.Transparency = 0.2, 0.4
            else
                TargetRingPart.Transparency, TargetInnerRing.Transparency = 1, 1
            end
        end
    else
        TargetBox.Visible = false
        TargetRingPart.Transparency, TargetInnerRing.Transparency = 1, 1
    end

    if ActiveSkinData then
        SkinRefreshTimer += dt
        if SkinRefreshTimer >= 0.2 then SkinRefreshTimer = 0; ApplySwordSkinToCharacter() end
    end

    if Config.RemovalsEnabled then
        RemovalTimer += dt
        if RemovalTimer >= 0.25 then RemovalTimer = 0; ApplyRemovalsSweep() end
    end

    if Config.FastCrystal and IsHoldingRMB and not CrystalBusy then
        task.spawn(TriggerCrystalCycle)
    end
end))
