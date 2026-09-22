-- SPECTRA alive/death predicate v2.
-- One source of truth for ESP, targeting, shots and chams.
-- Hard death signals are immediate; corpse posture is a lightweight recoverable fallback.

return function(ctx)
    local Players = assert(ctx.Players, "Alive: Players missing")
    local settings = assert(ctx.Settings, "Alive: Settings missing")
    local deadCharacters = assert(ctx.DeadCharacters, "Alive: DeadCharacters missing")
    local adapter = ctx.Adapter

    local deadAttributes = {
        "Dead", "IsDead", "Eliminated", "Killed", "Death", "Died",
    }
    local aliveAttributes = {"Alive", "IsAlive"}
    local deadStates = {
        dead=true, died=true, killed=true, eliminated=true, spectating=true,
        respawning=true,
    }
    local postureStates = {
        [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.Physics] = true,
        [Enum.HumanoidStateType.FallingDown] = true,
    }

    -- Weak-key cache: no permanent references to old ragdoll Characters.
    local postureCache = setmetatable({}, {__mode = "k"})

    local function boolValueDead(container, name, expected)
        if not container then return false end
        local value = container:FindFirstChild(name)
        return value and value:IsA("BoolValue") and value.Value == expected
    end

    local function hasDeadTag(character, humanoid)
        if settings.AliveDeadTags == false then return false end

        for _, name in ipairs(deadAttributes) do
            if character:GetAttribute(name) == true or humanoid:GetAttribute(name) == true then return true end
            if boolValueDead(character, name, true) or boolValueDead(humanoid, name, true) then return true end
        end

        for _, name in ipairs(aliveAttributes) do
            if character:GetAttribute(name) == false or humanoid:GetAttribute(name) == false then return true end
            if boolValueDead(character, name, false) or boolValueDead(humanoid, name, false) then return true end
        end

        for _, name in ipairs({"State", "Status", "LifeState"}) do
            local attr = character:GetAttribute(name)
            if type(attr) == "string" and deadStates[string.lower(attr)] then return true end
            local value = character:FindFirstChild(name)
            if value and value:IsA("StringValue") and deadStates[string.lower(value.Value)] then return true end
        end

        return false
    end

    local function velocityMagnitude(part, property)
        local ok, value = pcall(function() return part[property] end)
        return ok and typeof(value) == "Vector3" and value.Magnitude or math.huge
    end

    local function postureLooksDead(character, humanoid, root, head)
        if settings.AliveRagdollCheck == false or not root or not head then
            postureCache[character] = nil
            return false
        end

        local now = os.clock()
        local record = postureCache[character]
        if not record then
            record = {
                Next = 0,
                SuspectSince = nil,
                RecoverSince = nil,
                Suppressed = false,
            }
            postureCache[character] = record
        elseif now < record.Next then
            return record.Suppressed
        end
        record.Next = now + 0.10 -- at most 10 cheap checks/sec per Character

        local okState, state = pcall(humanoid.GetState, humanoid)
        local ragdollState = okState and postureStates[state] == true
        local platform = humanoid.PlatformStand == true

        local upY = math.abs(root.CFrame.UpVector.Y)
        local headDeltaY = math.abs(head.Position.Y - root.Position.Y)
        local tilted = upY < 0.58
        local flatBody = headDeltaY < 1.40

        local linearSpeed = velocityMagnitude(root, "AssemblyLinearVelocity")
        local angularSpeed = velocityMagnitude(root, "AssemblyAngularVelocity")
        local settled = linearSpeed < 2.25 and angularSpeed < 4.5
        local idle = humanoid.MoveDirection.Magnitude < 0.08

        -- Two paths:
        -- 1) engine explicitly says ragdoll/physics + body is down;
        -- 2) custom place leaves Humanoid "alive", but the body is horizontal and settled.
        local engineCorpse = (ragdollState or platform) and (tilted or flatBody)
        local passiveCorpse = tilted and flatBody and settled and idle
        local suspect = engineCorpse or passiveCorpse

        if suspect then
            record.RecoverSince = nil
            record.SuspectSince = record.SuspectSince or now
            local confirm = math.clamp(settings.AliveRagdollConfirmMS or 260, 80, 900) / 1000
            if now - record.SuspectSince >= confirm then record.Suppressed = true end
        else
            record.SuspectSince = nil

            if record.Suppressed then
                -- Hysteresis: a corpse bouncing for one frame must not reappear in ESP.
                local upright = upY > 0.72 and headDeltaY > 1.45
                local controlled = not ragdollState and not platform
                    and (humanoid.MoveDirection.Magnitude > 0.08 or linearSpeed > 3.5)

                if upright or controlled then
                    record.RecoverSince = record.RecoverSince or now
                    local release = math.clamp(settings.AliveRagdollReleaseMS or 420, 120, 1200) / 1000
                    if now - record.RecoverSince >= release then
                        record.Suppressed = false
                        record.RecoverSince = nil
                    end
                else
                    record.RecoverSince = nil
                end
            end
        end

        return record.Suppressed
    end

    local function isAlive(player, expected)
        if not player or player.Parent ~= Players then return nil end

        local character = adapter and adapter:GetCharacter(player) or player.Character
        if not character or (expected and character ~= expected) or deadCharacters[character] then
            return nil
        end

        if settings.AliveAncestryCheck ~= false and not character:IsDescendantOf(workspace) then
            return nil
        end

        local humanoid = adapter and adapter:GetHumanoid(character) or character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end

        if settings.AliveHealthCheck ~= false then
            local health
            if adapter and adapter.GetHealth then health = select(1, adapter:GetHealth(character)) end
            if health == nil then health = humanoid.Health end
            if health <= 0 then return nil end
        end

        if settings.AliveStateCheck ~= false then
            local ok, state = pcall(humanoid.GetState, humanoid)
            if ok and state == Enum.HumanoidStateType.Dead then return nil end
        end

        local root = adapter and adapter:GetRoot(character) or character:FindFirstChild("HumanoidRootPart")
        local head = adapter and adapter:GetHead(character) or character:FindFirstChild("Head")

        if settings.AliveRootCheck ~= false then
            if not root or not root:IsA("BasePart") or not root:IsDescendantOf(character)
                or not head or not head:IsA("BasePart") or not head:IsDescendantOf(character) then
                return nil
            end
        end

        if hasDeadTag(character, humanoid) then return nil end

        if root and head and root:IsA("BasePart") and head:IsA("BasePart")
            and postureLooksDead(character, humanoid, root, head) then
            return nil
        end

        return character, humanoid
    end

    local api = {}

    function api:IsAlive(player, expected)
        return isAlive(player, expected)
    end

    function api:MarkDead(character)
        if character then
            deadCharacters[character] = true
            postureCache[character] = nil
        end
    end

    function api:Clear(character)
        if character then
            deadCharacters[character] = nil
            postureCache[character] = nil
        end
    end

    function api:IsLatchedDead(character)
        return character and deadCharacters[character] == true or false
    end

    function api:IsSoftCorpse(character)
        local record = character and postureCache[character]
        return record and record.Suppressed == true or false
    end

    return api
end
