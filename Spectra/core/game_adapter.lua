-- SPECTRA portable game adapter.
-- No PlaceId, RemoteEvent, weapon path or server name is required.
-- Creators can override only the methods their place needs.

return function(ctx)
    local Players = assert(ctx.Players, "GameAdapter: Players missing")
    local localPlayer = assert(ctx.LocalPlayer, "GameAdapter: LocalPlayer missing")
    local startup = ctx.Startup or {}
    local custom = type(startup.GameAdapter) == "table" and startup.GameAdapter or {}

    local function call(name, ...)
        local fn = custom[name]
        if type(fn) ~= "function" then return nil, false end
        local ok, value, extra = pcall(fn, ...)
        if not ok then
            warn("Spectra GameAdapter." .. name .. ": " .. tostring(value))
            return nil, true
        end
        return value, true, extra
    end

    local api = {}

    function api:GetCharacter(player)
        local value, handled = call("GetCharacter", player)
        if handled then return value end
        return player and player.Character or nil
    end

    function api:GetPlayerFromCharacter(character)
        local value, handled = call("GetPlayerFromCharacter", character)
        if handled then return value end
        return character and Players:GetPlayerFromCharacter(character) or nil
    end

    function api:GetHumanoid(character)
        local value, handled = call("GetHumanoid", character)
        if handled then return value end
        return character and character:FindFirstChildOfClass("Humanoid") or nil
    end

    function api:GetRoot(character)
        local value, handled = call("GetRoot", character)
        if handled then return value end
        return character and character:FindFirstChild("HumanoidRootPart") or nil
    end

    function api:GetHead(character)
        local value, handled = call("GetHead", character)
        if handled then return value end
        return character and character:FindFirstChild("Head") or nil
    end

    function api:IsTeammate(player)
        local value, handled = call("IsTeammate", localPlayer, player)
        if handled then return value == true end
        return player and not localPlayer.Neutral and not player.Neutral
            and localPlayer.Team ~= nil and player.Team == localPlayer.Team
    end

    local function add(list, part)
        if part and part:IsA("BasePart") then list[#list + 1] = part end
    end

    function api:GetAimParts(character, mode)
        local value, handled = call("GetAimParts", character, mode)
        if handled and type(value) == "table" then return value end

        local result = {}
        local head = self:GetHead(character)
        local upper = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
        local lower = character and character:FindFirstChild("LowerTorso")
        local root = self:GetRoot(character)
        local normalized = tostring(mode or "Visible")

        if normalized == "Head" or normalized == "Голова" then
            add(result, head)
            return result
        end
        if normalized == "Torso" or normalized == "Корпус" then
            add(result, upper or lower or root)
            add(result, lower)
            return result
        end

        add(result, head)
        add(result, upper)
        add(result, lower)
        if normalized == "Random" then
            local randomNames = {
                "LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftHand","RightHand",
                "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot",
                "Left Arm","Right Arm","Left Leg","Right Leg",
            }
            for _, name in ipairs(randomNames) do add(result, character and character:FindFirstChild(name)) end
            add(result, root)
            return result
        end

        local names = {
            "LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg",
            "Left Arm","Right Arm","Left Leg","Right Leg",
        }
        for _, name in ipairs(names) do add(result, character and character:FindFirstChild(name)) end
        add(result, root)
        return result
    end

    function api:GetHealth(character)
        local value, handled, maximum = call("GetHealth", character)
        if handled then return value, maximum end
        local humanoid = self:GetHumanoid(character)
        return humanoid and humanoid.Health or nil, humanoid and humanoid.MaxHealth or nil
    end

    function api:GetCustom()
        return custom
    end

    return api
end
