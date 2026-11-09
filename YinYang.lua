-- A single minimap toggle: Yang restores the user's graphics; Yin minimizes GPU work.
local addonName, F = ...
local G = F.Graphics
local db, button
local busy, queuedToggle, pendingWake = false, false, false
local warning
local lastInput, cursorX, cursorY, elapsedSinceCheck = 0, nil, nil, 0
local IDLE_SECONDS, INPUT_POLL_SECONDS = 120, 0.25

-- Presets and their low-level renderer CVars are both controlled.
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

local engineLow = {
    {"farclip", 1600, 2200}, {"horizonStart", 800, 1100},
    {"horizonClip", 1600, 2200}, {"terrainLodDist", 400, 500},
    {"wmoLodDist", 350, 450}, {"groundEffectDensity", 16, 24},
    {"groundEffectDist", 70, 90}, {"environmentDetail", 50, 60},
    {"shadowMode", 0, 0}, {"shadowSoft", 0, 0}, {"SSAO", 0, 0},
    {"waterDetail", 0, 0}, {"reflectionMode", 0, 0},
    {"refraction", 0, 0}, {"rippleDetail", 0, 0},
    {"sunShafts", 0, 0}, {"particleDensity", 10, 20},
    {"particleMTDensity", 10, 20}, {"projectedTextures", 0, 1},
    {"volumeFog", 0, 0}, {"spellClutter", 0, 20},
    {"giQuality", 1, 1}, {"textureFilteringMode", 0, 0},
}

local standardQuality = {
    ParticleDensity = 1, SpellDensity = 1, ProjectedTextures = 1,
    ViewDistance = 1,
}

local function BuildMode(original, tier, extremeFPS)
    local standard = tier == "standard"
    local values = {}
    local function Put(name, value)
        if original.values[name] ~= nil then values[name] = tostring(value) end
    end
    Put("graphicsQuality", standard and 1 or 0)
    Put("RAIDgraphicsQuality", standard and 1 or 0)
    for _, prefix in ipairs({"graphics", "raidGraphics"}) do
        for _, suffix in ipairs(qualityOptions) do
            Put(prefix .. suffix, standard and (standardQuality[suffix] or 0) or 0)
        end
    end
    -- Preset selectors alone can leave the engine-side CVars unchanged.
    for _, prefix in ipairs({"", "RAID"}) do
        for _, entry in ipairs(engineLow) do
            Put(prefix .. entry[1], standard and entry[3] or entry[2])
        end
    end
    Put("RenderScale", standard and 0.35 or 0.1)
    Put("ffxAntiAliasingMode", 0)
    Put("MSAAQuality", "0,0")
    Put("msaaAlphaTest", 0)
    Put("shadowrt", 0)
    Put("bloomEnable", 0)
    Put("bloomUserMult", 0)
    Put("ResampleSharpness", 0)
    Put("vsync", 0)
    Put("maxFPS", standard and 20 or extremeFPS)
    Put("maxFPSBk", standard and 10 or extremeFPS)
    Put("useMaxFPS", 1)
    Put("useMaxFPSBk", 1)
    Put("useTargetFPS", 0)
    return {values = values}
end

local function CurrentTime()
    return type(GetTime) == "function" and GetTime() or 0
end

local function UpdateButton()
    if not button then return end
    -- Rotate the glyph by half a turn rather than adding a second button.
    button.icon:SetRotation(db.active and math.pi or 0)
    button.icon:SetVertexColor(db.active and 0.78 or 1, db.active and 0.86 or 1, 1)
    button:SetAlpha(busy and 0.65 or 1)
end

local Toggle, ApplyMode

local function FinishWork()
    busy = false
    UpdateButton()
    -- A click made during automatic wakeup must still restore normal graphics.
    if queuedToggle then
        queuedToggle = false
        Toggle()
    elseif pendingWake and db.active and db.tier == "extreme" then
        pendingWake = false
        ApplyMode("standard")
    else
        pendingWake = false
    end
end

ApplyMode = function(tier)
    if busy or not db.active or not db.original then return end
    local preferred = tier == "extreme" and (db.extremeFPS or 3) or 20
    local target = BuildMode(db.original, tier, preferred)
    local valid, reason = G.Validate(target)
    if not valid then
        Notify("无法创建画质档位：" .. tostring(reason))
        return
    end

    busy = true
    warning = nil
    db.tier = tier
    UpdateButton()
    local ok, result = pcall(G.Apply, target)
    if not ok or type(result) ~= "table" then
        warning = "画质设置未能完整切换"
        Notify(warning)
        FinishWork()
        return
    end

    local function Finish()
        if tier == "extreme" and preferred == 3 then
            -- If the client clamps the 3 FPS CVar, fall back to 8 FPS.
            local foreground = target.values.maxFPS and tonumber(G.GetValue("maxFPS")) or 3
            local background = target.values.maxFPSBk and tonumber(G.GetValue("maxFPSBk")) or 3
            if foreground ~= 3 or background ~= 3 then
                db.extremeFPS = 8
                target = BuildMode(db.original, "extreme", 8)
                pcall(G.Apply, target)
                Notify("客户端未接受 3 FPS，极限档已改用 8 FPS。")
            else
                db.extremeFPS = 3
            end
        end
        local comparison = G.Compare(target)
        if not comparison.matches then
            warning = "部分省电设置未生效"
            Notify(warning .. "（" .. tostring(comparison.matched or 0) .. "/" ..
                tostring(comparison.total or 0) .. "）。")
        elseif tier == "extreme" then
            Notify("连续 2 分钟无操作，已进入极限省电（FPS 上限 " ..
                tostring(db.extremeFPS or 8) .. "）。")
        end
        FinishWork()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.35, Finish) else Finish() end
end

local function Activity()
    if not db or not db.active then return end
    lastInput = CurrentTime()
    if db.tier == "extreme" then
        if busy then pendingWake = true else ApplyMode("standard") end
    end
end

local function Tick(_, elapsed)
    if not db or not db.active then return end
    elapsedSinceCheck = elapsedSinceCheck + elapsed
    if elapsedSinceCheck < INPUT_POLL_SECONDS then return end
    elapsedSinceCheck = 0
    if type(GetCursorPosition) == "function" then
        local x, y = GetCursorPosition()
        if x ~= nil and y ~= nil then
            if cursorX ~= nil and (cursorX ~= x or cursorY ~= y) then
                -- Avoid counting desktop motion as WoW input when a focus
                -- query is available from the installed client.
                if type(IsWindowFocused) ~= "function" or IsWindowFocused() then
                    Activity()
                end
            end
            cursorX, cursorY = x, y
        end
    end
    if db.tier == "standard" and not busy and CurrentTime() - lastInput >= IDLE_SECONDS then
        ApplyMode("extreme")
    end
end

Toggle = function()
    if busy then queuedToggle = true; return end
    if db.active then
        local original = db.original
        if not original then Notify("没有可恢复的原始画质快照。"); return end
        busy = true
        warning = nil
        UpdateButton()
        local ok, result = pcall(G.Apply, original)
        if not ok or type(result) ~= "table" then
            warning = "原画质恢复失败"
            Notify(warning)
            FinishWork()
            return
        end
        local function Finish()
            local comparison = G.Compare(original)
            if comparison.matches then
                db.active = false
                db.tier = nil
                db.original = nil
                Notify("已恢复正常画质和帧率。")
            else
                warning = "恢复不完整，点击重试"
                Notify(warning .. "（" .. tostring(comparison.matched or 0) .. "/" ..
                    tostring(comparison.total or 0) .. "）。")
            end
            FinishWork()
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.35, Finish) else Finish() end
        return
    end
    local original, reason = G.Capture()
    if not original then Notify("无法读取当前画质：" .. tostring(reason)); return end
    db.original = original
    db.active = true
    lastInput = CurrentTime()
    if type(GetCursorPosition) == "function" then cursorX, cursorY = GetCursorPosition() end
    ApplyMode("standard")
    Notify("已进入阴面·标准省电（35% 渲染、前台 20 FPS、后台 10 FPS）。")
end

local function ShowTooltip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("阴阳省电")
    if not db.active then
        GameTooltip:AddLine("阳 · 正常画质", 1, 0.85, 0.48)
        GameTooltip:AddLine("左键切换到标准省电", 1, 1, 1)
    elseif db.tier == "extreme" then
        GameTooltip:AddLine("阴 · 极限省电（" .. tostring(db.extremeFPS or 3) .. " FPS 上限）", 0.65, 0.83, 1)
        GameTooltip:AddLine("输入后自动恢复标准省电；左键退出阴面", 1, 1, 1)
    else
        GameTooltip:AddLine("阴 · 标准省电（前台 20 / 后台 10 FPS）", 0.65, 0.83, 1)
        GameTooltip:AddLine("无输入 2 分钟自动进入极限省电", 1, 1, 1)
        GameTooltip:AddLine("左键恢复原画质", 1, 1, 1)
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
frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
frame:RegisterEvent("PLAYER_STARTED_MOVING")
frame:SetScript("OnUpdate", Tick)
frame:SetScript("OnEvent", function(self, event, name)
    if event == "GLOBAL_MOUSE_DOWN" or event == "PLAYER_STARTED_MOVING" then
        Activity()
        return
    end
    if event ~= "ADDON_LOADED" or name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    local saved = ForeverYinYangDB
    if type(saved) == "table" and saved.active == true and G.Validate(saved.original) then
        db = saved
        -- Existing single-stage Yin sessions were the old extreme preset.
        db.tier = db.tier == "standard" and "standard" or "extreme"
    else
        db = {active = false}
        ForeverYinYangDB = db
    end
    lastInput = CurrentTime()
    if type(GetCursorPosition) == "function" then cursorX, cursorY = GetCursorPosition() end
    CreateButton()
    -- Capture keyboard activity without consuming any existing key bindings.
    local keys = CreateFrame("Frame", nil, UIParent)
    keys:SetSize(1, 1)
    keys:EnableKeyboard(true)
    keys:SetPropagateKeyboardInput(true)
    keys:SetScript("OnKeyDown", Activity)
end)
