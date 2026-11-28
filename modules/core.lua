local GST = getgenv()
if GST.__aero_unload then pcall(GST.__aero_unload, true) end

local S = {hooked={},closed={},hidden={},envCache={},mtCache={},inHook=false}
local _getfenv=getfenv
local _getinfo=debug.getinfo
local _info=debug.info
local _trace=debug.traceback
local _getreg=debug.getregistry
local _getup=debug.getupvalue
local _getups=debug.getupvalues
local _getmt=debug.getmetatable
local _getrawmt=getrawmetatable
local _cstack=getcallstack
local _gstack=getstack
local _getgc=getgc
local _getinst=getinstances
local _getnil=getnilinstances
local NCC=newcclosure or function(f) return f end
local MARKERS={"getgenv","getrenv","getreg","getfenv","setfenv","getrawmetatable","setreadonly","make_writeable","makereadonly","hookfunction","hookmetamethod","replaceclosure","newcclosure","clonefunction","checkcaller","islclosure","iscclosure","is_synapse_function","identifyexecutor","getexecutorname","getnamecallmethod","setnamecallmethod","syn","KRNL_LOADED","secure_call","request","http_request","getcallingscript","getcallstack","getstack","getgc","getinstances","getnilinstances","getloadedmodules","getscripts","getrunningscripts","getscriptclosure","getscriptbytecode","getfunctionhash","getupvalue","getupvalues","setupvalue","getconstants","getconstant","firetouchinterest","fireclickdetector","fireproximityprompt","setfpscap","getfpscap","setclipboard","Drawing","isrenderobj","cleardrawcache","queue_on_teleport","queueonteleport","sethiddenproperty","gethiddenproperty","setscriptable","getscriptable","loadstring","decompile","mousemoverel","mousemoveabs","mouse1click","mouse1press","mouse1release","getthreadidentity","setthreadidentity","getidentity","setidentity"}
local MSET={}
for _,m in ipairs(MARKERS) do MSET[m]=true end
local FAKE_C={what="C",source="=[C]",short_src="[C]",linedefined=-1,lastlinedefined=-1,currentline=-1,nups=0,namewhat=""}
local function wrapC(b) local w=NCC(b) S.hooked[w]=true return w end
local function isM(k) return type(k)=="string" and MSET[k]==true end
local function CleanEnv(env)
    if type(env)~="table" then return env end
    local c=S.envCache[env]
    if c then return c end
    c={}
    for k,v in pairs(env) do if not isM(k) then c[k]=v end end
    S.envCache[env]=c
    return c
end
local function CleanTrace(t)
    if type(t)~="string" then return t end
    local out={}
    for line in t:gmatch("[^\n]+") do
        local drop=false
        for m in pairs(MSET) do if line:find(m,1,true) then drop=true break end end
        if not drop and not line:find("AERO",1,true) then out[#out+1]=line end
    end
    return table.concat(out,"\n")
end
local function CleanStack(stk)
    if type(stk)~="table" then return stk end
    local out={}
    for i=1,#stk do
        local fr=stk[i]
        if type(fr)=="table" then
            local src=tostring(fr.source or fr.short_src or fr.script or "")
            local drop=false
            for m in pairs(MSET) do if src:find(m,1,true) then drop=true break end end
            if not drop and not src:find("AERO",1,true) then out[#out+1]=fr end
        else out[#out+1]=fr end
    end
    return out
end
local function ProxyMT(mt)
    if type(mt)~="table" then return mt end
    local p=S.mtCache[mt]
    if p then return p end
    p={}
    for k,v in pairs(mt) do if S.closed[v] then p[k]=S.closed[v] else p[k]=v end end
    S.mtCache[mt]=p
    return p
end
function S.registerHook(w,o) if w then S.hooked[w]=true end if w and o then S.closed[w]=o end end
function S.hideInstance(i) if i then S.hidden[i]=true end end
pcall(function()
    getfenv=wrapC(function(lvl)
        local ok,env=pcall(_getfenv,lvl)
        if not ok then return env end
        return CleanEnv(env)
    end)
end)
do
    local w=wrapC(function(f,what)
        if S.hooked[f] then return FAKE_C end
        local ok,r=pcall(_getinfo,f,what)
        if ok and type(r)=="table" then
            local src=tostring(r.source or "")
            for m in pairs(MSET) do if src:find(m,1,true) then return FAKE_C end end
            if src:find("AERO",1,true) then return FAKE_C end
        end
        return r
    end)
    pcall(function() debug.getinfo=w end)
    if _info then
        local w2=wrapC(function(f,what)
            if S.hooked[f] then
                if what=="S" then return {source="=[C]",short_src="[C]",what="C",linedefined=-1,lastlinedefined=-1} end
                if what=="s" then return "=[C]","C" end
                if what=="l" then return -1,-1 end
                if what=="n" then return "","" end
                if what=="u" then return 0,0 end
                return nil
            end
            return _info(f,what)
        end)
        pcall(function() debug.info=w2 end)
    end
end
pcall(function()
    debug.traceback=wrapC(function(msg,lvl)
        local ok,r=pcall(_trace,msg,lvl)
        if ok then return CleanTrace(r) end
        return r
    end)
end)
if _cstack then pcall(function() getcallstack=wrapC(function()
    local ok,r=pcall(_cstack) if ok then return CleanStack(r) end return r
end) end) end
if _gstack then pcall(function() getstack=wrapC(function()
    local ok,r=pcall(_gstack) if ok then return CleanStack(r) end return r
end) end) end
if _getup then pcall(function() debug.getupvalue=wrapC(function(f,i)
    if S.hooked[f] then return nil,nil end
    local ok,n,v=pcall(_getup,f,i)
    if not ok then return n,v end
    if S.hooked[v] then v=nil end
    return n,v
end) end) end
if _getups then pcall(function() debug.getupvalues=wrapC(function(f)
    if S.hooked[f] then return {} end
    local ok,r=pcall(_getups,f)
    if not ok or type(r)~="table" then return r end
    local c={}
    for i,v in ipairs(r) do if not S.hooked[v] then c[i]=v end end
    return c
end) end) end
do
    local regProxy
    local function buildReg()
        if regProxy then return regProxy end
        local ok,real=pcall(_getreg)
        if not ok or type(real)~="table" then return nil end
        regProxy={}
        for k,v in pairs(real) do
            if type(v)=="table" then
                local isMt=(rawget(v,"__namecall") or rawget(v,"__index") or rawget(v,"__newindex")) and true or false
                regProxy[k]=isMt and ProxyMT(v) or v
            else regProxy[k]=v end
        end
        return regProxy
    end
    pcall(function() debug.getregistry=wrapC(function() return buildReg() end) end)
    local function mtHook(orig)
        return wrapC(function(obj)
            local ok,mt=pcall(orig,obj)
            if not ok or type(mt)~="table" then return mt end
            return ProxyMT(mt)
        end)
    end
    pcall(function() debug.getmetatable=mtHook(_getmt) end)
    if _getrawmt then pcall(function() getrawmetatable=mtHook(_getrawmt) end) end
end
if _getgc then pcall(function() getgc=wrapC(function(inc)
    local ok,r=pcall(_getgc,inc)
    if not ok or type(r)~="table" then return r end
    local out={}
    for _,v in ipairs(r) do
        local skip=false
        if type(v)=="function" and S.hooked[v] then skip=true end
        if S.hidden[v] then skip=true end
        if not skip then out[#out+1]=v end
    end
    return out
end) end) end
for _,name in ipairs({"getinstances","getnilinstances"}) do
    local orig=_G[name]
    if orig then
        _G[name]=wrapC(function()
            local ok,r=pcall(orig)
            if not ok or type(r)~="table" then return r end
            local out={}
            for _,v in ipairs(r) do if not S.hidden[v] then out[#out+1]=v end end
            return out
        end)
    end
end
pcall(function()
    local real=checkcaller
    checkcaller=wrapC(function() return S.inHook and true or (real and real()) or false end)
end)
pcall(function()
    local real=islclosure
    islclosure=wrapC(function(f) if S.hooked[f] then return false end return real and real(f) or false end)
end)
pcall(function()
    local real=iscclosure
    iscclosure=wrapC(function(f) if S.hooked[f] then return true end return real and real(f) or true end)
end)
GST.AERO_STEALTH=S

local function StealthMark(fn)
    if fn then S.hooked[fn] = true end
    return fn
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

