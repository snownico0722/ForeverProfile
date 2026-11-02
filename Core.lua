local addonName, F = ...
local L, P, G = F.L, F.Profiles, F.Graphics
F.results = {}

local function Refresh()
    if F.UI then F.UI.Refresh() end
end

function F.Notify(message, isError)
    local prefix = isError and "|cffffb38aForever Profiles|r: " or "|cffd7b46bForever Profiles|r: "
    print(prefix .. message)
    if F.UI then F.UI.SetNotice(message, isError); Refresh() end
end

local function Error(message)
    message = L[message or "Settings could not be applied."]
    F.Notify(message, true)
    return nil, message
end

local function CanAct()
    if not F.ready then return Error(F.startupError or "Addon is not ready.") end
    if F.busy then return Error("Wait for the current switch to finish.") end
    return true
end

local function Changed(profile, message)
    P.SetSelected(profile.id)
    F.Notify(F.Format(message, profile.name))
    return profile
end

function F.CreateProfile(name)
    if not CanAct() then return nil end
    local snapshot, err = G.Capture()
    if not snapshot then return Error(err) end
    local profile, createError = P.Create(name, snapshot)
    if not profile then return Error(createError) end
    return Changed(profile, "Saved profile: %s.")
end

function F.UpdateProfile(id)
    if not CanAct() then return nil end
    local snapshot, err = G.Capture()
    if not snapshot then return Error(err) end
    local profile, updateError = P.Update(id, snapshot)
    if not profile then return Error(updateError) end
    F.results[id] = nil
    return Changed(profile, "Updated profile: %s.")
end

function F.RenameProfile(id, name)
    if not CanAct() then return nil end
    local profile, err = P.Rename(id, name)
    if not profile then return Error(err) end
    return Changed(profile, "Renamed profile: %s.")
end

function F.DuplicateProfile(id, name)
    if not CanAct() then return nil end
    local profile, err = P.Duplicate(id, name)
    if not profile then return Error(err) end
    return Changed(profile, "Duplicated profile: %s.")
end

function F.DeleteProfile(id)
    if not CanAct() then return nil end
    local profile = P.Get(id)
    if not profile then return Error("Profile not found.") end
    local name = profile.name
    local ok, err = P.Delete(id)
    if not ok then return Error(err) end
    F.results[id] = nil
    F.Notify(F.Format("Deleted profile: %s.", name))
    return true
end

function F.ToggleFavorite(id)
    if not CanAct() then return nil end
    local ok, err = P.ToggleFavorite(id)
    if not ok then return Error(err) end
    Refresh()
    return true
end

function F.SetQuickBarVisible(visible)
    if not F.ready then return end
    P.GetDB().ui.quickBarVisible = visible == true
    Refresh()
end

function F.SetQuickBarLocked(locked)
    if not F.ready then return end
    P.GetDB().ui.quickBarLocked = locked == true
    Refresh()
end

function F.SetQuickBarScale(scale)
    if not F.ready or type(scale) ~= "number" or scale ~= scale
        or scale == math.huge or scale == -math.huge then return end
    scale = math.floor(math.max(0.6, math.min(1.8, scale)) * 100 + 0.5) / 100
    P.GetDB().ui.quickBarScale = scale
    Refresh()
    return scale
end

function F.GetQuickBarDimensions()
    if not F.ready then return end
    local ui = P.GetDB().ui
    local count = math.min(3, #P.Favorites())
    local start = ui.quickBarLocked and 51 or 75
    local automaticWidth = count == 0 and start + 293 or start + count * 142
    return ui.quickBarWidth or automaticWidth, ui.quickBarHeight or 44
end

local function SetBarDimension(key, value, minimum, maximum)
    if not F.ready or type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge then return end
    value = math.floor(math.max(minimum, math.min(maximum, value)) + 0.5)
    P.GetDB().ui[key] = value
    Refresh()
    return value
end

function F.SetQuickBarWidth(width)
    if not F.ready then return end
    if width == nil then
        P.GetDB().ui.quickBarWidth = nil
        Refresh()
        local actualWidth = F.GetQuickBarDimensions()
        return actualWidth
    end
    return SetBarDimension("quickBarWidth", width, 160, 1000)
end

function F.SetQuickBarHeight(height)
    return SetBarDimension("quickBarHeight", height, 28, 120)
end

function F.GetProfileStatus(id)
    local profile = P.Get(id)
    if not profile then return L["Profile not found."], false end
    local comparison = G.Compare(profile.modules.graphics)
    if comparison.matches then return L["Active"], true end
    if F.results[id] and not F.results[id].success then return L["Applied partially"], false end
    return L["Modified"], false
end

function F.CanRestore()
    return F.ready and F.previousSnapshot ~= nil and not F.busy
end

-- Recheck after the client and other addons have processed CVar callbacks.
-- An accepted write does not prove that the requested configuration remained active.
local function Apply(snapshot, id, name, restoring)
    local valid, err = G.Validate(snapshot)
    if not valid then return Error(err) end
    local previous
    if not restoring then
        local comparison = G.Compare(snapshot)
        if comparison.matches then
            F.Notify(F.Format("Profile applied: %s.", name))
            return {success = true, total = comparison.total, unchanged = comparison.total, applied = 0, failed = {}, skipped = {}}
        end
        local captureError
        previous, captureError = G.Capture()
        if not previous then return Error(captureError) end
    end
    F.busy = true
    F.Notify(F.Format("Applying %s…", name))
    local ok, result = pcall(G.Apply, snapshot)
    if not ok or type(result) ~= "table" then
        if previous and not G.Compare(previous).matches then F.previousSnapshot = previous end
        F.busy = false
        return Error("Settings could not be applied.")
    end
    local function Finish()
        local comparison = G.Compare(snapshot)
        if previous and not G.Compare(previous).matches then F.previousSnapshot = previous end
        result.success = comparison.matches
        result.matched = comparison.matched
        result.differences = comparison.differences
        F.busy = false
        if id then F.results[id] = result end
        if restoring and comparison.matches then F.previousSnapshot = nil end
        if comparison.matches then
            F.Notify(restoring and L["Previous settings restored."] or F.Format("Profile applied: %s.", name))
        else
            F.Notify(F.Format("%s: %d of %d settings match. Open the profile for details.",
                name, comparison.matched or 0, comparison.total or 0), true)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.35, Finish) else Finish() end
    return result
end

function F.ApplyProfile(id)
    if not CanAct() then return nil end
    local profile = P.Get(id)
    if not profile then return Error("Profile not found.") end
    P.SetSelected(id)
    return Apply(profile.modules.graphics, id, profile.name, false)
end

function F.RestorePrevious()
    if not CanAct() then return nil end
    if not F.previousSnapshot then return Error("No previous settings to restore.") end
    return Apply(F.previousSnapshot, nil, L["Restore previous settings"], true)
end

function F.ApplyFavorite(slot)
    if not CanAct() then return nil end
    local profile = P.Favorites()[slot]
    if not profile then return Error("No favorite assigned to this slot.") end
    return F.ApplyProfile(profile.id)
end

function ForeverProfiles_Toggle()
    if not F.ready then return Error(F.startupError or "Addon is not ready.") end
    F.UI.Toggle()
end
function ForeverProfiles_ApplyFavorite(slot) return F.ApplyFavorite(slot) end
function ForeverProfiles_Restore() return F.RestorePrevious() end

local function RegisterSettings()
    if F.settingsCategory or not Settings or not Settings.RegisterCanvasLayoutCategory
        or not Settings.RegisterAddOnCategory then return end
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -24)
    title:SetText("Forever Profiles")
    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    help:SetPoint("TOPLEFT", 24, -60)
    help:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    help:SetJustifyH("LEFT")
    help:SetText(L["Open Forever Profiles to save and apply your graphics configurations."])
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetPoint("TOPLEFT", 24, -115)
    open:SetSize(240, 32)
    open:SetText(L["Open profiles"])
    open:SetScript("OnClick", function()
        if SettingsPanel and HideUIPanel then HideUIPanel(SettingsPanel) end
        F.UI.Show()
    end)
    F.settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Forever Profiles")
    Settings.RegisterAddOnCategory(F.settingsCategory)
end

local function FindProfile(name)
    for _, profile in ipairs(P.List()) do
        if profile.id == name or string.lower(profile.name) == string.lower(name) then return profile end
    end
end

local function Slash(text)
    if not F.ready then return Error(F.startupError or "Addon is not ready.") end
    local command, argument = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "" then F.UI.Toggle()
    elseif command == "save" then F.CreateProfile(argument)
    elseif command == "apply" then
        local profile = FindProfile(argument)
        if profile then F.ApplyProfile(profile.id) else Error("Profile not found.") end
    elseif command == "restore" then F.RestorePrevious()
    elseif command == "quick" then F.SetQuickBarVisible(not P.GetDB().ui.quickBarVisible)
    elseif command == "list" then
        for _, profile in ipairs(P.List()) do
            print("|cffd7b46bFP|r: " .. profile.name .. " (" .. F.GetProfileStatus(profile.id) .. ")")
        end
        if #P.List() == 0 then F.Notify(L["No profiles yet"]) end
    elseif command == "diagnostics" then
        local snapshot = G.Capture()
        local count = 0
        for _ in pairs(snapshot and snapshot.values or {}) do count = count + 1 end
        F.Notify(string.format("v%s | WoW %s (%s) | Interface %s | %d CVars | %d profiles",
            F.version, F.clientVersion or "?", F.clientBuild or "?", tostring(F.interfaceVersion or "?"), count, #P.List()))
    else
        F.Notify("/fp  |  /fp save <name>  |  /fp apply <name>  |  /fp restore  |  /fp quick  |  /fp list  |  /fp diagnostics")
    end
end

SLASH_FOREVERPROFILES1 = "/fp"
SLASH_FOREVERPROFILES2 = "/foreverprofiles"
SlashCmdList.FOREVERPROFILES = Slash

local catalogNames = {}
for _, entry in ipairs(G.catalog) do catalogNames[string.lower(entry.name)] = true end
local refreshPending
local events = CreateFrame("Frame")
F.events = events
events:SetScript("OnEvent", function(_, event, arg)
    if issecretvalue and issecretvalue(arg) then return end
    if event == "ADDON_LOADED" and arg == addonName then
        local version, build, date, tocVersion = GetBuildInfo()
        F.clientVersion, F.clientBuild, F.interfaceVersion = version, build, tocVersion
        local toc = tonumber(F.interfaceVersion)
        if not toc or toc < 16000 or toc >= 20000 then
            F.startupError = "This addon requires the WoW Forever client."
            F.Notify(L[F.startupError], true)
            return
        end
        local db, err = P.Initialize(ForeverProfilesDB)
        if not db then
            F.startupError = err
            F.Notify(L[err], true)
            return
        end
        ForeverProfilesDB = db
        F.ready = true
    elseif event == "PLAYER_LOGIN" and F.ready then
        pcall(RegisterSettings)
        F.UI.RefreshQuickBar()
    elseif event == "CVAR_UPDATE" and F.ready and not F.busy then
        if type(arg) ~= "string" or not catalogNames[string.lower(arg)] or refreshPending then return end
        refreshPending = true
        local function Update()
            refreshPending = nil
            if not F.busy then Refresh() end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.2, Update) else Update() end
    end
end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CVAR_UPDATE")
