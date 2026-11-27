local function FindFireRemote()
    local found = nil
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local kin = rs and rs:FindFirstChild("Kinetic")
        found = kin and kin:FindFirstChild("Fire")
        if found and not found:IsA("RemoteEvent") then found = nil end
    end)
    if found then
        if A.fireRemote ~= found then A.fireRemote = found A.fireSeen = false end
        return found
    end
    if A.fireRemote and A.fireRemote.Parent then return A.fireRemote end
    local nowS = tick()
    if not A.lastRemoteScan or (nowS - A.lastRemoteScan) >= 2 then
        A.lastRemoteScan = nowS
        local best = nil
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            if rs then
                for _, d in ipairs(rs:GetDescendants()) do
                    local okI, isRE = pcall(function() return d:IsA("RemoteEvent") end)
                    if okI and isRE and d.Name == "Fire" then
                        local par = d.Parent
                        local pn = par and par.Name and par.Name:lower() or ""
                        if pn:find("kinetic", 1, true) or pn:find("weapon", 1, true) then best = d break end
                    end
                end
            end
        end)
        if best and A.fireRemote ~= best then A.fireRemote = best A.fireSeen = false end
    end
    if A.fireRemote and not A.fireRemote.Parent then A.fireRemote = nil A.fireSeen = false end
    return A.fireRemote
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
    if A.silentRollOk == nil then A.silentRollOk = (math.random(1, 100) <= (C.silentHitChance or 100)) end
    if not A.silentRollOk then return nil end
    if A.silentGoalFrame == A.frame and A.silentGoalFor == part then return A.silentGoalCache end
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

local function IsFireShaped(remote, ...)
    local okA, isRE = pcall(function() return remote:IsA("RemoteEvent") end)
    if not okA or not isRE then return false end
    local nm = remote.Name
    local shaped = (nm == "Fire")
    if not shaped then
        local par = remote.Parent
        local pn = par and par.Name and par.Name:lower() or ""
        if pn:find("kinetic", 1, true) or pn:find("weapon", 1, true) then shaped = true end
    end
    if not shaped then return false end
    if select("#", ...) < 6 then return false end
    local a1, a2, a3, a4, a5, a6 = ...
    if not (type(a1) == "string" or typeof(a1) == "Instance") then return false end
    if typeof(a2) ~= "Vector3" or typeof(a3) ~= "Vector3" then return false end
    if not (typeof(a4) == "Instance" or a4 == nil) then return false end
    if typeof(a5) ~= "Vector3" then return false end
    if type(a6) ~= "number" then return false end
    return true
end

A.hm = hookmetamethod or GST.hookmetamethod
A.gnm = getnamecallmethod or GST.getnamecallmethod
A.grmt = getrawmetatable or GST.getrawmetatable
A.cc = checkcaller or GST.checkcaller

local function RestoreNamecallHook()
    local prev = A.oldNamecall
    if not prev then return true end
    local hm = A.hm or hookmetamethod
    if not hm then return false end
    local okR = pcall(function() hm(game, "__namecall", prev) end)
    if okR then A.oldNamecall = nil A.lastHookFn = nil end
    return okR
end
local function InstallHooks()
    RestoreNamecallHook()
    A.hooksOn = false
    local hm = A.hm or hookmetamethod
    if not hm then A.hookStage = "gate" return end
    local grmt = A.grmt or getrawmetatable
    local gnm = A.gnm or getnamecallmethod
    if not gnm then A.hookStage = "gate" return end
    local cc = A.cc or checkcaller
    local ncc = newcclosure or GST.newcclosure or function(f) return f end
    local inHook = false
    local oldNamecall
    local dispatched = false
    local function handleFire(self, ...)
        if self ~= A.fireRemote then return false end
        local argc = select("#", ...)
        if argc < 5 then return false end
        local a1 = select(1, ...)
        if not (type(a1) == "string" or typeof(a1) == "Instance") then return false end
        if typeof(select(5, ...)) ~= "Vector3" then return false end
        if argc >= 6 and type(select(6, ...)) ~= "number" then return false end
        A.silentRollOk = nil
        if not A.silentPartObj then RefreshSilentTarget() end
        local goal = SilentGoal()
        if goal and A.silentTarget then
            local okA, alive = pcall(IsAlive, A.silentTarget)
            if okA and not alive then
                RefreshSilentTarget()
                goal = SilentGoal()
            end
        end
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
        dispatched = true
        return true, oldNamecall(self, table.unpack(args))
    end
    local hookFn
    local hookRaw
    local function pass(self, ...)
            dispatched = true
            return oldNamecall(self, ...)
        end
        local function hookCore(self, ...)
        if A.unloaded then return pass(self, ...) end
        if inHook then return pass(self, ...) end
        local method = gnm()
        if method ~= "FireServer" then return pass(self, ...) end
        if IsAcRemote(self) then return pass(self, ...) end
        if not A.fireRemote then FindFireRemote() end
        if self ~= A.fireRemote then
            if IsFireShaped(self, ...) and not A.fireSeen then
                A.fireRemote = self
                A.fireSeen = true
            else
                return pass(self, ...)
            end
        else
            A.fireSeen = true
        end
        if cc and cc() then return pass(self, ...) end
        local seqArg = select(6, ...)
        if type(seqArg) == "number" and seqArg > (A.fireSeq or 0) then A.fireSeq = seqArg end
        A.lastFire = tick()
        if not C.silentEnabled then return pass(self, ...) end
        inHook = true
        local res = {pcall(handleFire, self, ...)}
        inHook = false
        if res[1] and res[2] then return res[3], res[4], res[5], res[6], res[7], res[8], res[9], res[10] end
        if dispatched then return end
        return pass(self, ...)
    end
    hookRaw = function(self, ...)
        if not oldNamecall then
            local f = A.lastKnownNC or A.oldNamecall
            if type(f) == "function" and f ~= hookFn and f ~= hookRaw then oldNamecall = f A.oldNamecall = f
            else return end
        end
        dispatched = false
        local res = table.pack(pcall(hookCore, self, ...))
        if res[1] then return table.unpack(res, 2, res.n) end
        if dispatched then error(res[2], 0) end
        return oldNamecall(self, ...)
    end
    hookFn = ncc(hookRaw)
    local prevNC = nil
    pcall(function()
        local mt = grmt(game)
        if mt and type(mt.__namecall) == "function" and mt.__namecall ~= hookFn and mt.__namecall ~= hookRaw then prevNC = mt.__namecall end
    end)
    if A.lastHookFn then
        local curH = nil
        pcall(function() local mt2 = grmt(game) if mt2 then curH = mt2.__namecall end end)
        if curH == A.lastHookFn then A.hooksOn = true return end
    end
    local okH, origHook = pcall(hm, game, "__namecall", hookFn)
    if not okH then
        okH, origHook = pcall(hm, game, "__namecall", hookRaw)
        if okH then hookFn = hookRaw end
    end
    if not okH then A.hookStage = "throw" return end
    pcall(StealthMark, hookFn)
    if type(origHook) == "function" then
        oldNamecall = origHook
    elseif prevNC then
        oldNamecall = prevNC
    elseif A.lastKnownNC then
        oldNamecall = A.lastKnownNC
    elseif A.oldNamecall then
        oldNamecall = A.oldNamecall
    end
    if oldNamecall then
        A.oldNamecall = oldNamecall
        A.lastKnownNC = oldNamecall
    end
    A.lastHookFn = hookFn
    A.hookStage = nil
    A.hooksOn = true
end

local function SyncSilentHooks()
    if C.silentEnabled or C.triggerEnabled then
        if A.hooksOn then return end
        if not (A.hm or hookmetamethod) or not (A.gnm or getnamecallmethod) then A.hookStage = "gate" return end
        local nowT = tick()
        if A.hookRetryAt and nowT < A.hookRetryAt then return end
        local okI = pcall(InstallHooks)
        if okI and A.hooksOn then
            A.hooksOn = true
            A.hookFails = 0
            A.hookRetryAt = nil
        else
            A.hookFails = (A.hookFails or 0) + 1
            A.hookRetryAt = nowT + math.min(0.25 * (2 ^ math.min(A.hookFails - 1, 4)), 4)
        end
    else
        if not A.hooksOn and not A.oldNamecall then return end
        A.hooksOn = false
        RestoreNamecallHook()
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
    local shotPart = part
    if (C.silentHitChance or 100) < 100 and math.random(1, 100) > (C.silentHitChance or 100) then
        local cam = A.cam
        if cam then goal = origin + cam.CFrame.LookVector * nd.Magnitude end
        shotPart = nil
        nd = goal - origin
        if nd.Magnitude <= 0.01 then return false end
    end
    local seq = (A.fireSeq or 0) + 1
    A.fireSeq = seq
    A.lastRemoteShot = tick()
    local ok = pcall(function() remote:FireServer(weapon, origin, nd.Unit, shotPart, goal, seq) end)
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
        A.triggerTarget = plr
    else
        plr, part = SelectTarget(C.silentPart, "triggerTarget")
        A.triggerTarget = plr
    end
    if not part then A.triggerStart = nil A.triggerFor = nil A.triggerTarget = nil return end
    local cam = A.cam
    if not cam then return end
    local goal = nil
    if plr and plr == A.silentTarget then goal = SilentGoal() end
    if not goal then goal = PredictPos(part, plr and A.cache[plr]) end
    local sp, on = cam:WorldToViewportPoint(goal)
    if not on then A.triggerStart = nil A.triggerFor = nil return end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    if (Vector2.new(sp.X, sp.Y) - center).Magnitude > (C.triggerRadius or 14) * FovRatio() then
        A.triggerStart = nil
        A.triggerFor = nil
        return
    end
    if A.triggerFor ~= part then A.triggerFor = part A.triggerStart = nil end
    if not A.triggerStart then A.triggerStart = tick() end
    if (tick() - A.triggerStart) * 1000 >= (C.triggerDelay or 60) then
        A.triggerStart = tick()
        if plr and part and not VisCheckPart(part, plr.Character) then return end
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
