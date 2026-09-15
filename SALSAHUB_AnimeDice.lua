--[[
    SALSAHUB V5 | Anime Dice
    UI refresh + mobile-first layout.
    Self-contained, no external UI library.

    Notes:
    - Keeps the V4 automation behavior and safety checks.
    - All automation features start OFF.
    - Designed for touch/mobile executors with responsive scaling.
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
if not LP then
    warn("[SALSAHUB] LocalPlayer belum tersedia")
    return
end

local PG = LP:WaitForChild("PlayerGui", 15)
if not PG then
    warn("[SALSAHUB] PlayerGui belum tersedia")
    return
end

-- ============================================================
-- UI parent selection
-- ============================================================
local uiRoots = {}
local function addRoot(root, label)
    if typeof(root) ~= "Instance" then return end
    for _, entry in ipairs(uiRoots) do
        if entry.root == root then return end
    end
    table.insert(uiRoots, {root = root, label = label})
end

addRoot(PG, "PlayerGui")
if type(gethui) == "function" then
    local ok, root = pcall(gethui)
    if ok then addRoot(root, "gethui") end
end
pcall(function()
    addRoot(game:GetService("CoreGui"), "CoreGui")
end)

local uiParent, uiParentName
for _, entry in ipairs(uiRoots) do
    local probe = Instance.new("ScreenGui")
    local ok = pcall(function()
        probe.Name = "SALSAHUB_Probe"
        probe.Enabled = false
        probe.Parent = entry.root
    end)
    probe:Destroy()
    if ok then
        uiParent = entry.root
        uiParentName = entry.label
        break
    end
end

if not uiParent then
    warn("[SALSAHUB] Tidak ada parent GUI yang didukung")
    return
end

for _, entry in ipairs(uiRoots) do
    pcall(function()
        local old = entry.root:FindFirstChild("SALSAHUB")
        if old then
            local unload = old:FindFirstChild("Unload")
            if unload and unload:IsA("BindableEvent") then
                unload:Fire()
            else
                old:Destroy()
            end
        end
    end)
end

-- ============================================================
-- Runtime state
-- ============================================================
local alive = true
local ready = false
local connections = {}
local toggles = {}
local pending = nil

local state = {
    Roll = false,
    Rarity = false,
    Equip = false,
    Upgrade = false,
    Level = false,
}

local config = {
    RollDelay = 0.75,
    RarityLimit = 0,
    Reserve = 0,
    MaxLevel = 50,
    EquipDelay = 10,
}

local api = {}
local nativeRollBefore, rarityBefore, lastRaritySent
local nativeRollChanged = false
local logs = {"Build V5 | GUI parent: " .. tostring(uiParentName)}

local function on(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function make(className, props, parent)
    local o = Instance.new(className)
    for k, v in pairs(props or {}) do
        o[k] = v
    end
    o.Parent = parent
    return o
end

local function safeNumber(value)
    return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

-- ============================================================
-- Theme
-- ============================================================
local C = {
    bg = Color3.fromRGB(15, 13, 22),
    panel = Color3.fromRGB(22, 19, 31),
    panel2 = Color3.fromRGB(29, 25, 40),
    card = Color3.fromRGB(34, 29, 47),
    cardHover = Color3.fromRGB(40, 34, 55),
    accent = Color3.fromRGB(178, 115, 255),
    accent2 = Color3.fromRGB(117, 82, 225),
    accentSoft = Color3.fromRGB(75, 50, 104),
    text = Color3.fromRGB(246, 242, 255),
    muted = Color3.fromRGB(173, 164, 192),
    faint = Color3.fromRGB(119, 111, 135),
    green = Color3.fromRGB(92, 214, 151),
    red = Color3.fromRGB(240, 103, 120),
    amber = Color3.fromRGB(244, 184, 86),
    stroke = Color3.fromRGB(60, 52, 78),
}

local function corner(parent, radius)
    return make("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, parent)
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Color = color or C.stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function padding(parent, l, r, t, b)
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
    }, parent)
end

local function label(parent, text, size, pos, fontSize, color, font)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        Size = size or UDim2.new(1, 0, 0, 20),
        Position = pos or UDim2.new(),
        TextColor3 = color or C.text,
        TextSize = fontSize or 13,
        Font = font or Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        BorderSizePixel = 0,
    }, parent)
end

local function button(parent, text, size, pos)
    local b = make("TextButton", {
        AutoButtonColor = false,
        Text = text or "",
        Size = size or UDim2.new(1, 0, 0, 36),
        Position = pos or UDim2.new(),
        BackgroundColor3 = C.card,
        TextColor3 = C.text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        BorderSizePixel = 0,
    }, parent)
    corner(b, 10)
    stroke(b, C.stroke, 1, 0.25)
    return b
end

local function tween(obj, duration, props)
    local ok, tw = pcall(function()
        return TweenService:Create(
            obj,
            TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            props
        )
    end)
    if ok and tw then tw:Play() end
end

-- ============================================================
-- Main UI
-- ============================================================
local gui = make("ScreenGui", {
    Name = "SALSAHUB",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    Enabled = true,
    DisplayOrder = 2147483645,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, uiParent)

local unloadEvent = make("BindableEvent", {Name = "Unload"}, gui)

local shadow = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.505),
    Size = UDim2.fromOffset(396, 486),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    ZIndex = 0,
}, gui)
corner(shadow, 20)

local frame = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(390, 480),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 1,
}, gui)
corner(frame, 18)
stroke(frame, C.stroke, 1, 0.1)

local bgGradient = make("UIGradient", {
    Rotation = 120,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 17, 31)),
        ColorSequenceKeypoint.new(0.55, C.bg),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 12, 19)),
    }),
}, frame)

local scale = make("UIScale", {Scale = 1}, frame)
local shadowScale = make("UIScale", {Scale = 1}, shadow)

local function resize()
    local camera = workspace.CurrentCamera
    local v = camera and camera.ViewportSize or Vector2.new(800, 600)
    local s = math.clamp(math.min((v.X - 18) / 390, (v.Y - 18) / 480), 0.62, 1)
    scale.Scale = s
    shadowScale.Scale = s
end

resize()
on(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    task.wait()
    resize()
end)
if workspace.CurrentCamera then
    on(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), resize)
end

-- Header
local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 66),
    BackgroundTransparency = 1,
    Active = true,
    ZIndex = 3,
}, frame)

local logo = make("Frame", {
    Position = UDim2.fromOffset(14, 13),
    Size = UDim2.fromOffset(40, 40),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
    ZIndex = 4,
}, header)
corner(logo, 12)
make("UIGradient", {
    Rotation = 45,
    Color = ColorSequence.new(C.accent, C.accent2),
}, logo)
local logoText = label(logo, "S", UDim2.fromScale(1, 1), UDim2.new(), 18, C.text, Enum.Font.GothamBold)
logoText.TextXAlignment = Enum.TextXAlignment.Center
logoText.ZIndex = 5

local brand = label(header, "SALSAHUB", UDim2.fromOffset(210, 24), UDim2.fromOffset(64, 11), 16, C.text, Enum.Font.GothamBold)
brand.ZIndex = 4
local subtitle = label(header, "Anime Dice  •  V5", UDim2.fromOffset(210, 20), UDim2.fromOffset(64, 34), 11, C.muted, Enum.Font.GothamMedium)
subtitle.ZIndex = 4

local mini = button(header, "—", UDim2.fromOffset(36, 36), UDim2.fromOffset(300, 15))
mini.BackgroundColor3 = C.panel2
mini.TextSize = 16
mini.ZIndex = 4

local close = button(header, "×", UDim2.fromOffset(36, 36), UDim2.fromOffset(340, 15))
close.BackgroundColor3 = C.panel2
close.TextColor3 = C.red
close.TextSize = 20
close.ZIndex = 4

local divider = make("Frame", {
    Position = UDim2.fromOffset(14, 65),
    Size = UDim2.new(1, -28, 0, 1),
    BackgroundColor3 = C.stroke,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    ZIndex = 3,
}, frame)

-- Tabs
local tabsBar = make("Frame", {
    Position = UDim2.fromOffset(14, 77),
    Size = UDim2.new(1, -28, 0, 42),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    ZIndex = 3,
}, frame)
corner(tabsBar, 12)
stroke(tabsBar, C.stroke, 1, 0.35)
padding(tabsBar, 4, 4, 4, 4)

local tabLayout = make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabsBar)

local pages = {}
local tabs = {}
local activePage = "Otomatis"

local tabInfo = {
    {"Otomatis", "AUTO"},
    {"Pengaturan", "SETTING"},
    {"Diagnostik", "DEBUG"},
}

local content = make("Frame", {
    Position = UDim2.fromOffset(14, 130),
    Size = UDim2.new(1, -28, 0, 258),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    ZIndex = 2,
}, frame)

for i, info in ipairs(tabInfo) do
    local name, display = info[1], info[2]
    local b = button(tabsBar, display, UDim2.new(1 / 3, -6, 1, 0), UDim2.new())
    b.LayoutOrder = i
    b.BackgroundColor3 = i == 1 and C.accentSoft or C.panel
    b.TextColor3 = i == 1 and C.text or C.muted
    b.ZIndex = 4
    tabs[name] = b

    local page = make("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.new(),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.accent,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = i == 1,
        ZIndex = 2,
    }, content)
    padding(page, 0, 4, 0, 8)
    make("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    pages[name] = page
end

local function switchPage(name)
    activePage = name
    for n, p in pairs(pages) do
        p.Visible = (n == name)
        local b = tabs[n]
        if b then
            tween(b, 0.15, {
                BackgroundColor3 = n == name and C.accentSoft or C.panel,
                TextColor3 = n == name and C.text or C.muted,
            })
        end
    end
end

for name, b in pairs(tabs) do
    on(b.Activated, function()
        switchPage(name)
    end)
end

local function sectionTitle(page, titleText, subText)
    local wrap = make("Frame", {
        Size = UDim2.new(1, -2, 0, subText and 48 or 28),
        BackgroundTransparency = 1,
    }, page)
    local t = label(wrap, titleText, UDim2.new(1, 0, 0, 22), UDim2.new(), 14, C.text, Enum.Font.GothamBold)
    if subText then
        local s = label(wrap, subText, UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 24), 10, C.faint, Enum.Font.GothamMedium)
        s.TextWrapped = true
    end
    return wrap
end

local function infoCard(page, textValue, tone)
    local card = make("Frame", {
        Size = UDim2.new(1, -2, 0, 52),
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
    }, page)
    corner(card, 12)
    stroke(card, tone or C.stroke, 1, 0.45)
    local dot = make("Frame", {
        Position = UDim2.fromOffset(12, 13),
        Size = UDim2.fromOffset(6, 26),
        BackgroundColor3 = tone or C.accent,
        BorderSizePixel = 0,
    }, card)
    corner(dot, 4)
    local t = label(card, textValue, UDim2.new(1, -36, 1, -12), UDim2.fromOffset(28, 6), 10, C.muted, Enum.Font.GothamMedium)
    t.TextWrapped = true
    t.TextYAlignment = Enum.TextYAlignment.Center
    return card
end

-- Footer / status
local footer = make("Frame", {
    Position = UDim2.fromOffset(14, 399),
    Size = UDim2.new(1, -28, 0, 67),
    BackgroundTransparency = 1,
    ZIndex = 3,
}, frame)

local statusCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 27),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, footer)
corner(statusCard, 9)
stroke(statusCard, C.stroke, 1, 0.4)

local statusDot = make("Frame", {
    Position = UDim2.fromOffset(9, 9),
    Size = UDim2.fromOffset(9, 9),
    BackgroundColor3 = C.amber,
    BorderSizePixel = 0,
}, statusCard)
corner(statusDot, 10)

local status = label(statusCard, "Menyiapkan modul...", UDim2.new(1, -34, 1, 0), UDim2.fromOffset(26, 0), 10, C.muted, Enum.Font.GothamMedium)
status.TextTruncate = Enum.TextTruncate.AtEnd

local stopButton = button(footer, "STOP SEMUA", UDim2.new(0.5, -4, 0, 32), UDim2.fromOffset(0, 35))
stopButton.BackgroundColor3 = Color3.fromRGB(72, 35, 48)
stopButton.TextColor3 = Color3.fromRGB(255, 188, 199)

local unloadButton = button(footer, "UNLOAD", UDim2.new(0.5, -4, 0, 32), UDim2.new(0.5, 4, 0, 35))
unloadButton.BackgroundColor3 = C.panel2
unloadButton.TextColor3 = C.muted

local function log(message)
    message = tostring(message)
    table.insert(logs, os.date("%H:%M:%S") .. " | " .. message)
    if #logs > 60 then table.remove(logs, 1) end
    if alive and status and status.Parent then
        status.Text = message
    end
end

local function setReadyVisual(isReady)
    tween(statusDot, 0.2, {BackgroundColor3 = isReady and C.green or C.amber})
end

-- ============================================================
-- Toggle UI
-- ============================================================
local toggleDescriptions = {
    Roll = "Roll otomatis tanpa menunggu animasi visual.",
    Rarity = "Pakai batas 1 in X dari menu setting.",
    Equip = "Tekan Equip Best secara berkala.",
    Upgrade = "Beli upgrade tree yang terjangkau.",
    Level = "Level-up unit base sampai batas yang dipilih.",
}

local toggleNames = {
    Roll = "Auto Roll",
    Rarity = "Auto Sell Rarity",
    Equip = "Auto Equip Best",
    Upgrade = "Auto Upgrade Tree",
    Level = "Auto Level Base",
}

local function createToggle(page, key)
    local card = make("TextButton", {
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.new(1, -2, 0, 58),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, page)
    corner(card, 12)
    local cardStroke = stroke(card, C.stroke, 1, 0.25)

    local name = label(card, toggleNames[key], UDim2.new(1, -90, 0, 22), UDim2.fromOffset(13, 8), 12, C.text, Enum.Font.GothamSemibold)
    local desc = label(card, toggleDescriptions[key], UDim2.new(1, -90, 0, 18), UDim2.fromOffset(13, 31), 9, C.muted, Enum.Font.GothamMedium)
    desc.TextTruncate = Enum.TextTruncate.AtEnd

    local track = make("Frame", {
        Position = UDim2.new(1, -64, 0.5, -13),
        Size = UDim2.fromOffset(50, 26),
        BackgroundColor3 = Color3.fromRGB(62, 56, 73),
        BorderSizePixel = 0,
    }, card)
    corner(track, 20)

    local knob = make("Frame", {
        Position = UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(20, 20),
        BackgroundColor3 = C.muted,
        BorderSizePixel = 0,
    }, track)
    corner(knob, 20)

    toggles[key] = {
        button = card,
        track = track,
        knob = knob,
        stroke = cardStroke,
    }

    on(card.MouseEnter, function()
        if not state[key] then tween(card, 0.12, {BackgroundColor3 = C.cardHover}) end
    end)
    on(card.MouseLeave, function()
        if not state[key] then tween(card, 0.12, {BackgroundColor3 = C.card}) end
    end)

    return card
end

local function repaint(key)
    local t = toggles[key]
    if not t then return end

    local enabled = state[key]
    tween(t.button, 0.16, {BackgroundColor3 = enabled and Color3.fromRGB(47, 35, 63) or C.card})
    tween(t.track, 0.16, {BackgroundColor3 = enabled and C.accent or Color3.fromRGB(62, 56, 73)})
    tween(t.knob, 0.16, {
        Position = enabled and UDim2.fromOffset(27, 3) or UDim2.fromOffset(3, 3),
        BackgroundColor3 = enabled and C.text or C.muted,
    })
    tween(t.stroke, 0.16, {Color = enabled and C.accent or C.stroke, Transparency = enabled and 0.1 or 0.25})
end

local function disable(key, message)
    state[key] = false
    repaint(key)
    if message then log(message) end
end

local function restoreRarity()
    if rarityBefore == nil then return end
    local old = rarityBefore
    rarityBefore = nil
    if api.Data and api.Data.AutoSell and api.AutoSell and api.Data.AutoSell() == lastRaritySent then
        api.AutoSell:Fire(old)
    end
    lastRaritySent = nil
end

local function restoreRoll()
    if not nativeRollChanged then return end
    nativeRollChanged = false
    if api.Data and api.Data.AutoRoll and api.NativeAutoRoll and api.Data.AutoRoll() == false then
        api.NativeAutoRoll:Fire(nativeRollBefore)
    end
end

local function toggleFeature(key)
    if not ready then
        log("Modul belum siap; tunggu status hijau")
        return
    end

    if key == "Roll" and not state.Roll then
        if not nativeRollChanged then nativeRollBefore = api.Data.AutoRoll() end
        if type(nativeRollBefore) ~= "boolean" then error("Data AutoRoll belum siap") end
        nativeRollChanged = true
        api.NativeAutoRoll:Fire(false)
        state.Roll = true
        log("Auto Roll ON")

    elseif key == "Roll" then
        state.Roll = false
        log("Auto Roll OFF")

    elseif key == "Rarity" and not state.Rarity then
        if config.RarityLimit <= 0 then
            log("Isi batas rarity 1 in X dulu di Setting")
            return
        end
        rarityBefore = api.Data.AutoSell()
        if not safeNumber(rarityBefore) then
            rarityBefore = nil
            error("Data AutoSell belum siap")
        end
        lastRaritySent = config.RarityLimit
        api.AutoSell:Fire(lastRaritySent)
        state.Rarity = true
        log("Auto Sell rarity ON • 1 in " .. tostring(lastRaritySent))

    elseif key == "Rarity" then
        state.Rarity = false
        restoreRarity()
        log("Auto Sell rarity OFF")

    elseif key == "Equip" and not state.Equip and type(firesignal) ~= "function" then
        log("Auto Equip tidak tersedia: firesignal tidak didukung")
        return

    else
        state[key] = not state[key]
        log(toggleNames[key] .. (state[key] and " ON" or " OFF"))
    end

    repaint(key)
end

-- ============================================================
-- AUTO PAGE
-- ============================================================
sectionTitle(pages.Otomatis, "Automation", "Aktifkan hanya fitur yang kamu butuhkan.")
for _, key in ipairs({"Roll", "Rarity", "Equip", "Upgrade", "Level"}) do
    local card = createToggle(pages.Otomatis, key)
    on(card.Activated, function()
        local ok, err = pcall(toggleFeature, key)
        if not ok then
            disable(key, "Error " .. key .. ": " .. tostring(err))
        end
    end)
    repaint(key)
end
infoCard(pages.Otomatis, "Semua fitur selalu mulai OFF. Upgrade dan level memakai saldo game.", C.amber)

-- ============================================================
-- SETTINGS PAGE
-- ============================================================
sectionTitle(pages.Pengaturan, "Pengaturan", "Nilai otomatis tersimpan selama script masih aktif.")

local settingMeta = {
    {"RollDelay", "Jeda Roll", "detik", 0.25, 30},
    {"RarityLimit", "Batas Auto Sell", "1 in X", 0, 1e18},
    {"Reserve", "Saldo Disisakan", "minimum", 0, 1e18},
    {"MaxLevel", "Batas Level", "level", 1, 100000},
    {"EquipDelay", "Jeda Equip Best", "detik", 5, 120},
}

for _, entry in ipairs(settingMeta) do
    local key, titleText, hint, low, high = entry[1], entry[2], entry[3], entry[4], entry[5]

    local row = make("Frame", {
        Size = UDim2.new(1, -2, 0, 58),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, pages.Pengaturan)
    corner(row, 12)
    stroke(row, C.stroke, 1, 0.25)

    local t = label(row, titleText, UDim2.new(0.58, 0, 0, 22), UDim2.fromOffset(13, 8), 11, C.text, Enum.Font.GothamSemibold)
    local h = label(row, hint, UDim2.new(0.58, 0, 0, 18), UDim2.fromOffset(13, 31), 9, C.faint, Enum.Font.GothamMedium)

    local box = make("TextBox", {
        Position = UDim2.new(1, -122, 0.5, -17),
        Size = UDim2.fromOffset(108, 34),
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
        Text = tostring(config[key]),
        TextColor3 = C.text,
        PlaceholderColor3 = C.faint,
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, row)
    corner(box, 9)
    local boxStroke = stroke(box, C.stroke, 1, 0.2)

    on(box.Focused, function()
        tween(boxStroke, 0.12, {Color = C.accent, Transparency = 0})
    end)

    on(box.FocusLost, function()
        tween(boxStroke, 0.12, {Color = C.stroke, Transparency = 0.2})
        local n = tonumber(box.Text)
        if not safeNumber(n) then
            log("Gunakan angka yang valid")
        elseif key == "RarityLimit" and state.Rarity then
            log("Matikan Auto Sell Rarity sebelum mengubah batas")
        else
            config[key] = math.clamp(n, low, high)
            if key == "MaxLevel" then config[key] = math.floor(config[key]) end
            log(titleText .. " = " .. tostring(config[key]))
        end
        box.Text = tostring(config[key])
    end)
end

infoCard(pages.Pengaturan, "Jeda lebih kecil tidak selalu membuat server menerima aksi lebih cepat.", C.accent)

-- ============================================================
-- DIAGNOSTIC PAGE
-- ============================================================
sectionTitle(pages.Diagnostik, "Diagnostik", "Untuk cek masalah modul atau mengambil controller.")

local function copyText(value)
    if type(setclipboard) ~= "function" then
        log("Clipboard tidak tersedia")
        return
    end
    local ok, err = pcall(setclipboard, value)
    log(ok and "Tersalin ke clipboard" or tostring(err))
end

local function diagnosticButton(textValue)
    local b = button(pages.Diagnostik, textValue, UDim2.new(1, -2, 0, 40), UDim2.new())
    b.BackgroundColor3 = C.card
    b.TextXAlignment = Enum.TextXAlignment.Left
    padding(b, 14, 12, 0, 0)
    return b
end

local copyLog = diagnosticButton("Salin Log SALSAHUB")
on(copyLog.Activated, function()
    copyText(table.concat(logs, "\n"))
end)

local reading = false
for _, relative in ipairs({
    "Selling.SellController",
    "Inventory.BackpackController",
    "Inventory.Kinds.Unit.UnitConfig",
}) do
    local path = relative
    local b = diagnosticButton("Salin " .. path:match("[^.]+$"))
    on(b.Activated, function()
        if reading then
            log("Masih membaca controller sebelumnya")
            return
        end
        if type(decompile) ~= "function" then
            log("Decompiler tidak tersedia")
            return
        end
        reading = true
        log("Membaca " .. path)
        task.spawn(function()
            local ok, result = pcall(function()
                local module = RS.Framework.Features
                for name in path:gmatch("[^.]+") do
                    module = assert(module:FindFirstChild(name), name .. " tidak ditemukan")
                end
                return decompile(module)
            end)
            reading = false
            if not alive then return end
            if ok and type(result) == "string" then
                copyText("-- " .. path .. "\n" .. result)
            else
                log("Gagal membaca: " .. tostring(result))
            end
        end)
    end)
end

infoCard(pages.Diagnostik, "Kirim log ke Chat kalau ada fitur yang gagal atau berhenti sendiri.", C.green)

-- ============================================================
-- Drag / collapse
-- ============================================================
local collapsed = false

local function syncShadow()
    shadow.Position = frame.Position + UDim2.fromOffset(0, 5)
end

local function setCollapsed(value)
    collapsed = value
    content.Visible = not value
    tabsBar.Visible = not value
    divider.Visible = not value
    footer.Visible = not value

    local targetSize = value and UDim2.fromOffset(390, 66) or UDim2.fromOffset(390, 480)
    local shadowTarget = value and UDim2.fromOffset(396, 72) or UDim2.fromOffset(396, 486)
    tween(frame, 0.2, {Size = targetSize})
    tween(shadow, 0.2, {Size = shadowTarget})
    mini.Text = value and "+" or "—"
end

on(mini.Activated, function()
    setCollapsed(not collapsed)
end)

local dragInput, dragStart, startPos
on(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragInput = input
        dragStart = input.Position
        startPos = frame.Position
    end
end)

on(UIS.InputChanged, function(input)
    if not dragInput then return end
    local validMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
    if input ~= dragInput and not validMouse then return end

    local delta = input.Position - dragStart
    local viewport = gui.AbsoluteSize
    local abs = frame.AbsoluteSize
    local halfX, halfY = abs.X * 0.5, abs.Y * 0.5
    local x = startPos.X.Scale * viewport.X + startPos.X.Offset + delta.X
    local y = startPos.Y.Scale * viewport.Y + startPos.Y.Offset + delta.Y

    frame.Position = UDim2.fromOffset(
        math.clamp(x, halfX, math.max(halfX, viewport.X - halfX)),
        math.clamp(y, halfY, math.max(halfY, viewport.Y - halfY))
    )
    syncShadow()
end)

on(UIS.InputEnded, function(input)
    if input == dragInput then dragInput = nil end
end)

-- ============================================================
-- Automation logic
-- ============================================================
local function upgradeCandidate()
    local seen = {}
    local best
    local funds = api.Data.Money() - config.Reserve

    local function walk(parent)
        if seen[parent] then return end
        seen[parent] = true
        for _, name in pairs(api.Tree.GetChildren(parent)) do
            if api.Data.Upgrades[name]() then
                walk(name)
            else
                local item = api.Upgrades[name]
                local cost = item and item.price
                if safeNumber(cost) and cost >= 0 and cost <= funds then
                    if not best or cost < best.cost or (cost == best.cost and tostring(name) < tostring(best.name)) then
                        best = {kind = "Upgrade", name = name, cost = cost}
                    end
                end
            end
        end
    end

    walk("Start")
    return best
end

local function levelCandidate()
    local plot = api.Plot.plot
    if not plot then return nil end

    local slots = plot:FindFirstChild("Slots")
    local roots = {}
    if slots then table.insert(roots, slots) end

    local hidden = api.PlotModule:FindFirstChild(plot.Name)
    if hidden then table.insert(roots, hidden) end

    local funds = api.Data.Money() - config.Reserve
    local best

    for _, root in ipairs(roots) do
        for _, model in ipairs(root:GetChildren()) do
            local slot = tonumber(model.Name)
            if model:IsA("Model") and slot and api.Data.Rebirth() >= api.PlotConfig.GetSlotRebirthRequirement(slot) then
                local s = api.Data.Slots[tostring(slot)]()
                local unit = s and s.unitId and api.Data.Inventory[s.unitId]()
                if unit and unit.attributes then
                    local level = unit.attributes.level or 1
                    local cost = api.UnitUtil.GetLevelPrice(unit.name, unit.attributes)
                    if safeNumber(cost) and cost >= 0 and cost <= funds and level < config.MaxLevel then
                        if not best or cost < best.cost or (cost == best.cost and slot < best.slot) then
                            best = {
                                kind = "Level",
                                slot = slot,
                                unitId = s.unitId,
                                level = level,
                                cost = cost,
                            }
                        end
                    end
                end
            end
        end
    end

    return best
end

local function acknowledged(action)
    if action.kind == "Upgrade" then
        return api.Data.Upgrades[action.name]() == true
    end
    local unit = api.Data.Inventory[action.unitId]()
    return unit and unit.attributes and (unit.attributes.level or 1) > action.level
end

local function stopAll()
    for key in pairs(state) do
        state[key] = false
        repaint(key)
    end
    local ok, err = pcall(restoreRarity)
    if not ok then log("Pemulihan AutoSell gagal: " .. tostring(err)) end
    log("Semua fitur OFF")
end

local unloading = false
local function unload()
    if unloading then return end
    unloading = true

    pcall(stopAll)
    pcall(restoreRoll)
    alive = false

    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end

    pcall(function() gui:Destroy() end)
    pcall(function() shadow:Destroy() end)
end

on(stopButton.Activated, stopAll)
on(unloadButton.Activated, unload)
on(close.Activated, unload)
on(unloadEvent.Event, unload)

-- ============================================================
-- Game / module init
-- ============================================================
if game.GameId ~= 10708913337 and game.PlaceId ~= 113290951185459 then
    log("Map tidak cocok • PlaceId " .. tostring(game.PlaceId))
    setReadyVisual(false)
    return
end

local loadingModule = "Framework"
local function loadModule(module, name)
    loadingModule = name
    log("Memuat " .. name .. "...")
    return require(module)
end

local initWorker
initWorker = task.spawn(function()
    local ok, err = pcall(function()
        local F = RS.Framework.Features
        api.Data = loadModule(F.Data.DataController, "DataController")
        api.Tree = loadModule(F.Upgrades.TreeStructure, "TreeStructure")
        api.Upgrades = loadModule(F.Upgrades.Upgrades, "Upgrades")
        api.PlotModule = F.Plot.PlotController
        api.Plot = loadModule(api.PlotModule, "PlotController")
        api.PlotConfig = loadModule(F.Plot.PlotConfig, "PlotConfig")
        api.UnitUtil = loadModule(F.Inventory.Kinds.Unit.UnitUtil, "UnitUtil")

        local Network = loadModule(RS.Packages.Network, "Network")
        local roll = Network.ClientComm.new(RS.Network, false, "RollService")
        local sell = Network.ClientComm.new(RS.Network, false, "SellService")
        local plot = Network.ClientComm.new(RS.Network, false, "PlotService")

        api.RollDice = roll:GetFunction("RollDice")
        api.NativeAutoRoll = roll:GetSignal("SetAutoRoll")
        api.AutoSell = sell:GetSignal("UpdateAutoSell")
        api.LevelUp = plot:GetSignal("LevelUpSlot")
        api.BuyUpgrade = Network.Client.GetSignal(RS.Network, "BuyUpgrade")

        assert(safeNumber(api.Data.Money()), "Data uang belum siap")
    end)

    if not alive then return end

    if not ok then
        log("Inisialisasi gagal: " .. tostring(err))
        setReadyVisual(false)
        return
    end

    ready = true
    setReadyVisual(true)
    log("Siap • semua fitur masih OFF")

    -- Roll worker
    task.spawn(function()
        local waitSince = nil
        while alive do
            if state.Roll then
                local success, result = pcall(function()
                    if api.Data.AutoRoll() then
                        waitSince = waitSince or os.clock()
                        if os.clock() - waitSince > 4 then
                            error("Auto-roll bawaan masih ON; matikan dari menu game")
                        end
                        return nil
                    end

                    waitSince = nil
                    local root = PG:FindFirstChild("Root")
                    local rolling = root and root:FindFirstChild("Rolling")
                    local rf = rolling and rolling:FindFirstChild("Frame")
                    local template = rf and rf:FindFirstChild("RollTemplate")

                    if rf then
                        for _, child in ipairs(rf:GetChildren()) do
                            if child ~= template and child.Name == "RollTemplate" then
                                return nil
                            end
                        end
                    end

                    return api.RollDice()
                end)

                if not success then
                    disable("Roll", "Roll dihentikan: " .. tostring(result))
                end
                task.wait(config.RollDelay)
            else
                waitSince = nil
                local okRestore, restoreErr = pcall(restoreRoll)
                if not okRestore then
                    log("Pemulihan AutoRoll gagal: " .. tostring(restoreErr))
                end
                task.wait(0.2)
            end
        end
    end)

    -- Upgrade / level worker
    task.spawn(function()
        local lastKind = "Level"
        while alive do
            if pending then
                local okAck, done = pcall(acknowledged, pending)
                if okAck and done then
                    log(pending.kind .. " terkonfirmasi")
                    pending = nil
                elseif not okAck or os.clock() - pending.sent > 5 then
                    disable(pending.kind, "Upgrade belum terkonfirmasi; fitur dihentikan")
                    pending = nil
                end

            elseif state.Upgrade or state.Level then
                local okAction, action = pcall(function()
                    local first = lastKind == "Level" and "Upgrade" or "Level"
                    local second = first == "Upgrade" and "Level" or "Upgrade"

                    for _, kind in ipairs({first, second}) do
                        if state[kind] then
                            local candidate
                            if kind == "Upgrade" then
                                candidate = upgradeCandidate()
                            else
                                candidate = levelCandidate()
                            end
                            if candidate then return candidate end
                        end
                    end
                end)

                if not okAction then
                    disable("Upgrade")
                    disable("Level", "Pemeriksaan upgrade gagal: " .. tostring(action))

                elseif action and state[action.kind] then
                    local sent, errorMessage = pcall(function()
                        if action.kind == "Upgrade" then
                            api.BuyUpgrade:Fire(action.name)
                        else
                            api.LevelUp:Fire(action.slot)
                        end
                    end)

                    if sent then
                        action.sent = os.clock()
                        pending = action
                        lastKind = action.kind
                        log("Menunggu " .. action.kind .. ": " .. tostring(action.name or action.slot))
                    else
                        disable(action.kind, tostring(errorMessage))
                    end
                end
            end

            task.wait(0.5)
        end
    end)

    -- Equip best worker
    task.spawn(function()
        local nextEquip = 0
        while alive do
            if state.Equip and not pending and os.clock() >= nextEquip then
                nextEquip = os.clock() + config.EquipDelay

                local success, errorMessage = pcall(function()
                    local b = PG.Root.Menus.Backpack.Units.Actions.EquipBest
                    assert(b:IsA("GuiButton"), "Tombol Equip Best tidak ditemukan")
                    assert(type(firesignal) == "function", "firesignal tidak didukung")
                    firesignal(b.Activated)
                end)

                if not success then
                    disable("Equip", tostring(errorMessage))
                else
                    log("Equip Best dipanggil")
                end
            end
            task.wait(0.5)
        end
    end)
end)

-- Timeout hint
task.delay(15, function()
    if alive and not ready then
        log("Belum siap: " .. tostring(loadingModule) .. " • buka DEBUG bila perlu")
    end
end)

-- Small intro animation
frame.BackgroundTransparency = 0.08
shadow.BackgroundTransparency = 0.75
tween(frame, 0.22, {BackgroundTransparency = 0})
tween(shadow, 0.22, {BackgroundTransparency = 0.5})

log("SALSAHUB V5 dibuka • memuat modul...")
