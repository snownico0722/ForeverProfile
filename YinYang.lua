-- A single minimap toggle: Yang restores the user's graphics; Yin minimizes GPU work.
local addonName, F = ...
local G = F.Graphics
local db
local button
local busy = false
local warning

-- Only native graphics options already present on this Forever client are touched.
-- Do not include engine-derived CVars here: the native preset sets those safely.
local qualityOptions = {
    "ShadowQuality", "LiquidDetail", "ParticleDensity", "SSAO", "DepthEffects",
    "ComputeEffects", "OutlineMode", "TextureResolution", "SpellDensity",
    "ProjectedTextures", "ViewDistance", "EnvironmentDetail", "GroundClutter",
    "Sunshafts", "LightMode", "PBRLiquidDetail", "BloomUserMult",
}

local function Notify(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffdec56b阴阳省电|r：" .. message)
    end
end

local function Minimum(snapshot)
    local values = {}
    local function Put(name, value)
        if snapshot.values[name] ~= nil then values[name] = tostring(value) end
    end

    -- Graphics presets must be written before individual settings (Graphics.lua
    -- guarantees that ordering). Explicit settings also handle customized presets.
    Put("graphicsQuality", 0)
    Put("RAIDgraphicsQuality", 0)
    for _, prefix in ipairs({"graphics", "raidGraphics"}) do
        for _, suffix in ipairs(qualityOptions) do
            Put(prefix .. suffix, 0)
        end
    end
    -- A graphicsQuality CVar change can leave the real renderer untouched.
    -- Write a small set of safe, low-cost engine values too. Never use zero
    -- indiscriminately (e.g. giQuality requires at least 1). Yang restores
    -- these CVars from the existing full snapshot, including custom values.
    local engineLow = {
        {"farclip", 1600}, {"horizonStart", 800}, {"horizonClip", 1600},
        {"terrainLodDist", 400}, {"wmoLodDist", 350},
        {"groundEffectDensity", 16}, {"groundEffectDist", 70},
        {"environmentDetail", 50},
        {"shadowMode", 0}, {"shadowSoft", 0}, {"SSAO", 0},
        {"waterDetail", 0}, {"reflectionMode", 0}, {"refraction", 0},
        {"rippleDetail", 0}, {"sunShafts", 0},
        {"particleDensity", 10}, {"particleMTDensity", 10},
        {"projectedTextures", 0}, {"volumeFog", 0},
        {"spellClutter", 0}, {"giQuality", 1}, {"textureFilteringMode", 0},
    }
    for _, group in ipairs({"", "RAID"}) do
        for _, option in ipairs(engineLow) do
            Put(group .. option[1], option[2])
        end
    end
    -- These are in-game render/FPS settings, not Windows resolution or refresh.
    Put("RenderScale", 0.1)
    Put("ffxAntiAliasingMode", 0)
    Put("MSAAQuality", "0,0")
    Put("msaaAlphaTest", 0)
    Put("shadowrt", 0)
    Put("bloomEnable", 0)
    Put("bloomUserMult", 0)
    Put("ResampleSharpness", 0)
    Put("vsync", 0)
    Put("maxFPS", 8)
    Put("maxFPSBk", 8)
    Put("useMaxFPS", 1)
    Put("useMaxFPSBk", 1)
    Put("useTargetFPS", 0)
    return { values = values }
end

local function UpdateButton()
    if not button then return end
    -- Rotate the glyph by half a turn rather than adding a second button.
    button.icon:SetRotation(db.active and math.pi or 0)
    button.icon:SetVertexColor(db.active and 0.78 or 1, db.active and 0.86 or 1, 1)
    button:SetAlpha(busy and 0.65 or 1)
end

local function Toggle()
    if busy then return end
    local restoring = db.active
    local target
    if restoring then
        target = db.original
        if not target then
            Notify("没有可恢复的画质快照。")
            return
        end
    else
        local original, err = G.Capture()
        if not original then
            Notify("无法读取当前画质：" .. (err or "未知错误"))
            return
        end
        target = Minimum(original)
        local valid, reason = G.Validate(target)
        if not valid then
            Notify("无法创建最低画质：" .. (reason or "未知错误"))
            return
        end
        -- Preserve before writing any CVar. SavedVariables survive normal
        -- logout/reload, so Yin can still be undone in the next session.
        db.original = original
        db.active = true
    end

    busy = true
    warning = nil
    UpdateButton()
    local ok, result = pcall(G.Apply, target)
    if not ok or type(result) ~= "table" then
        busy = false
        warning = "画质设置未能完整切换"
        Notify(warning .. "，可以再点图标重试。")
        UpdateButton()
        return
    end

    local function Finish()
        local comparison = G.Compare(target)
        if comparison.matches then
            if restoring then
                db.active = false
                db.original = nil
                Notify("已恢复原来的画质和帧率。")
            else
                Notify("已开启阴面：最低画质，前后台限制 8 FPS。")
            end
        else
            warning = restoring and "恢复不完整，点击重试" or "部分省电设置未生效"
            Notify(warning .. "（" .. tostring(comparison.matched or 0) .. "/" ..
                tostring(comparison.total or 0) .. "）。")
        end
        busy = false
        UpdateButton()
    end
    -- The client can change child CVars after a graphics preset is applied.
    if C_Timer and C_Timer.After then C_Timer.After(0.35, Finish) else Finish() end
end

local function ShowTooltip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("阴阳省电")
    if db.active then
        GameTooltip:AddLine("阴 · 省电中（前后台 8 FPS）", 0.65, 0.83, 1)
        GameTooltip:AddLine("左键恢复原画质", 1, 1, 1)
    else
        GameTooltip:AddLine("阳 · 正常画质", 1, 0.85, 0.48)
        GameTooltip:AddLine("左键切换到最低画质与帧率", 1, 1, 1)
    end
    if warning then GameTooltip:AddLine(warning, 1, 0.4, 0.4) end
    GameTooltip:Show()
end

local function CreateButton()
    if not Minimap then return end
    button = CreateFrame("Button", "ForeverYinYangButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    -- Standard minimap rim position (upper-left). No extra settings panel.
    button:SetPoint("CENTER", Minimap, "CENTER", -69, 39)
    button:RegisterForClicks("LeftButtonUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\ForeverProfiles\\Media\\YinYang")
    icon:SetAllPoints(button)
    button.icon = icon

    button:SetScript("OnClick", Toggle)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    UpdateButton()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if event ~= "ADDON_LOADED" or name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    local saved = ForeverYinYangDB
    if type(saved) == "table" and saved.active == true
        and G.Validate(saved.original) then
        db = saved
    else
        db = {active = false}
        ForeverYinYangDB = db
    end
    CreateButton()
end)
