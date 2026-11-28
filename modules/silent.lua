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
    A.silentRollOk = nil
    A.silentTarget = p
    A.silentPartObj = part
    A.silentIsNPC = p ~= nil and CharOf(p) == p
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

local function BotReport(part, goal, origin)
    local char = A.silentTarget
    if A.botLocked then
        A.botLockShots = (A.botLockShots or 0) + 1
        if A.botLockShots >= 25 then
            A.botLockShots = 0
            if (A.botDmgAt or 0) > (A.botLockAt or 0) then
                A.botLockAt = tick()
            else
                A.botLocked = false
                A.botVar = ((A.botVar or 1) % 3) + 1
                A.botVarShots = 0
            end
        end
    else
        A.botVarShots = (A.botVarShots or 0) + 1
        if A.botVarShots >= 10 then
            A.botVar = ((A.botVar or 1) % 3) + 1
            A.botVarShots = 0
        end
    end
    local v = A.botVar or 1
    if v == 2 then
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("HumanoidRootPart", true))
        if hrp then
            local g2 = PredictPos(hrp, A.cache[char])
            if g2 then return hrp, g2 end
        end
    elseif v == 3 then
        local dir = goal - origin
        if dir.Magnitude > 0.01 and char then
            if not A.botRayParams then
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Include
                rp.IgnoreWater = true
                A.botRayParams = rp
            end
            A.botRayParams.FilterDescendantsInstances = {char}
            local ok, hit = pcall(function() return Workspace:Raycast(origin, dir.Unit * (dir.Magnitude + 5), A.botRayParams) end)
            if ok and hit and hit.Instance then return hit.Instance, hit.Position end
        end
    end
    return part, goal
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
    local ncc = newcclosure or function(f) return f end
    local inHook = false
    local oldNamecall
    local SS = GST.AERO_STEALTH
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
        if A.silentIsNPC then
            local bp, bg = BotReport(part, goal, origin)
            if not bp or not bg then return false end
            part, goal = bp, bg
        end
        local nd = goal - origin
        if nd.Magnitude <= 0.01 then return false end
        args[3] = nd.Unit
        args[4] = part
        args[5] = goal
        AfterBend()
        local okr, r1, r2, r3, r4, r5, r6, r7, r8 = pcall(oldNamecall, self, table.unpack(args))
        if okr then return true, r1, r2, r3, r4, r5, r6, r7, r8 end
        return true
    end
    local wrappedNC = ncc(function(self, ...)
        if inHook then return oldNamecall(self, ...) end
        local method = getnamecallmethod()
        if method ~= "FireServer" then return oldNamecall(self, ...) end
        if not A.fireRemote then FindFireRemote() end
        if self ~= A.fireRemote then return oldNamecall(self, ...) end
        if checkcaller and checkcaller() then return oldNamecall(self, ...) end
        local seqArg = select(6, ...)
        if type(seqArg) == "number" and seqArg > (A.fireSeq or 0) then A.fireSeq = seqArg end
        A.lastFire = tick()
        if not C.silentEnabled then return oldNamecall(self, ...) end
        inHook = true
        if SS then SS.inHook = true end
        local res = {pcall(handleFire, self, ...)}
        inHook = false
        if SS then SS.inHook = false end
        if res[1] and res[2] then return res[3], res[4], res[5], res[6], res[7], res[8], res[9], res[10] end
        return oldNamecall(self, ...)
    end)
    oldNamecall = hookmetamethod(game, "__namecall", wrappedNC)
    A.oldNamecall = oldNamecall
    A.wrappedNamecall = wrappedNC
    if SS and SS.registerHook then SS.registerHook(wrappedNC, oldNamecall) end
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
    local shotPart = part
    if (C.silentHitChance or 100) < 100 and math.random(1, 100) > (C.silentHitChance or 100) then
        local cam = A.cam
        if cam then goal = origin + cam.CFrame.LookVector * nd.Magnitude + Vector3.new((math.random() - 0.5) * 12, (math.random() - 0.5) * 6, (math.random() - 0.5) * 12) end
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
        if plr and part and not VisCheckPart(part, CharOf(plr)) then return end
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
