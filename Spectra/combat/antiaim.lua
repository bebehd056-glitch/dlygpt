-- SPECTRA local anti-aim controller

return function(ctx)
    local settings = assert(ctx.Settings, "AntiAim: Settings missing")
    local getCharacter = assert(ctx.GetCharacter, "AntiAim: GetCharacter missing")

    local state, spinAngle = nil, 0
    local api = {}

    function api:Restore()
        local previous = state
        state = nil
        if not previous then return end
        if previous.Humanoid and previous.Humanoid.Parent then
            previous.Humanoid.AutoRotate = previous.AutoRotate
        end
        if previous.Root and previous.Root.Parent then
            previous.Root.CFrame = CFrame.new(previous.Root.Position) * previous.Rotation
        end
    end

    function api:Update(dt, camera, now, blocked)
        local character, humanoid = getCharacter()
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not settings.AntiAim or blocked or not root or not root:IsA("BasePart")
            or root.Anchored or not humanoid or humanoid.Sit or humanoid.PlatformStand then
            self:Restore()
            return
        end
        if state and state.Root ~= root then self:Restore() end
        if not state then
            state = {Humanoid = humanoid, Root = root, AutoRotate = humanoid.AutoRotate, Rotation = root.CFrame.Rotation}
        end
        humanoid.AutoRotate = false
        local look = camera.CFrame.LookVector
        local yaw = math.atan2(-look.X, -look.Z) + math.rad(settings.AntiYaw or 180)
        if settings.AntiMode == "Jitter" then
            local period = math.max((settings.AntiPeriod or 120) / 1000, 0.01)
            local sign = math.floor(now / period) % 2 == 0 and 1 or -1
            yaw = yaw + math.rad(settings.AntiJitter or 55) * sign
        elseif settings.AntiMode == "Spin" then
            spinAngle = (spinAngle + math.rad(settings.AntiSpeed or 180) * dt) % (math.pi * 2)
            yaw = yaw + spinAngle
        end
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
    end

    return api
end
