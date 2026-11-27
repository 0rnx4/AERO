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
    visCache = {}, teamMode = nil, protSeen = {},
}
A.optSaved = {}
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
