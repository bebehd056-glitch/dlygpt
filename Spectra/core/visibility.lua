-- SPECTRA multipoint visibility
-- Samples actual hitbox surfaces instead of a single center ray.

return function(ctx)
    local settings = assert(ctx.Settings, "Visibility: Settings missing")
    local World = ctx.Workspace or workspace

    local function mode()
        return settings.VisibilitySampling or "Dense"
    end

    local function samplePart(part)
        if not part or not part:IsA("BasePart") then return {} end
        local cf, size = part.CFrame, part.Size
        local x = math.max(0.03, size.X * 0.46)
        local y = math.max(0.03, size.Y * 0.46)
        local z = math.max(0.03, size.Z * 0.46)
        local points = {
            part.Position,
            cf:PointToWorldSpace(Vector3.new(0, y, 0)),
            cf:PointToWorldSpace(Vector3.new(0, -y, 0)),
            cf:PointToWorldSpace(Vector3.new(-x, 0, 0)),
            cf:PointToWorldSpace(Vector3.new(x, 0, 0)),
            cf:PointToWorldSpace(Vector3.new(0, 0, -z)),
            cf:PointToWorldSpace(Vector3.new(0, 0, z)),
        }
        if mode() == "Fast" then return {points[1], points[2], points[4], points[5]} end
        if mode() == "Dense" then
            local signs = {-1, 1}
            for _, sx in ipairs(signs) do
                for _, sy in ipairs(signs) do
                    for _, sz in ipairs(signs) do
                        points[#points + 1] = cf:PointToWorldSpace(Vector3.new(x * sx, y * sy, z * sz))
                    end
                end
            end
            points[#points + 1] = cf:PointToWorldSpace(Vector3.new(x, y, 0))
            points[#points + 1] = cf:PointToWorldSpace(Vector3.new(-x, y, 0))
            points[#points + 1] = cf:PointToWorldSpace(Vector3.new(0, y, z))
            points[#points + 1] = cf:PointToWorldSpace(Vector3.new(0, y, -z))
        end
        return points
    end

    local function clear(origin, point, character, rayParams)
        local delta = point - origin
        if delta.Magnitude < 0.01 then return true end
        local result = World:Raycast(origin, delta, rayParams)
        return not result or (result.Instance and result.Instance:IsDescendantOf(character))
    end

    local api = {}

    function api:SamplePart(part)
        return samplePart(part)
    end

    function api:Clear(origin, point, character, rayParams)
        return clear(origin, point, character, rayParams)
    end

    function api:FindVisiblePoint(origin, part, character, rayParams)
        if not part or not part:IsA("BasePart") or not part:IsDescendantOf(character) then return nil end
        for _, point in ipairs(samplePart(part)) do
            if clear(origin, point, character, rayParams) then return point end
        end
        return nil
    end

    function api:AnyVisible(origin, character, parts, rayParams)
        for _, part in ipairs(parts) do
            local point = self:FindVisiblePoint(origin, part, character, rayParams)
            if point then return part, point end
        end
        return nil
    end

    return api
end
