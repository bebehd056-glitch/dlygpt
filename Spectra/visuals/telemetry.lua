-- SPECTRA hit telemetry: tracers, hit marker, hit logs and local hit flash.
-- Hit confirmation is inferred from Humanoid health replication after a recorded shot.

return function(ctx)
    local settings = assert(ctx.Settings, "Telemetry: Settings missing")
    local overlay = assert(ctx.Overlay, "Telemetry: Overlay missing")
    local theme = assert(ctx.Theme, "Telemetry: Theme missing")
    local TweenService = ctx.TweenService or game:GetService("TweenService")

    local tracers, connections = {}, {}
    local logRows = {}
    local stopped = false

    local root = Instance.new("Frame")
    root.Name = "SpectraTelemetry"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromScale(1, 1)
    root.ZIndex = 40
    root.Parent = overlay

    local logs = Instance.new("Frame")
    logs.Name = "HitLogs"
    logs.BackgroundTransparency = 1
    logs.AnchorPoint = Vector2.new(0.5, 0)
    logs.Position = UDim2.new(0.5, 0, 0, 38)
    logs.Size = UDim2.fromOffset(440, 180)
    logs.ZIndex = 42
    logs.Parent = root
    local list = Instance.new("UIListLayout")
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 3)
    list.Parent = logs

    local hitMarker = Instance.new("Frame")
    hitMarker.Name = "HitMarker"
    hitMarker.BackgroundTransparency = 1
    hitMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    hitMarker.Position = UDim2.fromScale(0.5, 0.5)
    hitMarker.Size = UDim2.fromOffset(34, 34)
    hitMarker.Visible = false
    hitMarker.ZIndex = 45
    hitMarker.Parent = root

    local markerLines = {}
    for i = 1, 4 do
        local line = Instance.new("Frame")
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Size = UDim2.fromOffset(9, 1)
        line.BackgroundColor3 = theme.Text
        line.BorderSizePixel = 0
        line.ZIndex = 46
        line.Parent = hitMarker
        markerLines[i] = line
    end
    markerLines[1].Position = UDim2.fromOffset(10, 10); markerLines[1].Rotation = 45
    markerLines[2].Position = UDim2.fromOffset(24, 10); markerLines[2].Rotation = -45
    markerLines[3].Position = UDim2.fromOffset(10, 24); markerLines[3].Rotation = -45
    markerLines[4].Position = UDim2.fromOffset(24, 24); markerLines[4].Rotation = 45

    local markerToken = 0

    local function drawLine(frame, a, b, color, thickness)
        local delta = b - a
        if delta.Magnitude < 0.5 then frame.Visible = false return end
        local center = (a + b) * 0.5
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.fromOffset(center.X, center.Y)
        frame.Size = UDim2.fromOffset(delta.Magnitude, thickness or 1)
        frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
        frame.BackgroundColor3 = color
        frame.Visible = true
    end

    local function showMarker()
        if not settings.HitMarker then return end
        markerToken = markerToken + 1
        local token = markerToken
        hitMarker.Visible = true
        hitMarker.Rotation = 0
        for _, line in ipairs(markerLines) do
            line.BackgroundTransparency = 0
            line.BackgroundColor3 = theme.Text
        end
        task.delay(0.18, function()
            if stopped or token ~= markerToken then return end
            hitMarker.Visible = false
        end)
    end

    local function addLog(player, damage, killed, part)
        if not settings.HitLogs then return end
        local row = Instance.new("TextLabel")
        row.Name = "HitLog"
        row.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        row.BackgroundTransparency = 0.08
        row.BorderSizePixel = 0
        row.Size = UDim2.fromOffset(390, 22)
        row.Font = Enum.Font.Code
        row.TextSize = 12
        row.TextColor3 = theme.Text
        row.TextXAlignment = Enum.TextXAlignment.Center
        row.ZIndex = 43
        local hitbox = part and part.Name or "body"
        row.Text = string.format("hit %s  |  %s  |  -%d hp%s",
            player and player.DisplayName or "target", hitbox, math.max(0, math.floor(damage + 0.5)),
            killed and "  |  DEAD" or "")
        row.Parent = logs
        logRows[#logRows + 1] = row
        while #logRows > 6 do
            local old = table.remove(logRows, 1)
            if old then old:Destroy() end
        end
        local duration = math.clamp(settings.HitLogDuration or 2.5, 0.5, 8)
        task.delay(duration, function()
            if row.Parent then
                local tween = TweenService:Create(row, TweenInfo.new(0.18), {TextTransparency = 1, BackgroundTransparency = 1})
                tween:Play()
                task.delay(0.2, function()
                    if row.Parent then row:Destroy() end
                    for i = #logRows, 1, -1 do
                        if logRows[i] == row then table.remove(logRows, i) break end
                    end
                end)
            end
        end)
    end

    local function hitFlash(character)
        if not settings.HitFlash or not character or not character.Parent then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "SpectraHitFlash"
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineColor = theme.Accent
        highlight.FillTransparency = 0.42
        highlight.OutlineTransparency = 0
        highlight.Parent = character
        task.delay(0.09, function() if highlight.Parent then highlight:Destroy() end end)
    end

    local api = {}

    function api:RecordShot(player, character, part, origin, point)
        if stopped then return end
        local now = os.clock()
        if settings.BulletTracers and origin and point then
            local core = Instance.new("Frame")
            core.BackgroundColor3 = theme.Accent
            core.BorderSizePixel = 0
            core.ZIndex = 41
            core.Parent = root
            local glow = Instance.new("Frame")
            glow.BackgroundColor3 = theme.Accent
            glow.BackgroundTransparency = 0.72
            glow.BorderSizePixel = 0
            glow.ZIndex = 40
            glow.Parent = root
            tracers[#tracers + 1] = {
                Core = core, Glow = glow, Origin = origin, Point = point,
                Expires = now + math.clamp(settings.TracerDuration or 0.35, 0.08, 1.5),
            }
        end

        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local before = humanoid.Health
        local done = false
        local connection
        connection = humanoid.HealthChanged:Connect(function(health)
            if done or stopped then return end
            if health < before - 0.01 then
                done = true
                if connection then connection:Disconnect() end
                local damage = before - math.max(health, 0)
                showMarker()
                addLog(player, damage, health <= 0, part)
                hitFlash(character)
            end
        end)
        connections[#connections + 1] = connection
        task.delay(0.7, function()
            if not done then
                done = true
                if connection and connection.Connected then connection:Disconnect() end
            end
        end)
    end

    function api:Update(camera, now)
        if stopped then return end
        now = now or os.clock()
        for i = #tracers, 1, -1 do
            local tracer = tracers[i]
            if now >= tracer.Expires or not settings.BulletTracers then
                tracer.Core:Destroy()
                tracer.Glow:Destroy()
                table.remove(tracers, i)
            else
                local a, av = camera:WorldToViewportPoint(tracer.Origin)
                local b, bv = camera:WorldToViewportPoint(tracer.Point)
                if a.Z > 0 and b.Z > 0 and (av or bv) then
                    local p1, p2 = Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y)
                    drawLine(tracer.Glow, p1, p2, theme.Accent, 4)
                    drawLine(tracer.Core, p1, p2, theme.Text, 1)
                    local alpha = math.clamp((tracer.Expires - now) / math.max(settings.TracerDuration or 0.35, 0.05), 0, 1)
                    tracer.Core.BackgroundTransparency = 1 - alpha
                    tracer.Glow.BackgroundTransparency = 1 - alpha * 0.28
                else
                    tracer.Core.Visible = false
                    tracer.Glow.Visible = false
                end
            end
        end
    end

    function api:Stop()
        if stopped then return end
        stopped = true
        markerToken = markerToken + 1
        for _, connection in ipairs(connections) do
            pcall(function() connection:Disconnect() end)
        end
        connections = {}
        root:Destroy()
    end

    return api
end
