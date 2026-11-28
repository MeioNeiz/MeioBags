-- Preview: the item the delete key takes next, before the press. A red X in a Baganator
-- corner (top right; players move or drop it in Baganator's Corners settings), a tooltip
-- line on that item, and /meiobags next. Nothing while the key would trim a Soul Shard
-- instead (MeioShards over its cap; its overflow trim isn't predicted).
local _, ns = ...

local PASS = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local nextBag, nextSlot, nextID

local function ShardFirst()
  if not (ns.db.shards and ns.HasMeioShards()) then return false end
  local sk = _G.MeioShards
  local cap = sk.Cap and sk.Cap()
  return cap ~= nil and (sk.Count() or 0) > cap
end

function ns.Next()
  if not ns.db or ShardFirst() then return nil end
  return ns.NextDelete()
end

local function Find()
  local j = ns.Next()
  nextBag, nextSlot, nextID = j and j.bag, j and j.slot, j and j.id
end

function ns.IsNext(bag, slot) return bag ~= nil and bag == nextBag and slot == nextSlot end

-- list and option changes already refresh the bags: find first
local refresh = ns.RefreshBags
function ns.RefreshBags()
  Find()
  refresh()
end

-- bag and loot changes: refresh only when the target moved
local pending = false
local function Update()
  pending = false
  local bag, slot = nextBag, nextSlot
  Find()
  if bag ~= nextBag or slot ~= nextSlot then refresh() end
end
local function Soon()
  if pending then return end
  pending = true
  C_Timer.After(0.2, Update)
end
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "LOOT_OPENED", "LOOT_CLOSED",
    "GET_ITEM_INFO_RECEIVED", "PLAYER_ENTERING_WORLD" }) do
  ns.On(event, Soon)
end

------------------------------------------------------------------------------ Baganator
local api = _G.Baganator and _G.Baganator.API
if api and api.RegisterCornerWidget then
  api.RegisterCornerWidget("MeioBags: next delete", "meiobags_next", function(_, details)
    local loc = details.itemLocation
    return loc ~= nil and details.itemID == nextID and ns.IsNext(loc.bagID, loc.slotIndex)
  end, function(button)
    local x = button:CreateTexture(nil, "OVERLAY")
    x:SetTexture(PASS)
    x:SetSize(14, 14)
    x.padding = 0
    return x
  end, { corner = "top_right", priority = 1 }, true)
end

------------------------------------------------------------------------------ tooltip
function ns.NextLine()
  local key = GetBindingKey("MEIOBAGS_DELETE")
  return key and ("next for the delete key (" .. GetBindingText(key) .. ")")
    or ("next for " .. ns.SLASH .. " delete")
end

function ns.SayNext()
  if ShardFirst() then
    ns.Say("the key deletes an extra Soul Shard next (MeioShards)")
    return
  end
  local j = ns.Next()
  if not j then
    ns.Say("nothing: no junk the key would delete")
    return
  end
  local worth = j.value > 0 and (", sells for " .. GetMoneyString(j.value, true)) or ""
  ns.Say(("%s%s%s, %s"):format(j.link or ("item " .. j.id),
    j.count > 1 and (" x" .. j.count) or "", worth, ns.NextLine()))
end

-- "Inventory is full" while looting: name the key and what it would delete, once per loot
-- window (the error repeats on every click)
local told = false
ns.On("LOOT_OPENED", function() told = false end)
ns.On("UI_ERROR_MESSAGE", function(_, msg)
  if told or msg ~= ERR_INV_FULL or GetNumLootItems() == 0 or ns.InCombat() then return end
  local j = ns.Next()
  if not j then return end
  told = true
  local key = GetBindingKey("MEIOBAGS_DELETE")
  local how = key and ("press " .. ns.Cmd(GetBindingText(key)))
    or ("type " .. ns.Cmd(ns.SLASH .. " delete"))
  ns.Say(("bags full: %s to delete %s%s and loot"):format(how,
    j.link or ("item " .. j.id), j.count > 1 and (" x" .. j.count) or ""))
end)

hooksecurefunc(GameTooltip, "SetBagItem", function(tip, bag, slot)
  if not ns.IsNext(bag, slot) then return end
  tip:AddLine("|cffff8080MeioBags:|r " .. ns.NextLine(), 1, 1, 1)
  tip:Show()
end)
