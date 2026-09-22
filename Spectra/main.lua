--[[
SPECTRA v10 — portable SDK / motion aim / world shader stack.
Insert / RightShift: menu. End: unload. Regular aim: hold RMB.
Client-only. Weapon activation depends on the weapon's input implementation.
Silent keeps the camera aimed until input release, then restores the view.
Death is latched per Character; only a new Character resets the latch.
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

local startup = type(_G.SpectraOptions) == "table" and _G.SpectraOptions or {}
local MODULE_ROOT = type(startup.ModuleRoot) == "string" and startup.ModuleRoot
    or "https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/main/Spectra/"
local moduleCache = {}
local moduleResolver = type(startup.ModuleResolver) == "function" and startup.ModuleResolver or nil
local function importModule(path)
    if moduleCache[path] then return moduleCache[path] end

    if moduleResolver then
        local ok, exported = pcall(moduleResolver, path)
        if not ok then error("Spectra ModuleResolver failed [" .. path .. "]: " .. tostring(exported)) end
        if exported == nil then error("Spectra ModuleResolver returned nil [" .. path .. "]") end
        moduleCache[path] = exported
        return exported
    end

    if type(loadstring) ~= "function" then
        error("Spectra: loadstring unavailable. Provide SpectraOptions.ModuleResolver for local ModuleScripts.")
    end
    local ok, source = pcall(function() return game:HttpGet(MODULE_ROOT .. path, true) end)
    if not ok or type(source) ~= "string" or #source < 20 then
        error("Spectra module download failed [" .. path .. "]: " .. tostring(source))
    end
    local chunk, compileError = loadstring(source, "@Spectra/" .. path)
    if not chunk then error("Spectra module compile failed [" .. path .. "]: " .. tostring(compileError)) end
    local exported = chunk()
    moduleCache[path] = exported
    return exported
end
local BRAND_NAME = type(startup.Name) == "string" and string.sub(startup.Name, 1, 24) or "spectra"
local creatorInputAdapter
local skeetStyle = importModule("ui/skeet.lua")
local theme = skeetStyle.Theme
local palette = skeetStyle.Palette
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
    AimEnabled = false, AimSmooth = 16, TargetPriority = "Прицел",
    TargetStickiness = 20, AcquireMS = 25, ShotMS = 10, HoldMS = 25,
    FireInterval = 120, FireMethod = "VirtualUser", AimWallCheck = true,
    AntiAim = false, AntiMode = "Jitter", AntiYaw = 180,
    AntiJitter = 55, AntiSpeed = 180, AntiPeriod = 120,
    AimRayOrigin = "Camera", VisibilitySampling = "Dense",
    AliveHealthCheck = true, AliveStateCheck = true, AliveAncestryCheck = true,
    AliveRootCheck = true, AliveDeadTags = true,
    ThirdPerson = false, ThirdPersonDistance = 8, ThirdPersonShoulder = 0,
    BulletTracers = true, HitLogs = true, HitMarker = true, HitFlash = true,
    HitLogDuration = 2.5, TracerDuration = 0.35,
    AutoFireSource = "Auto",
    MotionAimSpeed = 240, MotionAimPart = "Visible", MotionRandomization = 18,
    MotionRandomRefreshMS = 140, MotionFireTolerance = 1.25, MotionActivation = "Hold RMB",
    ChamsEnabled = false, ChamsThroughWalls = true, ChamsFill = 36, ChamsOutline = 88,
    ChamsPulse = false, ChamsPulseSpeed = 1.2, ChamsColorMode = "Accent", ChamsRainbowSpeed = 0.12,
    WorldLightingMode = "Game", AuroraSky = false, AuroraIntensity = 55, AuroraSpeed = 0.5,
    ColorWorld = false, WorldTint = "Aurora", WorldTintStrength = 35,
    WorldSaturation = 0, WorldContrast = 0, WorldBrightness = 0,
    WorldFog = false, FogDensity = 0.3, FogOffset = 0, FogHaze = 1.5, FogGlare = 0, FogColor = "Blue",
    WorldBloom = false, BloomIntensity = 1, BloomSize = 24, BloomThreshold = 1,
    WorldBlur = false, BlurSize = 4,
    WorldSunRays = false, SunRaysIntensity = 0.08, SunRaysSpread = 0.85,
    WorldDOF = false, DOFFarIntensity = 0.15, DOFNearIntensity = 0,
    DOFFocusDistance = 60, DOFInFocusRadius = 45,
    HeadMarker = true, TargetFocus = true, DeathShatter = true,
}
local settingRanges = {
    MaxDistance={100,3000}, FillOpacity={0,100}, OutlineOpacity={0,100}, Thickness={1,3},
    PulseSpeed={0.4,2.4}, ColorIndex={1,4}, RadarRange={50,1000}, LookLength={3,24},
    AimFOV={5,360}, AimDistance={50,3000}, AimSmooth={2,40}, TargetStickiness={0,50},
    AcquireMS={0,100}, ShotMS={0,100}, HoldMS={10,100}, FireInterval={60,1000},
    AntiYaw={-180,180}, AntiJitter={0,120}, AntiSpeed={30,720}, AntiPeriod={50,500},
    ThirdPersonDistance={2,24}, ThirdPersonShoulder={-4,4},
    HitLogDuration={0.5,8}, TracerDuration={0.08,1.5},
    MotionAimSpeed={30,1080}, MotionRandomization={0,100}, MotionRandomRefreshMS={20,1000},
    MotionFireTolerance={0.1,12},
    ChamsFill={0,100}, ChamsOutline={0,100}, ChamsPulseSpeed={0.2,5}, ChamsRainbowSpeed={0.02,1},
    AuroraIntensity={5,100}, AuroraSpeed={0.05,3},
    WorldTintStrength={0,100}, WorldSaturation={-100,100}, WorldContrast={-100,100}, WorldBrightness={-100,100},
    FogDensity={0,1}, FogOffset={-1,1}, FogHaze={0,10}, FogGlare={0,10},
    BloomIntensity={0,4}, BloomSize={0,56}, BloomThreshold={0,2}, BlurSize={0,24},
    SunRaysIntensity={0,1}, SunRaysSpread={0,1},
    DOFFarIntensity={0,1}, DOFNearIntensity={0,1}, DOFFocusDistance={1,500}, DOFInFocusRadius={0,250},
}
local settingChoices = {
    BoxStyle={"Углы","Рамка"}, HighlightStyle={"Мягкий","Плотный","Контур","Пульс"},
    AimPart={"Голова","Корпус","Видимая"}, TargetPriority={"Прицел","Ближайший","Мало HP"},
    FireMethod={"VirtualUser","MouseButton","Creator"}, AntiMode={"Назад","Jitter","Spin"},
    AimRayOrigin={"Camera","Head","Both"}, VisibilitySampling={"Fast","Balanced","Dense"},
    AutoFireSource={"Auto","Silent","Motion"}, MotionAimPart={"Head","Torso","Visible","Random"},
    MotionActivation={"Hold RMB","Always"},
    ChamsColorMode={"Accent","Health","Team","Rainbow"},
    WorldLightingMode={"Game","Fullbright","Night","Sunset","Aurora"},
    WorldTint={"Aurora","Blue","Purple","Green","Red","Gold","Mono"},
    FogColor={"Aurora","Blue","Purple","Green","Red","Gold","Mono"},
}
local function normalizeSetting(key,value)
    if defaults[key] == nil or type(value) ~= type(defaults[key]) then return nil,"Unknown setting or wrong type" end
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return nil,"Number must be finite" end
        local range = settingRanges[key]
        if range then value = math.clamp(value,range[1],range[2]) end
        if key == "ColorIndex" then value = math.floor(value+0.5) end
    elseif type(value) == "string" then
        local found = false
        for _,option in ipairs(settingChoices[key] or {}) do if value == option then found=true break end end
        if not found then return nil,"Unknown choice" end
    end
    return value
end
local settings = {}
for key,value in pairs(defaults) do settings[key]=value end
if type(startup.Settings) == "table" then
    for key,value in pairs(startup.Settings) do
        local normalized = normalizeSetting(key,value)
        if normalized ~= nil then settings[key]=normalized end
    end
end
if type(startup.InputAdapter) == "table" and type(startup.InputAdapter.Press) == "function"
    and type(startup.InputAdapter.Release) == "function" then
    creatorInputAdapter = {Press=startup.InputAdapter.Press,Release=startup.InputAdapter.Release}
end
local alive, menuOpen = true, true
local connections, visuals, refreshers = {}, {}, {}
local activeTweens = setmetatable({}, {__mode = "k"})
local metadataDue, statsDue = 0, 0
local profileName = "Tactical"
local cleanup
local deadCharacters = setmetatable({}, {__mode = "k"})
local GameAdapter = importModule("core/game_adapter.lua")({
    Players = Players,
    LocalPlayer = localPlayer,
    Startup = startup,
})
local Alive = importModule("core/alive.lua")({
    Players = Players,
    Settings = settings,
    DeadCharacters = deadCharacters,
    Adapter = GameAdapter,
})
local Visibility = importModule("core/visibility.lua")({
    Settings = settings,
    Workspace = workspace,
})

local function liveCharacter(player, expected)
    return Alive:IsAlive(player, expected)
end

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
        Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
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
        Text = text, Font = font or Enum.Font.Arial, TextSize = size or 12,
        TextColor3 = color or theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end
local function button(parent, text, x, y, width, height)
    return new("TextButton", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = theme.Sidebar, BorderSizePixel = 0, AutoButtonColor = false,
        Text = text, TextSize = 11, Font = Enum.Font.Arial, TextColor3 = theme.Text,
    }, parent)
end
local function refreshUI()
    for _, refresh in ipairs(refreshers) do refresh() end
end
local function setSetting(key, value)
    local normalized, reason = normalizeSetting(key,value)
    if normalized == nil then return false,reason end
    if settings[key] == normalized then return true end
    settings[key] = normalized
    profileName = "Custom"
    metadataDue = 0
    refreshUI()
    return true
end

local gui = new("ScreenGui", {
    Name = GUI_NAME, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None,
    ClipToDeviceSafeArea = false, ResetOnSpawn = false, DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local shutdown = new("BindableEvent", {Name = "Shutdown"}, gui)
local overlay = new("Frame", {Name = "Overlay", BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 1}, gui)

local telemetry = importModule("visuals/telemetry.lua")({
    Settings = settings,
    Overlay = overlay,
    Theme = theme,
    TweenService = TweenService,
})
local thirdPerson = importModule("camera/thirdperson.lua")({
    LocalPlayer = localPlayer,
    Settings = settings,
})
local chams = importModule("visuals/chams.lua")({
    Players = Players,
    LocalPlayer = localPlayer,
    Settings = settings,
    Alive = Alive,
    Adapter = GameAdapter,
    Theme = theme,
})
local environment = importModule("world/environment.lua")({
    Settings = settings,
    Workspace = workspace,
})

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

-- Classic gamesense-inspired geometry; all controls/icons are drawn locally.
local MENU_W, MENU_H = 700, 590
local menu = new("CanvasGroup", {Name = "Menu", Size = UDim2.fromOffset(MENU_W, MENU_H),
    Position = UDim2.fromOffset(28, 100), BackgroundColor3 = Color3.fromRGB(10, 10, 10),
    BorderSizePixel = 1, BorderColor3 = Color3.new(0, 0, 0), GroupTransparency = 0, ZIndex = 20}, gui)
local menuScale = new("UIScale", {Scale = 1}, menu)
local function flatFrame(parent, x, y, w, h, color)
    return new("Frame", {Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h),
        BackgroundColor3=color, BorderSizePixel=0}, parent)
end
local outer = flatFrame(menu, 1, 1, MENU_W-2, MENU_H-2, Color3.fromRGB(54,54,54))
local inner = flatFrame(outer, 1, 1, MENU_W-4, MENU_H-4, Color3.fromRGB(20,20,20))
local surface = flatFrame(inner, 4, 4, MENU_W-12, MENU_H-12, theme.Background)
stroke(surface, Color3.fromRGB(55,55,55))
local spectrum = flatFrame(menu, 7, 7, MENU_W-14, 2, Color3.new(1,1,1))
new("UIGradient", {Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(64,185,225)),
    ColorSequenceKeypoint.new(0.28,Color3.fromRGB(139,110,207)),
    ColorSequenceKeypoint.new(0.52,Color3.fromRGB(221,89,147)),
    ColorSequenceKeypoint.new(0.76,Color3.fromRGB(225,163,86)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(176,204,85)),
})}, spectrum)
-- A sparse woven texture without downloading images or creating thousands of cells.
for y=39,MENU_H-29,6 do
    local line=flatFrame(menu,82,y,MENU_W-91,1,Color3.fromRGB(30,30,30))
    line.BackgroundTransparency=0.58
end
local header = new("Frame", {Name="DragHandle", BackgroundTransparency=1, Active=true,
    Position=UDim2.fromOffset(9,10), Size=UDim2.fromOffset(MENU_W-44,25)}, menu)
local brand = label(header, BRAND_NAME, 9, 1, 210, 22, 13, theme.Text, Enum.Font.ArialBold)
label(header, "[ portable / v10 ]", 214, 3, 130, 18, 10, theme.Muted)
local master = button(header, "", MENU_W-164, 3, 104, 18)
master.BackgroundTransparency=1
master.Modal=true
local function updateMaster()
    master.Text=settings.Enabled and "ESP  [ ON ]" or "ESP  [ OFF ]"
    master.TextColor3=settings.Enabled and theme.Accent or theme.Muted
end
refreshers[#refreshers+1]=updateMaster
connect(master.Activated,function() setSetting("Enabled",not settings.Enabled) end)
local closeButton=button(menu,"×",MENU_W-33,12,20,19)
closeButton.BackgroundTransparency=1
closeButton.TextSize=16
local sidebar=flatFrame(menu,8,36,66,MENU_H-61,Color3.fromRGB(12,12,12))
flatFrame(menu,74,36,1,MENU_H-61,theme.Line)
local footer=label(menu,"",15,MENU_H-23,MENU_W-30,16,10,theme.Muted)
local footerHint
local function hintOn(item,text)
    if not text then return end
    connect(item.MouseEnter,function() footerHint=text end)
    connect(item.MouseLeave,function() if footerHint==text then footerHint=nil end end)
end
local pages,tabs,tabIcons={}, {}, {}
local activePage="RAGE"
local contentW=278
local columns,currentGroups={},{}
local dropdownClose
local function closeDropdown()
    if dropdownClose then local close=dropdownClose; dropdownClose=nil; close() end
end
local function icon(parent,kind)
    local segments={}
    local function segment(x,y,w,h,rotation)
        local part=flatFrame(parent,x,y,w,h,theme.Muted)
        part.Rotation=rotation or 0
        segments[#segments+1]=part
    end
    if kind==1 then -- crosshair
        segment(30,13,2,12); segment(30,35,2,12); segment(13,29,12,2); segment(37,29,12,2)
        local ring=flatFrame(parent,22,21,18,18,theme.Muted)
        ring.BackgroundTransparency=1
        corner(ring,9)
        segments[#segments+1]=stroke(ring,theme.Muted)
    elseif kind==2 then -- cursor
        segment(23,15,2,29); segment(23,15,24,2,44); segment(24,35,16,2,-25); segment(35,35,2,14,-28)
    elseif kind==3 then -- opposing arrows
        segment(16,22,29,2); segment(15,19,11,2,-40); segment(15,25,11,2,40)
        segment(17,37,29,2); segment(37,34,11,2,40); segment(37,40,11,2,-40)
    elseif kind==4 then -- body
        local head=flatFrame(parent,26,13,10,10,theme.Muted); corner(head,5); segments[#segments+1]=head
        segment(25,26,12,16); segment(17,27,5,17,15); segment(40,27,5,17,-15)
        segment(25,43,5,12,6); segment(32,43,5,12,-6)
    elseif kind==5 then -- sun
        for i=0,7 do
            local a=i*math.pi/4
            segment(30+math.cos(a)*18,29+math.sin(a)*18,8,2,math.deg(a))
        end
        local sun=flatFrame(parent,25,24,12,12,theme.Muted); corner(sun,6); segments[#segments+1]=sun
    elseif kind==6 then -- sliders
        for i=0,2 do
            segment(16,20+i*12,31,2); segment(23+(i%2)*12,16+i*12,5,10)
        end
    else -- file
        segment(20,14,2,36); segment(20,14,24,2); segment(43,14,2,36); segment(20,49,25,2)
        segment(26,24,12,2); segment(26,31,12,2); segment(26,38,9,2)
    end
    return segments
end
local function showPage(name)
    closeDropdown()
    activePage=name
    footerHint=nil
    for key,page in pairs(pages) do
        local selected=key==name
        page.Visible=selected
        tabs[key].BackgroundColor3=selected and theme.Background or Color3.fromRGB(12,12,12)
        tabs[key].TextColor3=selected and theme.Text or theme.Muted
        for _,part in ipairs(tabIcons[key]) do
            if part:IsA("UIStroke") then part.Color=selected and theme.Text or theme.Muted
            else part.BackgroundColor3=selected and theme.Text or theme.Muted end
        end
    end
end
for index,name in ipairs(skeetStyle.Tabs) do
    local key=name
    local tab=button(sidebar,"",0,(index-1)*71,66,71)
    tab.Name=name
    tabs[name]=tab
    tabIcons[name]=icon(tab,index)
    local caption=label(tab,name,0,55,66,12,8,theme.Muted)
    caption.TextXAlignment=Enum.TextXAlignment.Center
    flatFrame(tab,0,70,66,1,theme.Line)
    hintOn(tab,name)
    local page=new("Frame",{Name=name,Position=UDim2.fromOffset(91,42),
        Size=UDim2.fromOffset(588,MENU_H-75),BackgroundTransparency=1,Visible=false},menu)
    pages[name]=page
    columns[name]={}
    for col=1,2 do
        local column=new("ScrollingFrame",{Name="Column"..col,Position=UDim2.fromOffset((col-1)*297,0),
            Size=UDim2.fromOffset(288,MENU_H-77),BackgroundTransparency=1,BorderSizePixel=0,
            ScrollBarThickness=2,ScrollBarImageColor3=theme.Off,CanvasSize=UDim2.fromOffset(0,0),
            AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},page)
        new("UIListLayout",{Padding=UDim.new(0,16),SortOrder=Enum.SortOrder.LayoutOrder},column)
        new("UIPadding",{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,2),
            PaddingBottom=UDim.new(0,8),PaddingRight=UDim.new(0,6)},column)
        columns[name][col]=column
        connect(column:GetPropertyChangedSignal("CanvasPosition"),closeDropdown)
    end
    connect(tab.Activated,function() showPage(key) end)
end
local order=0
local function section(pageName,titleText,column)
    order=order+1
    local group=new("Frame",{Name=titleText,BackgroundColor3=Color3.fromRGB(23,23,23),
        BorderSizePixel=1,BorderColor3=Color3.new(0,0,0),Size=UDim2.fromOffset(contentW,28),
        AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=order},columns[pageName][column or 1])
    stroke(group,Color3.fromRGB(49,49,49))
    local title=label(group,titleText,10,-8,contentW-20,16,11,theme.Text,Enum.Font.ArialBold)
    title.AutomaticSize=Enum.AutomaticSize.X
    title.Size=UDim2.fromOffset(0,16)
    title.BackgroundTransparency=0
    title.BackgroundColor3=Color3.fromRGB(23,23,23)
    title.ZIndex=3
    local body=new("Frame",{Name="Body",Position=UDim2.fromOffset(12,16),
        Size=UDim2.fromOffset(contentW-24,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},group)
    new("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},body)
    new("UIPadding",{PaddingBottom=UDim.new(0,12)},body)
    currentGroups[pageName]=body
    return group
end
local function row(pageName,height)
    order=order+1
    return new("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,height),LayoutOrder=order},currentGroups[pageName])
end
local function shade(parent,top,bottom)
    new("UIGradient",{Rotation=90,Color=ColorSequence.new(top,bottom)},parent)
end
local function toggle(pageName,titleText,key,hint)
    local item=row(pageName,21)
    local hit=button(item,"",0,0,contentW-24,21)
    hit.BackgroundTransparency=1
    local box=flatFrame(hit,1,5,10,10,Color3.fromRGB(58,58,58))
    box.BorderSizePixel=1
    box.BorderColor3=Color3.new(0,0,0)
    shade(box,Color3.new(1,1,1),Color3.fromRGB(145,145,145))
    local textLabel=label(hit,titleText,20,1,contentW-48,18,11)
    refreshers[#refreshers+1]=function()
        box.BackgroundColor3=settings[key] and theme.Accent or Color3.fromRGB(62,62,62)
        textLabel.TextColor3=settings[key] and theme.Text or Color3.fromRGB(184,184,184)
    end
    hintOn(hit,hint)
    connect(hit.Activated,function() setSetting(key,not settings[key]) end)
end
local sliderDrag
local function slider(pageName,titleText,key,minimum,maximum,step,unit)
    local item=row(pageName,37)
    label(item,titleText,20,0,contentW-44,16,11)
    local hit=button(item,"",21,16,contentW-58,19)
    hit.BackgroundTransparency=1
    local track=flatFrame(hit,0,4,contentW-58,7,Color3.fromRGB(45,45,45))
    track.BorderSizePixel=1; track.BorderColor3=Color3.new(0,0,0)
    local fill=flatFrame(track,0,0,0,7,theme.Accent)
    shade(fill,Color3.new(1,1,1),Color3.fromRGB(132,132,132))
    local valueLabel=label(hit,"",0,1,contentW-58,14,10,theme.Text,Enum.Font.ArialBold)
    valueLabel.TextXAlignment=Enum.TextXAlignment.Center
    valueLabel.TextStrokeTransparency=0
    valueLabel.TextStrokeColor3=Color3.new(0,0,0)
    valueLabel.ZIndex=4
    local function fromX(x)
        local p=math.clamp((x-hit.AbsolutePosition.X)/math.max(hit.AbsoluteSize.X,1),0,1)
        setSetting(key,math.clamp(minimum+math.floor(p*(maximum-minimum)/step+0.5)*step,minimum,maximum))
    end
    refreshers[#refreshers+1]=function()
        fill.Size=UDim2.fromScale((settings[key]-minimum)/(maximum-minimum),1)
        valueLabel.Text=string.format(step<1 and "%.1f%s" or "%.0f%s",settings[key],unit or "")
    end
    connect(hit.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            closeDropdown()
            sliderDrag={Input=input,Update=fromX}
            fromX(input.Position.X)
        end
    end)
end
local displayOptions={
    ["Голова"]="Head",["Корпус"]="Body",["Видимая"]="Visible point",
    ["Прицел"]="Crosshair",["Ближайший"]="Distance",["Мало HP"]="Lowest health",
    ["Назад"]="Backward",["Углы"]="Corners",["Рамка"]="Full box",
    ["Мягкий"]="Soft",["Плотный"]="Solid",["Контур"]="Outline",["Пульс"]="Pulse",
}
local function choices(pageName,titleText,key,options)
    local item=row(pageName,46)
    label(item,titleText,20,0,contentW-44,17,11)
    local hit=button(item,"",21,20,contentW-58,20)
    hit.BorderSizePixel=1; hit.BorderColor3=Color3.new(0,0,0)
    shade(hit,Color3.fromRGB(55,55,55),Color3.fromRGB(30,30,30))
    hit.BackgroundColor3=Color3.new(1,1,1)
    local valueLabel=label(hit,"",7,1,contentW-85,18,11)
    label(hit,"▾",contentW-75,1,12,17,11,theme.Muted)
    refreshers[#refreshers+1]=function() valueLabel.Text=displayOptions[settings[key]] or settings[key] end
    connect(hit.Activated,function()
        local wasOpen=hit:GetAttribute("DropdownOpen")
        closeDropdown()
        if wasOpen then return end
        sliderDrag=nil
        hit:SetAttribute("DropdownOpen",true)
        local shield=button(gui,"",0,0,0,0)
        shield.Name="DropdownShield"; shield.Size=UDim2.fromScale(1,1)
        shield.BackgroundTransparency=1; shield.ZIndex=80
        local scale=menuScale.Scale
        local h=#options*22*scale
        local x,y=hit.AbsolutePosition.X,hit.AbsolutePosition.Y+hit.AbsoluteSize.Y+2
        local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        if viewport and y+h>viewport.Y-8 then y=hit.AbsolutePosition.Y-h-2 end
        local popup=new("Frame",{Name="Dropdown",Position=UDim2.fromOffset(x,math.max(8,y)),
            Size=UDim2.fromOffset(hit.AbsoluteSize.X,h),BackgroundColor3=Color3.fromRGB(20,20,20),
            BorderSizePixel=1,BorderColor3=Color3.new(0,0,0),ZIndex=81},shield)
        local popupConnections={}
        dropdownClose=function()
            hit:SetAttribute("DropdownOpen",false)
            for _,connection in ipairs(popupConnections) do connection:Disconnect() end
            shield:Destroy()
        end
        popupConnections[#popupConnections+1]=shield.Activated:Connect(closeDropdown)
        for i,option in ipairs(options) do
            local value=option
            local choice=button(popup,displayOptions[option] or option,0,(i-1)*22*scale,hit.AbsoluteSize.X,22*scale)
            choice.TextSize=math.max(8,11*scale); choice.ZIndex=82
            choice.TextColor3=settings[key]==option and theme.Accent or theme.Text
            choice.BackgroundColor3=Color3.fromRGB(24,24,24)
            popupConnections[#popupConnections+1]=choice.Activated:Connect(function() setSetting(key,value); closeDropdown() end)
            popupConnections[#popupConnections+1]=choice.MouseEnter:Connect(function() choice.BackgroundColor3=Color3.fromRGB(43,43,43) end)
            popupConnections[#popupConnections+1]=choice.MouseLeave:Connect(function() choice.BackgroundColor3=Color3.fromRGB(24,24,24) end)
        end
    end)
end

section("RAGE","Aimbot",1)
toggle("RAGE","Enabled","SilentAim","Silent: поворот камеры → нажатие → отпускание → возврат")
toggle("RAGE","Automatic fire","AutoFire","Работает с Silent или Motion aim")
choices("RAGE","Auto fire aim","AutoFireSource",{"Auto","Silent","Motion"})
toggle("RAGE","Check team","AimTeamCheck")
toggle("RAGE","Visibility check","AimWallCheck","Multipoint raycast по реально видимым частям")
choices("RAGE","Ray origin","AimRayOrigin",{"Camera","Head","Both"})
choices("RAGE","Multipoint sampling","VisibilitySampling",{"Fast","Balanced","Dense"})
choices("RAGE","Target selection","TargetPriority",{"Прицел","Ближайший","Мало HP"})
choices("RAGE","Target hitbox","AimPart",{"Голова","Корпус","Видимая"})
slider("RAGE","Maximum FOV","AimFOV",5,360,5,"°")
slider("RAGE","Maximum distance","AimDistance",50,3000,50," st")
slider("RAGE","Target retention","TargetStickiness",0,50,5,"%")
section("RAGE","Input",2)
choices("RAGE","Fire method","FireMethod",{"VirtualUser","MouseButton","Creator"})
slider("RAGE","Acquire delay","AcquireMS",0,100,5," ms")
slider("RAGE","Camera settle time","ShotMS",0,100,5," ms")
slider("RAGE","Press duration","HoldMS",10,100,5," ms")
slider("RAGE","Automatic fire interval","FireInterval",60,1000,10," ms")
section("RAGE","Target visuals",2)
toggle("RAGE","Target focus","TargetFocus")
toggle("RAGE","Head marker","HeadMarker")
toggle("RAGE","Death particles","DeathShatter")

section("LEGIT","Motion aim",1)
toggle("LEGIT","Enabled","AimEnabled","Прицел физически ведётся к цели с ограниченной угловой скоростью")
choices("LEGIT","Activation","MotionActivation",{"Hold RMB","Always"})
slider("LEGIT","Aim speed","MotionAimSpeed",30,1080,15,"°/s")
choices("LEGIT","Body selection","MotionAimPart",{"Head","Torso","Visible","Random"})
slider("LEGIT","Randomization","MotionRandomization",0,100,5,"%")
slider("LEGIT","Random refresh","MotionRandomRefreshMS",20,1000,20," ms")
slider("LEGIT","Auto-fire tolerance","MotionFireTolerance",0.1,12,0.1,"°")
slider("LEGIT","Maximum FOV","AimFOV",5,360,5,"°")
slider("LEGIT","Maximum distance","AimDistance",50,3000,50," st")
section("LEGIT","Target selection",2)
choices("LEGIT","Priority","TargetPriority",{"Прицел","Ближайший","Мало HP"})
toggle("LEGIT","Check team","AimTeamCheck")
toggle("LEGIT","Visibility check","AimWallCheck")
slider("LEGIT","Target retention","TargetStickiness",0,50,5,"%")

section("ANTI-AIM","Anti-aimbot angles",1)
toggle("ANTI-AIM","Enabled","AntiAim","Поворачивает персонажа; репликация зависит от плейса")
choices("ANTI-AIM","Yaw mode","AntiMode",{"Назад","Jitter","Spin"})
slider("ANTI-AIM","Yaw offset","AntiYaw",-180,180,5,"°")
section("ANTI-AIM","Modifiers",2)
slider("ANTI-AIM","Jitter range","AntiJitter",0,120,5,"°")
slider("ANTI-AIM","Jitter interval","AntiPeriod",50,500,10," ms")
slider("ANTI-AIM","Spin speed","AntiSpeed",30,720,30,"°/s")

section("VISUALS","Player ESP",1)
toggle("VISUALS","Enabled","Enabled")
toggle("VISUALS","Player name","Names")
toggle("VISUALS","Bounding box","Boxes")
choices("VISUALS","Box style","BoxStyle",{"Углы","Рамка"})
toggle("VISUALS","Health bar","Health")
toggle("VISUALS","Skeleton","Skeleton")
toggle("VISUALS","Weapon text","Tool")
toggle("VISUALS","Distance","Distance")
toggle("VISUALS","Tracers","Tracers")
section("VISUALS","Filters",2)
toggle("VISUALS","Ignore teammates","TeamCheck")
toggle("VISUALS","Visible only","OnlyVisible")
slider("VISUALS","Maximum distance","MaxDistance",100,3000,50," st")
section("VISUALS","Extra",2)
toggle("VISUALS","Offscreen arrows","Arrows")
toggle("VISUALS","Look direction","LookDirection")
slider("VISUALS","Look length","LookLength",3,24,1," st")
toggle("VISUALS","Velocity vector","Velocity")

section("EFFECTS","Player glow",1)
toggle("EFFECTS","Enabled","Highlights")
choices("EFFECTS","Glow style","HighlightStyle",{"Мягкий","Плотный","Контур","Пульс"})
slider("EFFECTS","Fill opacity","FillOpacity",0,100,1,"%")
slider("EFFECTS","Outline opacity","OutlineOpacity",0,100,1,"%")
toggle("EFFECTS","Line glow","Glow")
slider("EFFECTS","Line thickness","Thickness",1,3,0.5," px")
slider("EFFECTS","Pulse speed","PulseSpeed",0.4,2.4,0.1," Hz")
section("EFFECTS","Chams",1)
toggle("EFFECTS","Enabled","ChamsEnabled")
toggle("EFFECTS","Through walls","ChamsThroughWalls")
choices("EFFECTS","Color mode","ChamsColorMode",{"Accent","Health","Team","Rainbow"})
slider("EFFECTS","Fill","ChamsFill",0,100,1,"%")
slider("EFFECTS","Outline","ChamsOutline",0,100,1,"%")
toggle("EFFECTS","Pulse","ChamsPulse")
slider("EFFECTS","Pulse speed","ChamsPulseSpeed",0.2,5,0.1," Hz")
slider("EFFECTS","Rainbow speed","ChamsRainbowSpeed",0.02,1,0.02,"")
section("EFFECTS","Colors",2)
toggle("EFFECTS","Visibility colors","VisibilityColors")
toggle("EFFECTS","Team colors","TeamColors")
do
    local item=row("EFFECTS",42)
    label(item,"ESP color",20,0,150,16,11)
    for i,color in ipairs(palette) do
        local index=i
        local hit=button(item,"",20+(i-1)*42,22,32,12)
        hit.BackgroundColor3=color
        local border=stroke(hit,theme.Text)
        refreshers[#refreshers+1]=function() border.Transparency=settings.ColorIndex==index and 0 or 0.8 end
        connect(hit.Activated,function() setSetting("ColorIndex",index) end)
    end
end
section("EFFECTS","Indicators",2)
toggle("EFFECTS","Head marker","HeadMarker")
toggle("EFFECTS","Bullet tracers","BulletTracers")
toggle("EFFECTS","Hit marker","HitMarker")
toggle("EFFECTS","Hit logs","HitLogs")
toggle("EFFECTS","Hit flash shader","HitFlash")
slider("EFFECTS","Tracer lifetime","TracerDuration",0.08,1.5,0.01," s")
slider("EFFECTS","Hitlog lifetime","HitLogDuration",0.5,8,0.25," s")
toggle("EFFECTS","Target focus","TargetFocus")
toggle("EFFECTS","Death particles","DeathShatter")

section("MISC","Camera",1)
toggle("MISC","Third person","ThirdPerson")
slider("MISC","Third person distance","ThirdPersonDistance",2,24,1," st")
slider("MISC","Shoulder offset","ThirdPersonShoulder",-4,4,0.5," st")

section("MISC","World",1)
choices("MISC","Lighting mode","WorldLightingMode",{"Game","Fullbright","Night","Sunset","Aurora"})
toggle("MISC","Aurora ribbons","AuroraSky","Процедурное полярное сияние без внешних skybox assets")
slider("MISC","Aurora intensity","AuroraIntensity",5,100,5,"%")
slider("MISC","Aurora speed","AuroraSpeed",0.05,3,0.05,"")

section("MISC","Radar",2)
toggle("MISC","Enabled","Radar")
slider("MISC","Radar range","RadarRange",50,1000,25," st")

section("MISC","Color world / fog",2)
toggle("MISC","Color world","ColorWorld")
choices("MISC","World tint","WorldTint",{"Aurora","Blue","Purple","Green","Red","Gold","Mono"})
slider("MISC","Tint strength","WorldTintStrength",0,100,5,"%")
slider("MISC","Saturation","WorldSaturation",-100,100,5,"%")
slider("MISC","Contrast","WorldContrast",-100,100,5,"%")
slider("MISC","Brightness","WorldBrightness",-100,100,5,"%")
toggle("MISC","Atmosphere fog","WorldFog")
choices("MISC","Fog tint","FogColor",{"Aurora","Blue","Purple","Green","Red","Gold","Mono"})
slider("MISC","Fog density","FogDensity",0,1,0.05,"")
slider("MISC","Fog offset","FogOffset",-1,1,0.05,"")
slider("MISC","Fog haze","FogHaze",0,10,0.25,"")
slider("MISC","Fog glare","FogGlare",0,10,0.25,"")

section("MISC","Post processing",2)
toggle("MISC","Bloom","WorldBloom")
slider("MISC","Bloom intensity","BloomIntensity",0,4,0.1,"")
slider("MISC","Bloom size","BloomSize",0,56,1,"")
slider("MISC","Bloom threshold","BloomThreshold",0,2,0.05,"")
toggle("MISC","Blur","WorldBlur")
slider("MISC","Blur size","BlurSize",0,24,1,"")
toggle("MISC","Sun rays","WorldSunRays")
slider("MISC","Sun rays intensity","SunRaysIntensity",0,1,0.02,"")
slider("MISC","Sun rays spread","SunRaysSpread",0,1,0.02,"")
toggle("MISC","Depth of field","WorldDOF")
slider("MISC","DOF far","DOFFarIntensity",0,1,0.05,"")
slider("MISC","DOF near","DOFNearIntensity",0,1,0.05,"")
slider("MISC","Focus distance","DOFFocusDistance",1,500,5," st")
slider("MISC","In-focus radius","DOFInFocusRadius",0,250,5," st")

section("MISC","Interface",2)
do
    local item=row("MISC",62)
    label(item,"Menu  [ INS / RightShift ]",20,0,contentW-44,18,11)
    label(item,"Unload  [ END ]",20,21,contentW-44,18,11)
    label(item,"Aim  [ hold MOUSE2 ]",20,42,contentW-44,18,11)
end
local combatKeys={SilentAim=true,AutoFire=true,AimTeamCheck=true,AimFOV=true,AimDistance=true,
    AimPart=true,HeadMarker=true,TargetFocus=true,DeathShatter=true,AimEnabled=true,AimSmooth=true,
    TargetPriority=true,TargetStickiness=true,AcquireMS=true,ShotMS=true,HoldMS=true,FireInterval=true,
    FireMethod=true,AimWallCheck=true,AimRayOrigin=true,VisibilitySampling=true,
    AntiAim=true,AntiMode=true,AntiYaw=true,AntiJitter=true,AntiSpeed=true,AntiPeriod=true,
    AliveHealthCheck=true,AliveStateCheck=true,AliveAncestryCheck=true,AliveRootCheck=true,AliveDeadTags=true,
    ThirdPerson=true,ThirdPersonDistance=true,ThirdPersonShoulder=true,
    BulletTracers=true,HitLogs=true,HitMarker=true,HitFlash=true,HitLogDuration=true,TracerDuration=true,
    AutoFireSource=true,MotionAimSpeed=true,MotionAimPart=true,MotionRandomization=true,
    MotionRandomRefreshMS=true,MotionFireTolerance=true,MotionActivation=true,
    ChamsEnabled=true,ChamsThroughWalls=true,ChamsFill=true,ChamsOutline=true,ChamsPulse=true,
    ChamsPulseSpeed=true,ChamsColorMode=true,ChamsRainbowSpeed=true,
    WorldLightingMode=true,AuroraSky=true,AuroraIntensity=true,AuroraSpeed=true,
    ColorWorld=true,WorldTint=true,WorldTintStrength=true,WorldSaturation=true,WorldContrast=true,WorldBrightness=true,
    WorldFog=true,FogDensity=true,FogOffset=true,FogHaze=true,FogGlare=true,FogColor=true,
    WorldBloom=true,BloomIntensity=true,BloomSize=true,BloomThreshold=true,WorldBlur=true,BlurSize=true,
    WorldSunRays=true,SunRaysIntensity=true,SunRaysSpread=true,WorldDOF=true,DOFFarIntensity=true,
    DOFNearIntensity=true,DOFFocusDistance=true,DOFInFocusRadius=true}
local profiles={
    {Name="Clean",Values={Boxes=false,Distance=false,Radar=false,Arrows=false,VisibilityColors=false,Tool=false,HighlightStyle="Контур",Glow=false}},
    {Name="Tactical",Values={}},
    {Name="Detailed",Values={Skeleton=true,Tracers=true,LookDirection=true,Velocity=true,HighlightStyle="Пульс"}},
}
section("CONFIG","Alive checks",1)
toggle("CONFIG","Health > 0","AliveHealthCheck")
toggle("CONFIG","Humanoid state","AliveStateCheck")
toggle("CONFIG","Workspace ancestry","AliveAncestryCheck")
toggle("CONFIG","Head + root exist","AliveRootCheck")
toggle("CONFIG","Dead/Alive attributes","AliveDeadTags")
section("CONFIG","Visual presets",2)
for _,profile in ipairs(profiles) do
    local preset=profile
    local item=row("CONFIG",29)
    local hit=button(item,profile.Name,20,2,contentW-58,23)
    hit.BorderSizePixel=1; hit.BorderColor3=Color3.new(0,0,0)
    shade(hit,Color3.fromRGB(60,60,60),Color3.fromRGB(33,33,33))
    hit.BackgroundColor3=Color3.new(1,1,1)
    refreshers[#refreshers+1]=function() hit.TextColor3=profileName==preset.Name and theme.Accent or theme.Text end
    connect(hit.Activated,function()
        for key,value in pairs(defaults) do if not combatKeys[key] then settings[key]=value end end
        for key,value in pairs(preset.Values) do settings[key]=value end
        profileName=preset.Name; metadataDue=0; refreshUI()
    end)
end
section("CONFIG","Session",2)
local unloadRow=row("CONFIG",29)
local unload=button(unloadRow,"Unload",20,2,contentW-58,23)
unload.BorderSizePixel=1; unload.BorderColor3=Color3.new(0,0,0)
connect(unload.Activated,function() if cleanup then cleanup() end end)


local launcher = button(gui, BRAND_NAME, 22, 65, 88, 24)
launcher.Name = "OpenMenu"
launcher.ZIndex = 30
launcher.TextSize = 10
stroke(launcher, theme.Line)
local menuTransition = 0
local function setMenuOpen(open)
    menuOpen = open
    closeDropdown()
    footerHint = nil
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
    closeDropdown()
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
        closeDropdown()
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
    if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then setMenuOpen(not menuOpen)
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
    return GameAdapter:IsTeammate(player)
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
    local character = GameAdapter:GetCharacter(data.Player)
    if data.Character ~= character then
        releaseHighlight(data)
        data.Character = character
        data.VisibleToCamera = nil
        data.RayDue = 0
    end
    data.Root = character and GameAdapter:GetRoot(character)
    data.Head = character and GameAdapter:GetHead(character)
    data.Humanoid = character and GameAdapter:GetHumanoid(character)
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
    data.Eligible = liveCharacter(data.Player, character) ~= nil
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
    return Visibility:SamplePart(head)
end
local function updateVisibility(data, camera, now)
    if not settings.VisibilityColors and not settings.OnlyVisible and not settings.HeadMarker then return end
    if now < data.RayDue or rayBudget < 1 then return end

    local start = camera.CFrame.Position
    local scanParts = {
        data.Head,
        data.Parts.UpperTorso or data.Parts.Torso,
        data.Parts.LowerTorso,
        data.Parts["Left Arm"] or data.Parts.LeftUpperArm,
        data.Parts["Right Arm"] or data.Parts.RightUpperArm,
        data.Parts["Left Leg"] or data.Parts.LeftUpperLeg,
        data.Parts["Right Leg"] or data.Parts.RightUpperLeg,
    }
    local visible = false
    for _, part in ipairs(scanParts) do
        if part and part.Parent then
            for _, point in ipairs(Visibility:SamplePart(part)) do
                if rayBudget < 1 then break end
                rayBudget = rayBudget - 1
                if Visibility:Clear(start, point, data.Character, rayParams) then
                    visible = true
                    break
                end
            end
        end
        if visible or rayBudget < 1 then break end
    end

    data.VisibleToCamera = visible
    data.RayDue = now + (settings.VisibilitySampling == "Dense" and 0.045 or 0.07)
        + (math.abs(data.Player.UserId) % 5) * 0.004
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
    if settings.ChamsEnabled then
        releaseHighlight(data)
        return
    end
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
    if not settings.Enabled or not data.Eligible or GameAdapter:GetCharacter(data.Player) ~= data.Character
        or not data.Root or not data.Root:IsDescendantOf(data.Character)
        or not data.Head or not data.Head:IsDescendantOf(data.Character)
        or deadCharacters[data.Character]
        or not liveCharacter(data.Player, data.Character) then
        hide(data)
        releaseHighlight(data)
        return false
    end
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
    local TARGET_REFRESH = 0.05
    local PRE_CAMERA = RENDER_NAME .. "_Restore"
    local syntheticInput, consumedClick = false, false
    local bindFireAction
    local inputRebindToken = 0
    local pressed
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
        local character, humanoid = liveCharacter(localPlayer)
        local head = character and GameAdapter:GetHead(character)
        if not head or not head:IsA("BasePart") then return nil end
        return character, head, humanoid
    end
    local function blocked()
        return not controller.Running or menuOpen or not focused or GuiService.MenuIsOpen
            or UserInputService:GetFocusedTextBox() ~= nil or not ownCharacter()
    end
    local function updateFilter(camera)
        local ignored = {camera, debrisFolder}
        local own = GameAdapter:GetCharacter(localPlayer)
        if own then ignored[#ignored + 1] = own end
        rayParams.FilterDescendantsInstances = ignored
    end
    local function enemyAlive(player, expected)
        if player == localPlayer or (settings.AimTeamCheck and isTeammate(player)) then return false end
        local character = Alive:IsAlive(player, expected)
        return character ~= nil and not character:FindFirstChildOfClass("ForceField")
    end

    local targeting = importModule("combat/targeting.lua")({
        Players = Players,
        LocalPlayer = localPlayer,
        Settings = settings,
        Alive = Alive,
        Visibility = Visibility,
        IsTeammate = isTeammate,
        GetLocalHead = function()
            local _, head = ownCharacter()
            return head
        end,
        Adapter = GameAdapter,
    })
    local motionAim = importModule("combat/motion_aim.lua")({
        Settings = settings,
        Targeting = targeting,
        Visibility = Visibility,
        UserInputService = UserInputService,
    })
    local antiAim = importModule("combat/antiaim.lua")({
        Settings = settings,
        GetCharacter = function()
            local character, _, humanoid = ownCharacter()
            return character, humanoid
        end,
    })

    local function validPoint(camera, part, character, forceWalls)
        local player = character and GameAdapter:GetPlayerFromCharacter(character)
        if not player then return nil end
        return targeting:ValidatePoint(camera, rayParams, player, character, part, forceWalls)
    end

    local function findTarget(camera, forceWalls, partMode)
        if blocked() then return nil end
        updateFilter(camera)
        local player, _, part, point = targeting:Find(camera, rayParams, currentTarget, forceWalls, partMode)
        return player, part, point
    end

    local function setTarget(player, part)
        currentTarget, currentPart = player, part
        controller.Target = player
    end
    -- Aim never reads an equipped weapon. The selected input backend is independent.
    local function resolveInputAdapter(method)
        if method == "Creator" then
            if not creatorInputAdapter then return nil, "Creator adapter is not configured" end
            return creatorInputAdapter
        end
        if method == "MouseButton" then
            if type(mouse1press) ~= "function" or type(mouse1release) ~= "function" then
                return nil, "MouseButton API is unavailable; select VirtualUser or Creator"
            end
            -- Snapshot both functions so release uses the same backend as press.
            local press, release = mouse1press, mouse1release
            return {Press=function() press() end, Release=function() release() end}
        end
        if method == "VirtualUser" then
            return {
                Press=function(context)
                    VirtualUser:CaptureController()
                    VirtualUser:Button1Down(context.MousePosition, context.Camera.CFrame)
                end,
                Release=function(context)
                    VirtualUser:Button1Up(context.MousePosition, context.Camera.CFrame)
                end,
            }
        end
        return nil, "Unknown input method"
    end
    local function releaseInput()
        local input = pressed
        pressed = nil
        if not input then return end
        local wasSynthetic = syntheticInput
        syntheticInput = true
        local ok, result, reason = pcall(input.Adapter.Release, input.Context)
        syntheticInput = wasSynthetic
        if not ok or result == false then
            warn("Spectra input release: " .. tostring(ok and reason or result))
        end
        if input.Synthetic then
            inputRebindToken = inputRebindToken + 1
            local token = inputRebindToken
            -- Generated mouse events may be delivered after the API call returns.
            task.delay(0.05, function()
                if controller.Running and token == inputRebindToken and not pressed and bindFireAction then
                    bindFireAction()
                end
            end)
        end
    end
    local function pressInput(camera)
        if pressed then return false, "Input is already held" end
        local adapter, errorMessage = resolveInputAdapter(settings.FireMethod)
        if not adapter then return false, errorMessage end
        local context = {
            Camera=camera, MousePosition=UserInputService:GetMouseLocation(),
            Target=shot and shot.Player, Character=shot and shot.Character,
            Part=shot and shot.Part, AimPosition=shot and shot.Point,
            Automatic=shot and shot.Auto or false,
        }
        local input = {Adapter=adapter, Context=context, Synthetic=settings.FireMethod ~= "Creator"}
        if input.Synthetic then
            inputRebindToken = inputRebindToken + 1
            ContextActionService:UnbindAction(ACTION)
        end
        pressed = input
        local wasSynthetic = syntheticInput
        syntheticInput = true
        local ok, result, reason = pcall(adapter.Press, context)
        syntheticInput = wasSynthetic
        if not ok or result == false then
            releaseInput()
            return false, "Input failed: " .. tostring(ok and reason or result)
        end
        return true
    end

    local function restoreShot(_, status)
        local previous = shot
        releaseInput()
        shot = nil
        if previous and previous.Camera and previous.Applied then
            pcall(function() previous.Camera.CFrame = previous.Base end)
        end
        if status then controller.Status = status end
    end
    -- Restore before Roblox's camera controller, so mouse movement during a shot is preserved.
    RunService:BindToRenderStep(PRE_CAMERA, Enum.RenderPriority.Camera.Value - 1, function()
        if shot and shot.Applied then
            shot.Camera.CFrame = shot.Base
            shot.Applied = false
        end
    end)
    local function restoreAnti()
        antiAim:Restore()
    end
    local function updateAnti(dt, camera, now)
        local busy = shot or pendingAcquire
            or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        antiAim:Update(dt, camera, now, blocked() or busy)
    end
    local function resolveAutoSource()
        if not settings.AutoFire then return nil end
        if settings.AutoFireSource == "Silent" then
            return settings.SilentAim and "Silent" or nil
        elseif settings.AutoFireSource == "Motion" then
            return settings.AimEnabled and "Motion" or nil
        end
        if settings.SilentAim then return "Silent" end
        if settings.AimEnabled then return "Motion" end
        return nil
    end

    local function beginClick(auto, player, part)
        if pendingAcquire or shot or blocked() or not settings.SilentAim then return false end
        if auto and os.clock() < autoFireDue then return false end
        pendingAcquire = {At=os.clock() + settings.AcquireMS / 1000, Auto=auto == true,
            Player=player, Character=GameAdapter:GetCharacter(player), Part=part}
        restoreAnti()
        return true
    end

    local function beginMotionAuto(camera, player, character, part, aimPoint, now)
        if pendingAcquire or shot or pressed or blocked() or not settings.AimEnabled
            or not settings.AutoFire or now < autoFireDue then return false end
        if not player or not character or not part or not aimPoint then return false end
        shot = {
            Camera=camera, Base=camera.CFrame, Player=player, Character=character,
            Part=part, Point=aimPoint, FireAt=now, Auto=true, NoFlick=true,
            Phase="Aim", Expires=now + 1,
        }
        setTarget(player, part)
        restoreAnti()
        return true
    end

    local function acquireForShot(camera, now)
        if not pendingAcquire or now < pendingAcquire.At then return end
        local request = pendingAcquire
        pendingAcquire = nil
        if blocked() or not settings.SilentAim or (request.Auto and not settings.AutoFire)
            or not enemyAlive(request.Player, request.Character) then return end
        updateFilter(camera)
        local point = request.Part and request.Part:IsDescendantOf(request.Character)
            and validPoint(camera, request.Part, request.Character, request.Auto)
        if not point then controller.Status = "Цель потеряна" return end
        shot = {Camera=camera, Base=camera.CFrame, Player=request.Player, Character=request.Character,
            Part=request.Part, Point=point, FireAt=now + settings.ShotMS / 1000, Auto=request.Auto,
            NoFlick=false, Phase="Aim", Expires=now + 1}
        setTarget(request.Player, request.Part)
    end

    local function updateShot(camera, now)
        if not shot then return end
        local sourceEnabled = (shot.NoFlick and settings.AimEnabled)
            or ((not shot.NoFlick) and settings.SilentAim)
        if blocked() or not sourceEnabled or camera ~= shot.Camera or now > shot.Expires
            or (shot.Auto and not settings.AutoFire) or not enemyAlive(shot.Player, shot.Character)
            or not shot.Part:IsDescendantOf(shot.Character) then
            restoreShot(camera, "Выстрел отменён")
            return
        end

        updateFilter(camera)
        local point = validPoint(camera, shot.Part, shot.Character, true)
        if not point then
            restoreShot(camera, "Цель скрылась / вне FOV")
            return
        end

        if shot.NoFlick then
            local motionPlayer, motionCharacter, motionPart, motionPoint = motionAim:GetTarget()
            if motionPlayer == shot.Player and motionCharacter == shot.Character
                and motionPart == shot.Part and motionPoint
                and (motionPoint - shot.Part.Position).Magnitude <= shot.Part.Size.Magnitude + 1 then
                point = motionPoint
            end
            shot.Point = point
            if not motionAim:IsAligned(camera, point) then return end
        else
            shot.Point = point
        end

        if shot.Phase == "Aim" and now >= shot.FireAt then
            shot.Base = camera.CFrame

            if not shot.NoFlick then
                -- Silent: flick only around the input call, then restore in the same render step.
                camera.CFrame = CFrame.lookAt(shot.Base.Position, point, shot.Base.UpVector)
                shot.Applied = true
            end

            telemetry:RecordShot(shot.Player, shot.Character, shot.Part, shot.Base.Position, point)
            local activeShot = shot
            local fired, reason = pressInput(camera)

            if not shot.NoFlick and camera == workspace.CurrentCamera then
                camera.CFrame = shot and shot.Base or camera.CFrame
            end
            if shot then shot.Applied = false end

            if shot ~= activeShot then
                releaseInput()
                return
            end
            if not fired then
                autoFireDue = now + 0.5
                restoreShot(camera, reason)
                return
            end

            shot.Phase = "Hold"
            shot.ReleaseAt = now + settings.HoldMS / 1000
            autoFireDue = now + settings.FireInterval / 1000
            controller.Status = (shot.NoFlick and "Motion fire: " or "Silent fire: ") .. shot.Player.DisplayName
        elseif shot.Phase == "Hold" and now >= shot.ReleaseAt then
            restoreShot(camera)
        end
    end
    local function fireAction(_, state)
        if syntheticInput then return Enum.ContextActionResult.Pass end
        if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
            local consumed = consumedClick
            consumedClick = false
            return consumed and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
        end
        if state ~= Enum.UserInputState.Begin or not settings.SilentAim or blocked() then
            return Enum.ContextActionResult.Pass
        end
        if shot or pendingAcquire then consumedClick = true return Enum.ContextActionResult.Sink end
        local camera = workspace.CurrentCamera
        if not camera then return Enum.ContextActionResult.Pass end
        local player, part = findTarget(camera, false)
        -- A normal click stays normal when there is no valid target.
        if player and beginClick(false, player, part) then
            consumedClick = true
            return Enum.ContextActionResult.Sink
        end
        return Enum.ContextActionResult.Pass
    end
    bindFireAction = function()
        consumedClick = false
        ContextActionService:UnbindAction(ACTION)
        ContextActionService:BindActionAtPriority(ACTION, fireAction, false, 3000, Enum.UserInputType.MouseButton1)
    end
    bindFireAction()
    local function suspend()
        pendingAcquire = nil
        restoreShot(workspace.CurrentCamera, "Пауза")
        restoreAnti()
        motionAim:Clear()
        setTarget(nil, nil)
        targetMarker.Visible = false
    end
    bind(UserInputService.WindowFocusReleased, function() focused = false suspend() end)
    bind(UserInputService.WindowFocused, function() focused = true end)
    bind(UserInputService.TextBoxFocused, suspend)

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
        if not character then return end
        Alive:MarkDead(character)
        local data = visuals[player]
        if data and data.Character == character then
            data.Eligible = false
            data.VisibleToCamera = false
            hide(data)
            releaseHighlight(data)
        end
        if currentTarget == player then
            setTarget(nil, nil)
            targetMarker.Visible = false
        end
        if shot and shot.Character == character then restoreShot(workspace.CurrentCamera, "Цель умерла") end
        if pendingAcquire and pendingAcquire.Character == character then pendingAcquire = nil end
        if player == localPlayer then suspend() end
        metadataDue, candidateDue = 0, 0
    end
    local function watch(player)
        if watchers[player] then return end
        local record = {Life={}, HumanoidConnections={}}
        watchers[player] = record
        local function clearLife()
            disconnect(record.Life)
            disconnect(record.HumanoidConnections)
            record.Life, record.HumanoidConnections = {}, {}
            record.Humanoid = nil
        end
        local function attach(character)
            clearLife()
            if record.Character then restoreBody(record.Character) end
            Alive:Clear(character)
            record.Character, record.Shattered = character, false
            metadataDue = 0
            local function onDead()
                if record.Character ~= character then return end
                local first = not deadCharacters[character]
                markDead(player, character)
                if first and not record.Shattered then
                    record.Shattered = true
                    disintegrate(character)
                end
            end
            record.OnDead = onDead
            local function attachHumanoid(humanoid)
                if not humanoid:IsA("Humanoid") or record.Humanoid == humanoid then return end
                disconnect(record.HumanoidConnections)
                record.HumanoidConnections = {}
                record.Humanoid = humanoid
                local function check()
                    if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then onDead() end
                end
                local list = record.HumanoidConnections
                list[#list + 1] = humanoid.HealthChanged:Connect(check)
                list[#list + 1] = humanoid.Died:Connect(onDead)
                list[#list + 1] = humanoid.StateChanged:Connect(check)
                check() -- Handles a corpse that existed before Spectra was loaded.
            end
            record.Life[#record.Life + 1] = character.ChildAdded:Connect(attachHumanoid)
            record.Life[#record.Life + 1] = character.ChildRemoved:Connect(function(child)
                if child == record.Humanoid then
                    disconnect(record.HumanoidConnections)
                    record.HumanoidConnections, record.Humanoid = {}, nil
                    local data = visuals[player]
                    if data then hide(data) releaseHighlight(data) end
                    metadataDue = 0
                    local nextHumanoid = character:FindFirstChildOfClass("Humanoid")
                    if nextHumanoid then attachHumanoid(nextHumanoid) end
                end
            end)
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then attachHumanoid(humanoid) end
        end
        record.Spawn = player.CharacterAdded:Connect(attach)
        record.Removing = player.CharacterRemoving:Connect(function(character)
            markDead(player, character)
            if record.Character == character then
                clearLife()
                restoreBody(character)
                record.Character, record.OnDead = nil, nil
            end
        end)
        if player.Character then attach(player.Character) end
    end
    local function unwatch(player)
        local record = watchers[player]
        if not record then return end
        markDead(player, record.Character)
        record.Spawn:Disconnect()
        record.Removing:Disconnect()
        disconnect(record.Life)
        disconnect(record.HumanoidConnections)
        if record.Character then restoreBody(record.Character) end
        watchers[player] = nil
    end
    bind(Players.PlayerAdded, watch)
    bind(Players.PlayerRemoving, unwatch)
    for _, player in ipairs(Players:GetPlayers()) do watch(player) end

    function controller:Pause()
        pendingAcquire = nil
        restoreShot(workspace.CurrentCamera, "Пауза")
        restoreAnti()
        motionAim:Clear()
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
        -- Events hide immediately; polling catches missed/deferred health and state events.
        for _, record in pairs(watchers) do
            local h = record.Humanoid
            if h and record.OnDead and not deadCharacters[record.Character]
                and (h.Health <= 0 or h:GetState() == Enum.HumanoidStateType.Dead) then record.OnDead() end
        end
        local suspended = blocked()
        local aiming = settings.SilentAim or settings.AimEnabled
        reticle.Visible = aiming and not suspended
        if suspended then
            suspend()
        else
            if not settings.SilentAim then
                pendingAcquire = nil
                if shot and not shot.NoFlick then restoreShot(camera) end
            end

            acquireForShot(camera, now)
            if shot then
                updateShot(camera, now)
            else
                local silentPoint
                if settings.SilentAim then
                    if currentTarget and currentPart then
                        updateFilter(camera)
                        local character = GameAdapter:GetCharacter(currentTarget)
                        silentPoint = enemyAlive(currentTarget) and character
                            and currentPart:IsDescendantOf(character)
                            and validPoint(camera, currentPart, character, true)
                        if not silentPoint then
                            setTarget(nil, nil)
                            candidateDue = 0
                        end
                    end

                    if not currentTarget and now >= candidateDue then
                        local player, part, foundPoint = findTarget(camera, true, settings.AimPart)
                        setTarget(player, part)
                        silentPoint = foundPoint
                        candidateDue = now + TARGET_REFRESH
                    end
                else
                    setTarget(nil, nil)
                end

                updateFilter(camera)
                local source = resolveAutoSource()
                local forceMotion = source == "Motion"
                local motionPlayer, motionPart, motionPoint = motionAim:Update(
                    dt, camera, rayParams, false, forceMotion, now
                )
                local motionCharacter = motionPlayer and GameAdapter:GetCharacter(motionPlayer) or nil

                if not settings.SilentAim then
                    setTarget(motionPlayer, motionPart)
                end

                if settings.AutoFire and now >= autoFireDue then
                    if source == "Silent" and settings.SilentAim and currentTarget
                        and currentPart and not pendingAcquire then
                        if beginClick(true, currentTarget, currentPart) then
                            autoFireDue = now + settings.FireInterval / 1000
                        end
                    elseif source == "Motion" and motionPlayer and motionCharacter
                        and motionPart and motionPoint and motionAim:IsAligned(camera) then
                        if beginMotionAuto(camera, motionPlayer, motionCharacter, motionPart, motionPoint, now) then
                            autoFireDue = now + settings.FireInterval / 1000
                        end
                    end
                end
            end
            updateAnti(dt, camera, now)
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
        combatStatus.Visible = (settings.SilentAim or settings.AimEnabled or settings.AntiAim) and not menuOpen
        combatStatus.Text = string.format("%s / %s / %s / FOV %.0f°",
            self.Status, settings.FireMethod, settings.AutoFire and "AUTO" or "CLICK", settings.AimFOV)

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
        RunService:UnbindFromRenderStep(PRE_CAMERA)
        restoreShot(workspace.CurrentCamera)
        restoreAnti()
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
    closeDropdown()
    combat:Stop()
    thirdPerson:Stop()
    telemetry:Stop()
    chams:Stop()
    environment:Stop()
    RunService:UnbindFromRenderStep(RENDER_NAME)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, motion in pairs(activeTweens) do motion:Cancel() end
    for _, data in pairs(visuals) do releaseHighlight(data) end
    visuals = {}
    gui:Destroy()
end
connect(shutdown.Event, cleanup)
connect(gui.Destroying, cleanup)
if typeof(script) == "Instance" then connect(script.Destroying, cleanup) end
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
    environment:Update(camera, now)
    thirdPerson:Update()
    combat:Update(dt, camera, now)
    telemetry:Update(camera, now)
    chams:Update(now)
    local localCharacter = GameAdapter:GetCharacter(localPlayer)
    local localRoot = localCharacter and GameAdapter:GetRoot(localCharacter)
    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local ignore = {camera}
    if localCharacter then ignore[#ignore + 1] = localCharacter end
    rayParams.FilterDescendantsInstances = ignore
    rayBudget = settings.VisibilitySampling == "Dense" and 160 or (settings.VisibilitySampling == "Balanced" and 96 or 56)
    if now >= metadataDue then updateMetadata(camera, origin, now) end
    radar.Visible = settings.Enabled and settings.Radar
    local count = 0
    for _, data in pairs(visuals) do
        if updatePlayer(data, camera, origin, now) then count = count + 1 end
    end
    smoothedFPS = smoothedFPS + ((1 / math.max(dt, 0.001)) - smoothedFPS) * math.min(dt * 3, 1)
    if now >= statsDue then
        footer.Text = footerHint or string.format("%s  |  %s  |  %d players  |  %d fps                         INS / RSHIFT", BRAND_NAME, profileName, count, math.floor(smoothedFPS + 0.5))
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

-- Portable creator API: no PlaceId, RemoteEvent names or weapon/server paths.
local api = {Version="10.0.0"}
function api:Set(key,value)
    if not alive then return false,"Spectra is unloaded" end
    return setSetting(key,value)
end
function api:GetSettings()
    local copy={}
    for key,value in pairs(settings) do copy[key]=value end
    return copy
end
function api:SetInputAdapter(adapter)
    if not alive then return false,"Spectra is unloaded" end
    if adapter ~= nil and (type(adapter) ~= "table" or type(adapter.Press) ~= "function"
        or type(adapter.Release) ~= "function") then return false,"Expected Press and Release functions" end
    combat:Pause()
    creatorInputAdapter=adapter and {Press=adapter.Press,Release=adapter.Release} or nil
    return true
end
function api:SetGameAdapter(adapter)
    if not alive then return false,"Spectra is unloaded" end
    combat:Pause()
    local ok, reason = GameAdapter:SetCustom(adapter)
    if ok then metadataDue = 0 end
    return ok, reason
end
function api:GetState()
    return {
        Running=alive,Target=combat.Target,Status=combat.Status,MenuOpen=menuOpen,
        AutoFireSource=settings.AutoFireSource,WorldMode=settings.WorldLightingMode,
    }
end
function api:OpenMenu(open)
    if alive then setMenuOpen(open ~= false) end
end
function api:Unload() cleanup() end
return api
