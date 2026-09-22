-- SPECTRA alive/death predicate
-- Centralized so ESP, targeting and shot validation cannot disagree.

return function(ctx)
    local Players = assert(ctx.Players, "Alive: Players missing")
    local settings = assert(ctx.Settings, "Alive: Settings missing")
    local deadCharacters = assert(ctx.DeadCharacters, "Alive: DeadCharacters missing")
    local adapter = ctx.Adapter

    local deadAttributes = {"Dead", "IsDead", "Eliminated", "Killed", "Death", "Died"}
    local aliveAttributes = {"Alive", "IsAlive"}
    local deadStates = {dead=true, died=true, killed=true, eliminated=true, spectating=true}

    -- Lightweight soft corpse/ragdoll filter.
    -- It never writes to DeadCharacters: temporary knockdowns can recover normally.
    local postureCache = setmetatable({}, {__mode = "k"})
    local postureStates = {
        [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.Physics] = true,
        [Enum.HumanoidStateType.FallingDown] = true,
    }

    local function postureLooksDead(character, humanoid, root, head)
        if settings.AliveRagdollCheck == false or not root or not head then
            postureCache[character] = nil
            return false
        end

        local now = os.clock()
        local record = postureCache[character]
        if not record then
            record = {Next = 0, SuspectSince = nil, Suppressed = false}
            postureCache[character] = record
        elseif now < record.Next then
            return record.Suppressed
        end
        record.Next = now + 0.12 -- max ~8 cheap posture evaluations/sec per character

        local signals = 0
        local ok, state = pcall(humanoid.GetState, humanoid)
        if ok and postureStates[state] then signals = signals + 1 end
        if humanoid.PlatformStand == true then signals = signals + 1 end

        -- Standing/running characters normally have Root.UpVector.Y close to 1.
        if math.abs(root.CFrame.UpVector.Y) < 0.52 then signals = signals + 1 end

        -- On a horizontal ragdoll the head and root are usually near the same height.
        if math.abs(head.Position.Y - root.Position.Y) < 1.25 then signals = signals + 1 end

        if signals >= 3 then
            record.SuspectSince = record.SuspectSince or now
            local confirm = math.clamp(settings.AliveRagdollConfirmMS or 220, 80, 600) / 1000
            record.Suppressed = now - record.SuspectSince >= confirm
        else
            record.SuspectSince = nil
            record.Suppressed = false
        end
        return record.Suppressed
    end

    local function hasDeadTag(character, humanoid)
        if settings.AliveDeadTags == false then return false end

        for _, name in ipairs(deadAttributes) do
            if character:GetAttribute(name) == true or humanoid:GetAttribute(name) == true then
                return true
            end
            local value = character:FindFirstChild(name) or humanoid:FindFirstChild(name)
            if value and value:IsA("BoolValue") and value.Value then return true end
        end
        for _, name in ipairs(aliveAttributes) do
            if character:GetAttribute(name) == false or humanoid:GetAttribute(name) == false then
                return true
            end
            local value = character:FindFirstChild(name) or humanoid:FindFirstChild(name)
            if value and value:IsA("BoolValue") and value.Value == false then return true end
        end

        for _, name in ipairs({"State", "Status", "LifeState"}) do
            local attr = character:GetAttribute(name)
            if type(attr) == "string" and deadStates[string.lower(attr)] then return true end
            local value = character:FindFirstChild(name)
            if value and value:IsA("StringValue") and deadStates[string.lower(value.Value)] then return true end
        end
        return false
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

        if settings.AliveHealthCheck ~= false and humanoid.Health <= 0 then
            return nil
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
        if character then deadCharacters[character] = true end
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

    return api
end
