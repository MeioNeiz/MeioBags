-- Alts cache: each character's bags, bank and gear in MeioBagsDB.chars["Name-Realm"], so the
-- windows can show an alt (or the bank away from a banker) and item tooltips count across
-- characters. Saved after bag and gear changes (a second later), at logout, and while the
-- bank is open: bank bags can't be read away from a banker, so the last save before leaving
-- is the copy. Account bank tabs are shared: one copy in MeioBagsDB.account.
-- A saved bag: { size, family, name, items = { [slot] = { id, n, link, q, b } } }.
local _, ns = ...

-- head .. tabard; the ammo slot (0) only points at arrows that sit in the bags
local GEAR_FIRST, GEAR_LAST = 1, 19
local SAVE_DELAY = 1
local MAX_TIP_LINES = 4

local function Realm() return GetNormalizedRealmName() or "" end
function ns.MyKey() return UnitName("player") .. "-" .. Realm() end

local function Saved(info)
  return { id = info.itemID, n = info.stackCount or 1, link = info.hyperlink, q = info.quality,
    b = info.isBound or nil }
end

local function SaveBag(bag, name)
  local size = ns.BagSize(bag)
  if size == 0 then return nil end
  local items = {}
  for slot = 1, size do
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info and info.itemID then items[slot] = Saved(info) end
  end
  return { size = size, family = ns.BagFamily(bag), name = name or ns.ContainerName(bag),
    items = items }
end

-- itemID -> { bags, bank, gear } per character key, rebuilt after that character is saved
local index = {}

local function Me()
  local key = ns.MyKey()
  local c = ns.db.chars[key] or {}
  ns.db.chars[key] = c
  c.name, c.realm, c.realmKey = UnitName("player"), GetRealmName(), Realm()
  c.class, c.level = select(2, UnitClass("player")), UnitLevel("player")
  c.faction, c.money, c.at = UnitFactionGroup("player"), GetMoney(), time()
  index[key] = nil
  return c
end

local function SaveBags(c)
  local bags = {}
  for bag = 0, ns.LastBag() do bags[bag] = SaveBag(bag) end
  if ns.BagSize(ns.KEYRING) > 0 and ns.BagHasItems(ns.KEYRING) then
    bags[ns.KEYRING] = SaveBag(ns.KEYRING)
  end
  c.bags = bags
  local gear = {}
  for slot = GEAR_FIRST, GEAR_LAST do
    local link = GetInventoryItemLink("player", slot)
    if link then
      gear[slot] = { id = GetInventoryItemID("player", slot), n = 1, link = link,
        q = GetInventoryItemQuality("player", slot) }
    end
  end
  c.equipped = gear
end

local function SaveBank(c)
  local bank, any = {}, false
  for _, t in ipairs(ns.BankBags(false)) do
    bank[t.bag] = SaveBag(t.bag, t.name)
    any = any or bank[t.bag] ~= nil
  end
  -- left the bank already: keep the last copy
  if not any then return end
  c.bank, c.bankAt = bank, time()
  local account = {}
  for _, t in ipairs(ns.BankBags(true)) do account[t.bag] = SaveBag(t.bag, t.name) end
  if next(account) then
    ns.db.account = { bags = account, at = time() }
    index.account = nil
  end
end

function ns.SaveCharacter()
  if not ns.db then return end
  local c = Me()
  SaveBags(c)
  if ns.AtBank() then SaveBank(c) end
end

local pending = false
local function SaveSoon()
  if pending then return end
  pending = true
  C_Timer.After(SAVE_DELAY, function()
    pending = false
    ns.SaveCharacter()
  end)
end

------------------------------------------------------------------------------ reading
local function Count(into, field, bags)
  for _, s in pairs(bags or {}) do
    for _, it in pairs(s.items or {}) do
      local t = into[it.id]
      if not t then
        t = { bags = 0, bank = 0, gear = 0 }
        into[it.id] = t
      end
      t[field] = t[field] + (it.n or 1)
    end
  end
end

local function Index(key)
  if index[key] then return index[key] end
  local t = {}
  if key == "account" then
    Count(t, "bank", ns.db.account and ns.db.account.bags)
  else
    local c = ns.db.chars[key]
    Count(t, "bags", c.bags)
    Count(t, "bank", c.bank)
    Count(t, "gear", { { items = c.equipped } })
  end
  index[key] = t
  return t
end

-- this realm's characters, you first: { { key, name, realm, class, level, money, at,
-- bankAt, me } }
function ns.Characters()
  local out, mine, realm = {}, ns.MyKey(), Realm()
  for key, c in pairs(ns.db.chars) do
    if c.realmKey == realm then
      out[#out + 1] = { key = key, name = c.name, realm = c.realm, class = c.class,
        level = c.level, money = c.money, at = c.at, bankAt = c.bankAt, me = key == mine }
    end
  end
  table.sort(out, function(a, b)
    if a.me ~= b.me then return a.me end
    return a.name < b.name
  end)
  return out
end

function ns.Character(key) return ns.db.chars[key] end

-- -> characters holding itemID (you first, then most first): { { key, name, class, me, bags,
-- bank, gear, total } }, the account bank's count
function ns.ItemCounts(itemID)
  local out = {}
  for _, c in ipairs(ns.Characters()) do
    local t = Index(c.key)[itemID]
    if t then
      out[#out + 1] = { key = c.key, name = c.name, class = c.class, me = c.me, bags = t.bags,
        bank = t.bank, gear = t.gear, total = t.bags + t.bank + t.gear }
    end
  end
  table.sort(out, function(a, b)
    if a.me ~= b.me then return a.me end
    if a.total ~= b.total then return a.total > b.total end
    return a.name < b.name
  end)
  local account = Index("account")[itemID]
  return out, account and account.bank or 0
end

function ns.Forget(name)
  local gone = {}
  name = name:lower()
  for key, c in pairs(ns.db.chars) do
    if key ~= ns.MyKey() and (c.name or ""):lower() == name then
      ns.db.chars[key] = nil
      index[key] = nil
      gone[#gone + 1] = c.name
    end
  end
  if ns.ViewKey and ns.db.chars[ns.ViewKey] == nil then ns.SetView(nil) end
  return gone
end

-- "3 h ago" for a saved time()
function ns.Ago(at)
  if not at then return "never" end
  local s = math.max(0, time() - at)
  if s < 90 then return "just now" end
  if s < 5400 then return ("%d min ago"):format(s / 60 + 0.5) end
  if s < 129600 then return ("%d h ago"):format(s / 3600 + 0.5) end
  return ("%d days ago"):format(s / 86400 + 0.5)
end

function ns.ClassName(name, class)
  local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  return color and ("|c%s%s|r"):format(color.colorStr, name) or name
end

------------------------------------------------------------------------------ tooltip
function ns.AltTipsActive() return ns.db.alttips and not ns.BaganatorLoaded() end

local function Breakdown(t)
  local parts = {}
  if t.bags > 0 then parts[#parts + 1] = "bags " .. t.bags end
  if t.bank > 0 then parts[#parts + 1] = "bank " .. t.bank end
  if t.gear > 0 then parts[#parts + 1] = "worn " .. t.gear end
  return table.concat(parts, ", ")
end

-- one line per character holding it; only when somewhere other than your bags holds some.
-- Shift: where on each, the account bank, the total
local function AddCounts(tooltip, itemID)
  local list, account = ns.ItemCounts(itemID)
  local elsewhere = account > 0
  for _, t in ipairs(list) do
    if not t.me or t.bank > 0 then elsewhere = true end
  end
  if not elsewhere then return end
  local shift = IsShiftKeyDown()
  local total = account
  local W = HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
  for i, t in ipairs(list) do
    total = total + t.total
    if shift or i <= MAX_TIP_LINES then
      local right = tostring(t.total)
      if shift then right = right .. ns.MUTED .. " (" .. Breakdown(t) .. ")|r" end
      tooltip:AddDoubleLine(ns.ClassName(t.name, t.class), right, 1, 1, 1, W.r, W.g, W.b)
    end
  end
  local more = #list - MAX_TIP_LINES
  if not shift and more > 0 then
    tooltip:AddLine(("%sand %d more|r"):format(ns.MUTED, more))
  end
  if account > 0 then
    tooltip:AddDoubleLine(ACCOUNT_BANK_PANEL_TITLE or "Account bank", tostring(account),
      NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, W.r, W.g, W.b)
  end
  if shift then
    tooltip:AddDoubleLine("Total", tostring(total), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
      NORMAL_FONT_COLOR.b, W.r, W.g, W.b)
  elseif not tooltip.meioShiftHint then
    tooltip.meioShiftHint = true
    tooltip:AddLine(ns.MUTED .. "Shift: more|r")
  end
end

local TIPS = {}
local function OnItem(tooltip, data)
  if not (ns.db and TIPS[tooltip] and ns.AltTipsActive()) then return end
  local id = data and data.id
  if id == nil or (issecretvalue and issecretvalue(id)) or type(id) ~= "number" then return end
  AddCounts(tooltip, id)
end

local function HookTips()
  for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
    local tip = _G[name]
    if tip then
      TIPS[tip] = true
      tip:HookScript("OnTooltipCleared", function(self) self.meioShiftHint = nil end)
    end
  end
  local item = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and item then
    TooltipDataProcessor.AddTooltipPostCall(item, OnItem)
  end
end

------------------------------------------------------------------------------ events
ns.On("PLAYER_LOGIN", HookTips)
ns.On("PLAYER_ENTERING_WORLD", SaveSoon)
ns.On("BAG_UPDATE_DELAYED", SaveSoon)
ns.On("PLAYER_EQUIPMENT_CHANGED", SaveSoon)
ns.On("BANKFRAME_OPENED", SaveSoon)
-- the bank may still read at its close event; an empty read keeps the last copy
ns.On("BANKFRAME_CLOSED", function() SaveBank(Me()) end)
for _, event in ipairs({ "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED",
    "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" }) do
  ns.On(event, function() if ns.AtBank() then SaveSoon() end end)
end
ns.On("PLAYER_MONEY", function()
  local c = ns.db.chars[ns.MyKey()]
  if c then c.money = GetMoney() end
end)
ns.On("PLAYER_LOGOUT", ns.SaveCharacter)
