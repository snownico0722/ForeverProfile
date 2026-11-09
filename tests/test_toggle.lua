-- UI/state smoke test; the real Graphics.lua is covered by the integration test.
local clock, cursorX, cursorY, clampFPS = 0, 10, 20, false
function GetTime() return clock end
function GetCursorPosition() return cursorX, cursorY end
function IsWindowFocused() return true end
local frames, byName = {}, {}
local state = {
    graphicsQuality = "7", RAIDgraphicsQuality = "6",
    graphicsShadowQuality = "4", graphicsViewDistance = "6",
    farclip = "7500", RAIDfarclip = "6500", projectedTextures = "1",
    RenderScale = "1.0", maxFPS = "120", maxFPSBk = "45",
    useMaxFPS = "0", useMaxFPSBk = "1", useTargetFPS = "1",
}
local function Copy(source)
    local target = {}
    for k, v in pairs(source) do target[k] = v end
    return target
end
local original = Copy(state)
local G = {}
local partialRestore = false
function G.Capture() return {values = Copy(state)} end
function G.Validate(snapshot)
    return type(snapshot)=="table" and type(snapshot.values)=="table" and next(snapshot.values)~=nil
end
function G.Apply(snapshot)
    for k, value in pairs(snapshot.values) do
        if not (partialRestore and k=="maxFPS" and value=="120") then
            state[k] = clampFPS and (k=="maxFPS" or k=="maxFPSBk") and value=="3" and "8" or value
        end
    end
    return {success = true}
end
function G.GetValue(name) return state[name] end
function G.Compare(snapshot)
    local matched,total=0,0
    for k,v in pairs(snapshot.values) do
        total=total+1
        if tostring(state[k])==tostring(v) then matched=matched+1 end
    end
    return {total=total,matched=matched,matches=matched==total}
end
local function NewFrame(name)
    local frame = {scripts={}}
    setmetatable(frame,{__index=function(t,method)
        if method=="GetFrameLevel" then return function() return 1 end end
        if method=="CreateTexture" then return function()
            return setmetatable({},{__index=function()return function()end end})
        end end
        return function(self,...)
            if method=="SetScript" then self.scripts[select(1,...)]=select(2,...) end
        end
    end})
    frames[#frames+1]=frame
    if name then byName[name]=frame end
    return frame
end
Minimap=NewFrame("Minimap")
UIParent=NewFrame("UIParent")
function CreateFrame(_, name) return NewFrame(name) end
C_Timer={After=function(_,f)f()end}
DEFAULT_CHAT_FRAME={AddMessage=function()end}
local F={Graphics=G}
local function Boot()
    assert(loadfile("YinYang.lua"))("ForeverProfiles",F)
    local root=frames[#frames]
    root.scripts.OnEvent(root,"ADDON_LOADED","ForeverProfiles")
    local keyListener=frames[#frames]
    return byName.ForeverYinYangButton,root,keyListener
end
local button,root,keys=Boot()
button.scripts.OnClick()
assert(ForeverYinYangDB.active and ForeverYinYangDB.tier=="standard")
assert(state.graphicsQuality=="1" and state.RenderScale=="0.35")
assert(state.maxFPS=="20" and state.maxFPSBk=="10")
clock=119
root.scripts.OnUpdate(root,0.25)
assert(ForeverYinYangDB.tier=="standard")
clock=120
root.scripts.OnUpdate(root,0.25)
assert(ForeverYinYangDB.tier=="extreme" and state.maxFPS=="3" and state.maxFPSBk=="3")
assert(state.RenderScale=="0.1")
cursorX=45
root.scripts.OnUpdate(root,0.25)
assert(ForeverYinYangDB.tier=="standard" and state.maxFPS=="20")
clock=200
root.scripts.OnEvent(root,"GLOBAL_MOUSE_DOWN","LeftButton")
clock=319
root.scripts.OnUpdate(root,0.25)
assert(ForeverYinYangDB.tier=="standard")
clock=320
root.scripts.OnUpdate(root,0.25)
assert(ForeverYinYangDB.tier=="extreme")
keys.scripts.OnKeyDown(keys,"W")
assert(ForeverYinYangDB.tier=="standard")
partialRestore=true
button.scripts.OnClick()
assert(ForeverYinYangDB.active and ForeverYinYangDB.original)
partialRestore=false
button.scripts.OnClick()
assert(not ForeverYinYangDB.active and ForeverYinYangDB.original==nil)
for k,v in pairs(original) do assert(state[k]==v,"failed to restore "..k)end
clampFPS=true
clock=500
button.scripts.OnClick()
clock=620
root.scripts.OnUpdate(root,0.25)
assert(ForeverYinYangDB.tier=="extreme" and ForeverYinYangDB.extremeFPS==8)
assert(state.maxFPS=="8" and state.maxFPSBk=="8")
button,root,keys=Boot()
assert(ForeverYinYangDB.tier=="extreme")
button.scripts.OnClick()
assert(not ForeverYinYangDB.active)
for k,v in pairs(original) do assert(state[k]==v,"failed reload restore "..k)end
print("PASS: 20/10 staging, idle timer, wake, FPS fallback, snapshot restore and reload")
