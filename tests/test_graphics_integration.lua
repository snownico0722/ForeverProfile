-- Run from addon root: lua5.1 tests/test_graphics_integration.lua
-- This integration test uses the production Graphics.lua, not a mock of it.
local addon = "ForeverProfiles"
local F = {}
local clock = 0
local cursorX, cursorY = 10, 20
function GetTime() return clock end
function GetCursorPosition() return cursorX, cursorY end
function IsWindowFocused() return true end
local cvars = {
    graphicsQuality = "8", RAIDgraphicsQuality = "6",
    graphicsShadowQuality = "4", raidGraphicsShadowQuality = "3",
    graphicsViewDistance = "8", raidGraphicsViewDistance = "6",
    graphicsGroundClutter = "8", raidGraphicsGroundClutter = "7",
    farclip = "8000", RAIDfarclip = "6000",
    horizonStart = "3200", RAIDhorizonStart = "2800",
    horizonClip = "8000", RAIDhorizonClip = "6000",
    terrainLodDist = "900", RAIDterrainLodDist = "700",
    wmoLodDist = "900", RAIDwmoLodDist = "700",
    groundEffectDensity = "200", RAIDgroundEffectDensity = "100",
    groundEffectDist = "500", RAIDgroundEffectDist = "350",
    environmentDetail = "150", RAIDenvironmentDetail = "120",
    shadowMode = "3", RAIDshadowMode = "2",
    SSAO = "3", RAIDSSAO = "2",
    waterDetail = "2", RAIDwaterDetail = "2",
    particleDensity = "90", RAIDparticleDensity = "70",
    giQuality = "3", RAIDgiQuality = "2",
    projectedTextures = "1", RAIDprojectedTextures = "1",
    spellClutter = "75", RAIDspellClutter = "55",
    RenderScale = "1.2", ffxAntiAliasingMode = "2",
    maxFPS = "144", maxFPSBk = "40",
    useMaxFPS = "1", useMaxFPSBk = "1", useTargetFPS = "1",
}
local function Copy(src)
    local copy = {}
    for name, value in pairs(src) do copy[name] = value end
    return copy
end
local original = Copy(cvars)
local writes = {}
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value)
        if cvars[name] == nil then return false end
        -- On this simulated client, UI preset values do not cascade to engine CVars.
        cvars[name] = tostring(value)
        writes[#writes + 1] = name
        return true
    end,
}
assert(loadfile("Graphics.lua"))(addon, F)
assert(type(F.Graphics.Apply) == "function", "production Graphics.lua not loaded")

local frames = {}
local function Texture()
    return setmetatable({}, {__index = function() return function() end end})
end
local function Frame(name)
    local frame = {scripts = {}}
    setmetatable(frame, {__index = function(_, method)
        if method == "CreateTexture" then return function() return Texture() end end
        if method == "GetFrameLevel" then return function() return 1 end end
        return function(self, ...)
            if method == "SetScript" then
                self.scripts[select(1, ...)] = select(2, ...)
            end
        end
    end})
    frames[#frames + 1] = frame
    if name then frames[name] = frame end
    return frame
end
Minimap = Frame("Minimap")
UIParent = Frame("UIParent")
function CreateFrame(_, name) return Frame(name) end
C_Timer = {After = function(_, callback) callback() end}
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
local function Boot()
    assert(loadfile("YinYang.lua"))(addon, F)
    local loadingFrame = frames[#frames]
    loadingFrame.scripts.OnEvent(loadingFrame, "ADDON_LOADED", addon)
    return assert(frames.ForeverYinYangButton).scripts.OnClick, loadingFrame, frames[#frames]
end
local click,root,keyboard = Boot()
assert(not ForeverYinYangDB.active)
click() -- Yang -> standard Yin
assert(ForeverYinYangDB.active and ForeverYinYangDB.tier == "standard")
assert(cvars.graphicsQuality == "1" and cvars.RAIDgraphicsQuality == "1")
assert(cvars.maxFPS == "20" and cvars.maxFPSBk == "10")
assert(cvars.useTargetFPS == "0" and cvars.RenderScale == "0.35")
assert(cvars.farclip == "2200" and cvars.RAIDfarclip == "2200")
assert(cvars.groundEffectDensity == "24" and cvars.RAIDgroundEffectDensity == "24")
assert(cvars.projectedTextures == "1")
clock = 119
root.scripts.OnUpdate(root, 0.25)
assert(ForeverYinYangDB.tier == "standard")
clock = 120
root.scripts.OnUpdate(root, 0.25)
assert(ForeverYinYangDB.tier == "extreme")
assert(cvars.maxFPS == "3" and cvars.maxFPSBk == "3")
assert(cvars.RenderScale == "0.1")
local engineLow = {
    farclip = "1600", RAIDfarclip = "1600",
    horizonStart = "800", RAIDhorizonStart = "800",
    groundEffectDensity = "16", RAIDgroundEffectDensity = "16",
    groundEffectDist = "70", RAIDgroundEffectDist = "70",
    terrainLodDist = "400", RAIDterrainLodDist = "400",
    shadowMode = "0", RAIDshadowMode = "0",
    SSAO = "0", RAIDSSAO = "0",
    particleDensity = "10", RAIDparticleDensity = "10",
    giQuality = "1", RAIDgiQuality = "1",
    projectedTextures = "0", RAIDprojectedTextures = "0",
}
for name, value in pairs(engineLow) do
    assert(cvars[name] == value, name .. ": engine CVar remained " .. tostring(cvars[name]))
end
assert(#writes >= 15, "graphics engine values were not written")
keyboard.scripts.OnKeyDown(keyboard, "W")
assert(ForeverYinYangDB.tier == "standard" and cvars.maxFPS == "20")
-- Reloading while Yin is active must not lose the original graphics snapshot.
click, root, keyboard = Boot()
assert(ForeverYinYangDB.active and ForeverYinYangDB.tier == "standard")
click() -- Yin -> Yang
assert(not ForeverYinYangDB.active and ForeverYinYangDB.original == nil)
for name, value in pairs(original) do
    assert(cvars[name] == value, "failed to restore " .. name)
end
print("PASS: production Graphics.lua, standard/extreme CVars, input wake and exact restore")
