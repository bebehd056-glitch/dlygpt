-- SPECTRA motion aim.
-- Moves the camera at a bounded angular speed instead of snapping it.

return function(ctx)
    local settings = assert(ctx.Settings, "MotionAim: Settings missing")
    local targeting = assert(ctx.Targeting, "MotionAim: Targeting missing")
    local visibility = assert(ctx.Visibility, "MotionAim: Visibility missing")
    local UserInputService = ctx.UserInputService or game:GetService("UserInputService")

    local currentTarget, currentCharacter, currentPart
    local point, randomPoint
    local randomDue = 0

    local api = {}

    local function active(force)
        if not settings.AimEnabled then return false end
        if force then return true end
        if settings.MotionActivation == "Always" then return true end
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    local function randomizedPoint(camera, part, character, rayParams, basePoint, now)
        local amount = math.clamp((settings.MotionRandomization or 0) / 100, 0, 1)
        if amount <= 0 then return basePoint end
        if randomPoint and now < randomDue then return randomPoint end

        local candidates = visibility:SamplePart(part)
        local visible = {}
        for _, sample in ipairs(candidates) do
            if visibility:Clear(camera.CFrame.Position, sample, character, rayParams) then
                visible[#visible + 1] = sample
            end
        end
        local chosen = #visible > 0 and visible[math.random(1, #visible)] or basePoint
        randomPoint = basePoint:Lerp(chosen, amount)
        randomDue = now + math.max(settings.MotionRandomRefreshMS or 140, 20) / 1000
        return randomPoint
    end

    local function angularError(camera, targetPoint)
        if not targetPoint then return math.huge end
        local delta = targetPoint - camera.CFrame.Position
        if delta.Magnitude < 0.001 then return 0 end
        local dot = math.clamp(camera.CFrame.LookVector:Dot(delta.Unit), -1, 1)
        return math.deg(math.acos(dot))
    end

    function api:Clear()
        currentTarget, currentCharacter, currentPart = nil, nil, nil
        point, randomPoint, randomDue = nil, nil, 0
    end

    function api:GetTarget()
        return currentTarget, currentCharacter, currentPart, point
    end

    function api:IsAligned(camera)
        return angularError(camera, point) <= (settings.MotionFireTolerance or 1.25)
    end

    function api:Update(dt, camera, rayParams, blocked, forceActive, now)
        now = now or os.clock()
        if blocked or not active(forceActive) then
            self:Clear()
            return nil
        end

        local validated
        if currentTarget and currentCharacter and currentPart then
            validated = targeting:ValidatePoint(
                camera, rayParams, currentTarget, currentCharacter, currentPart, true
            )
        end

        if not validated then
            local player, character, part, found = targeting:Find(
                camera, rayParams, currentTarget, true, settings.MotionAimPart
            )
            if not player then
                self:Clear()
                return nil
            end
            if player ~= currentTarget or part ~= currentPart then
                randomPoint, randomDue = nil, 0
            end
            currentTarget, currentCharacter, currentPart = player, character, part
            validated = found
        end

        point = randomizedPoint(camera, currentPart, currentCharacter, rayParams, validated, now)
        local delta = point - camera.CFrame.Position
        if delta.Magnitude < 0.001 then return currentTarget, currentPart, point end

        local desired = CFrame.lookAt(camera.CFrame.Position, point, camera.CFrame.UpVector)
        local dot = math.clamp(camera.CFrame.LookVector:Dot(delta.Unit), -1, 1)
        local angle = math.acos(dot)
        local maxStep = math.rad(math.max(settings.MotionAimSpeed or 240, 1)) * math.min(dt, 0.1)
        local alpha = angle < 0.0001 and 1 or math.clamp(maxStep / angle, 0, 1)
        camera.CFrame = camera.CFrame:Lerp(desired, alpha)

        return currentTarget, currentPart, point
    end

    return api
end
