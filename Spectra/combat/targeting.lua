-- SPECTRA target selection + multipoint scan

return function(ctx)
    local Players = assert(ctx.Players, "Targeting: Players missing")
    local localPlayer = assert(ctx.LocalPlayer, "Targeting: LocalPlayer missing")
    local settings = assert(ctx.Settings, "Targeting: Settings missing")
    local alive = assert(ctx.Alive, "Targeting: Alive missing")
    local visibility = assert(ctx.Visibility, "Targeting: Visibility missing")
    local isTeammate = assert(ctx.IsTeammate, "Targeting: IsTeammate missing")
    local getLocalHead = assert(ctx.GetLocalHead, "Targeting: GetLocalHead missing")

    local function withinFOV(forward, delta)
        local magnitude = delta.Magnitude
        if magnitude < 0.05 then return false end
        if settings.AimFOV >= 359.5 then return true end
        return forward:Dot(delta / magnitude) >= math.cos(math.rad(settings.AimFOV * 0.5))
    end

    local function addPart(list, part)
        if part and part:IsA("BasePart") then list[#list + 1] = part end
    end

    local function parts(character)
        local result = {}
        local head = character:FindFirstChild("Head")
        local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        local lower = character:FindFirstChild("LowerTorso")
        local root = character:FindFirstChild("HumanoidRootPart")

        if settings.AimPart == "Голова" then
            addPart(result, head)
            return result
        elseif settings.AimPart == "Корпус" then
            addPart(result, upper or lower or root)
            addPart(result, lower)
            return result
        end

        addPart(result, head)
        addPart(result, upper)
        addPart(result, lower)
        local limbNames = {
            "LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftHand","RightHand",
            "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot",
            "Left Arm","Right Arm","Left Leg","Right Leg",
        }
        for _, name in ipairs(limbNames) do addPart(result, character:FindFirstChild(name)) end
        addPart(result, root)
        return result
    end

    local function score(player, humanoid, part, origin, forward, currentTarget)
        local delta = part.Position - origin
        local distance = delta.Magnitude
        if distance < 0.05 or distance > settings.AimDistance or not withinFOV(forward, delta) then
            return nil
        end
        local value
        if settings.TargetPriority == "Ближайший" then
            value = distance / math.max(settings.AimDistance, 1)
        elseif settings.TargetPriority == "Мало HP" then
            value = humanoid.Health / math.max(humanoid.MaxHealth, 1)
        else
            value = 1 - math.clamp(forward:Dot(delta / distance), -1, 1)
        end
        if player == currentTarget then
            value = value * (1 - math.clamp(settings.TargetStickiness or 0, 0, 80) / 100)
        end
        return value
    end

    local function pointVisible(cameraOrigin, pointPart, character, rayParams, requireVisibility)
        if not requireVisibility then return pointPart.Position end
        local originMode = settings.AimRayOrigin or "Camera"
        local cameraPoint
        if originMode == "Camera" or originMode == "Both" then
            cameraPoint = visibility:FindVisiblePoint(cameraOrigin, pointPart, character, rayParams)
            if not cameraPoint then return nil end
        end
        if originMode == "Head" or originMode == "Both" then
            local ownHead = getLocalHead()
            if not ownHead then return nil end
            local headPoint = visibility:FindVisiblePoint(ownHead.Position, pointPart, character, rayParams)
            if not headPoint then return nil end
            if not cameraPoint then cameraPoint = headPoint end
        end
        return cameraPoint
    end

    local api = {}

    function api:WithinFOV(forward, delta)
        return withinFOV(forward, delta)
    end

    function api:Find(camera, rayParams, currentTarget, forceVisibility)
        local origin, forward = camera.CFrame.Position, camera.CFrame.LookVector
        local candidates = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer and not (settings.AimTeamCheck and isTeammate(player)) then
                local character, humanoid = alive:IsAlive(player)
                if character then
                    local candidateParts = parts(character)
                    local best = math.huge
                    for _, part in ipairs(candidateParts) do
                        local value = score(player, humanoid, part, origin, forward, currentTarget)
                        if value and value < best then best = value end
                    end
                    if best < math.huge then
                        candidates[#candidates + 1] = {
                            Player = player, Character = character, Humanoid = humanoid,
                            Parts = candidateParts, Score = best,
                        }
                    end
                end
            end
        end

        table.sort(candidates, function(a, b)
            if a.Score == b.Score then return a.Player.UserId < b.Player.UserId end
            return a.Score < b.Score
        end)

        local requireVisibility = forceVisibility or settings.AimWallCheck
        for _, candidate in ipairs(candidates) do
            for _, part in ipairs(candidate.Parts) do
                local delta = part.Position - origin
                if delta.Magnitude <= settings.AimDistance and withinFOV(forward, delta) then
                    local point = pointVisible(origin, part, candidate.Character, rayParams, requireVisibility)
                    if point and withinFOV(forward, point - origin)
                        and (point - origin).Magnitude <= settings.AimDistance then
                        return candidate.Player, candidate.Character, part, point
                    end
                end
            end
        end
        return nil
    end

    function api:ValidatePoint(camera, rayParams, player, expectedCharacter, part, forceVisibility)
        local character = alive:IsAlive(player, expectedCharacter)
        if not character or not part or not part:IsDescendantOf(character) then return nil end
        local delta = part.Position - camera.CFrame.Position
        if delta.Magnitude > settings.AimDistance or not withinFOV(camera.CFrame.LookVector, delta) then
            return nil
        end
        return pointVisible(camera.CFrame.Position, part, character, rayParams,
            forceVisibility or settings.AimWallCheck)
    end

    return api
end
