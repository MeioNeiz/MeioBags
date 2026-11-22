-- Opens bag items that hold loot (clams, sacks, unlocked lockboxes), one per click in the
-- world or key press: like RestedXP, it waits for a hardware event to use the item. Never at
-- a vendor, bank, mailbox, trade window or AH, where using an item sells, stores or attaches
-- it, nor while looting, casting, in combat or with no free bag slot for the loot.
local _, ns = ...

-- show event -> its close event
local BUSY = {
  MERCHANT_SHOW = "MERCHANT_CLOSED", BANKFRAME_OPENED = "BANKFRAME_CLOSED",
  MAIL_SHOW = "MAIL_CLOSED", TRADE_SHOW = "TRADE_CLOSED",
  AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED", GUILDBANKFRAME_OPENED = "GUILDBANKFRAME_CLOSED",
  LOOT_OPENED = "LOOT_CLOSED",
}
-- an item that failed to open (UI error right after) is left alone for the session
local FAIL_WINDOW = 1.5

local busy = {}
local failed = {}
local pending = false
local last

local function HasFreeSlot()
  for bag = 0, ns.LastBag() do
    local free, family = C_Container.GetContainerNumFreeSlots(bag)
    if (family or 0) == 0 and (free or 0) > 0 then return true end
  end
  return false
end

local function Locked(bag, slot)
  local data = C_TooltipInfo and C_TooltipInfo.GetBagItem
    and C_TooltipInfo.GetBagItem(bag, slot)
  for _, line in ipairs(data and data.lines or {}) do
    if line.leftText == LOCKED then return true end
  end
  return false
end

-- -> bag, slot, itemID of the next item to open, or nil
local function NextOpenable()
  if not HasFreeSlot() then return end
  for bag = 0, ns.LastBag() do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.hasLoot and not info.isLocked and not failed[info.itemID]
          and not Locked(bag, slot) then
        return bag, slot, info.itemID
      end
    end
  end
end
ns.NextOpenable = NextOpenable

local function CanOpen()
  if not (ns.db and ns.db.open) or next(busy) then return false end
  if InCombatLockdown() or UnitIsDeadOrGhost("player") then return false end
  if CursorHasItem() or SpellIsTargeting() then return false end
  if UnitCastingInfo("player") or UnitChannelInfo("player") then return false end
  return true
end

local function Check() pending = ns.db and ns.db.open and NextOpenable() ~= nil end

local function Try()
  if not (pending and CanOpen()) then return end
  local bag, slot, id = NextOpenable()
  pending = false
  if not bag then return end
  last = { id = id, at = GetTime() }
  C_Container.UseContainerItem(bag, slot)
end
ns.TryOpen = Try

for show, close in pairs(BUSY) do
  ns.On(show, function() busy[show] = true end)
  ns.On(close, function()
    busy[show] = nil
    Check()
  end)
end
ns.On("PLAYER_ENTERING_WORLD", function()
  wipe(busy)
  Check()
end)
ns.On("BAG_UPDATE_DELAYED", Check)
ns.On("PLAYER_REGEN_ENABLED", Check)
ns.On("UI_ERROR_MESSAGE", function()
  if last and GetTime() - last.at < FAIL_WINDOW then failed[last.id] = true end
  last = nil
end)

WorldFrame:HookScript("OnMouseDown", Try)

-- sees every key press without taking it from the game
local keys = CreateFrame("Frame", nil, UIParent)
keys:EnableKeyboard(true)
keys:SetPropagateKeyboardInput(true)
keys:SetScript("OnKeyDown", Try)
