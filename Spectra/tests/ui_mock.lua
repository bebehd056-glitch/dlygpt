-- Minimal test doubles, not a Roblox runtime or an in-game rendering test.
local function signal()
    local callbacks={}
    return {
        Connect=function(_,fn)
            local slot={Callback=fn,Active=true}; callbacks[#callbacks+1]=slot
            return {Disconnect=function() slot.Active=false end}
        end,
        Fire=function(_,...)
            for _,slot in ipairs(callbacks) do if slot.Active then slot.Callback(...) end end
        end,
    }
end
math.clamp=function(n,a,b) return math.max(a,math.min(b,n)) end
Enum=setmetatable({}, {__index=function(t,k)
    local category=setmetatable({}, {__index=function(c,n) rawset(c,n,n); return n end})
    rawset(t,k,category); return category
end})
Color3={new=function(r,g,b) return {R=r,G=g,B=b} end,
    fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
UDim={new=function(s,o) return {Scale=s,Offset=o} end}
UDim2={new=function(xs,xo,ys,yo) return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)} end}
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
Vector2={new=function(x,y) return {X=x,Y=y} end}
ColorSequenceKeypoint={new=function(t,c) return {Time=t,Value=c} end}
ColorSequence={new=function(a,b)
    if b then return {ColorSequenceKeypoint.new(0,a),ColorSequenceKeypoint.new(1,b)} end
    return a
end}
TweenInfo={new=function() return {} end}
local defaultsMock={BackgroundTransparency=0,BorderSizePixel=0,Visible=true,ZIndex=1,
    Text='',TextSize=14,Rotation=0,LayoutOrder=0}
local methods={}
local instanceMt={}
function methods:IsA(kind) return self._class==kind end
function methods:GetChildren() return self._children end
function methods:FindFirstChild(name)
    for _,child in ipairs(self._children) do if child.Name==name then return child end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name)) end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:SetAttribute(key,value) self._attributes[key]=value end
function methods:GetPropertyChangedSignal(key)
    self._signals[key]=self._signals[key] or signal()
    return self._signals[key]
end
function methods:Destroy()
    if self._parent then
        for i,child in ipairs(self._parent._children) do if child==self then table.remove(self._parent._children,i) break end end
    end
    self._destroyed=true
end
instanceMt.__index=function(self,key)
    if methods[key] then return methods[key] end
    if key=='ClassName' then return self._class end
    if key=='Parent' then return self._parent end
    if key=='AbsolutePosition' then
        local parent=self._parent and self._parent.AbsolutePosition or Vector2.new(0,0)
        local pos=self._props.Position or UDim2.fromOffset(0,0)
        return Vector2.new(parent.X+pos.X.Offset,parent.Y+pos.Y.Offset)
    end
    if key=='AbsoluteSize' then
        local size=self._props.Size or UDim2.fromOffset(0,0)
        return Vector2.new(size.X.Offset,size.Y.Offset)
    end
    if self._props[key]~=nil then return self._props[key] end
    if defaultsMock[key]~=nil then return defaultsMock[key] end
    if key=='Name' then return self._class end
    if key=='Position' then return UDim2.fromOffset(0,0) end
    if key=='Size' then return UDim2.fromOffset(0,0) end
    if key=='BackgroundColor3' then return Color3.new(1,1,1) end
    if key=='TextColor3' then return Color3.new(0,0,0) end
    if key=='AnchorPoint' then return Vector2.new(0,0) end
    return self:GetPropertyChangedSignal(key)
end
instanceMt.__newindex=function(self,key,value)
    if key=='Parent' then
        rawset(self,'_parent',value)
        if value then value._children[#value._children+1]=self end
    elseif key:sub(1,1)=='_' then rawset(self,key,value)
    else self._props[key]=value end
end
Instance={new=function(kind)
    return setmetatable({_class=kind,_children={},_props={},_signals={},_attributes={}},instanceMt)
end}
local playerMock=Instance.new('Player')
local playerGuiMock=Instance.new('PlayerGui'); playerGuiMock.Parent=playerMock
local servicesMock={Players={LocalPlayer=playerMock},TweenService={Create=function(_,item,_,props)
    return {Cancel=function() end,Play=function() for k,v in pairs(props) do item[k]=v end end}
end}}
game={GetService=function(_,name) servicesMock[name]=servicesMock[name] or {}; return servicesMock[name] end}
workspace={CurrentCamera={ViewportSize=Vector2.new(1280,900)}}
task={delay=function(_,fn) fn() end}
local function json(value)
    local t=type(value)
    if t=='string' then return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"' end
    if t=='number' or t=='boolean' then return tostring(value) end
    if t~='table' then return 'null' end
    local parts={}
    if #value>0 then
        for _,v in ipairs(value) do parts[#parts+1]=json(v) end
        return '['..table.concat(parts,',')..']'
    end
    for k,v in pairs(value) do if type(v)~='function' then parts[#parts+1]=json(k)..':'..json(v) end end
    return '{'..table.concat(parts,',')..'}'
end
local function exportTree(item)
    local result={ClassName=item._class,props={},children={}}
    for k,v in pairs(item._props) do if type(v)~='function' then result.props[k]=v end end
    for k,v in pairs(defaultsMock) do if result.props[k]==nil then result.props[k]=v end end
    for _,child in ipairs(item._children) do result.children[#result.children+1]=exportTree(child) end
    return result
end
