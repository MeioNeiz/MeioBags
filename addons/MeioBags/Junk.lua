-- Junk: grey items plus the ones put on the junk list, minus the keep list, never quest
-- items. The key deletes one per press: extra Soul Shards first (MeioShards, when loaded),
-- else the junk stack that sells for least, if that is at most MAX_VALUE. Never in combat.
-- DeleteCursorItem needs a hardware event, so only from the key, a click or a slash.
local _, ns = ...

local POOR = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
local QUEST_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
-- a stack worth more is worth a trip to a vendor; README and help promise this
ns.MAX_VALUE = 10000

function ns.IsQuestItem(itemID, bag, slot)
  if select(6, C_Item.GetItemInfoInstant(itemID)) == QUEST_CLASS then return true end
  local q = bag and C_Container.GetContainerItemQuestInfo
    and C_Container.GetContainerItemQuestInfo(bag, slot)
  return q ~= nil and (q.isQuestItem or q.questID ~= nil)
end

-- quality: from the bag slot when known, as item info may not be cached yet
function ns.IsJunk(itemID, quality, bag, slot)
  if not itemID then return false end
  local db = ns.db
  if db.keep[itemID] or ns.IsQuestItem(itemID, bag, slot) then return false end
  if db.junk[itemID] then return true end
  if quality == nil then quality = C_Item.GetItemQualityByID(itemID) end
  return quality == POOR
end

local function SellPrice(itemID) return select(11, C_Item.GetItemInfo(itemID)) end

-- -> { bag, slot, id, count, link, value } of the junk stack worth least, or nil. Unknown
-- prices (item info not cached) go last.
function ns.Cheapest()
  local best
  for bag = 0, ns.LastBag() do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and not info.isLocked and ns.IsJunk(info.itemID, info.quality, bag, slot) then
        local count = info.stackCount or 1
        local price = info.hasNoValue and 0 or SellPrice(info.itemID)
        local value = price and price * count or math.huge
        if not best or value < best.value then
          best = { bag = bag, slot = slot, id = info.itemID, count = count,
            link = info.hyperlink, value = value }
        end
      end
    end
  end
  return best
end

local function Money(copper) return GetMoneyString(copper, true) end

function ns.DeleteJunk()
  if InCombatLockdown() then
    ns.Say(ns.BAD .. "not in combat|r")
    return
  end
  if CursorHasItem() then
    ns.Say(ns.BAD .. "put down the item on your cursor first|r")
    return
  end
  local j = ns.Cheapest()
  if not j then
    ns.Say("no junk to delete")
    return
  end
  local name = j.link or ("item " .. j.id)
  if j.value == math.huge then
    C_Item.RequestLoadItemDataByID(j.id)
    ns.Say(name .. " is still loading; press again in a moment")
    return
  end
  if j.value > ns.MAX_VALUE then
    ns.Say(("%s sells for %s, over the %s limit: sell it instead"):format(name,
      Money(j.value), Money(ns.MAX_VALUE)))
    return
  end
  C_Container.PickupContainerItem(j.bag, j.slot)
  local kind, id = GetCursorInfo()
  if kind ~= "item" or id ~= j.id then
    ClearCursor()
    ns.Say(ns.BAD .. "could not pick up the junk item|r (try again in a moment)")
    return
  end
  DeleteCursorItem()
  -- refused: put it back rather than drop it in the next slot clicked
  if CursorHasItem() then
    ClearCursor()
    ns.Say(ns.BAD .. "could not delete the junk item|r (try again in a moment)")
    return
  end
  local worth = j.value > 0 and (", sold for " .. Money(j.value)) or ""
  ns.Say(("deleted %s%s%s"):format(name, j.count > 1 and (" x" .. j.count) or "", worth))
end

function ns.Key()
  if InCombatLockdown() then
    ns.Say(ns.BAD .. "not in combat|r")
    return
  end
  local sk = ns.db.shards and _G.MeioShards
  if sk and sk.Trim and sk.Trim(true) then return end
  ns.DeleteJunk()
end

------------------------------------------------------------------------------ Baganator
-- Baganator picks a newly registered junk plugin by itself unless the chosen one is still
-- registered (RestedXP's, until Takeover.lua turns its Inventory Manager off).
local function RefreshBags()
  local api = _G.Baganator and _G.Baganator.API
  if api and api.RequestItemButtonsRefresh then api.RequestItemButtonsRefresh() end
end
ns.RefreshBags = RefreshBags

local api = _G.Baganator and _G.Baganator.API
if api and api.RegisterJunkPlugin then
  api.RegisterJunkPlugin("MeioBags", "MeioBags", function(bag, slot, itemID)
    if not (ns.db and itemID) then return nil end
    local info = bag and slot and C_Container.GetContainerItemInfo(bag, slot)
    if not (info and info.itemID == itemID) then return ns.IsJunk(itemID) end
    return ns.IsJunk(itemID, info.quality, bag, slot)
  end)
end

-- "junk" or "keep": puts the item on that list, or takes it off when already there
function ns.Mark(list, itemID)
  local db = ns.db
  local other = list == "junk" and "keep" or "junk"
  local on = not db[list][itemID]
  db[list][itemID] = on or nil
  if on then db[other][itemID] = nil end
  RefreshBags()
  return on
end
