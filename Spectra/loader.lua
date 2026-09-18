-- SPECTRA remote loader
-- GitHub repository must be PUBLIC for anonymous raw.githubusercontent.com access.

local MAIN_URL = "https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/main/Spectra/main.lua"

local source = game:HttpGet(MAIN_URL, true)
local chunk, compileError = loadstring(source)

if not chunk then
    error("Spectra loader: compile error: " .. tostring(compileError))
end

return chunk()
