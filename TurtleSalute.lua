-- TurtleSalute.lua  // auto-welcomes (guild chat) + silent leave salutes (with safety checks)
local playerName = UnitName("player")

-- System chat patterns (enUS client strings)
local JOIN   = "(.+) has joined the guild"
local LEAVE  = "(.+) has left the guild"
local KICK   = "(.+) has been kicked out of the guild" -- extra pattern to suppress
local REMOVE = "(.+) has been removed from the guild"  -- extra pattern to suppress

-- Return current guild name (fallback so the code never nils)
local function G() return GetGuildInfo("player") or "our guild" end

-- Quote pools (welcomes only — leave/kick lines removed per request)
local welcomeLines = {
    "Welcome to GUILD, NAME! Don’t forget your complimentary shell polish.",
    "Slow and steady wins the raids, NAME. Glad you've joined GUILD!",
    "NAME just hopped aboard the GUILD party wagon. Buckle up!",
    "Fresh meat! Err… fresh kelp? Either way, welcome to GUILD NAME.",
    "Shell yeah! NAME is now part of GUILD.",
    "NAME just joined GUILD! Time to teach them the turtle shuffle.",
    "Welcome aboard, NAME! Hope you brought snacks for the raid.",
    "NAME has entered GUILD. Let the shell-abration begin!",
    "Slow and steady, NAME! Welcome to GUILD, where patience is a virtue.",
    "NAME joined GUILD! Prepare for epic turtle adventures!",
    "Welcome, NAME! GUILD’s shell game just got stronger.",
    "NAME is now part of GUILD! Let’s shell-ebrate!",
    "NAME joined GUILD! Hope you like long walks on the beach.",
    "Welcome, NAME! GUILD’s shell polish is on the house.",
    "NAME just joined GUILD! Time to turtle up and raid!",
    "A TURTLE MADE IT TO THE WATER! Welcome to GUILD, NAME!",
}

-- Helpers ---------------------------------------------------------------
local function pick(list)
    return list[math.random(1, table.getn(list))]  -- Lua 5.0: table.getn()
end

local function fmt(tmpl, who)
    tmpl = string.gsub(tmpl, "NAME", who)
    return string.gsub(tmpl, "GUILD", G())
end

local function welcome(name)
    if name ~= playerName then
        SendChatMessage(fmt(pick(welcomeLines), name), "GUILD")
    end
end

-- ---- city / safety checks for leave salutes ---------------------------
local MAJOR_CITIES = {
    ["Stormwind City"] = true,
    ["Ironforge"]      = true,
    ["Darnassus"]      = true,
    ["Orgrimmar"]      = true,
    ["Thunder Bluff"]  = true,
    ["Undercity"]      = true,
}

local function IsInMajorCity()
    local z = GetZoneText()
    return z and MAJOR_CITIES[z] or false
end

local function IsSafeToSalute()
    if UnitAffectingCombat and UnitAffectingCombat("player") then return false end
    if UnitExists and UnitExists("target") then return false end
    return IsInMajorCity()
end

local function salute_leave_only(name)
    if name ~= playerName and IsSafeToSalute() then
        DoEmote("SALUTE")  -- silent emote; no guild chat message
    end
end

-- System message suppression (kick/remove only) -------------------------
local function is_kick_or_remove(msg)
    if not msg then return false end
    if string.find(msg, "has been kicked", 1, true) then return true end
    if string.find(msg, "has been removed", 1, true) then return true end
    if string.find(msg, "removed from the guild", 1, true) then return true end
    return false
end

-- Prefer message event filter if available; fallback to ChatFrame_OnEvent hook
if ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, msg)
        if is_kick_or_remove(msg) then
            return true  -- hide kicked/removed system lines
        end
    end)
else
    -- Vanilla-style fallback
    if ChatFrame_OnEvent then
        local _orig = ChatFrame_OnEvent
        ChatFrame_OnEvent = function(event)
            if event == "CHAT_MSG_SYSTEM" and is_kick_or_remove(arg1) then
                return  -- suppress kicked/removed
            end
            return _orig(event)
        end
    end
end

-- Event driver ----------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_SYSTEM")
math.randomseed(time())

f:SetScript("OnEvent", function()
    if event ~= "CHAT_MSG_SYSTEM" then return end   -- ignore anything else
    local msg = arg1                                 -- system text

    -- joined -> keep welcomes in guild chat
    local _, _, who = string.find(msg, JOIN)
    if who then
        welcome(who)
        return
    end

    -- left -> silent salute only (with safety checks)
    _, _, who = string.find(msg, LEAVE)
    if who then
        salute_leave_only(who)
        return
    end

    -- kicked/removed -> do nothing (suppressed above)
    _, _, who = string.find(msg, KICK)
    if who then
        return
    end
    _, _, who = string.find(msg, REMOVE)
    if who then
        return
    end
end)
