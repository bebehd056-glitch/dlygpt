-- SPECTRA client environment / shader stack.
-- Uses standard Lighting, Atmosphere and camera-local post effects only.

return function(ctx)
    local settings = assert(ctx.Settings, "Environment: Settings missing")
    local Lighting = game:GetService("Lighting")
    local Workspace = ctx.Workspace or workspace

    local stopped = false
    local lastLightingMode
    local currentCamera
    local post = {}
    local aurora = {}
    local auroraFolder

    local lightingSnapshot = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ColorShift_Top = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        Brightness = Lighting.Brightness,
        ExposureCompensation = Lighting.ExposureCompensation,
        ClockTime = Lighting.ClockTime,
        GlobalShadows = Lighting.GlobalShadows,
    }

    local originalAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    local atmosphere = originalAtmosphere
    local atmosphereCreated = false
    local fogActive = false
    local atmosphereSnapshot = originalAtmosphere and {
        Density = originalAtmosphere.Density,
        Offset = originalAtmosphere.Offset,
        Haze = originalAtmosphere.Haze,
        Glare = originalAtmosphere.Glare,
        Color = originalAtmosphere.Color,
        Decay = originalAtmosphere.Decay,
    } or nil

    local function ensureAtmosphere()
        if atmosphere and atmosphere.Parent then return atmosphere end
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "SpectraAtmosphere"
        atmosphere.Parent = Lighting
        atmosphereCreated = true
        return atmosphere
    end

    local tintColors = {
        Aurora = Color3.fromRGB(145, 205, 225),
        Blue = Color3.fromRGB(135, 175, 255),
        Purple = Color3.fromRGB(190, 145, 255),
        Green = Color3.fromRGB(145, 235, 175),
        Red = Color3.fromRGB(255, 150, 145),
        Gold = Color3.fromRGB(255, 210, 145),
        Mono = Color3.fromRGB(210, 210, 210),
    }

    local function restoreLighting()
        for key, value in pairs(lightingSnapshot) do
            pcall(function() Lighting[key] = value end)
        end
        lastLightingMode = nil
    end

    local function applyLightingMode()
        local mode = settings.WorldLightingMode or "Game"
        if settings.AuroraSky and mode == "Game" then mode = "Aurora" end
        if mode == lastLightingMode then return end
        if mode == "Game" then
            restoreLighting()
            lastLightingMode = "Game"
            return
        end

        if mode == "Fullbright" then
            Lighting.Ambient = Color3.fromRGB(205, 205, 205)
            Lighting.OutdoorAmbient = Color3.fromRGB(205, 205, 205)
            Lighting.ColorShift_Top = Color3.new(0, 0, 0)
            Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
            Lighting.Brightness = 2.4
            Lighting.ExposureCompensation = 0.25
            Lighting.GlobalShadows = false
        elseif mode == "Night" then
            Lighting.Ambient = Color3.fromRGB(36, 43, 68)
            Lighting.OutdoorAmbient = Color3.fromRGB(44, 52, 78)
            Lighting.ColorShift_Top = Color3.fromRGB(18, 30, 72)
            Lighting.ColorShift_Bottom = Color3.fromRGB(8, 12, 26)
            Lighting.Brightness = 1
            Lighting.ExposureCompensation = -0.35
            Lighting.ClockTime = 0.5
            Lighting.GlobalShadows = true
        elseif mode == "Sunset" then
            Lighting.Ambient = Color3.fromRGB(115, 72, 75)
            Lighting.OutdoorAmbient = Color3.fromRGB(132, 92, 82)
            Lighting.ColorShift_Top = Color3.fromRGB(255, 156, 104)
            Lighting.ColorShift_Bottom = Color3.fromRGB(88, 60, 92)
            Lighting.Brightness = 1.6
            Lighting.ExposureCompensation = 0.08
            Lighting.ClockTime = 18.4
        elseif mode == "Aurora" then
            Lighting.Ambient = Color3.fromRGB(28, 45, 68)
            Lighting.OutdoorAmbient = Color3.fromRGB(32, 52, 72)
            Lighting.ColorShift_Top = Color3.fromRGB(70, 150, 145)
            Lighting.ColorShift_Bottom = Color3.fromRGB(16, 22, 48)
            Lighting.Brightness = 1.05
            Lighting.ExposureCompensation = -0.28
            Lighting.ClockTime = 1.1
            Lighting.GlobalShadows = true
        end
        lastLightingMode = mode
    end

    local function ensurePost(camera)
        if currentCamera == camera and post.Color and post.Color.Parent then return end
        currentCamera = camera
        for _, effect in pairs(post) do
            if effect then effect:Destroy() end
        end
        post = {}

        local color = Instance.new("ColorCorrectionEffect")
        color.Name = "SpectraColorWorld"
        color.Parent = camera
        post.Color = color

        local bloom = Instance.new("BloomEffect")
        bloom.Name = "SpectraBloom"
        bloom.Parent = camera
        post.Bloom = bloom

        local blur = Instance.new("BlurEffect")
        blur.Name = "SpectraBlur"
        blur.Parent = camera
        post.Blur = blur

        local sun = Instance.new("SunRaysEffect")
        sun.Name = "SpectraSunRays"
        sun.Parent = camera
        post.Sun = sun

        local dof = Instance.new("DepthOfFieldEffect")
        dof.Name = "SpectraDOF"
        dof.Parent = camera
        post.DOF = dof
    end

    local function updatePost(camera)
        ensurePost(camera)

        local tint = tintColors[settings.WorldTint or "Aurora"] or tintColors.Aurora
        local strength = math.clamp((settings.WorldTintStrength or 35) / 100, 0, 1)
        post.Color.Enabled = settings.ColorWorld == true
        post.Color.TintColor = Color3.new(1, 1, 1):Lerp(tint, strength)
        post.Color.Saturation = math.clamp((settings.WorldSaturation or 0) / 100, -1, 1)
        post.Color.Contrast = math.clamp((settings.WorldContrast or 0) / 100, -1, 1)
        post.Color.Brightness = math.clamp((settings.WorldBrightness or 0) / 100, -1, 1)

        post.Bloom.Enabled = settings.WorldBloom == true
        post.Bloom.Intensity = settings.BloomIntensity or 1
        post.Bloom.Size = settings.BloomSize or 24
        post.Bloom.Threshold = settings.BloomThreshold or 1

        post.Blur.Enabled = settings.WorldBlur == true
        post.Blur.Size = settings.BlurSize or 4

        post.Sun.Enabled = settings.WorldSunRays == true
        post.Sun.Intensity = settings.SunRaysIntensity or 0.08
        post.Sun.Spread = settings.SunRaysSpread or 0.85

        post.DOF.Enabled = settings.WorldDOF == true
        post.DOF.FarIntensity = settings.DOFFarIntensity or 0.15
        post.DOF.NearIntensity = settings.DOFNearIntensity or 0
        post.DOF.FocusDistance = settings.DOFFocusDistance or 60
        post.DOF.InFocusRadius = settings.DOFInFocusRadius or 45
    end

    local function updateAtmosphere()
        if settings.WorldFog then
            local active = ensureAtmosphere()
            active.Density = settings.FogDensity or 0.3
            active.Offset = settings.FogOffset or 0
            active.Haze = settings.FogHaze or 1.5
            active.Glare = settings.FogGlare or 0
            local base = tintColors[settings.FogColor or "Blue"] or tintColors.Blue
            active.Color = base
            active.Decay = base:Lerp(Color3.fromRGB(15, 18, 28), 0.55)
            fogActive = true
        elseif fogActive then
            if atmosphereCreated then
                if atmosphere and atmosphere.Parent then atmosphere:Destroy() end
                atmosphere = originalAtmosphere
                atmosphereCreated = false
            elseif atmosphere and atmosphereSnapshot then
                for key, value in pairs(atmosphereSnapshot) do atmosphere[key] = value end
            end
            fogActive = false
        end
    end

    local function destroyAurora()
        if auroraFolder then auroraFolder:Destroy() end
        auroraFolder = nil
        aurora = {}
    end

    local function ensureAurora()
        if auroraFolder and auroraFolder.Parent then return end
        destroyAurora()
        auroraFolder = Instance.new("Folder")
        auroraFolder.Name = "SpectraAurora"
        auroraFolder.Parent = Workspace

        for i = 1, 7 do
            local a = Instance.new("Part")
            a.Name = "AuroraA" .. i
            a.Anchored = true
            a.CanCollide = false
            a.CanTouch = false
            a.CanQuery = false
            a.Transparency = 1
            a.Size = Vector3.new(0.2, 0.2, 0.2)
            a.Parent = auroraFolder

            local b = a:Clone()
            b.Name = "AuroraB" .. i
            b.Parent = auroraFolder

            local at0 = Instance.new("Attachment")
            at0.Parent = a
            local at1 = Instance.new("Attachment")
            at1.Parent = b

            local beam = Instance.new("Beam")
            beam.Name = "AuroraRibbon" .. i
            beam.Attachment0 = at0
            beam.Attachment1 = at1
            beam.FaceCamera = true
            beam.Segments = 24
            beam.Width0 = 70 + i * 6
            beam.Width1 = 95 + i * 5
            beam.LightEmission = 1
            beam.LightInfluence = 0
            beam.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 235, 180)),
                ColorSequenceKeypoint.new(0.45, Color3.fromRGB(90, 190, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 105, 255)),
            })
            beam.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.92),
                NumberSequenceKeypoint.new(0.2, 0.55),
                NumberSequenceKeypoint.new(0.55, 0.7),
                NumberSequenceKeypoint.new(1, 0.96),
            })
            beam.Parent = a
            aurora[#aurora + 1] = {A = a, B = b, Beam = beam, Phase = i * 0.83}
        end
    end

    local function updateAurora(camera, now)
        if not settings.AuroraSky then
            destroyAurora()
            return
        end
        ensureAurora()

        local position = camera.CFrame.Position
        local forward = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local intensity = math.clamp((settings.AuroraIntensity or 55) / 100, 0.05, 1)
        local speed = settings.AuroraSpeed or 0.5

        for i, item in ipairs(aurora) do
            local wave = math.sin(now * speed + item.Phase)
            local depth = 280 + i * 42
            local height = 150 + i * 17 + wave * 18
            local width = 460 + i * 34
            local center = position + forward * depth + Vector3.new(0, height, 0)
            item.A.CFrame = CFrame.new(center - right * width * 0.5)
            item.B.CFrame = CFrame.new(center + right * width * 0.5)
            item.Beam.CurveSize0 = 70 * math.sin(now * speed * 0.75 + item.Phase)
            item.Beam.CurveSize1 = -70 * math.cos(now * speed * 0.62 + item.Phase)
            item.Beam.Width0 = (55 + i * 7) * intensity
            item.Beam.Width1 = (85 + i * 6) * intensity
            item.Beam.Enabled = true
        end
    end

    local api = {}

    function api:Update(camera, now)
        if stopped or not camera then return end
        applyLightingMode()
        updatePost(camera)
        updateAtmosphere()
        updateAurora(camera, now or os.clock())
    end

    function api:Stop()
        if stopped then return end
        stopped = true
        destroyAurora()
        for _, effect in pairs(post) do
            if effect then effect:Destroy() end
        end
        post = {}
        restoreLighting()
        if atmosphereCreated then
            if atmosphere and atmosphere.Parent then atmosphere:Destroy() end
        elseif atmosphere and atmosphereSnapshot then
            for key, value in pairs(atmosphereSnapshot) do atmosphere[key] = value end
        end
    end

    return api
end
