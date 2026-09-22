# Spectra v10 — Creator API

Spectra v10 собран как переносимый клиентский SDK. Runtime не содержит `PlaceId`, `GameId`, имён конкретных RemoteEvent/RemoteFunction, путей до оружия или серверных объектов конкретного плейса.

По умолчанию используются стандартные Roblox API: `Players`, `Character`, `Humanoid`, `Camera`, `Workspace`, `Lighting`. Для нестандартного рига/HP/команд можно передать небольшой `GameAdapter`, не меняя combat/ESP код.

## Запуск

```lua
local spectra = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/spectra-v7-rework/Spectra/loader.lua",
    true
))()
```

Loader задаёт `ModuleRoot`, после чего `main.lua` загружает модули из той же ветки.

Можно заранее задать настройки:

```lua
_G.SpectraOptions = {
    Name = "my client",
    Settings = {
        SilentAim = true,
        AimEnabled = true,
        AutoFire = true,
        AutoFireSource = "Auto",

        MotionAimSpeed = 260,
        MotionAimPart = "Visible",
        MotionRandomization = 15,

        ChamsEnabled = true,
        WorldLightingMode = "Aurora",
        AuroraSky = true,
    },
}
```

## Локальная поставка через ModuleScript

Для продажи/встраивания в чужой плейс не обязательно использовать GitHub или `loadstring`.

`main.lua` принимает `SpectraOptions.ModuleResolver`. Функция получает относительный путь модуля и должна вернуть результат `require`.

Пример схемы:

```lua
local root = game:GetService("ReplicatedStorage"):WaitForChild("Spectra")

_G.SpectraOptions = {
    ModuleResolver = function(path)
        local node = root
        for part in string.gmatch(path:gsub("%.lua$", ""), "[^/]+") do
            node = node:WaitForChild(part)
        end
        return require(node)
    end,
}

local spectra = require(root:WaitForChild("main"))
```

Так можно распространять весь пакет как набор обычных ModuleScript. Remote loader остаётся только удобным development-вариантом.

## Aim

Есть два независимых режима.

### Silent

`SilentAim=true`.

Точка выбирается multipoint raycast. Камера поворачивается только вокруг вызова input и возвращается в том же render step.

Основные настройки:
- `AimPart`: Голова / Корпус / Видимая
- `AimFOV`
- `AimDistance`
- `AimRayOrigin`: Camera / Head / Both
- `VisibilitySampling`: Fast / Balanced / Dense
- `TargetPriority`
- `TargetStickiness`

### Motion Aim

`AimEnabled=true`.

Камера реально ведётся к цели с ограниченной угловой скоростью.

- `MotionAimSpeed`: градусов в секунду
- `MotionActivation`: Hold RMB / Always
- `MotionAimPart`: Head / Torso / Visible / Random
- `MotionRandomization`: величина смещения к случайной видимой точке части тела
- `MotionRandomRefreshMS`: как часто выбирать новую точку
- `MotionFireTolerance`: максимальная угловая ошибка для автострельбы

## Auto Fire

`AutoFire=true`.

`AutoFireSource`:
- `Auto` — Silent, если он включён; иначе Motion
- `Silent`
- `Motion`

Motion Auto Fire ждёт, пока прицел реально окажется в `MotionFireTolerance`. Silent использует свой acquire/flick pipeline.

Общий input backend:
- `VirtualUser`
- `MouseButton`
- `Creator`

Ни один из них не ищет оружие по пути и не вызывает серверный RemoteEvent.

## InputAdapter

Для собственного клиентского оружия:

```lua
spectra:SetInputAdapter({
    Press = function(context)
        -- ваш локальный primary fire
    end,
    Release = function(context)
        -- ваш локальный release
    end,
})

spectra:Set("FireMethod", "Creator")
```

`context` содержит:
- `Camera`
- `MousePosition`
- `Target`
- `Character`
- `Part`
- `AimPosition`
- `Automatic`

## GameAdapter

Опционален. Если ничего не передавать, используется стандартная Roblox логика.

Можно задать при запуске:

```lua
_G.SpectraOptions.GameAdapter = {
    GetCharacter = function(player)
        return player.Character
    end,

    GetHumanoid = function(character)
        return character:FindFirstChildOfClass("Humanoid")
    end,

    GetRoot = function(character)
        return character:FindFirstChild("HumanoidRootPart")
    end,

    GetHead = function(character)
        return character:FindFirstChild("Head")
    end,

    GetPlayerFromCharacter = function(character)
        return game:GetService("Players"):GetPlayerFromCharacter(character)
    end,

    IsTeammate = function(localPlayer, otherPlayer)
        return localPlayer.Team ~= nil and localPlayer.Team == otherPlayer.Team
    end,

    GetAimParts = function(character, mode)
        -- вернуть массив BasePart
    end,

    GetHealth = function(character)
        -- return currentHealth, maxHealth
    end,
}
```

Или заменить во время работы:

```lua
spectra:SetGameAdapter(myAdapter)
```

Это и есть слой, который place-maker меняет под свой нестандартный framework. Combat, chams, targeting и alive checks остаются общими.

## World / shaders

Все эффекты клиентские и восстанавливаются при unload.

Lighting:
- Game
- Fullbright
- Night
- Sunset
- Aurora

Aurora:
- `AuroraSky`
- `AuroraIntensity`
- `AuroraSpeed`

Color World:
- tint preset
- tint strength
- saturation
- contrast
- brightness

Fog:
- density
- offset
- haze
- glare
- tint

Post processing:
- Bloom
- Blur
- Sun Rays
- Depth of Field

PostEffects создаются на текущей Camera. Fog использует Atmosphere только когда включён; если Atmosphere в игре не было, Spectra удаляет созданный объект после выключения.

## Chams

- `ChamsEnabled`
- `ChamsThroughWalls`
- `ChamsColorMode`: Accent / Health / Team / Rainbow
- fill / outline
- pulse / speed
- rainbow speed

Старый ESP Highlight автоматически уступает новому chams, чтобы два Highlight не конфликтовали.

## API

| Метод | Назначение |
| --- | --- |
| `Set(key, value)` | изменить настройку |
| `GetSettings()` | копия настроек |
| `GetState()` | состояние клиента |
| `SetInputAdapter(adapter)` | заменить способ локального primary input |
| `SetGameAdapter(adapter)` | заменить слой персонажа/HP/команд |
| `OpenMenu(bool)` | открыть/закрыть меню |
| `Unload()` | полный cleanup и восстановление окружения |

Версия API: `10.0.0`.

## Ограничения переносимости

Универсально определить серверное подтверждение попадания, патроны или кастомную оружейную систему невозможно без API самого плейса. Поэтому core Spectra не пытается угадывать RemoteEvent.

Hit log по умолчанию подтверждает попадание через уменьшение `Humanoid.Health`. Place-maker с собственной HP системой может использовать свой GameAdapter/локальный weapon layer.
