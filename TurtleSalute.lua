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

-- Debugging output for communication
local function debugPrint(...)
    if TurtleSaluteDB.debug then
        print("[TurtleSalute Debug]", ...)
    end
end

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

-- Updated sendComm function with debugging
local function sendComm(p)
    debugPrint("Sending message:", p)
    if HAVE_MSG then
        SendAddonMessage(PREFIX, p, "GUILD")
    else
        SendChatMessage(MARKER .. PREFIX .. ":" .. p, "GUILD")
    end
end

-- Updated receiveRoll function with debugging
local function receiveRoll(sender, tag, val)
    debugPrint("Received roll from:", sender, "Tag:", tag, "Value:", val)
    pending[sender] = { roll = tonumber(val), tag = tag }
    if not rollOpen then
        rollOpen = true
        After(TurtleSaluteDB.rollTimeout, finishRoll)
    end
end

-- Event driver ----------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_SYSTEM")
math.randomseed(time())

-- Debugging output for event handling
f:SetScript("OnEvent", function()
    local ev = arg1
    debugPrint("Event triggered:", ev)

    if ev == "PLAYER_LOGIN" then
        math.randomseed(time())
        debugPrint("Addon initialized.")
        return
    end

    if ev == "CHAT_MSG_ADDON" then
        local pre, msg, chan, sender = arg2, arg3, arg4, arg5
        debugPrint("Addon message received:", msg, "From:", sender)
        if pre == PREFIX and chan == "GUILD" then
            local _, _, tg, val = string.find(msg, "^ROLL:([A-Z]+):(%d+)$")
            if tg then receiveRoll(sender, tg, val) end
        end
        return
    end

    if ev == "CHAT_MSG_GUILD" and not HAVE_MSG then
        local raw, sender = arg2, arg3
        debugPrint("Guild chat message received:", raw, "From:", sender)
        local head = MARKER .. PREFIX .. ":"
        if string.sub(raw, 1, strlen(head)) == head then
            local body = string.sub(raw, strlen(head) + 1)
            local _, _, tg, val = string.find(body, "^ROLL:([A-Z]+):(%d+)$")
            if tg then receiveRoll(sender, tg, val) end
        end
        return
    end

    if ev == "CHAT_MSG_SYSTEM" then
        local msg = arg2
        debugPrint("System message received:", msg)

        local who = string.match(msg, "^(.-) has joined the guild")
        if who then
            debugPrint("Player joined:", who)
            lastJoin = who
            enqueueRoll(EVT_WELCOME)
            return
        end

        who = string.match(msg, "^(.-) has left the guild")
        if who then
            debugPrint("Player left:", who)
            wasKick = false
            lastLeave = who
            enqueueRoll(EVT_FAREWELL)
            return
        end

        who = string.match(msg, "^(.-) has been kicked")
        if who then
            debugPrint("Player kicked:", who)
            wasKick = true
            lastLeave = who
            enqueueRoll(EVT_FAREWELL)
            return
        end

        if string.find(msg, "has fallen in Hardcore") then
            debugPrint("Hardcore death detected.")
            DoEmote("salute")
        end
    end
end)

-- Slash command to toggle debugging
SLASH_TSDEBUG1 = "/tsdebug"
SlashCmdList["TSDEBUG"] = function()
    TurtleSaluteDB.debug = not TurtleSaluteDB.debug
    local status = TurtleSaluteDB.debug and "enabled" or "disabled"
    print("TurtleSalute debugging is now", status)
end