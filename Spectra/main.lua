--[[
SPECTRA / PLAYER VISUALS v6 — AUTO FIRE + MODERN VISUALS
Установка: LocalScript в StarterPlayer > StarterPlayerScripts. RightShift — меню, End — выгрузка.

БОЙ УПРОЩЁН:
• ЛКМ сохранён как основной режим; дополнительно есть Auto Fire по живой видимой цели.
• ЛКМ/Auto Fire используют один pipeline: 25 мс захват → camera flick → 10 мс → клик → возврат.
• Auto Fire никогда не кликает в пустоту: только когда найдена живая видимая цель.
• FOV наведения можно поставить до 360°. Значение 360° разрешает цель в любой стороне от камеры.
• Перед захватом и непосредственно перед выстрелом повторно проверяются Humanoid, стены и команда.
• После смерти цель немедленно исключается из ESP/aim; старый Character помечается мёртвым до respawn.

ВИДИМОСТЬ:
• ESP и silent aim используют одинаковую проверку открытой части головы.
  Достаточно видимого края/макушки головы — всё тело видеть не нужно.
• Добавлены head-dot маркеры и анимированный target-focus для текущей цели.

Тайминги 25/10 мс являются целевыми: фактическое выполнение зависит от FPS/планировщика Roblox.
Скрипт не вызывает серверные RemoteEvent и не содержит логики конкретного оружия.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local localPlayer = Players.LocalPlayer
if not localPlayer then
    warn("Spectra: нужен LocalScript в StarterPlayerScripts.")
    return
end
local playerGui = localPlayer:WaitForChild("PlayerGui")
local GUI_NAME = "SpectraPlayerVisualsV2"
local RENDER_NAME = "SpectraPlayerVisualsV2_Render"
local oldGui = playerGui:FindFirstChild(GUI_NAME)
if oldGui then
    local stop = oldGui:FindFirstChild("Shutdown")
    if stop and stop:IsA("BindableEvent") then stop:Fire() end
    oldGui:Destroy()
end

local theme = {
    Background = Color3.fromRGB(18, 20, 23),
    Sidebar = Color3.fromRGB(22, 24, 28),
    Hover = Color3.fromRGB(31, 35, 40),
    Line = Color3.fromRGB(43, 47, 53),
    Text = Color3.fromRGB(231, 234, 238),
    Muted = Color3.fromRGB(139, 147, 158),
    Accent = Color3.fromRGB(163, 195, 181),
    Off = Color3.fromRGB(56, 61, 70),
    Visible = Color3.fromRGB(142, 214, 174),
    Hidden = Color3.fromRGB(231, 143, 119),
}
local palette = {
    Color3.fromRGB(160, 200, 236), Color3.fromRGB(145, 213, 177),
    Color3.fromRGB(233, 151, 143), Color3.fromRGB(229, 200, 137),
}
local defaults = {
    Enabled = true, Names = true, Distance = true, Boxes = true, Health = true,
    Skeleton = false, Tracers = false, Highlights = true, TeamCheck = false,
    TeamColors = false, MaxDistance = 1500, BoxStyle = "Углы",
    HighlightStyle = "Мягкий", FillOpacity = 24, OutlineOpacity = 85,
    Glow = true, Thickness = 1, PulseSpeed = 1, ColorIndex = 1,
    Radar = true, RadarRange = 250, Arrows = true, VisibilityColors = true,
    OnlyVisible = false, Tool = true, LookDirection = false, Velocity = false,
    LookLength = 9,
    SilentAim = true, AutoFire = false, AimTeamCheck = true, AimFOV = 360,
    AimDistance = 1500, AimPart = "Видимая",
    HeadMarker = true, TargetFocus = true, DeathShatter = true,
}
local settings = {}
for key, value in pairs(defaults) do settings[key] = value end
local alive, menuOpen = true, true
local connections, visuals, refreshers = {}, {}, {}
local activeTweens = setmetatable({}, {__mode = "k"})
local metadataDue, statsDue = 0, 0
local profileName = "Тактический"
local cleanup
local deadCharacters = setmetatable({}, {__mode = "k"})

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    connections[#connections + 1] = connection
    return connection
end
local function new(className, properties, parent)
    local item = Instance.new(className)
    for key, value in pairs(properties or {}) do item[key] = value end
    item.Parent = parent
    return item
end
local function corner(parent, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end
local function stroke(parent, color, transparency)
    return new("UIStroke", {Color = color or theme.Line, Thickness = 1,
        Transparency = transparency or 0}, parent)
end
local function tween(item, properties, duration)
    if activeTweens[item] then activeTweens[item]:Cancel() end
    local motion = TweenService:Create(item,
        TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
    activeTweens[item] = motion
    motion:Play()
end
local function label(parent, text, x, y, width, height, size, color, font)
    return new("TextLabel", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
        Text = text, Font = font or Enum.Font.Gotham, TextSize = size or 12,
        TextColor3 = color or theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end
local function button(parent, text, x, y, width, height)
    return new("TextButton", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = theme.Sidebar, BorderSizePixel = 0, AutoButtonColor = false,
        Text = text, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = theme.Text,
    }, parent)
end
local function refreshUI()
    for _, refresh in ipairs(refreshers) do refresh() end
end
local function setSetting(key, value)
    if settings[key] == value then return end
    settings[key] = value
    profileName = "Свои настройки"
    metadataDue = 0
    refreshUI()
end

local gui = new("ScreenGui", {
    Name = GUI_NAME, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None,
    ClipToDeviceSafeArea = false, ResetOnSpawn = false, DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local shutdown = new("BindableEvent", {Name = "Shutdown"}, gui)
local overlay = new("Frame", {Name = "Overlay", BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 1}, gui)

-- One line owns a sharp core and a faint, wider halo. No scene-wide post processing.
local function newLine(parent)
    local halo = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0, BackgroundTransparency = 0.88, Visible = false, ZIndex = 1}, parent)
    local core = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0, Visible = false, ZIndex = 2}, parent)
    return {Core = core, Halo = halo}
end
local function hideLine(line)
    line.Core.Visible = false
    line.Halo.Visible = false
end
local function drawLine(line, a, b, color, thickness, glow)
    local delta = b - a
    local length = delta.Magnitude
    if length < 0.25 then hideLine(line) return end
    local center = (a + b) * 0.5
    local rotation = math.deg(math.atan2(delta.Y, delta.X))
    local width = thickness or settings.Thickness
    line.Core.Position = UDim2.fromOffset(center.X, center.Y)
    line.Core.Size = UDim2.fromOffset(length, width)
    line.Core.Rotation = rotation
    line.Core.BackgroundColor3 = color
    line.Core.Visible = true
    line.Halo.Visible = glow ~= false and settings.Glow
    if line.Halo.Visible then
        line.Halo.Position = line.Core.Position
        line.Halo.Size = UDim2.fromOffset(length + 2, width + 5)
        line.Halo.Rotation = rotation
        line.Halo.BackgroundColor3 = color
    end
end

-- Menu: restrained typography, four tabs, flat rows, no external assets.
local MENU_W, MENU_H = 562, 516
local menu = new("CanvasGroup", {Name = "Menu", Size = UDim2.fromOffset(MENU_W, MENU_H),
    Position = UDim2.fromOffset(28, 100), BackgroundColor3 = theme.Background,
    BorderSizePixel = 0, GroupTransparency = 0, ZIndex = 20}, gui)
corner(menu, 9)
stroke(menu)
local menuScale = new("UIScale", {Scale = 1}, menu)
local header = new("Frame", {BackgroundTransparency = 1, Active = true,
    Size = UDim2.new(1, -46, 0, 68)}, menu)
for i = 1, 3 do
    new("Frame", {Position = UDim2.fromOffset(20 + (i - 1) * 5, 24 + (3 - i) * 3),
        Size = UDim2.fromOffset(2, 12 + (i - 1) * 3), BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0}, header)
end
label(header, "SPECTRA", 45, 17, 175, 23, 17, theme.Text, Enum.Font.GothamMedium)
label(header, "PLAYER VISUALS  /  03", 45, 39, 180, 14, 9, theme.Muted)
local master = button(header, "", 384, 22, 103, 26)
corner(master, 4)
master.Modal = true
local function updateMaster()
    master.Text = settings.Enabled and "ESP  ·  ВКЛ" or "ESP  ·  ВЫКЛ"
    master.TextColor3 = settings.Enabled and theme.Accent or theme.Muted
end
refreshers[#refreshers + 1] = updateMaster
connect(master.Activated, function() setSetting("Enabled", not settings.Enabled) end)
local closeButton = button(menu, "−", MENU_W - 48, 20, 30, 30)
closeButton.BackgroundTransparency = 1
closeButton.TextSize = 23
new("Frame", {Position = UDim2.fromOffset(16, 67), Size = UDim2.new(1, -32, 0, 1),
    BackgroundColor3 = theme.Line, BorderSizePixel = 0}, menu)
local sidebar = new("Frame", {Position = UDim2.fromOffset(0, 68),
    Size = UDim2.new(0, 124, 1, -102), BackgroundColor3 = theme.Sidebar, BorderSizePixel = 0}, menu)
local footer = label(menu, "", 17, MENU_H - 28, MENU_W - 34, 18, 10, theme.Muted)
local pages, tabs = {}, {}
local tabNames = {"ESP", "Эффекты", "Навигация", "Бой", "Профили"}
local activePage = "ESP"
local contentW = MENU_W - 156
local function showPage(name)
    activePage = name
    for tabName, page in pairs(pages) do
        page.Visible = tabName == name
        tabs[tabName].TextColor3 = tabName == name and theme.Text or theme.Muted
        tabs[tabName].BackgroundTransparency = tabName == name and 0 or 1
    end
end
for index, name in ipairs(tabNames) do
    local tabName = name
    local tab = button(sidebar, string.format("%02d  %s", index, name), 10, 16 + (index - 1) * 40, 104, 32)
    tab.TextSize = 11
    tab.BackgroundColor3 = theme.Hover
    corner(tab, 4)
    tabs[name] = tab
    local page = new("ScrollingFrame", {Name = name, Position = UDim2.fromOffset(140, 81),
        Size = UDim2.fromOffset(contentW, MENU_H - 129), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = theme.Off,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false}, menu)
    new("UIListLayout", {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    new("UIPadding", {PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 7)}, page)
    pages[name] = page
    connect(tab.Activated, function() showPage(tabName) end)
end
label(sidebar, "LOCAL\nR6 / R15", 21, 343, 89, 40, 10, theme.Muted)

local order = 0
local function row(pageName, height)
    order = order + 1
    return new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height),
        LayoutOrder = order}, pages[pageName])
end
local function divider(parent, height)
    new("Frame", {Position = UDim2.new(0, 0, 0, height - 1), Size = UDim2.new(1, -2, 0, 1),
        BackgroundColor3 = theme.Line, BackgroundTransparency = 0.45, BorderSizePixel = 0}, parent)
end
local function section(pageName, titleText, description)
    local item = row(pageName, description and 57 or 34)
    label(item, titleText, 0, 5, contentW - 12, 21, 14, theme.Text, Enum.Font.GothamMedium)
    if description then label(item, description, 0, 28, contentW - 12, 18, 10, theme.Muted) end
end
local function toggle(pageName, titleText, key, hint)
    local item = row(pageName, hint and 52 or 41)
    local hit = button(item, "", 0, 0, contentW - 8, hint and 51 or 40)
    hit.BackgroundTransparency = 1
    label(hit, titleText, 0, hint and 7 or 10, contentW - 69, 19, 12)
    if hint then label(hit, hint, 0, 27, contentW - 65, 16, 10, theme.Muted) end
    local pill = new("Frame", {AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(30, 16),
        BorderSizePixel = 0, BackgroundColor3 = theme.Off}, hit)
    corner(pill, 8)
    local dot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10), BackgroundColor3 = theme.Text, BorderSizePixel = 0}, pill)
    corner(dot, 5)
    local function refresh()
        tween(pill, {BackgroundColor3 = settings[key] and theme.Accent or theme.Off})
        tween(dot, {Position = UDim2.new(settings[key] and 1 or 0, settings[key] and -8 or 8, 0.5, 0)})
    end
    refreshers[#refreshers + 1] = refresh
    connect(hit.Activated, function() setSetting(key, not settings[key]) end)
    connect(hit.MouseEnter, function() tween(hit, {BackgroundTransparency = 0.45}) end)
    connect(hit.MouseLeave, function() tween(hit, {BackgroundTransparency = 1}) end)
    divider(item, hint and 52 or 41)
end
local sliderDrag
local function slider(pageName, titleText, key, minimum, maximum, step, unit)
    local item = row(pageName, 70)
    label(item, titleText, 0, 8, contentW - 114, 18, 12)
    local valueLabel = label(item, "", contentW - 112, 8, 96, 18, 11, theme.Muted, Enum.Font.Code)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    local trackHit = button(item, "", 3, 34, contentW - 24, 24)
    trackHit.BackgroundTransparency = 1
    local track = new("Frame", {Position = UDim2.new(0, 0, 0.5, -1),
        Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = theme.Off, BorderSizePixel = 0}, trackHit)
    local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = theme.Accent, BorderSizePixel = 0}, track)
    local dot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = theme.Text, BorderSizePixel = 0}, trackHit)
    corner(dot, 4)
    local function fromX(x)
        local percent = math.clamp((x - trackHit.AbsolutePosition.X) / math.max(trackHit.AbsoluteSize.X, 1), 0, 1)
        local value = minimum + math.floor(percent * (maximum - minimum) / step + 0.5) * step
        setSetting(key, math.clamp(value, minimum, maximum))
    end
    refreshers[#refreshers + 1] = function()
        local percent = (settings[key] - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(percent, 1)        dot.Position = UDim2.new(percent, 0, 0.5, 0)
        valueLabel.Text = string.format(step < 1 and "%.1f%s" or "%.0f%s", settings[key], unit or "")
    end
    connect(trackHit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliderDrag = {Input = input, Update = fromX}
            fromX(input.Position.X)
        elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.Right then
            setSetting(key, math.clamp(settings[key] + (input.KeyCode == Enum.KeyCode.Right and step or -step), minimum, maximum))
        end
    end)
    divider(item, 70)
end
local function choices(pageName, titleText, key, options)
    local item = row(pageName, 73)
    label(item, titleText, 0, 5, contentW - 12, 21, 12)
    local buttons = {}
    local width = (contentW - 16 - (#options - 1) * 5) / #options
    for i, option in ipairs(options) do
        local value = option
        local hit = button(item, option, (i - 1) * (width + 5), 33, width, 26)
        hit.TextSize = 10
        corner(hit, 3)
        buttons[option] = hit
        connect(hit.Activated, function() setSetting(key, value) end)
    end
    refreshers[#refreshers + 1] = function()
        for value, hit in pairs(buttons) do
            hit.BackgroundColor3 = settings[key] == value and theme.Hover or theme.Sidebar
            hit.TextColor3 = settings[key] == value and theme.Accent or theme.Muted
        end
    end
    divider(item, 73)
end

section("ESP", "Игроки", "Всё нужное — рядом с моделью.")
toggle("ESP", "Ники игроков", "Names")
toggle("ESP", "Расстояние", "Distance")
toggle("ESP", "Боксы", "Boxes")
choices("ESP", "Форма бокса", "BoxStyle", {"Углы", "Рамка"})
toggle("ESP", "Полоса здоровья", "Health")
toggle("ESP", "Скелет R6 / R15", "Skeleton")
toggle("ESP", "Линии до игроков", "Tracers")
toggle("ESP", "Предмет в руках", "Tool", "Название экипированного Tool")
toggle("ESP", "Скрывать союзников", "TeamCheck")
toggle("ESP", "Только видимые", "OnlyVisible", "Достаточно видимого края/макушки головы")
slider("ESP", "Максимальная дистанция", "MaxDistance", 100, 3000, 50, " st")
section("Эффекты", "Свет и контур", "Мягкий ореол, спокойная палитра.")
toggle("Эффекты", "Подсветка модели", "Highlights")
choices("Эффекты", "Стиль подсветки", "HighlightStyle", {"Мягкий", "Плотный", "Контур", "Пульс"})
toggle("Эффекты", "Ореол у линий", "Glow")
slider("Эффекты", "Плотность заливки", "FillOpacity", 0, 100, 1, "%")
slider("Эффекты", "Яркость контура", "OutlineOpacity", 0, 100, 1, "%")
slider("Эффекты", "Толщина линий", "Thickness", 1, 3, 0.5, " px")
slider("Эффекты", "Скорость пульса", "PulseSpeed", 0.4, 2.4, 0.1, " Hz")
toggle("Эффекты", "Цвет по видимости", "VisibilityColors", "Зелёный: виден · терракотовый: за препятствием")
toggle("Эффекты", "Цвета команд", "TeamColors", "Используются, когда выключен цвет по видимости")
toggle("Эффекты", "Метка головы", "HeadMarker", "Мини-точка на реально видимой части головы")
toggle("Эффекты", "Фокус текущей цели", "TargetFocus", "Анимированные углы вокруг цели silent/auto fire")
do
    local item = row("Эффекты", 62)
    label(item, "Основной цвет", 0, 6, 180, 19, 12)
    for i, color in ipairs(palette) do
        local colorIndex = i
        local hit = button(item, "", (i - 1) * 42, 30, 32, 22)
        hit.BackgroundColor3 = color
        corner(hit, 3)
        local border = stroke(hit, theme.Text, 1)
        refreshers[#refreshers + 1] = function() border.Transparency = settings.ColorIndex == colorIndex and 0 or 1 end
        connect(hit.Activated, function() setSetting("ColorIndex", colorIndex) end)
    end
end
section("Навигация", "Ориентация", "Радар поворачивается вместе с камерой.")
toggle("Навигация", "Радар", "Radar", "Игроки за пределами радиуса — на краю круга")
slider("Навигация", "Радиус радара", "RadarRange", 50, 1000, 25, " st")
toggle("Навигация", "Стрелки за экраном", "Arrows")
toggle("Навигация", "Направление головы", "LookDirection", "Линия показывает поворот Head")
slider("Навигация", "Длина линии взгляда", "LookLength", 3, 24, 1, " st")
toggle("Навигация", "Движение и скорость", "Velocity", "Вектор движения + скорость в studs/сек")

section("Бой", "Silent aim + Auto Fire", "Один pipeline: 25 мс поиск → flick → 10 мс → клик → возврат")
toggle("Бой", "Silent aim", "SilentAim", "ЛКМ использует silent-пайплайн; видимость перепроверяется перед выстрелом")
toggle("Бой", "Автовыстрел", "AutoFire", "Сам стреляет только когда есть живая видимая цель")
slider("Бой", "FOV наведения", "AimFOV", 5, 360, 5, "°")
choices("Бой", "Точка попадания", "AimPart", {"Голова", "Корпус", "Видимая"})
toggle("Бой", "Не стрелять в союзников", "AimTeamCheck")
section("Бой", "Эффект смерти", "Мёртвый игрок сразу удаляется из ESP и выбора цели")
toggle("Бой", "Рассыпание модели", "DeathShatter", "Локальный VFX; на aim/ESP не влияет")

local combatKeys = {
    SilentAim=true, AutoFire=true, AimTeamCheck=true, AimFOV=true, AimDistance=true,
    AimPart=true, HeadMarker=true, TargetFocus=true, DeathShatter=true,
}
local profiles = {
    {Name = "Чистый", Description = "Имена, здоровье, мягкий контур. Меньше деталей.",
        Values = {Boxes = false, Distance = false, Radar = false, Arrows = false,
            VisibilityColors = false, Tool = false, HighlightStyle = "Контур", Glow = false}},
    {Name = "Тактический", Description = "Углы, видимость, предметы, радар и стрелки.", Values = {}},
    {Name = "Подробный", Description = "Все слои ESP, скелет, взгляд и движение.",
        Values = {Skeleton = true, Tracers = true, LookDirection = true, Velocity = true,
            HighlightStyle = "Пульс"}},
}
section("Профили", "Готовые пресеты", "Применяются сразу. Настройки — на текущую сессию.")
for _, profile in ipairs(profiles) do
    local preset = profile
    local item = row("Профили", 83)
    local hit = button(item, "", 0, 7, contentW - 10, 66)
    corner(hit, 5)
    local border = stroke(hit)
    label(hit, profile.Name, 12, 10, contentW - 50, 21, 13, theme.Text, Enum.Font.GothamMedium)
    label(hit, profile.Description, 12, 36, contentW - 39, 18, 10, theme.Muted)
    refreshers[#refreshers + 1] = function()
        border.Color = profileName == preset.Name and theme.Accent or theme.Line
    end
    connect(hit.Activated, function()
        for key, value in pairs(defaults) do
            if not combatKeys[key] then settings[key] = value end
        end
        for key, value in pairs(preset.Values) do settings[key] = value end
        profileName = preset.Name
        metadataDue = 0
        refreshUI()
    end)
end
local unloadRow = row("Профили", 59)
local unload = button(unloadRow, "Выгрузить Spectra", 0, 15, contentW - 10, 32)
unload.TextColor3 = theme.Muted
corner(unload, 4)
connect(unload.Activated, function() if cleanup then cleanup() end end)

local launcher = button(gui, "VISUALS", 22, 65, 88, 29)
launcher.Name = "OpenMenu"
launcher.ZIndex = 30
launcher.TextSize = 10
corner(launcher, 5)
stroke(launcher)
local menuTransition = 0
local function setMenuOpen(open)
    menuOpen = open
    master.Modal = open
    menuTransition = menuTransition + 1
    local generation = menuTransition
    sliderDrag = nil
    if open then menu.Visible = true end
    tween(menu, {GroupTransparency = open and 0 or 1}, 0.16)
    if not open then
        task.delay(0.17, function()
            if alive and menuTransition == generation and not menuOpen then menu.Visible = false end
        end)
    end
    launcher.TextColor3 = open and theme.Accent or theme.Text
end
connect(closeButton.Activated, function() setMenuOpen(false) end)
connect(launcher.Activated, function() setMenuOpen(not menuOpen) end)

-- Radar lies outside the menu, so closing the menu leaves the HUD visible.
local radar = new("Frame", {Name = "Radar", AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -22, 0, 68), Size = UDim2.fromOffset(182, 210),
    BackgroundTransparency = 1, ZIndex = 5}, gui)
local radarScale = new("UIScale", {Scale = 1}, radar)
local radarTitle = label(radar, "RADAR  /  250 st", 0, 0, 182, 18, 10, theme.Muted, Enum.Font.Code)
radarTitle.TextXAlignment = Enum.TextXAlignment.Center
local disc = new("Frame", {Name = "Disc", Position = UDim2.fromOffset(6, 28),
    Size = UDim2.fromOffset(170, 170), BackgroundColor3 = theme.Background,
    BackgroundTransparency = 0.12, BorderSizePixel = 0}, radar)
corner(disc, 85)
stroke(disc)
local ring = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(85, 85), BackgroundTransparency = 1}, disc)
corner(ring, 43)
stroke(ring, theme.Line, 0.35)
for _, dimensions in ipairs({{1, 152}, {152, 1}}) do
    new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(dimensions[1], dimensions[2]), BackgroundColor3 = theme.Line,
        BorderSizePixel = 0, BackgroundTransparency = 0.25}, disc)
end
local centerDot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(5, 5), Rotation = 45, BackgroundColor3 = theme.Text,
    BorderSizePixel = 0, ZIndex = 4}, disc)
label(disc, "ВПЕРЁД", 48, 7, 74, 12, 8, theme.Muted).TextXAlignment = Enum.TextXAlignment.Center

local lastViewport = Vector2.new(0, 0)
local safeTop = 50
local function clampMenu()
    local viewport = lastViewport
    local size = Vector2.new(MENU_W, MENU_H) * menuScale.Scale
    menu.Position = UDim2.fromOffset(
        math.clamp(menu.Position.X.Offset, 8, math.max(8, viewport.X - size.X - 8)),
        math.clamp(menu.Position.Y.Offset, safeTop, math.max(safeTop, viewport.Y - size.Y - 8)))
end
local function updateLayout(viewport)
    lastViewport = viewport
    local inset = GuiService:GetGuiInset()
    safeTop = math.max(10, inset.Y + 8)
    menuScale.Scale = math.max(0.2, math.min(1, (viewport.X - 16) / MENU_W, (viewport.Y - safeTop - 10) / MENU_H))
    radarScale.Scale = viewport.X < 600 and 0.72 or 1
    radar.Position = UDim2.new(1, -16, 0, safeTop + 12)
    launcher.Position = UDim2.fromOffset(16, safeTop + 4)
    clampMenu()
end
local menuDrag
connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        menuDrag = {Input = input, Start = Vector2.new(input.Position.X, input.Position.Y), Position = menu.Position}
    end
end)
connect(UserInputService.InputChanged, function(input)
    local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
    if sliderDrag and (input == sliderDrag.Input or (isMouse and sliderDrag.Input.UserInputType == Enum.UserInputType.MouseButton1)) then
        sliderDrag.Update(input.Position.X)
    elseif menuDrag and (input == menuDrag.Input or (isMouse and menuDrag.Input.UserInputType == Enum.UserInputType.MouseButton1)) then
        local delta = Vector2.new(input.Position.X, input.Position.Y) - menuDrag.Start
        menu.Position = UDim2.fromOffset(menuDrag.Position.X.Offset + delta.X, menuDrag.Position.Y.Offset + delta.Y)
        clampMenu()
    end
end)
connect(UserInputService.InputEnded, function(input)
    if sliderDrag and input == sliderDrag.Input then sliderDrag = nil end
    if menuDrag and input == menuDrag.Input then menuDrag = nil end
end)
connect(UserInputService.WindowFocusReleased, function() sliderDrag = nil menuDrag = nil end)
connect(UserInputService.InputBegan, function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightShift then setMenuOpen(not menuOpen)
    elseif input.KeyCode == Enum.KeyCode.End then if cleanup then cleanup() end end
end)

local r15Bones = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local r6Bones = {{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}}
local corners = {
    Vector3.new(-1,-1,-1), Vector3.new(1,-1,-1), Vector3.new(-1,1,-1), Vector3.new(1,1,-1),
    Vector3.new(-1,-1,1), Vector3.new(1,-1,1), Vector3.new(-1,1,1), Vector3.new(1,1,1),
}
local boxEdges = {{1,2},{1,3},{2,4},{3,4},{5,6},{5,7},{6,8},{7,8},{1,5},{2,6},{3,7},{4,8}}
local function espLabel(parent, fontSize)
    local item = label(parent, "", 0, 0, 260, 18, fontSize, theme.Text, Enum.Font.GothamMedium)
    item.AnchorPoint = Vector2.new(0.5, 0)
    item.TextXAlignment = Enum.TextXAlignment.Center
    item.TextStrokeColor3 = Color3.new(0, 0, 0)
    item.TextStrokeTransparency = 0.25
    item.Visible = false
    item.ZIndex = 3
    return item
end
local function newVisuals(player)
    local layer = new("Frame", {Name = tostring(player.UserId), Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Visible = false}, overlay)
    local screen = new("Frame", {Name = "OnScreen", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Visible = false}, layer)
    local data = {Player = player, Layer = layer, Screen = screen, Box = {}, Bones = {},
        Arrow = {}, VelocityLines = {}, Character = nil, Highlight = nil, Eligible = false,
        RayDue = 0, VisibleToCamera = nil, Parts = {}, BonePairs = {}, DistanceValue = 0}
    for i = 1, 8 do data.Box[i] = newLine(screen) end
    for i = 1, 14 do data.Bones[i] = newLine(screen) end
    for i = 1, 3 do data.Arrow[i] = newLine(layer) data.VelocityLines[i] = newLine(screen) end
    data.Tracer, data.Look = newLine(screen), newLine(screen)
    data.Name, data.Details, data.HPText = espLabel(screen, 12), espLabel(screen, 10), espLabel(screen, 9)
    data.ArrowLabel = espLabel(layer, 10)
    data.HeadDot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = theme.Accent, BorderSizePixel = 0, Visible = false, ZIndex = 5}, screen)
    corner(data.HeadDot, 3)
    data.HeadDotStroke = stroke(data.HeadDot, theme.Text, 0.22)
    data.HealthBack = new("Frame", {BackgroundColor3 = Color3.fromRGB(9, 11, 13),
        BorderSizePixel = 0, Visible = false, ZIndex = 3}, screen)
    data.HealthFill = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        BorderSizePixel = 0, BackgroundColor3 = theme.Accent}, data.HealthBack)
    data.RadarDot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(6, 6), BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0, Visible = false, ZIndex = 3}, disc)
    corner(data.RadarDot, 3)
    return data
end
local function releaseHighlight(data)
    if data.Highlight then data.Highlight:Destroy() data.Highlight = nil end
end
local function hide(data)
    data.Layer.Visible = false
    data.RadarDot.Visible = false
    if data.Highlight then data.Highlight.Enabled = false end
end
local function addPlayer(player)
    if player ~= localPlayer and not visuals[player] then
        visuals[player] = newVisuals(player)
        metadataDue = 0
    end
end
local function removePlayer(player)
    local data = visuals[player]
    if not data then return end
    releaseHighlight(data)
    data.Layer:Destroy()
    data.RadarDot:Destroy()
    visuals[player] = nil
end
local function isTeammate(player)
    return not localPlayer.Neutral and not player.Neutral and localPlayer.Team ~= nil and player.Team == localPlayer.Team
end
local function getColor(data)
    if settings.VisibilityColors and data.VisibleToCamera ~= nil then
        return data.VisibleToCamera and theme.Visible or theme.Hidden    end
    if settings.TeamColors and not data.Player.Neutral and data.Player.Team then return data.Player.TeamColor.Color end
    return palette[settings.ColorIndex]
end

-- Cache body bounds and rig connections at ~7 Hz, leaving projection smooth each frame.
-- Accessory/Tool parts are excluded so held items cannot inflate the body box.
local function cacheCharacter(data)
    local character = data.Player.Character
    if data.Character ~= character then
        releaseHighlight(data)
        data.Character = character
        data.VisibleToCamera = nil
        data.RayDue = 0
    end
    data.Root = character and character:FindFirstChild("HumanoidRootPart")
    data.Head = character and character:FindFirstChild("Head")
    data.Humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not data.Root or not data.Root:IsA("BasePart") or not data.Head or not data.Head:IsA("BasePart") or not data.Humanoid then
        data.Eligible = false
        return
    end
    data.Parts, data.BonePairs = {}, {}
    local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            data.Parts[part.Name] = part
            local relative = data.Root.CFrame:ToObjectSpace(part.CFrame)
            for _, sign in ipairs(corners) do
                local point = relative:PointToWorldSpace(part.Size * sign * 0.5)
                minV = Vector3.new(math.min(minV.X, point.X), math.min(minV.Y, point.Y), math.min(minV.Z, point.Z))
                maxV = Vector3.new(math.max(maxV.X, point.X), math.max(maxV.Y, point.Y), math.max(maxV.Z, point.Z))
            end
        end
    end
    data.BoundsCenter = (minV + maxV) * 0.5
    data.BoundsHalf = (maxV - minV) * 0.5 + Vector3.new(0.1, 0.1, 0.1)
    local rig = data.Humanoid.RigType == Enum.HumanoidRigType.R15 and r15Bones or r6Bones
    for index, pair in ipairs(rig) do data.BonePairs[index] = {data.Parts[pair[1]], data.Parts[pair[2]]} end
    local tool = character:FindFirstChildOfClass("Tool")
    data.ToolName = tool and tool.Name or ""
    data.Eligible = not deadCharacters[character]
        and data.Humanoid.Health > 0 and character:IsDescendantOf(workspace)
end
local function updateMetadata(camera, origin, now)
    local candidates = {}
    for _, data in pairs(visuals) do
        cacheCharacter(data)
        data.AllowHighlight = false
        if data.Eligible then
            data.DistanceValue = (origin - data.Root.Position).Magnitude
            data.Eligible = data.DistanceValue <= settings.MaxDistance and not (settings.TeamCheck and isTeammate(data.Player))
            if data.Eligible and settings.Highlights and settings.Enabled then candidates[#candidates + 1] = data end
        end
    end
    table.sort(candidates, function(a, b)
        if a.DistanceValue == b.DistanceValue then return a.Player.UserId < b.Player.UserId end
        return a.DistanceValue < b.DistanceValue
    end)
    for index = 1, math.min(24, #candidates) do candidates[index].AllowHighlight = true end
    for _, data in pairs(visuals) do
        if not data.AllowHighlight then releaseHighlight(data) end
    end
    metadataDue = now + 0.15
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local rayBudget = 0
local function headSamplePoints(head)
    local sx = math.max(0.08, head.Size.X * 0.42)
    local sy = math.max(0.08, head.Size.Y * 0.42)
    local sz = math.max(0.08, head.Size.Z * 0.34)
    local cf = head.CFrame
    return {
        head.Position,
        cf:PointToWorldSpace(Vector3.new(0, sy, 0)),
        cf:PointToWorldSpace(Vector3.new(-sx, 0, 0)),
        cf:PointToWorldSpace(Vector3.new(sx, 0, 0)),
        cf:PointToWorldSpace(Vector3.new(0, 0, -sz)),
        cf:PointToWorldSpace(Vector3.new(0, 0, sz)),
    }
end
local function updateVisibility(data, camera, now)
    if not settings.VisibilityColors and not settings.OnlyVisible and not settings.HeadMarker then return end
    if now < data.RayDue or rayBudget < 1 then return end
    local start = camera.CFrame.Position
    local function clearPoint(point)
        if rayBudget < 1 then return false end
        rayBudget = rayBudget - 1
        local result = workspace:Raycast(start, point - start, rayParams)
        return not result or result.Instance:IsDescendantOf(data.Character)
    end
    local visible = false
    for _, point in ipairs(headSamplePoints(data.Head)) do
        if clearPoint(point) then
            visible = true
            break
        end
    end
    if not visible and rayBudget > 0 then
        visible = clearPoint(data.Root.Position)
    end
    data.VisibleToCamera = visible
    data.RayDue = now + 0.10 + (math.abs(data.Player.UserId) % 5) * 0.006
end

-- Clip world segments at the camera near plane before projecting them.
local NEAR = 0.08
local function projectSegment(camera, a, b)
    local ca, cb = camera.CFrame:PointToObjectSpace(a), camera.CFrame:PointToObjectSpace(b)
    if ca.Z >= -NEAR and cb.Z >= -NEAR then return nil end
    if ca.Z > -NEAR then ca = ca:Lerp(cb, (-NEAR - ca.Z) / (cb.Z - ca.Z))
    elseif cb.Z > -NEAR then cb = cb:Lerp(ca, (-NEAR - cb.Z) / (ca.Z - cb.Z)) end
    local pa = camera:WorldToViewportPoint(camera.CFrame:PointToWorldSpace(ca))
    local pb = camera:WorldToViewportPoint(camera.CFrame:PointToWorldSpace(cb))
    local a2, b2 = Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y)
    -- Liang-Barsky clipping keeps near-camera lines finite and inside the viewport.
    local delta, t0, t1 = b2 - a2, 0, 1
    local view = camera.ViewportSize
    local function clip(p, q)
        if math.abs(p) < 0.000001 then return q >= 0 end
        local ratio = q / p
        if p < 0 then t0 = math.max(t0, ratio) else t1 = math.min(t1, ratio) end
        return t0 <= t1
    end
    if not clip(-delta.X, a2.X) or not clip(delta.X, view.X - a2.X)
        or not clip(-delta.Y, a2.Y) or not clip(delta.Y, view.Y - a2.Y) then return nil end
    return a2 + delta * t0, a2 + delta * t1
end
local function bodyRect(data, camera)
    local localPoints, projected = {}, {}
    local bounds = data.Root.CFrame * CFrame.new(data.BoundsCenter)
    for index, sign in ipairs(corners) do
        localPoints[index] = camera.CFrame:PointToObjectSpace(bounds:PointToWorldSpace(data.BoundsHalf * sign))
        if localPoints[index].Z <= -NEAR then projected[#projected + 1] = localPoints[index] end
    end
    for _, edge in ipairs(boxEdges) do
        local a, b = localPoints[edge[1]], localPoints[edge[2]]
        if (a.Z < -NEAR) ~= (b.Z < -NEAR) then
            projected[#projected + 1] = a:Lerp(b, (-NEAR - a.Z) / (b.Z - a.Z))
        end
    end
    if #projected == 0 then return nil end
    local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
    for _, point in ipairs(projected) do
        local p = camera:WorldToViewportPoint(camera.CFrame:PointToWorldSpace(point))
        left, top = math.min(left, p.X), math.min(top, p.Y)
        right, bottom = math.max(right, p.X), math.max(bottom, p.Y)
    end
    local view = camera.ViewportSize
    if right < 0 or bottom < 0 or left > view.X or top > view.Y then return nil end
    left, right = math.clamp(left, 1, view.X - 1), math.clamp(right, 1, view.X - 1)
    top, bottom = math.clamp(top, 1, view.Y - 1), math.clamp(bottom, 1, view.Y - 1)
    if right - left < 2 or bottom - top < 2 then return nil end
    return left, top, right, bottom
end
local function drawBox(data, left, top, right, bottom, color)
    for _, line in ipairs(data.Box) do hideLine(line) end
    if not settings.Boxes then return end
    local a, b, c, d = Vector2.new(left, top), Vector2.new(right, top), Vector2.new(right, bottom), Vector2.new(left, bottom)
    if settings.BoxStyle == "Рамка" then
        drawLine(data.Box[1], a, b, color) drawLine(data.Box[2], b, c, color)
        drawLine(data.Box[3], c, d, color) drawLine(data.Box[4], d, a, color)
    else
        local x, y = math.min((right - left) * 0.24, 24), math.min((bottom - top) * 0.17, 27)
        drawLine(data.Box[1], a, a + Vector2.new(x, 0), color)
        drawLine(data.Box[2], a, a + Vector2.new(0, y), color)
        drawLine(data.Box[3], b, b - Vector2.new(x, 0), color)
        drawLine(data.Box[4], b, b + Vector2.new(0, y), color)
        drawLine(data.Box[5], c, c - Vector2.new(x, 0), color)
        drawLine(data.Box[6], c, c - Vector2.new(0, y), color)
        drawLine(data.Box[7], d, d + Vector2.new(x, 0), color)
        drawLine(data.Box[8], d, d - Vector2.new(0, y), color)
    end
end
local function drawWorldLine(line, camera, a, b, color)
    local first, second = projectSegment(camera, a, b)
    if first then drawLine(line, first, second, color) else hideLine(line) end
end
local function updateHighlight(data, color, now)
    if not data.AllowHighlight or not settings.Highlights then return end
    if not data.Highlight then
        data.Highlight = new("Highlight", {Name = "SpectraHighlight", Adornee = data.Character,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false}, data.Character)
    end
    local opacity = settings.FillOpacity / 100
    if settings.HighlightStyle == "Контур" then opacity = 0
    elseif settings.HighlightStyle == "Плотный" then opacity = math.min(1, opacity * 2.4)
    elseif settings.HighlightStyle == "Пульс" then
        opacity = opacity * (0.55 + 0.45 * (0.5 + 0.5 * math.sin(now * math.pi * 2 * settings.PulseSpeed)))
    end
    local highlight = data.Highlight
    highlight.Adornee = data.Character
    highlight.DepthMode = settings.OnlyVisible and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.OutlineColor = color:Lerp(theme.Text, 0.18)
    highlight.FillTransparency = 1 - opacity
    highlight.OutlineTransparency = 1 - settings.OutlineOpacity / 100
    highlight.Enabled = true
end
local function updateArrow(data, camera, color)
    for _, line in ipairs(data.Arrow) do hideLine(line) end
    data.ArrowLabel.Visible = false
    if not settings.Arrows then return end
    local point, onScreen = camera:WorldToViewportPoint(data.Root.Position)
    if onScreen and point.Z > 0 then return end
    local relative = camera.CFrame:PointToObjectSpace(data.Root.Position)
    local direction
    if relative.Z < -NEAR then
        direction = Vector2.new(point.X - camera.ViewportSize.X * 0.5, point.Y - camera.ViewportSize.Y * 0.5)
    else
        direction = Vector2.new(relative.X, -relative.Y)
    end
    if direction.Magnitude < 0.001 then direction = Vector2.new(0, 1) end
    direction = direction.Unit
    local view = camera.ViewportSize
    local center = view * 0.5
    local rx, ry = math.max(15, center.X - 40), math.max(15, center.Y - safeTop - 30)
    local t = 1 / math.sqrt((direction.X / rx)^2 + (direction.Y / ry)^2)
    local tip = center + direction * t
    local side = Vector2.new(-direction.Y, direction.X)
    local back = tip - direction * 12
    drawLine(data.Arrow[1], tip, back + side * 5, color, 2)
    drawLine(data.Arrow[2], tip, back - side * 5, color, 2)
    drawLine(data.Arrow[3], back - side * 5, back + side * 5, color, 1)
    local textPosition = tip - direction * 32
    data.ArrowLabel.Position = UDim2.fromOffset(textPosition.X, textPosition.Y - 7)
    data.ArrowLabel.Text = string.format("%d", math.floor(data.DistanceValue + 0.5))
    data.ArrowLabel.TextColor3 = color
    data.ArrowLabel.Visible = settings.Distance
end
local function updateRadar(data, camera, origin, color)
    data.RadarDot.Visible = settings.Radar
    if not settings.Radar then return end
    local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
    if forward.Magnitude < 0.001 then
        local right = camera.CFrame.RightVector
        forward = Vector3.new(right.Z, 0, -right.X)
    end
    forward = forward.Unit
    local right = Vector3.new(-forward.Z, 0, forward.X)
    local delta = data.Root.Position - origin
    local offset = Vector2.new(delta:Dot(right), -delta:Dot(forward)) / settings.RadarRange * 76
    local outside = offset.Magnitude > 76
    if outside then offset = offset.Unit * 76 end
    data.RadarDot.Position = UDim2.fromOffset(85 + offset.X, 85 + offset.Y)
    data.RadarDot.BackgroundColor3 = color
    data.RadarDot.BackgroundTransparency = outside and 0.4 or 0
end
local function updatePlayer(data, camera, origin, now)
    if not settings.Enabled or not data.Eligible or data.Player.Character ~= data.Character
        or not data.Root or not data.Root.Parent or not data.Head or not data.Head.Parent
        or deadCharacters[data.Character]
        or not data.Humanoid or data.Humanoid.Health <= 0 then hide(data) return false end
    data.DistanceValue = (data.Root.Position - origin).Magnitude
    if data.DistanceValue > settings.MaxDistance or (settings.TeamCheck and isTeammate(data.Player)) then hide(data) return false end
    updateVisibility(data, camera, now)
    if settings.OnlyVisible and data.VisibleToCamera ~= true then hide(data) return false end
    data.Layer.Visible = true
    local color = getColor(data)
    updateHighlight(data, color, now)
    updateRadar(data, camera, origin, color)
    local left, top, right, bottom = bodyRect(data, camera)
    data.Screen.Visible = left ~= nil
    if not left then
        data.HeadDot.Visible = false
        updateArrow(data, camera, color)
        return true
    end
    for _, line in ipairs(data.Arrow) do hideLine(line) end
    data.ArrowLabel.Visible = false
    drawBox(data, left, top, right, bottom, color)
    local middle, height = (left + right) * 0.5, bottom - top
    data.HeadDot.Visible = false
    if settings.HeadMarker and data.VisibleToCamera == true and data.Head and data.Head.Parent then
        local hp, headOnScreen = camera:WorldToViewportPoint(data.Head.Position)
        if headOnScreen and hp.Z > 0 then
            data.HeadDot.Position = UDim2.fromOffset(hp.X, hp.Y)
            data.HeadDot.BackgroundColor3 = color
            data.HeadDotStroke.Color = color:Lerp(theme.Text, 0.45)
            data.HeadDot.Visible = true
        end
    end
    data.Name.Visible = settings.Names
    data.Name.Position = UDim2.fromOffset(middle, math.max(2, top - 21))
    data.Name.Text = data.Player.DisplayName == data.Player.Name and data.Player.Name or (data.Player.DisplayName .. "  @" .. data.Player.Name)
    data.Name.TextColor3 = color
    local details = {}
    if settings.Distance then details[#details + 1] = string.format("%d st", math.floor(data.DistanceValue + 0.5)) end
    if settings.Tool and data.ToolName ~= "" then details[#details + 1] = data.ToolName end
    if settings.Velocity then details[#details + 1] = string.format("%.0f st/s", data.Root.AssemblyLinearVelocity.Magnitude) end
    data.Details.Text = table.concat(details, "  ·  ")
    data.Details.Visible = #details > 0
    data.Details.Position = UDim2.fromOffset(middle, math.min(bottom + 4, camera.ViewportSize.Y - 19))
    data.Details.TextColor3 = theme.Text
    local ratio = math.clamp(data.Humanoid.Health / math.max(data.Humanoid.MaxHealth, 1), 0, 1)
    data.HealthBack.Visible = settings.Health
    data.HealthBack.Position = UDim2.fromOffset(left - 6, top)
    data.HealthBack.Size = UDim2.fromOffset(3, height)
    data.HealthFill.Size = UDim2.new(1, 0, ratio, 0)
    data.HealthFill.BackgroundColor3 = theme.Hidden:Lerp(theme.Visible, ratio)
    data.HPText.Visible = settings.Health and ratio < 0.995
    data.HPText.Position = UDim2.fromOffset(left - 19, math.clamp(bottom - height * ratio - 7, top, math.max(top, bottom - 12)))
    data.HPText.Text = tostring(math.ceil(data.Humanoid.Health))
    data.HPText.TextColor3 = data.HealthFill.BackgroundColor3
    if settings.Tracers then
        drawLine(data.Tracer, Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y - 8), Vector2.new(middle, bottom), color)
    else hideLine(data.Tracer) end
    for index, line in ipairs(data.Bones) do
        local pair = data.BonePairs[index]
        if settings.Skeleton and pair and pair[1] and pair[2] and pair[1].Parent and pair[2].Parent then
            drawWorldLine(line, camera, pair[1].Position, pair[2].Position, color)        else hideLine(line) end
    end
    if settings.LookDirection then
        drawWorldLine(data.Look, camera, data.Head.Position, data.Head.Position + data.Head.CFrame.LookVector * settings.LookLength, color)
    else hideLine(data.Look) end
    for _, line in ipairs(data.VelocityLines) do hideLine(line) end
    local velocity = data.Root.AssemblyLinearVelocity
    if settings.Velocity and velocity.Magnitude > 0.8 then
        local endpoint = data.Root.Position + velocity.Unit * math.min(18, velocity.Magnitude * 0.35)
        local a, b = projectSegment(camera, data.Root.Position, endpoint)
        if a and (b - a).Magnitude > 3 then
            local direction = (b - a).Unit
            local side = Vector2.new(-direction.Y, direction.X)
            drawLine(data.VelocityLines[1], a, b, color)
            drawLine(data.VelocityLines[2], b, b - direction * 7 + side * 3, color)
            drawLine(data.VelocityLines[3], b, b - direction * 7 - side * 3, color)
        end
    end
    return true
end

-- Client-only camera snap combat. It contains no RemoteEvent or server-specific weapon logic.
local function startCombat()
    local controller = {Running = true, Target = nil, Status = "Готов"}
    local ACTION = GUI_NAME .. "_ClickOnlyFire"
    local ACQUIRE_DELAY = 0.025
    local SHOT_DELAY = 0.010
    local TARGET_REFRESH = 0.025
    local AUTO_FIRE_GAP = 0.085
    local serviceConnections, watchers = {}, {}
    local candidateDue, autoFireDue = 0, 0
    local currentTarget, currentPart, focused = nil, nil, true
    local pendingAcquire, shot = nil, nil
    local debrisFolder = new("Folder", {Name = "SpectraLocalFragments"}, workspace)
    local effects, pool, hiddenBodies = {}, {}, {}
    local createdFragments, effectClock, smoothFPS = 0, 0, 60
    local deathTimes = {}
    local stopped = false
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true

    local function bind(signal, callback)
        local connection = signal:Connect(callback)
        serviceConnections[#serviceConnections + 1] = connection
        return connection
    end
    local function disconnect(list)
        for _, connection in ipairs(list) do connection:Disconnect() end
    end

    local reticle = new("Frame", {Name = "CombatReticle", Size = UDim2.fromOffset(6, 6),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = theme.Text, BackgroundTransparency = 0.15, BorderSizePixel = 0,
        ZIndex = 6, Visible = false}, overlay)
    corner(reticle, 3)
    local targetMarker = new("Frame", {Name = "AimTarget", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30),
        BorderSizePixel = 0, Visible = false, ZIndex = 14}, overlay)
    local targetCorners = {}
    for i = 1, 8 do
        targetCorners[i] = newLine(targetMarker)
        targetCorners[i].Core.ZIndex = 16
        targetCorners[i].Halo.ZIndex = 15
    end
    local targetDot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4),
        BackgroundColor3 = theme.Accent, BorderSizePixel = 0, ZIndex = 16}, targetMarker)
    corner(targetDot, 2)
    local combatStatus = label(gui, "", 0, 0, 520, 18, 10, theme.Muted, Enum.Font.Code)
    combatStatus.Name = "CombatStatus"
    combatStatus.AnchorPoint = Vector2.new(0.5, 1)
    combatStatus.Position = UDim2.new(0.5, 0, 1, -26)
    combatStatus.TextXAlignment = Enum.TextXAlignment.Center
    combatStatus.ZIndex = 6

    local function ownCharacter()
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local head = character and character:FindFirstChild("Head")
        if not humanoid or humanoid.Health <= 0 or not head or not head:IsA("BasePart") then return nil end
        return character, head
    end
    local function blocked()
        return not controller.Running or menuOpen or not focused or GuiService.MenuIsOpen
            or UserInputService:GetFocusedTextBox() ~= nil or not ownCharacter()
    end
    local function updateFilter(camera)
        local ignored = {camera, debrisFolder}
        if localPlayer.Character then ignored[#ignored + 1] = localPlayer.Character end
        rayParams.FilterDescendantsInstances = ignored
    end
    local function enemyAlive(player)
        if player == localPlayer or (settings.AimTeamCheck and isTeammate(player)) then return false end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        return character and not deadCharacters[character] and character:IsDescendantOf(workspace)
            and humanoid and humanoid.Health > 0 and not character:FindFirstChildOfClass("ForceField")
    end
    local function clear(origin, point, character)
        local delta = point - origin
        if delta.Magnitude < 0.001 then return true end
        local result = workspace:Raycast(origin, delta, rayParams)
        return not result or result.Instance:IsDescendantOf(character)
    end
    local function visiblePointOnPart(origin, part, character)
        if not part or not part:IsA("BasePart") then return nil end
        if part.Name ~= "Head" then
            return clear(origin, part.Position, character) and part.Position or nil
        end
        for _, point in ipairs(headSamplePoints(part)) do
            if clear(origin, point, character) then return point end
        end
        return nil
    end
    local function points(character)
        local head = character:FindFirstChild("Head")
        local body = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
        local result = {}
        if settings.AimPart ~= "Корпус" and head and head:IsA("BasePart") then result[#result + 1] = head end
        if settings.AimPart ~= "Голова" and body and body:IsA("BasePart") then result[#result + 1] = body end
        return result
    end
    local function withinFOV(forward, delta)
        if settings.AimFOV >= 359.5 then return true end
        local halfAngle = math.clamp(settings.AimFOV * 0.5, 0.5, 179.5)
        return forward:Dot(delta.Unit) >= math.cos(math.rad(halfAngle))
    end
    local function findTarget(camera)
        if blocked() then return nil end
        local ownCharacterModel = ownCharacter()
        if not ownCharacterModel then return nil end
        updateFilter(camera)
        local origin, forward = camera.CFrame.Position, camera.CFrame.LookVector
        local candidates = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if enemyAlive(player) then
                local options, score = points(player.Character), math.huge
                for _, part in ipairs(options) do
                    local delta = part.Position - origin
                    local distance = delta.Magnitude
                    if distance > 0.05 and distance <= settings.AimDistance and withinFOV(forward, delta) then
                        local value = 1 - forward:Dot(delta / distance)
                        if player == currentTarget then value = value * 0.85 end
                        score = math.min(score, value)
                    end
                end
                if score < math.huge then candidates[#candidates + 1] = {Player = player, Points = options, Score = score} end
            end
        end
        table.sort(candidates, function(a, b)
            if a.Score == b.Score then return a.Player.UserId < b.Player.UserId end
            return a.Score < b.Score
        end)
        for index = 1, math.min(6, #candidates) do
            local candidate = candidates[index]
            for _, part in ipairs(candidate.Points) do
                local delta = part.Position - origin
                if delta.Magnitude > 0.05 and delta.Magnitude <= settings.AimDistance
                    and withinFOV(forward, delta) then
                    local visiblePoint = visiblePointOnPart(origin, part, candidate.Player.Character)
                    if visiblePoint then
                        return candidate.Player, part, visiblePoint
                    end
                end
            end
        end
        return nil
    end
    local function setTarget(player, part)
        currentTarget, currentPart = player, part
        controller.Target = player
    end
    local function restoreShot(camera, status)
        if shot and camera and shot.Camera == camera then camera.CFrame = shot.Original end
        shot = nil
        if status then controller.Status = status end
    end

    local bindFireAction
    local function virtualClick(camera)
        ContextActionService:UnbindAction(ACTION)
        local position = UserInputService:GetMouseLocation()
        local downOk, downError = pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(position, camera.CFrame)
        end)
        task.delay(0.025, function()
            pcall(function()
                local currentCamera = workspace.CurrentCamera
                VirtualUser:Button1Up(position, currentCamera and currentCamera.CFrame or camera.CFrame)
            end)
            if controller.Running then bindFireAction() end
        end)
        if not downOk then return false, "Виртуальный ЛКМ недоступен: " .. tostring(downError) end
        return true, "клик"
    end

    local function beginClick(auto)
        if pendingAcquire or shot or blocked() then return false end
        pendingAcquire = {At = os.clock() + ACQUIRE_DELAY, Auto = auto == true}
        controller.Status = auto and "Auto · поиск цели · 25 ms" or "Поиск цели · 25 ms"
        return true
    end

    local function acquireForShot(camera, now)
        if not pendingAcquire or now < pendingAcquire.At then return end
        local request = pendingAcquire
        pendingAcquire = nil
        if blocked() then return end
        local player, part, point = findTarget(camera)
        if not player then
            if request.Auto then
                controller.Status = "Auto · нет видимой цели"
                return
            end
            local fired, reason = virtualClick(camera)
            controller.Status = fired and "Обычный выстрел · клик" or reason
            return
        end
        if not enemyAlive(player) then return end
        shot = {Camera = camera, Original = camera.CFrame, Player = player, Part = part,
            Point = point, FireAt = now + SHOT_DELAY, Auto = request.Auto}
        camera.CFrame = CFrame.lookAt(shot.Original.Position, point, shot.Original.UpVector)
        controller.Status = "Цель: " .. player.DisplayName .. " · +10 ms"
    end

    local function updateShot(camera, now)
        if not shot then return end
        if blocked() or camera ~= shot.Camera or not enemyAlive(shot.Player)
            or not shot.Part or not shot.Part.Parent then
            restoreShot(camera, "Выстрел отменён")
            return
        end
        updateFilter(camera)
        local point = visiblePointOnPart(shot.Original.Position, shot.Part, shot.Player.Character)
        if not point then
            restoreShot(camera, "Стена — отмена")
            return
        end
        shot.Point = point
        camera.CFrame = CFrame.lookAt(shot.Original.Position, point, shot.Original.UpVector)
        if now >= shot.FireAt then
            if not enemyAlive(shot.Player) then
                restoreShot(camera, "Цель уже мертва")
                return
            end
            local fired, reason = virtualClick(camera)
            local name = shot.Player.DisplayName
            local wasAuto = shot.Auto
            restoreShot(camera)
            if wasAuto then autoFireDue = now + AUTO_FIRE_GAP end
            controller.Status = fired and ((wasAuto and "Auto: " or "Выстрел: ") .. name .. " · клик") or reason
        end
    end

    local function fireAction(_, state)
        if state == Enum.UserInputState.Begin and settings.SilentAim and not blocked() then
            beginClick(false)
            return Enum.ContextActionResult.Sink
        end
        if settings.SilentAim and not menuOpen then return Enum.ContextActionResult.Sink end
        return Enum.ContextActionResult.Pass
    end
    bindFireAction = function()
        ContextActionService:UnbindAction(ACTION)
        ContextActionService:BindActionAtPriority(ACTION, fireAction, false, 3000,
            Enum.UserInputType.MouseButton1)
    end
    bindFireAction()

    bind(UserInputService.WindowFocusReleased, function()
        focused = false
        pendingAcquire = nil
        restoreShot(workspace.CurrentCamera, "Пауза")
        setTarget(nil, nil)
    end)
    bind(UserInputService.WindowFocused, function() focused = true end)
    bind(UserInputService.TextBoxFocused, function()
        pendingAcquire = nil
        restoreShot(workspace.CurrentCamera, "Пауза")
        setTarget(nil, nil)
    end)

    local function release(entry)
        local part = entry.Part
        part.Transparency = 1
        part.Parent = nil
        pool[#pool + 1] = part
    end
    local function obtain()
        local part = table.remove(pool)
        if not part then
            if createdFragments >= 72 then return nil end
            part = new("Part", {Name = "SpectraFragment", Anchored = true, CanCollide = false,
                CanTouch = false, CanQuery = false, CastShadow = false, Material = Enum.Material.Neon,
                TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth}, nil)
            createdFragments = createdFragments + 1
        end
        part.Parent = debrisFolder
        part.Transparency = 0
        return part
    end
    local function restoreBody(character)
        local record = hiddenBodies[character]
        if not record then return end
        for _, saved in ipairs(record.Parts) do
            if saved.Part.Parent and saved.Part.LocalTransparencyModifier == 1 then
                saved.Part.LocalTransparencyModifier = saved.Transparency            end
        end
        hiddenBodies[character] = nil
    end
    local function disintegrate(character)
        if not controller.Running or not settings.DeathShatter then return end
        local camera = workspace.CurrentCamera
        local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
        if not camera or not root or not root:IsA("BasePart")
            or (camera.CFrame.Position - root.Position).Magnitude > 350 then return end
        local now = os.clock()
        while deathTimes[1] and now - deathTimes[1] > 1 do table.remove(deathTimes, 1) end
        if #deathTimes >= 4 then return end
        deathTimes[#deathTimes + 1] = now
        local bodyParts = {}
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
                bodyParts[#bodyParts + 1] = part
            end
        end
        if #bodyParts == 0 then return end
        local count = smoothFPS < 40 and 8 or 18
        local spawned = 0
        for index = 1, count do
            local source = bodyParts[(index - 1) % #bodyParts + 1]
            local shard = obtain()
            if not shard then break end
            local random = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
            local position = source.CFrame:PointToWorldSpace(source.Size * random * 0.8)
            local outward = position - root.Position
            if outward.Magnitude < 0.01 then outward = Vector3.new(1, 0, 0) end
            local size = 0.15 + math.random() * 0.25
            shard.Size = Vector3.new(size, size * (1 + math.random()), size)
            shard.Color = source.Color:Lerp(theme.Accent, 0.35)
            shard.CFrame = CFrame.new(position)
            effects[#effects + 1] = {Part = shard, Position = position,
                Velocity = outward.Unit * (3 + math.random() * 5) + Vector3.new(0, 4 + math.random() * 4, 0),
                Rotation = random * 8, Started = now, Life = 0.65 + math.random() * 0.35}
            spawned = spawned + 1
        end
        if spawned == 0 then return end
        local saved = {}
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                saved[#saved + 1] = {Part = part, Transparency = part.LocalTransparencyModifier}
                part.LocalTransparencyModifier = 1
            end
        end
        hiddenBodies[character] = {Parts = saved}
    end

    local function markDead(player, character)
        if not character or deadCharacters[character] then return end
        deadCharacters[character] = true
        local data = visuals[player]
        if data and data.Character == character then
            data.Eligible = false
            data.VisibleToCamera = false
            hide(data)
            releaseHighlight(data)
        end
        if currentTarget == player then setTarget(nil, nil) end
        if shot and shot.Player == player then restoreShot(workspace.CurrentCamera, "Цель умерла") end
        pendingAcquire = nil
    end

    local function watch(player)
        if watchers[player] then return end
        local record = {Life = {}}
        watchers[player] = record
        local function attach(character)
            disconnect(record.Life)
            if record.Character then restoreBody(record.Character) end
            record.Life = {}
            record.Character = character
            record.Shattered = false
            deadCharacters[character] = nil
            local attachedHumanoid
            local function attachHumanoid(humanoid)
                if attachedHumanoid or not humanoid:IsA("Humanoid") then return end
                attachedHumanoid = humanoid
                local function onDead()
                    local first = not deadCharacters[character]
                    markDead(player, character)
                    if first and not record.Shattered then
                        record.Shattered = true
                        disintegrate(character)
                    end
                end
                record.Life[#record.Life + 1] = humanoid.HealthChanged:Connect(function(health)
                    if health <= 0 then onDead() end
                end)
                record.Life[#record.Life + 1] = humanoid.Died:Connect(onDead)
            end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then attachHumanoid(humanoid) end
            record.Life[#record.Life + 1] = character.ChildAdded:Connect(attachHumanoid)
        end
        record.Spawn = player.CharacterAdded:Connect(attach)
        if player.Character then attach(player.Character) end
    end
    local function unwatch(player)
        local record = watchers[player]
        if not record then return end
        record.Spawn:Disconnect()
        disconnect(record.Life)
        if record.Character then restoreBody(record.Character) end
        watchers[player] = nil
    end
    bind(Players.PlayerAdded, watch)
    bind(Players.PlayerRemoving, unwatch)
    for _, player in ipairs(Players:GetPlayers()) do watch(player) end

    function controller:Pause()
        pendingAcquire = nil
        restoreShot(workspace.CurrentCamera, "Пауза")
        setTarget(nil, nil)
        candidateDue = 0
        autoFireDue = 0
        targetMarker.Visible = false
        reticle.Visible = false
        combatStatus.Visible = false
    end

    function controller:Update(dt, camera, now)
        if not self.Running then return end
        smoothFPS = smoothFPS + (1 / math.max(dt, 0.001) - smoothFPS) * math.min(dt * 3, 1)
        local suspended = blocked()
        reticle.Visible = settings.SilentAim and not suspended
        if suspended then
            pendingAcquire = nil
            restoreShot(camera, "Пауза")
            setTarget(nil, nil)
        else
            acquireForShot(camera, now)
            if shot then
                updateShot(camera, now)
            elseif settings.SilentAim and now >= candidateDue then
                local player, part = findTarget(camera)
                setTarget(player, part)
                candidateDue = now + TARGET_REFRESH
                self.Status = player and ("Цель: " .. player.DisplayName) or "Нет видимой цели"
            elseif not settings.SilentAim then
                pendingAcquire = nil
                setTarget(nil, nil)
                self.Status = "Наведение выключено"
            end
        end

        if settings.SilentAim and settings.AutoFire and not suspended and not shot and not pendingAcquire
            and currentTarget and enemyAlive(currentTarget) and now >= autoFireDue then
            if beginClick(true) then autoFireDue = now + AUTO_FIRE_GAP end
        end

        targetMarker.Visible = false
        if settings.TargetFocus and currentTarget and currentPart and currentPart.Parent and enemyAlive(currentTarget)
            and not suspended and not shot then
            local point, visible = camera:WorldToViewportPoint(currentPart.Position)
            if visible and point.Z > 0 then
                targetMarker.Position = UDim2.fromOffset(point.X, point.Y)
                local pulse = 1 + 0.16 * (0.5 + 0.5 * math.sin(now * 9))
                local size = 30 * pulse
                targetMarker.Size = UDim2.fromOffset(size, size)
                targetDot.BackgroundColor3 = theme.Accent
                local pad, arm = 2, 8
                local a = Vector2.new(pad, pad)
                local b = Vector2.new(size - pad, pad)
                local c = Vector2.new(size - pad, size - pad)
                local d = Vector2.new(pad, size - pad)
                local tc = targetCorners
                drawLine(tc[1], a, a + Vector2.new(arm, 0), theme.Accent, 1.5)
                drawLine(tc[2], a, a + Vector2.new(0, arm), theme.Accent, 1.5)
                drawLine(tc[3], b, b - Vector2.new(arm, 0), theme.Accent, 1.5)
                drawLine(tc[4], b, b + Vector2.new(0, arm), theme.Accent, 1.5)
                drawLine(tc[5], c, c - Vector2.new(arm, 0), theme.Accent, 1.5)
                drawLine(tc[6], c, c - Vector2.new(0, arm), theme.Accent, 1.5)
                drawLine(tc[7], d, d + Vector2.new(arm, 0), theme.Accent, 1.5)
                drawLine(tc[8], d, d - Vector2.new(0, arm), theme.Accent, 1.5)
                targetMarker.Visible = true
            end
        end
        combatStatus.Visible = settings.SilentAim and not menuOpen
        combatStatus.Text = string.format("%s  /  %s  /  FIND 25 ms  /  SHOT 10 ms  /  FOV %.0f°",
            self.Status, settings.AutoFire and "AUTO FIRE" or "CLICK", settings.AimFOV)

        effectClock = effectClock + dt
        if effectClock >= 1 / 30 then
            effectClock = 0
            for index = #effects, 1, -1 do
                local effect = effects[index]
                local elapsed = now - effect.Started
                if elapsed >= effect.Life or not settings.DeathShatter then
                    release(effect)
                    effects[index] = effects[#effects]
                    effects[#effects] = nil
                else
                    local position = effect.Position + effect.Velocity * elapsed
                        + Vector3.new(0, -12, 0) * (elapsed * elapsed)
                    effect.Part.CFrame = CFrame.new(position) * CFrame.Angles(
                        effect.Rotation.X * elapsed, effect.Rotation.Y * elapsed, effect.Rotation.Z * elapsed)
                    effect.Part.Transparency = math.clamp((elapsed / effect.Life - 0.25) / 0.75, 0, 1)
                end
            end
            for character in pairs(hiddenBodies) do
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if not character.Parent or not settings.DeathShatter or (humanoid and humanoid.Health > 0) then
                    restoreBody(character)
                end
            end
        end
    end

    function controller:Stop()
        if stopped then return end
        stopped = true
        self.Running = false
        pendingAcquire = nil
        ContextActionService:UnbindAction(ACTION)
        restoreShot(workspace.CurrentCamera)
        disconnect(serviceConnections)
        for player in pairs(watchers) do unwatch(player) end
        for character in pairs(hiddenBodies) do restoreBody(character) end
        for _, entry in ipairs(effects) do if entry.Part.Parent then entry.Part:Destroy() end end
        for _, part in ipairs(pool) do part:Destroy() end
        debrisFolder:Destroy()
        reticle:Destroy()
        targetMarker:Destroy()
        combatStatus:Destroy()
    end
    return controller
end
local combat = startCombat()


cleanup = function()
    if not alive then return end
    alive = false
    combat:Stop()
    RunService:UnbindFromRenderStep(RENDER_NAME)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, motion in pairs(activeTweens) do motion:Cancel() end
    for _, data in pairs(visuals) do releaseHighlight(data) end
    visuals = {}
    gui:Destroy()
end
connect(shutdown.Event, cleanup)
connect(gui.Destroying, cleanup)
connect(script.Destroying, cleanup)
connect(Players.PlayerAdded, addPlayer)
connect(Players.PlayerRemoving, removePlayer)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
showPage(activePage)
refreshUI()
updateMaster()
local smoothedFPS = 60
local lastCamera
local errorReported = false
local function render(dt)
    local camera = workspace.CurrentCamera
    if not camera or camera.ViewportSize.X < 4 or camera.ViewportSize.Y < 4 then
        combat:Pause()
        for _, data in pairs(visuals) do hide(data) end
        radar.Visible = false
        return
    end
    if camera ~= lastCamera then
        combat:Pause()
        lastCamera = camera
        metadataDue = 0
        for _, data in pairs(visuals) do data.VisibleToCamera = nil data.RayDue = 0 end
    end
    if (camera.ViewportSize - lastViewport).Magnitude > 0.5 then updateLayout(camera.ViewportSize) end
    local now = os.clock()
    combat:Update(dt, camera, now)
    local localCharacter = localPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local ignore = {camera}
    if localCharacter then ignore[#ignore + 1] = localCharacter end
    rayParams.FilterDescendantsInstances = ignore
    rayBudget = 56
    if now >= metadataDue then updateMetadata(camera, origin, now) end
    radar.Visible = settings.Enabled and settings.Radar
    local count = 0
    for _, data in pairs(visuals) do
        if updatePlayer(data, camera, origin, now) then count = count + 1 end
    end
    smoothedFPS = smoothedFPS + ((1 / math.max(dt, 0.001)) - smoothedFPS) * math.min(dt * 3, 1)
    if now >= statsDue then
        footer.Text = string.format("%s  ·  %d игроков     /     %d FPS     /     RightShift — меню", profileName, count, math.floor(smoothedFPS + 0.5))
        radarTitle.Text = string.format("RADAR  /  %d st", settings.RadarRange)
        statsDue = now + 0.4
    end
end
RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 50, function(dt)
    if not alive then return end
    local ok, err = pcall(render, dt)
    if not ok then
        if not errorReported then warn("Spectra render error: " .. tostring(err)) errorReported = true end
        -- Fail closed and disconnect the loop instead of spamming an error every frame.
        cleanup()
    end
end)