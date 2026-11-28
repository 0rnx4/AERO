if game.PlaceId ~= 75205943460003 then
    local lpGate = game:GetService("Players").LocalPlayer
    if lpGate then pcall(function() lpGate:Kick("AERO以外では使用できません") end) end
    return
end
local GEN = getgenv()
if GEN.__aero_loading then print("[AERO] loader already running") return end
GEN.__aero_loading = true
local PIN = "93626847fb49ad9a9c6b1d21fd56cfd056716903"
local HOSTS = {
    "https://raw.githubusercontent.com/0rnx4/AERO/" .. PIN .. "/modules/",
    "https://cdn.jsdelivr.net/gh/0rnx4/AERO@" .. PIN .. "/modules/",
}
local MANIFEST = {
    {name = "core.lua", size = 4116, hash = 3039152862},
    {name = "config.lua", size = 1758, hash = 2463783136},
    {name = "draw.lua", size = 1262, hash = 2606187962},
    {name = "target.lua", size = 15733, hash = 49831525},
    {name = "input.lua", size = 1831, hash = 3480904149},
    {name = "silent.lua", size = 9339, hash = 263838343},
    {name = "esp_draw.lua", size = 2644, hash = 2217781911},
    {name = "esp.lua", size = 15253, hash = 2743208579},
    {name = "fov_opt.lua", size = 15325, hash = 2407192141},
    {name = "main.lua", size = 32326, hash = 1080332402},
}
local function notify(text, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "AERO", Text = text, Duration = dur or 3})
    end)
end
local function fnv(s)
    local h = 2166136261
    for i = 1, #s do
        h = bit32.bxor(h, string.byte(s, i))
        local hi = math.floor(h / 65536)
        local lo = h - hi * 65536
        h = (((hi * 16777619) % 65536) * 65536 + lo * 16777619) % 4294967296
    end
    return h
end
local function verify(body, meta)
    return type(body) == "string" and #body == meta.size and fnv(body) == meta.hash
end
local CACHE_DIR = "AERO_CACHE/" .. PIN:sub(1, 8)
local fsReady = false
if typeof(isfile) == "function" and typeof(readfile) == "function" and typeof(writefile) == "function" and typeof(makefolder) == "function" and typeof(isfolder) == "function" then
    fsReady = pcall(function()
        if not isfolder("AERO_CACHE") then makefolder("AERO_CACHE") end
        if not isfolder(CACHE_DIR) then makefolder(CACHE_DIR) end
    end)
end
local function fetchOnce(url, timeout)
    local done, result = false, nil
    task.spawn(function()
        local ok, r = pcall(game.HttpGet, game, url)
        if ok then result = r end
        done = true
    end)
    local t0 = tick()
    while not done and (tick() - t0) < timeout do task.wait(0.05) end
    if done then return result end
    return nil
end
local function resolve(meta)
    if fsReady then
        local path = CACHE_DIR .. "/" .. meta.name
        local okF, isF = pcall(isfile, path)
        if okF and isF then
            local okR, body = pcall(readfile, path)
            if okR and verify(body, meta) then return body, "cache" end
        end
    end
    for attempt = 1, 3 do
        local host = HOSTS[(attempt - 1) % #HOSTS + 1]
        local body = fetchOnce(host .. meta.name, 8)
        if body and verify(body, meta) then
            if fsReady then pcall(writefile, CACHE_DIR .. "/" .. meta.name, body) end
            return body, "net"
        end
        if attempt < 3 then task.wait(0.3 * attempt) end
    end
    return nil
end
local parts, sources = {}, {}
local failed = nil
local pending = #MANIFEST
local t0 = tick()
for i, meta in ipairs(MANIFEST) do
    task.spawn(function()
        local body, src = resolve(meta)
        if body then parts[i] = body sources[i] = src else failed = meta.name end
        pending = pending - 1
    end)
end
while pending > 0 do task.wait(0.05) end
GEN.__aero_loading = nil
if failed then
    print("[AERO] module load failed: " .. tostring(failed))
    notify("読み込み失敗: " .. tostring(failed), 5)
    return
end
local fn, lerr = loadstring(table.concat(parts))
if not fn then
    print("[AERO] build failed: " .. tostring(lerr))
    notify("読み込み失敗", 5)
    return
end
local cacheN, netN = 0, 0
for _, s in ipairs(sources) do if s == "cache" then cacheN = cacheN + 1 else netN = netN + 1 end end
local ms = math.floor((tick() - t0) * 1000)
GEN.__aero_loader = {pin = PIN, ms = ms, cache = cacheN, net = netN}
print(("[AERO] modules ready: cache %d / net %d / %dms"):format(cacheN, netN, ms))
fn()
