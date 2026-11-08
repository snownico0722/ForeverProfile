-- Headless smoke test for the minimap toggle. Run: texlua tests/test_toggle.lua
local addon = "ForeverProfiles"
local frames = {}
local state = {
    graphicsQuality = "8", RAIDgraphicsQuality = "6", graphicsShadowQuality = "3",
    RenderScale = "1.000000", maxFPS = "120", maxFPSBk = "30",
    useMaxFPS = "0", useMaxFPSBk = "1", useTargetFPS = "1", vsync = "1",
    ffxAntiAliasingMode = "2", MSAAQuality = "4,0",
}
local applyCount = 0
local partialRestore = false
local function Copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end
local G = {}
function G.Capture() return {values=Copy(state)} end
function G.Validate(s) return type(s)=="table" and type(s.values)=="table" and next(s.values)~=nil end
function G.Apply(s)
    applyCount = applyCount + 1
    for k, v in pairs(s.values) do
        if not (partialRestore and v == "120" and k == "maxFPS") then state[k] = v end
    end
    return {success=true}
end
function G.Compare(s)
    local total, matched = 0, 0
    for k, v in pairs(s.values) do
        total = total + 1
        if (tonumber(v) and tonumber(state[k]) and tonumber(v) == tonumber(state[k])) or state[k] == v then
            matched = matched + 1
        end
    end
    return {total=total, matched=matched, matches=matched==total}
end
local F = {Graphics=G}
local function Texture()
    return setmetatable({}, {__index=function() return function() end end})
end
local function Frame(name)
    local obj = {scripts={}, name=name}
    setmetatable(obj, {__index=function(_, method)
        if method == "CreateTexture" then return function() return Texture() end end
        if method == "GetFrameLevel" then return function() return 1 end end
        return function(self, ...)
            if method == "SetScript" then self.scripts[select(1,...)] = select(2,...) end
        end
    end})
    frames[#frames+1] = obj
    if name then frames[name] = obj end
    return obj
end
Minimap = Frame("Minimap")
function CreateFrame(_,name) return Frame(name) end
C_Timer = {After=function(_,func) func() end}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
local function Boot()
    assert(loadfile("YinYang.lua"))(addon, F)
    local loadFrame = frames[#frames]
    loadFrame.scripts.OnEvent(loadFrame, "ADDON_LOADED", addon)
    return frames["ForeverYinYangButton"]
end
local original = Copy(state)
local button = Boot()
assert(type(button.scripts.OnClick)=="function", "minimap toggle missing")
assert(ForeverYinYangDB.active==false)
button.scripts.OnClick()
assert(ForeverYinYangDB.active==true, "Yin not enabled")
assert(state.graphicsQuality=="0" and state.RAIDgraphicsQuality=="0")
assert(state.graphicsShadowQuality=="0")
assert(state.RenderScale=="0.1")
assert(state.maxFPS=="8" and state.maxFPSBk=="8")
assert(state.useMaxFPS=="1" and state.useMaxFPSBk=="1")
assert(state.useTargetFPS=="0")
assert(ForeverYinYangDB.original.values.maxFPS == "120", "original settings overwritten")
-- Simulate /reload: restore state comes from saved DB, not a transient variable.
button = Boot()
assert(ForeverYinYangDB.active==true)
partialRestore = true
button.scripts.OnClick()
assert(ForeverYinYangDB.active==true and ForeverYinYangDB.original, "failed restore lost backup")
partialRestore = false
button.scripts.OnClick()
assert(ForeverYinYangDB.active==false and ForeverYinYangDB.original==nil)
for key, value in pairs(original) do
    assert(state[key] == value, "failed to restore " .. key)
end
assert(applyCount == 3)
print("PASS: Yin/Yang toggle, 8 FPS, persistence, partial-restore retry")
