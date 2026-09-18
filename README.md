# Spectra

Remote-loadable Spectra build.

## Structure

- `Spectra/main.lua` — current working build.
- `Spectra/loader.lua` — tiny loader that fetches the main build.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/main/Spectra/loader.lua", true))()
```

The repository is currently private. GitHub raw URLs are not anonymously accessible while it remains private. To use the raw loader directly, make the repository public or use a private authenticated host.

Current build: click-only silent aim, 25 ms acquisition, 10 ms pre-fire delay, FOV up to 360 degrees, shared partial-head visibility logic for ESP/aim, and no third-person camera.
