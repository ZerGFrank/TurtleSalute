-- TurtleSalute.lua  •  auto-welcomes, snarks, and salutes
local playerName = UnitName("player")

-- System chat patterns (enUS client strings)
local JOIN  = "(.+) has joined the guild"
local LEAVE = "(.+) has left the guild"
local KICK  = "(.+) has been kicked out of the guild"

-- Return current guild name (fallback so the code never nils)
local function G() return GetGuildInfo("player") or "our guild" end

-- Quote pools
local welcomeLines = {
    "Welcome to GUILD, NAME! Don’t forget your complimentary shell polish.",
    "Slow and steady wins raids—glad you joined GUILD, NAME!",
    "NAME just hopped aboard GUILD’s party wagon. Buckle up!",
    "Fresh meat! Err… fresh kelp? Either way, welcome to GUILD, NAME.",
    "Shell yeah! NAME is now part of GUILD."
}

local leaveLines = {
    "NAME left GUILD. Guess the turtle pace was too OP.",
    "Farewell, NAME—may your walk speed be ever swift outside GUILD.",
    "NAME rage‑quit GUILD faster than /camp.",
    "Another shell rolls away… bye, NAME!",
    "NAME couldn’t handle GUILD’s cool‑down… see ya!"
}

local kickLines = {
    "GUILD just yeeted NAME into the great beyond. 🐢💨",
    "NAME was booted from GUILD. Mind the doorstep on the way out!",
    "Ouch—NAME just bounced off GUILD’s shell.",
    "GUILD applied /gkick to NAME. It was super‑effective!",
    "NAME has been kicked: shell shock is real."
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

local function salute(name, kicked)
    if name ~= playerName then
        local pool = kicked and kickLines or leaveLines
        SendChatMessage(fmt(pick(pool), name), "GUILD")
        DoEmote("SALUTE")
    end
end

-- Event driver ----------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_SYSTEM")
math.randomseed(time())

f:SetScript("OnEvent", function()
    if event ~= "CHAT_MSG_SYSTEM" then return end   -- ignore anything else
    local msg = arg1                                 -- system text

    -- joined
    local _, _, who = string.find(msg, JOIN)
    if who then
        welcome(who)
        return
    end

    -- left
    _, _, who = string.find(msg, LEAVE)
    if who then
        salute(who, false)
        return
    end

    -- kicked
    _, _, who = string.find(msg, KICK)
    if who then
        salute(who, true)
        return
    end
end)