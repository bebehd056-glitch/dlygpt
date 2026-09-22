"""Exercise the actual menu construction with test doubles; optional JSON scene export."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root=Path(__file__).resolve().parents[1]
source=(root/'main.lua').read_text()
prefix=source[:source.index('-- Radar lies outside')]
api_source=source[source.index('local api = {Version="8.0.0"}'):]
api_setup='''
local pauses=0
local combat={Target='target',Status='ready',Pause=function() pauses=pauses+1 end}
cleanup=function() alive=false end
local creatorApi=(function()
'''+api_source+'\nend)()\n'
tests=r'''
local count=0
local function check(v,msg) assert(v,msg); count=count+1 end
showPage(activePage)
refreshUI()
updateMaster()
for name,tab in pairs(tabs) do
    tab.Activated:Fire()
    for key,page in pairs(pages) do check(page.Visible==(key==name),'tab visibility '..key) end
end
local function withText(root,text)
    if root._props.Text==text then return root end
    for _,child in ipairs(root._children) do local found=withText(child,text); if found then return found end end
end
showPage('RAGE')
local enabled=withText(pages.RAGE,'Enabled').Parent
enabled.Activated:Fire()
check(settings.SilentAim==false,'checkbox updates setting')
enabled.Activated:Fire()
check(settings.SilentAim==true,'checkbox toggles back')
local combo=withText(pages.RAGE,'VirtualUser').Parent
combo.Activated:Fire()
check(combo:GetAttribute('DropdownOpen')==true,'dropdown opens')
local shield=gui:FindFirstChild('DropdownShield')
withText(shield,'MouseButton').Activated:Fire()
check(settings.FireMethod=='MouseButton','dropdown changes backend')
check(not gui:FindFirstChild('DropdownShield'),'dropdown destroys overlay after selection')
combo.Activated:Fire()
tabs.LEGIT.Activated:Fire()
check(not gui:FindFirstChild('DropdownShield'),'tab switch closes popup')
showPage('RAGE'); combo.Activated:Fire(); setMenuOpen(false)
check(not gui:FindFirstChild('DropdownShield'),'closing menu closes popup')
setMenuOpen(true)
check(not setSetting('FireMethod','Tool'),'unsupported backend rejected')
check(not setSetting('AimFOV',0/0),'NaN rejected')
check(not setSetting('AimFOV',math.huge),'infinity rejected')
check(not setSetting('Missing',true),'unknown settings rejected')
check(setSetting('AimFOV',999) and settings.AimFOV==360,'numeric settings clamped')
check(setSetting('SilentAim',false) and not settings.SilentAim,'false is accepted')
setSetting('SilentAim',true)
setSetting('FireMethod','VirtualUser')
local snapshot=creatorApi:GetSettings()
snapshot.SilentAim=false
check(settings.SilentAim,'settings API returns a copy')
check(creatorApi:Set('AimFOV',25) and settings.AimFOV==25,'creator API changes live setting')
check(not creatorApi:SetInputAdapter({Press=function() end}),'creator API requires paired release')
local custom={Press=function() end,Release=function() end}
check(creatorApi:SetInputAdapter(custom),'creator API accepts valid adapter')
check(pauses==1 and creatorInputAdapter~=custom,'adapter replacement pauses and snapshots callbacks')
custom.Press=nil
check(type(creatorInputAdapter.Press)=='function','adapter mutation cannot break captured callback')
check(creatorApi:GetState().Target=='target','state API returns current target')
creatorApi:OpenMenu(false)
check(not menuOpen,'creator API closes menu')
creatorApi:OpenMenu(true)
setSetting('AimFOV',360)
showPage('RAGE')
footer.Text='spectra  |  Tactical  |  8 players  |  144 fps                   INS / RSHIFT'
if arg[1] then
    local file=assert(io.open(arg[1],'w')); file:write(json(exportTree(menu))); file:close()
end
creatorApi:Unload()
check(not creatorApi:GetState().Running,'unload reflected in state')
check(not creatorApi:Set('SilentAim',true),'unloaded API rejects setting changes')
print(tostring(count)..' menu/settings smoke checks passed')
'''
runner=shutil.which('lua') or shutil.which('texlua')
if not runner: raise SystemExit('Install Lua or texlua')
with tempfile.TemporaryDirectory() as tmp:
    script=Path(tmp)/'ui_smoke.lua'
    script.write_text((root/'tests/ui_mock.lua').read_text()+'\n'+prefix+'\n'+api_setup+tests)
    subprocess.run([runner,str(script),*sys.argv[1:]],check=True)
