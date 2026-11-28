-- Item grid shared by the bag and bank windows, laid out in sections (a grid of bags, with a
-- label above or not).
-- Taint: buttons are the game's ContainerFrameItemButtonTemplate, each parented to a frame
-- per bag whose ID is the bag, so Blizzard's click code reads the bag from GetParent():GetID()
-- and the slot from GetID(), never a field of ours. No Blizzard container code is hooked.
-- Buttons are made only out of combat; a bag that grows in combat fills in afterwards.
-- Saved view (Alts.lua cache: an alt, or the bank away from a banker): plain ItemButtons
-- from a pool of their own that only show the item and its tooltip; a click never touches
-- the live bags.
local _, ns = ...

local SIZE, GAP = 37, 4
local LABEL = 18
local PASS = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local REAGENT_BAG = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
local KEYRING = Enum and Enum.BagIndex and Enum.BagIndex.Keyring or -1
ns.REAGENT_BAG, ns.KEYRING = REAGENT_BAG, KEYRING
ns.SLOT_STEP = SIZE + GAP

function ns.BagSize(bag) return C_Container.GetContainerNumSlots(bag) or 0 end
function ns.BagFree(bag) return (C_Container.GetContainerNumFreeSlots(bag)) or 0 end

function ns.BagFamily(bag)
  local _, family = C_Container.GetContainerNumFreeSlots(bag)
  return family or 0
end

function ns.BagHasItems(bag)
  for slot = 1, ns.BagSize(bag) do
    if C_Container.GetContainerItemID(bag, slot) then return true end
  end
  return false
end

function ns.ContainerName(bag)
  if bag == KEYRING then return _G.KEYRING_LABEL or "Keyring" end
  local name = C_Container.GetBagName and C_Container.GetBagName(bag)
  if name and name ~= "" then return name end
  return bag == REAGENT_BAG and "Reagent bag" or ("Bag " .. bag)
end

-- a saved bag: { size, family, name, items = { [slot] = { id, n, link, q, b } } }
function ns.SavedFree(saved)
  local used = 0
  for _ in pairs(saved.items) do used = used + 1 end
  return saved.size - used
end

local Grid = {}
Grid.__index = Grid

-- frame: the window; pad: { left, right, top, bottom } around the sections
function ns.NewGrid(frame, pad)
  return setmetatable({ frame = frame, pad = pad, holders = {}, buttons = {}, static = {},
    labels = {}, shown = {} }, Grid)
end

-- bags: { [bagID] = saved bag } to show a saved copy, nil for the live bags
function Grid:SetSaved(bags)
  if bags == self.saved then return end
  self.saved = bags
  self.key = nil
end

function Grid:Size(bag)
  if self.saved then
    local s = self.saved[bag]
    return s and s.size or 0
  end
  return ns.BagSize(bag)
end

function Grid:Holder(bag)
  if not self.holders[bag] then
    local name = "MeioBagsBag" .. (bag < 0 and ("N" .. -bag) or bag)
    local h = CreateFrame("Frame", name, self.frame)
    h:SetID(bag)
    h:SetAllPoints(self.frame)
    self.holders[bag] = h
  end
  return self.holders[bag]
end

local function NextMark(b)
  local x = b:CreateTexture(nil, "OVERLAY", nil, 4)
  x:SetTexture(PASS)
  x:SetSize(14, 14)
  x:SetPoint("TOPRIGHT", -1, -1)
  x:Hide()
  b.meioNext = x
end

function Grid:LiveButton(bag, slot)
  self.buttons[bag] = self.buttons[bag] or {}
  local b = self.buttons[bag][slot]
  if b or InCombatLockdown() then return b end
  local h = self:Holder(bag)
  b = CreateFrame("ItemButton", h:GetName() .. "Item" .. slot, h,
    "ContainerFrameItemButtonTemplate")
  b:SetID(slot)
  NextMark(b)
  self.buttons[bag][slot] = b
  return b
end

local function StaticEnter(self)
  if not self.link then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink(self.link)
  GameTooltip:Show()
end

local function StaticClick(self)
  if self.link then HandleModifiedItemClick(self.link) end
end

-- not secure and not a container button: safe to make in combat
function Grid:StaticButton(bag, slot)
  self.static[bag] = self.static[bag] or {}
  local b = self.static[bag][slot]
  if b then return b end
  b = CreateFrame("ItemButton", nil, self.frame)
  b:SetSize(SIZE, SIZE)
  local coin = b:CreateTexture(nil, "OVERLAY", nil, 5)
  coin:SetAtlas("bags-junkcoin", true)
  coin:SetPoint("TOPLEFT", 1, 0)
  coin:Hide()
  b.JunkIcon = coin
  NextMark(b)
  -- else the item context result starts nil, which ItemButton reads as "doesn't match" and
  -- darkens the slot until the next item context change (bank, vendor)
  b:UpdateItemContextMatching()
  b:SetScript("OnEnter", StaticEnter)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnClick", StaticClick)
  self.static[bag][slot] = b
  return b
end

function Grid:Button(bag, slot)
  if self.saved then return self:StaticButton(bag, slot) end
  return self:LiveButton(bag, slot)
end

-- the button shown for bag, slot in the current view
function Grid:Get(bag, slot)
  local pool = self.saved and self.static or self.buttons
  return pool[bag] and pool[bag][slot]
end

-- -> the saved item in bag, slot as the fields Marks and search read
function Grid:SavedInfo(bag, slot)
  local s = self.saved and self.saved[bag]
  local it = s and s.items[slot]
  if not it then return nil end
  return { itemID = it.id, quality = it.q, hyperlink = it.link, stackCount = it.n,
    isBound = it.b, iconFileID = C_Item.GetItemIconByID(it.id) }
end

function Grid:Marks(b, bag, slot, info)
  local live = not self.saved
  local junk = info ~= nil and ns.IsJunk(info.itemID, info.quality, live and bag or nil,
    live and slot or nil)
  b.JunkIcon:SetShown(junk)
  b.meioNext:SetShown(live and info ~= nil and ns.IsNext(bag, slot))
  local ok = true
  if self.match then
    local it = ns.SearchItem(bag, slot, info, not live)
    ok = it ~= nil and self.match(it)
  end
  b:SetMatchesSearch(ok)
end

function Grid:PaintSaved(b, bag, slot)
  local info = self:SavedInfo(bag, slot)
  b.link = info and info.hyperlink
  b:SetItemButtonTexture(info and info.iconFileID)
  SetItemButtonQuality(b, info and info.quality, info and info.hyperlink, false,
    info and info.isBound)
  SetItemButtonCount(b, info and info.stackCount)
  self:Marks(b, bag, slot, info)
end

-- as Blizzard's own bag frame paints a slot, plus our marks
function Grid:Paint(b, bag, slot, tipOwner)
  if self.saved then return self:PaintSaved(b, bag, slot) end
  local info = C_Container.GetContainerItemInfo(bag, slot)
  local texture = info and info.iconFileID
  local quest = C_Container.GetContainerItemQuestInfo(bag, slot) or {}
  ClearItemButtonOverlay(b)
  b:SetHasItem(texture)
  b:SetItemButtonTexture(texture)
  b:SyncAppearanceWithHasItem()
  SetItemButtonQuality(b, info and info.quality, info and info.hyperlink, false,
    info and info.isBound)
  SetItemButtonCount(b, info and info.stackCount)
  SetItemButtonDesaturated(b, info and info.isLocked)
  b:UpdateQuestItem(quest.isQuestItem, quest.questID, quest.isActive)
  b:UpdateNewItem(info and info.quality)
  b:UpdateItemContextMatching()
  b:UpdateCooldown(texture)
  b:SetReadable(info and info.isReadable)
  b:CheckUpdateTooltip(tipOwner)
  self:Marks(b, bag, slot, info)
end

function Grid:Each(fn)
  for bag, size in pairs(self.shown) do
    for slot = 1, size do
      local b = self:Get(bag, slot)
      if b then fn(b, bag, slot) end
    end
  end
end

function Grid:PaintAll()
  local owner = GameTooltip:GetOwner()
  self:Each(function(b, bag, slot) self:Paint(b, bag, slot, owner) end)
end

function Grid:Info(bag, slot)
  if self.saved then return self:SavedInfo(bag, slot) end
  return C_Container.GetContainerItemInfo(bag, slot)
end

function Grid:MarkAll()
  self:Each(function(b, bag, slot) self:Marks(b, bag, slot, self:Info(bag, slot)) end)
end

function Grid:SetSearch(text)
  self.match = ns.ParseSearch(text)
  self:MarkAll()
end

function Grid:Lock(bag, slot)
  if self.saved then return end
  local b = bag and slot and self.buttons[bag] and self.buttons[bag][slot]
  if b and b:IsShown() then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    SetItemButtonDesaturated(b, info and info.isLocked)
  end
end

function Grid:Cooldowns()
  if self.saved then return end
  self:Each(function(b, bag, slot) b:UpdateCooldown(C_Container.HasContainerItem(bag, slot)) end)
end

function Grid:Label(i)
  if not self.labels[i] then
    self.labels[i] = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  end
  return self.labels[i]
end

function Grid:Signature(sections, cols)
  local parts = { cols, tostring(self.saved) }
  for _, s in ipairs(sections) do
    parts[#parts + 1] = s.label and "L" or "-"
    for _, bag in ipairs(s.bags or {}) do parts[#parts + 1] = bag .. ":" .. self:Size(bag) end
    for _, p in ipairs(s.slots or {}) do parts[#parts + 1] = p[1] .. "." .. p[2] end
  end
  return table.concat(parts, ",")
end

-- a section's slots in order: { bag, slot } pairs, from its bags or its own slot list
function Grid:Slots(s)
  if s.slots then return s.slots end
  local list = {}
  for _, bag in ipairs(s.bags) do
    for slot = 1, self:Size(bag) do list[#list + 1] = { bag, slot } end
  end
  return list
end

function Grid:SetLabels(sections)
  local i = 0
  for _, s in ipairs(sections) do
    if s.label then
      i = i + 1
      self:Label(i):SetText(s.label)
    end
  end
end

function Grid:Place(b, i, top, cols)
  local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", self.pad[1] + col * (SIZE + GAP),
    -(top + row * (SIZE + GAP)))
  b:Show()
end

-- sections: { { bags = { bagID, ... }, label = text or nil }, ... }
-- -> width, height the sections need; nil when nothing moved (only repainted)
function Grid:Layout(sections, cols)
  local key = self:Signature(sections, cols)
  if key == self.key and not self.waitCombat then
    self:PaintAll()
    self:SetLabels(sections)
    return
  end
  for _, pool in ipairs({ self.buttons, self.static }) do
    for _, list in pairs(pool) do
      for _, b in pairs(list) do b:Hide() end
    end
  end
  for _, l in pairs(self.labels) do l:Hide() end
  wipe(self.shown)
  local missing = false
  local y, n = self.pad[3], 0
  for _, s in ipairs(sections) do
    if s.label then
      n = n + 1
      local l = self:Label(n)
      l:ClearAllPoints()
      l:SetPoint("TOPLEFT", self.frame, "TOPLEFT", self.pad[1], -(y + 4))
      l:Show()
      y = y + LABEL
    end
    local slots = self:Slots(s)
    for i, p in ipairs(slots) do
      local bag, slot = p[1], p[2]
      self.shown[bag] = self.shown[bag] or self:Size(bag)
      local b = self:Button(bag, slot)
      if b then self:Place(b, i, y, cols) else missing = true end
    end
    y = y + math.max(1, math.ceil(#slots / cols)) * (SIZE + GAP)
  end
  self.waitCombat = missing
  self.key = not missing and key or nil
  self:PaintAll()
  self:SetLabels(sections)
  return self.pad[1] + self.pad[2] + cols * (SIZE + GAP) - GAP, y + self.pad[4]
end

function Grid:Relayout() self.key = nil end
