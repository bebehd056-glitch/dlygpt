# Spectra

Spectra v8: меню в классическом стиле Skeet/gamesense, camera silent, aim на ПКМ, ESP с проверкой здоровья, Auto Fire и повороты персонажа.

- `Spectra/main.lua` — клиентская реализация и меню.
- `Spectra/loader.lua` — удалённый загрузчик с проверкой ошибок ответа.
- [Настройки, установка и совместимость оружия](Spectra/README.md).
- [Переносимый клиентский API для создателей плейсов](Spectra/CREATOR_API.md).
- `python Spectra/tests/regression.py` — локальные проверки извлечённой логики жизненного цикла, камеры и ввода; требуют Lua или texlua.
- `python Spectra/tests/input_adapters.py` — проверки независимых способов ввода.
- `python Spectra/tests/ui_smoke.py` — проверки построения меню, вкладок, настроек, списков и клиентского API с тестовыми заменами Roblox-объектов.

Загрузчик основной ветки:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/main/Spectra/loader.lua", true))()
```

При проверке изменений в отдельной ветке запускайте `Spectra/main.lua` именно из этой ветки: `loader.lua` загружает основную `main`.
В Studio используйте `main.lua` как LocalScript в StarterPlayerScripts.

Текущая версия в ветке разработки:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/spectra-v7-rework/Spectra/main.lua", true))()
```
