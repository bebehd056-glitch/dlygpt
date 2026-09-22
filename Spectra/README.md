# Spectra v10 — portable rework

Ветка: `spectra-v7-rework`.

Цель v10 — не код под один сервер, а переносимый клиентский пакет, который можно подключать к разным Roblox FPS/HvH плейсам.

## Архитектура

```text
Spectra/
  loader.lua
  main.lua

  core/
    game_adapter.lua
    alive.lua
    visibility.lua

  combat/
    targeting.lua
    motion_aim.lua
    antiaim.lua

  camera/
    thirdperson.lua

  visuals/
    chams.lua
    telemetry.lua

  world/
    environment.lua

  ui/
    skeet.lua

  tests/
```

Runtime не содержит PlaceId/GameId, имён RemoteEvent конкретной игры или путей до оружия.

## Combat

### Silent Aim
- multipoint visibility
- Camera / Head / Both ray origin
- Fast / Balanced / Dense sampling
- Head / Torso / Visible
- FOV / distance
- target priority
- target retention
- same-render-step camera restore

### Motion Aim
Второй тип aim.

- постоянная регулируемая скорость в градусах/сек
- Hold RMB / Always
- Head / Torso / Visible / Random
- randomization видимой точки
- random refresh interval
- auto-fire angular tolerance

### Auto Fire
`Auto / Silent / Motion`.

Auto сам использует Silent, если он включён, иначе Motion. Motion ждёт, пока прицел физически дойдёт до цели.

### Anti-aim
Back / Jitter / Spin. При выключении не snap-ает Root назад на старый yaw.

## Alive / corpse checks

Общий live predicate используется ESP, chams, targeting и shot validation.

Проверки:
- HP > 0
- Humanoid Dead state
- workspace ancestry
- Head + Root
- Dead / IsDead / Eliminated / Killed / Alive=false / State / Status / LifeState
- death latch до нового Character

## Visuals

ESP:
- boxes
- health
- names
- distance
- skeleton
- tracers
- offscreen arrows
- radar
- velocity
- look direction

Chams:
- occluded / through walls
- accent / health / team / rainbow
- fill / outline
- pulse

Hit feedback:
- bullet tracers
- hit marker
- hit logs
- hit flash
- death particles

## World / shader stack

Lighting presets:
- Game
- Fullbright
- Night
- Sunset
- Aurora

Procedural Aurora:
- 3D Beam ribbons
- intensity
- animation speed
- без внешнего skybox asset

Color World:
- Aurora / Blue / Purple / Green / Red / Gold / Mono
- tint strength
- saturation
- contrast
- brightness

Atmosphere / Fog:
- density
- offset
- haze
- glare
- color

Post-processing:
- Bloom
- Blur
- Sun Rays
- Depth of Field

Roblox поддерживает Atmosphere для density/haze/color и camera-local post-processing effects, поэтому эти эффекты реализованы стандартными объектами движка. При unload исходный Lighting восстанавливается.

## Portability

`core/game_adapter.lua` даёт необязательные hooks:
- GetCharacter
- GetHumanoid
- GetRoot
- GetHead
- GetPlayerFromCharacter
- GetAimParts
- GetHealth
- IsTeammate

Если плейс стандартный — ничего настраивать не надо.

## Запуск

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/spectra-v7-rework/Spectra/loader.lua",
    true
))()
```

Insert / RightShift — меню.
End — unload.

## Перед merge в main

Проверить в живом плейсе:
1. Silent без видимого camera tug.
2. Motion Aim на 60/120/240 FPS.
3. Motion random body part и random point.
4. Auto Fire: Auto / Silent / Motion.
5. Узкие щели/забор на Dense sampling.
6. Смерть цели в acquire, fire и hold.
7. Third person после respawn.
8. Chams + старый ESP.
9. Aurora + Color World + Fog + Bloom/DOF.
10. Unload должен вернуть Lighting/Atmosphere/Camera.
