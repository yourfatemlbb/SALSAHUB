--[[
    SALSAHUB V6.2 | Anime Dice
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
local ready = false -- core/data modules ready
local networkReady = false -- all known Network endpoints bound
local networkRequireStarted = false
local networkRequireDone = false
local networkRequireOk = false
local networkRequireResult = nil
local networkLastError = nil
local connections = {}
local toggles = {}
local pending = nil

local state = {
    Roll = false,
    Rarity = false,
    Equip = false,
    Upgrade = false,
    Level = false,
    Dice = false,
    Quest = false,
}

local config = {
    RollDelay = 0.75,
    RarityLimit = 0,
    Reserve = 0,
    MaxLevel = 50,
    LevelDelay = 0.15,
    EquipDelay = 10,
    DiceDelay = 2.0,
    QuestDelay = 3.0,
    SellDelay = 0.8,
}

local api = {}
local nativeRollBefore, rarityBefore, lastRaritySent
local nativeRollChanged = false
local logs = {"Build V6.2 | GUI parent: " .. tostring(uiParentName)}

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
    Active = true,
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
local subtitle = label(header, "Anime Dice  •  V6.2", UDim2.fromOffset(210, 20), UDim2.fromOffset(64, 34), 11, C.muted, Enum.Font.GothamMedium)
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
    Rarity = "Jual unit non-plot sampai batas 1 in X.",
    Equip = "Tekan Equip Best unit secara berkala.",
    Upgrade = "Beli upgrade tree yang terjangkau.",
    Level = "Level-up unit di plot dengan loop lebih cepat.",
    Dice = "Beli dice terbaik yang terjangkau lalu equip terbaik.",
    Quest = "Claim reward quest yang sudah selesai otomatis.",
}

local toggleNames = {
    Roll = "Auto Roll",
    Rarity = "Auto Sell",
    Equip = "Auto Equip Best Unit",
    Upgrade = "Auto Upgrade Tree",
    Level = "Fast Upgrade Plot Unit",
    Dice = "Auto Buy + Equip Best Dice",
    Quest = "Auto Claim Quest Reward",
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
    -- V6.1: Auto Sell no longer mutates the game's native AutoSell state.
    -- SellController shows selling is performed through SellInventory(keys),
    -- so there is nothing native to restore here.
    rarityBefore = nil
    lastRaritySent = nil
end

local function restoreRoll()
    if not nativeRollChanged then return end
    nativeRollChanged = false
    if api.Data and api.Data.AutoRoll and api.NativeAutoRoll and api.Data.AutoRoll() == false then
        api.NativeAutoRoll:Fire(nativeRollBefore)
    end
end

local function dependencyReady(key)
    if key == "Roll" then
        return api.RollDice ~= nil and api.NativeAutoRoll ~= nil, "RollService"
    elseif key == "Rarity" then
        return api.SellInventory ~= nil, "SellService.SellInventory"
    elseif key == "Upgrade" then
        return api.BuyUpgrade ~= nil, "BuyUpgrade"
    elseif key == "Level" then
        return api.LevelUp ~= nil, "PlotService.LevelUpSlot"
    end
    -- Equip Unit, Dice, and Quest use the game's loaded UI and do not need
    -- SALSAHUB's Network package binding.
    return true, nil
end

local function toggleFeature(key)
    if not ready then
        log("Core belum siap; tunggu DataController selesai")
        return
    end

    local depOk, depName = dependencyReady(key)
    if not depOk then
        log(toggleNames[key] .. " menunggu " .. tostring(depName) .. " • fitur UI lain tetap bisa")
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
            log("Isi batas Auto Sell 1 in X dulu di Setting")
            return
        end

        -- SellController uses SellService:GetFunction("SellInventory").
        -- Do not send a guessed numeric payload to UpdateAutoSell.
        rarityBefore = nil
        lastRaritySent = nil
        state.Rarity = true
        log("Auto Sell ON • batch SellInventory • sampai 1 in " .. tostring(config.RarityLimit))

    elseif key == "Rarity" then
        state.Rarity = false
        pcall(restoreRarity)
        log("Auto Sell OFF")

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
for _, key in ipairs({"Roll", "Rarity", "Equip", "Upgrade", "Level", "Dice", "Quest"}) do
    local card = createToggle(pages.Otomatis, key)
    on(card.Activated, function()
        local ok, err = pcall(toggleFeature, key)
        if not ok then
            disable(key, "Error " .. key .. ": " .. tostring(err))
        end
    end)
    repaint(key)
end
infoCard(pages.Otomatis, "Semua fitur mulai OFF. Auto Sell melindungi unit yang sedang diplot/locked jika statusnya terbaca.", C.amber)

-- ============================================================
-- SETTINGS PAGE
-- ============================================================
sectionTitle(pages.Pengaturan, "Pengaturan", "Nilai otomatis tersimpan selama script masih aktif.")

local settingMeta = {
    {"RollDelay", "Jeda Roll", "detik", 0.25, 30},
    {"RarityLimit", "Batas Auto Sell", "jual sampai 1 in X", 0, 1e18},
    {"Reserve", "Saldo Disisakan", "minimum", 0, 1e18},
    {"MaxLevel", "Batas Level", "level", 1, 100000},
    {"LevelDelay", "Kecepatan Upgrade Plot", "detik / level", 0.08, 2},
    {"EquipDelay", "Jeda Equip Best Unit", "detik", 2, 120},
    {"DiceDelay", "Jeda Buy/Equip Dice", "detik", 0.5, 30},
    {"QuestDelay", "Jeda Claim Quest", "detik", 1, 60},
    {"SellDelay", "Jeda Auto Sell", "detik", 0.25, 10},
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
-- Adaptive GUI helpers (V6)
-- ============================================================
local function lower(value)
    return string.lower(tostring(value or ""))
end

local function objectBlob(obj, ancestorDepth)
    local parts = {obj.Name}
    if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
        table.insert(parts, obj.Text)
    end

    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            if child.Text and child.Text ~= "" then
                table.insert(parts, child.Text)
            end
        end
    end

    local parent = obj.Parent
    for _ = 1, (ancestorDepth or 5) do
        if not parent then break end
        table.insert(parts, parent.Name)
        if parent:IsA("TextLabel") or parent:IsA("TextButton") then
            table.insert(parts, parent.Text)
        end
        parent = parent.Parent
    end

    return lower(table.concat(parts, " "))
end

local function containsAny(blob, words)
    for _, word in ipairs(words) do
        if string.find(blob, lower(word), 1, true) then return true end
    end
    return false
end

local function containsAll(blob, words)
    for _, word in ipairs(words) do
        if not string.find(blob, lower(word), 1, true) then return false end
    end
    return true
end

local suffixPower = {
    k = 1e3, m = 1e6, b = 1e9, t = 1e12,
    qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24,
    oc = 1e27, no = 1e30, dc = 1e33,
}

local function parseLargestNumber(text)
    text = lower(text):gsub(",", "")
    local best
    for number, suffix in text:gmatch("([%d%.]+)%s*([%a]*)") do
        local n = tonumber(number)
        if n then
            local mul = suffixPower[suffix] or 1
            n = n * mul
            if not best or n > best then best = n end
        end
    end
    return best
end

local function activateButton(b)
    if not b or not b.Parent or not b:IsA("GuiButton") then return false end
    if type(firesignal) == "function" then
        local ok = pcall(function() firesignal(b.Activated) end)
        if ok then return true end
    end
    local ok = pcall(function() b:Activate() end)
    return ok
end

local function findButtons(required, anyWords, forbidden)
    local result = {}
    for _, obj in ipairs(PG:GetDescendants()) do
        if obj:IsA("GuiButton") and not obj:IsDescendantOf(gui) then
            local blob = objectBlob(obj, 6)
            if containsAll(blob, required or {})
                and (not anyWords or #anyWords == 0 or containsAny(blob, anyWords))
                and (not forbidden or not containsAny(blob, forbidden)) then
                table.insert(result, {button = obj, blob = blob})
            end
        end
    end
    return result
end

local function clickQuestClaims()
    local found = findButtons({"quest"}, {"claim", "collect"}, {"claimed", "locked"})
    local clicked = 0
    for _, item in ipairs(found) do
        if clicked >= 12 then break end
        local b = item.button
        if (b.Visible or type(firesignal) == "function") and b.Active ~= false and activateButton(b) then
            clicked += 1
        end
    end
    return clicked
end

local function clickBestDiceActions()
    local money = 0
    pcall(function() money = api.Data.Money() end)

    local buyButtons = findButtons({"dice"}, {"buy", "purchase"}, {"robux", "gamepass", "product", "premium"})
    local bestBuy, bestPrice
    for _, item in ipairs(buyButtons) do
        local price = parseLargestNumber(item.blob)
        if (item.button.Visible or type(firesignal) == "function") and (not price or price <= money) then
            if not bestBuy or (price and (not bestPrice or price > bestPrice)) then
                bestBuy = item.button
                bestPrice = price
            end
        end
    end

    local didBuy = bestBuy and activateButton(bestBuy) or false

    local equipButtons = findButtons({"dice", "equip"}, {"best", "equip"}, {"unequip"})
    local bestEquip, bestEquipScore = nil, -math.huge
    for _, item in ipairs(equipButtons) do
        if item.button.Visible or type(firesignal) == "function" then
            local score = 0
            if string.find(item.blob, "best", 1, true) then score += 1000000 end
            local n = parseLargestNumber(item.blob)
            if n then score += math.min(n, 999999) end
            if score > bestEquipScore then
                bestEquipScore = score
                bestEquip = item.button
            end
        end
    end

    local didEquip = bestEquip and activateButton(bestEquip) or false
    return didBuy, didEquip
end

local function readStateSnapshot(stateObject)
    if stateObject == nil then return nil end

    -- State values in this game are callable (DataController.Inventory(),
    -- DataController.Slots()), but some builds expose a plain table/proxy.
    local ok, value = pcall(function()
        return stateObject()
    end)
    if ok and type(value) == "table" then
        return value
    end

    if type(stateObject) == "table" then
        return stateObject
    end
    return nil
end

local function resolveStateEntry(value)
    if type(value) == "function" then
        local ok, result = pcall(value)
        if ok then return result end
    elseif type(value) == "table" then
        local ok, result = pcall(function() return value() end)
        if ok and result ~= nil then return result end
        return value
    end
    return value
end

local function inventorySnapshot()
    return readStateSnapshot(api.Data and api.Data.Inventory) or {}
end

local function slotsSnapshot()
    return readStateSnapshot(api.Data and api.Data.Slots) or {}
end

local function plottedUnitIds()
    local out = {}
    for _, rawSlot in pairs(slotsSnapshot()) do
        local slot = resolveStateEntry(rawSlot)
        if type(slot) == "table" then
            local unitId = slot.unitId or slot.unitID or slot.unit or slot.inventoryKey
            if unitId ~= nil then
                out[tostring(unitId)] = true
            end
        end
    end
    return out
end

local function numericOdds(value)
    if safeNumber(value) then
        if value > 0 and value < 1 then return 1 / value end
        if value >= 1 then return value end
    elseif type(value) == "string" then
        local cleaned = value:gsub(",", "")
        local direct = cleaned:match("1%s*[iI][nN]%s*([%d%.]+)")
        if direct then return tonumber(direct) end
        local oneOver = cleaned:match("1%s*/%s*([%d%.]+)")
        if oneOver then return tonumber(oneOver) end
        local percent = cleaned:match("([%d%.]+)%s*%%")
        if percent then
            local pct = tonumber(percent)
            if pct and pct > 0 then return 100 / pct end
        end
    end
    return nil
end

local function scanOddsTable(tbl, depth, seen)
    if type(tbl) ~= "table" or depth <= 0 then return nil end
    seen = seen or {}
    if seen[tbl] then return nil end
    seen[tbl] = true

    -- First pass: keys that clearly describe probability/odds.
    for k, v in pairs(tbl) do
        local key = string.lower(tostring(k))
        if string.find(key, "odds", 1, true)
            or string.find(key, "chance", 1, true)
            or string.find(key, "probability", 1, true) then
            local n = numericOdds(v)
            if n then return n end
        end
    end

    -- Second pass: nested attributes/config data.
    for _, v in pairs(tbl) do
        if type(v) == "table" then
            local n = scanOddsTable(v, depth - 1, seen)
            if n then return n end
        elseif type(v) == "string" then
            local n = numericOdds(v)
            if n then return n end
        end
    end
    return nil
end

local function getUnitOdds(unit)
    if type(unit) ~= "table" then return nil end

    local n = scanOddsTable(unit, 3)
    if n then return n end

    -- Probe UnitUtil helpers whose names explicitly mention probability.
    if type(api.UnitUtil) == "table" then
        for name, fn in pairs(api.UnitUtil) do
            local lname = string.lower(tostring(name))
            if type(fn) == "function" and (
                string.find(lname, "odds", 1, true)
                or string.find(lname, "chance", 1, true)
                or string.find(lname, "probability", 1, true)
            ) then
                local attempts = {
                    {unit.name, unit.attributes},
                    {unit},
                    {unit.name},
                }
                for _, args in ipairs(attempts) do
                    local ok, value = pcall(function()
                        return fn(table.unpack(args))
                    end)
                    if ok then
                        n = numericOdds(value)
                        if n then return n end
                        if type(value) == "table" then
                            n = scanOddsTable(value, 2)
                            if n then return n end
                        end
                    end
                end
            end
        end
    end

    -- UnitConfig fallback.
    if api.UnitConfig and unit.name then
        local cfg
        if type(api.UnitConfig) == "table" then
            cfg = api.UnitConfig[unit.name]
            if not cfg and type(api.UnitConfig.Get) == "function" then
                pcall(function() cfg = api.UnitConfig.Get(unit.name) end)
            end
        end
        n = scanOddsTable(cfg, 4)
        if n then return n end
    end

    return nil
end

local function isLockedUnit(unit)
    if type(unit) ~= "table" then return false end
    if unit.locked == true or unit.isLocked == true or unit.favorited == true or unit.favorite == true then
        return true
    end
    local a = unit.attributes
    return type(a) == "table" and (
        a.locked == true or a.isLocked == true or a.favorited == true or a.favorite == true
    )
end

local function sellCandidates(maxBatch)
    if config.RarityLimit <= 0 or not api.Data then return {}, 0 end

    local inventory = inventorySnapshot()
    local plotted = plottedUnitIds()
    local candidates = {}
    local unknownOdds = 0

    for key, rawUnit in pairs(inventory) do
        local unit = resolveStateEntry(rawUnit)
        local keyString = tostring(key)
        if type(unit) == "table" and not plotted[keyString] and not isLockedUnit(unit) then
            local odds = getUnitOdds(unit)
            if odds then
                -- "jual sampai 1 in X": 1/2, 1/10, ... 1/X are eligible.
                if odds <= config.RarityLimit then
                    table.insert(candidates, {
                        key = key,
                        odds = odds,
                        name = unit.name or unit.unitName or "Unit",
                    })
                end
            else
                unknownOdds += 1
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.odds == b.odds then return tostring(a.key) < tostring(b.key) end
        return a.odds < b.odds
    end)

    local keys = {}
    local limit = math.min(maxBatch or 25, #candidates)
    for i = 1, limit do
        table.insert(keys, candidates[i].key)
    end
    return keys, unknownOdds
end

local function sellInventoryBatch(keys)
    if type(keys) ~= "table" or #keys == 0 then return false, "batch kosong" end
    if not api.SellInventory then return false, "SellInventory belum tersedia" end

    local ok, first, second = pcall(function()
        return api.SellInventory(keys)
    end)
    if not ok then return false, first end

    -- SellController checks the second return value (> 0) for the sell sound.
    local soldValue = tonumber(second) or tonumber(first)
    return true, soldValue
end

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
local function beginDrag(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragInput = input
        dragStart = input.Position
        startPos = frame.Position
    end
end

-- V6: drag from most non-scroll areas, not only the header.
for _, handle in ipairs({frame, header, tabsBar, footer, statusCard, divider, content}) do
    handle.Active = true
    on(handle.InputBegan, beginDrag)
end

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

-- Network is intentionally NOT required inside the blocking core init.
-- In this game the Network package can already be in the middle of a require
-- from a game controller; requiring it again from an executor can yield
-- indefinitely. V6.2 first loads the data modules, then binds Network in a
-- separate worker. UI-only automation stays usable while that happens.
local function findNetworkTableInGC()
    if type(getgc) ~= "function" then return nil end
    local ok, objects = pcall(getgc, true)
    if not ok or type(objects) ~= "table" then return nil end

    for _, object in ipairs(objects) do
        if type(object) == "table" then
            local cc = rawget(object, "ClientComm")
            local client = rawget(object, "Client")
            if type(cc) == "table" and type(rawget(cc, "new")) == "function"
                and type(client) == "table" and type(rawget(client, "GetSignal")) == "function" then
                return object
            end
        end
    end
    return nil
end

local function startNetworkRequireOnce()
    if networkRequireStarted then return end
    networkRequireStarted = true
    task.spawn(function()
        local ok, result = pcall(require, RS.Packages.Network)
        networkRequireOk = ok
        networkRequireResult = result
        networkRequireDone = true
        if not ok then networkLastError = tostring(result) end
    end)
end

local function remoteNameMatch(instance, wanted)
    local a = string.lower(tostring(instance.Name)):gsub("[^%w]", "")
    local b = string.lower(tostring(wanted)):gsub("[^%w]", "")
    return a == b or string.find(a, b, 1, true) ~= nil
end

local function findDirectRemote(wanted, className)
    local root = RS:FindFirstChild("Network")
    if not root then return nil end
    local fallback = nil
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA(className) and remoteNameMatch(d, wanted) then
            if d.Name == wanted then return d end
            fallback = fallback or d
        end
    end
    return fallback
end

local function signalWrapper(remote)
    if not remote then return nil end
    return {
        Fire = function(_, ...)
            return remote:FireServer(...)
        end
    }
end

local function bindDirectRemotes()
    -- Fallback for executors where getgc/getloaded package access is restricted.
    -- Only exact/near-exact RemoteEvent/RemoteFunction names are used.
    if not api.RollDice then
        local r = findDirectRemote("RollDice", "RemoteFunction")
        if r then api.RollDice = function(...) return r:InvokeServer(...) end end
    end
    if not api.SellInventory then
        local r = findDirectRemote("SellInventory", "RemoteFunction")
        if r then api.SellInventory = function(...) return r:InvokeServer(...) end end
    end
    if not api.SellEquipped then
        local r = findDirectRemote("SellEquipped", "RemoteFunction")
        if r then api.SellEquipped = function(...) return r:InvokeServer(...) end end
    end
    if not api.NativeAutoRoll then
        api.NativeAutoRoll = signalWrapper(findDirectRemote("SetAutoRoll", "RemoteEvent"))
    end
    if not api.LevelUp then
        api.LevelUp = signalWrapper(findDirectRemote("LevelUpSlot", "RemoteEvent"))
    end
    if not api.BuyUpgrade then
        api.BuyUpgrade = signalWrapper(findDirectRemote("BuyUpgrade", "RemoteEvent"))
    end
end

local function updateNetworkReady()
    networkReady = api.RollDice ~= nil
        and api.NativeAutoRoll ~= nil
        and api.LevelUp ~= nil
        and api.BuyUpgrade ~= nil
        and api.SellInventory ~= nil
    setReadyVisual(networkReady)
    return networkReady
end

local function bindNetworkTable(Network)
    if type(Network) ~= "table" then return false, "Network table invalid" end
    local ok, err = pcall(function()
        local roll = Network.ClientComm.new(RS.Network, false, "RollService")
        local sell = Network.ClientComm.new(RS.Network, false, "SellService")
        local plot = Network.ClientComm.new(RS.Network, false, "PlotService")

        api.RollDice = api.RollDice or roll:GetFunction("RollDice")
        api.NativeAutoRoll = api.NativeAutoRoll or roll:GetSignal("SetAutoRoll")
        api.LevelUp = api.LevelUp or plot:GetSignal("LevelUpSlot")
        api.BuyUpgrade = api.BuyUpgrade or Network.Client.GetSignal(RS.Network, "BuyUpgrade")
        api.SellEquipped = api.SellEquipped or sell:GetFunction("SellEquipped")
        api.SellInventory = api.SellInventory or sell:GetFunction("SellInventory")
    end)
    if not ok then
        networkLastError = tostring(err)
        return false, err
    end
    return updateNetworkReady()
end

local function startNetworkBootstrap()
    task.spawn(function()
        loadingModule = "Network"
        startNetworkRequireOnce()
        local lastLog = 0

        while alive and not networkReady do
            local Network = findNetworkTableInGC()
            if not Network and networkRequireDone and networkRequireOk then
                Network = networkRequireResult
            end

            if Network then
                bindNetworkTable(Network)
            end

            -- Also try direct remotes; this does not require Packages.Network.
            bindDirectRemotes()
            updateNetworkReady()

            if networkReady then
                loadingModule = "Ready"
                log("Network siap • semua fitur tersedia")
                break
            elseif os.clock() - lastLog > 6 then
                lastLog = os.clock()
                local parts = {}
                if not api.RollDice or not api.NativeAutoRoll then table.insert(parts, "Roll") end
                if not api.SellInventory then table.insert(parts, "Sell") end
                if not api.BuyUpgrade then table.insert(parts, "Upgrade") end
                if not api.LevelUp then table.insert(parts, "Level") end
                log("Core siap • menunggu Network: " .. table.concat(parts, ", ") .. " • Equip/Dice/Quest tetap bisa")
            end
            task.wait(0.5)
        end
    end)
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
        pcall(function()
            api.UnitConfig = loadModule(F.Inventory.Kinds.Unit.UnitConfig, "UnitConfig")
        end)

        assert(safeNumber(api.Data.Money()), "Data uang belum siap")
    end)

    if not alive then return end

    if not ok then
        log("Inisialisasi gagal: " .. tostring(err))
        setReadyVisual(false)
        return
    end

    ready = true
    setReadyVisual(false)
    log("Core siap • menghubungkan Network...")
    startNetworkBootstrap()

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

                    assert(api.RollDice, "RollService belum siap")
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

    -- Upgrade tree worker
    task.spawn(function()
        while alive do
            if pending then
                local okAck, done = pcall(acknowledged, pending)
                if okAck and done then
                    pending = nil
                elseif not okAck or os.clock() - pending.sent > 3 then
                    disable("Upgrade", "Upgrade tree belum terkonfirmasi; fitur dihentikan")
                    pending = nil
                end
            elseif state.Upgrade then
                local okAction, action = pcall(upgradeCandidate)
                if not okAction then
                    disable("Upgrade", "Pemeriksaan upgrade tree gagal: " .. tostring(action))
                elseif action then
                    local sent, errorMessage = pcall(function()
                        assert(api.BuyUpgrade, "BuyUpgrade belum siap")
                        api.BuyUpgrade:Fire(action.name)
                    end)
                    if sent then
                        action.sent = os.clock()
                        pending = action
                    else
                        disable("Upgrade", tostring(errorMessage))
                    end
                end
            end
            task.wait(0.18)
        end
    end)

    -- V6 fast plotted-unit leveling. This no longer waits behind upgrade-tree
    -- acknowledgements, so plotted units can level continuously.
    task.spawn(function()
        local count = 0
        while alive do
            if state.Level then
                local okAction, action = pcall(levelCandidate)
                if not okAction then
                    disable("Level", "Fast upgrade plot gagal: " .. tostring(action))
                    task.wait(0.5)
                elseif action then
                    local sent, errorMessage = pcall(function()
                        assert(api.LevelUp, "LevelUpSlot belum siap")
                        api.LevelUp:Fire(action.slot)
                    end)
                    if sent then
                        count += 1
                        if count % 25 == 0 then
                            log("Fast Upgrade Plot • " .. tostring(count) .. " level dikirim")
                        end
                        task.wait(config.LevelDelay)
                    else
                        disable("Level", tostring(errorMessage))
                    end
                else
                    task.wait(0.3)
                end
            else
                task.wait(0.25)
            end
        end
    end)

    -- Equip best unit worker
    task.spawn(function()
        local nextEquip = 0
        while alive do
            if state.Equip and os.clock() >= nextEquip then
                nextEquip = os.clock() + config.EquipDelay

                local success, errorMessage = pcall(function()
                    local b = PG.Root.Menus.Backpack.Units.Actions.EquipBest
                    assert(b:IsA("GuiButton"), "Tombol Equip Best tidak ditemukan")
                    assert(activateButton(b), "Tombol Equip Best gagal diaktifkan")
                end)

                if not success then
                    disable("Equip", tostring(errorMessage))
                else
                    log("Equip Best Unit dipanggil")
                end
            end
            task.wait(0.35)
        end
    end)

    -- V6.1 Auto Sell worker. SellController expects one SellInventory call
    -- with an ARRAY of inventory keys, not SellUnit/SellUnits remotes.
    task.spawn(function()
        local lastInfoLog = 0
        local batchCount = 0
        while alive do
            if state.Rarity then
                local okScan, keys, unknownOdds = pcall(sellCandidates, 30)
                if not okScan then
                    log("Auto Sell scan gagal: " .. tostring(keys))
                    task.wait(1)
                elseif #keys > 0 then
                    local sent, soldValue = sellInventoryBatch(keys)
                    if sent then
                        batchCount += 1
                        if batchCount % 5 == 0 then
                            log("Auto Sell • batch " .. tostring(batchCount) .. " • " .. tostring(#keys) .. " unit dikirim")
                        end
                    elseif os.clock() - lastInfoLog > 5 then
                        lastInfoLog = os.clock()
                        log("Auto Sell SellInventory gagal: " .. tostring(soldValue))
                    end
                    task.wait(config.SellDelay)
                else
                    if os.clock() - lastInfoLog > 8 then
                        lastInfoLog = os.clock()
                        if unknownOdds and unknownOdds > 0 then
                            log("Auto Sell: 0 eligible • odds " .. tostring(unknownOdds) .. " unit belum terbaca")
                        else
                            log("Auto Sell: tidak ada unit yang masuk batas 1 in " .. tostring(config.RarityLimit))
                        end
                    end
                    task.wait(math.max(config.SellDelay, 0.8))
                end
            else
                task.wait(0.35)
            end
        end
    end)

    -- Auto buy + equip best dice. Uses the game's own UI callbacks so it can
    -- survive service-name changes better than a hardcoded remote-only path.
    task.spawn(function()
        local nextRun = 0
        local missSince = 0
        while alive do
            if state.Dice and os.clock() >= nextRun then
                nextRun = os.clock() + config.DiceDelay
                local okDice, didBuy, didEquip = pcall(clickBestDiceActions)
                if not okDice then
                    log("Auto Dice gagal: " .. tostring(didBuy))
                elseif didBuy or didEquip then
                    missSince = 0
                elseif os.clock() - missSince > 12 then
                    missSince = os.clock()
                    log("Auto Dice: tombol dice belum ditemukan; buka menu Dice sekali bila perlu")
                end
            end
            task.wait(0.35)
        end
    end)

    -- Auto claim completed quest rewards.
    task.spawn(function()
        local nextRun = 0
        local lastMiss = 0
        while alive do
            if state.Quest and os.clock() >= nextRun then
                nextRun = os.clock() + config.QuestDelay
                local okQuest, count = pcall(clickQuestClaims)
                if not okQuest then
                    log("Auto Quest gagal: " .. tostring(count))
                elseif count > 0 then
                    log("Quest claim dipanggil • " .. tostring(count) .. " tombol")
                elseif os.clock() - lastMiss > 15 then
                    lastMiss = os.clock()
                    log("Auto Quest: belum ada reward claimable / menu Quest belum termuat")
                end
            end
            task.wait(0.4)
        end
    end)
end)

-- Timeout hint
task.delay(15, function()
    if not alive then return end
    if not ready then
        log("Core belum siap: " .. tostring(loadingModule) .. " • buka DEBUG bila perlu")
    elseif not networkReady then
        local extra = networkLastError and (" • " .. tostring(networkLastError)) or ""
        log("Core sudah siap • Network masih di-bind" .. extra .. " • Equip/Dice/Quest tetap tersedia")
    end
end)

-- Small intro animation
frame.BackgroundTransparency = 0.08
shadow.BackgroundTransparency = 0.75
tween(frame, 0.22, {BackgroundTransparency = 0})
tween(shadow, 0.22, {BackgroundTransparency = 0.5})

log("SALSAHUB V6.2 dibuka • memuat core...")
