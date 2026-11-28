local function FovStep()
    local cam = Workspace.CurrentCamera
    if cam ~= A.cam then
        A.cam = cam
        if cam and A.origFOV == nil then A.origFOV = cam.FieldOfView end
    end
    if not cam then return end
    local cur = cam.FieldOfView
    if A.origFOV and A.origFOV >= 45 and not A.learnedBase then A.learnedBase = A.origFOV end
    local base = A.learnedBase or C.fovValue
    local detBase = (C.fovEnabled and A.lastSetFOV) or base
    local inputADS = A.adsBtnHeld == true
    if not inputADS then pcall(function() inputADS = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end) end
    if cur < detBase - 3 then
        A.adsActive = true
        A.adsFOV = cur
    elseif cur >= detBase - 1 and not inputADS then
        A.adsActive = false
    end
    if not A.adsActive and not C.fovEnabled then
        if math.abs(cur - (A.baseCand or -100)) <= 0.3 then
            A.baseStable = (A.baseStable or 0) + 1
        else
            A.baseCand = cur
            A.baseStable = 0
        end
        if cur >= 45 and ((A.baseStable >= 40 and (not A.learnedBase or cur <= A.learnedBase)) or A.baseStable >= 240) then A.learnedBase = cur end
    end
    if not C.fovEnabled then
        if A.fovApplied then
            A.fovApplied = false
            local rb = A.learnedBase or A.origFOV if rb then pcall(function() cam.FieldOfView = rb end) end
            if A.origStretch ~= nil then pcall(function() cam.ViewStretch = A.origStretch end) end
            A.lastSetFOV = nil
        end
        A.desiredFOV = nil
        return
    end
    A.fovApplied = true
    local desired = C.fovValue
    if A.adsActive and A.adsFOV then
        local ratio = math.tan(math.rad(A.adsFOV / 2)) / math.tan(math.rad(base / 2))
        if C.fovKeepADS then
            desired = C.fovValue
        else
            desired = math.deg(2 * math.atan(math.tan(math.rad(C.fovValue / 2)) * ratio))
            desired = clampNum(desired, 5, 120)
        end
    end
    A.desiredFOV = desired
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
        local rb = A.learnedBase or A.origFOV if rb then pcall(function() cam.FieldOfView = rb end) end
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
        if ok then rec[prop] = {v = v} end
    end
end
local function RestoreAllProps()
    for inst, rec in pairs(A.optSaved) do
        for prop, w in pairs(rec) do
            if type(w) == "table" then pcall(function() inst[prop] = w.v end) end
        end
    end
    A.optSaved = {}
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
        if tier >= 2 then pcall(function() Workspace.InterpolationThrottling = C.silentEnabled and ((A.scalarOrig and A.scalarOrig.interpThrottle) or Enum.InterpolationThrottlingMode.Disabled) or Enum.InterpolationThrottlingMode.Enabled end) end
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
        if A.fpsCapOrigin then pcall(function() setfpscap(tier >= 3 and 60 or 120) end) end
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
                    if ch:IsA("SurfaceAppearance") then SaveProp(ch, "Parent") pcall(function() ch.Parent = nil end) end
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
    local budget = 0.004
    if A.fpsEMA < 45 then budget = 0.002 elseif A.fpsEMA > 100 then budget = 0.007 end
    local deadline = tick() + budget
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
    if tick() - (A.optAutoAt or 0) < 2.5 then return end
    local f = A.fpsEMA
    local t = A.optTier
    local nt = t
    if f < 34 then nt = math.min(4, t + 1)
    elseif f < 42 and t < 2 then nt = t + 1
    elseif f < 50 and t < 1 then nt = 1
    elseif f > 72 and t > (C.optSliderTier or 0) then nt = t - 1 end
    if nt ~= t then A.optAutoAt = tick() SetTier(nt) end
end

A.hideAllEsp = function()
    for _, b in pairs(A.esp) do HideBundle(b) end
end

