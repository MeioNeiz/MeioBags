-- RestedXP's Inventory Manager does the same jobs and fights ours: it keeps Baganator's junk
-- plugin slot, and its delete key skips MeioShards. /meiobags rxp hands it over, only when
-- asked (it also stops RXP's vendor auto-sell):
-- - its Inventory Manager off; after a /reload RXP never registers its Baganator junk
--   plugin, so Baganator picks ours
-- - its junk / not-junk marks (per character) copied onto our lists
-- - keys bound to its "Delete Cheapest Junk Item" moved to our key
local _, ns = ...

local RXP_DELETE = "CLICK RXPInventory_DeleteJunk:LeftButton"

local function RXP()
  local ace = LibStub and LibStub("AceAddon-3.0", true)
  return ace and ace:GetAddon("RXPGuides", true)
end

function ns.HasRXP()
  local rxp = RXP()
  return rxp ~= nil and rxp.settings ~= nil and rxp.settings.profile ~= nil
end

local function TurnOff(rxp)
  local profile = rxp.settings.profile
  if profile.enableInventoryManager == false then return false end
  profile.enableInventoryManager = false
  local im = rxp.inventoryManager
  if im and im.initialized and im.Setup then pcall(im.Setup, im) end
  return true
end

-- -> how many marks were copied
local function Import()
  local pile = type(RXPCData) == "table" and RXPCData.discardPile
  if type(pile) ~= "table" then return 0 end
  local n = 0
  for id, junk in pairs(pile) do
    if type(id) == "number" and not ns.db.junk[id] and not ns.db.keep[id] then
      ns.db[junk and "junk" or "keep"][id] = true
      n = n + 1
    end
  end
  return n
end

-- -> the keys moved, as shown in the key bindings
local function Rebind()
  local keys = { GetBindingKey(RXP_DELETE) }
  if #keys == 0 then return {} end
  for _, key in ipairs(keys) do SetBinding(key, "MEIOBAGS_DELETE") end
  SaveBindings(GetCurrentBindingSet())
  local names = {}
  for i, key in ipairs(keys) do names[i] = GetBindingText(key) end
  return names
end

function ns.TakeOverRXP()
  local rxp = RXP()
  if not ns.HasRXP() then
    ns.Say("RestedXP Guides isn't loaded")
    return
  end
  if InCombatLockdown() then
    ns.Say(ns.BAD .. "not in combat|r")
    return
  end
  local changed = {}
  local off = TurnOff(rxp)
  if off then changed[#changed + 1] = "turned RestedXP's Inventory Manager off" end
  local n = Import()
  if n > 0 then
    changed[#changed + 1] = ("copied its %d junk / keep mark%s"):format(n, ns.Plural(n))
  end
  local keys = Rebind()
  if #keys > 0 then
    changed[#changed + 1] = table.concat(keys, ", ") .. " now runs MeioBags' delete key"
  end
  if #changed == 0 then
    ns.Say("RestedXP's Inventory Manager is already off; nothing to move")
    return
  end
  ns.RefreshBags()
  ns.Say(table.concat(changed, "; ") .. (off and (". " .. ns.Cmd("/reload")
    .. " so Baganator shows MeioBags' junk marks") or ""))
end
