-- TurtleSalute - guild greet/farewell with roll-based spam control

-- Saved variables (defaults)
TurtleSaluteDB = TurtleSaluteDB or {}
local defaults = {
  winnersPerEvent = { WELCOME = 5, FAREWELL = 3 },
  rollTimeout     = 1.0,   -- seconds to collect rolls
}
for k, v in pairs(defaults) do if TurtleSaluteDB[k] == nil then TurtleSaluteDB[k] = v end end

-- Helpers
local strlen = string.len
local function tbl_len(t) return table.getn(t) end            -- vanilla len
if not wipe then function wipe(t) for k in pairs(t) do t[k] = nil end end end
local function smatch(s, p) if not s then return end return string.find(s, p) end
local function After(d, fn)
  if C_Timer and C_Timer.After then return C_Timer.After(d, fn) end
  local fr, acc = CreateFrame("Frame"), 0
  fr:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt; if acc >= d then self:SetScript("OnUpdate", nil); fn() end
  end)
end

-- Load quote tables from optional file
local Welcome, Leave, Kick = { "Welcome, {player}!" }, { "Farewell, {player}." }, { "{player} was kicked!" }
local ok, data = pcall(require, "TurtleSaluteLines")
if ok and type(data) == "table" and data[1] then Welcome, Leave, Kick = data[1], data[2], data[3] end

-- Simple format
local function gname() return GetGuildInfo("player") or "the guild" end
local function fmt(tmpl, who)
  tmpl = string.gsub(tmpl, "{player}", who)
  return string.gsub(tmpl, "{guild}", gname())
end
local function pick(t) return t[math.random(1, tbl_len(t))] end

-- Constants
local PREFIX, MARKER = "TSALUTE", "§"
local EVT_WELCOME, EVT_FAREWELL = "WELCOME", "FAREWELL"

-- Communication hide if SendAddonMessage missing
local HAVE_MSG = type(SendAddonMessage) == "function"
if not ChatFrame_AddMessageEventFilter then ChatFrame_AddMessageEventFilter = function() end end
if not HAVE_MSG then
  ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", function(_, _, m)
    return m:sub(1, strlen(MARKER .. PREFIX .. ":")) == MARKER .. PREFIX .. ":"
  end)
end

-- Debugging output for communication
local function debugPrint(...)
    if TurtleSaluteDB.debug then
        print("[TurtleSalute Debug]", ...)
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

-- State
local pending, rollOpen = {}, false
local lastJoin, lastLeave, wasKick = nil, nil, false

-- Roll finalise
local function finishRoll()
  rollOpen = false; if next(pending) == nil then return end
  local buckets = {}
  for n, d in pairs(pending) do
    local t = d.tag; if not buckets[t] then buckets[t] = {} end
    local lst = buckets[t]; lst[tbl_len(lst) + 1] = { n, d.roll }
  end
  wipe(pending)
  for tag, lst in pairs(buckets) do
    table.sort(lst, function(a, b) return a[2] == b[2] and a[1] < b[1] or a[2] > b[2] end)
    local cap = TurtleSaluteDB.winnersPerEvent[tag] or 0
    local winners = {}
    for i = 1, math.min(cap, tbl_len(lst)) do winners[lst[i][1]] = true end
    DoEmote("salute")
    if winners[UnitName("player")] then
      if tag == EVT_WELCOME and lastJoin then SendChatMessage(fmt(pick(Welcome), lastJoin), "GUILD") end
      if tag == EVT_FAREWELL and lastLeave then
        local pool = wasKick and Kick or Leave
        SendChatMessage(fmt(pick(pool), lastLeave), "GUILD")
      end
    end
  end
end

local function enqueueRoll(tag)
  local me = UnitName("player")
  local r  = math.random(1, 1000)
  pending[me] = { roll = r, tag = tag }
  sendComm("ROLL:" .. tag .. ":" .. r)
  if not rollOpen then rollOpen = true; After(TurtleSaluteDB.rollTimeout, finishRoll) end
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

-- Event frame
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_SYSTEM")
if HAVE_MSG then f:RegisterEvent("CHAT_MSG_ADDON") else f:RegisterEvent("CHAT_MSG_GUILD") end

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

    if ev ~= "CHAT_MSG_SYSTEM" then return end
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
end)

-- Slash command
SLASH_TS1 = "/ts"
SlashCmdList["TS"] = function(c)
  local a, b = c:match("^(%S*)%s*(.-)$")
  if a == "timeout" then
    local t = tonumber(b)
    if t then TurtleSaluteDB.rollTimeout = t; print("TS timeout set to", t) else print("usage: /ts timeout <sec>") end
  else
    print("/ts timeout <sec> (current " .. TurtleSaluteDB.rollTimeout .. ")")
  end
end

-- Slash command to toggle debugging
SLASH_TSDEBUG1 = "/tsdebug"
SlashCmdList["TSDEBUG"] = function()
    TurtleSaluteDB.debug = not TurtleSaluteDB.debug
    local status = TurtleSaluteDB.debug and "enabled" or "disabled"
    print("TurtleSalute debugging is now", status)
end