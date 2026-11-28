-- Junk: grey items plus the ones put on the junk list, minus the keep list, never quest
-- items except leftovers of a quest handed in (Quest.lua). The key deletes one per press:
-- extra Soul Shards first (MeioShards, when loaded), else the junk stack that sells for
-- least, if that is at most MAX_VALUE, from a bag the waiting loot fits; with the loot window
-- open it then loots. Never in combat.
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
  if db.keep[itemID] then return false end
  if ns.IsLeftover(itemID, bag, slot) then return true end
  if ns.IsQuestItem(itemID, bag, slot) then return false end
  if db.junk[itemID] then return true end
  if quality == nil then quality = C_Item.GetItemQualityByID(itemID) end
  return quality == POOR
end

local function SellPrice(itemID) return select(11, C_Item.GetItemInfo(itemID)) end

------------------------------------------------------------------------------ room for loot
-- A slot freed in the reagent bag, a soul bag or a quiver only takes some items: deleting
-- junk there left players on other delete addons still unable to loot. So junk goes first
-- from a bag the waiting loot fits (normal bags when nothing is waiting).
local REAGENT_BAG = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
local ITEM_SLOT = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or 1
-- after a delete with loot waiting: loot once the freed slot shows, or after this long
local LOOT_WAIT = 1

local looting, lootAfter = false, nil

-- -> 0 for a bag that takes anything, its family bits, or "reagent" (Forever's reagent bag
-- slot can also hold a soul bag, which then reports its family)
local function Takes(bag)
  local _, family = C_Container.GetContainerNumFreeSlots(bag)
  if (family or 0) ~= 0 then return family end
  return bag == REAGENT_BAG and "reagent" or 0
end

local function Fits(itemID, takes)
  if takes == 0 then return true end
  if takes == "reagent" then return select(17, C_Item.GetItemInfo(itemID)) == true end
  return bit.band(C_Item.GetItemFamily(itemID) or 0, takes) ~= 0
end

-- -> item IDs in the open loot window
local function Waiting()
  local ids = {}
  if not looting then return ids end
  for i = 1, GetNumLootItems() do
    local link = GetLootSlotType(i) == ITEM_SLOT and GetLootSlotLink(i)
    local id = link and C_Item.GetItemInfoInstant(link)
    if id then ids[#ids + 1] = id end
  end
  return ids
end

local function Useful(bag, loot)
  local takes = Takes(bag)
  if #loot == 0 then return takes == 0 end
  for _, id in ipairs(loot) do
    if Fits(id, takes) then return true end
  end
  return false
end

local function LootAll()
  if not lootAfter then return end
  lootAfter = nil
  if not looting then return end
  for i = 1, GetNumLootItems() do LootSlot(i) end
end

ns.On("LOOT_OPENED", function() looting = true end)
ns.On("LOOT_CLOSED", function()
  looting = false
  lootAfter = nil
end)
ns.On("BAG_UPDATE_DELAYED", LootAll)

------------------------------------------------------------------------------ cheapest
-- -> { bag, slot, id, count, link, value } of the junk stack worth least in a bag where the
-- loot fits, and the cheapest in the other bags. Unknown prices (item info not cached) go last.
function ns.Cheapest(loot)
  loot = loot or {}
  local best, other
  for bag = 0, ns.LastBag() do
    local useful = Useful(bag, loot)
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and not info.isLocked and ns.IsJunk(info.itemID, info.quality, bag, slot) then
        local count = info.stackCount or 1
        local price = info.hasNoValue and 0 or SellPrice(info.itemID)
        local value = price and price * count or math.huge
        local cur
        if useful then cur = best else cur = other end
        if not cur or value < cur.value then
          cur = { bag = bag, slot = slot, id = info.itemID, count = count,
            link = info.hyperlink, value = value,
            quest = ns.db.leftover[info.itemID] ~= nil and ns.IsQuestItem(info.itemID) }
          if useful then best = cur else other = cur end
        end
      end
    end
  end
  return best, other
end

local function Money(copper) return GetMoneyString(copper, true) end

local function BagName(bag)
  local name = C_Container.GetBagName and C_Container.GetBagName(bag)
  return name and name ~= "" and name or ("bag " .. bag)
end

local mapRefused = false
ns.On("PLAYER_ENTERING_WORLD", function() mapRefused = false end)
local MAP_LINE = "the game doesn't let addons delete items in this dungeon: delete by hand, "
  .. "or after you leave"

function ns.DeleteJunk()
  if ns.InCombat() then
    ns.Say(ns.BAD .. "not in combat|r")
    return
  end
  if CursorHasItem() then
    ns.Say(ns.BAD .. "put down the item on your cursor first|r")
    return
  end
  local map = ns.MapRestricted()
  if map and mapRefused then
    ns.Say(MAP_LINE)
    return
  end
  local loot = Waiting()
  local j, other = ns.Cheapest(loot)
  if not j and other and #loot > 0 then
    ns.Say(("no junk where this loot fits: the only junk is in your %s"):format(
      BagName(other.bag)))
    return
  end
  j = j or other
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
    if map then
      mapRefused = true
      ns.Say(MAP_LINE)
    else
      ns.Say(ns.BAD .. "could not delete the junk item|r (try again in a moment)")
    end
    return
  end
  local worth = j.value > 0 and (", sold for " .. Money(j.value)) or ""
  local after = #loot > 0 and "; looting" or ""
  local why = j.quest and " (quest done)" or ""
  ns.Say(("deleted %s%s%s%s%s"):format(name, j.count > 1 and (" x" .. j.count) or "", why,
    worth, after))
  if #loot > 0 then
    lootAfter = true
    C_Timer.After(LOOT_WAIT, LootAll)
  end
end

-- -> what DeleteJunk would take now, nil when it would refuse (nothing cheap enough, price
-- unknown, no junk where the waiting loot fits)
function ns.NextDelete()
  local loot = Waiting()
  local j, other = ns.Cheapest(loot)
  if not j and #loot == 0 then j = other end
  if j and j.value <= ns.MAX_VALUE then return j end
end

function ns.Key()
  if ns.InCombat() then
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
  if ns.WindowRefresh then ns.WindowRefresh() end
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
  ns.RefreshBags()
  return on
end
