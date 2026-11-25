-- One key deletes the cheapest junk item (a warlock's extra Soul Shards first, through
-- MeioShards when loaded), junk marked in Baganator, containers opened. Each feature file
-- registers its own events here.
local ADDON, ns = ...

local PREFIX = "|cffb090ffMeioBags:|r "
ns.SLASH = "/meiobags"
ns.GOLD, ns.MUTED, ns.GOOD, ns.BAD = "|cffffd100", "|cff999999", "|cff80ff80", "|cffff8080"
ns.SETTINGS_PATH = "Esc > Options > AddOns > MeioBags"
ns.KEY_PATH = "Esc > Options > Keybindings > AddOns > MeioBags"
ns.DEFAULTS = { shards = true, open = true, sell = true }

function ns.Say(msg) print(PREFIX .. msg) end
function ns.Line(msg) print("  " .. msg) end
function ns.Cmd(text) return ns.GOLD .. text .. "|r" end
function ns.OnOff(on) return on and ns.GOOD .. "on|r" or ns.BAD .. "off|r" end
function ns.Plural(n) return n == 1 and "" or "s" end

-- MeioShards (optional) only trims for warlocks
function ns.HasMeioShards()
  return type(_G.MeioShards) == "table" and select(2, UnitClass("player")) == "WARLOCK"
end

function ns.KeyName()
  return ns.HasMeioShards() and "Delete extra Soul Shards, else the cheapest junk item"
    or "Delete the cheapest junk item"
end

function ns.LastBag() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end

-- one handler list per event, each in its own pcall so one feature's error can't stop the
-- others. Events this client doesn't have are skipped: RegisterEvent throws on them.
local frame = CreateFrame("Frame")
local handlers = {}
function ns.On(event, fn)
  if not handlers[event] then
    local valid = C_EventUtils and C_EventUtils.IsEventValid
    if valid and not valid(event) then return end
    if not pcall(frame.RegisterEvent, frame, event) then return end
    handlers[event] = {}
  end
  table.insert(handlers[event], fn)
end
frame:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
  end
end)

ns.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  MeioBagsDB = MeioBagsDB or {}
  local db = MeioBagsDB
  for k, v in pairs(ns.DEFAULTS) do
    if db[k] == nil then db[k] = v end
  end
  -- itemID -> true: always junk / never junk, whatever the quality
  db.junk = db.junk or {}
  db.keep = db.keep or {}
  ns.db = db
end)
