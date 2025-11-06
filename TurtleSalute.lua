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
    "Welcome to GUILD, NAME! Try not to break anything in the first five minutes.",
    "A wild NAME has appeared in GUILD! Someone hand them a quest log.",
    "NAME has joined GUILD! Hope you brought snacks and questionable life choices.",
    "Brace yourselves... NAME has arrived in GUILD!",
    "GUILD just got 10% cooler thanks to NAME.",
    "NAME has entered GUILD — may their loot rolls be ever in their favor.",
    "Welcome to GUILD, NAME! Remember, we don’t talk about the last raid night.",
    "NAME just joined GUILD. Hide your mounts and lock the bank.",
    "A new challenger approaches! Welcome to GUILD, NAME!",
    "NAME has joined GUILD! The average IQ of the guild has definitely changed.",
    "Welcome aboard, NAME! We promise it’s mostly chaos, but fun chaos.",
    "NAME joined GUILD! Someone hand them the survival guide.",
    "Big cheers for NAME joining GUILD! Hope you brought a sense of humor.",
    "NAME has joined GUILD! May your armor never break mid-dungeon.",
    "Welcome to GUILD, NAME! The initiation ritual is purely optional. Probably.",
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
