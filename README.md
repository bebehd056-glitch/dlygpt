# Spectra

Spectra v7: camera silent, aim на ПКМ, ESP с проверкой здоровья, Auto Fire и повороты персонажа.

- `Spectra/main.lua` — клиентская реализация и меню.
- `Spectra/loader.lua` — удалённый загрузчик с проверкой ошибок ответа.
- [Настройки, установка и совместимость оружия](Spectra/README.md).
- `python Spectra/tests/regression.py` — локальные проверки извлечённой логики жизненного цикла, камеры и ввода; требуют Lua или texlua.

Загрузчик основной ветки:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/main/Spectra/loader.lua", true))()
```

При проверке изменений в отдельной ветке запускайте `Spectra/main.lua` именно из этой ветки: `loader.lua` загружает основную `main`.
В Studio используйте `main.lua` как LocalScript в StarterPlayerScripts.
