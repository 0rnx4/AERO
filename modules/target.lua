local function GetHum(char)
    if not char then return nil end
    local h = char:FindFirstChildOfClass("Humanoid")
    if h then return h end
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("Model") then
            local h2 = d:FindFirstChildOfClass("Humanoid")
            if h2 then return h2 end
        end
    end
    return nil
end
local function CharOf(x)
    if not x then return nil end
    local ok, isP = pcall(function() return x:IsA("Player") end)
    if ok and isP then return x.Character end
    return x
end
local function IsAlive(p)
    if not p then return false end
    local c = CharOf(p)
    if not c then return false end
    local h = GetHum(c)
    if h then return h.Health > 0 end
    if c ~= p then return false end
    local hp = nil
    pcall(function() hp = c:GetAttribute("Health") end)
    if type(hp) == "number" then return hp > 0 end
    return true
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
            fovStretch = {50, 200}, optSliderTier = {0, 4},
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
local function IsProtected(p)
    local char = p and CharOf(p)
    if not char then
        if p then A.protSeen[p] = nil end
        return false
    end
    if char:FindFirstChildOfClass("ForceField") or char:FindFirstChild("SpawnProtection") then
        local ps = A.protSeen[p]
        if not ps or ps.char ~= char then
            A.protSeen[p] = {char = char, at = tick()}
            return true
        end
        if tick() - ps.at <= 10 then return true end
    else
        A.protSeen[p] = nil
    end
    local pu = nil
    pcall(function() pu = char:GetAttribute("ProtectedUntil") end)
    if type(pu) == "number" and pu == pu then
        local dt = pu - tick()
        if dt > 0 and dt <= 300 then return true end
    end
    return false
end
local function IsEnemy(p, useTeamCheck)
    if not p or not LP or p == LP then return false end
    if not useTeamCheck then return true end
    if A.teamAttrMode then
        local lt, pt = LP:GetAttribute("Team"), p:GetAttribute("Team")
        if lt ~= nil and pt ~= nil then return lt ~= pt end
        return true
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
local RAY_FILTER = {nil, nil}
local function VisCheckPart(part, char)
    local cam = A.cam
    if not cam or not part then return false end
    local origin = cam.CFrame.Position
    local dir = part.Position - origin
    local dist = dir.Magnitude
    if dist < 0.1 then return true end
    local lc = LP and LP.Character
    if lc then RAY_FILTER[1] = lc RAY_FILTER[2] = A.cam RAY_PARAMS.FilterDescendantsInstances = RAY_FILTER
    else RAY_FILTER[1] = A.cam RAY_FILTER[2] = nil RAY_PARAMS.FilterDescendantsInstances = RAY_FILTER end
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
local function VisCached(p, part, char, pool)
    local byPart = A.visCache[p]
    if not byPart then byPart = {} A.visCache[p] = byPart end
    local e = byPart[part]
    if e and (A.frame - (e.frame or 0)) <= 1 then return e.ok end
    if A.visBudgetFrame ~= A.frame then
        A.visBudgetFrame = A.frame
        A.visRayAim = 8
        A.visRayEsp = 6
    end
    local left
    if pool == "esp" then left = A.visRayEsp or 0 else left = A.visRayAim or 0 end
    if left <= 0 then
        if e then return e.ok end
        return false
    end
    if pool == "esp" then A.visRayEsp = left - 1 else A.visRayAim = left - 1 end
    local ok = VisCheckPart(part, char)
    byPart[part] = {ok = ok, frame = A.frame}
    return ok
end

local function ResolvePart(p, mode)
    local char = p and CharOf(p)
    if not char then return nil end
    if mode == "胴体" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
            or char:FindFirstChild("HumanoidRootPart", true) or char:FindFirstChild("UpperTorso", true) or char:FindFirstChild("Torso", true)
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Head", true) or char:FindFirstChild("HumanoidRootPart", true)
end

local function PredictPos(part, entry)
    if not C.silentPrediction or not entry then return part.Position end
    local cam = A.cam
    if not cam then return part.Position end
    local ping = A.ping or 0.05
    if ping ~= ping or ping < 0 then ping = 0.08 end
    if ping > 0.13 then ping = 0.13 end
    local t = ping + (A.dt or 0) * 0.5
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
    if off.Magnitude > 6 then off = off.Unit * 6 end
    local g = part.Position + off
    if g.X ~= g.X or g.Y ~= g.Y or g.Z ~= g.Z then return part.Position end
    return g
end

local function FovRatio()
    local cam = A.cam
    if not cam then return 1 end
    local cur = cam.FieldOfView
    if not cur or cur <= 5 or cur >= 179 then return 1 end
    local ref = C.fovEnabled and C.fovValue or (A.learnedBase or cur)
    if not ref or ref <= 5 or ref >= 179 then return 1 end
    local r = math.tan(math.rad(ref / 2)) / math.tan(math.rad(cur / 2))
    if r ~= r then return 1 end
    if r < 0.5 then r = 0.5 elseif r > 4 then r = 4 end
    return r
end
local function EffFOV(base)
    return (base or 150) * FovRatio()
end

local function SelectTarget(partMode, stickyKey)
    local cam = A.cam
    if not cam or not LP then return nil, nil end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local fov = EffFOV(C.silentFOV)
    local best, bestPart, bestD = nil, nil, math.huge
    local sticky, stickyPart, stickyD = nil, nil, nil
    local lockedP = stickyKey and A[stickyKey] or nil
    local function eval(key)
        if not IsAlive(key) or IsProtected(key) then return end
        local part = ResolvePart(key, partMode)
        if not part or not part.Parent then return end
        local sp, on = cam:WorldToViewportPoint(part.Position)
        if on and sp.Z > 0 then
            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
            local dMax = (key == lockedP) and fov * 1.25 or fov
            if d <= dMax then
                if d < bestD then bestD = d best = key bestPart = part end
                if stickyKey and A[stickyKey] == key then sticky = key stickyPart = part stickyD = d end
            end
        end
    end
    for _, p in ipairs(A.players or Players:GetPlayers()) do
        if IsEnemy(p, C.teamCheck) then eval(p) end
    end
    if A.npcs then
        for _, m in ipairs(A.npcs) do eval(m) end
    end
    if sticky and stickyD and stickyD <= fov * 1.25 and (not best or best == sticky or stickyD < bestD * 1.8) then
        return sticky, stickyPart
    end
    if best and bestPart and not VisCached(best, bestPart, CharOf(best)) then
        local subP, subPart, subD = nil, nil, math.huge
        local function evalSub(key)
            if key == best or not IsAlive(key) or IsProtected(key) then return end
            local part2 = ResolvePart(key, partMode)
            if not part2 or not part2.Parent then return end
            local sp2, on2 = cam:WorldToViewportPoint(part2.Position)
            if on2 and sp2.Z > 0 then
                local d2 = (Vector2.new(sp2.X, sp2.Y) - center).Magnitude
                if d2 <= fov and d2 <= math.max(bestD * 1.5, 40) and d2 < subD and VisCached(key, part2, CharOf(key)) then
                    subP = key subPart = part2 subD = d2
                end
            end
        end
        for _, p in ipairs(A.players or Players:GetPlayers()) do
            if IsEnemy(p, C.teamCheck) then evalSub(p) end
        end
        if A.npcs then
            for _, m in ipairs(A.npcs) do evalSub(m) end
        end
        if subP then return subP, subPart end
    end
    return best, bestPart
end

local function ScanNPCs()
    local chars = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then chars[pl.Character] = true end
    end
    local found, seen = {}, {}
    local function isBot(m)
        if chars[m] then return false end
        local anc = m.Parent
        while anc do
            if seen[anc] then return false end
            anc = anc.Parent
        end
        local head = m:FindFirstChild("Head", true)
        local root = m:FindFirstChild("HumanoidRootPart", true) or m:FindFirstChild("RootPart", true)
            or m:FindFirstChild("UpperTorso", true) or m:FindFirstChild("Torso", true)
        if not head or not root then return false end
        if GetHum(m) then return true end
        local hp = nil
        pcall(function() hp = m:GetAttribute("Health") end)
        if type(hp) == "number" then return true end
        return true
    end
    pcall(function()
        for _, m in ipairs(Workspace:GetDescendants()) do
            if m:IsA("Model") and isBot(m) then
                found[#found + 1] = m
                seen[m] = true
            end
        end
    end)
    if A.npcs then
        for _, old in ipairs(A.npcs) do
            if not seen[old] then
                A.cache[old] = nil A.visCache[old] = nil A.protSeen[old] = nil
                if A.silentTarget == old then A.silentTarget = nil A.silentPartObj = nil end
                if A.triggerTarget == old then A.triggerTarget = nil end
            end
        end
    end
    A.npcs = found
end

local function CacheOne(p, char, dt)
    local e = A.cache[p]
    if not e then e = {vel = Vector3.new(), accel = Vector3.new()} A.cache[p] = e end
    if char ~= e.char then
        e.char = char
        A.visCache[p] = nil
        e.vel = Vector3.new()
        e.accel = Vector3.new()
        e.prevPos = nil
        e.hum = nil
        e.hrp = nil
        e.head = nil
        e.hpPrev = nil
        e.hpAttrPrev = nil
    end
    if e.hum and not e.hum.Parent then e.hum = nil end
    if e.hrp and not e.hrp.Parent then e.hrp = nil e.prevPos = nil end
    if e.head and not e.head.Parent then e.head = nil end
    if not e.hum then e.hum = GetHum(char) end
    if not e.hrp then e.hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("HumanoidRootPart", true)) end
    if not e.head then e.head = char and (char:FindFirstChild("Head") or char:FindFirstChild("Head", true)) end
    if e.hum then
        local hpNow = e.hum.Health
        if e.hpPrev ~= nil and hpNow < e.hpPrev and CharOf(p) == p then
            A.botDmgAt = tick()
            if not A.botLocked then A.botLocked = true A.botLockAt = tick() A.botLockShots = 0 end
        end
        e.hpPrev = hpNow
    end
    if CharOf(p) == p then
        local tot = nil
        pcall(function()
            local h = char:GetAttribute("Health")
            if type(h) ~= "number" then h = char:GetAttribute("HP") end
            if type(h) == "number" then
                local a = char:GetAttribute("Armor")
                tot = h + (type(a) == "number" and a or 0)
            end
        end)
        if tot ~= nil then
            if e.hpAttrPrev ~= nil and tot < e.hpAttrPrev then
                A.botDmgAt = tick()
                if not A.botLocked then A.botLocked = true A.botLockAt = tick() A.botLockShots = 0 end
            end
            e.hpAttrPrev = tot
        end
    end
    local hrp = e.hrp
    if hrp then
        local pos = hrp.Position
        if e.vel.X ~= e.vel.X or e.vel.Y ~= e.vel.Y or e.vel.Z ~= e.vel.Z then e.vel = Vector3.new() e.accel = Vector3.new() end
        if e.prevPos then
            local delta = pos - e.prevPos
            local rawPre = delta / dt
            local nanDelta = rawPre.X ~= rawPre.X or rawPre.Y ~= rawPre.Y or rawPre.Z ~= rawPre.Z
            local phantom = false
            if not nanDelta and rawPre.Magnitude > 160 then
                local av = nil
                pcall(function() av = hrp.AssemblyLinearVelocity end)
                phantom = not (av and av.Magnitude > 80 and av:Dot(rawPre) > 0)
            end
            if delta.Magnitude > 8 or nanDelta or phantom then
                e.vel = Vector3.new()
                e.accel = Vector3.new()
            else
                local raw = rawPre
                if raw.Magnitude > 400 then raw = Vector3.new() end
                local okA, blended = pcall(function()
                    local a = hrp.AssemblyLinearVelocity
                    if a and raw.Magnitude > 3 and a.Magnitude > 3 and a.Magnitude < 400 and a:Dot(raw) > 0 then
                        return raw:Lerp(a, 0.65)
                    end
                    return nil
                end)
                if okA and blended then raw = blended end
                local nv = e.vel:Lerp(raw, 1 - 0.55 ^ (dt * 60))
                local dv = nv - e.vel
                local maxDv = 260 * dt + 6
                if dv.Magnitude > maxDv then nv = e.vel + dv.Unit * maxDv end
                if nv.Magnitude < 0.5 then nv = Vector3.new() end
                local acc = (nv - e.vel) / dt
                if acc.Magnitude > 80 then acc = acc.Unit * 80 end
                e.accel = e.accel:Lerp(acc, 1 - 0.75 ^ (dt * 60))
                e.vel = nv
            end
        end
        e.prevPos = pos
    else
        e.prevPos = nil
    end
end

local function CacheStep(dt)
    A.players = Players:GetPlayers()
    if not (C.silentEnabled or C.triggerEnabled or C.espEnabled) then A.cacheIdle = true return end
    if A.cacheIdle then A.cacheIdle = false pcall(RefreshTeamMode) end
    if A.frame % 120 == 0 then pcall(RefreshTeamMode) end
    if dt <= 0 then dt = 1 / 60 end
    if (C.silentEnabled or C.triggerEnabled) and tick() - (A.npcScanAt or 0) > 1 then
        A.npcScanAt = tick()
        ScanNPCs()
    end
    for _, p in ipairs(A.players) do
        if p ~= LP then CacheOne(p, p.Character, dt) end
    end
    if A.npcs then
        for _, m in ipairs(A.npcs) do
            if m.Parent then CacheOne(m, m, dt) end
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
