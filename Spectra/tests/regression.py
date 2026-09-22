"""Run extracted production Lua logic without Roblox: python Spectra/tests/regression.py."""
from pathlib import Path
import shutil
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[1] / 'main.lua').read_text()
def section(start, end):
    return source[source.index(start):source.index(end, source.index(start))]

lua = r'''
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local Players, workspace = {}, {}
local Enum = {HumanoidStateType={Dead='Dead'}, UserInputState={Begin='Begin', End='End', Cancel='Cancel'},
    ContextActionResult={Pass='Pass', Sink='Sink'}}
local deadCharacters = setmetatable({}, {__mode='k'})
local function playerWithHealth(health)
    local humanoid = {Health=health, State='Running'}
    function humanoid:GetState() return self.State end
    local character = {InWorkspace=true}
    function character:IsDescendantOf(parent) return parent == workspace and self.InWorkspace end
    function character:FindFirstChildOfClass() return humanoid end
    return {Character=character, Parent=Players}, humanoid, character
end
'''
lua += section('local function liveCharacter(', 'local function connect(')
lua += r'''
local target, health, character = playerWithHealth(100)
check(liveCharacter(target) == character, 'live target accepted')
health.Health = 0
check(liveCharacter(target) == nil, 'zero HP rejected')
health.Health = -1
check(liveCharacter(target) == nil, 'negative HP rejected')
health.Health, health.State = 100, 'Dead'
check(liveCharacter(target) == nil, 'Dead state rejected even with positive HP')
health.State = 'Running'
deadCharacters[character] = true
check(liveCharacter(target) == nil, 'death latch survives health increase')
local replacement, newHealth, newCharacter = playerWithHealth(100)
target.Character = newCharacter
check(liveCharacter(target) == newCharacter, 'new Character accepted')
check(liveCharacter(target, character) == nil, 'old shot cannot follow respawn')
newCharacter.InWorkspace = false
check(liveCharacter(target) == nil, 'removed model rejected')
newCharacter.InWorkspace = true
target.Parent = nil
check(liveCharacter(target) == nil, 'departed player rejected')
target.Parent = Players

local pressed, syntheticInput, shot
local controller = {}
local released = 0
local VirtualUser = {Button1Up=function() released=released+1 end}
local function warn() end
'''
lua += section('    local function releaseInput()', '    local function pressInput(')
lua += section('    local function restoreShot(', '    -- Restore before Roblox')
lua += r'''
local oldCamera, nextCamera = {CFrame='flick'}, {CFrame='new-view'}
shot = {Camera=oldCamera, Applied=true, Base='original'}
pressed = {Camera=oldCamera}
restoreShot(nextCamera, 'cancel')
check(oldCamera.CFrame == 'original', 'camera swap restores the old camera')
check(nextCamera.CFrame == 'new-view', 'camera swap leaves new camera intact')
check(shot == nil and pressed == nil and released == 1, 'cancel releases held input')
restoreShot(nextCamera)
check(released == 1, 'input release is idempotent')
oldCamera.CFrame = 'mouse-moved'
shot = {Camera=oldCamera, Applied=false, Base='stale'}
restoreShot(oldCamera)
check(oldCamera.CFrame == 'mouse-moved', 'pre-restored view is not overwritten')

local setTargetCount, hideCount, highlightCount = 0, 0, 0
local currentTarget, currentPart, pendingAcquire
local visuals, targetMarker = {}, {Visible=true}
local localPlayer = {}
local metadataDue, candidateDue = 10, 10
local function setTarget(p, part) currentTarget, currentPart=p, part; setTargetCount=setTargetCount+1 end
local function hide(data) data.Hidden=true; hideCount=hideCount+1 end
local function releaseHighlight() highlightCount=highlightCount+1 end
local function suspend() end
'''
lua += section('    local function markDead(', '    local function watch(')
lua += r'''
local victim, victimHumanoid, victimCharacter = playerWithHealth(10)
visuals[victim] = {Character=victimCharacter, Eligible=true}
currentTarget = victim
shot = {Character=victimCharacter, Camera=oldCamera, Base='normal', Applied=true}
pressed = {Camera=oldCamera}
pendingAcquire = {Character=newCharacter}
markDead(victim, victimCharacter)
check(visuals[victim].Hidden and not visuals[victim].Eligible, 'death hides ESP immediately')
check(highlightCount == 1, 'death removes highlight')
check(currentTarget == nil and not targetMarker.Visible, 'death removes target marker')
check(shot == nil and pressed == nil, 'death cancels shot and releases input')
check(pendingAcquire ~= nil, 'unrelated death does not cancel queued target')
pendingAcquire = {Character=victimCharacter}
markDead(victim, victimCharacter)
check(pendingAcquire == nil, 'same-character death cancels queued acquisition')
check(deadCharacters[victimCharacter], 'death is latched')

local settings = {SilentAim=true, AutoFire=true, HoldMS=25, FireInterval=120}
local isBlocked, targetAlive, wallClear = false, true, true
local function blocked() return isBlocked end
local function enemyAlive() return targetAlive end
local function updateFilter() end
local function validPoint() return wallClear and 'point' or nil end
local CFrame = {lookAt=function() return 'aimed' end}
local autoFireDue = 0
local activePart = {IsDescendantOf=function() return true end}
local camera = {CFrame={Position='origin', UpVector='up'}}
local shouldDieOnActivate = false
local function pressInput(c)
    pressed = {Camera=c}
    if shouldDieOnActivate then restoreShot(c) end
    return true
end
'''
lua += section('    local function updateShot(', '    local function fireAction(')
lua += r'''
local function prepare()
    camera.CFrame = {Position='origin', UpVector='up'}
    shot = {Camera=camera, Base=camera.CFrame, Player={DisplayName='Test'}, Character={},
        Part=activePart, FireAt=1, Expires=10, Auto=true, Phase='Aim'}
    return shot
end
prepare()
updateShot(camera, 1)
check(shot and shot.Phase == 'Hold' and pressed, 'camera remains aimed through input hold')
local base = shot.Base
camera.CFrame = base
shot.Applied = false -- production pre-camera callback
updateShot(camera, 1.03)
check(shot == nil and pressed == nil and camera.CFrame == base, 'release completes before camera restore')
prepare()
wallClear = false
updateShot(camera, 1)
check(shot == nil and pressed == nil, 'wall appearing cancels shot')
wallClear = true
prepare()
targetAlive = false
updateShot(camera, 1)
check(shot == nil, 'dead target cancels before input')
targetAlive = true
prepare()
settings.SilentAim = false
updateShot(camera, 1)
check(shot == nil, 'disabling silent cancels pending shot')
settings.SilentAim = true
prepare()
shouldDieOnActivate = true
updateShot(camera, 1)
check(shot == nil and pressed == nil, 'synchronous Tool death cannot dereference a cancelled shot')
shouldDieOnActivate = false
prepare()
updateShot(camera, 11)
check(shot == nil, 'timeout cancels stalled input')

local consumedClick = false
local hasTarget = false
local function findTarget() if hasTarget then return victim, activePart end end
local function beginClick() return true end
workspace.CurrentCamera = camera
'''
lua += section('    local function fireAction(', '    ContextActionService:BindActionAtPriority(')
lua += r'''
check(fireAction(nil, 'Begin') == 'Pass', 'no target preserves ordinary click')
hasTarget = true
check(fireAction(nil, 'Begin') == 'Sink', 'targeted click is consumed')
check(fireAction(nil, 'End') == 'Sink', 'consumed click release is paired')
syntheticInput = true
check(fireAction(nil, 'Begin') == 'Pass', 'generated click does not recursively aim')
syntheticInput = false
isBlocked = true
check(fireAction(nil, 'Begin') == 'Pass', 'menu/focus block preserves UI input')
print(tostring(checks) .. ' regression checks passed')
'''

runner = shutil.which('lua') or shutil.which('texlua')
if not runner:
    raise SystemExit('Install Lua 5.3+ or texlua to run regression checks.')
with tempfile.TemporaryDirectory() as directory:
    test = Path(directory) / 'spectra_regression.lua'
    test.write_text(lua)
    subprocess.run([runner, str(test)], check=True)
