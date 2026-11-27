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
    if not A.errPrinted then A.errPrinted = {} end
    if not A.errPrinted[name] then A.errPrinted[name] = true print("[AERO] " .. name .. ": " .. tostring(err)) end
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
