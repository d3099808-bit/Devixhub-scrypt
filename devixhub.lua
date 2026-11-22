--[[
    Devix hub LAST (BETA) | Monochrome Cyber-Minimalist UI (Full Script)
    Fixes:
    - Fixed ScreenGui self-parenting error (DevixHub_UI Parent is now correctly set to CoreGui/PlayerGui)
    - Fixed Obsidian/Crystal cycle (places obsidian -> waits for server sync -> switches to crystal & places it)
    - Vertical Hit-Pop (pure Y=50 vertical velocity pop without horizontal knockback)
    - Cached RemoteEvents + Smooth RenderStepped WalkSpeed + Toggle Keybinds + SkinChanger
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
    Plan = "BETA",

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

    -- Combat: Smart AI Crystal Aura
    CrystalAura = false,
    CrystalRange = 22,
    CrystalDelay = 0.04,
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

local Keybinds = {}
local ListeningBindTarget = nil

-- ==========================================
-- КЭШ ИГРОВЫХ REMOTEEVENT
-- ==========================================
local CachedRemotes = {
    Place = {},
    Break = {},
    Attack = {},
}

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

local function CacheGameRemotes()
    for _, rem in ipairs(ReplicatedStorage:GetDescendants()) do
        RegisterRemote(rem)
    end
    table.insert(Connections, ReplicatedStorage.DescendantAdded:Connect(RegisterRemote))
end
task.spawn(CacheGameRemotes)

-- Контейнер GUI (Исправлено: ScreenGui больше не ссылается сама на себя)
local function GetGuiParent()
    if typeof(gethui) == "function" then
        return gethui()
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then
        return core
    end
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
ScreenGui.Parent = ParentGui -- Корректный родитель

-- Премиальная кибер-палитра (#030303 / #080808 / #141414 / #222222 / #FFFFFF)
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
    local info = TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
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
-- 1. WATERMARK HUD
-- ==========================================
local WatermarkFrame = Instance.new("Frame")
WatermarkFrame.Name = "Watermark"
WatermarkFrame.Size = UDim2.new(0, 360, 0, 30)
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
WatermarkLabel.Text = "DEVIX HUB LAST (BETA)  |  PLAYER  |  0 MS"
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

local function UpdateGhostPrediction(surfacePos, hasObsidianAlready)
    if not Config.CrystalPreview or not Config.CrystalAura or Unloaded then
        HideGhostPrediction()
        return
    end
    GhostSurfaceRing.CFrame = CFrame.new(surfacePos + Vector3.new(0, 0.03, 0))
    GhostSurfaceOutline.Color3 = hasObsidianAlready and Color3.fromHex("#FFFFFF") or Color3.fromHex("#7A7A7A")
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
        t.Completed:Connect(function()
            spark:Destroy()
        end)
    end
end

-- ==========================================
-- 4. ГЛАВНОЕ ОКНО
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
BrandTitle.Text = "DEVIX HUB LAST (BETA)"
BrandTitle.Parent = Topbar

local PlanBadge = Instance.new("TextLabel")
PlanBadge.Size = UDim2.new(0, 52, 0, 20)
PlanBadge.Position = UDim2.new(0, 218, 0.5, -10)
PlanBadge.BackgroundColor3 = Theme.Card
PlanBadge.Font = FontMono
PlanBadge.TextSize = 10
PlanBadge.TextColor3 = Theme.Text
PlanBadge.Text = "BETA"
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
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    Topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
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

local Pages = {}
local TabButtons = {}

local function SelectTab(tabName)
    for name, page in pairs(Pages) do
        page.Visible = (name == tabName)
    end
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

    btn.MouseButton1Click:Connect(function()
        SelectTab(name)
    end)

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

    local state = defaultState
    local boundKey = nil

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

    local function ToggleState()
        SetState(not state)
    end

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
                    Keybinds[keyCode] = {
                        Toggle = ToggleState,
                        Title = title
                    }
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            UpdateSlider(input)
        end
    end)

    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateSlider(input)
        end
    end))

    table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
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

    btn.MouseEnter:Connect(function()
        Tween(btn, {BackgroundColor3 = Theme.CardHover}, 0.12)
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, {BackgroundColor3 = Theme.Card}, 0.12)
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn, lbl, sub
end

-- ==========================================
-- ЛОГИКА: SKINCHANGER
-- ==========================================
local SwordSkins = {
    {
        Name = "Bloodfang",
        Rarity = "RELIC! (2%)",
        AccentHex = "#FF2A2A",
        BladeColor = Color3.fromHex("#9E0B0B"),
        EdgeColor = Color3.fromHex("#FF3B3B"),
        Neon = true,
        Pattern = {
            "00000022",
            "00000212",
            "00002120",
            "00021200",
            "03212000",
            "03320000",
            "30330000",
            "33000000",
        }
    },
    {
        Name = "Void Edge",
        Rarity = "EPIC (7%)",
        AccentHex = "#A855F7",
        BladeColor = Color3.fromHex("#4C1D95"),
        EdgeColor = Color3.fromHex("#38BDF8"),
        Neon = true,
        Pattern = {
            "00000022",
            "00000212",
            "00002120",
            "00021200",
            "03212000",
            "03320000",
            "30330000",
            "33000000",
        }
    },
    {
        Name = "Frost Sword",
        Rarity = "RARE (19%)",
        AccentHex = "#38BDF8",
        BladeColor = Color3.fromHex("#7DD3FC"),
        EdgeColor = Color3.fromHex("#E0F2FE"),
        Neon = false,
        Pattern = {
            "00000022",
            "00000212",
            "00002120",
            "00021200",
            "03212000",
            "03320000",
            "30330000",
            "33000000",
        }
    },
    {
        Name = "Ember Blade",
        Rarity = "UNCOMMON (21%)",
        AccentHex = "#FB923C",
        BladeColor = Color3.fromHex("#EA580C"),
        EdgeColor = Color3.fromHex("#FDE047"),
        Neon = true,
        Pattern = {
            "00000022",
            "00000212",
            "00002120",
            "00021200",
            "03212000",
            "03320000",
            "30330000",
            "33000000",
        }
    },
    {
        Name = "Heavy Mace",
        Rarity = "LEGENDARY (5%)",
        AccentHex = "#EAB308",
        BladeColor = Color3.fromHex("#9CA3AF"),
        EdgeColor = Color3.fromHex("#F3F4F6"),
        Neon = false,
        Pattern = {
            "00002222",
            "00002112",
            "00002112",
            "00002222",
            "00030000",
            "00300000",
            "03000000",
            "30000000",
        }
    },
    {
        Name = "Starter Club",
        Rarity = "COMMON (46%)",
        AccentHex = "#94A3B8",
        BladeColor = Color3.fromHex("#78350F"),
        EdgeColor = Color3.fromHex("#92400E"),
        Neon = false,
        Pattern = {
            "00000011",
            "00000121",
            "00001210",
            "00012100",
            "00121000",
            "01210000",
            "12100000",
            "11000000",
        }
    },
}

local ActiveSkinData = nil
local BodyPartNames = {
    ["Head"] = true, ["Torso"] = true, ["UpperTorso"] = true, ["LowerTorso"] = true,
    ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
    ["LeftUpperArm"] = true, ["LeftLowerArm"] = true, ["LeftHand"] = true,
    ["RightUpperArm"] = true, ["RightLowerArm"] = true, ["RightHand"] = true,
    ["LeftUpperLeg"] = true, ["LeftLowerLeg"] = true, ["LeftFoot"] = true,
    ["RightUpperLeg"] = true, ["RightLowerLeg"] = true, ["RightFoot"] = true,
    ["HumanoidRootPart"] = true
}

local function ApplySkinTo3DPart(part, skin)
    if not part or not part:IsA("BasePart") then return end
    part.Color = skin.EdgeColor
    part.Material = skin.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic

    if part:IsA("MeshPart") then
        part.TextureID = ""
    end
    local specialMesh = part:FindFirstChildOfClass("SpecialMesh")
    if specialMesh then
        specialMesh.TextureId = ""
        specialMesh.VertexColor = Vector3.new(skin.EdgeColor.R, skin.EdgeColor.G, skin.EdgeColor.B)
    end

    local selBox = part:FindFirstChild("DevixSkinBox")
    if not selBox then
        selBox = Instance.new("SelectionBox")
        selBox.Name = "DevixSkinBox"
        selBox.Adornee = part
        selBox.LineThickness = 0.02
        selBox.SurfaceTransparency = 0.65
        selBox.Parent = part
    end
    selBox.Color3 = skin.EdgeColor
    selBox.SurfaceColor3 = skin.BladeColor
end

local function ApplySwordSkinToCharacter()
    if not ActiveSkinData or Unloaded then return end

    local char = LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") or (child:IsA("Model") and child.Name ~= "DevixVisualFX") then
                for _, part in ipairs(child:GetDescendants()) do
                    if part:IsA("BasePart") then
                        ApplySkinTo3DPart(part, ActiveSkinData)
                    end
                end
            elseif child:IsA("BasePart") and not BodyPartNames[child.Name] then
                ApplySkinTo3DPart(child, ActiveSkinData)
            end
        end

        local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
        if rightHand then
            for _, desc in ipairs(rightHand:GetDescendants()) do
                if desc:IsA("BasePart") and not BodyPartNames[desc.Name] then
                    ApplySkinTo3DPart(desc, ActiveSkinData)
                end
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

    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pGui then
        for _, gui in ipairs(pGui:GetDescendants()) do
            if gui:IsA("GuiObject") and gui.Visible then
                local slotNum = tonumber(string.match(gui.Name, "^[Ss]lot(%d)$") or string.match(gui.Name, "^(%d)$"))
                if slotNum and slotNum >= 1 and slotNum <= 9 then
                    local stroke = gui:FindFirstChildOfClass("UIStroke")
                    local isSelected = (stroke and stroke.Enabled and stroke.Thickness >= 2) or (gui.BorderSizePixel >= 2)
                    if isSelected then
                        local old = gui:FindFirstChild("DevixSkinOverlay")
                        if old then old:Destroy() end

                        local overlay = Instance.new("Frame")
                        overlay.Name = "DevixSkinOverlay"
                        overlay.Size = UDim2.new(0.82, 0, 0.82, 0)
                        overlay.Position = UDim2.new(0.09, 0, 0.09, 0)
                        overlay.BackgroundColor3 = Color3.fromHex("#080808")
                        overlay.BackgroundTransparency = 0.15
                        overlay.ZIndex = gui.ZIndex + 6
                        overlay.Parent = gui
                        AddCorner(overlay, 5)

                        local handleColor = Color3.fromHex("#3B2F2F")
                        for y = 1, 8 do
                            local row = ActiveSkinData.Pattern[y]
                            for x = 1, 8 do
                                local ch = string.sub(row, x, x)
                                if ch ~= "0" then
                                    local px = Instance.new("Frame")
                                    px.Size = UDim2.new(0.125, 0, 0.125, 0)
                                    px.Position = UDim2.new((x - 1) * 0.125, 0, (y - 1) * 0.125, 0)
                                    px.BorderSizePixel = 0
                                    px.ZIndex = overlay.ZIndex + 1
                                    if ch == "1" then
                                        px.BackgroundColor3 = ActiveSkinData.BladeColor
                                    elseif ch == "2" then
                                        px.BackgroundColor3 = ActiveSkinData.EdgeColor
                                    else
                                        px.BackgroundColor3 = handleColor
                                    end
                                    px.Parent = overlay
                                end
                            end
                        end
                    else
                        local old = gui:FindFirstChild("DevixSkinOverlay")
                        if old then old:Destroy() end
                    end
                end
            end
        end
    end
end

local function ClearSwordSkin()
    ActiveSkinData = nil
    local char = LocalPlayer.Character
    if char then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc.Name == "DevixSkinBox" then desc:Destroy() end
        end
    end
    for _, desc in ipairs(Camera:GetDescendants()) do
        if desc.Name == "DevixSkinBox" then desc:Destroy() end
    end
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pGui then
        for _, gui in ipairs(pGui:GetDescendants()) do
            if gui.Name == "DevixSkinOverlay" then gui:Destroy() end
        end
    end
end

-- ==========================================
-- ЛОГИКА: ПЛАВНЫЙ FLY
-- ==========================================
local FlyAttachment = nil
local FlyLinearVel = nil

local function StopSmoothFly()
    if FlyLinearVel then FlyLinearVel:Destroy(); FlyLinearVel = nil end
    if FlyAttachment then FlyAttachment:Destroy(); FlyAttachment = nil end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.AutoRotate = true
            hum.PlatformStand = false
        end
    end
end

local function UpdateSmoothFly()
    if not Config.FlyEnabled or Unloaded then
        StopSmoothFly()
        return
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if not FlyAttachment or FlyAttachment.Parent ~= hrp then
        if FlyAttachment then FlyAttachment:Destroy() end
        FlyAttachment = Instance.new("Attachment")
        FlyAttachment.Name = "DevixFlyAtt"
        FlyAttachment.Parent = hrp
    end

    if not FlyLinearVel or FlyLinearVel.Parent ~= hrp then
        if FlyLinearVel then FlyLinearVel:Destroy() end
        FlyLinearVel = Instance.new("LinearVelocity")
        FlyLinearVel.Name = "DevixFlyVel"
        FlyLinearVel.Attachment0 = FlyAttachment
        FlyLinearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        FlyLinearVel.MaxForce = math.huge
        FlyLinearVel.RelativeTo = Enum.ActuatorRelativeTo.World
        FlyLinearVel.VectorVelocity = Vector3.zero
        FlyLinearVel.Parent = hrp
    end

    local moveDir = Vector3.zero
    local camCF = Camera.CFrame
    local forward = camCF.LookVector
    local right = camCF.RightVector

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveDir = moveDir + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        moveDir = moveDir - Vector3.new(0, 1, 0)
    end

    if moveDir.Magnitude > 0 then
        FlyLinearVel.VectorVelocity = moveDir.Unit * Config.FlySpeed
    else
        FlyLinearVel.VectorVelocity = Vector3.new(0, 0.01, 0)
    end
end

-- ==========================================
-- ЛОГИКА: ATTACKAURA
-- ==========================================
local LastAuraHit = 0
local LastCritJump = 0

local function GetNearestEnemyInAura(maxRange)
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil, math.huge end

    local bestTarget = nil
    local bestDist = maxRange

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
    local targetTorso = targetPlr.Character:FindFirstChild("UpperTorso") or targetPlr.Character:FindFirstChild("Torso") or targetHrp
    if not targetHrp or not targetTorso then return end

    local predictedPos = targetTorso.Position + (targetHrp.AssemblyLinearVelocity * 0.055)

    local flatTargetPos = Vector3.new(predictedPos.X, myHrp.Position.Y, predictedPos.Z)
    if (flatTargetPos - myHrp.Position).Magnitude > 0.1 then
        local lookCF = CFrame.lookAt(myHrp.Position, flatTargetPos)
        myHrp.CFrame = myHrp.CFrame:Lerp(lookCF, math.clamp(dt * 18, 0, 1))
    end

    if Config.CameraAimLock then
        local camGoal = CFrame.lookAt(Camera.CFrame.Position, predictedPos)
        Camera.CFrame = Camera.CFrame:Lerp(camGoal, math.clamp(dt * 24, 0, 1))
    end

    if Config.TargetFollow and not Config.FlyEnabled then
        local dirToTarget = (flatTargetPos - myHrp.Position)
        if dirToTarget.Magnitude > Config.FollowDistance then
            myHum:Move(dirToTarget.Unit, false)
        end
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {myChar, VisualFolder}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local groundRay = Workspace:Raycast(myHrp.Position, Vector3.new(0, -3.5, 0), rayParams)
    local isGrounded = (groundRay ~= nil) or (myHum.FloorMaterial ~= Enum.Material.Air)

    local velY = myHrp.AssemblyLinearVelocity.Y
    local isFallingDown = (not isGrounded and velY < -2.2)

    if Config.OnlyCrits and Config.AutoJumpCrits and not Config.FlyEnabled then
        if isGrounded and (tick() - LastCritJump) > 0.48 and (tick() - LastAuraHit) >= (Config.CritCooldown * 0.5) then
            LastCritJump = tick()
            myHum.Jump = true
            myHum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    local canHit = (not Config.OnlyCrits) or isFallingDown or Config.FlyEnabled

    if canHit and (tick() - LastAuraHit) >= Config.CritCooldown then
        LastAuraHit = tick()

        local tool = myChar:FindFirstChildOfClass("Tool")
        if tool then
            tool:Activate()
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
        local clickX = onScreen and screenPos.X or (Camera.ViewportSize.X / 2)
        local clickY = onScreen and screenPos.Y or (Camera.ViewportSize.Y / 2)

        VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, true, game, 1)
        task.delay(0.02, function()
            VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, false, game, 1)
        end)

        SpawnHitSparks(predictedPos, true)
    end
end

-- ==========================================
-- ЛОГИКА: AI CRYSTAL AURA
-- ==========================================
local CrystalOverlapParams = OverlapParams.new()
CrystalOverlapParams.FilterType = Enum.RaycastFilterType.Exclude

local NumberKeyCodes = {
    [1] = Enum.KeyCode.One, [2] = Enum.KeyCode.Two, [3] = Enum.KeyCode.Three,
    [4] = Enum.KeyCode.Four, [5] = Enum.KeyCode.Five, [6] = Enum.KeyCode.Six,
    [7] = Enum.KeyCode.Seven, [8] = Enum.KeyCode.Eight, [9] = Enum.KeyCode.Nine,
}

local LastSlotSwitchTime = 0
local CurrentEquippedType = ""

local function PressSlotKeyFast(slot)
    local kc = NumberKeyCodes[slot]
    if not kc then return end
    VirtualInputManager:SendKeyEvent(true, kc, false, game)
    task.defer(function()
        VirtualInputManager:SendKeyEvent(false, kc, false, game)
    end)
end

local function EquipItemInstant(itemType, keywords, fallbackSlot)
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
        PressSlotKeyFast(fallbackSlot)
    end
    return nil
end

local function FireServerAction(remoteList, pos, targetPart, normal)
    for _, rem in ipairs(remoteList) do
        if rem and rem.Parent then
            pcall(function()
                rem:FireServer(pos, targetPart, normal or Vector3.new(0, 1, 0))
            end)
        end
    end
end

local function IsObsidianOrBedrock(part)
    if not part or not part:IsA("BasePart") then return false end
    local n = string.lower(part.Name)
    return string.find(n, "obsidian") or string.find(n, "обсидиан") or string.find(n, "bedrock") or part.Material == Enum.Material.Basalt
end

local function TriggerVerticalPop(myHrp, targetHrp)
    if not Config.AutoHitPop then return end
    if myHrp then
        myHrp.AssemblyLinearVelocity = Vector3.new(myHrp.AssemblyLinearVelocity.X, Config.HitPopPower, myHrp.AssemblyLinearVelocity.Z)
    end
    if targetHrp then
        targetHrp.AssemblyLinearVelocity = Vector3.new(targetHrp.AssemblyLinearVelocity.X, Config.HitPopPower, targetHrp.AssemblyLinearVelocity.Z)
    end
    EquipItemInstant("sword", {"sword", "blade", "mace", "меч", "клинок"}, 1)
    if targetHrp then
        FireServerAction(CachedRemotes.Attack, targetHrp.Position, targetHrp, Vector3.new(0, 1, 0))
        local tPos, tOnScreen = Camera:WorldToViewportPoint(targetHrp.Position)
        if tOnScreen and tPos.Z > 0 then
            VirtualInputManager:SendMouseButtonEvent(tPos.X, tPos.Y, 0, true, game, 1)
            task.defer(function()
                VirtualInputManager:SendMouseButtonEvent(tPos.X, tPos.Y, 0, false, game, 1)
            end)
        end
    end
end

local function DetonateCrystalPart(crystalPart)
    if not crystalPart or not crystalPart.Parent then return false end

    EquipItemInstant("sword", {"sword", "blade", "mace", "меч", "клинок"}, 1)

    local cd = crystalPart:FindFirstChildOfClass("ClickDetector")
        or (crystalPart.Parent and crystalPart.Parent:FindFirstChildWhichIsA("ClickDetector", true))
    if cd and typeof(fireclickdetector) == "function" then
        fireclickdetector(cd)
    end

    FireServerAction(CachedRemotes.Attack, crystalPart.Position, crystalPart, Vector3.new(0, 1, 0))

    local cPos, cOnScreen = Camera:WorldToViewportPoint(crystalPart.Position)
    if cOnScreen and cPos.Z > 0 then
        VirtualInputManager:SendMouseButtonEvent(cPos.X, cPos.Y, 0, true, game, 1)
        task.defer(function()
            VirtualInputManager:SendMouseButtonEvent(cPos.X, cPos.Y, 0, false, game, 1)
        end)
    end

    SpawnHitSparks(crystalPart.Position, true)
    return true
end

table.insert(Connections, Workspace.DescendantAdded:Connect(function(desc)
    if not Config.CrystalAura or Unloaded then return end
    if not (desc:IsA("BasePart") or desc:IsA("Model")) then return end

    local n = string.lower(desc.Name)
    local pName = desc.Parent and string.lower(desc.Parent.Name) or ""
    if not (string.find(n, "crystal") or string.find(pName, "crystal")) then return end

    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    local targetPlr = GetNearestEnemyInAura(Config.CrystalRange)
    local targetHrp = targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end

    task.defer(function()
        if not desc or not desc.Parent then return end
        local part = desc:IsA("BasePart") and desc or desc:FindFirstChildWhichIsA("BasePart")
        if not part then return end

        local distToEnemy = (part.Position - targetHrp.Position).Magnitude
        local distToSelf = (part.Position - myHrp.Position).Magnitude

        if distToEnemy <= 9.5 and distToSelf >= 2.5 then
            DetonateCrystalPart(part)
        end
    end)
end))

local function FindBestCrystalSetup(myHrp, targetPlr)
    local targetHrp = targetPlr.Character:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return nil, nil, nil, nil end

    local enemyVel = targetHrp.AssemblyLinearVelocity
    local flatVel = Vector3.new(enemyVel.X, 0, enemyVel.Z)
    local predictedPos = targetHrp.Position + (flatVel * 0.12)

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {targetPlr.Character, myHrp.Parent, VisualFolder}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local floorHit = Workspace:Raycast(predictedPos + Vector3.new(0, 1, 0), Vector3.new(0, -9, 0), rayParams)
    local floorBlock = floorHit and floorHit.Instance

    if floorBlock and floorBlock:IsA("BasePart") and floorBlock.Anchored and floorBlock.CanCollide then
        local gridStep = floorBlock.Size.Y
        local obsCenter = floorBlock.Position + Vector3.new(0, gridStep, 0)
        local topSurface = obsCenter + Vector3.new(0, gridStep / 2, 0)

        CrystalOverlapParams.FilterDescendantsInstances = {myHrp.Parent, targetPlr.Character, VisualFolder}
        local nearbyParts = Workspace:GetPartBoundsInRadius(obsCenter, 1.2, CrystalOverlapParams)

        for _, part in ipairs(nearbyParts) do
            if part:IsA("BasePart") and part.Anchored and part.CanCollide and IsObsidianOrBedrock(part) then
                local realTop = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
                return part, part.Position, realTop, nil
            end
        end

        return nil, obsCenter, topSurface, floorBlock
    end

    return nil, nil, nil, nil
end

local AI_Timers = {
    HitPop = 0,
    Mine = 0,
    PlaceObsidian = 0,
    PlaceCrystal = 0,
    Detonate = 0,
    StrafePhase = 0,
    ActiveObsidianTargetPos = nil,
}

local function UpdateSmartCrystalAuraAI(dt)
    if not Config.CrystalAura or Unloaded then
        HideGhostPrediction()
        return
    end

    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not myHum or myHum.Health <= 0 then
        HideGhostPrediction()
        return
    end

    local targetPlr = GetNearestEnemyInAura(Config.CrystalRange)
    if not targetPlr or not targetPlr.Character then
        HideGhostPrediction()
        return
    end

    local targetHrp = targetPlr.Character:FindFirstChild("HumanoidRootPart")
    local targetHum = targetPlr.Character:FindFirstChildOfClass("Humanoid")
    if not targetHrp or not targetHum or targetHum.Health <= 0 then
        HideGhostPrediction()
        return
    end

    local now = tick()
    local distToEnemy = (targetHrp.Position - myHrp.Position).Magnitude

    if not Config.FlyEnabled then
        local flatToEnemy = Vector3.new(targetHrp.Position.X - myHrp.Position.X, 0, targetHrp.Position.Z - myHrp.Position.Z)
        if flatToEnemy.Magnitude > 0.1 then
            local forwardDir = flatToEnemy.Unit
            if distToEnemy > 7.5 then
                myHum:Move(forwardDir, false)
            elseif Config.CombatStrafe and distToEnemy < 4.2 then
                AI_Timers.StrafePhase = AI_Timers.StrafePhase + dt * 4
                local rightDir = Vector3.new(-forwardDir.Z, 0, forwardDir.X)
                local strafeSign = math.sin(AI_Timers.StrafePhase) >= 0 and 1 or -1
                local tacticalDir = (-forwardDir * 0.7 + rightDir * strafeSign * 0.7).Unit
                myHum:Move(tacticalDir, false)
            elseif Config.CombatStrafe then
                AI_Timers.StrafePhase = AI_Timers.StrafePhase + dt * 3.5
                local rightDir = Vector3.new(-forwardDir.Z, 0, forwardDir.X)
                local strafeSign = math.sin(AI_Timers.StrafePhase) >= 0 and 1 or -1
                myHum:Move(rightDir * strafeSign, false)
            end
        end
    end

    if Config.AutoHitPop and (now - AI_Timers.HitPop) >= 0.75 and distToEnemy <= 12.0 then
        if math.abs(targetHrp.AssemblyLinearVelocity.Y) < 1.5 then
            AI_Timers.HitPop = now
            TriggerVerticalPop(myHrp, targetHrp)
        end
    end

    local obsidianBlock, obsCenterPos, topClickPos, floorBlock = FindBestCrystalSetup(myHrp, targetPlr)
    if not obsCenterPos or not topClickPos then
        HideGhostPrediction()
        return
    end

    if AI_Timers.ActiveObsidianTargetPos and (AI_Timers.ActiveObsidianTargetPos - obsCenterPos).Magnitude > 4.5 then
        AI_Timers.ActiveObsidianTargetPos = nil
    end

    UpdateGhostPrediction(topClickPos, obsidianBlock ~= nil)

    CrystalOverlapParams.FilterDescendantsInstances = {myChar, targetPlr.Character, VisualFolder}
    local partsAround = Workspace:GetPartBoundsInRadius(topClickPos + Vector3.new(0, 1.2, 0), 5.5, CrystalOverlapParams)
    for _, obj in ipairs(partsAround) do
        local n = string.lower(obj.Name)
        local pName = obj.Parent and string.lower(obj.Parent.Name) or ""
        if string.find(n, "crystal") or string.find(pName, "crystal") then
            if (now - AI_Timers.Detonate) >= 0.03 then
                AI_Timers.Detonate = now
                DetonateCrystalPart(obj)
            end
            return
        end
    end

    if obsidianBlock then
        if (now - AI_Timers.PlaceCrystal) >= Config.CrystalDelay then
            AI_Timers.PlaceCrystal = now
            AI_Timers.ActiveObsidianTargetPos = nil

            EquipItemInstant("crystal", {"crystal", "кристалл"}, Config.CrystalSlot)
            FireServerAction(CachedRemotes.Place, topClickPos, obsidianBlock, Vector3.new(0, 1, 0))

            local cScreen, cOnScreen = Camera:WorldToViewportPoint(topClickPos)
            if cOnScreen and cScreen.Z > 0 then
                VirtualInputManager:SendMouseButtonEvent(cScreen.X, cScreen.Y, 1, true, game, 1)
                task.defer(function()
                    VirtualInputManager:SendMouseButtonEvent(cScreen.X, cScreen.Y, 1, false, game, 1)
                end)
            end
        end
        return
    end

    if floorBlock and (now - AI_Timers.PlaceObsidian) >= 0.28 and AI_Timers.ActiveObsidianTargetPos ~= obsCenterPos then
        if Config.AutoMineUnder and not IsObsidianOrBedrock(floorBlock) and (now - AI_Timers.Mine) >= 0.18 then
            AI_Timers.Mine = now
            EquipItemInstant("pickaxe", {"pickaxe", "pick", "кирк"}, 4)
            FireServerAction(CachedRemotes.Break, floorBlock.Position, floorBlock, Vector3.new(0, 1, 0))
        end

        AI_Timers.PlaceObsidian = now
        AI_Timers.ActiveObsidianTargetPos = obsCenterPos

        local floorTopPos = floorBlock.Position + Vector3.new(0, floorBlock.Size.Y / 2, 0)
        EquipItemInstant("obsidian", {"obsidian", "обсидиан"}, Config.ObsidianSlot)
        FireServerAction(CachedRemotes.Place, obsCenterPos, floorBlock, Vector3.new(0, 1, 0))

        local oScreen, oOnScreen = Camera:WorldToViewportPoint(floorTopPos)
        if oOnScreen and oOnScreen.Z > 0 then
            VirtualInputManager:SendMouseButtonEvent(oScreen.X, oScreen.Y, 1, true, game, 1)
            task.defer(function()
                VirtualInputManager:SendMouseButtonEvent(oScreen.X, oScreen.Y, 1, false, game, 1)
            end)
        end
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
    Galaxy = {
        SkyboxBk = "rbxassetid://159454299",
        SkyboxDn = "rbxassetid://159454296",
        SkyboxFt = "rbxassetid://159454293",
        SkyboxLf = "rbxassetid://159454286",
        SkyboxRt = "rbxassetid://159454300",
        SkyboxUp = "rbxassetid://159454288",
        Ambient = Color3.fromRGB(145, 130, 190),
        OutdoorAmbient = Color3.fromRGB(160, 145, 210),
    },
    Sunset = {
        SkyboxBk = "rbxassetid://458016711",
        SkyboxDn = "rbxassetid://458016826",
        SkyboxFt = "rbxassetid://458016532",
        SkyboxLf = "rbxassetid://458016655",
        SkyboxRt = "rbxassetid://458016782",
        SkyboxUp = "rbxassetid://458016792",
        Ambient = Color3.fromRGB(210, 155, 130),
        OutdoorAmbient = Color3.fromRGB(225, 170, 140),
    },
    Cyber = {
        SkyboxBk = "rbxassetid://271042516",
        SkyboxDn = "rbxassetid://271077243",
        SkyboxFt = "rbxassetid://271042556",
        SkyboxLf = "rbxassetid://271042310",
        SkyboxRt = "rbxassetid://271042467",
        SkyboxUp = "rbxassetid://271077958",
        Ambient = Color3.fromRGB(130, 175, 200),
        OutdoorAmbient = Color3.fromRGB(145, 190, 215),
    }
}

local SavedOldSky = nil

local function ApplyCustomSky(enabled)
    if enabled then
        local existingSky = Lighting:FindFirstChildOfClass("Sky")
        if existingSky and existingSky.Name ~= "DevixSky" then
            SavedOldSky = existingSky:Clone()
            existingSky:Destroy()
        end

        local sky = Lighting:FindFirstChild("DevixSky") or Instance.new("Sky")
        sky.Name = "DevixSky"
        local preset = SkyPresets[Config.SkyPreset] or SkyPresets.Galaxy
        sky.SkyboxBk = preset.SkyboxBk
        sky.SkyboxDn = preset.SkyboxDn
        sky.SkyboxFt = preset.SkyboxFt
        sky.SkyboxLf = preset.SkyboxLf
        sky.SkyboxRt = preset.SkyboxRt
        sky.SkyboxUp = preset.SkyboxUp
        sky.StarCount = 3000
        sky.Parent = Lighting

        Lighting.Ambient = preset.Ambient
        Lighting.OutdoorAmbient = preset.OutdoorAmbient
    else
        local devixSky = Lighting:FindFirstChild("DevixSky")
        if devixSky then devixSky:Destroy() end
        if SavedOldSky then
            SavedOldSky.Parent = Lighting
            SavedOldSky = nil
        end
    end
end

local function ApplyRemovalsSweep()
    if not Config.RemovalsEnabled or Unloaded then return end

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Fire") or obj:IsA("Smoke") then obj.Enabled = false end
        end
    end

    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pGui then
        for _, gui in ipairs(pGui:GetDescendants()) do
            if gui:IsA("GuiObject") and gui.Visible then
                local n = string.lower(gui.Name)
                if string.find(n, "fire") or string.find(n, "burn") or string.find(n, "flame") or string.find(n, "shake") or string.find(n, "vignette") then
                    gui.Visible = false
                end
            end
        end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Fire") or obj:IsA("Smoke") then
            obj.Enabled = false
        elseif obj:IsA("ParticleEmitter") then
            local n = string.lower(obj.Name)
            local pName = obj.Parent and string.lower(obj.Parent.Name) or ""
            if string.find(n, "break") or string.find(n, "destroy") or string.find(n, "crack") or string.find(n, "debris") or string.find(pName, "break") or string.find(pName, "fire") then
                obj.Enabled = false
            end
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            local n = string.lower(obj.Name)
            if string.find(n, "crack") or string.find(n, "destroy") or string.find(n, "break") or string.find(n, "stage") then
                obj.Transparency = 1
            end
        end
    end
end

local function ApplySmartFPSBoost(enabled)
    if enabled then
        SavedLighting.GlobalShadows = Lighting.GlobalShadows
        Lighting.GlobalShadows = false
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") then
                v.Enabled = false
            end
        end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Trail") then
                obj.Enabled = false
            elseif obj:IsA("BasePart") then
                obj.CastShadow = false
            end
        end
    else
        if SavedLighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = SavedLighting.GlobalShadows
        end
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") then
                v.Enabled = true
            end
        end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Trail") then
                obj.Enabled = true
            elseif obj:IsA("BasePart") then
                obj.CastShadow = true
            end
        end
    end
end

-- ==========================================
-- CUSTOM RESOURCE PACK (8x8 PAINTER)
-- ==========================================
local GridSize = 8
local PixelGridData = {}
for y = 1, GridSize do
    PixelGridData[y] = {}
    for x = 1, GridSize do
        PixelGridData[y][x] = Color3.fromHex("#181818")
    end
end

local function ClearCustomTextures()
    for _, inst in ipairs(CustomPackInstances) do
        if inst and inst.Parent then inst:Destroy() end
    end
    CustomPackInstances = {}
end

local function ApplyPixelTextureToPart(part)
    if not part or not part:IsA("BasePart") then return end
    for _, child in ipairs(part:GetChildren()) do
        if child.Name == "DevixCustomTexture" then child:Destroy() end
    end

    local faces = {
        Enum.NormalId.Front, Enum.NormalId.Back,
        Enum.NormalId.Left, Enum.NormalId.Right,
        Enum.NormalId.Top, Enum.NormalId.Bottom,
    }

    for _, face in ipairs(faces) do
        local sGui = Instance.new("SurfaceGui")
        sGui.Name = "DevixCustomTexture"
        sGui.Face = face
        sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sGui.PixelsPerStud = 32
        sGui.Parent = part

        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 1, 0)
        container.BackgroundTransparency = 1
        container.BorderSizePixel = 0
        container.Parent = sGui

        local cellSize = 1 / GridSize
        for y = 1, GridSize do
            for x = 1, GridSize do
                local px = Instance.new("Frame")
                px.Size = UDim2.new(cellSize, 0, cellSize, 0)
                px.Position = UDim2.new((x - 1) * cellSize, 0, (y - 1) * cellSize, 0)
                px.BackgroundColor3 = PixelGridData[y][x]
                px.BorderSizePixel = 0
                px.Parent = container
            end
        end
        table.insert(CustomPackInstances, sGui)
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
CreateSlider(TabMovement, "Fly Speed", 16, 150, 42, true, function(v)
    Config.FlySpeed = v
end)

CreateSectionLabel(TabMovement, "Smooth Zero-Shake WalkSpeed (16 - 350)")
CreateToggle(TabMovement, "Custom WalkSpeed", "Плавная высокая скорость без тряски камеры (прыжки работают)", false, function(v)
    Config.SpeedEnabled = v
    if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
    end
end)
CreateSlider(TabMovement, "WalkSpeed Value (16 - 350)", 16, 350, 24, true, function(v)
    Config.WalkSpeed = v
end)

-- [2. COMBAT]
CreateSectionLabel(TabCombat, "AI Smart Crystal Aura (KitPvP Fix)")
CreateToggle(TabCombat, "Crystal Aura (AI Mind)", "Ставит обсидиан под врагом -> ставит кристалл -> взрывает", false, function(v)
    Config.CrystalAura = v
    if not v then HideGhostPrediction() end
end)
CreateToggle(TabCombat, "Surface Target Outline", "Тонкая белая рамка на грани блока куда встанет кристалл", true, function(v)
    Config.CrystalPreview = v
    if not v then HideGhostPrediction() end
end)
CreateToggle(TabCombat, "Combat Strafe (Тактический стрейф)", "Держит дистанцию 5-7 блоков и мансит вокруг врага", true, function(v)
    Config.CombatStrafe = v
end)
CreateToggle(TabCombat, "Vertical Hit-Pop (Подброс Y)", "Подбрасывает вверх без откидывания в стороны (Vector3(0, Y, 0))", true, function(v)
    Config.AutoHitPop = v
end)
CreateSlider(TabCombat, "Vertical Pop Velocity (Y)", 25, 90, 50, true, function(v)
    Config.HitPopPower = v
end)
CreateToggle(TabCombat, "Auto Mine Under Enemy", "Ломает блок под игроком для установки обсидиана", true, function(v)
    Config.AutoMineUnder = v
end)
CreateSlider(TabCombat, "Crystal Aura Range", 6, 32, 22, true, function(v)
    Config.CrystalRange = v
end)
CreateSlider(TabCombat, "Crystal Spam Delay (sec)", 0.02, 0.25, 0.04, false, function(v)
    Config.CrystalDelay = v
end)
CreateSlider(TabCombat, "Obsidian Hotbar Slot (1-9)", 1, 9, 2, true, function(v)
    Config.ObsidianSlot = v
end)
CreateSlider(TabCombat, "Crystal Hotbar Slot (1-9)", 1, 9, 3, true, function(v)
    Config.CrystalSlot = v
end)

CreateSectionLabel(TabCombat, "AttackAura (Mace / Crits)")
CreateToggle(TabCombat, "AttackAura", "Умная аура с упреждением и критами в падении", false, function(v)
    Config.AttackAura = v
end)
CreateToggle(TabCombat, "Camera Hitbox Lock", "Доводит камеру в центр хитбокса врага", false, function(v)
    Config.CameraAimLock = v
end)
CreateToggle(TabCombat, "Only Crits / Mace Fall", "Бьёт строго в падении (Y < 0) без закликивания", true, function(v)
    Config.OnlyCrits = v
end)
CreateToggle(TabCombat, "Auto Jump for Crits", "Автоматически подпрыгивает для крита", true, function(v)
    Config.AutoJumpCrits = v
end)
CreateToggle(TabCombat, "Target Follow (Бежать за целью)", "Плавное преследование противника", false, function(v)
    Config.TargetFollow = v
end)
CreateSlider(TabCombat, "Crit / Mace Cooldown (sec)", 0.45, 0.90, 0.60, false, function(v)
    Config.CritCooldown = v
end)
CreateSlider(TabCombat, "AttackAura Range", 6, 25, 16, true, function(v)
    Config.AuraRange = v
end)

CreateSectionLabel(TabCombat, "Super Upback & Manual Crystal")
CreateToggle(TabCombat, "Super Upback", "Усиленная отдача и подброс при ручном ударе", false, function(v)
    Config.SuperUpback = v
end)
CreateSlider(TabCombat, "Knockback Power", 15, 100, 45, true, function(v)
    Config.KnockbackPower = v
end)
CreateSlider(TabCombat, "Upback Height (Блоки)", 0.5, 4.0, 1.0, false, function(v)
    Config.UpbackBlocks = v
end)
CreateToggle(TabCombat, "Fast Crystal (Hold RMB)", "Ручной спам кристаллами при зажатии ПКМ по обсидиану", false, function(v)
    Config.FastCrystal = v
end)

-- [3. SKINCHANGER]
CreateSectionLabel(TabSkinChanger, "Weapon Crate Skins (Select Sword Skin)")

local SkinStatusLbl = Instance.new("TextLabel")
SkinStatusLbl.Size = UDim2.new(1, -4, 0, 22)
SkinStatusLbl.BackgroundColor3 = Theme.Card
SkinStatusLbl.Font = FontMono
SkinStatusLbl.TextSize = 11
SkinStatusLbl.TextColor3 = Theme.Text
SkinStatusLbl.Text = "ACTIVE SKIN: NONE (DEFAULT)"
SkinStatusLbl.Parent = TabSkinChanger
AddCorner(SkinStatusLbl, 5)
AddStroke(SkinStatusLbl, Theme.Border, 1)

for _, skin in ipairs(SwordSkins) do
    local sCard = Instance.new("TextButton")
    sCard.Size = UDim2.new(1, -4, 0, 56)
    sCard.BackgroundColor3 = Theme.Card
    sCard.Text = ""
    sCard.AutoButtonColor = false
    sCard.Parent = TabSkinChanger
    AddCorner(sCard, 8)
    AddStroke(sCard, Color3.fromHex(skin.AccentHex), skin.Name == "Bloodfang" and 1.5 or 1)

    local iconBox = Instance.new("Frame")
    iconBox.Size = UDim2.new(0, 40, 0, 40)
    iconBox.Position = UDim2.new(0, 8, 0.5, -20)
    iconBox.BackgroundColor3 = Theme.Bg
    iconBox.Parent = sCard
    AddCorner(iconBox, 6)
    AddStroke(iconBox, Color3.fromHex(skin.AccentHex), 1)

    local handleCol = Color3.fromHex("#3B2F2F")
    for y = 1, 8 do
        local row = skin.Pattern[y]
        for x = 1, 8 do
            local ch = string.sub(row, x, x)
            if ch ~= "0" then
                local px = Instance.new("Frame")
                px.Size = UDim2.new(0.125, 0, 0.125, 0)
                px.Position = UDim2.new((x - 1) * 0.125, 0, (y - 1) * 0.125, 0)
                px.BorderSizePixel = 0
                if ch == "1" then
                    px.BackgroundColor3 = skin.BladeColor
                elseif ch == "2" then
                    px.BackgroundColor3 = skin.EdgeColor
                else
                    px.BackgroundColor3 = handleCol
                end
                px.Parent = iconBox
            end
        end
    end

    local sName = Instance.new("TextLabel")
    sName.Size = UDim2.new(1, -140, 0, 20)
    sName.Position = UDim2.new(0, 58, 0, 8)
    sName.BackgroundTransparency = 1
    sName.Font = FontMain
    sName.TextSize = 13
    sName.TextColor3 = Theme.Text
    sName.TextXAlignment = Enum.TextXAlignment.Left
    sName.Text = skin.Name
    sName.Parent = sCard

    local sRarity = Instance.new("TextLabel")
    sRarity.Size = UDim2.new(1, -140, 0, 16)
    sRarity.Position = UDim2.new(0, 58, 0, 29)
    sRarity.BackgroundTransparency = 1
    sRarity.Font = FontMono
    sRarity.TextSize = 11
    sRarity.TextColor3 = Color3.fromHex(skin.AccentHex)
    sRarity.TextXAlignment = Enum.TextXAlignment.Left
    sRarity.Text = skin.Rarity
    sRarity.Parent = sCard

    local equipBadge = Instance.new("TextLabel")
    equipBadge.Size = UDim2.new(0, 68, 0, 22)
    equipBadge.Position = UDim2.new(1, -80, 0.5, -11)
    equipBadge.BackgroundColor3 = Theme.Bg
    equipBadge.Font = FontMono
    equipBadge.TextSize = 10
    equipBadge.TextColor3 = Theme.Text
    equipBadge.Text = "EQUIP"
    equipBadge.Parent = sCard
    AddCorner(equipBadge, 5)
    AddStroke(equipBadge, Theme.BorderActive, 1)

    sCard.MouseEnter:Connect(function()
        Tween(sCard, {BackgroundColor3 = Theme.CardHover}, 0.12)
    end)
    sCard.MouseLeave:Connect(function()
        Tween(sCard, {BackgroundColor3 = Theme.Card}, 0.12)
    end)
    sCard.MouseButton1Click:Connect(function()
        ActiveSkinData = skin
        Config.ActiveSkin = skin.Name
        SkinStatusLbl.Text = "ACTIVE SKIN: " .. string.upper(skin.Name) .. " [" .. skin.Rarity .. "]"
        ApplySwordSkinToCharacter()
    end)
end

CreateButton(TabSkinChanger, "RESET TO DEFAULT SKIN", "Убрать скин с меча и слота хотбара", function()
    ClearSwordSkin()
    Config.ActiveSkin = "None"
    SkinStatusLbl.Text = "ACTIVE SKIN: NONE (DEFAULT)"
end)

-- [4. VISUALS / PACK]
CreateSectionLabel(TabVisuals, "Atmosphere & Rich Colors")
CreateToggle(TabVisuals, "Rich Colors (Сочные цвета)", "Повышает насыщенность, контраст и мягкое свечение", false, function(v)
    Config.RichColors = v
    ColorFx.Enabled = v
    BloomFx.Enabled = v
end)
CreateSlider(TabVisuals, "Color Saturation", 0.1, 1.2, 0.45, false, function(v)
    Config.Saturation = v
    ColorFx.Saturation = v
end)
CreateToggle(TabVisuals, "Custom Sky (Красивое небо)", "Заменяет стандартное небо на выбранный пресет", false, function(v)
    Config.CustomSky = v
    ApplyCustomSky(v)
end)

local _, skyBtnTitle = CreateButton(TabVisuals, "Sky Preset: Galaxy", "Нажмите для смены (Galaxy / Sunset / Cyber)", function()
    if Config.SkyPreset == "Galaxy" then
        Config.SkyPreset = "Sunset"
    elseif Config.SkyPreset == "Sunset" then
        Config.SkyPreset = "Cyber"
    else
        Config.SkyPreset = "Galaxy"
    end
    skyBtnTitle.Text = "Sky Preset: " .. Config.SkyPreset
    if Config.CustomSky then ApplyCustomSky(true) end
end)

CreateSectionLabel(TabVisuals, "Removals & Optimization")
CreateToggle(TabVisuals, "Removals (Clean Screen)", "Убирает тряску рук/камеры, огонь на экране/полу и ломание блоков", false, function(v)
    Config.RemovalsEnabled = v
    if v then ApplyRemovalsSweep() end
end)
CreateToggle(TabVisuals, "Smart FPS Boost", "Буст FPS без порчи и размытия текстур", false, function(v)
    Config.SmartFPSBoost = v
    ApplySmartFPSBoost(v)
end)

CreateSectionLabel(TabVisuals, "Target Visuals")
CreateToggle(TabVisuals, "Target ESP Box", "Квадрат и инфо на ближайшей цели", true, function(v)
    Config.TargetESP = v
    if not v then TargetBox.Visible = false end
end)
CreateToggle(TabVisuals, "Target Aura Ring", "Светящееся кольцо вокруг захваченной цели", true, function(v)
    Config.TargetRing = v
    if not v then
        TargetRingPart.Transparency = 1
        TargetInnerRing.Transparency = 1
    end
end)
CreateToggle(TabVisuals, "Hit Sparks Effect", "Вспышка искр при критическом ударе", true, function(v)
    Config.HitSparks = v
end)

CreateSectionLabel(TabVisuals, "Custom Resource Pack (8x8 Texture Painter)")

local PainterCard = Instance.new("Frame")
PainterCard.Size = UDim2.new(1, -4, 0, 245)
PainterCard.BackgroundColor3 = Theme.Card
PainterCard.Parent = TabVisuals
AddCorner(PainterCard, 8)
AddStroke(PainterCard, Theme.Border, 1)

local PainterHeader = Instance.new("TextLabel")
PainterHeader.Size = UDim2.new(1, -24, 0, 20)
PainterHeader.Position = UDim2.new(0, 12, 0, 8)
PainterHeader.BackgroundTransparency = 1
PainterHeader.Font = FontMain
PainterHeader.TextSize = 12
PainterHeader.TextColor3 = Theme.Text
PainterHeader.TextXAlignment = Enum.TextXAlignment.Left
PainterHeader.Text = "Нарисуйте текстуру (зажмите ЛКМ на сетке)"
PainterHeader.Parent = PainterCard

local CanvasFrame = Instance.new("Frame")
CanvasFrame.Size = UDim2.new(0, 160, 0, 160)
CanvasFrame.Position = UDim2.new(0, 12, 0, 34)
CanvasFrame.BackgroundColor3 = Theme.Bg
CanvasFrame.Parent = PainterCard
AddStroke(CanvasFrame, Theme.BorderActive, 1)

local IsPainting = false
local CellButtons = {}

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then IsPainting = false end
end))

for y = 1, GridSize do
    CellButtons[y] = {}
    for x = 1, GridSize do
        local cell = Instance.new("TextButton")
        cell.Size = UDim2.new(1 / GridSize, -1, 1 / GridSize, -1)
        cell.Position = UDim2.new((x - 1) / GridSize, 0, (y - 1) / GridSize, 0)
        cell.BackgroundColor3 = PixelGridData[y][x]
        cell.BorderSizePixel = 0
        cell.Text = ""
        cell.AutoButtonColor = false
        cell.Parent = CanvasFrame

        local function PaintCell()
            PixelGridData[y][x] = Config.BrushColor
            cell.BackgroundColor3 = Config.BrushColor
        end

        cell.MouseButton1Down:Connect(function() IsPainting = true; PaintCell() end)
        cell.MouseEnter:Connect(function() if IsPainting then PaintCell() end end)
        CellButtons[y][x] = cell
    end
end

local PaletteHolder = Instance.new("Frame")
PaletteHolder.Size = UDim2.new(1, -192, 0, 160)
PaletteHolder.Position = UDim2.new(0, 182, 0, 34)
PaletteHolder.BackgroundTransparency = 1
PaletteHolder.Parent = PainterCard

local PaletteColors = {
    {Name = "White",  Hex = "#FFFFFF"},
    {Name = "Silver", Hex = "#B0B0B0"},
    {Name = "Gray",   Hex = "#555555"},
    {Name = "Dark",   Hex = "#181818"},
    {Name = "Black",  Hex = "#030303"},
    {Name = "Cyan",   Hex = "#5CE1E6"},
    {Name = "Red",    Hex = "#FF4D4D"},
    {Name = "Gold",   Hex = "#FFD166"},
}

local ColorGrid = Instance.new("UIGridLayout")
ColorGrid.CellSize = UDim2.new(0, 52, 0, 26)
ColorGrid.CellPadding = UDim2.new(0, 6, 0, 6)
ColorGrid.Parent = PaletteHolder

for _, colData in ipairs(PaletteColors) do
    local cBtn = Instance.new("TextButton")
    cBtn.BackgroundColor3 = Color3.fromHex(colData.Hex)
    cBtn.Font = FontMono
    cBtn.TextSize = 10
    cBtn.Text = colData.Name
    cBtn.TextColor3 = (colData.Name == "White" or colData.Name == "Silver" or colData.Name == "Cyan" or colData.Name == "Gold") and Theme.Bg or Theme.Text
    cBtn.Parent = PaletteHolder
    AddCorner(cBtn, 5)
    AddStroke(cBtn, Theme.BorderActive, 1)
    cBtn.MouseButton1Click:Connect(function() Config.BrushColor = Color3.fromHex(colData.Hex) end)
end

local ApplyCursorBtn = Instance.new("TextButton")
ApplyCursorBtn.Size = UDim2.new(0, 130, 0, 30)
ApplyCursorBtn.Position = UDim2.new(0, 12, 1, -40)
ApplyCursorBtn.BackgroundColor3 = Theme.Accent
ApplyCursorBtn.Font = FontMain
ApplyCursorBtn.TextSize = 11
ApplyCursorBtn.TextColor3 = Theme.Bg
ApplyCursorBtn.Text = "На блок под прицелом"
ApplyCursorBtn.Parent = PainterCard
AddCorner(ApplyCursorBtn, 6)
ApplyCursorBtn.MouseButton1Click:Connect(function()
    if Mouse.Target and Mouse.Target:IsA("BasePart") then ApplyPixelTextureToPart(Mouse.Target) end
end)

local FillClearBtn = Instance.new("TextButton")
FillClearBtn.Size = UDim2.new(0, 130, 0, 30)
FillClearBtn.Position = UDim2.new(0, 150, 1, -40)
FillClearBtn.BackgroundColor3 = Theme.Header
FillClearBtn.Font = FontMono
FillClearBtn.TextSize = 11
FillClearBtn.TextColor3 = Theme.SubText
FillClearBtn.Text = "Сброс текстур"
FillClearBtn.Parent = PainterCard
AddCorner(FillClearBtn, 6)
AddStroke(FillClearBtn, Theme.Border, 1)
FillClearBtn.MouseButton1Click:Connect(function()
    ClearCustomTextures()
    for y = 1, GridSize do
        for x = 1, GridSize do
            PixelGridData[y][x] = Color3.fromHex("#181818")
            CellButtons[y][x].BackgroundColor3 = PixelGridData[y][x]
        end
    end
end)

-- [5. INFO]
CreateSectionLabel(TabInfo, "Client & Keybinds")
local InfoCard = Instance.new("Frame")
InfoCard.Size = UDim2.new(1, -4, 0, 185)
InfoCard.BackgroundColor3 = Theme.Card
InfoCard.Parent = TabInfo
AddCorner(InfoCard, 8)
AddStroke(InfoCard, Theme.Border, 1)

local InfoText = Instance.new("TextLabel")
InfoText.Size = UDim2.new(1, -24, 1, -20)
InfoText.Position = UDim2.new(0, 12, 0, 10)
InfoText.BackgroundTransparency = 1
InfoText.Font = FontMono
InfoText.TextSize = 11
InfoText.TextColor3 = Theme.Text
InfoText.TextXAlignment = Enum.TextXAlignment.Left
InfoText.TextYAlignment = Enum.TextYAlignment.Top
InfoText.TextWrapped = true
InfoText.Text = string.format(
    "CLIENT   :: Devix hub LAST (BETA)\nPLAN     :: %s\nUSER     :: %s (@%s)\n\nTOGGLE KEYBINDS:\n1. Нажмите КОЛЁСИКОМ МЫШИ по функции.\n2. Нажмите любую клавишу (например, R).\n3. Одно нажатие R включает функцию, повторное R — выключает.",
    Config.Plan, LocalPlayer.DisplayName, LocalPlayer.Name
)
InfoText.Parent = InfoCard

CreateToggle(TabInfo, "Watermark HUD", "Верхняя панель с пингом и статусом", true, function(v)
    Config.Watermark = v
    WatermarkFrame.Visible = v
end)

-- [6. PANIC / CLEAR]
CreateSectionLabel(TabPanic, "Emergency Unload")
local function UnloadScript()
    if Unloaded then return end
    Unloaded = true
    Config.FastCrystal = false
    Config.CrystalAura = false
    Config.SpeedEnabled = false
    Config.SuperUpback = false
    Config.RemovalsEnabled = false
    Config.FlyEnabled = false
    Config.AttackAura = false
    Config.TargetFollow = false

    StopSmoothFly()
    ClearSwordSkin()
    ApplyCustomSky(false)
    if Config.SmartFPSBoost then ApplySmartFPSBoost(false) end
    if ColorFx then ColorFx:Destroy() end
    if BloomFx then BloomFx:Destroy() end
    ClearCustomTextures()

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 end

    if VisualFolder then VisualFolder:Destroy() end

    for _, conn in ipairs(Connections) do
        if conn.Connected then conn:Disconnect() end
    end

    if ScreenGui then ScreenGui:Destroy() end
end

CreateButton(TabPanic, "PANIC / CLEAR UNLOAD", "Выключить все функции, вернуть небо и закрыть меню", UnloadScript)

SelectTab("Combat")

-- ==========================================
-- ЛОГИКА: SUPER UPBACK
-- ==========================================
local LastUpbackTime = 0

local function ExecuteSuperUpback(targetPlr)
    if not Config.SuperUpback or Unloaded then return end
    if (tick() - LastUpbackTime) < 0.25 then return end

    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

    local targetChar = targetPlr and targetPlr.Character
    local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

    if not myHrp or not myHum or not targetHrp or not targetHum or targetHum.Health <= 0 then return end
    if (targetHrp.Position - myHrp.Position).Magnitude > Config.HitRange then return end

    LastUpbackTime = tick()

    local prevSpeed = myHum.WalkSpeed
    myHum.WalkSpeed = 0
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)

    local dirToTarget = (targetHrp.Position - myHrp.Position) * Vector3.new(1, 0, 1)
    if dirToTarget.Magnitude > 0.01 then
        dirToTarget = dirToTarget.Unit
    else
        dirToTarget = myHrp.CFrame.LookVector * Vector3.new(1, 0, 1)
    end

    local upVel = math.sqrt(2 * Workspace.Gravity * (Config.UpbackBlocks * 4.2))
    myHrp.AssemblyLinearVelocity = (dirToTarget * Config.KnockbackPower) + Vector3.new(0, upVel * 0.45, 0)
    targetHrp.AssemblyLinearVelocity = (dirToTarget * Config.KnockbackPower) + Vector3.new(0, upVel, 0)

    SpawnHitSparks(targetHrp.Position, false)

    task.delay(0.04, function()
        if myHum and myHum.Parent then
            myHum.WalkSpeed = Config.SpeedEnabled and Config.WalkSpeed or prevSpeed
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
            end
        end
    end)
end

-- ==========================================
-- ЛОГИКА: INPUT & FAST CRYSTAL
-- ==========================================
local IsHoldingRMB = false
local CrystalBusy = false

table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if ListeningBindTarget and input.UserInputType == Enum.UserInputType.Keyboard then
        local target = ListeningBindTarget
        ListeningBindTarget = nil
        target.OnBind(input.KeyCode)
        return
    end

    if input.KeyCode == Config.ToggleKey then
        Config.MenuOpen = not Config.MenuOpen
        MainFrame.Visible = Config.MenuOpen
    end

    if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard then
        local bindData = Keybinds[input.KeyCode]
        if bindData then
            bindData.Toggle()
        end
    end

    if not gameProcessed then
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            IsHoldingRMB = true
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            if Config.SuperUpback and CurrentTargetPlayer then
                ExecuteSuperUpback(CurrentTargetPlayer)
            end
        end
    end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        IsHoldingRMB = false
    end
end))

local function IsLookingAtObsidian()
    local target = Mouse.Target
    if not target then return false, nil end
    local name = string.lower(target.Name)
    if string.find(name, "obsidian") or string.find(name, "обсидиан") or target.Material == Enum.Material.Basalt then
        return true, target
    end
    return false, target
end

local function TriggerCrystalCycle()
    if CrystalBusy or Unloaded then return end
    local isObs, targetBlock = IsLookingAtObsidian()
    if not isObs or not targetBlock then return end

    CrystalBusy = true
    local mousePos = UserInputService:GetMouseLocation()

    for i = 1, Config.CrystalsPerCycle do
        if not IsHoldingRMB or not Config.FastCrystal or Unloaded then break end

        VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, true, game, 1)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, false, game, 1)

        task.wait(Config.CrystalDelay)

        CrystalOverlapParams.FilterDescendantsInstances = {LocalPlayer.Character, VisualFolder}
        local nearCrystals = Workspace:GetPartBoundsInRadius(targetBlock.Position, 7, CrystalOverlapParams)
        for _, obj in ipairs(nearCrystals) do
            local checkName = string.lower(obj.Name)
            local parentName = obj.Parent and string.lower(obj.Parent.Name) or ""
            if string.find(checkName, "crystal") or string.find(parentName, "crystal") then
                local cd = obj:FindFirstChildOfClass("ClickDetector") or (obj.Parent and obj.Parent:FindFirstChildWhichIsA("ClickDetector", true))
                if cd and typeof(fireclickdetector) == "function" then
                    fireclickdetector(cd)
                end
                break
            end
        end

        VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 1)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 1)

        task.wait(Config.CrystalDelay)
    end

    CrystalBusy = false
end

-- ==========================================
-- ОСНОВНОЙ ЦИКЛ: FLY, ATTACKAURA, AI CRYSTAL AURA
-- ==========================================
local function GetClosestTargetToCursor()
    local mouseLoc = UserInputService:GetMouseLocation()
    local closestPlayer = nil
    local shortestDist = 350

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        closestPlayer = plr
                    end
                end
            end
        end
    end
    return closestPlayer
end

local RingAngle = 0
local RemovalTimer = 0
local SkinRefreshTimer = 0

table.insert(Connections, RunService.Heartbeat:Connect(function(dt)
    if Unloaded then return end

    if Config.FlyEnabled then
        UpdateSmoothFly()
    end

    if Config.AttackAura then
        ProcessAttackAura(dt)
    end

    UpdateSmartCrystalAuraAI(dt)
end))

table.insert(Connections, RunService.RenderStepped:Connect(function(dt)
    if Unloaded then return end

    if Config.SpeedEnabled and not Config.FlyEnabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.CameraOffset = Vector3.zero
            hum.WalkSpeed = Config.WalkSpeed
        end
    end

    if Config.Watermark then
        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        WatermarkLabel.Text = string.format("DEVIX HUB LAST (BETA)  |  %s MS", ping)
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
                local topPos, onScreenTop = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
                local botPos, onScreenBot = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

                if onScreenTop and onScreenBot then
                    local height = math.abs(botPos.Y - topPos.Y)
                    local width = height * 0.65

                    TargetBox.Size = UDim2.new(0, width, 0, height)
                    TargetBox.Position = UDim2.new(0, topPos.X - width / 2, 0, topPos.Y)
                    TargetBox.Visible = true

                    local distStuds = 0
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        distStuds = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
                    end

                    TargetInfoTag.Text = string.format("%s [%d HP] • %dm", CurrentTargetPlayer.Name, math.floor(hum.Health), distStuds)
                    TargetInfoTag.Size = UDim2.new(0, TargetInfoTag.TextBounds.X + 14, 0, 20)
                    TargetInfoTag.Position = UDim2.new(0.5, -TargetInfoTag.Size.X.Offset / 2, 0, -26)
                else
                    TargetBox.Visible = false
                end
            else
                TargetBox.Visible = false
            end

            if Config.TargetRing then
                RingAngle = RingAngle + dt * 3
                local bobOffset = math.sin(RingAngle * 1.5) * 0.25
                local ringCF = CFrame.new(hrp.Position - Vector3.new(0, 2.7 - bobOffset, 0)) * CFrame.Angles(0, RingAngle, math.rad(90))
                TargetRingPart.CFrame = ringCF
                TargetInnerRing.CFrame = ringCF
                TargetRingPart.Transparency = 0.2
                TargetInnerRing.Transparency = 0.4
            else
                TargetRingPart.Transparency = 1
                TargetInnerRing.Transparency = 1
            end
        end
    else
        TargetBox.Visible = false
        TargetRingPart.Transparency = 1
        TargetInnerRing.Transparency = 1
    end

    if ActiveSkinData then
        SkinRefreshTimer = SkinRefreshTimer + dt
        if SkinRefreshTimer >= 0.2 then
            SkinRefreshTimer = 0
            ApplySwordSkinToCharacter()
        end
    end

    if Config.RemovalsEnabled then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
        end
        RemovalTimer = RemovalTimer + dt
        if RemovalTimer >= 0.25 then
            RemovalTimer = 0
            ApplyRemovalsSweep()
        end
    end

    if Config.FastCrystal and IsHoldingRMB and not CrystalBusy then
        task.spawn(TriggerCrystalCycle)
    end
end))
