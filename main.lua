if game.PlaceId ~= 75205943460003 then
    local lpGate = game:GetService("Players").LocalPlayer
    if lpGate then pcall(function() lpGate:Kick("AERO以外では使用できません") end) end
    return
end
local GST = getgenv()
if GST.__aero_unload then pcall(GST.__aero_unload, true) end

local STEALTH = {
    hooked = {},
    origFenv = getfenv,
    origInfo = debug and debug.getinfo,
    origTrace = debug and debug.traceback,
    origCallStack = getcallstack,
}
local EXEC_MARKERS = {"getgenv", "syn", "KRNL_LOADED", "secure_call", "request", "getfenv", "getrawmetatable", "setreadonly", "hookfunction"}

local function IsExecutorEnv(env)
    if type(env) ~= "table" then return false end
    for i = 1, #EXEC_MARKERS do
        if rawget(env, EXEC_MARKERS[i]) ~= nil then return true end
    end
    return false
end

local function CleanEnv(env)
    if type(env) ~= "table" then return env end
    local clean = {}
    for k, v in pairs(env) do
        local skip = false
        for i = 1, #EXEC_MARKERS do
            if k == EXEC_MARKERS[i] then skip = true break end
        end
        if not skip then clean[k] = v end
    end
    return clean
end

do
    local hasNCC = type(newcclosure) == "function"
    if type(STEALTH.origFenv) == "function" then
        local body = function(lvl)
            local ok, env = pcall(STEALTH.origFenv, lvl)
            if not ok then return env end
            if IsExecutorEnv(env) then return CleanEnv(env) end
            return env
        end
        local wrapped = hasNCC and newcclosure(body) or body
        pcall(function() getfenv = wrapped end)
        STEALTH.hooked[wrapped] = true
    end
    if type(STEALTH.origInfo) == "function" then
        local fakeC = {what = "C", source = "=[C]", short_src = "[C]", linedefined = -1, currentline = -1, nups = 0}
        local body = function(f, what)
            local ok, info = pcall(STEALTH.origInfo, f, what)
            if ok and type(info) == "table" and STEALTH.hooked[f] then return fakeC end
            return info
        end
        local wrapped = hasNCC and newcclosure(body) or body
        pcall(function() debug.getinfo = wrapped end)
        STEALTH.hooked[wrapped] = true
    end
    if type(STEALTH.origTrace) == "function" then
        local body = function(msg, lvl)
            local ok, trace = pcall(STEALTH.origTrace, msg, lvl)
            if not ok or type(trace) ~= "string" then return trace end
            local lines = {}
            for line in trace:gmatch("[^\n]+") do
                local keep = true
                for i = 1, #EXEC_MARKERS do
                    if line:find(EXEC_MARKERS[i], 1, true) then keep = false break end
                end
                if keep and not line:find("AERO", 1, true) then table.insert(lines, line) end
            end
            return table.concat(lines, "\n")
        end
        local wrapped = hasNCC and newcclosure(body) or body
        pcall(function() debug.traceback = wrapped end)
        STEALTH.hooked[wrapped] = true
    end
    if type(STEALTH.origCallStack) == "function" then
        local body = function()
            local ok, stack = pcall(STEALTH.origCallStack)
            if not ok or type(stack) ~= "table" then return stack end
            local clean = {}
            for _, frame in ipairs(stack) do
                local skip = false
                if type(frame) == "table" then
                    local src = tostring(frame.source or "")
                    for i = 1, #EXEC_MARKERS do
                        if src:find(EXEC_MARKERS[i], 1, true) then skip = true break end
                    end
                    if not skip and not src:find("AERO", 1, true) then table.insert(clean, frame) end
                end
            end
            return clean
        end
        local wrapped = hasNCC and newcclosure(body) or body
        pcall(function() getcallstack = wrapped end)
        STEALTH.hooked[wrapped] = true
    end
end

local function StealthMark(fn)
    if fn then STEALTH.hooked[fn] = true end
    return fn
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

local C = {
    triggerEnabled = false, triggerDelay = 60, triggerRadius = 14, triggerInterval = 90,
    silentEnabled = false, silentPart = "頭", silentHitChance = 100, silentShowFOV = true, teamCheck = true,
    silentFOV = 150, silentPrediction = true, silentPredictScale = 100,
    espEnabled = true, espBox = true, espSkeleton = true,
    espTracer = false, espHPBar = true, espHPText = true, espNameDist = true,
    espHeadDot = true, espShowTeam = false, espVisColor = true, espRenderDist = 800,
    fovEnabled = true, fovValue = 110, fovStretch = 100, fovKeepADS = true,
    optSliderTier = 0, optAuto = false,
    optQuality = true, optLighting = true, optPost = true, optMaterial = true,
    optTerrain = true, optEffects = true, optShadow = true, optAvatar = true, optFpsCap = true,
    autoExecute = true,
}
local CDEF = {}
for k, v in pairs(C) do CDEF[k] = v end

local A = {
    conns = {}, drawSet = {}, esp = {}, cache = {},
    frame = 0, ping = 0.08, fpsEMA = 60, lastFire = 0, fireHeld = false,
    silentTarget = nil, silentPartObj = nil, fireSeq = 0, cam = nil,
    learnedBase = nil, baseStable = 0, adsActive = false, adsFOV = nil, zoomSmooth = 1,
    optTier = 0, optAppliedTier = -1, optSaved = {}, optQueue = {}, optQSeen = {},
    fpsCapOrigin = nil, origFOV = nil, origMaxZoom = nil, origMinZoom = nil,
    unloaded = false, errCounts = {}, disabled = {},
    visCache = {}, teamMode = nil,
}
A.optSaved = setmetatable({}, {__mode = "k"})
A.cam = Workspace.CurrentCamera
if A.cam then
    A.origFOV = A.cam.FieldOfView
    pcall(function() A.origStretch = A.cam.ViewStretch end)
end
if LP then A.origMaxZoom = LP.CameraMaxZoomDistance A.origMinZoom = LP.CameraMinZoomDistance end

local function Track(c)
    if c then table.insert(A.conns, c) end
    return c
end
local function NewDraw(kind, props)
    local ok, o = pcall(Drawing.new, kind)
    if not ok or not o then return nil end
    if props then for k, v in pairs(props) do pcall(function() o[k] = v end) end end
    A.drawSet[o] = true
    return o
end
local function RemoveDraw(o)
    if o then A.drawSet[o] = nil pcall(function() o:Remove() end) end
end
local function SafeCall(name, fn, ...)
    if A.disabled[name] then return end
    local ok, err = pcall(fn, ...)
    if ok then A.errCounts[name] = 0 return end
    A.errCounts[name] = (A.errCounts[name] or 0) + 1
    if A.errCounts[name] == 1 then print("[AERO] " .. name .. ": " .. tostring(err)) end
    if A.errCounts[name] > 60 then
        A.disabled[name] = true
        if name == "esp" and A.hideAllEsp then A.hideAllEsp() end
        if name == "fov" then A.desiredFOV = nil end
        if name == "hud" then
            if A.fovCircle then A.fovCircle.Visible = false end
            if A.hudText then A.hudText.Visible = false end
        end
    end
end

local function clampNum(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function LerpNum(a, b, t) return a + (b - a) * t end
local function GetHum(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end
local function IsAlive(p)
    if not p then return false end
    local c = p.Character
    if not c then return false end
    local h = GetHum(c)
    return h ~= nil and h.Health > 0
end

local CONFIG_FILE = "aero_config_v4.json"
local function SaveConfig()
    if not writefile then return end
    local ok, HttpService = pcall(function() return game:GetService("HttpService") end)
    if not ok or not HttpService then return end
    local data = {}
    for k in pairs(CDEF) do data[k] = C[k] end
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
end
local saveQueued = false
local function SaveSoon()
    if saveQueued then return end
    saveQueued = true
    task.spawn(function()
        task.wait(0.4)
        saveQueued = false
        SaveConfig()
    end)
end
local function LoadConfig()
    if not (readfile and isfile) then return end
    local ok, HttpService = pcall(function() return game:GetService("HttpService") end)
    if not ok or not HttpService then return end
    pcall(function()
        if not isfile(CONFIG_FILE) then return end
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) ~= "table" then return end
        local strOK = { silentPart = {["頭"]=true, ["胴体"]=true} }
        local numClamp = {
            fovValue = {70, 120}, silentHitChance = {1, 100},
            triggerDelay = {0, 300}, triggerRadius = {1, 60}, triggerInterval = {50, 300},
            silentFOV = {40, 600}, silentPredictScale = {0, 200},
            espRenderDist = {100, 2000}, fovStretch = {50, 200}, optSliderTier = {0, 4},
        }
        for k, v in pairs(data) do
            if CDEF[k] ~= nil and type(v) == type(CDEF[k]) then
                if strOK[k] then
                    if strOK[k][v] then C[k] = v end
                elseif numClamp[k] and type(v) == "number" then
                    C[k] = clampNum(v, numClamp[k][1], numClamp[k][2])
                else
                    C[k] = v
                end
            end
        end
    end)
end

local function RefreshTeamMode()
    local attrSeen = nil
    local attrDistinct = false
    for _, p in ipairs(Players:GetPlayers()) do
        local tv = p:GetAttribute("Team")
        if tv ~= nil then
            if attrSeen == nil then attrSeen = tv elseif attrSeen ~= tv then attrDistinct = true end
        end
    end
    A.teamAttrMode = attrDistinct
    local distinct = false
    local seen = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Team ~= nil then
            if seen == nil then seen = p.Team elseif seen ~= p.Team then distinct = true end
        end
    end
    if distinct then A.teamMode = "team" return end
    A.teamMode = "ffa"
end
local function IsProtected(char)
    if not char then return false end
    if char:FindFirstChildOfClass("ForceField") then return true end
    if char:FindFirstChild("SpawnProtection") then return true end
    local pu = nil
    pcall(function() pu = char:GetAttribute("ProtectedUntil") end)
    if type(pu) == "number" and pu > tick() then return true end
    return false
end
local function IsEnemy(p, useTeamCheck)
    if not p or p == LP then return false end
    if not useTeamCheck then return true end
    if A.teamAttrMode then
        local lt, pt = LP:GetAttribute("Team"), p:GetAttribute("Team")
        if lt ~= nil and pt ~= nil then return lt ~= pt end
    end
    if A.teamMode == nil then RefreshTeamMode() end
    if A.teamMode == "team" then
        if p.Team ~= nil or (LP and LP.Team ~= nil) then return p.Team ~= LP.Team end
        return true
    end
    return true
end

local RAY_PARAMS = RaycastParams.new()
RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
RAY_PARAMS.IgnoreWater = true
local function VisCheckPart(part, char)
    local cam = A.cam
    if not cam or not part then return false end
    local origin = cam.CFrame.Position
    local dir = part.Position - origin
    local dist = dir.Magnitude
    if dist < 0.1 then return true end
    RAY_PARAMS.FilterDescendantsInstances = {LP and LP.Character, A.cam}
    local ok, res = pcall(function() return Workspace:Raycast(origin, dir, RAY_PARAMS) end)
    if not ok then return true end
    if not res then return true end
    if (res.Position - origin).Magnitude < 3 then return true end
    if char and res.Instance:IsDescendantOf(char) then return true end
    if (res.Position - part.Position).Magnitude < 2 then return true end
    local okT, tr = pcall(function() return res.Instance.Transparency end)
    if okT and tr and tr >= 0.75 then return true end
    return false
end
local function VisCached(p, part, char)
    local e = A.visCache[p]
    if e and e.part == part and (A.frame - (e.frame or 0)) <= 1 then return e.ok end
    local ok = VisCheckPart(part, char)
    A.visCache[p] = {part = part, ok = ok, frame = A.frame}
    return ok
end

local function ResolvePart(p, mode)
    local char = p and p.Character
    if not char then return nil end
    if mode == "胴体" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function PredictPos(part, entry)
    if not C.silentPrediction or not entry then return part.Position end
    local cam = A.cam
    if not cam then return part.Position end
    local ping = A.ping or 0.05
    if ping > 0.13 then ping = 0.13 end
    local t = ping
    local vel = entry.vel or Vector3.new()
    local off = vel * t
    local acc = entry.accel
    if acc then off = off + acc * (0.5 * t * t) end
    local yF = 0.35
    local hum = entry.hum
    if hum then
        local ok, fm = pcall(function() return hum.FloorMaterial end)
        if ok and fm == Enum.Material.Air and math.abs(vel.Y) <= 25 then yF = yF * 0.5 end
    end
    off = Vector3.new(off.X, off.Y * yF, off.Z)
    local predScale = C.silentPredictScale or 100
    off = off * (predScale / 100)
    if off.Magnitude > 14 then off = off.Unit * 14 end
    local jitter = Vector3.new(
        (math.random() - 0.5) * 2,
        (math.random() - 0.5) * 2,
        (math.random() - 0.5) * 2
    ) * 0.35
    return part.Position + off + jitter
end

local function EffFOV(base)
    local f = base or 150
    if A.adsActive and A.zoomSmooth and A.zoomSmooth > 0.01 then f = f / A.zoomSmooth end
    return f
end

local function SelectTarget(partMode, stickyKey)
    local cam = A.cam
    if not cam or not LP then return nil, nil end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local fov = EffFOV(C.silentFOV)
    local best, bestPart, bestD = nil, nil, math.huge
    local sticky, stickyPart, stickyD = nil, nil, nil
    local lockedP = stickyKey and A[stickyKey] or nil
    for _, p in ipairs(A.players or Players:GetPlayers()) do
        if IsEnemy(p, C.teamCheck) and IsAlive(p) then
            if not IsProtected(p.Character) then
                local part = ResolvePart(p, partMode)
                if part then
                    local entry = A.cache[p]
                    local sp, on = cam:WorldToViewportPoint(part.Position)
                    if on and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        local dMax = (p == lockedP) and fov * 1.25 or fov
                        if d <= dMax then
                            if d < bestD then bestD = d best = p bestPart = part end
                            if stickyKey and A[stickyKey] == p then sticky = p stickyPart = part stickyD = d end
                        end
                    end
                end
            end
        end
    end
    if sticky and stickyD and stickyD <= fov * 1.25 and (not best or best == sticky or stickyD < bestD * 1.8) then
        return sticky, stickyPart
    end
    return best, bestPart
end

local function CacheStep(dt)
    A.players = Players:GetPlayers()
    if A.frame % 120 == 0 then pcall(RefreshTeamMode) end
    if dt <= 0 then dt = 1 / 60 end
    for _, p in ipairs(A.players) do
        if p ~= LP then
            local e = A.cache[p]
            if not e then e = {vel = Vector3.new(), accel = Vector3.new()} A.cache[p] = e end
            local char = p.Character
            if char ~= e.char then
                e.char = char
                e.vel = Vector3.new()
                e.accel = Vector3.new()
                e.prevPos = nil
                e.hum = nil
                e.hrp = nil
                e.head = nil
            end
            if not e.hum then e.hum = GetHum(char) end
            if not e.hrp then e.hrp = char and char:FindFirstChild("HumanoidRootPart") end
            if not e.head then e.head = char and char:FindFirstChild("Head") end
            local hrp = e.hrp
            if hrp then
                local pos = hrp.Position
                if e.prevPos then
                    local delta = pos - e.prevPos
                    if delta.Magnitude > 8 then
                        e.vel = Vector3.new()
                        e.accel = Vector3.new()
                    else
                        local raw = delta / dt
                        if raw.Magnitude > 400 then raw = Vector3.new() end
                        local okA, blended = pcall(function()
                            local a = hrp.AssemblyLinearVelocity
                            if a and raw.Magnitude > 3 and a.Magnitude > 3 and a.Magnitude < 400 and a:Dot(raw) > 0 then
                                return raw:Lerp(a, 0.5)
                            end
                            return nil
                        end)
                        if okA and blended then raw = blended end
                        local nv = e.vel:Lerp(raw, 0.45)
                        local dv = nv - e.vel
                        local maxDv = 260 * dt + 6
                        if dv.Magnitude > maxDv then nv = e.vel + dv.Unit * maxDv end
                        if nv.Magnitude < 0.5 then nv = Vector3.new() end
                        local acc = (nv - e.vel) / dt
                        if acc.Magnitude > 80 then acc = acc.Unit * 80 end
                        e.accel = e.accel:Lerp(acc, 0.25)
                        e.vel = nv
                    end
                end
                e.prevPos = pos
            else
                e.prevPos = nil
            end
        end
    end
end

local function MarkFire()
    A.lastFire = tick()
    A.fireHeld = true
    A.fireHeldAt = tick()
end

pcall(function() A.isTouch = (UIS.TouchEnabled == true) end)
local function OnOwnGui(pos)
    local rects = A.guiHitRects
    if not rects or not pos then return false end
    local hit = false
    pcall(function()
        for _, o in ipairs(rects) do
            if o and o.Visible then
                local ap, as = o.AbsolutePosition, o.AbsoluteSize
                if pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y then hit = true return end
            end
        end
    end)
    return hit
end
Track(UIS.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then A.adsBtnHeld = true end
    if input.UserInputType == Enum.UserInputType.Touch then
        if input.Position and not OnOwnGui(input.Position) then
            local cam = A.cam
            local vw = cam and cam.ViewportSize.X or 1000
            if input.Position.X >= vw * 0.5 then
                A.fireTouch = input
                A.fireTouchPos = Vector2.new(input.Position.X, input.Position.Y)
                MarkFire()
            end
        end
        return
    end
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MarkFire()
    end
end))
pcall(function()
    Track(UIS.InputChanged:Connect(function(input)
        if A.fireTouch and input == A.fireTouch and A.fireTouchPos and input.Position then
            local moved = (Vector2.new(input.Position.X, input.Position.Y) - A.fireTouchPos).Magnitude
            if moved > 70 then
                A.fireTouch = nil
                A.fireTouchPos = nil
                A.fireHeld = false
            end
        end
    end))
end)
Track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then A.adsBtnHeld = false end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        A.fireHeld = false
    elseif input.UserInputType == Enum.UserInputType.Touch then
        if A.fireTouch and input == A.fireTouch then
            A.fireHeld = false
            A.fireTouch = nil
            A.fireTouchPos = nil
        end
    end
end))

local function FindFireRemote()
    if A.fireRemote and A.fireRemote.Parent then return A.fireRemote end
    local found = nil
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local kin = rs and rs:FindFirstChild("Kinetic")
        found = kin and kin:FindFirstChild("Fire")
    end)
    A.fireRemote = found
    return found
end
local function RefreshSilentTarget()
    if not C.silentEnabled then
        A.silentTarget = nil
        A.silentPartObj = nil
        return
    end
    FindFireRemote()
    local p, part = SelectTarget(C.silentPart, "silentTarget")
    if p ~= A.silentTarget then A.silentRollOk = nil end
    A.silentTarget = p
    A.silentPartObj = part
end
local function SilentGoal()
    local part = A.silentPartObj
    if not part or not part.Parent then return nil end
    if A.silentGoalFrame == A.frame and A.silentGoalFor == part then return A.silentGoalCache end
    if A.silentRollOk == nil then A.silentRollOk = (math.random(1, 100) <= (C.silentHitChance or 100)) end
    if not A.silentRollOk then return nil end
    local p = A.silentTarget
    local g = PredictPos(part, p and A.cache[p])
    A.silentGoalFrame = A.frame A.silentGoalFor = part A.silentGoalCache = g
    return g
end
local function AfterBend()
    A.silentRollOk = nil
    A.silentGoalFrame = -1
    A.silentGoalFor = nil
    A.lastFire = tick()
    A.fireHeldAt = tick()
end

local AC_PATTERNS = {"detect", "ban", "kick", "iac", "respond", "report", "anticheat", "ac_", "integrity", "flag"}
local function IsAcRemote(remote)
    if not remote then return false end
    local ok, n = pcall(function() return remote.Name end)
    if not ok or type(n) ~= "string" then return false end
    local low = n:lower()
    for i = 1, #AC_PATTERNS do
        if low:find(AC_PATTERNS[i], 1, true) then return true end
    end
    return false
end

local function InstallHooks()
    local ncc = newcclosure or function(f) return f end
    local inHook = false
    local oldNamecall
    local function handleFire(self, ...)
        if self ~= A.fireRemote then return false end
        if not A.silentPartObj then RefreshSilentTarget() end
        local goal = SilentGoal()
        if not goal then return false end
        local part = A.silentPartObj
        if not part or not part.Parent then return false end
        if select("#", ...) < 5 then return false end
        local args = {...}
        local origin = args[2]
        if typeof(origin) ~= "Vector3" or typeof(args[3]) ~= "Vector3" then return false end
        local nd = goal - origin
        if nd.Magnitude <= 0.01 then return false end
        args[3] = nd.Unit
        args[4] = part
        args[5] = goal
        AfterBend()
        return true, oldNamecall(self, table.unpack(args))
    end
    local hookFn
    hookFn = ncc(function(self, ...)
        if inHook then return oldNamecall(self, ...) end
        local method = getnamecallmethod()
        if method ~= "FireServer" then return oldNamecall(self, ...) end
        if IsAcRemote(self) then return oldNamecall(self, ...) end
        if not A.fireRemote then FindFireRemote() end
        if self ~= A.fireRemote then return oldNamecall(self, ...) end
        if checkcaller and checkcaller() then return oldNamecall(self, ...) end
        local seqArg = select(6, ...)
        if type(seqArg) == "number" and seqArg > (A.fireSeq or 0) then A.fireSeq = seqArg end
        A.lastFire = tick()
        if not C.silentEnabled then return oldNamecall(self, ...) end
        inHook = true
        local res = {pcall(handleFire, self, ...)}
        inHook = false
        if res[1] and res[2] then return res[3], res[4], res[5], res[6], res[7], res[8], res[9], res[10] end
        return oldNamecall(self, ...)
    end)
    StealthMark(hookFn)
    oldNamecall = hookmetamethod(game, "__namecall", hookFn)
    A.oldNamecall = oldNamecall
    A.hooksOn = true
end

local function SyncSilentHooks()
    if C.silentEnabled or C.triggerEnabled then
        if A.hooksOn then return end
        if not (hookmetamethod and getnamecallmethod) then return end
        local okI = pcall(InstallHooks)
        if okI and A.oldNamecall then A.hooksOn = true end
    else
        if not A.hooksOn and not A.oldNamecall then return end
        A.hooksOn = false
        if A.oldNamecall then pcall(function() hookmetamethod(game, "__namecall", A.oldNamecall) end) A.oldNamecall = nil end
    end
end
A.syncSilentHooks = SyncSilentHooks
A.findFireRemote = FindFireRemote

local function DoRemoteShot(part, goal)
    local remote = FindFireRemote()
    if not remote then return false end
    local lchar = LP and LP.Character
    if not lchar then return false end
    local weapon = nil
    pcall(function() weapon = lchar:GetAttribute("Weapon") end)
    if type(weapon) ~= "string" or weapon == "" then return false end
    local hrp = lchar:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local origin = hrp.Position
    local nd = goal - origin
    if nd.Magnitude <= 0.01 then return false end
    local seq = (A.fireSeq or 0) + 1
    A.fireSeq = seq
    A.lastRemoteShot = tick()
    local ok = pcall(function() remote:FireServer(weapon, origin, nd.Unit, part, goal, seq) end)
    return ok
end
local function FireRemoteShot(part, goal)
    if A.lastRemoteShot and (tick() - A.lastRemoteShot) < (C.triggerInterval or 90) / 1000 then return true end
    return DoRemoteShot(part, goal)
end
local function TriggerStep()
    if not C.triggerEnabled then A.triggerStart = nil return end
    local plr, part = nil, nil
    if A.silentPartObj and A.silentPartObj.Parent then
        plr, part = A.silentTarget, A.silentPartObj
    else
        plr, part = SelectTarget(C.silentPart, "triggerTarget")
    end
    if not part then A.triggerStart = nil A.triggerFor = nil return end
    local cam = A.cam
    if not cam then return end
    local goal = PredictPos(part, plr and A.cache[plr])
    local sp, on = cam:WorldToViewportPoint(goal)
    if not on then A.triggerStart = nil A.triggerFor = nil return end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    if (Vector2.new(sp.X, sp.Y) - center).Magnitude > (C.triggerRadius or 14) then
        A.triggerStart = nil
        A.triggerFor = nil
        return
    end
    if A.triggerFor ~= part then A.triggerFor = part A.triggerStart = nil end
    if not A.triggerStart then A.triggerStart = tick() end
    if (tick() - A.triggerStart) * 1000 >= (C.triggerDelay or 60) then
        A.triggerStart = tick()
        local function fireViaTool()
            local lchar = LP and LP.Character
            local tool = lchar and lchar:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) return true end
            return false
        end
        if A.isTouch then
            if not fireViaTool() and not FireRemoteShot(part, goal) then
                if mouse1press and mouse1release then pcall(function() mouse1press() mouse1release() end)
                elseif mouse1click then pcall(function() mouse1click() end) end
            end
        else
            if mouse1press and mouse1release then
                pcall(function() mouse1press() mouse1release() end)
            elseif mouse1click then
                pcall(function() mouse1click() end)
            elseif not fireViaTool() then
                FireRemoteShot(part, goal)
            end
        end
    end
end
local function HideBundle(b)
    if not b then return end
    local function h(o) if o then o.Visible = false end end
    h(b.tracer) h(b.tracerOut) h(b.nameTxt) h(b.distTxt) h(b.hpBg) h(b.hpBar) h(b.hpTxt) h(b.headDot)
    if b.corners then for _, o in ipairs(b.corners) do h(o) end end
    if b.cornersOut then for _, o in ipairs(b.cornersOut) do h(o) end end
    if b.bones then for _, o in ipairs(b.bones) do h(o) end end
end
local function CreateBundle(p)
    local b = {}
    A.bundleSeq = (A.bundleSeq or 0) + 1
    b.phase = A.bundleSeq % 3
    b.corners = {}
    b.cornersOut = {}
    for i = 1, 8 do
        b.corners[i] = NewDraw("Line", {Visible = false, Thickness = 1, Transparency = 1, ZIndex = 2})
        b.cornersOut[i] = NewDraw("Line", {Visible = false, Thickness = 3, Transparency = 1, Color = Color3.fromRGB(0, 0, 0), ZIndex = 1})
    end
    b.tracer = NewDraw("Line", {Visible = false, Thickness = 1, Transparency = 1, ZIndex = 2})
    b.tracerOut = NewDraw("Line", {Visible = false, Thickness = 3, Transparency = 1, Color = Color3.fromRGB(0, 0, 0), ZIndex = 1})
    b.nameTxt = NewDraw("Text", {Visible = false, Center = true, Outline = true, Size = 13, Transparency = 1, ZIndex = 3})
    b.distTxt = NewDraw("Text", {Visible = false, Center = true, Outline = true, Size = 12, Transparency = 1, ZIndex = 3})
    b.hpBg = NewDraw("Square", {Visible = false, Filled = true, Thickness = 1, Transparency = 1, Color = Color3.fromRGB(0, 0, 0), ZIndex = 1})
    b.hpBar = NewDraw("Square", {Visible = false, Filled = true, Thickness = 1, Transparency = 1, ZIndex = 2})
    b.hpTxt = NewDraw("Text", {Visible = false, Center = true, Outline = true, Size = 11, Transparency = 1, ZIndex = 3})
    b.headDot = NewDraw("Circle", {Visible = false, Filled = false, Thickness = 1, Transparency = 1, NumSides = 12, Radius = 3, ZIndex = 2})
    b.bones = {}
    for i = 1, 15 do b.bones[i] = NewDraw("Line", {Visible = false, Thickness = 1, Transparency = 1, ZIndex = 2}) end
    pcall(function() if Drawing.Fonts and Drawing.Fonts.Plex then b.nameTxt.Font = Drawing.Fonts.Plex b.distTxt.Font = Drawing.Fonts.Plex b.hpTxt.Font = Drawing.Fonts.Plex end end)
    A.esp[p] = b
    return b
end
local function RemoveBundle(p)
    local b = A.esp[p]
    if not b then return end
    A.esp[p] = nil
    RemoveDraw(b.tracer) RemoveDraw(b.tracerOut)
    RemoveDraw(b.nameTxt) RemoveDraw(b.distTxt) RemoveDraw(b.hpBg) RemoveDraw(b.hpBar) RemoveDraw(b.hpTxt) RemoveDraw(b.headDot)
    if b.corners then for _, o in ipairs(b.corners) do RemoveDraw(o) end end
    if b.cornersOut then for _, o in ipairs(b.cornersOut) do RemoveDraw(o) end end
    if b.bones then for _, o in ipairs(b.bones) do RemoveDraw(o) end end
end
local function ProjectBox(char)
    local cam = A.cam
    if not cam or not char then return nil end
    local ok, cf, size = pcall(function() return char:GetBoundingBox() end)
    if not ok or not cf then return nil end
    local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
    local corners = {
        cf * Vector3.new(-hx, -hy, -hz), cf * Vector3.new(hx, -hy, -hz), cf * Vector3.new(-hx, hy, -hz), cf * Vector3.new(hx, hy, -hz),
        cf * Vector3.new(-hx, -hy, hz), cf * Vector3.new(hx, -hy, hz), cf * Vector3.new(-hx, hy, hz), cf * Vector3.new(hx, hy, hz),
    }
    local minX, minY, maxX, maxY = 1e9, 1e9, -1e9, -1e9
    local any = false
    for _, w in ipairs(corners) do
        local sp, on = cam:WorldToViewportPoint(w)
        if on then
            any = true
            if sp.X < minX then minX = sp.X end
            if sp.Y < minY then minY = sp.Y end
            if sp.X > maxX then maxX = sp.X end
            if sp.Y > maxY then maxY = sp.Y end
        end
    end
    if not any then return nil end
    return minX, minY, maxX, maxY
end
local BONES15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local BONES6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}, {"Torso", "HumanoidRootPart"},
}

local ESP_COL_ENEMY = Color3.fromRGB(80, 255, 120)
local ESP_COL_TEAM = Color3.fromRGB(80, 200, 255)
local ESP_COL_VIS = Color3.fromRGB(255, 70, 70)
local ESP_COL_WHITE = Color3.fromRGB(255, 255, 255)
local tableClear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
local BONE_PC = {}
local BONE_JC = {}
local HP_COLS = {}
for i = 0, 16 do local f = i / 16 HP_COLS[i] = Color3.fromRGB(255 * (1 - f), 255 * f, 40) end

local function EspStep()
    if not C.espEnabled then
        if A.espWasOn then
            A.espWasOn = false
            for _, b in pairs(A.esp) do HideBundle(b) end
        end
        return
    end
    A.espWasOn = true
    local cam = A.cam
    if not cam or not LP or not LP.Character then return end
    local lpChar = LP.Character
    local lpHrp = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
    if not lpHrp then
        for _, b in pairs(A.esp) do HideBundle(b) end
        return
    end
    local vp = cam.ViewportSize
    local tracerFrom = Vector2.new(vp.X / 2, vp.Y)
    for _, p in ipairs(A.players or Players:GetPlayers()) do
        if p ~= LP then
            local enemy = IsEnemy(p, C.teamCheck)
            local show = enemy or C.espShowTeam
            local b = A.esp[p]
            local char = p.Character
            local e = A.cache[p]
            local hum = (e and e.char == char and e.hum) or GetHum(char)
            local hrp = (e and e.char == char and e.hrp) or (char and char:FindFirstChild("HumanoidRootPart"))
            if show and char and hum and hum.Health > 0 and hrp then
                local dist = (hrp.Position - lpHrp.Position).Magnitude
                if dist <= (C.espRenderDist or 800) then
                    if not b then b = CreateBundle(p) end
                    local minX, minY, maxX, maxY
                    local skipN = (dist > 500 and 3) or (dist > 300 and 2) or 1
                    if skipN > 1 and (A.frame + (b.phase or 0)) % skipN ~= 0 then
                        minX = false
                    else
                        local nowC = os.clock()
                        if not b.aspect or nowC - (b.learnAt or 0) > 1 then
                            b.learnAt = nowC
                            minX, minY, maxX, maxY = ProjectBox(char)
                            local okS, cfS, szS = pcall(function() return char:GetBoundingBox() end)
                            if okS and szS then b.hw = szS.X / 2 b.hh = szS.Y / 2 b.aspect = szS.X / math.max(szS.Y, 0.1) end
                        end
                        if not minX and b.hh then
                            local spF, onF = cam:WorldToViewportPoint(hrp.Position)
                            if onF then
                                local pxS = vp.Y / (2 * math.max(dist, 1) * math.tan(math.rad(cam.FieldOfView) / 2))
                                local hPx = b.hh * 2 * pxS
                                local wPx = hPx * b.aspect
                                minX = spF.X - wPx / 2 maxX = spF.X + wPx / 2
                                minY = spF.Y - hPx / 2 maxY = spF.Y + hPx / 2
                            end
                        end
                    end
                    if minX == false then
                    elseif minX then
                        if b.sx then
                            local k = 0.5
                            minX = LerpNum(b.sx, minX, k) minY = LerpNum(b.sy, minY, k)
                            maxX = LerpNum(b.sw, maxX, k) maxY = LerpNum(b.sh, maxY, k)
                        end
                        b.sx, b.sy, b.sw, b.sh = minX, minY, maxX, maxY
                        local bw, bh = maxX - minX, maxY - minY
                        local baseCol = enemy and ESP_COL_ENEMY or ESP_COL_TEAM
                        local headP = (e and e.char == char and e.head) or (char and char:FindFirstChild("Head"))
                        if enemy and C.espVisColor then
                            if headP and VisCached(p, headP, char) then baseCol = ESP_COL_VIS end
                        end
                        if b.corners then for _, o in ipairs(b.corners) do if o then o.Visible = false end end end
                        if b.cornersOut then for _, o in ipairs(b.cornersOut) do if o then o.Visible = false end end end
                        if C.espBox then
                            local cl = math.min(bw, bh) * 0.25
                            local cPts, cOut = b.corners, b.cornersOut
                            local function setCorner(i, x1, y1, x2, y2)
                                local o = cPts and cPts[i]
                                if o then o.From = Vector2.new(x1, y1) o.To = Vector2.new(x2, y2) o.Color = baseCol o.Visible = true end
                                local u = cOut and cOut[i]
                                if u then u.From = Vector2.new(x1, y1) u.To = Vector2.new(x2, y2) u.Visible = true end
                            end
                            setCorner(1, minX, minY, minX + cl, minY) setCorner(2, minX, minY, minX, minY + cl)
                            setCorner(3, maxX, minY, maxX - cl, minY) setCorner(4, maxX, minY, maxX, minY + cl)
                            setCorner(5, minX, maxY, minX + cl, maxY) setCorner(6, minX, maxY, minX, maxY - cl)
                            setCorner(7, maxX, maxY, maxX - cl, maxY) setCorner(8, maxX, maxY, maxX, maxY - cl)
                        end
                        if b.tracer then
                            if C.espTracer then
                                local from = tracerFrom
                                b.tracer.From = from b.tracer.To = Vector2.new((minX + maxX) / 2, maxY) b.tracer.Color = baseCol b.tracer.Visible = true
                                if b.tracerOut then b.tracerOut.From = from b.tracerOut.To = b.tracer.To b.tracerOut.Visible = true end
                            else
                                b.tracer.Visible = false
                                if b.tracerOut then b.tracerOut.Visible = false end
                            end
                        end
                        if b.nameTxt then
                            if C.espNameDist then
                                b.nameTxt.Text = p.DisplayName
                                b.nameTxt.Position = Vector2.new((minX + maxX) / 2, minY - 16)
                                b.nameTxt.Color = baseCol
                                b.nameTxt.Visible = true
                                if b.distTxt then
                                    local dInt = math.floor(dist)
                                    if b._dInt ~= dInt then b._dInt = dInt b.distTxt.Text = tostring(dInt) .. "m" end
                                    b.distTxt.Position = Vector2.new((minX + maxX) / 2, maxY + 2)
                                    b.distTxt.Color = ESP_COL_WHITE
                                    b.distTxt.Visible = true
                                end
                            else
                                b.nameTxt.Visible = false
                                if b.distTxt then b.distTxt.Visible = false end
                            end
                        end
                        local hpNow, hpMax = hum.Health, math.max(hum.MaxHealth, 1)
                        pcall(function()
                            local ar = char:GetAttribute("Armor")
                            local arm = char:GetAttribute("MaxArmor")
                            if type(ar) == "number" and type(arm) == "number" and arm > 0 then
                                hpNow = hpNow + ar hpMax = hpMax + arm
                            end
                        end)
                        local hpFrac = clampNum(hpNow / hpMax, 0, 1)
                        if b.hpBar then
                            if C.espHPBar then
                                local bx = minX - 6
                                if b.hpBg then b.hpBg.Position = Vector2.new(bx - 1, minY - 1) b.hpBg.Size = Vector2.new(3, bh + 2) b.hpBg.Visible = true end
                                b.hpBar.Position = Vector2.new(bx, minY + bh * (1 - hpFrac))
                                b.hpBar.Size = Vector2.new(1, bh * hpFrac)
                                b.hpBar.Color = HP_COLS[math.floor(hpFrac * 16 + 0.5)]
                                b.hpBar.Visible = true
                            else
                                b.hpBar.Visible = false
                                if b.hpBg then b.hpBg.Visible = false end
                            end
                        end
                        if b.hpTxt then
                            if C.espHPText then
                                local hpInt = math.floor(hpNow)
                                if b._hpInt ~= hpInt then b._hpInt = hpInt b.hpTxt.Text = tostring(hpInt) end
                                b.hpTxt.Position = Vector2.new(minX - 14, minY + bh * (1 - hpFrac) - 6)
                                b.hpTxt.Color = ESP_COL_WHITE
                                b.hpTxt.Visible = true
                            else
                                b.hpTxt.Visible = false
                            end
                        end
                        if b.headDot then
                            if C.espHeadDot and headP then
                                local sp, on = cam:WorldToViewportPoint(headP.Position)
                                if on and sp.Z > 0 then
                                    b.headDot.Position = Vector2.new(sp.X, sp.Y)
                                    b.headDot.Color = baseCol
                                    b.headDot.Visible = true
                                else
                                    b.headDot.Visible = false
                                end
                            else
                                b.headDot.Visible = false
                            end
                        end
                        if b.bones then
                            local showBones = C.espSkeleton and dist <= 150
                            local rig = nil
                            if showBones then
                                local okR, rt = pcall(function() return hum.RigType end)
                                rig = (okR and rt == Enum.HumanoidRigType.R15) and BONES15 or BONES6
                            end
                            local partCache = BONE_PC
                            local projCache = BONE_JC
                            tableClear(partCache)
                            tableClear(projCache)
                            for i, o in ipairs(b.bones) do
                                if o then
                                    local pairDef = rig and rig[i]
                                    if pairDef then
                                        local p1 = partCache[pairDef[1]]
                                        if not p1 then p1 = char:FindFirstChild(pairDef[1]) if p1 then partCache[pairDef[1]] = p1 end end
                                        local p2 = partCache[pairDef[2]]
                                        if not p2 then p2 = char:FindFirstChild(pairDef[2]) if p2 then partCache[pairDef[2]] = p2 end end
                                        if p1 and p2 then
                                            local pr1 = projCache[p1]
                                            if not pr1 then local sx, ox = cam:WorldToViewportPoint(p1.Position) pr1 = {sx, ox} projCache[p1] = pr1 end
                                            local pr2 = projCache[p2]
                                            if not pr2 then local sx, ox = cam:WorldToViewportPoint(p2.Position) pr2 = {sx, ox} projCache[p2] = pr2 end
                                            local s1, on1 = pr1[1], pr1[2]
                                            local s2, on2 = pr2[1], pr2[2]
                                            if on1 and on2 and s1.Z > 0 and s2.Z > 0 then
                                                o.From = Vector2.new(s1.X, s1.Y) o.To = Vector2.new(s2.X, s2.Y) o.Color = baseCol o.Visible = true
                                            else
                                                o.Visible = false
                                            end
                                        else
                                            o.Visible = false
                                        end
                                    else
                                        o.Visible = false
                                    end
                                end
                            end
                        end
                    else
                        HideBundle(b)
                    end
                else
                    HideBundle(b)
                end
            else
                if b then HideBundle(b) end
            end
        end
    end
end

local function FovStep()
    local cam = Workspace.CurrentCamera
    if cam ~= A.cam then
        A.cam = cam
        if cam and A.origFOV == nil then A.origFOV = cam.FieldOfView end
    end
    if not cam then return end
    local cur = cam.FieldOfView
    if A.origFOV and A.origFOV >= 60 and not A.learnedBase then A.learnedBase = A.origFOV end
    local base = A.learnedBase or C.fovValue
    local inputADS = A.adsBtnHeld == true
    if not inputADS then pcall(function() inputADS = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end) end
    if cur < base - 3 then
        A.adsActive = true
        A.adsFOV = cur
    elseif cur >= base - 1 and not inputADS then
        A.adsActive = false
    end
    if not A.adsActive then
        if math.abs(cur - (A.baseCand or -100)) <= 0.3 then
            A.baseStable = (A.baseStable or 0) + 1
        else
            A.baseCand = cur
            A.baseStable = 0
        end
        if A.baseStable >= 40 and cur >= 60 and (not A.learnedBase or cur >= A.learnedBase) then A.learnedBase = cur end
    end
    if not C.fovEnabled then
        if A.fovApplied then
            A.fovApplied = false
            if A.origFOV then pcall(function() cam.FieldOfView = A.origFOV end) end
            if A.origStretch ~= nil then pcall(function() cam.ViewStretch = A.origStretch end) end
            A.lastSetFOV = nil
        end
        A.desiredFOV = nil
        local rOff = 1
        if A.learnedBase and A.learnedBase > 5 then rOff = math.tan(math.rad(cur / 2)) / math.tan(math.rad(A.learnedBase / 2)) end
        A.zoomSmooth = LerpNum(A.zoomSmooth or 1, clampNum(rOff, 0.08, 1), 0.2)
        return
    end
    A.fovApplied = true
    local desired = C.fovValue
    A.desiredFOV = desired
    if A.adsActive and A.adsFOV then
        local ratio = math.tan(math.rad(A.adsFOV / 2)) / math.tan(math.rad(base / 2))
        if C.fovKeepADS then
            desired = C.fovValue
        else
            desired = math.deg(2 * math.atan(math.tan(math.rad(C.fovValue / 2)) * ratio))
            desired = clampNum(desired, 5, 120)
        end
    end
    A.zoomTarget = math.tan(math.rad(desired / 2)) / math.tan(math.rad(base / 2))
    A.zoomSmooth = LerpNum(A.zoomSmooth or 1, clampNum(A.zoomTarget, 0.08, 1), 0.25)
    if math.abs(cur - desired) > 0.05 then
        pcall(function() cam.FieldOfView = desired end)
        A.lastSetFOV = desired
    else
        A.lastSetFOV = cur
    end
    if A.stretchOk ~= false then
        local okS = pcall(function() cam.ViewStretch = (C.fovStretch or 100) / 100 end)
        if not okS then A.stretchOk = false end
    end
end

local function RestoreFOV()
    local cam = A.cam or Workspace.CurrentCamera
    if cam then
        if A.origFOV then pcall(function() cam.FieldOfView = A.origFOV end) end
        if A.origStretch ~= nil then pcall(function() cam.ViewStretch = A.origStretch end) end
    end
    if LP then
        if A.origMaxZoom then pcall(function() LP.CameraMaxZoomDistance = A.origMaxZoom end) end
        if A.origMinZoom then pcall(function() LP.CameraMinZoomDistance = A.origMinZoom end) end
    end
    A.fovApplied = false
    A.lastSetFOV = nil
    A.desiredFOV = nil
end

local function SaveProp(inst, prop)
    local rec = A.optSaved[inst]
    if not rec then rec = {} A.optSaved[inst] = rec end
    if rec[prop] == nil then
        local ok, v = pcall(function() return inst[prop] end)
        if ok then rec[prop] = v else rec[prop] = false end
    end
end
local function RestoreAllProps()
    for inst, rec in pairs(A.optSaved) do
        for prop, v in pairs(rec) do
            if v ~= false then pcall(function() inst[prop] = v end) end
        end
    end
    A.optSaved = setmetatable({}, {__mode = "k"})
end
local function SaveScalars()
    if A.scalarsSaved then return end
    A.scalarsSaved = true
    local o = {}
    A.scalarOrig = o
    pcall(function() o.quality = settings().Rendering.QualityLevel end)
    pcall(function() o.meshDetail = settings().Rendering.MeshPartDetailLevel end)
    pcall(function() o.savedQuality = UserSettings():GetService("UserGameSettings").SavedQualityLevel end)
    pcall(function() o.shadows = Lighting.GlobalShadows end)
    pcall(function() o.fogEnd = Lighting.FogEnd end)
    pcall(function() o.shadowSoft = Lighting.ShadowSoftness end)
    pcall(function() o.diffuse = Lighting.EnvironmentDiffuseScale end)
    pcall(function() o.specular = Lighting.EnvironmentSpecularScale end)
    pcall(function() o.animThrottle = Workspace.ClientAnimatorThrottling end)
    pcall(function() o.interpThrottle = Workspace.InterpolationThrottling end)
    pcall(function() o.lod = Workspace.LevelOfDetail end)
    pcall(function() o.streamTarget = Workspace.StreamingTargetRadius end)
    pcall(function() o.streamMin = Workspace.StreamingMinRadius end)
    pcall(function() o.use2022 = game:GetService("MaterialService").Use2022Materials end)
end
local function RestoreScalars()
    if not A.scalarsSaved then return end
    local o = A.scalarOrig or {}
    pcall(function() if o.quality ~= nil then settings().Rendering.QualityLevel = o.quality end end)
    pcall(function() if o.meshDetail ~= nil then settings().Rendering.MeshPartDetailLevel = o.meshDetail end end)
    pcall(function() if o.savedQuality ~= nil then UserSettings():GetService("UserGameSettings").SavedQualityLevel = o.savedQuality end end)
    pcall(function() if o.shadows ~= nil then Lighting.GlobalShadows = o.shadows end end)
    pcall(function() if o.fogEnd ~= nil then Lighting.FogEnd = o.fogEnd end end)
    pcall(function() if o.shadowSoft ~= nil then Lighting.ShadowSoftness = o.shadowSoft end end)
    pcall(function() if o.diffuse ~= nil then Lighting.EnvironmentDiffuseScale = o.diffuse end end)
    pcall(function() if o.specular ~= nil then Lighting.EnvironmentSpecularScale = o.specular end end)
    pcall(function() if o.animThrottle ~= nil then Workspace.ClientAnimatorThrottling = o.animThrottle end end)
    pcall(function() if o.interpThrottle ~= nil then Workspace.InterpolationThrottling = o.interpThrottle end end)
    pcall(function() if o.lod ~= nil then Workspace.LevelOfDetail = o.lod end end)
    pcall(function() if o.streamTarget ~= nil then Workspace.StreamingTargetRadius = o.streamTarget end end)
    pcall(function() if o.streamMin ~= nil then Workspace.StreamingMinRadius = o.streamMin end end)
    pcall(function() if o.use2022 ~= nil then game:GetService("MaterialService").Use2022Materials = o.use2022 end end)
    A.scalarsSaved = false
    A.scalarOrig = nil
end
local function ApplyScalars(tier)
    if tier <= 0 then return end
    SaveScalars()
    if C.optQuality then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)
        pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01 end)
        if tier >= 2 then pcall(function() Workspace.ClientAnimatorThrottling = Enum.ClientAnimatorThrottlingMode.Enabled end) end
        if tier >= 2 then pcall(function() Workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Enabled end) end
        if tier >= 3 then pcall(function() Workspace.LevelOfDetail = Enum.ModelLevelOfDetail.Performance end) end
        if tier >= 4 then
            pcall(function() Workspace.StreamingTargetRadius = 128 end)
            pcall(function() Workspace.StreamingMinRadius = 64 end)
        end
    end
    if C.optLighting then
        pcall(function() Lighting.GlobalShadows = false end)
        pcall(function() Lighting.ShadowSoftness = 0 end)
        pcall(function() Lighting.EnvironmentDiffuseScale = 0 end)
        pcall(function() Lighting.EnvironmentSpecularScale = 0 end)
        pcall(function() Lighting.FogEnd = 5000 end)
        for _, ch in ipairs(Lighting:GetChildren()) do
            if ch:IsA("Atmosphere") then SaveProp(ch, "Density") pcall(function() ch.Density = 0 end) end
            if C.optPost and ch:IsA("PostEffect") then SaveProp(ch, "Enabled") pcall(function() ch.Enabled = false end) end
            if tier >= 3 and ch:IsA("Sky") then SaveProp(ch, "Parent") pcall(function() ch.Parent = nil end) end
            if tier >= 3 and ch:IsA("Atmosphere") then SaveProp(ch, "Parent") pcall(function() ch.Parent = nil end) end
        end
        local terr = Workspace:FindFirstChildOfClass("Terrain")
        if terr then
            for _, ch in ipairs(terr:GetChildren()) do
                if ch:IsA("Clouds") then SaveProp(ch, "Parent") pcall(function() ch.Parent = nil end) end
            end
        end
    end
    if C.optPost then
        for _, ch in ipairs(Lighting:GetChildren()) do
            if ch:IsA("PostEffect") then SaveProp(ch, "Enabled") pcall(function() ch.Enabled = false end) end
        end
    end
    if C.optTerrain then
        local terr2 = Workspace:FindFirstChildOfClass("Terrain")
        if terr2 then
            SaveProp(terr2, "WaterWaveSize") SaveProp(terr2, "WaterWaveSpeed") SaveProp(terr2, "WaterReflectance") SaveProp(terr2, "WaterTransparency")
            pcall(function() terr2.WaterWaveSize = 0 terr2.WaterWaveSpeed = 0 terr2.WaterReflectance = 0 terr2.WaterTransparency = 0 end)
            SaveProp(terr2, "Decoration")
            local okDec = pcall(function() terr2.Decoration = false end)
            if not okDec and sethiddenproperty then pcall(function() sethiddenproperty(terr2, "Decoration", false) end) end
        end
    end
    if tier >= 4 and C.optMaterial then
        pcall(function() game:GetService("MaterialService").Use2022Materials = false end)
    end
    if C.optFpsCap and setfpscap then
        if not A.fpsCapOrigin and getfpscap then
            pcall(function() local v = getfpscap() if type(v) == "number" then A.fpsCapOrigin = v end end)
        end
        pcall(function() setfpscap(tier >= 3 and 60 or 120) end)
    end
end
local function IsOwnStuff(inst)
    local char = LP and LP.Character
    if char and inst:IsDescendantOf(char) then return true end
    if A.cam and inst:IsDescendantOf(A.cam) then return true end
    return false
end
local function ApplyToInstance(inst, tier)
    if IsOwnStuff(inst) then return end
    pcall(function()
        if inst:IsA("BasePart") then
            if C.optMaterial and tier >= 2 then SaveProp(inst, "Material") SaveProp(inst, "Reflectance") inst.Material = Enum.Material.SmoothPlastic inst.Reflectance = 0 end
            if C.optShadow and tier >= 1 then SaveProp(inst, "CastShadow") inst.CastShadow = false end
            if inst:IsA("MeshPart") and C.optMaterial and tier >= 2 then
                SaveProp(inst, "TextureID") inst.TextureID = ""
                SaveProp(inst, "RenderFidelity") pcall(function() inst.RenderFidelity = Enum.RenderFidelity.Performance end)
            end
            if tier >= 4 and C.optMaterial and inst:IsA("MeshPart") then
                for _, ch in ipairs(inst:GetChildren()) do
                    if ch:IsA("SurfaceAppearance") then pcall(function() ch:Destroy() end) end
                end
            end
        elseif inst:IsA("Light") then
            if C.optEffects and tier >= 2 then SaveProp(inst, "Enabled") inst.Enabled = false end
        elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
            if C.optEffects and tier >= 4 then SaveProp(inst, "Enabled") inst.Enabled = false end
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            if C.optMaterial and tier >= 2 then SaveProp(inst, "Transparency") inst.Transparency = 1 end
            if C.optMaterial and tier >= 3 then SaveProp(inst, "Texture") pcall(function() inst.Texture = "" end) end
        elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") or inst:IsA("Beam") then
            if C.optEffects then
                if tier == 1 and inst:IsA("ParticleEmitter") then
                    SaveProp(inst, "Rate")
                    pcall(function() local r = inst.Rate inst.Rate = NumberRange.new(math.min(r.Min, 10), math.min(r.Max, 10)) end)
                elseif tier >= 2 then
                    SaveProp(inst, "Enabled") inst.Enabled = false
                    if inst:IsA("ParticleEmitter") then SaveProp(inst, "Rate") pcall(function() inst.Rate = NumberRange.new(0, 0) end) end
                end
            end
        end
    end)
end
local function EnqueueInstance(inst)
    if A.optQSeen[inst] then return end
    A.optQSeen[inst] = true
    table.insert(A.optQueue, inst)
end
local function BuildQueue()
    A.optQueue = {}
    A.optQSeen = {}
    for _, d in ipairs(Workspace:GetDescendants()) do EnqueueInstance(d) end
end
local function ProcessOptQueue()
    if A.optTier <= 0 then return end
    local deadline = tick() + 0.004
    while #A.optQueue > 0 do
        local inst = table.remove(A.optQueue)
        A.optQSeen[inst] = nil
        if inst and inst.Parent then ApplyToInstance(inst, A.optTier) end
        if tick() > deadline then break end
    end
end
local function RestoreOptimizer()
    RestoreAllProps()
    RestoreScalars()
    if A.fpsCapOrigin and setfpscap then pcall(function() setfpscap(A.fpsCapOrigin) end) end
    A.fpsCapOrigin = nil
    A.optQueue = {}
    A.optQSeen = {}
    A.optTier = 0
    A.optAppliedTier = 0
end
local function SetTier(tier, force)
    tier = clampNum(tier or 0, 0, 4)
    if tier == A.optAppliedTier and not force then return end
    if A.optAppliedTier > 0 then
        RestoreAllProps()
        RestoreScalars()
        if A.fpsCapOrigin and setfpscap then pcall(function() setfpscap(A.fpsCapOrigin) end) end
        A.fpsCapOrigin = nil
    end
    A.optTier = tier
    A.optAppliedTier = tier
    if tier > 0 then
        ApplyScalars(tier)
        BuildQueue()
        if tier >= 2 and C.optAvatar and A.stripAvatar then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then A.stripAvatar(p.Character) end
            end
        end
    else
        A.optQueue = {}
        A.optQSeen = {}
    end
end
local function OptApplyFromUI()
    SetTier(C.optSliderTier, true)
end
local function StripAvatar(char)
    if not char then return end
    for _, ch in ipairs(char:GetDescendants()) do
        pcall(function()
            if ch:IsA("Shirt") then SaveProp(ch, "ShirtTemplate") ch.ShirtTemplate = ""
            elseif ch:IsA("Pants") then SaveProp(ch, "PantsTemplate") ch.PantsTemplate = ""
            elseif ch:IsA("Accessory") then
                local h = ch:FindFirstChild("Handle")
                if h then SaveProp(h, "Transparency") h.Transparency = 1 end
            end
        end)
    end
end
A.stripAvatar = StripAvatar
local function AdaptiveStep()
    if not C.optAuto then return end
    local f = A.fpsEMA
    local t = A.optTier
    local nt = t
    if f < 34 then nt = math.min(4, t + 1)
    elseif f < 42 and t < 2 then nt = t + 1
    elseif f < 50 and t < 1 then nt = 1
    elseif f > 72 and t > (C.optSliderTier or 0) then nt = t - 1 end
    if nt ~= t then SetTier(nt) end
end

A.hideAllEsp = function()
    for _, b in pairs(A.esp) do HideBundle(b) end
end

local fovCircle = NewDraw("Circle", {Visible = false, Filled = false, Thickness = 1, Transparency = 1, NumSides = 48, Radius = 150, Color = Color3.fromRGB(255, 255, 255), ZIndex = 5})
local hudText = NewDraw("Text", {Visible = false, Outline = true, Size = 13, Transparency = 1, Color = Color3.fromRGB(255, 255, 255), ZIndex = 5})
A.fovCircle = fovCircle A.hudText = hudText
local function HudStep()
    local cam = A.cam
    if fovCircle and cam then
        if C.silentShowFOV and C.silentEnabled then
            fovCircle.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
            fovCircle.Radius = EffFOV(C.silentFOV)
            fovCircle.Color = A.silentTarget and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
    if hudText then
        hudText.Text = tostring(math.floor(A.fpsEMA + 0.5)) .. " FPS   " .. tostring(math.floor(A.ping * 1000 + 0.5)) .. " ms   discord@kurudojindegomen"
        hudText.Position = Vector2.new(10, 10)
        hudText.Visible = true
    end
end

local function BindPlayer(p)
    local function onChar(char)
        A.cache[p] = {vel = Vector3.new(), accel = Vector3.new()}
        if p ~= LP and C.optAvatar and A.optTier >= 2 then
            task.defer(function() StripAvatar(char) end)
        end
    end
    Track(p.CharacterAdded:Connect(onChar))
    if p.Character then onChar(p.Character) end
end
for _, p in ipairs(Players:GetPlayers()) do BindPlayer(p) end
Track(Players.PlayerAdded:Connect(function(p) BindPlayer(p) RefreshTeamMode() end))
Track(Players.PlayerRemoving:Connect(function(p)
    RemoveBundle(p)
    A.cache[p] = nil
    A.visCache[p] = nil
    if A.triggerTarget == p then A.triggerTarget = nil end
    if A.silentTarget == p then A.silentTarget = nil A.silentPartObj = nil end
    RefreshTeamMode()
end))
Track(Workspace.DescendantAdded:Connect(function(inst)
    if A.optTier > 0 then EnqueueInstance(inst) end
end))

local Unload
local function DestroyGUI()
    if A.guiConns then
        for _, c in ipairs(A.guiConns) do pcall(function() c:Disconnect() end) end
        A.guiConns = {}
    end
    if A.guiRoot then pcall(function() A.guiRoot:Destroy() end) A.guiRoot = nil end
end

local function BuildUI()
    A.guiControls = {}
    GST.__aero_gui_controls = A.guiControls
    GST.__aero_gui_window = true
    local COL = {
        bg = Color3.fromRGB(15, 15, 18), panel = Color3.fromRGB(23, 23, 29),
        panel2 = Color3.fromRGB(32, 32, 40), elev = Color3.fromRGB(41, 41, 51),
        line = Color3.fromRGB(47, 47, 59), text = Color3.fromRGB(240, 240, 244),
        muted = Color3.fromRGB(150, 150, 162), accent = Color3.fromRGB(240, 240, 244),
        onAccent = Color3.fromRGB(15, 15, 18), knobOff = Color3.fromRGB(140, 140, 150),
    }
    local function mk(class, props, parent)
        local ok, o = pcall(function()
            local i = Instance.new(class)
            if props then for k, v in pairs(props) do i[k] = v end end
            if parent then i.Parent = parent end
            return i
        end)
        if ok then return o end
        return nil
    end
    local function addCorner(o, r)
        if o then mk("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
    end
    local function addStroke(o, col, th)
        if o then mk("UIStroke", {Color = col or COL.line, Thickness = th or 1}, o) end
    end
    if not A.guiConns then A.guiConns = {} end
    local function guiTrack(c)
        if c then table.insert(A.guiConns, c) table.insert(A.conns, c) end
        return c
    end
    local function onGui(obj, ev, fn)
        if not obj then return end
        pcall(function() guiTrack(obj[ev]:Connect(fn)) end)
    end
    local function onUIS(ev, fn)
        pcall(function() guiTrack(UIS[ev]:Connect(fn)) end)
    end
    local function regCtl(kind, tabName, title, initial, cb)
        local e = {kind = kind, title = title, tab = tabName, value = initial}
        e.callback = function(v)
            e.value = v
            if cb then cb(v) end
            if e._refresh then pcall(e._refresh, v) end
        end
        table.insert(A.guiControls, e)
        return e
    end
    local parent = nil
    pcall(function() if gethui then parent = gethui() end end)
    if not parent then pcall(function() if protect_gui then parent = protect_gui() end end) end
    if not parent then pcall(function() parent = LP.PlayerGui end) end
    local gui = mk("ScreenGui", {Name = "Chat", ResetOnSpawn = false, DisplayOrder = 10}, parent)
    A.guiRoot = gui
    local vpY, vpX = 800, 1000
    pcall(function()
        local vs = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
        if vs then vpY = vs.Y vpX = vs.X end
    end)
    local winH = math.min(330, vpY - 40)
    if winH < 200 then winH = 200 end
    local winW = math.min(460, vpX - 16)
    if winW < 280 then winW = math.min(460, vpX) end
    local win = mk("Frame", {Name = "Window", Size = UDim2.fromOffset(winW, winH), Position = UDim2.new(0.5, -winW / 2, 0.5, -winH / 2), BackgroundColor3 = COL.bg, BorderSizePixel = 0}, gui)
    A.winFrame = win
    addCorner(win, 12)
    addStroke(win, COL.line, 1)
    mk("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 37), BackgroundColor3 = COL.line, BackgroundTransparency = 0.4, BorderSizePixel = 0}, win)
    mk("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 73), BackgroundColor3 = COL.line, BackgroundTransparency = 0.4, BorderSizePixel = 0}, win)
    local top = mk("Frame", {Name = "TopBar", Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = COL.bg, BorderSizePixel = 0, Active = true}, win)
    mk("TextLabel", {Size = UDim2.new(0, 60, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Text = "AERO", TextColor3 = COL.text, Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left}, top)
    mk("TextLabel", {Size = UDim2.new(0, 50, 1, 0), Position = UDim2.fromOffset(56, 0), BackgroundTransparency = 1, Text = "v8.6", TextColor3 = COL.muted, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, top)
    mk("TextLabel", {Size = UDim2.new(1, -200, 1, 0), Position = UDim2.fromOffset(110, 0), BackgroundTransparency = 1, Text = "discord@kurudojindegomen", TextColor3 = COL.muted, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left}, top)
    local minBtn = mk("TextButton", {Size = UDim2.fromOffset(34, 38), Position = UDim2.new(1, -72, 0, 0), BackgroundTransparency = 1, Text = "—", TextColor3 = COL.muted, Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false}, top)
    local closeBtn = mk("TextButton", {Size = UDim2.fromOffset(34, 38), Position = UDim2.new(1, -36, 0, 0), BackgroundTransparency = 1, Text = "✕", TextColor3 = COL.muted, Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false}, top)
    local openBtn = mk("TextButton", {Name = "OpenBtn", Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -58, 0.5, -23), BackgroundColor3 = COL.panel2, Text = "A", TextColor3 = COL.text, Font = Enum.Font.GothamBold, TextSize = 17, AutoButtonColor = false, Active = true}, gui)
    addCorner(openBtn, 23)
    addStroke(openBtn, COL.line, 1)
    A.guiHitRects = {win, openBtn}
    local tabBar = mk("ScrollingFrame", {Name = "TabBar", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.fromOffset(560, 0)}, win)
    mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}, tabBar)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 4)}, tabBar)
    local body = mk("Frame", {Name = "Body", Size = UDim2.new(1, 0, 1, -74), Position = UDim2.fromOffset(0, 74), BackgroundTransparency = 1, BorderSizePixel = 0}, win)
    local minimized = false
    onGui(minBtn, "MouseButton1Click", function()
        minimized = not minimized
        if tabBar then tabBar.Visible = not minimized end
        if body then body.Visible = not minimized end
        if win then win.Size = UDim2.fromOffset(winW, minimized and 38 or winH) end
    end)
    onGui(closeBtn, "MouseButton1Click", function() if win then win.Visible = false end end)
    onGui(openBtn, "MouseButton1Click", function()
        if (os.clock() - (A.dragMovedAt or 0)) < 0.3 then return end
        if win then win.Visible = not win.Visible end
    end)
    local function makeDraggable(handle, target)
        if not handle or not target then return end
        local dragging, dragStart, startPos = false, nil, nil
        onGui(handle, "InputBegan", function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = target.Position
            end
        end)
        onUIS("InputChanged", function(input)
            if dragging and dragStart and target.Parent and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                if d.Magnitude > 10 then A.dragMovedAt = os.clock() end
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        onUIS("InputEnded", function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
    end
    makeDraggable(top, win)
    makeDraggable(openBtn, openBtn)
    local sliderDrag = nil
    onUIS("InputChanged", function(input)
        if sliderDrag and A.guiRoot == gui and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            sliderDrag(input.Position.X)
        end
    end)
    onUIS("InputEnded", function()
        sliderDrag = nil
        if A.activeScrollFrame then
            local f = A.activeScrollFrame
            A.activeScrollFrame = nil
            pcall(function() f.ScrollingEnabled = true end)
        end
    end)
    local tabObjs = {}
    local tabCount = 0
    local function selectTab(t)
        for _, o in ipairs(tabObjs) do
            local sel = (o == t)
            if o.content then o.content.Visible = sel end
            if o.btn then
                o.btn.TextColor3 = sel and COL.onAccent or COL.muted
                o.btn.BackgroundColor3 = sel and COL.accent or COL.panel
                o.btn.BackgroundTransparency = sel and 0 or 1
            end
        end
    end
    local function NewTab(title)
        tabCount = tabCount + 1
        local t = {name = title, order = 0}
        local btn = mk("TextButton", {Size = UDim2.fromOffset(74, 28), LayoutOrder = tabCount, BackgroundColor3 = COL.panel, BackgroundTransparency = 1, Text = title, TextColor3 = COL.muted, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false}, tabBar)
        addCorner(btn, 9)
        t.btn = btn
        local content = mk("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = COL.line, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false}, body)
        mk("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)}, content)
        mk("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, content)
        t.content = content
        table.insert(tabObjs, t)
        onGui(btn, "MouseButton1Click", function() selectTab(t) end)
        local function nextOrder() t.order = t.order + 1 return t.order * 10 end
        local function rowBase(h)
            local row = mk("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = COL.panel, BorderSizePixel = 0, LayoutOrder = nextOrder()}, content)
            addCorner(row, 10)
            return row
        end
        local function titleLabels(row, spec, w)
            mk("TextLabel", {Size = UDim2.new(1, -(w or 60), 0, 20), Position = UDim2.fromOffset(10, 5), BackgroundTransparency = 1, Text = spec.Title, TextColor3 = COL.text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, row)
            if spec.Desc then
                mk("TextLabel", {Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 24), BackgroundTransparency = 1, Text = spec.Desc, TextColor3 = COL.muted, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, row)
            end
        end
        function t:Toggle(spec)
            local e = regCtl("Toggle", title, spec.Title, spec.Default, spec.Callback)
            local row = rowBase(spec.Desc and 44 or 38)
            titleLabels(row, spec, 70)
            local pill = mk("Frame", {Size = UDim2.fromOffset(44, 24), Position = UDim2.new(1, -54, 0.5, -12), BackgroundColor3 = COL.panel2, BorderSizePixel = 0}, row)
            addCorner(pill, 12)
            addStroke(pill, COL.line, 1)
            local knob = mk("Frame", {Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = COL.knobOff, BorderSizePixel = 0}, pill)
            addCorner(knob, 10)
            local hit = mk("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, row)
            local function refresh(v)
                if pill then pill.BackgroundColor3 = v and COL.accent or COL.panel2 end
                if knob then
                    knob.Position = UDim2.fromOffset(v and 22 or 2, 2)
                    knob.BackgroundColor3 = v and Color3.fromRGB(15, 15, 18) or COL.knobOff
                end
            end
            e._refresh = refresh
            pcall(refresh, spec.Default)
            onGui(hit, "MouseButton1Click", function() e.callback(not e.value) end)
            return e
        end
        function t:Slider(spec)
            local val = spec.Value or {}
            local mn, mx, df = val.Min or 0, val.Max or 100, val.Default or 0
            local step = spec.Step or 1
            local e = regCtl("Slider", title, spec.Title, df, spec.Callback)
            local row = rowBase(spec.Desc and 58 or 52)
            titleLabels(row, spec, 70)
            local vl = mk("TextLabel", {Size = UDim2.new(0, 56, 0, 20), Position = UDim2.new(1, -66, 0, 5), BackgroundTransparency = 1, Text = tostring(df), TextColor3 = COL.text, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right}, row)
            local track = mk("Frame", {Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, spec.Desc and 42 or 36), BackgroundColor3 = COL.panel2, BorderSizePixel = 0, Active = true}, row)
            addCorner(track, 3)
            local fill = mk("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = COL.accent, BorderSizePixel = 0}, track)
            addCorner(fill, 3)
            local thumb = mk("Frame", {Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = COL.accent, BorderSizePixel = 0}, track)
            addCorner(thumb, 8)
            addStroke(thumb, COL.line, 1)
            local function refresh(v)
                local r = 0
                if mx > mn then r = (v - mn) / (mx - mn) end
                if fill then fill.Size = UDim2.fromScale(r, 1) end
                if thumb then thumb.Position = UDim2.fromScale(r, 0.5) end
                if vl then vl.Text = tostring(v) end
            end
            e._refresh = refresh
            pcall(refresh, df)
            local function setFromX(absX)
                if not track then return end
                local ok, ratio = pcall(function()
                    local px = track.AbsolutePosition.X
                    local sx = track.AbsoluteSize.X
                    if sx <= 0 then return nil end
                    return (absX - px) / sx
                end)
                if not ok or not ratio then return end
                if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
                local raw = mn + ratio * (mx - mn)
                local v = math.floor(raw / step + 0.5) * step
                if v < mn then v = mn elseif v > mx then v = mx end
                if v ~= e.value then e.callback(v) end
            end
            onGui(track, "InputBegan", function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    setFromX(input.Position.X)
                    sliderDrag = setFromX
                    if content then
                        A.activeScrollFrame = content
                        pcall(function() content.ScrollingEnabled = false end)
                    end
                end
            end)
            return e
        end
        function t:Dropdown(spec)
            local e = regCtl("Dropdown", title, spec.Title, spec.Default, spec.Callback)
            local row = rowBase(38)
            titleLabels(row, spec, 130)
            local vl = mk("TextLabel", {Size = UDim2.new(0, 110, 0, 20), Position = UDim2.new(1, -120, 0.5, -10), BackgroundTransparency = 1, Text = tostring(spec.Default or "") .. "  ▾", TextColor3 = COL.text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right}, row)
            local hit = mk("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, row)
            local list = mk("Frame", {Size = UDim2.new(1, 0, 0, #(spec.Values or {}) * 32), BackgroundColor3 = COL.elev, BorderSizePixel = 0, LayoutOrder = (t.order * 10) + 5, Visible = false}, content)
            addCorner(list, 10)
            addStroke(list, COL.line, 1)
            if list then
                mk("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, list)
                for i, opt in ipairs(spec.Values or {}) do
                    local ob = mk("TextButton", {Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Text = "  " .. opt, TextColor3 = COL.text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = i}, list)
                    onGui(ob, "MouseButton1Click", function()
                        e.callback(opt)
                        list.Visible = false
                    end)
                end
            end
            e._refresh = function(v) if vl then vl.Text = tostring(v) .. "  ▾" end end
            onGui(hit, "MouseButton1Click", function() if list then list.Visible = not list.Visible end end)
            return e
        end
        function t:Button(spec)
            local e = regCtl("Button", title, spec.Title, nil, spec.Callback)
            local btn = mk("TextButton", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = COL.panel2, Text = spec.Title, TextColor3 = COL.text, Font = Enum.Font.Gotham, TextSize = 13, AutoButtonColor = false, LayoutOrder = nextOrder()}, content)
            addCorner(btn, 10)
            onGui(btn, "MouseButton1Click", function() e.callback() end)
            return e
        end
        function t:Paragraph(spec)
            local row = rowBase(spec.Desc and 44 or 30)
            titleLabels(row, spec, 20)
            return row
        end
        return t
    end
    local tSil = NewTab("サイレント")
    local tEsp = NewTab("ESP")
    local tFov = NewTab("視点・FOV")
    local tOpt = NewTab("軽量化")
    local tSet = NewTab("設定")
    if tabObjs[1] then selectTab(tabObjs[1]) end
    local function populate()
    tSil:Toggle({Title = "サイレントエイム有効", Default = C.silentEnabled, Callback = function(v) C.silentEnabled = v pcall(SyncSilentHooks) SaveSoon() end})
    tSil:Dropdown({Title = "狙う部位", Values = {"頭", "胴体"}, Default = C.silentPart, Callback = function(v) C.silentPart = v SaveSoon() end})
    tSil:Slider({Title = "FOV半径(px)", Step = 1, Value = {Min = 40, Max = 600, Default = C.silentFOV}, Callback = function(v) C.silentFOV = v SaveSoon() end})
    tSil:Toggle({Title = "予測", Default = C.silentPrediction, Callback = function(v) C.silentPrediction = v SaveSoon() end})
    tSil:Slider({Title = "予測倍率 (%)", Step = 5, Value = {Min = 0, Max = 200, Default = C.silentPredictScale}, Callback = function(v) C.silentPredictScale = v SaveSoon() end})
    tSil:Slider({Title = "命中率(%)", Step = 1, Value = {Min = 1, Max = 100, Default = C.silentHitChance}, Callback = function(v) C.silentHitChance = v SaveSoon() end})
    tSil:Toggle({Title = "FOV円表示", Desc = "サイレントの有効範囲を円で表示", Default = C.silentShowFOV, Callback = function(v) C.silentShowFOV = v SaveSoon() end})
    tSil:Toggle({Title = "チームチェック", Default = C.teamCheck, Callback = function(v) C.teamCheck = v SaveSoon() end})
    tSil:Toggle({Title = "トリガーボット", Desc = "照準が敵に合ったら自動で撃つ。スマホではFireリモートで発射する", Default = C.triggerEnabled, Callback = function(v) C.triggerEnabled = v pcall(SyncSilentHooks) SaveSoon() end})
    tSil:Slider({Title = "トリガー遅延(ms)", Step = 5, Value = {Min = 0, Max = 300, Default = C.triggerDelay}, Callback = function(v) C.triggerDelay = v SaveSoon() end})
    tSil:Slider({Title = "トリガー間隔(ms)", Desc = "リモート発射の最小間隔", Step = 5, Value = {Min = 50, Max = 300, Default = C.triggerInterval}, Callback = function(v) C.triggerInterval = v SaveSoon() end})

    tEsp:Toggle({Title = "ESP有効", Default = C.espEnabled, Callback = function(v) C.espEnabled = v SaveSoon() end})
    tEsp:Toggle({Title = "ボックス", Default = C.espBox, Callback = function(v) C.espBox = v SaveSoon() end})
    tEsp:Toggle({Title = "骨格", Default = C.espSkeleton, Callback = function(v) C.espSkeleton = v SaveSoon() end})
    tEsp:Toggle({Title = "トレーサー", Default = C.espTracer, Callback = function(v) C.espTracer = v SaveSoon() end})
    tEsp:Toggle({Title = "HPバー", Default = C.espHPBar, Callback = function(v) C.espHPBar = v SaveSoon() end})
    tEsp:Toggle({Title = "HP数値", Default = C.espHPText, Callback = function(v) C.espHPText = v SaveSoon() end})
    tEsp:Toggle({Title = "名前+距離", Default = C.espNameDist, Callback = function(v) C.espNameDist = v SaveSoon() end})
    tEsp:Toggle({Title = "頭ドット", Default = C.espHeadDot, Callback = function(v) C.espHeadDot = v SaveSoon() end})
    tEsp:Toggle({Title = "味方表示", Default = C.espShowTeam, Callback = function(v) C.espShowTeam = v SaveSoon() end})
    tEsp:Toggle({Title = "見えている敵の色変更", Default = C.espVisColor, Callback = function(v) C.espVisColor = v SaveSoon() end})
    tEsp:Slider({Title = "描画距離", Step = 10, Value = {Min = 100, Max = 2000, Default = C.espRenderDist}, Callback = function(v) C.espRenderDist = v SaveSoon() end})

    tFov:Toggle({Title = "FOV有効", Default = C.fovEnabled, Callback = function(v) C.fovEnabled = v FovStep() SaveSoon() end})
    tFov:Slider({Title = "FOV", Step = 1, Value = {Min = 70, Max = 120, Default = C.fovValue}, Callback = function(v) C.fovValue = v FovStep() SaveSoon() end})
    tFov:Slider({Title = "画面ストレッチ (%)", Step = 5, Value = {Min = 50, Max = 200, Default = C.fovStretch}, Callback = function(v) C.fovStretch = v FovStep() SaveSoon() end})
    tFov:Toggle({Title = "ADS中もFOV維持", Default = C.fovKeepADS, Callback = function(v) C.fovKeepADS = v SaveSoon() end})

    tOpt:Slider({Title = "軽量化の強さ (0=OFF / 4=最大)", Desc = "重い・熱い時ほど上げる。4は一部元に戻せない項目あり", Step = 1, Value = {Min = 0, Max = 4, Default = C.optSliderTier}, Callback = function(v) C.optSliderTier = v OptApplyFromUI() SaveSoon() end})
    tOpt:Toggle({Title = "自動調整 (FPS連動)", Desc = "ONの間はFPSを見て強さを勝手に変える", Default = C.optAuto, Callback = function(v) C.optAuto = v if not v then SetTier(C.optSliderTier, true) end SaveSoon() end})
    tOpt:Toggle({Title = "描画品質低下", Default = C.optQuality, Callback = function(v) C.optQuality = v OptApplyFromUI() SaveSoon() end})
    tOpt:Toggle({Title = "ライティング軽量化", Default = C.optLighting, Callback = function(v) C.optLighting = v OptApplyFromUI() SaveSoon() end})
    tOpt:Toggle({Title = "ポストプロセスOFF", Default = C.optPost, Callback = function(v) C.optPost = v OptApplyFromUI() SaveSoon() end})
    tOpt:Toggle({Title = "マテリアル/テクスチャ軽量化", Default = C.optMaterial, Callback = function(v) C.optMaterial = v OptApplyFromUI() SaveSoon() end})
    tOpt:Toggle({Title = "地形/空 軽量化", Default = C.optTerrain, Callback = function(v) C.optTerrain = v OptApplyFromUI() SaveSoon() end})
    tOpt:Toggle({Title = "エフェクトOFF", Default = C.optEffects, Callback = function(v) C.optEffects = v OptApplyFromUI() SaveSoon() end})
    tOpt:Toggle({Title = "影OFF", Default = C.optShadow, Callback = function(v) C.optShadow = v OptApplyFromUI() SaveSoon() end})
    tOpt:Toggle({Title = "他人アバター軽量化", Default = C.optAvatar, Callback = function(v) C.optAvatar = v OptApplyFromUI() SaveSoon() end})
    tOpt:Toggle({Title = "FPS上限", Desc = "強さ1-2は120、3以上は60（発熱対策）", Default = C.optFpsCap, Callback = function(v) C.optFpsCap = v OptApplyFromUI() SaveSoon() end})
    tOpt:Button({Title = "今すぐ最適化を再適用", Callback = function() OptApplyFromUI() end})
    tOpt:Button({Title = "最適化を復元", Callback = function()
        RestoreOptimizer()
        C.optSliderTier = 0
        C.optAuto = false
        SaveConfig()
        DestroyGUI()
        BuildUI()
    end})

    tSet:Toggle({Title = "自動再実行 (サーバー移動)", Default = C.autoExecute, Callback = function(v) C.autoExecute = v SaveSoon() end})
    tSet:Button({Title = "設定を保存", Callback = function() SaveConfig() end})
    tSet:Button({Title = "設定をロード", Callback = function()
        LoadConfig()
        RestoreOptimizer()
        pcall(SyncSilentHooks)
        SetTier(C.optSliderTier or 0, true)
        DestroyGUI()
        BuildUI()
        FovStep()
    end})
    tSet:Button({Title = "設定リセット", Callback = function()
        for k, v in pairs(CDEF) do C[k] = v end
        RestoreOptimizer()
        RestoreFOV()
        pcall(SyncSilentHooks)
        SaveConfig()
        DestroyGUI()
        BuildUI()
        FovStep()
    end})
    tSet:Button({Title = "アンロード", Callback = function() if Unload then Unload() end end})
    end
    local okPop, errPop = pcall(populate)
    if not okPop then print("[AERO] GUI populate failed: " .. tostring(errPop)) end
end

Unload = function(replacing)
    if A.unloaded then return end
    A.unloaded = true
    if not replacing then GST.__aero_noauto = true end
    A.hooksOn = false
    if A.oldNamecall then pcall(function() hookmetamethod(game, "__namecall", A.oldNamecall) end) A.oldNamecall = nil end
    pcall(function() RunService:UnbindFromRenderStep("AEROCam") end)
    for _, c in ipairs(A.conns) do pcall(function() c:Disconnect() end) end
    A.conns = {}
    local objs = {}
    for o in pairs(A.drawSet) do table.insert(objs, o) end
    for _, o in ipairs(objs) do RemoveDraw(o) end
    A.esp = {}
    RestoreOptimizer()
    RestoreFOV()
    DestroyGUI()
    GST.__aero_unload = nil
end
GST.__aero_unload = Unload

Track(RunService.RenderStepped:Connect(function(dt)
    if A.unloaded then return end
    if dt <= 0 or dt > 0.25 then dt = 1 / 60 end
    A.frame = A.frame + 1
    A.fpsEMA = LerpNum(A.fpsEMA, 1 / dt, 0.05)
    if A.fireHeld then
        if A.fireTouch then A.fireHeldAt = tick() end
        pcall(function()
            if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then A.fireHeldAt = tick() end
        end)
    end
    SafeCall("cache", CacheStep, dt)
    SafeCall("fov", FovStep)
    SafeCall("silent", RefreshSilentTarget)
    SafeCall("trigger", TriggerStep)
    SafeCall("esp", EspStep)
    SafeCall("optq", ProcessOptQueue)
    SafeCall("hud", HudStep)
end))
local function AEROCamStep()
    if A.unloaded then return end
    if A.desiredFOV then
        local cam2 = A.cam
        if cam2 and math.abs(cam2.FieldOfView - A.desiredFOV) > 0.05 then
            pcall(function() cam2.FieldOfView = A.desiredFOV end)
        end
    end
end
RunService:BindToRenderStep("AEROCam", Enum.RenderPriority.Last.Value + 100, function() pcall(AEROCamStep) end)
Track(RunService.Heartbeat:Connect(function()
    if A.unloaded then return end
    if A.desiredFOV then
        local cam = A.cam
        if cam and math.abs(cam.FieldOfView - A.desiredFOV) > 0.05 then pcall(function() cam.FieldOfView = A.desiredFOV end) end
    end
end))
task.spawn(function()
    while not A.unloaded do
        task.wait(0.25)
        pcall(function()
            local pv = LP and LP:GetNetworkPing()
            if type(pv) == "number" then
                A.ping = LerpNum(A.ping, clampNum(pv, 0.01, 0.5), 0.4)
            end
        end)
        SafeCall("adaptive", AdaptiveStep)
    end
end)

LoadConfig()
pcall(SyncSilentHooks)
local okGui, errGui = pcall(BuildUI)
if not okGui then print("[AERO] GUI build failed: " .. tostring(errGui)) end
pcall(FovStep)
if C.optSliderTier and C.optSliderTier > 0 then pcall(function() SetTier(C.optSliderTier, true) end) end
if C.autoExecute and queue_on_teleport and not GST.__aero_noauto then
    pcall(function()
        queue_on_teleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/0rnx4/AERO/main/main.lua"))()')
    end)
end
GST.__aero_noauto = false
print("[AERO] v8.6 loaded.")