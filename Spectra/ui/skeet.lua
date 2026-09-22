-- SPECTRA SKEET-inspired UI style preset
-- Layout/colors are kept separate from menu behavior so the UI can be reskinned safely.

return {
    Theme = {
        Background = Color3.fromRGB(19, 19, 19),
        Sidebar = Color3.fromRGB(28, 28, 28),
        Hover = Color3.fromRGB(39, 39, 39),
        Line = Color3.fromRGB(48, 48, 48),
        Text = Color3.fromRGB(218, 218, 218),
        Muted = Color3.fromRGB(115, 115, 115),
        Accent = Color3.fromRGB(164, 198, 48),
        Off = Color3.fromRGB(62, 62, 62),
        Visible = Color3.fromRGB(142, 214, 174),
        Hidden = Color3.fromRGB(231, 143, 119),
    },
    Palette = {
        Color3.fromRGB(160, 200, 236),
        Color3.fromRGB(145, 213, 177),
        Color3.fromRGB(233, 151, 143),
        Color3.fromRGB(229, 200, 137),
    },
    Tabs = {"RAGE", "LEGIT", "ANTI-AIM", "VISUALS", "EFFECTS", "MISC", "CONFIG"},
    Layout = {
        Width = 660,
        Height = 540,
        SidebarWidth = 68,
        TopAccentHeight = 2,
        Border = 1,
    },
}
