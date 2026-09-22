"""Static regression checks for Spectra portable v10.

Run:
    python Spectra/tests/modular_static.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "main.lua").read_text(encoding="utf-8")
loader = (ROOT / "loader.lua").read_text(encoding="utf-8")

required_modules = {
    "core/game_adapter.lua": ["function api:GetCharacter", "function api:SetCustom", "GetAimParts"],
    "core/alive.lua": ["function api:IsAlive", "AliveDeadTags", "Adapter"],
    "core/visibility.lua": ["function api:FindVisiblePoint", "VisibilitySampling"],
    "combat/targeting.lua": ["function api:Find", "partMode", "adapter:GetAimParts"],
    "combat/motion_aim.lua": ["MotionAimSpeed", "MotionRandomization", "function api:IsAligned"],
    "combat/antiaim.lua": ["function api:Update", "AutoRotate"],
    "camera/thirdperson.lua": ["function api:Update", "ThirdPersonDistance"],
    "visuals/chams.lua": ["SpectraChams", "ChamsThroughWalls", "ChamsColorMode"],
    "visuals/telemetry.lua": ["function api:RecordShot", "HitLogs", "BulletTracers"],
    "world/environment.lua": ["AuroraRibbon", "ColorCorrectionEffect", "DepthOfFieldEffect", "Atmosphere"],
    "ui/skeet.lua": ["Tabs =", "Theme ="],
}

checks = 0

def check(value, message):
    global checks
    assert value, message
    checks += 1

for path, needles in required_modules.items():
    file = ROOT / path
    check(file.exists(), f"missing module: {path}")
    text = file.read_text(encoding="utf-8")
    for needle in needles:
        check(needle in text, f"{path} missing marker: {needle}")

for module in required_modules:
    check(f'importModule("{module}")' in main, f"main does not import {module}")

check('Version="10.0.0"' in main, "creator API version is not v10")
check('AimRayOrigin = "Camera"' in main, "camera ray origin must be default")
check('VisibilitySampling = "Dense"' in main, "dense multipoint must be default")
check('AutoFireSource = "Auto"' in main, "automatic fire routing default missing")
check('MotionAimSpeed = 240' in main, "motion aim speed default missing")
check('MotionAimPart = "Visible"' in main, "motion aim body-selection default missing")
check('MotionRandomization = 18' in main, "motion randomization default missing")
check('MotionFireTolerance = 1.25' in main, "motion auto-fire tolerance missing")

check('ChamsEnabled = false' in main, "chams default missing")
check('WorldLightingMode = "Game"' in main, "world mode default missing")
check('AuroraSky = false' in main, "aurora default missing")
check('ColorWorld = false' in main, "color-world default missing")
check('WorldFog = false' in main, "fog default missing")
check('WorldBloom = false' in main, "bloom default missing")
check('WorldDOF = false' in main, "DOF default missing")

check('AliveHealthCheck = true' in main, "alive health toggle missing")
check('AliveStateCheck = true' in main, "alive state toggle missing")
check('AliveDeadTags = true' in main, "dead-tag toggle missing")
check('ThirdPerson = false' in main, "third-person setting missing")
check('BulletTracers = true' in main and 'HitLogs = true' in main, "telemetry defaults missing")

# Portability guard: production code must not target one game/server.
portable_sources = [main]
for path in required_modules:
    portable_sources.append((ROOT / path).read_text(encoding="utf-8"))
portable = "\n".join(portable_sources)
for forbidden in ("PlaceId", "GameId", "RemoteEvent", "RemoteFunction", "ReplicatedStorage:WaitForChild"):
    check(forbidden not in portable, f"server-specific marker leaked into runtime: {forbidden}")

# Regression for the fence/partial-visibility bug.
check('clear(origin, point, character) and clear(head.Position, point, character)' not in main,
      "old mandatory camera+head double-ray check returned")

shot_start = main.index('local function updateShot(camera, now)')
shot_end = main.index('local function fireAction(_, state)', shot_start)
shot = main[shot_start:shot_end]
check('local fired, reason = pressInput(camera)' in shot, "shot input dispatch missing")
check('camera.CFrame = shot and shot.Base or camera.CFrame' in shot,
      "same-step silent camera restore missing")
check('shot.NoFlick' in shot, "motion auto-fire path missing")
check('telemetry:RecordShot' in shot, "shot telemetry hook missing")

update_start = main.index('function controller:Update(dt, camera, now)')
update_end = main.index('targetMarker.Visible = false', update_start)
update = main[update_start:update_end]
check('resolveAutoSource()' in update, "auto-fire source routing missing")
check('motionAim:Update' in update, "motion aim update missing")
check('beginMotionAuto' in update, "motion auto-fire trigger missing")
check('if not currentTarget and now >= candidateDue then' in update,
      "silent target lock/re-scan guard missing")

check('environment:Update(camera, now)' in main, "environment update not wired")
check('environment:Stop()' in main, "environment cleanup not wired")
check('chams:Update(now)' in main and 'chams:Stop()' in main, "chams lifecycle incomplete")
check('function api:SetGameAdapter(adapter)' in main, "runtime GameAdapter API missing")

check('spectra-v7-rework' in loader, "branch loader does not point to rework branch")
check('_G.SpectraOptions.ModuleRoot = ROOT' in loader, "loader does not propagate module root")

print(f"{checks} portable v10 static checks passed")
