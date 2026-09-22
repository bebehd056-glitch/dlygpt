"""Static regression checks for the modular Spectra rework.

Run:
    python Spectra/tests/modular_static.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "main.lua").read_text(encoding="utf-8")
loader = (ROOT / "loader.lua").read_text(encoding="utf-8")

required_modules = {
    "core/alive.lua": ["function api:IsAlive", "AliveDeadTags"],
    "core/visibility.lua": ["function api:FindVisiblePoint", "VisibilitySampling"],
    "combat/targeting.lua": ["function api:Find", "AimRayOrigin"],
    "combat/antiaim.lua": ["function api:Update", "AutoRotate"],
    "camera/thirdperson.lua": ["function api:Update", "ThirdPersonDistance"],
    "visuals/telemetry.lua": ["function api:RecordShot", "HitLogs", "BulletTracers"],
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

check('AimRayOrigin = "Camera"' in main, "camera ray origin must be default")
check('VisibilitySampling = "Dense"' in main, "dense multipoint must be default")
check('AliveHealthCheck = true' in main, "alive health toggle missing")
check('AliveStateCheck = true' in main, "alive state toggle missing")
check('AliveDeadTags = true' in main, "dead-tag toggle missing")
check('ThirdPerson = false' in main, "third-person setting missing")
check('BulletTracers = true' in main and 'HitLogs = true' in main, "telemetry defaults missing")

# Regression for the fence/partial-visibility bug: the old implementation required
# both camera and head rays to clear the same point.
check('clear(origin, point, character) and clear(head.Position, point, character)' not in main,
      "old mandatory camera+head double-ray check returned")

# Regression for visible silent-camera tug: input is dispatched between flick and
# immediate restoration in updateShot.
shot_start = main.index('local function updateShot(camera, now)')
shot_end = main.index('local function fireAction(_, state)', shot_start)
shot = main[shot_start:shot_end]
check('local fired, reason = pressInput(camera)' in shot, "shot input dispatch missing")
check('camera.CFrame = shot and shot.Base or camera.CFrame' in shot,
      "same-step camera restore missing")
check('telemetry:RecordShot' in shot, "shot telemetry hook missing")

update_start = main.index('function controller:Update(dt, camera, now)')
update_end = main.index('targetMarker.Visible = false', update_start)
update = main[update_start:update_end]
check('if not currentTarget and now >= candidateDue then' in update,
      "target search should only run after current target is lost")
check('if currentTarget and currentPart then' in update,
      "current target validity lock missing")

check('spectra-v7-rework' in loader, "branch loader does not point to rework branch")
check('_G.SpectraOptions.ModuleRoot = ROOT' in loader, "loader does not propagate module root")

print(f"{checks} modular static checks passed")
