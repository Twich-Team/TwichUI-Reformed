_G.PortalAuthority = _G.PortalAuthority or {}

local PortalAuthority = _G.PortalAuthority
PortalAuthority.Media = PortalAuthority.Media or {}

local Media = PortalAuthority.Media

local ADDON_ROOT = "Interface\\AddOns\\PortalAuthority\\"
local MEDIA_ROOT = ADDON_ROOT .. "Media\\"
local AUDIO_ROOT = MEDIA_ROOT .. "Audio\\"
local FONT_ROOT = MEDIA_ROOT .. "Fonts\\"
local STATUSBAR_ROOT = MEDIA_ROOT .. "Statusbars\\"

local BUNDLED_FONTS = {
    { label = "Overclock: Friz", value = "Overclock: Friz", path = FONT_ROOT .. "FRIZQT__.ttf" },
}

local BUNDLED_STATUSBARS = {
    { label = "Overclock: Stormy Clean", value = "Overclock: Stormy Clean", path = STATUSBAR_ROOT .. "Auro_Clean" },
    { label = "Overclock: ElvUI Stripes", value = "Overclock: ElvUI Stripes", path = STATUSBAR_ROOT .. "ElvUiStripes" },
}

local BUNDLED_SOUNDS = {
    { label = "Overclock: Pause", value = "Overclock: Pause", file = "pause.mp3" },
    { label = "Overclock: OOT Press Start", value = "Overclock: OOT Press Start", file = "OOT_PressStart.mp3" },
    { label = "Overclock: MGS", value = "Overclock: MGS", file = "MGS.ogg" },
    { label = "Overclock: MMX Life Gain", value = "Overclock: MMX Life Gain", file = "12 - MMX - X Life Gain.mp3", aliasFiles = { "12_ MMX-X-Life-Gain.mp3" } },
    { label = "Overclock: MMX X Die", value = "Overclock: MMX X Die", file = "11_-_MMX_-_X_Die.mp3" },
    { label = "Overclock: MMX Energy Tank Full", value = "Overclock: MMX Energy Tank Full", file = "33_-_MMX_-_Energy_Tank_Full.mp3" },
    { label = "Overclock: MMX Ice", value = "Overclock: MMX Ice", file = "34 - MMX - Ice.mp3" },
    { label = "Overclock: MMX Beep 3", value = "Overclock: MMX Beep 3", file = "45 - MMX - Beep (3).mp3" },
    { label = "Overclock: Ability Gain", value = "Overclock: Ability Gain", file = "ability-gain.mp3" },
    { label = "Overclock: Ability Dispose", value = "Overclock: Ability Dispose", file = "ability-dispose.mp3" },
    { label = "Overclock: Ally Item", value = "Overclock: Ally Item", file = "ally-item.mp3" },
    { label = "Overclock: Enter Door", value = "Overclock: Enter Door", file = "enter-door.mp3" },
    { label = "Overclock: Double Shine", value = "Overclock: Double Shine", file = "DoubleShine.mp3" },
    { label = "Overclock: Fox Victory", value = "Overclock: Fox Victory", file = "FoxVictory.mp3" },
    { label = "Overclock: That's Wrong", value = "Overclock: That's Wrong", file = "ThatsWrong.mp3" },
    { label = "Overclock: SMW 1-Up", value = "Overclock: SMW 1-Up", file = "SMW_1up.mp3" },
    { label = "Overclock: SMW Coin", value = "Overclock: SMW Coin", file = "SMW_coin.mp3" },
    { label = "Overclock: SMW Jump", value = "Overclock: SMW Jump", file = "SMW_jump.mp3" },
    { label = "Overclock: SMW Fireball", value = "Overclock: SMW Fireball", file = "SMW_fireball.mp3" },
    { label = "Overclock: SMW Kick", value = "Overclock: SMW Kick", file = "SMW_kick.mp3" },
    { label = "Overclock: SMW Riding Yoshi", value = "Overclock: SMW Riding Yoshi", file = "SMW_riding_yoshi.mp3" },
    { label = "Overclock: SMW Yoshi Tongue", value = "Overclock: SMW Yoshi Tongue", file = "SMW_yoshi_tongue.mp3" },
    { label = "Overclock: SMW Yellow Yoshi Stomp", value = "Overclock: SMW Yellow Yoshi Stomp", file = "SMW_yellow_yoshi_stomp.mp3" },
    { label = "Overclock: SMW Map Move To Spot", value = "Overclock: SMW Map Move To Spot", file = "SMW_map_move_to_spot.mp3" },
    { label = "Overclock: SMW Save Menu", value = "Overclock: SMW Save Menu", file = "SMW_save_menu.mp3" },
    { label = "Overclock: SMW Lemmy Wendy Correct", value = "Overclock: SMW Lemmy Wendy Correct", file = "SMW_lemmy_wendy_correct.mp3" },
    { label = "Overclock: SMW Lemmy Wendy Incorrect", value = "Overclock: SMW Lemmy Wendy Incorrect", file = "SMW_lemmy_wendy_incorrect.mp3" },
    { label = "Overclock: SMW Lemmy Wendy Falls Out Of Pipe", value = "Overclock: SMW Lemmy Wendy Falls Out Of Pipe", file = "SMW_lemmy_wendy_falls_out_of_pipe.mp3" },
}

local BUILTIN_SOUND_CHOICES = {
    { label = "Alarm Clock", value = 567478 },
    { label = "Raid Warning", value = 567463 },
    { label = "Ready Check", value = 567482 },
    { label = "Tell Message", value = 3081 },
}

local SOUND_NAME_TO_ENTRY = {}
local SOUND_ALIAS_TO_NAME = {}
local FONT_NAME_TO_PATH = {}
local STATUSBAR_NAME_TO_PATH = {}

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeLookupKey(value)
    if type(value) ~= "string" then
        return nil
    end
    local text = trim(value):gsub("/", "\\")
    if text == "" then
        return nil
    end
    return string.lower(text)
end

local function basenameWithoutExtension(path)
    local text = trim(tostring(path or "")):gsub("/", "\\")
    if text == "" then
        return ""
    end
    local name = text:match("([^\\]+)$") or text
    return (name:gsub("%.%w+$", ""))
end

local function compareChoiceLabels(left, right)
    return tostring(left.label or ""):lower() < tostring(right.label or ""):lower()
end

for _, entry in ipairs(BUNDLED_FONTS) do
    FONT_NAME_TO_PATH[entry.value] = entry.path
end

for _, entry in ipairs(BUNDLED_STATUSBARS) do
    STATUSBAR_NAME_TO_PATH[entry.value] = entry.path
end

for _, entry in ipairs(BUNDLED_SOUNDS) do
    entry.path = AUDIO_ROOT .. entry.file
    SOUND_NAME_TO_ENTRY[entry.value] = entry

    local canonicalKey = normalizeLookupKey(entry.value)
    if canonicalKey then
        SOUND_ALIAS_TO_NAME[canonicalKey] = entry.value
    end

    local aliasFiles = { entry.file }
    for _, aliasFile in ipairs(entry.aliasFiles or {}) do
        aliasFiles[#aliasFiles + 1] = aliasFile
    end

    for _, fileName in ipairs(aliasFiles) do
        SOUND_ALIAS_TO_NAME[normalizeLookupKey(MEDIA_ROOT .. fileName)] = entry.value
        SOUND_ALIAS_TO_NAME[normalizeLookupKey(AUDIO_ROOT .. fileName)] = entry.value
    end
end

local function getLibSharedMedia()
    local libStub = _G.LibStub
    if type(libStub) == "table" and type(libStub.GetLibrary) == "function" then
        local ok, library = pcall(libStub.GetLibrary, libStub, "LibSharedMedia-3.0", true)
        if ok and type(library) == "table" then
            return library
        end
    end
    if type(libStub) == "function" then
        local ok, library = pcall(libStub, "LibSharedMedia-3.0", true)
        if ok and type(library) == "table" then
            return library
        end
    end
    return nil
end

local function fetchMediaPath(kind, value)
    local lsm = getLibSharedMedia()
    if not lsm or type(lsm.Fetch) ~= "function" then
        return nil
    end

    local ok, resolved = pcall(lsm.Fetch, lsm, kind, value, true)
    if ok and type(resolved) == "string" and resolved ~= "" then
        return resolved
    end
    return nil
end

local function ensureRegistered()
    if Media._registered then
        return getLibSharedMedia()
    end

    local lsm = getLibSharedMedia()
    if not lsm or type(lsm.Register) ~= "function" then
        return nil
    end

    for _, entry in ipairs(BUNDLED_FONTS) do
        pcall(lsm.Register, lsm, "font", entry.value, entry.path)
    end
    for _, entry in ipairs(BUNDLED_STATUSBARS) do
        pcall(lsm.Register, lsm, "statusbar", entry.value, entry.path)
    end
    for _, entry in ipairs(BUNDLED_SOUNDS) do
        pcall(lsm.Register, lsm, "sound", entry.value, entry.path)
    end

    Media._registered = true
    return lsm
end

local function addChoice(choices, seen, label, value, path)
    local key
    if type(value) == "number" then
        key = "num:" .. tostring(value)
    else
        key = "str:" .. tostring(value or "")
    end

    if seen[key] then
        return
    end

    seen[key] = true
    choices[#choices + 1] = {
        label = tostring(label or value or ""),
        value = value,
        path = path,
    }
end

local function addBundledChoices(kind, choices, seen)
    local entries
    if kind == "font" then
        entries = BUNDLED_FONTS
    elseif kind == "statusbar" then
        entries = BUNDLED_STATUSBARS
    elseif kind == "sound" then
        entries = BUNDLED_SOUNDS
    else
        return
    end

    for _, entry in ipairs(entries) do
        addChoice(choices, seen, entry.label, entry.value, entry.path)
    end
end

local function addExternalChoices(kind, choices, seen)
    local lsm = ensureRegistered()
    if not lsm or type(lsm.List) ~= "function" then
        return
    end

    local external = {}
    for _, name in ipairs(lsm:List(kind) or {}) do
        local normalized = tostring(name or "")
        if normalized ~= "" and not normalized:match("^Overclock:%s") and normalized ~= "None" then
            external[#external + 1] = {
                label = normalized,
                value = normalized,
                path = fetchMediaPath(kind, normalized),
            }
        end
    end

    table.sort(external, compareChoiceLabels)
    for _, entry in ipairs(external) do
        addChoice(choices, seen, entry.label, entry.value, entry.path)
    end
end

local function addCurrentSoundChoice(currentValue, choices, seen)
    local normalized = Media.NormalizeBundledSoundValue(currentValue)
    if normalized == nil or normalized == "" or type(normalized) == "number" then
        return
    end

    local soundEntry = SOUND_NAME_TO_ENTRY[normalized]
    if soundEntry then
        return
    end

    local resolved = fetchMediaPath("sound", normalized)
    if resolved then
        return
    end

    local label = normalized
    if normalized:find("[/\\]") then
        local basename = basenameWithoutExtension(normalized)
        if basename ~= "" then
            label = "Custom: " .. basename
        end
    end

    addChoice(choices, seen, label, normalized, normalized)
end

function Media.NormalizeBundledSoundValue(value, opts)
    if type(value) == "number" then
        return value
    end

    local text = trim(tostring(value or ""))
    if text == "" then
        return ""
    end

    local directEntry = SOUND_NAME_TO_ENTRY[text]
    if directEntry then
        return directEntry.value
    end

    local lookupKey = normalizeLookupKey(text)
    local bundledName = lookupKey and SOUND_ALIAS_TO_NAME[lookupKey] or nil
    if bundledName then
        return bundledName
    end

    return text
end

function Media.ResolveSoundFile(value)
    if type(value) == "number" then
        return value
    end

    local normalized = Media.NormalizeBundledSoundValue(value)
    if type(normalized) == "number" then
        return normalized
    end

    local text = trim(tostring(normalized or ""))
    if text == "" then
        return nil
    end

    local bundledEntry = SOUND_NAME_TO_ENTRY[text]
    if bundledEntry then
        local bundledResolved = fetchMediaPath("sound", bundledEntry.value)
        return bundledResolved or bundledEntry.path
    end

    local lsmResolved = fetchMediaPath("sound", text)
    if lsmResolved then
        return lsmResolved
    end

    return text
end

function Media.GetChoices(kind, opts)
    kind = tostring(kind or ""):lower()
    opts = type(opts) == "table" and opts or {}

    local choices = {}
    local seen = {}
    local lsm = ensureRegistered()

    if kind == "sound" and opts.includeNone then
        addChoice(choices, seen, "None", "")
    elseif kind == "font" and opts.includeGlobalUi then
        addChoice(choices, seen, "Global UI Font", "")
    end

    if kind ~= "statusbar" or lsm then
        addBundledChoices(kind, choices, seen)
    end
    if lsm then
        addExternalChoices(kind, choices, seen)
    end

    if kind == "sound" then
        addCurrentSoundChoice(opts.currentValue, choices, seen)
        if opts.includeBuiltinIDs then
            for _, entry in ipairs(BUILTIN_SOUND_CHOICES) do
                addChoice(choices, seen, entry.label, entry.value)
            end
        end
    end

    return choices
end

Media.BuiltinSoundChoices = BUILTIN_SOUND_CHOICES
Media.BundledFonts = BUNDLED_FONTS
Media.BundledStatusbars = BUNDLED_STATUSBARS
Media.BundledSounds = BUNDLED_SOUNDS

ensureRegistered()
