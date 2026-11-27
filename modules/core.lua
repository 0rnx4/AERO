local GST = getgenv()
if GST.__aero_unload then pcall(GST.__aero_unload, true) end

local STEALTH = {
    hooked = {},
    origFenv = getfenv,
    origInfo = debug and debug.getinfo,
    origTrace = debug and debug.traceback,
    origCallStack = getcallstack,
}
local EXEC_MARKERS = {"getgenv", "syn", "KRNL_LOADED", "secure_call", "request", "getfenv", "getrawmetatable", "setreadonly", "hookfunction"}

local function IsExecutorEnv(env)
    if type(env) ~= "table" then return false end
    for i = 1, #EXEC_MARKERS do
        if rawget(env, EXEC_MARKERS[i]) ~= nil then return true end
    end
    return false
end

local function CleanEnv(env)
    if type(env) ~= "table" then return env end
    local clean = {}
    for k, v in pairs(env) do
        local skip = false
        for i = 1, #EXEC_MARKERS do
            if k == EXEC_MARKERS[i] then skip = true break end
        end
        if not skip then clean[k] = v end
    end
    return clean
end

do
    local hasNCC = type(newcclosure) == "function"
    if type(STEALTH.origFenv) == "function" then
        local body = function(lvl)
            local ok, env = pcall(STEALTH.origFenv, lvl)
            if not ok then return env end
            if IsExecutorEnv(env) then return CleanEnv(env) end
            return env
        end
        local wrapped = hasNCC and newcclosure(body) or body
        pcall(function() getfenv = wrapped end)
        STEALTH.hooked[wrapped] = true
    end
    if type(STEALTH.origInfo) == "function" then
        local fakeC = {what = "C", source = "=[C]", short_src = "[C]", linedefined = -1, currentline = -1, nups = 0}
        local body = function(f, what)
            local ok, info = pcall(STEALTH.origInfo, f, what)
            if ok and type(info) == "table" and STEALTH.hooked[f] then return fakeC end
            return info
        end
        local wrapped = hasNCC and newcclosure(body) or body
        pcall(function() debug.getinfo = wrapped end)
        STEALTH.hooked[wrapped] = true
    end
    if type(STEALTH.origTrace) == "function" then
        local body = function(msg, lvl)
            local ok, trace = pcall(STEALTH.origTrace, msg, lvl)
            if not ok or type(trace) ~= "string" then return trace end
            local lines = {}
            for line in trace:gmatch("[^\n]+") do
                local keep = true
                for i = 1, #EXEC_MARKERS do
                    if line:find(EXEC_MARKERS[i], 1, true) then keep = false break end
                end
                if keep and not line:find("AERO", 1, true) then table.insert(lines, line) end
            end
            return table.concat(lines, "\n")
        end
        local wrapped = hasNCC and newcclosure(body) or body
        pcall(function() debug.traceback = wrapped end)
        STEALTH.hooked[wrapped] = true
    end
    if type(STEALTH.origCallStack) == "function" then
        local body = function()
            local ok, stack = pcall(STEALTH.origCallStack)
            if not ok or type(stack) ~= "table" then return stack end
            local clean = {}
            for _, frame in ipairs(stack) do
                local skip = false
                if type(frame) == "table" then
                    local src = tostring(frame.source or "")
                    for i = 1, #EXEC_MARKERS do
                        if src:find(EXEC_MARKERS[i], 1, true) then skip = true break end
                    end
                    if not skip and not src:find("AERO", 1, true) then table.insert(clean, frame) end
                end
            end
            return clean
        end
        local wrapped = hasNCC and newcclosure(body) or body
        pcall(function() getcallstack = wrapped end)
        STEALTH.hooked[wrapped] = true
    end
end

local function StealthMark(fn)
    if fn then STEALTH.hooked[fn] = true end
    return fn
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

