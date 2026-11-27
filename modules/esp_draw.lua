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
