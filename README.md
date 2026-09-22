# Spectra

Spectra v10 — переносимый Roblox client SDK для FPS/HvH плейсов: Silent Aim, Motion Aim, Auto Fire routing, ESP/chams, third person, anti-aim и клиентский world/shader stack.

Главный принцип v10: runtime не привязан к конкретному серверу. В нём нет PlaceId/GameId, имён оружейных RemoteEvent или жёстких путей до объектов конкретной игры.

- `Spectra/main.lua` — координатор UI/render/combat.
- `Spectra/loader.lua` — модульный remote loader.
- `Spectra/core/game_adapter.lua` — необязательный слой для нестандартного Character/HP/teams.
- `Spectra/combat/motion_aim.lua` — второй вид aim с регулируемой угловой скоростью и randomization.
- `Spectra/world/environment.lua` — Aurora / Color World / Fog / Bloom / Blur / Sun Rays / DOF.
- `Spectra/visuals/chams.lua` — portable Highlight chams.
- [Полное описание v10](Spectra/README.md).
- [API для place-makers](Spectra/CREATOR_API.md).
- `python Spectra/tests/modular_static.py` — portability/structure regression checks.

Основная ветка пока оставлена на стабильной версии.

Текущая v10 development-ветка:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/spectra-v7-rework/Spectra/loader.lua",
    true
))()
```

После проверки v10 в живом Roblox-плейсе ветку можно сливать в `main`.
