-- SPECTRA motion aim v2.
-- Camera steering uses a smoothed target point plus acceleration/braking-limited angular motion.
-- No server/place/weapon binding is required.

return function(ctx)
    local settings = assert(ctx.Settings, "MotionAim: Settings missing")
    local targeting = assert(ctx.Targeting, "MotionAim: Targeting missing")
    local visibility = assert(ctx.Visibility, "MotionAim: Visibility missing")
    local UserInputService = ctx.UserInputService or game:GetService("UserInputService")

    local currentTarget, currentCharacter, currentPart
    local point, filteredPoint, randomLocalPoint
    local randomDue = 0
    local angularVelocity = 0

    local api = {}

    local function active(force)
        if not settings.AimEnabled then return false end
        if force then return true end
        if settings.MotionActivation == "Always" then return true end
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    local function moveTowards(current, target, maximumDelta)
        if current < target then return math.min(current + maximumDelta, target) end
        return math.max(current - maximumDelta, target)
    end

    local function chooseRandomGoal(camera, part, character, rayParams, basePoint, now)
        local amount = math.clamp((settings.MotionRandomization or 0) / 100, 0, 1)
        if amount <= 0 then
            randomLocalPoint = nil
            return basePoint
        end

        if randomLocalPoint and now < randomDue then
            return part.CFrame:PointToWorldSpace(randomLocalPoint)
        end

        local candidates = visibility:SamplePart(part)
        local visible = {}
        for _, sample in ipairs(candidates) do
            if visibility:Clear(camera.CFrame.Position, sample, character, rayParams) then
                visible[#visible + 1] = sample
            end
        end

        local chosen = #visible > 0 and visible[math.random(1, #visible)] or basePoint
        local worldGoal = basePoint:Lerp(chosen, amount)
        randomLocalPoint = part.CFrame:PointToObjectSpace(worldGoal)
        randomDue = now + math.max(settings.MotionRandomRefreshMS or 180, 40) / 1000
        return part.CFrame:PointToWorldSpace(randomLocalPoint)
    end

    local function smoothPoint(rawPoint, dt)
        if not filteredPoint then
            filteredPoint = rawPoint
            return filteredPoint
        end

        -- Exponential smoothing is framerate-independent and prevents the random point
        -- or a moving limb from creating a one-frame camera jerk.
        local response = math.clamp(settings.MotionAimTracking or 11, 2, 30)
        local alpha = 1 - math.exp(-response * math.min(dt, 0.05))
        filteredPoint = filteredPoint:Lerp(rawPoint, alpha)
        return filteredPoint
    end

    local function angularError(camera, targetPoint)
        if not targetPoint then return math.huge end
        local delta = targetPoint - camera.CFrame.Position
        if delta.Magnitude < 0.001 then return 0 end
        local dot = math.clamp(camera.CFrame.LookVector:Dot(delta.Unit), -1, 1)
        return math.deg(math.acos(dot))
    end

    local function steer(camera, targetPoint, dt)
        local origin = camera.CFrame.Position
        local delta = targetPoint - origin
        if delta.Magnitude < 0.001 then
            angularVelocity = 0
            return
        end

        local currentDirection = camera.CFrame.LookVector
        local desiredDirection = delta.Unit
        local dot = math.clamp(currentDirection:Dot(desiredDirection), -1, 1)
        local angle = math.acos(dot)
        if angle < 0.00005 then
            angularVelocity = 0
            return
        end

        local maxSpeed = math.rad(math.max(settings.MotionAimSpeed or 240, 1))
        local acceleration = math.rad(math.max(settings.MotionAimAcceleration or 1500, 30))
        local frame = math.min(dt, 0.05)

        -- sqrt(2*a*d) is the maximum speed that can still brake to zero at the target.
        -- This removes the sharp "hit target then stop" feel from the old implementation.
        local brakingSpeed = math.sqrt(math.max(0, 2 * acceleration * angle))
        local desiredSpeed = math.min(maxSpeed, brakingSpeed)
        angularVelocity = moveTowards(angularVelocity, desiredSpeed, acceleration * frame)

        local step = math.min(angle, angularVelocity * frame)
        if step <= 0 then return end

        local axis = currentDirection:Cross(desiredDirection)
        if axis.Magnitude < 0.00001 then
            axis = camera.CFrame.UpVector
        else
            axis = axis.Unit
        end

        local rotation = CFrame.fromAxisAngle(axis, step)
        local nextDirection = rotation:VectorToWorldSpace(currentDirection).Unit
        local up = camera.CFrame.UpVector
        if math.abs(nextDirection:Dot(up)) > 0.985 then
            up = Vector3.yAxis
            if math.abs(nextDirection:Dot(up)) > 0.985 then up = Vector3.xAxis end
        end
        camera.CFrame = CFrame.lookAt(origin, origin + nextDirection, up)
    end

    function api:Clear()
        currentTarget, currentCharacter, currentPart = nil, nil, nil
        point, filteredPoint, randomLocalPoint, randomDue = nil, nil, nil, 0
        angularVelocity = 0
    end

    function api:GetTarget()
        return currentTarget, currentCharacter, currentPart, point
    end

    function api:IsAligned(camera, targetPoint)
        return angularError(camera, targetPoint or point) <= (settings.MotionFireTolerance or 1.25)
    end

    function api:Update(dt, camera, rayParams, blocked, forceActive, now)
        now = now or os.clock()
        if blocked or not active(forceActive) then
            self:Clear()
            return nil
        end

        local requireVisibility = forceActive or settings.AimWallCheck
        local validated

        if currentTarget and currentCharacter and currentPart then
            validated = targeting:ValidatePoint(
                camera, rayParams, currentTarget, currentCharacter, currentPart, requireVisibility
            )
        end

        if not validated then
            local player, character, part, found = targeting:Find(
                camera, rayParams, currentTarget, requireVisibility, settings.MotionAimPart
            )
            if not player then
                self:Clear()
                return nil
            end

            if player ~= currentTarget or part ~= currentPart then
                randomLocalPoint, randomDue = nil, 0
                filteredPoint = found
                angularVelocity = math.min(angularVelocity, math.rad((settings.MotionAimSpeed or 240) * 0.35))
            end

            currentTarget, currentCharacter, currentPart = player, character, part
            validated = found
        end

        local rawPoint = chooseRandomGoal(camera, currentPart, currentCharacter, rayParams, validated, now)
        point = smoothPoint(rawPoint, dt)
        steer(camera, point, dt)

        return currentTarget, currentPart, point
    end

    return api
end
