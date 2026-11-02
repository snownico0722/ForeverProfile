local _, F = ...
local G = {}
F.Graphics = G

-- Explicit allowlist: settings exposed by Blizzard's graphics panel and the
-- engine CVars they derive. Never enumerate or write the entire CVar registry.
-- The order matters: presets first, individual UI options next, engine values
-- last. This preserves custom settings when a preset changes its children.
local catalog, byName = {}, {}
G.catalog = catalog

local function Add(name, label, group, minimum, maximum, integer, support)
    local entry = {
        name = name, label = label, group = group,
        minimum = minimum, maximum = maximum, integer = integer,
        support = support,
    }
    catalog[#catalog + 1] = entry
    byName[name] = entry
end

-- Modern Classic sliders store 0..9 and display 1..10. Do not offset saved
-- values. The RAIDgraphicsQuality spelling also works on this Forever build.
Add("graphicsQuality", "Graphics quality", "normal", 0, 9, true)
Add("RAIDgraphicsQuality", "Graphics quality", "raid", 0, 9, true)

local settings = {
    {"ShadowQuality", "Shadows", 0, 5},
    {"LiquidDetail", "Liquids", 0, 3},
    {"ParticleDensity", "Particles", 0, 5},
    {"SSAO", "Ambient occlusion", 0, 4},
    {"DepthEffects", "Depth effects", 0, 3},
    {"ComputeEffects", "Compute effects", 0, 4},
    {"OutlineMode", "Outlines", 0, 2},
    {"TextureResolution", "Textures", 0, 3},
    {"SpellDensity", "Spell density", 0, 5},
    {"ProjectedTextures", "Projected textures", 0, 1},
    {"ViewDistance", "View distance", 0, 9},
    {"EnvironmentDetail", "Environment detail", 0, 9},
    {"GroundClutter", "Ground clutter", 0, 9},
    -- Classic/Forever additions. Absent CVars are ignored at capture time.
    {"Sunshafts", "Sun shafts", 0, 2},
    {"LightMode", "Secondary lighting", 0, 3},
    {"PBRLiquidDetail", "Enhanced liquids", 0, 3},
}
for _, group in ipairs({"normal", "raid"}) do
    local prefix = group == "raid" and "raidGraphics" or "graphics"
    for _, option in ipairs(settings) do
        Add(prefix .. option[1], option[2], group, option[3], option[4], true, "setting")
    end
    Add(prefix .. "BloomUserMult", "Bloom", group, 0, 2, false)
end

-- These values are affected by the UI quality options and may also have been
-- customized by console commands or another addon (notably weather density).
-- Bounds intentionally include the native quality presets, not arbitrary
-- experimental console values. Both normal and native raid variants are saved.
local derived = {
    {"farclip", "View distance", 0, 20000, false},
    {"horizonStart", "Horizon start", 0, 20000, false},
    {"horizonClip", "Horizon distance", 0, 20000, false},
    {"terrainLodDist", "Terrain distance", 0, 2000, false},
    {"terrainLodDiv", "Terrain detail divisor", 0, 2048, false},
    {"wmoLodDist", "Building distance", 0, 2000, false},
    {"doodadLodScale", "Doodad detail scale", 0, 300, false},
    {"entityLodDist", "Entity distance", 0, 100, false},
    {"terrainTextureLod", "Terrain texture detail", 0, 10, true},
    {"terrainMipLevel", "Terrain textures", 0, 3, true},
    {"worldBaseMip", "World textures", 0, 3, true},
    {"componentTextureLevel", "Character textures", 0, 3, true},
    {"textureFilteringMode", "Texture filtering", 0, 5, true},
    {"environmentDetail", "Environment detail", 0, 200, false},
    {"lodObjectCullSize", "Object culling size", 0, 256, false},
    {"lodObjectCullDist", "Object culling distance", 0, 1000, false},
    {"lodObjectMinSize", "Object detail", 0, 1000, false},
    {"lodObjectFadeScale", "Object fade distance", 0, 5000, false},
    {"groundEffectDensity", "Ground clutter density", 0, 256, true},
    {"groundEffectDist", "Ground clutter distance", 0, 600, false},
    {"groundEffectAnimation", "Ground clutter animation", 0, 1, true},
    {"shadowMode", "Shadow mode", 0, 4, true},
    -- Cascade counts and shadow texture allocations are deliberately left to
    -- graphicsShadowQuality: low-level values can crash the Forever client.
    {"shadowSoft", "Soft shadows", 0, 1, true},
    {"shadowBlendCascades", "Shadow blending", 0, 1, true},
    {"entityShadowFadeScale", "Shadow fade distance", 0, 100, false},
    {"waterDetail", "Liquids", 0, 3, true},
    {"pbrLiquidDetail", "Enhanced liquids", 0, 3, true},
    {"rippleDetail", "Water ripples", 0, 3, true},
    {"reflectionMode", "Reflections", 0, 3, true},
    {"reflectionDownscale", "Reflection downscale", 0, 4, true},
    {"refraction", "Refraction", 0, 2, true},
    {"sunShafts", "Sun shafts", 0, 2, true},
    {"SSAO", "Ambient occlusion", 0, 4, true},
    {"DepthBasedOpacity", "Depth effects", 0, 1, true},
    {"OutlineEngineMode", "Outlines", 0, 3, true},
    {"lightMode", "Lighting", 0, 2, true},
    -- Forever's secondary lighting uses 1..4 in the engine (presets 0..9).
    -- Zero is not a supported disabled state and is never captured or written.
    {"giQuality", "Secondary lighting", 1, 4, true},
    {"volumeFog", "Volumetric fog enabled", 0, 1, true},
    {"volumeFogLevel", "Volumetric fog", 0, 4, true},
    {"particulatesEnabled", "Particulates", 0, 1, true},
    {"clusteredShading", "Clustered shading", 0, 1, true},
    {"particleDensity", "Particle density", 0, 100, false},
    {"particleMTDensity", "Particle density", 0, 100, false},
    {"spellClutter", "Spell density", 0, 100, true},
    {"projectedTextures", "Projected textures", 0, 1, true},
    {"weatherDensity", "Weather density", 0, 5, true},
}
for _, group in ipairs({"normal", "raid"}) do
    for _, option in ipairs(derived) do
        local name = group == "raid" and ("RAID" .. option[1]) or option[1]
        Add(name, option[2], group, option[3], option[4], option[5])
    end
end

Add("spellVisualDensityFilterSetting", "Spell density", "common", 0, 4, true)
Add("bloomUserMult", "Bloom", "common", 0, 2, false)
Add("bloomEnable", "Bloom enabled", "common", 0, 1, true)
Add("RenderScale", "Render scale", "common", 0.1, 2, false)
Add("ResampleQuality", "Resampling", "common", 0, 3, true, "cvar")
Add("ResampleSharpness", "Resample sharpness", "common", 0, 2, false)
Add("ffxAntiAliasingMode", "Image antialiasing", "common", 0, 4, true, "fxaa")
Add("MSAAQuality", "Multisample antialiasing", "common", 0, 16, true, "msaa")
Add("msaaAlphaTest", "Multisample alpha test", "common", 0, 1, true, "cvar")
Add("shadowrt", "Ray traced shadows", "common", 0, 3, true, "cvar")
Add("LowLatencyMode", "Low latency mode", "common", 0, 5, true, "cvar")
Add("vsync", "Vertical sync", "common", 0, 1, true)
Add("maxFPS", "Foreground FPS", "common", 0, 1000, true)
Add("maxFPSBk", "Background FPS", "common", 0, 1000, true)
Add("targetFPS", "Target FPS", "common", 0, 1000, true)
-- Activation flags follow their values, so a disabled native option retains
-- its saved slider value when the profile is restored.
Add("useMaxFPS", "Foreground FPS limit", "common", 0, 1, true)
Add("useMaxFPSBk", "Background FPS limit", "common", 0, 1, true)
Add("useTargetFPS", "Target FPS enabled", "common", 0, 1, true)
Add("RAIDsettingsEnabled", "Raid settings", "common", 0, 1, true)

local function IsSecret(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        return not ok or secret
    end
    return false
end

local function Translate(text)
    return type(F.L) == "table" and (F.L[text] or text) or text
end

local function FiniteNumber(value)
    if IsSecret(value) then return nil end
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        return nil
    end
    return number
end

local function SplitMSAA(value)
    if type(value) ~= "string" then return nil end
    local primary, coverage = value:match("^(%d+),(%d+)$")
    if primary then return tonumber(primary), tonumber(coverage) end
    return FiniteNumber(value), 0
end

local function ValidateValue(entry, value)
    if IsSecret(value) then return nil, "Secret value" end
    if type(value) ~= "string" or #value > 32 then return nil, "Invalid value" end
    local number, coverage
    if entry.name == "MSAAQuality" then
        number, coverage = SplitMSAA(value)
        if coverage and (coverage < 0 or coverage > 32 or coverage % 1 ~= 0) then
            return nil, "Invalid value"
        end
    else
        number = FiniteNumber(value)
    end
    if not number or number < entry.minimum or number > entry.maximum then
        return nil, "Value outside supported range"
    end
    if entry.integer and number % 1 ~= 0 then return nil, "Invalid value" end
    return true
end

-- Only already allowlisted names reach the API. Secret results never reach
-- string conversion, equality, SavedVariables, or user-visible error messages.
function G.GetValue(name)
    if IsSecret(name) or type(name) ~= "string" or not byName[name] then
        return nil, "Unknown option"
    end
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if type(getter) ~= "function" then return nil, "CVar API unavailable" end
    local ok, value = pcall(getter, name)
    if not ok then return nil, "Read failed" end
    if IsSecret(value) then return nil, "Secret value" end
    if value == nil or value == "" then return nil, "Unavailable on this client" end
    if type(value) ~= "string" and type(value) ~= "number" then return nil, "Invalid value" end
    return tostring(value)
end

local function ValuesEqual(entry, expected, actual)
    if expected == actual then return true end
    if actual == nil then return false end
    if entry.name == "MSAAQuality" then
        local ep, ec = SplitMSAA(expected)
        local ap, ac = SplitMSAA(actual)
        return ep ~= nil and ap ~= nil and ep == ap and ec == ac
    end
    local left, right = FiniteNumber(expected), FiniteNumber(actual)
    if not left or not right then return false end
    if entry.integer then return left == right end
    -- CVars may serialize the same floating point value with different digits.
    return math.abs(left - right) <= 0.000001 * math.max(1, math.abs(left), math.abs(right))
end

function G.Validate(snapshot)
    if IsSecret(snapshot) or type(snapshot) ~= "table" then return nil, "Invalid profile" end
    local values = snapshot.values
    if IsSecret(values) or type(values) ~= "table" then return nil, "Invalid profile" end
    local count = 0
    for name, value in pairs(values) do
        if IsSecret(name) or type(name) ~= "string" then return nil, "Invalid option name" end
        local entry = byName[name]
        if not entry then return nil, "Unknown option: " .. name end
        local valid, reason = ValidateValue(entry, value)
        if not valid then return nil, name .. ": " .. reason end
        count = count + 1
    end
    if count == 0 then return nil, "No graphics options in this profile" end
    -- Existence on the CURRENT client is deliberately not part of validation:
    -- old profiles remain usable when a client update removes one option.
    return true
end

function G.Capture()
    local snapshot = {values = {}}
    local count = 0
    for _, entry in ipairs(catalog) do
        local value = G.GetValue(entry.name)
        if value and ValidateValue(entry, value) then
            snapshot.values[entry.name] = value
            count = count + 1
        end
    end
    if count == 0 then return nil, "No readable graphics options on this client" end
    return snapshot
end

local function Supported(entry, value)
    local validator
    if entry.support == "setting" then
        validator = IsGraphicsSettingValueSupported
    elseif entry.support == "cvar" then
        validator = IsGraphicsCVarValueSupported
    end
    if type(validator) == "function" then
        local ok, code = pcall(validator, entry.name, tonumber(value), entry.group == "raid")
        if not ok then return nil, "Support check failed" end
        if IsSecret(code) then return nil, "Secret value" end
        -- Blizzard returns a zero-based error index (0 means no error).
        if code == false or (type(code) == "number" and code ~= 0) then
            return nil, "Unsupported on this hardware"
        end
    elseif entry.support == "fxaa" and type(AntiAliasingSupported) == "function" then
        if tonumber(value) == 0 then return true end
        local ok, fxaa, cmaa, cmaa2 = pcall(AntiAliasingSupported)
        if not ok then return nil, "Support check failed" end
        if IsSecret(fxaa) or IsSecret(cmaa) or IsSecret(cmaa2) then return nil, "Secret value" end
        local number = tonumber(value)
        if (number <= 2 and not fxaa) or (number == 3 and not cmaa) or (number == 4 and not cmaa2) then
            return nil, "Unsupported on this hardware"
        end
    elseif entry.support == "msaa" and type(MultiSampleAntiAliasingSupported) == "function" then
        local primary, coverage = SplitMSAA(value)
        if primary == 0 then return true end
        local options = {pcall(MultiSampleAntiAliasingSupported)}
        if not options[1] then return nil, "Support check failed" end
        for index = 2, #options, 3 do
            local raw = options[index]
            if IsSecret(raw) then return nil, "Secret value" end
            if type(raw) == "number" then raw = tostring(raw) end
            local optionPrimary, optionCoverage = SplitMSAA(raw)
            if primary == optionPrimary and coverage == optionCoverage then return true end
        end
        return nil, "Unsupported on this hardware"
    end
    return true
end

local function Write(entry, value)
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if type(setter) ~= "function" then return nil, "CVar API unavailable" end
    local ok, accepted = pcall(setter, entry.name, value)
    if not ok then return nil, "Write failed" end
    if IsSecret(accepted) then return nil, "Secret value" end
    if accepted == false then return nil, "Write refused" end
    return true
end

function G.Compare(snapshot)
    local result = {total = 0, matched = 0, differences = {}, matches = false}
    local valid, reason = G.Validate(snapshot)
    if not valid then
        result.error = reason
        result.differences[1] = {name = "profile", reason = reason}
        return result
    end
    for _, entry in ipairs(catalog) do
        local expected = snapshot.values[entry.name]
        if expected then
            result.total = result.total + 1
            local actual, readReason = G.GetValue(entry.name)
            if ValuesEqual(entry, expected, actual) then
                result.matched = result.matched + 1
            else
                result.differences[#result.differences + 1] = {
                    name = entry.name, expected = expected, actual = actual,
                    reason = readReason or "Value differs",
                }
            end
        end
    end
    result.matches = result.total > 0 and result.matched == result.total
    return result
end

function G.Apply(snapshot)
    local result = {total = 0, applied = 0, unchanged = 0, failed = {}, skipped = {}, success = false}
    local valid, reason = G.Validate(snapshot)
    if not valid then
        result.error = reason
        result.failed[1] = {name = "profile", reason = reason}
        return result
    end
    local written, errors, skipped = {}, {}, {}
    for _, entry in ipairs(catalog) do
        local expected = snapshot.values[entry.name]
        if expected then
            result.total = result.total + 1
            local actual, readReason = G.GetValue(entry.name)
            if actual == nil then
                skipped[entry.name] = readReason
            elseif not ValuesEqual(entry, expected, actual) then
                local supported, supportReason = Supported(entry, expected)
                if supported then
                    local accepted, writeReason = Write(entry, expected)
                    if accepted then written[entry.name] = true else errors[entry.name] = writeReason end
                else
                    errors[entry.name] = supportReason
                end
            end
        end
    end
    -- Re-read AFTER all writes: a later CVar or another addon's callback may
    -- have changed an earlier one. A successful SetCVar is not proof of success.
    for _, entry in ipairs(catalog) do
        local expected = snapshot.values[entry.name]
        if expected then
            local actual, readReason = G.GetValue(entry.name)
            if ValuesEqual(entry, expected, actual) then
                if written[entry.name] then result.applied = result.applied + 1
                else result.unchanged = result.unchanged + 1 end
            elseif skipped[entry.name] then
                result.skipped[#result.skipped + 1] = {name = entry.name, reason = skipped[entry.name]}
            else
                result.failed[#result.failed + 1] = {
                    name = entry.name, expected = expected, actual = actual,
                    reason = errors[entry.name] or readReason or "Value refused or changed",
                }
            end
        end
    end
    result.success = result.total > 0 and #result.failed == 0 and #result.skipped == 0
    return result
end

function G.GetSummary(snapshot)
    if not G.Validate(snapshot) then return {} end
    local values, summary = snapshot.values, {}
    local function Row(name, label, formatter, group)
        local value = values[name]
        if not value then return end
        summary[#summary + 1] = {
            label = Translate(label), value = formatter and formatter(value) or value,
            group = group or byName[name].group,
        }
    end
    local function Quality(value) return string.format("%d / 10", tonumber(value) + 1) end
    local function Choice(choices)
        return function(value) return Translate(choices[tonumber(value) + 1] or value) end
    end
    local function FPS(value)
        return tonumber(value) == 0 and Translate("Unlimited") or (value .. " FPS")
    end
    -- Keep the two native modes symmetrical. The UI can filter one mode plus
    -- common rows without inventing missing settings or duplicating FPS limits.
    local modeRows = {
        {"ViewDistance", "View distance", Quality},
        {"EnvironmentDetail", "Environment detail", Quality},
        {"GroundClutter", "Ground clutter", Quality},
        {"ShadowQuality", "Shadows", Choice({"Low", "Fair", "Medium", "High", "Ultra", "Ultra high"})},
        {"LiquidDetail", "Liquids", Choice({"Low", "Fair", "Medium", "High"})},
        {"ParticleDensity", "Particles", Choice({"Disabled", "Low", "Fair", "Medium", "High", "Ultra"})},
        {"SSAO", "Ambient occlusion", Choice({"Disabled", "Low", "Medium", "High", "Ultra"})},
        {"DepthEffects", "Depth effects", Choice({"Disabled", "Low", "Medium", "High"})},
        {"ComputeEffects", "Compute effects", Choice({"Disabled", "Low", "Medium", "High", "Ultra"})},
        {"LightMode", "Secondary lighting", Choice({"Fair", "Good", "High", "Ultra"})},
        {"TextureResolution", "Textures", Choice({"Low", "Medium", "High", "Ultra"})},
        {"SpellDensity", "Spell density", Choice({"Essential", "Reduced", "All"})},
        {"ProjectedTextures", "Projected textures", Choice({"Disabled", "Enabled"})},
    }
    for _, group in ipairs({"normal", "raid"}) do
        local prefix = group == "raid" and "raidGraphics" or "graphics"
        local qualityName = group == "raid" and "RAIDgraphicsQuality" or "graphicsQuality"
        Row(qualityName, "Graphics quality", Quality, group)
        for _, option in ipairs(modeRows) do
            Row(prefix .. option[1], option[2], option[3], group)
        end
    end
    Row("RenderScale", "Render scale", function(value) return string.format("%.0f%%", tonumber(value) * 100) end)
    Row("maxFPS", "Foreground FPS", function(value)
        return tonumber(values.useMaxFPS) == 0 and Translate("Unlimited") or FPS(value)
    end)
    Row("maxFPSBk", "Background FPS", function(value)
        return tonumber(values.useMaxFPSBk) == 0 and Translate("Unlimited") or FPS(value)
    end)
    Row("RAIDsettingsEnabled", "Raid settings", Choice({"Disabled", "Enabled"}))
    return summary
end
