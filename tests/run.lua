local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    passed = passed + 1
    print("PASS " .. name)
end
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local secret = {}
issecretvalue = function(value) return value == secret end
GetLocale = function() return "enUS" end
GetBuildInfo = function() return "1.60.1", "70707", "", 16001 end
time = function() return 1790899200 end
SlashCmdList = {}
local F = {}
assert(loadfile("Init.lua"))("ForeverProfiles", F)
assert(loadfile("Graphics.lua"))("ForeverProfiles", F)
assert(loadfile("Profiles.lua"))("ForeverProfiles", F)
local G, P = F.Graphics, F.Profiles
local values, writes, refused, override, delayed = {}, {}, {}, nil, {}
local function reset()
    values = {
        graphicsquality = "8", graphicsshadowquality = "5", shadowmode = "4",
        raidgraphicsquality = "4", raidgraphicsshadowquality = "2", raidshadowmode = "2",
        raidsettingsenabled = "1", renderscale = "1", maxfps = "160", maxfpsbk = "30",
        graphicsprojectedtextures = "1", raidgraphicsprojectedtextures = "1",
    }
    writes, refused, override, delayed = {}, {}, nil, {}
    C_CVar = {
        GetCVar = function(name) return values[string.lower(name)] end,
        SetCVar = function(name, value)
            local key = string.lower(name)
            writes[#writes + 1] = name
            if refused[key] then error("Client refused write") end
            values[key] = tostring(value)
            if key == "graphicsquality" then
                values.graphicsshadowquality = "1"; values.shadowmode = "1"
            elseif key == "raidgraphicsquality" then
                values.raidgraphicsshadowquality = "1"; values.raidshadowmode = "1"
            end
            if override then override(key) end
        end,
    }
    C_Timer = {After = function(_, fn) delayed[#delayed + 1] = fn end}
end
local function flush()
    local work = delayed; delayed = {}
    for _, fn in ipairs(work) do fn() end
end
reset()
local function snapshot(t) return {values = t} end

test("Interface messages and binding labels stay English on a French client", function()
    GetLocale = function() return "frFR" end
    equal(F.L["Apply profile"], "Apply profile")
    equal(F.L["Lock favorite bar"], "Lock favorite bar")
    equal(F.Format("Saved profile: %s.", "Été"), "Saved profile: Été.")
    equal(BINDING_NAME_FOREVERPROFILES_TOGGLE, "Open profiles")
    GetLocale = function() return "enUS" end
end)
test("Graphics summaries preserve both modes and their shared options", function()
    local summary = G.GetSummary(snapshot({graphicsQuality = "8", RAIDgraphicsQuality = "3",
        graphicsShadowQuality = "5", raidGraphicsShadowQuality = "2", RenderScale = "1"}))
    local normal, raid, common = {}, {}, {}
    for _, row in ipairs(summary) do
        local group = row.group == "normal" and normal or row.group == "raid" and raid or common
        group[row.label] = row.value
    end
    equal(normal["Graphics quality"], "9 / 10")
    equal(raid["Graphics quality"], "4 / 10")
    equal(normal.Shadows, "Ultra high")
    equal(raid.Shadows, "Medium")
    equal(common["Render scale"], "100%")
end)

test("Capture both graphics modes and shared settings", function()
    local capture = assert(G.Capture())
    equal(capture.values.graphicsQuality, "8")
    assert(capture.values.raidGraphicsQuality or capture.values.RAIDgraphicsQuality)
    equal(capture.values.RenderScale, "1")
    values.graphicsshadowquality = "0"
    equal(capture.values.graphicsShadowQuality, "5")
end)
test("Apply restores individual settings after global quality side effects", function()
    reset()
    local capture = assert(G.Capture())
    values.graphicsquality = "1"; values.raidgraphicsquality = "1"
    values.graphicsshadowquality = "0"; values.shadowmode = "0"
    values.raidgraphicsshadowquality = "0"; values.raidshadowmode = "0"
    local result = G.Apply(capture)
    assert(result.success)
    equal(values.graphicsshadowquality, "5"); equal(values.shadowmode, "4")
    equal(values.raidgraphicsshadowquality, "2"); equal(values.raidshadowmode, "2")
    assert(G.Compare(capture).matches)
end)
test("Invalid CVar and invalid values cause zero writes", function()
    reset()
    assert(not G.Validate(snapshot({Sound_MasterVolume = "0"})))
    assert(not G.Apply(snapshot({Sound_MasterVolume = "0"})).success)
    assert(not G.Validate(snapshot({graphicsQuality = "999"})))
    assert(not G.Validate(snapshot({graphicsQuality = "nan"})))
    assert(not G.Validate(snapshot({graphicsQuality = "1; print('x')"})))
    equal(#writes, 0)
end)
test("Absent and rejected settings are reported without hiding partial results", function()
    reset()
    local capture = assert(G.Capture())
    values.renderscale = nil
    refused.graphicsshadowquality = true
    values.graphicsshadowquality = "0"; values.graphicsquality = "1"
    local result = G.Apply(capture)
    assert(not result.success)
    assert(#result.skipped > 0); assert(#result.failed > 0)
    equal(values.graphicsquality, "8")
    assert(not G.Compare(capture).matches)
end)
test("Final comparison catches settings reimposed by another addon", function()
    reset()
    override = function() values.graphicsshadowquality = "0" end
    local result = G.Apply(snapshot({graphicsQuality = "4", graphicsShadowQuality = "3"}))
    assert(not result.success)
end)
test("Secret CVar values are skipped safely", function()
    reset()
    values.graphicsshadowquality = secret
    local capture = assert(G.Capture())
    assert(capture.values.graphicsShadowQuality == nil)
    assert(not G.Compare(snapshot({graphicsShadowQuality = "3"})).matches)
end)
test("Numeric representations compare without false mismatches", function()
    reset()
    values.renderscale = "1.000000"
    assert(G.Compare(snapshot({RenderScale = "1"})).matches)
end)
test("Legacy global CVar APIs remain usable", function()
    reset()
    GetCVar, SetCVar = C_CVar.GetCVar, C_CVar.SetCVar
    C_CVar = nil
    local capture = assert(G.Capture())
    values.graphicsquality = "1"
    assert(G.Apply(capture).success)
    GetCVar, SetCVar = nil, nil
    reset()
end)
test("MSAA tuple values and hardware support checks are respected", function()
    reset()
    values.msaaquality = "4,0"
    local capture = assert(G.Capture())
    equal(capture.values.MSAAQuality, "4,0")
    assert(G.Compare(snapshot({MSAAQuality = "4"})).matches)
    assert(not G.Validate(snapshot({MSAAQuality = "4,999"})))
    IsGraphicsSettingValueSupported = function() return 1 end
    values.graphicsshadowquality = "0"
    assert(not G.Apply(snapshot({graphicsShadowQuality = "5"})).success)
    equal(values.graphicsshadowquality, "0")
    IsGraphicsSettingValueSupported = nil
end)
test("Profiles own snapshots, enforce unique safe names, and keep stable IDs", function()
    reset(); assert(P.Initialize(nil))
    local capture = assert(G.Capture())
    local high = assert(P.Create("  High quality  ", capture))
    equal(high.name, "High quality")
    capture.values.graphicsQuality = "2"
    equal(P.Get(high.id).modules.graphics.values.graphicsQuality, "8")
    assert(not P.Create("high QUALITY", capture))
    assert(not P.Create("|cffff0000Bad", capture))
    assert(not P.Create("Bad\nname", capture))
    assert(not P.Create(string.rep("a", 49), capture))
    local clone = assert(P.Duplicate(high.id, "High copy"))
    equal(clone.modules.graphics.values.graphicsQuality, "8")
    assert(P.Rename(high.id, "Quality")); equal(P.Get(high.id).id, high.id)
    local returned = P.Get(high.id); returned.name = "Mutated"
    equal(P.Get(high.id).name, "Quality")
    assert(P.Update(high.id, capture)); equal(P.Get(high.id).modules.graphics.values.graphicsQuality, "2")
end)
test("Favorites are capped, ordered, and cleaned on deletion", function()
    reset(); P.Initialize(nil)
    local profiles = {}
    for index = 1, 4 do
        profiles[index] = assert(P.Create("Profile " .. index, assert(G.Capture())))
    end
    for index = 1, 3 do assert(P.ToggleFavorite(profiles[index].id)) end
    assert(not P.ToggleFavorite(profiles[4].id))
    equal(#P.Favorites(), 3)
    assert(P.Delete(profiles[2].id))
    equal(#P.Favorites(), 2); equal(P.Favorites()[2].id, profiles[3].id)
end)
test("Persistence reload preserves profiles, favorites, selection and positions", function()
    reset(); P.Initialize(nil)
    local profile = assert(P.Create("Raid", assert(G.Capture())))
    P.ToggleFavorite(profile.id); P.SetSelected(profile.id)
    local saved = P.GetDB()
    saved.ui.quickBarVisible = true
    saved.ui.quickBarScale = 1.6
    saved.ui.quickBarWidth = 420
    saved.ui.quickBarHeight = 72
    saved.ui.quickBarLocked = true
    saved.ui.windowPosition = {point = "CENTER", relativePoint = "CENTER", x = 20, y = 30}
    local restored = assert(P.Initialize(saved))
    assert(restored ~= saved)
    equal(P.Get(profile.id).name, "Raid"); equal(#P.Favorites(), 1)
    equal(restored.lastSelectedID, profile.id); equal(restored.ui.windowPosition.x, 20)
    assert(restored.ui.quickBarVisible)
    equal(restored.ui.quickBarScale, 1.6)
    equal(restored.ui.quickBarWidth, 420)
    equal(restored.ui.quickBarHeight, 72)
    assert(restored.ui.quickBarLocked)
end)
test("Favorite bar scale keeps safe bounds and survives old or invalid settings", function()
    local restored = assert(P.Initialize({schemaVersion = 1, ui = {quickBarScale = 1.8}}))
    equal(restored.ui.quickBarScale, 1.8)
    equal(P.Initialize(restored).ui.quickBarScale, 1.8)
    equal(P.Initialize({schemaVersion = 1, ui = {quickBarScale = 0.1}}).ui.quickBarScale, 0.6)
    equal(P.Initialize({schemaVersion = 1, ui = {quickBarScale = 99}}).ui.quickBarScale, 1.8)
    equal(P.Initialize({schemaVersion = 1, ui = {quickBarScale = "1.6"}}).ui.quickBarScale, 1)
    equal(P.Initialize({schemaVersion = 1, ui = {quickBarScale = 0 / 0}}).ui.quickBarScale, 1)
    equal(P.Initialize({schemaVersion = 1, ui = {quickBarVisible = true}}).ui.quickBarScale, 1)
end)
test("Favorite bar dimensions migrate, clamp and persist independently", function()
    local old = assert(P.Initialize({schemaVersion = 1, ui = {quickBarScale = 1.5}}))
    assert(old.ui.quickBarWidth == nil); equal(old.ui.quickBarHeight, 44)
    local saved = assert(P.Initialize({schemaVersion = 1, ui = {quickBarWidth = 540, quickBarHeight = 36}}))
    local restored = assert(P.Initialize(saved))
    equal(restored.ui.quickBarWidth, 540); equal(restored.ui.quickBarHeight, 36)
    local bounded = P.Initialize({schemaVersion = 1, ui = {quickBarWidth = 50, quickBarHeight = 999}})
    equal(bounded.ui.quickBarWidth, 160); equal(bounded.ui.quickBarHeight, 120)
    local invalid = P.Initialize({schemaVersion = 1, ui = {quickBarWidth = "bad", quickBarHeight = 0 / 0}})
    assert(invalid.ui.quickBarWidth == nil); equal(invalid.ui.quickBarHeight, 44)
end)
test("Future saved data is preserved and malformed old entries are sanitized", function()
    local future = {schemaVersion = 2, profiles = {valuable = "keep"}}
    assert(not P.Initialize(future)); equal(future.profiles.valuable, "keep")
    assert(P.Initialize({schemaVersion = 1, profiles = {bad = {}}, order = {false, {}, "bad"},
        favorites = {true}, ui = {windowPosition = {point = "BAD", x = 0, y = 0}}}))
    equal(#P.List(), 0)
end)
test("Maximum profile count rejects overflow without changing storage", function()
    reset(); P.Initialize(nil)
    for index = 1, 40 do assert(P.Create("Profile " .. index, assert(G.Capture()))) end
    assert(not P.Create("One too many", assert(G.Capture())))
    equal(#P.List(), 40)
end)

local frames = {}
CreateFrame = function()
    local frame = {scripts = {}}
    function frame:SetScript(kind, fn) self.scripts[kind] = fn end
    function frame:RegisterEvent() end
    frames[#frames + 1] = frame
    return frame
end
F.UI = {Refresh = function() end, RefreshQuickBar = function() end, SetNotice = function() end,
    Toggle = function() end, Show = function() end}
assert(loadfile("Core.lua"))("ForeverProfiles", F)
local function start(saved)
    reset(); F.ready = nil; F.busy = nil; F.previousSnapshot = nil; F.results = {}
    ForeverProfilesDB = saved
    F.events.scripts.OnEvent(F.events, "ADDON_LOADED", "ForeverProfiles")
end

test("Initialization does not change any game settings", function()
    start(nil)
    assert(F.ready); equal(#writes, 0); equal(#P.List(), 0)
end)
test("Changing bar size saves its setting without changing graphics", function()
    start(nil)
    equal(F.SetQuickBarScale(1.6), 1.6)
    equal(P.GetDB().ui.quickBarScale, 1.6)
    equal(F.SetQuickBarScale(0.1), 0.6)
    equal(F.SetQuickBarScale(9), 1.8)
    assert(not F.SetQuickBarScale("bad"))
    equal(P.GetDB().ui.quickBarScale, 1.8)
    equal(#writes, 0)
end)
test("Favorite bar width and height can be changed separately", function()
    start(nil)
    local width, height = F.GetQuickBarDimensions()
    equal(width, 368); equal(height, 44)
    equal(F.SetQuickBarWidth(420), 420)
    width, height = F.GetQuickBarDimensions()
    equal(width, 420); equal(height, 44)
    equal(F.SetQuickBarHeight(72), 72)
    width, height = F.GetQuickBarDimensions()
    equal(width, 420); equal(height, 72)
    F.SetQuickBarLocked(true)
    width, height = F.GetQuickBarDimensions()
    equal(width, 420); equal(height, 72)
    F.SetQuickBarWidth(nil)
    width, height = F.GetQuickBarDimensions()
    equal(width, 344); equal(height, 72)
    equal(F.SetQuickBarWidth(99999), 1000)
    equal(F.SetQuickBarHeight(5), 28)
    assert(not F.SetQuickBarWidth("bad"))
    equal(P.GetDB().ui.quickBarWidth, 1000)
    equal(#writes, 0)
end)
test("Favorite bar lock persists and old settings remain unlocked", function()
    start(nil)
    assert(not P.GetDB().ui.quickBarLocked)
    F.SetQuickBarLocked(true)
    assert(P.GetDB().ui.quickBarLocked)
    local restored = assert(P.Initialize(P.GetDB()))
    assert(restored.ui.quickBarLocked)
    F.SetQuickBarLocked(false)
    assert(not P.GetDB().ui.quickBarLocked)
    assert(not P.Initialize({schemaVersion = 1, ui = {quickBarLocked = "true"}}).ui.quickBarLocked)
    equal(#writes, 0)
end)
test("Full application, deferred verification and restore work together", function()
    start(nil)
    local high = assert(F.CreateProfile("High"))
    values.graphicsquality = "1"; values.graphicsshadowquality = "1"; values.shadowmode = "1"
    local low = assert(F.CreateProfile("Low"))
    assert(F.ApplyProfile(high.id)); assert(F.busy)
    assert(not F.ApplyProfile(low.id))
    flush(); assert(not F.busy); assert(F.CanRestore())
    assert(G.Compare(high.modules.graphics).matches)
    assert(F.RestorePrevious()); flush()
    assert(G.Compare(low.modules.graphics).matches); assert(not F.CanRestore())
end)
test("Already-active profiles keep the previous restore point", function()
    start(nil)
    local high = assert(F.CreateProfile("High"))
    values.graphicsquality = "1"
    assert(F.ApplyProfile(high.id)); flush()
    local previous = F.previousSnapshot
    assert(F.ApplyProfile(high.id)); equal(F.previousSnapshot, previous)
end)
test("An entirely refused switch retains the last useful restore point", function()
    start(nil)
    local high = assert(F.CreateProfile("High"))
    values.graphicsquality = "1"
    local low = assert(F.CreateProfile("Low"))
    assert(F.ApplyProfile(high.id)); flush()
    local previous = F.previousSnapshot
    C_CVar.SetCVar = function() return false end
    assert(F.ApplyProfile(low.id)); flush()
    equal(F.previousSnapshot, previous)
    assert(not F.results[low.id].success)
end)
test("Deferred verification catches late client/addon changes", function()
    start(nil)
    local profile = assert(F.CreateProfile("High"))
    values.graphicsquality = "1"
    assert(F.ApplyProfile(profile.id))
    values.graphicsshadowquality = "0"
    flush()
    assert(not F.results[profile.id].success)
    equal(F.GetProfileStatus(profile.id), "Applied partially")
    assert(F.CanRestore())
end)
test("Favorite bindings and slash commands target the saved configuration", function()
    start(nil)
    local profile = assert(F.CreateProfile("My high quality"))
    assert(F.ToggleFavorite(profile.id)); values.graphicsquality = "1"
    assert(ForeverProfiles_ApplyFavorite(1)); flush()
    assert(G.Compare(profile.modules.graphics).matches)
    values.graphicsquality = "1"
    SlashCmdList.FOREVERPROFILES("apply My high quality"); flush()
    assert(G.Compare(profile.modules.graphics).matches)
    SlashCmdList.FOREVERPROFILES("quick"); assert(P.GetDB().ui.quickBarVisible)
end)
test("Future database and unsupported client never get overwritten", function()
    local future = {schemaVersion = 2, profiles = {precious = true}}
    start(future); assert(not F.ready); equal(ForeverProfilesDB, future)
    GetBuildInfo = function() return "12.0.1", "70000", "", 120001 end
    start(future); assert(not F.ready); equal(ForeverProfilesDB, future); equal(#writes, 0)
    GetBuildInfo = function() return "1.60.1", "70707", "", 16001 end
end)
test("Future module data fits the same copy budget as complete profile records", function()
    reset(); P.Initialize(nil)
    local profile = assert(P.Create("Future modules", assert(G.Capture())))
    local data = P.GetDB()
    local nested = {}; local cursor = nested
    for _ = 1, 7 do cursor.child = {}; cursor = cursor.child end
    data.profiles[profile.id].modules.audio = nested
    assert(P.Initialize(data))
    assert(P.Get(profile.id)); equal(#P.List(), 1)
    assert(P.Duplicate(profile.id, "Copy still visible"))
end)
test("WoW Forever release derived and shared CVars are captured, validated and restored", function()
    reset()
    values.pbrliquiddetail = "2"; values.raidpbrliquiddetail = "1"
    values.spellclutter = "2"; values.raidspellclutter = "1"
    values.entityshadowfadescale = "25"; values.raidentityshadowfadescale = "15"
    values.terrainloddiv = "768"; values.raidterrainloddiv = "512"
    values.doodadlodscale = "150"; values.raiddoodadlodscale = "100"
    values.entityloddist = "10"; values.raidentityloddist = "8"
    values.reflectiondownscale = "1"; values.raidreflectiondownscale = "2"
    values.volumefog = "1"; values.raidvolumefog = "1"
    values.particulatesenabled = "1"; values.raidparticulatesenabled = "1"
    values.clusteredshading = "1"; values.raidclusteredshading = "1"
    values.giquality = "4"; values.raidgiquality = "4"
    values.graphicslightmode = "3"; values.raidgraphicslightmode = "3"
    values.lowlatencymode = "5"
    values.spellvisualdensityfiltersetting = "2"
    values.bloomusermult = "1"; values.bloomenable = "1"
    local capture = assert(G.Capture())
    equal(capture.values.pbrLiquidDetail, "2")
    equal(capture.values.RAIDpbrLiquidDetail, "1")
    equal(capture.values.spellClutter, "2")
    equal(capture.values.RAIDspellClutter, "1")
    equal(capture.values.entityShadowFadeScale, "25")
    equal(capture.values.RAIDentityShadowFadeScale, "15")
    equal(capture.values.terrainLodDiv, "768")
    equal(capture.values.RAIDterrainLodDiv, "512")
    equal(capture.values.doodadLodScale, "150")
    equal(capture.values.RAIDdoodadLodScale, "100")
    equal(capture.values.entityLodDist, "10")
    equal(capture.values.RAIDentityLodDist, "8")
    equal(capture.values.reflectionDownscale, "1")
    equal(capture.values.RAIDreflectionDownscale, "2")
    equal(capture.values.volumeFog, "1")
    equal(capture.values.RAIDvolumeFog, "1")
    equal(capture.values.particulatesEnabled, "1")
    equal(capture.values.RAIDparticulatesEnabled, "1")
    equal(capture.values.clusteredShading, "1")
    equal(capture.values.RAIDclusteredShading, "1")
    equal(capture.values.giQuality, "4")
    equal(capture.values.RAIDgiQuality, "4")
    equal(capture.values.graphicsLightMode, "3")
    equal(capture.values.raidGraphicsLightMode, "3")
    equal(capture.values.LowLatencyMode, "5")
    equal(capture.values.spellVisualDensityFilterSetting, "2")
    equal(capture.values.bloomUserMult, "1")
    equal(capture.values.bloomEnable, "1")
    assert(not G.Validate(snapshot({giQuality = "0"})))
    assert(not G.Validate(snapshot({RAIDgiQuality = "0"})))
    assert(not G.Validate(snapshot({giQuality = "5"})))
    assert(not G.Validate(snapshot({LowLatencyMode = "6"})))
    values.pbrliquiddetail = "0"; values.raidpbrliquiddetail = "0"
    values.spellclutter = "0"; values.spellvisualdensityfiltersetting = "1"
    values.giquality = "1"; values.raidgiquality = "1"
    values.lowlatencymode = "1"; values.terrainloddiv = "384"
    assert(G.Apply(capture).success)
    equal(values.pbrliquiddetail, "2"); equal(values.raidpbrliquiddetail, "1")
    equal(values.spellclutter, "2"); equal(values.spellvisualdensityfiltersetting, "2")
    equal(values.giquality, "4"); equal(values.raidgiquality, "4")
    equal(values.lowlatencymode, "5"); equal(values.terrainloddiv, "768")
end)
test("Secret event arguments are ignored before any comparison", function()
    start(nil)
    local uncomparable = setmetatable({}, {__eq = function() error("Secret value compared") end})
    local oldIsSecret = issecretvalue
    issecretvalue = function(value) return value == secret or value == uncomparable end
    F.events.scripts.OnEvent(F.events, "ADDON_LOADED", uncomparable)
    F.events.scripts.OnEvent(F.events, "CVAR_UPDATE", uncomparable)
    issecretvalue = oldIsSecret
end)
print(string.format("%d behavior tests passed.", passed))
ForeverProfilesTestContext = {F = F, reset = reset, flush = flush, start = start}

