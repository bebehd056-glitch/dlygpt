-- SPECTRA portable player chams.
-- Uses only standard Highlight objects and Character/Humanoid data.

return function(ctx)
    local Players = assert(ctx.Players, "Chams: Players missing")
    local localPlayer = assert(ctx.LocalPlayer, "Chams: LocalPlayer missing")
    local settings = assert(ctx.Settings, "Chams: Settings missing")
    local alive = assert(ctx.Alive, "Chams: Alive missing")
    local adapter = assert(ctx.Adapter, "Chams: Adapter missing")
    local theme = assert(ctx.Theme, "Chams: Theme missing")

    local records = {}
    local stopped = false

    local function colorFor(player, humanoid, now)
        local mode = settings.ChamsColorMode or "Accent"
        if mode == "Team" and player.Team then return player.TeamColor.Color end
        if mode == "Health" and humanoid then
            local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
            return Color3.fromRGB(235, 78, 78):Lerp(Color3.fromRGB(104, 224, 139), ratio)
        end
        if mode == "Rainbow" then
            return Color3.fromHSV((now * (settings.ChamsRainbowSpeed or 0.12)) % 1, 0.72, 1)
        end
        return theme.Accent
    end

    local function remove(player)
        local item = records[player]
        if item then
            if item.Highlight then item.Highlight:Destroy() end
            records[player] = nil
        end
    end

    local api = {}

    function api:Update(now)
        if stopped then return end
        now = now or os.clock()
        local seen = {}

        if settings.ChamsEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer and not (settings.TeamCheck and adapter:IsTeammate(player)) then
                    local character, humanoid = alive:IsAlive(player)
                    if character then
                        seen[player] = true
                        local item = records[player]
                        if not item or item.Character ~= character then
                            remove(player)
                            local highlight = Instance.new("Highlight")
                            highlight.Name = "SpectraChams"
                            highlight.Adornee = character
                            highlight.Parent = character
                            item = {Character = character, Highlight = highlight}
                            records[player] = item
                        end

                        local highlight = item.Highlight
                        local color = colorFor(player, humanoid, now)
                        local fill = math.clamp((settings.ChamsFill or 36) / 100, 0, 1)
                        if settings.ChamsPulse then
                            fill = fill * (0.55 + 0.45 * (0.5 + 0.5
                                * math.sin(now * math.pi * 2 * (settings.ChamsPulseSpeed or 1.2))))
                        end
                        highlight.DepthMode = settings.ChamsThroughWalls
                            and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                        highlight.FillColor = color
                        highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.26)
                        highlight.FillTransparency = 1 - fill
                        highlight.OutlineTransparency = 1 - math.clamp((settings.ChamsOutline or 88) / 100, 0, 1)
                        highlight.Enabled = true
                    end
                end
            end
        end

        for player in pairs(records) do
            if not seen[player] then remove(player) end
        end
    end

    function api:Stop()
        if stopped then return end
        stopped = true
        for player in pairs(records) do remove(player) end
    end

    return api
end
