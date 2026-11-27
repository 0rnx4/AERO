local fovCircle = NewDraw("Circle", {Visible = false, Filled = false, Thickness = 1, Transparency = 1, NumSides = 48, Radius = 150, Color = Color3.fromRGB(255, 255, 255), ZIndex = 5})
local hudText = NewDraw("Text", {Visible = false, Outline = true, Size = 13, Transparency = 1, Color = Color3.fromRGB(255, 255, 255), ZIndex = 5})
A.fovCircle = fovCircle A.hudText = hudText
local function HudStep()
    local cam = A.cam
    if fovCircle and cam then
        if C.silentShowFOV and C.silentEnabled then
            fovCircle.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
            fovCircle.Radius = EffFOV(C.silentFOV)
            local fcol = Color3.fromRGB(255, 255, 255)
            if not A.hooksOn then
                fcol = Color3.fromRGB(120, 120, 120)
            elseif A.silentTarget then
                fcol = Color3.fromRGB(255, 80, 80)
                local tp = A.silentPartObj
                if tp and tp.Parent then
                    local sp2 = cam:WorldToViewportPoint(tp.Position)
                    if sp2.Z > 0 and (Vector2.new(sp2.X, sp2.Y) - fovCircle.Position).Magnitude > fovCircle.Radius then
                        fcol = Color3.fromRGB(255, 170, 60)
                    end
                end
            end
            fovCircle.Color = fcol
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
    if hudText then
        local hs = tostring(math.floor(A.fpsEMA + 0.5)) .. " FPS   " .. tostring(math.floor(A.ping * 1000 + 0.5)) .. " ms   discord@kurudojindegomen"
        if A.hudStr ~= hs then A.hudStr = hs hudText.Text = hs end
        hudText.Position = Vector2.new(10, 10)
        hudText.Visible = true
    end
end

local function BindPlayer(p)
    local function onChar(char)
        A.cache[p] = {vel = Vector3.new(), accel = Vector3.new()}
        if p == LP then
            A.silentTarget = nil
            A.silentPartObj = nil
            A.silentRollOk = nil
            A.triggerStart = nil
            A.wantHookRefresh = tick() + 0.5
        end
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
    A.protSeen[p] = nil
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
    A.guiHitRects = nil
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
    mk("TextLabel", {Size = UDim2.new(0, 50, 1, 0), Position = UDim2.fromOffset(56, 0), BackgroundTransparency = 1, Text = "v9.8", TextColor3 = COL.muted, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, top)
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
        for _, mn in ipairs({"Toggle", "Slider", "Dropdown", "Button", "Paragraph"}) do
            local origM = t[mn]
            if type(origM) == "function" then
                t[mn] = function(self, spec) local okM, rM = pcall(origM, self, spec) if okM then return rM end print("[AERO] control failed: " .. tostring(mn)) return nil end
            end
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
    tSil:Toggle({Title = "サイレントエイム有効", Default = C.silentEnabled, Callback = function(v) C.silentEnabled = v pcall(SyncSilentHooks) if (A.optAppliedTier or 0) >= 2 then pcall(ApplyScalars, A.optAppliedTier) end SaveSoon() end})
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
    RestoreNamecallHook()
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
    local wcam = Workspace.CurrentCamera
    if wcam and wcam ~= A.cam then A.cam = wcam end
    local rawDt = dt
    if rawDt <= 0 then rawDt = 1 / 60 end
    if dt <= 0 or dt > 0.25 then dt = 1 / 60 end
    A.dt = dt
    A.frame = A.frame + 1
    A.fpsEMA = LerpNum(A.fpsEMA, 1 / dt, 0.05)
    SafeCall("cache", CacheStep, rawDt)
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
task.spawn(function()
    local iter = 0
    while not A.unloaded do
        task.wait(0.1)
        iter = iter + 1
        pcall(function()
            local pv = nil
            pcall(function() pv = LP and LP:GetNetworkPing() end)
            if not (type(pv) == "number" and pv == pv and pv > 0) then
                pv = nil
                pcall(function()
                    local net = game:GetService("Stats").Network.ServerStatsItem
                    local it = net and net:FindFirstChild("Data Ping")
                    local ms = it and it:GetValue()
                    if type(ms) == "number" and ms == ms and ms > 0 then pv = ms / 1000 end
                end)
            end
            if pv then
                A.pingOkAt = tick()
                if A.ping ~= A.ping then A.ping = clampNum(pv, 0.01, 0.5)
                else A.ping = LerpNum(A.ping, clampNum(pv, 0.01, 0.5), 0.18) end
            end
        end)
        if iter % 3 == 0 then SafeCall("adaptive", AdaptiveStep) end
        if iter % 10 == 0 and (C.silentEnabled or C.triggerEnabled) and not A.hooksOn then pcall(SyncSilentHooks) end
        if A.wantHookRefresh and tick() >= A.wantHookRefresh then
            A.wantHookRefresh = nil
            if (C.silentEnabled or C.triggerEnabled) and not A.unloaded then
                if A.hooksOn then RestoreNamecallHook() A.hooksOn = false end
                pcall(SyncSilentHooks)
            end
        end
        if iter % 100 == 0 then
            for dn in pairs(A.disabled) do A.disabled[dn] = nil A.errCounts[dn] = 0 end
            if A.pingOkAt and (tick() - A.pingOkAt) > 5 and A.ping == A.ping then A.ping = LerpNum(A.ping, 0.08, 0.2) end
        end
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
print("[AERO] v9.8 loaded.")