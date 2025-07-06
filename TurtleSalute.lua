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
    "Shell yeah! NAME is now part of GUILD.",
    "NAME just joined GUILD! Time to teach them the turtle shuffle.",
    "Welcome aboard, NAME! Hope you brought snacks for the raid.",
    "NAME has entered GUILD. Let the shell-abration begin!",
    "Slow and steady, NAME! Welcome to GUILD, where patience is a virtue.",
    "NAME joined GUILD! Prepare for epic turtle power!",
    "Welcome, NAME! GUILD’s shell game just got stronger.",
    "NAME is now part of GUILD! Let’s shell-ebrate with a dance-off.",
    "NAME joined GUILD! Hope you like long walks on the beach.",
    "Welcome, NAME! GUILD’s shell polish is on the house.",
    "NAME just joined GUILD! Time to turtle up and raid!",
    "A TURTLE MADE IT TO THE WATER! Welcome to GUILD, NAME!",
}

local leaveLines = {
    "NAME left GUILD. Guess the turtle pace was too OP.",
    "Farewell, NAME—may your walk speed be ever swift outside GUILD.",
    "NAME rage‑quit GUILD faster than /camp.",
    "Another shell rolls away… bye, NAME!",
    "NAME couldn’t handle GUILD’s cool‑down… see ya!",
    "NAME left GUILD. Guess they couldn’t handle the turtle grind.",
    "NAME has left GUILD. May their shell always be shiny.",
    "NAME rage-quit GUILD faster than a turtle on turbo.",
    "NAME left GUILD. The turtle tide rolls on without them.",
    "NAME couldn’t keep up with GUILD’s turtle tactics. Farewell!",
    "NAME left GUILD. Guess they prefer hare-speed adventures.",
    "NAME has left GUILD. May their next guild be less shell-shocking.",
    "NAME rolled out of GUILD. The turtle shuffle continues!",
    "NAME left GUILD. Hope they find a faster shell elsewhere.",
    "NAME couldn’t handle GUILD’s turtle pace. Bye-bye!",
    "NAME was an NPC anyway. They left GUILD to become a quest giver.",
}

local kickLines = {
    "GUILD just yeeted NAME into the great beyond. 🐢💨",
    "NAME was booted from GUILD. Mind the doorstep on the way out!",
    "Ouch—NAME just bounced off GUILD’s shell.",
    "GUILD applied /gkick to NAME. It was super‑effective!",
    "NAME has been kicked: shell shock is real.",
    "GUILD just gave NAME the boot. Shell shock incoming!",
    "NAME was kicked from GUILD. Guess they weren’t turtle enough.",
    "GUILD applied /gkick to NAME. The shell storm is real!",
    "NAME got yeeted from GUILD. Watch out for flying turtles!",
    "NAME was booted from GUILD. The shell shuffle stops here.",
    "GUILD kicked NAME out. Guess they didn’t pass the turtle test.",
    "NAME was kicked from GUILD. The shell-polish budget is safe again!",
    "GUILD just bounced NAME out. Turtle power prevails!",
    "NAME got kicked from GUILD. The turtle tide rolls on!",
    "NAME was kicked from GUILD. Shell shock therapy recommended."
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