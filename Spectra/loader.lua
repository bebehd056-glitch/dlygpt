-- SPECTRA remote loader
-- GitHub repository must be PUBLIC for anonymous raw.githubusercontent.com access.

local MAIN_URL = "https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/main/Spectra/main.lua"

if type(loadstring) ~= "function" then
    error("Spectra loader: loadstring is unavailable; install main.lua as a LocalScript in Studio.")
end
local ok, source = pcall(function() return game:HttpGet(MAIN_URL, true) end)
if not ok then error("Spectra loader: download failed: " .. tostring(source)) end
if type(source) ~= "string" or #source < 100 or source:match("^%s*<") or source:match("^404:") then
    error("Spectra loader: expected Lua source, received an empty/error/HTML response. Check repository access.")
end
local chunk, compileError = loadstring(source, "@Spectra/main.lua")

if not chunk then
    error("Spectra loader: compile error: " .. tostring(compileError))
end

return chunk()
