-- SPECTRA third-person camera controller

return function(ctx)
    local player = assert(ctx.LocalPlayer, "ThirdPerson: LocalPlayer missing")
    local settings = assert(ctx.Settings, "ThirdPerson: Settings missing")

    local active = false
    local saved = nil
    local api = {}

    local function humanoid()
        local character = player.Character
        return character and character:FindFirstChildOfClass("Humanoid")
    end

    local function enable()
        if active then return end
        active = true
        local h = humanoid()
        saved = {
            CameraMode = player.CameraMode,
            MinZoom = player.CameraMinZoomDistance,
            MaxZoom = player.CameraMaxZoomDistance,
            CameraOffset = h and h.CameraOffset or Vector3.new(),
        }
    end

    function api:Update()
        if not settings.ThirdPerson then
            if active then self:Stop() end
            return
        end
        enable()
        local distance = math.clamp(settings.ThirdPersonDistance or 8, 2, 24)
        player.CameraMode = Enum.CameraMode.Classic
        player.CameraMinZoomDistance = distance
        player.CameraMaxZoomDistance = distance
        local h = humanoid()
        if h then h.CameraOffset = Vector3.new(settings.ThirdPersonShoulder or 0, 0, 0) end
    end

    function api:Stop()
        if not active then return end
        active = false
        if saved then
            pcall(function()
                player.CameraMode = saved.CameraMode
                player.CameraMinZoomDistance = saved.MinZoom
                player.CameraMaxZoomDistance = saved.MaxZoom
                local h = humanoid()
                if h then h.CameraOffset = saved.CameraOffset end
            end)
        end
        saved = nil
    end

    return api
end
