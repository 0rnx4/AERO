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
    local vp = cam.ViewportSize
    for _, w in ipairs(corners) do
        local sp = cam:WorldToViewportPoint(w)
        if sp.Z > 0 then
            any = true
            local cx = clampNum(sp.X, -2000, vp.X + 2000)
            local cy = clampNum(sp.Y, -2000, vp.Y + 2000)
            if cx < minX then minX = cx end
            if cy < minY then minY = cy end
            if cx > maxX then maxX = cx end
            if cy > maxY then maxY = cy end
        end
    end
    if not any then return nil end
    return minX, minY, maxX, maxY, size
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
    if not cam or not LP or not LP.Character then
        if not A.espHidden then
            A.espHidden = true
            for _, b in pairs(A.esp) do HideBundle(b) end
        end
        return
    end
    A.espHidden = false
    local lpChar = LP.Character
    local lpHrp = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
    if not lpHrp then
        for _, b in pairs(A.esp) do HideBundle(b) end
        return
    end
    if A.frame % 2 == 1 then return end
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
                if not b then b = CreateBundle(p) end
                local minX, minY, maxX, maxY
                local skipN = (dist > 500 and 3) or (dist > 300 and 2) or 1
                local stale = false
                if skipN > 1 then
                    b.tickN = (b.tickN or 0) + 1
                    if b.tickN % skipN ~= 0 then stale = true end
                end
                if stale then
                    minX = false
                else
                    if b.char ~= char then b.char = char b.aspect = nil b.sx = nil end
                    local nowC = os.clock()
                    if not b.aspect or nowC - (b.learnAt or 0) > 0.35 then
                        b.learnAt = nowC
                        local szS
                        minX, minY, maxX, maxY, szS = ProjectBox(char)
                        if szS then
                            local nhw, nhh = szS.X / 2, szS.Y / 2
                            local nasp = szS.X / math.max(szS.Y, 0.1)
                            if b.aspect then
                                b.hw = LerpNum(b.hw, nhw, 0.5) b.hh = LerpNum(b.hh, nhh, 0.5) b.aspect = LerpNum(b.aspect, nasp, 0.5)
                            else
                                b.hw = nhw b.hh = nhh b.aspect = nasp
                            end
                        end
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
                        if (headP and VisCached(p, headP, char, "esp")) or (hrp and VisCached(p, hrp, char, "esp")) then baseCol = ESP_COL_VIS end
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
                            if b._name ~= p.DisplayName then b._name = p.DisplayName b.nameTxt.Text = p.DisplayName end
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
                    if b._armorChar ~= char or b._armorFrame == nil or (A.frame - b._armorFrame) >= 30 then
                        b._armorChar = char
                        b._armorFrame = A.frame
                        b._armor = nil b._maxArmor = nil
                        pcall(function()
                            local ar = char:GetAttribute("Armor")
                            local arm = char:GetAttribute("MaxArmor")
                            if type(ar) == "number" and type(arm) == "number" and arm > 0 then
                                b._armor = ar b._maxArmor = arm
                            end
                        end)
                    end
                    if b._armor then hpNow = hpNow + b._armor hpMax = hpMax + b._maxArmor end
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
                if b then HideBundle(b) end
            end
        end
    end
end

