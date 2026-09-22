# Spectra modular rework

Rework ветка `spectra-v7-rework`. Проект больше не держит всю логику в одном `main.lua`: живость, multipoint-видимость, targeting, anti-aim, third person, hit telemetry и SKEET-style preset вынесены отдельно.

## Структура

```text
Spectra/
  loader.lua
  main.lua
  core/
    alive.lua
    visibility.lua
  combat/
    targeting.lua
    antiaim.lua
  camera/
    thirdperson.lua
  visuals/
    telemetry.lua
  ui/
    skeet.lua
  tests/
```

`main.lua` остаётся координатором старого ESP/render-кода и модулей. Loader задаёт общий ModuleRoot, поэтому все файлы берутся из одной ветки.

## Что изменено

### Aim / silent

- Target теперь удерживается, пока остаётся живым, в FOV и видимым. Пересортировка каждые 50 мс больше не переключает валидную цель туда-сюда.
- Silent меняет `Camera.CFrame` только вокруг вызова ввода и восстанавливает его в том же render step. Камера больше не должна оставаться дёрнутой на цели во время hold.
- Ray origin: `Camera`, `Head` или `Both`. По умолчанию `Camera`.
- Старое обязательное условие «луч от камеры И луч от головы одновременно» удалено. Именно оно давало лишние миссы через щели/заборы.
- Multipoint sampling: Fast / Balanced / Dense.
- Для режима `Видимая` сканируются не только центр головы/торса, но и поверхности головы, торса, рук и ног.
- Auto Fire всё ещё требует валидную живую цель и повторную проверку перед вводом.

### Живость / трупы

Все подсистемы используют один `core/alive.lua`.

Переключаемые проверки в CONFIG:
- Health > 0
- Humanoid state != Dead
- Character находится в workspace
- существуют Head + HumanoidRootPart
- распространённые Dead / IsDead / Eliminated / Killed / Alive=false / Status=dead атрибуты и Value-объекты

ESP вызывает общий live predicate каждый кадр, а combat — при выборе и при каждом подтверждении текущей цели. Death latch сохраняется до нового Character.

### Anti-aim / third person

ANTI-AIM:
- Back / Jitter / Spin
- yaw offset, jitter range/period, spin speed
- при остановке восстанавливается AutoRotate, но Root больше не snap-ается назад на сохранённый старый yaw

MISC:
- Third person
- Distance
- Shoulder offset

### Visual feedback

EFFECTS:
- Bullet tracers
- Hit marker
- Hit logs
- Hit flash shader через локальный Highlight
- настраиваемое время tracer/hitlog

Hit confirmation универсально оценить нельзя, поэтому telemetry связывает выстрел с последующим уменьшением `Humanoid.Health` цели в коротком окне. В плейсах с собственной системой HP для точного hitlog нужен их клиентский адаптер.

### Меню

Интерфейс оставлен в classic gamesense/SKEET-направлении: двойная тёмная рамка, тонкая спектральная полоса сверху, узкая вертикальная панель категорий, две колонки groupbox, Arial, квадратные checkbox, компактные slider/dropdown. Стиль вынесен в `ui/skeet.lua`.

Это не официальный gamesense/SKEET клиент и внешние ассеты/логотипы не копируются.

## Запуск rework-ветки

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/spectra-v7-rework/Spectra/loader.lua", true))()
```

Loader требует среду с `game:HttpGet` и `loadstring`. Модульная версия больше не является одним автономным LocalScript для чистого Roblox Studio.

Insert / RightShift — меню. End — unload. LEGIT aim — удержание RMB при включённой опции.

## Что проверить в самом плейсе

1. Убить игрока и убедиться, что ESP/target marker исчезают сразу, а не через пару секунд.
2. Убить цель прямо во время acquire/shot delay.
3. Смотреть на игрока через узкую щель забора с `Ray origin = Camera` и `Sampling = Dense`.
4. Проверить Camera / Head / Both отдельно.
5. Проверить обычный ЛКМ без цели — он должен проходить как обычный ввод.
6. Проверить silent: экран не должен удерживаться на цели во время HoldMS.
7. Проверить third person после respawn и после unload.
8. Проверить anti-aim -> выстрел -> anti-aim: не должно быть возврата Root на старый yaw.
9. Проверить hitlog/tracer на оружии, где урон отражается через Humanoid.Health.

Вне живого Roblox-плейса нельзя подтвердить конкретную механику выстрела, репликацию anti-aim или кастомную HP-систему конкретной игры.
