local _, F = ...

F.version = "0.2.1"

-- The addon interface intentionally stays in English on every client locale.
-- Profile names remain user data and are never translated or rewritten.
F.L = setmetatable({}, {
    __index = function(_, key) return key end,
})

function F.Format(key, ...)
    return string.format(F.L[key], ...)
end

BINDING_HEADER_FOREVERPROFILES = "Forever Profiles"
BINDING_NAME_FOREVERPROFILES_TOGGLE = F.L["Open profiles"]
BINDING_NAME_FOREVERPROFILES_FAVORITE1 = F.L["Switch to favorite 1"]
BINDING_NAME_FOREVERPROFILES_FAVORITE2 = F.L["Switch to favorite 2"]
BINDING_NAME_FOREVERPROFILES_FAVORITE3 = F.L["Switch to favorite 3"]
BINDING_NAME_FOREVERPROFILES_RESTORE = F.L["Restore previous settings"]
