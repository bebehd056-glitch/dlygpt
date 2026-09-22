"""Checks real production adapter functions without a Roblox process."""
from pathlib import Path
import shutil
import subprocess
import tempfile

source=(Path(__file__).resolve().parents[1]/'main.lua').read_text()
start=source.index('    local function resolveInputAdapter(')
end=source.index('    local function restoreShot(',start)
test=r'''
local checks=0
local function check(value,message) assert(value,message); checks=checks+1 end
local creatorInputAdapter, pressed, syntheticInput, shot
local inputRebindToken=0
local pendingCallbacks={}
local task={delay=function(_,callback) pendingCallbacks[#pendingCallbacks+1]=callback end}
local controller={Running=true}
local rebinds,unbinds=0,0
local bindFireAction=function() rebinds=rebinds+1 end
local ContextActionService={UnbindAction=function() unbinds=unbinds+1 end}
local ACTION='test'
local settings={FireMethod='VirtualUser'}
local UserInputService={GetMouseLocation=function() return 'mouse' end}
local calls={}
local VirtualUser={
    CaptureController=function() calls[#calls+1]='capture' end,
    Button1Down=function() calls[#calls+1]='down' end,
    Button1Up=function() calls[#calls+1]='up' end,
}
local function warn() end
'''+source[start:end]+r'''
local camera={CFrame='frame'}
check(pressInput(camera),'VirtualUser does not require Character/Tool')
check(calls[2]=='down' and pressed~=nil,'press dispatches input')
settings.FireMethod='Creator'
releaseInput()
check(calls[3]=='up','backend change preserves matching release')
check(unbinds==1 and rebinds==0,'synthetic input keeps capture unbound until release delivery')
pendingCallbacks[1]()
check(rebinds==1,'capture restored after release delivery')
releaseInput()
check(#calls==3,'release is idempotent')
check(not pressInput(camera),'missing creator adapter fails closed')
settings.FireMethod='MouseButton'
check(not pressInput(camera),'missing mouse functions fail closed')
local mouseDown,mouseUp=0,0
mouse1press=function() mouseDown=mouseDown+1 end
mouse1release=function() mouseUp=mouseUp+1 end
check(pressInput(camera),'MouseButton backend works without weapon lookup')
mouse1release=function() error('wrong release') end
releaseInput()
check(mouseDown==1 and mouseUp==1,'release function is captured at press')
controller.Running=false
pendingCallbacks[#pendingCallbacks]()
check(rebinds==1,'unload prevents delayed callback rebinding')
controller.Running=true
settings.FireMethod='Creator'
local contextSeen,upCount=nil,0
creatorInputAdapter={Press=function(context) contextSeen=context end,
    Release=function() upCount=upCount+1 end}
shot={Player='target',Character='character',Part='head',Point='position',Auto=true}
check(pressInput(camera),'creator press dispatched')
check(contextSeen.Target=='target' and contextSeen.AimPosition=='position' and contextSeen.Automatic,'creator receives aim context')
creatorInputAdapter={Press=function() end,Release=function() error('wrong adapter') end}
releaseInput()
check(upCount==1,'in-flight release uses original adapter')
creatorInputAdapter={Press=function() return false,'cannot fire' end,Release=function() upCount=upCount+1 end}
local ok,reason=pressInput(camera)
check(not ok and reason:find('cannot fire',1,true),'explicit adapter refusal propagated')
check(pressed==nil and upCount==2,'refused press cleaned up')
creatorInputAdapter={Press=function() error('test failure') end,Release=function() upCount=upCount+1 end}
check(not pressInput(camera),'adapter error caught')
check(pressed==nil and upCount==3 and not syntheticInput,'error resets input state')
creatorInputAdapter={Press=function() releaseInput() end,Release=function() upCount=upCount+1 end}
check(pressInput(camera),'synchronous cancellation is supported')
check(pressed==nil and upCount==4 and not syntheticInput,'nested release preserves guard state')
settings.FireMethod='bad'
check(not pressInput(camera),'unknown backend rejected')
print(tostring(checks)..' input adapter checks passed')
'''
runner=shutil.which('lua') or shutil.which('texlua')
if not runner: raise SystemExit('Install Lua or texlua')
with tempfile.TemporaryDirectory() as tmp:
    p=Path(tmp)/'input.lua';p.write_text(test)
    subprocess.run([runner,str(p)],check=True)
