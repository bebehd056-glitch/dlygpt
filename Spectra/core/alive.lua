-- SPECTRA alive/death predicate
-- Centralized so ESP, targeting and shot validation cannot disagree.

return function(ctx)
    local Players = assert(ctx.Players, "Alive: Players missing")
    local settings = assert(ctx.Settings, "Alive: Settings missing")
    local deadCharacters = assert(ctx.DeadCharacters, "Alive: DeadCharacters missing")

    local deadAttributes = {"Dead", "IsDead", "Eliminated", "Killed", "Death", "Died"}
    local aliveAttributes = {"Alive", "IsAlive"}
    local deadStates = {dead=true, died=true, killed=true, eliminated=true, spectating=true}

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
        local character = player.Character
        if not character or (expected and character ~= expected) or deadCharacters[character] then
            return nil
        end

        if settings.AliveAncestryCheck ~= false and not character:IsDescendantOf(workspace) then
            return nil
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end

        if settings.AliveHealthCheck ~= false and humanoid.Health <= 0 then
            return nil
        end

        if settings.AliveStateCheck ~= false then
            local ok, state = pcall(humanoid.GetState, humanoid)
            if ok and state == Enum.HumanoidStateType.Dead then return nil end
        end

        if settings.AliveRootCheck ~= false then
            local root = character:FindFirstChild("HumanoidRootPart")
            local head = character:FindFirstChild("Head")
            if not root or not root:IsA("BasePart") or not root:IsDescendantOf(character)
                or not head or not head:IsA("BasePart") or not head:IsDescendantOf(character) then
                return nil
            end
        end

        if hasDeadTag(character, humanoid) then return nil end
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
        if character then deadCharacters[character] = nil end
    end

    function api:IsLatchedDead(character)
        return character and deadCharacters[character] == true or false
    end

    return api
end
