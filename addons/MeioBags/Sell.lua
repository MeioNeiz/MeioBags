-- Sells the junk (Junk.lua's rules: greys plus the junk list, minus the keep list, never quest
-- items) when a vendor opens. Shift held while opening skips it. Blizzard's Sell All Junk, which
-- FlareUI's auto-sell uses, knows only greys: it misses the junk list and sells kept greys, so
-- FlareUI's is turned off while ours is on.
-- Our MERCHANT_SHOW is registered at file load, FlareUI's at its PLAYER_LOGIN, so ours runs first
-- and can still turn FlareUI's off for that visit.
local _, ns = ...

-- the server drops sales sent faster
local GAP = 0.2

local atVendor, ticker = false, nil

local function FlareTweaks()
  local f = _G.FlareUI
  return type(f) == "table" and f.db and f.db.profile and f.db.profile.tweaks or nil
end

function ns.TakeOverFlare()
  local t = FlareTweaks()
  if not (ns.db.sell and t and t.sellJunk) then return end
  t.sellJunk = false
  ns.Say("turned FlareUI's Sell Junk off: MeioBags sells your junk at vendors ("
    .. ns.Cmd(ns.SLASH .. " sell off") .. " to hand it back)")
end

-- -> { { bag, slot, id, count } ... } of the junk stacks a vendor buys
local function SellList()
  local list = {}
  for bag = 0, ns.LastBag() do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and not info.isLocked and not info.hasNoValue
          and ns.IsJunk(info.itemID, info.quality, bag, slot) then
        list[#list + 1] = { bag = bag, slot = slot, id = info.itemID,
          count = info.stackCount or 1 }
      end
    end
  end
  return list
end

local function Stop() if ticker then ticker:Cancel() ticker = nil end end

function ns.SellJunk()
  if ticker or not atVendor or InCombatLockdown() then return end
  local list = SellList()
  if #list == 0 then return end
  local i, sold, got = 0, 0, 0
  ticker = C_Timer.NewTicker(GAP, function()
    i = i + 1
    local e = list[i]
    if not (e and atVendor) then
      Stop()
      if sold > 0 then
        ns.Say(("sold %d junk item%s%s"):format(sold, ns.Plural(sold),
          got > 0 and (" for " .. GetMoneyString(got, true)) or ""))
      end
      return
    end
    -- the bags may have changed since the list was made
    if C_Container.GetContainerItemID(e.bag, e.slot) ~= e.id then return end
    C_Container.UseContainerItem(e.bag, e.slot)
    sold = sold + 1
    got = got + (select(11, C_Item.GetItemInfo(e.id)) or 0) * e.count
  end)
end

ns.On("MERCHANT_SHOW", function()
  atVendor = true
  if not ns.db.sell or IsShiftKeyDown() then return end
  ns.TakeOverFlare()
  ns.SellJunk()
end)
ns.On("MERCHANT_CLOSED", function() atVendor = false end)
ns.On("PLAYER_LOGIN", function() ns.TakeOverFlare() end)
