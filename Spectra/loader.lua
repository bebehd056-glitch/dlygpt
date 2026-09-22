-- SPECTRA modular remote loader
-- Rework branch loader; main.lua imports the rest of the project from the same root.

local BRANCH = "spectra-v7-rework"
local ROOT = "https://raw.githubusercontent.com/bebehd056-glitch/dlygpt/" .. BRANCH .. "/Spectra/"
local MAIN_URL = ROOT .. "main.lua"

if type(loadstring) ~= "function" then
    error("Spectra loader: loadstring is unavailable.")
end

_G.SpectraOptions = type(_G.SpectraOptions) == "table" and _G.SpectraOptions or {}
_G.SpectraOptions.ModuleRoot = ROOT

local ok, source = pcall(function()
    return game:HttpGet(MAIN_URL, true)
end)
if not ok then error("Spectra loader: download failed: " .. tostring(source)) end
if type(source) ~= "string" or #source < 100 or source:match("^%s*<") or source:match("^404:") then
    error("Spectra loader: invalid Lua response from GitHub.")
end

local chunk, compileError = loadstring(source, "@Spectra/main.lua")
if not chunk then
    error("Spectra loader: compile error: " .. tostring(compileError))
end
return chunk()
