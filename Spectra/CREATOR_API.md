# Клиентский API Spectra v8

`main.lua` возвращает объект API. Внутри нет загрузки модулей из сети, идентификаторов плейсов, поиска серверных RemoteEvent или привязки наведения к оружию. ESP может читать имя Tool только для подписи предмета.

Базовые требования: клиент Roblox, Players.LocalPlayer, Character с Humanoid и обычными частями R6/R15. Для кастомных ригов или отдельной системы здоровья нужно адаптировать получение персонажа/HP. Нельзя запускать этот клиентский модуль как серверный Script.

## Запуск через loadstring

```lua
_G.SpectraOptions = {
    Name = "my project",
    Settings = {
        SilentAim = true,
        AimEnabled = false,
        AutoFire = false,
        FireMethod = "VirtualUser",
        AimFOV = 360,
        AimWallCheck = true,
    },
}

local spectra = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/spectra-v7-rework/Spectra/main.lua", true
))()

spectra:Set("AimEnabled", true)
spectra:OpenMenu(true)
```

Перед новой независимой загрузкой можно очистить `_G.SpectraOptions = nil`; запущенный экземпляр уже скопировал настройки и обработчики.

## В Roblox Studio

Для простого запуска поместите содержимое main.lua в LocalScript внутри StarterPlayerScripts.
Если нужен возвращаемый API, поместите тот же код в ModuleScript `ReplicatedStorage.Spectra`, затем вызовите из LocalScript:

```lua
local spectra = require(game:GetService("ReplicatedStorage"):WaitForChild("Spectra"))
spectra:Set("AimEnabled", true)
```

ModuleScript, выполняемый через require, кешируется. После Unload тот же require не создаст экземпляр заново; для новой сессии используйте новый запуск клиента или новый экземпляр модуля.

## Методы

| Метод | Результат |
| --- | --- |
| `spectra:Set(key, value)` | `true` либо `false, reason`; числа ограничиваются допустимым диапазоном, неизвестные ключи/типы/варианты отвергаются |
| `spectra:GetSettings()` | Независимая копия текущих настроек |
| `spectra:GetState()` | Таблица `Running`, `Target`, `Status`, `MenuOpen` |
| `spectra:SetInputAdapter(adapter)` | Заменяет пользовательский обработчик, предварительно отменяя активный выстрел; `nil` снимает обработчик |
| `spectra:OpenMenu(boolean)` | Показать/скрыть меню |
| `spectra:Unload()` | Отпустить ввод, вернуть камеру/AutoRotate и удалить интерфейс |

`Version` содержит строку версии. Полный список ключей, вариантов и диапазонов расположен в `defaults`, `settingRanges`, `settingChoices` в начале main.lua. Настройки RAGE/LEGIT частично общие и синхронно отображаются в обеих вкладках.

## Собственный обработчик ввода

Это необязательный способ интеграции для оружия, не принимающего обычный виртуальный ЛКМ. Достаточно передать функции из своего клиентского контроллера; код выбора цели менять не требуется.

Контракт адаптера:

```lua
-- primaryPressed и primaryReleased — функции вашего клиентского контроллера.
local ok, reason = spectra:SetInputAdapter({
    Press = primaryPressed,
    Release = primaryReleased,
})
assert(ok, reason)
spectra:Set("FireMethod", "Creator")
```

Обе функции получают один аргумент `context` (обычный вызов функции, без self):

- `Camera` — камера, уже направленная в точку цели.
- `MousePosition` — положение курсора при начале нажатия.
- `Target`, `Character`, `Part` — выбранный игрок, модель и часть тела.
- `AimPosition` — актуальная точка наведения перед вызовом Press.
- `Automatic` — инициирован ли выстрел автоматикой.

Функции должны выполняться синхронно, без task.wait/ожидания событий. `Press` может вернуть `false, reason` при невозможности выстрела. Ошибки перехватываются и отображаются в статусе. `Release` должен быть безопасен даже после частично выполненного Press.

Press/Release фиксируются на время нажатия: смена метода в меню не направит отпускание в другой обработчик. После смерти, закрытия окна игры, потери цели или выгрузки выполняется освобождение ввода. При ошибке функция нажатия не повторяется другим методом автоматически, чтобы не дублировать выстрел.

Ограничение: успешный вызов означает отправленный ввод. Подтверждение сервером, попадание, патроны и темп оружия остаются частью реализации вашего плейса.
