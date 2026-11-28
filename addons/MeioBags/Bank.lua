-- Bank window (opt-in): Forever's bank is C_Bank tabs, each one a bag (CharacterBankTab_1..
-- are bags 6..14; the account bank's tabs, 15..23, when the account bank can be viewed).
-- Normal bank bags share one grid and a soul bag or quiver in the bank gets its own labelled
-- row, or every bag gets its own row (bankbybag), or the normal bags' items go into
-- categories (categoryview wins over bankbybag). Same buttons as the bag window (Grid.lua):
-- Blizzard's right-click withdraws from here and deposits from the bags, into the bank type
-- Blizzard's bank frame has selected. Opens at the banker, beside Blizzard's bank and with
-- the bag window, when bankopen is on and Baganator isn't loaded (it opens its own bank).
-- Away from a banker, or for an alt, it shows the saved bank (Alts.lua), view only.
local _, ns = ...

local LEFT, RIGHT, TOP, BOTTOM = 14, 14, 64, 34
local HOME = { "TOPLEFT", "TOPLEFT", 40, -104 }
-- Blizzard's bank page tabs stick out right of its frame
local TAB_STRIP = 46
local BANK_TYPE = Enum and Enum.BankType or {}
local CHARACTER, ACCOUNT = BANK_TYPE.Character or 0, BANK_TYPE.Account or 2

local win, grid
local atBank, openedBags = false, false

local function Tabs(bankType)
  if not (C_Bank and C_Bank.FetchPurchasedBankTabData) then return {} end
  if bankType == ACCOUNT then
    local ok, can = pcall(C_Bank.CanViewBank, ACCOUNT)
    if not (ok and can) then return {} end
  end
  local ok, data = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
  return ok and type(data) == "table" and data or {}
end

-- the bag in a bank bag slot by its name; the first tab (the bank itself) by the tab's
local function TabName(tab, i)
  local name = C_Container.GetBagName and C_Container.GetBagName(tab.ID)
  if name and name ~= "" then return name end
  if tab.name and tab.name ~= "" then return tab.name end
  return i == 1 and (BANK or "Bank") or ("Bank tab " .. i)
end

local function Label(name, bag)
  return ("%s |cffffffff(%d free)|r"):format(name, ns.BagFree(bag))
end

-- -> sections, free and total slots in normal character bank bags
local function ByBag() return ns.db.bankbybag and not ns.db.categoryview end

local function Sections()
  local byBag = ByBag()
  local main, sections = {}, {}
  local free, total = 0, 0
  for i, tab in ipairs(Tabs(CHARACTER)) do
    local bag = tab.ID
    if bag and ns.BagSize(bag) > 0 then
      local special = ns.BagFamily(bag) ~= 0
      if not special then free, total = free + ns.BagFree(bag), total + ns.BagSize(bag) end
      if byBag or special then
        sections[#sections + 1] = { bags = { bag }, label = Label(TabName(tab, i), bag) }
      else
        main[#main + 1] = bag
      end
    end
  end
  if #main > 0 then table.insert(sections, 1, { bags = main }) end
  local account = ACCOUNT_BANK_PANEL_TITLE or "Warband Bank"
  for i, tab in ipairs(Tabs(ACCOUNT)) do
    if tab.ID and ns.BagSize(tab.ID) > 0 then
      local name = tab.name ~= "" and tab.name or ("tab " .. i)
      sections[#sections + 1] = { bags = { tab.ID },
        label = Label(account .. ": " .. name, tab.ID) }
    end
  end
  return sections, free, total
end

local function Columns() return math.max(6, math.min(30, ns.db.columns or 10)) end

-- -> { { bag, name } } of the bank's bags now (Alts.lua saves them)
function ns.BankBags(account)
  local out = {}
  for i, tab in ipairs(Tabs(account and ACCOUNT or CHARACTER)) do
    if tab.ID then
      local name = account and (tab.name ~= "" and tab.name or ("tab " .. i))
        or TabName(tab, i)
      out[#out + 1] = { bag = tab.ID, name = name }
    end
  end
  return out
end

-- the character the window shows from the saved copy (nil: live, at a banker)
local function SavedCharacter()
  if not ns.ViewKey and atBank then return nil end
  return ns.Character(ns.ViewKey or ns.MyKey()) or { name = UnitName("player") }
end

-- the saved character bank plus the saved account bank tabs, as one bag table for the grid;
-- the same table while neither copy changes, so the grid keeps its buttons
local merged = {}
local function SavedBank(c)
  local account = ns.db.account and ns.db.account.bags
  if merged.bank ~= c.bank or merged.account ~= account then
    local bags = {}
    for bag, s in pairs(c.bank) do bags[bag] = s end
    for bag, s in pairs(account or {}) do bags[bag] = s end
    merged = { bank = c.bank, account = account, bags = bags }
  end
  return merged.bags, account
end

local function SavedSections(c)
  local bags, account = SavedBank(c)
  local sections, free, total = ns.SavedSections(c.bank, ByBag())
  local title = ACCOUNT_BANK_PANEL_TITLE or "Warband Bank"
  local ids = {}
  for bag in pairs(account or {}) do ids[#ids + 1] = bag end
  table.sort(ids)
  for _, bag in ipairs(ids) do
    local s = account[bag]
    sections[#sections + 1] = { bags = { bag },
      label = ns.RowLabel(title .. ": " .. s.name, ns.SavedFree(s)) }
  end
  return bags, sections, free, total
end

-- -> what the view button switches to: one grid -> by bag -> categories -> one grid
local NEXT_VIEW = { grid = "By bag", bybag = "Categories", categories = "One grid" }
local function View()
  if ns.db.categoryview then return "categories" end
  return ns.db.bankbybag and "bybag" or "grid"
end

local function Layout()
  local c = SavedCharacter()
  local saved = c ~= nil
  local sections, free, total, bags
  if saved and c.bank then
    bags, sections, free, total = SavedSections(c)
  elseif saved then
    bags, sections, free, total = {}, {}, 0, 0
  else
    sections, free, total = Sections()
  end
  grid:SetSaved(bags)
  if ns.HoldCategories(grid) then return end
  local w, h = grid:Layout(ns.Categorise(grid, sections), Columns())
  if saved and not c.bank then
    win.empty:SetText(("No bank saved for %s yet: it is saved each time %s visits a banker.")
      :format(c.name, c.name))
    w, h = 400, TOP + 50 + BOTTOM
  end
  local empty = saved and not c.bank
  win.empty:SetShown(empty)
  if w then win:SetSize(w, h) end
  win.free:SetText(empty and "" or ns.FreeText(free, total, saved and c.bankAt))
  win.view:SetText(NEXT_VIEW[View()])
  ns.UpdateWho(win, ns.ViewKey and c and c.name)
  win.sort:SetShown(not saved)
end

local pending = false
local function Soon()
  if pending then return end
  pending = true
  C_Timer.After(0, function()
    pending = false
    if win and win:IsShown() then Layout() end
  end)
end

------------------------------------------------------------------------------ window
local function Sort()
  if InCombatLockdown() then
    ns.Say(ns.BAD .. "not in combat|r")
    return
  end
  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  if C_Container.SortBank then
    C_Container.SortBank(CHARACTER)
  elseif C_Container.SortBankBags then
    C_Container.SortBankBags()
  end
end

-- a saved position wins; else beside Blizzard's bank, unless that would cover the bag
-- window (narrow screens), then left of the bag window; else HOME
local function Position()
  if ns.db.bankwin then return ns.PositionWindow(win) end
  win:ClearAllPoints()
  local bags = ns.BagWindow()
  bags = bags and bags:IsShown() and bags:GetLeft() and bags
  local blizz = BankFrame and BankFrame:IsVisible() and BankFrame:GetRight() and BankFrame
  local s = win:GetEffectiveScale()
  local x = blizz and (blizz:GetRight() + TAB_STRIP) * blizz:GetEffectiveScale()
  if x and bags and x + win:GetWidth() * s > bags:GetLeft() * bags:GetEffectiveScale() then
    x = nil
  end
  if x then
    win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s,
      blizz:GetTop() * blizz:GetEffectiveScale() / s)
  elseif bags then
    win:SetPoint("TOPRIGHT", bags, "TOPLEFT", -8, 0)
  else
    local p = win.home
    win:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
end

local function Make()
  win = ns.MakeWindow("MeioBagsBankFrame", "MeioBags Bank", "bankwin", HOME,
    { "Sort bank", "The game's own bank sort, as the bank's button does." }, Sort)
  grid = ns.NewGrid(win, { LEFT, RIGHT, TOP, BOTTOM })
  win.grid = grid
  ns.gridWindows[#ns.gridWindows + 1] = win
  win.search:HookScript("OnTextChanged", function(self) grid:SetSearch(self:GetText()) end)
  local view = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  view:SetSize(84, 20)
  view:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -RIGHT + 4, 5)
  view:SetScript("OnClick", function()
    local now = View()
    if now == "grid" then
      ns.SetBankByBag(true)
    elseif now == "bybag" then
      ns.SetOption("bankbybag", false)
      ns.SetCategoryView(true)
    else
      ns.SetCategoryView(false)
    end
  end)
  view:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local now = View()
    GameTooltip:SetText(NEXT_VIEW[now])
    GameTooltip:AddLine(now == "grid" and "Every bank bag in its own row."
      or now == "bybag" and "Items grouped by category, in the bag window too."
      or "Normal bags in one grid; soul bags and quivers in their own rows.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  view:SetScript("OnLeave", GameTooltip_Hide)
  win.view = view
  win.relayout = Layout
  win:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    Layout()
  end)
  win:SetScript("OnHide", function()
    PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
    ns.ResetViewIfClosed()
  end)
  win.empty = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  win.empty:SetPoint("TOPLEFT", win, "TOPLEFT", LEFT + 4, -TOP - 4)
  win.empty:SetPoint("RIGHT", win, "RIGHT", -RIGHT - 4, 0)
  win.empty:SetJustifyH("LEFT")
  win.empty:Hide()
end

-- placed after the layout, which sets its width
local function Show()
  if not win then Make() end
  win:Show()
  Position()
end

function ns.AtBank() return atBank end
function ns.BankWindow() return win end

function ns.ToggleBank()
  if win and win:IsShown() then
    win:Hide()
  elseif atBank or ns.ViewKey or (ns.Character(ns.MyKey()) or {}).bank then
    Show()
  else
    ns.Say("no bank saved yet: visit a banker once, then the bank window opens anywhere")
  end
end

function ns.BankOpenActive() return ns.db.bankopen and not ns.BaganatorLoaded() end

function ns.BankViewChanged()
  if win and win:IsShown() then Layout() end
end

function ns.SetBankByBag(on)
  ns.SetOption("bankbybag", on)
  ns.BankViewChanged()
end

function ns.ResetBankWindow()
  ns.db.bankwin = nil
  if win and win:IsShown() then Position() end
end

function ns.BankSettingsChanged()
  if not win then return end
  win:SetScale(ns.db.scale or 1)
  grid:Relayout()
  if win:IsShown() then Layout() end
end

function ns.BankRefresh()
  if win and win:IsShown() then grid:MarkAll() end
end

------------------------------------------------------------------------------ events
ns.On("BANKFRAME_OPENED", function()
  atBank = true
  if win and win:IsShown() then Layout() end
  if not ns.BankOpenActive() then return end
  -- after Blizzard has placed its bank frame
  C_Timer.After(0, function()
    if not atBank then return end
    local bags = ns.BagWindow()
    if not (bags and bags:IsShown()) then
      ns.ShowWindow()
      openedBags = true
    end
    Show()
  end)
end)

ns.On("BANKFRAME_CLOSED", function()
  atBank = false
  if win then win:Hide() end
  if openedBags then
    openedBags = false
    local bags = ns.BagWindow()
    if bags then bags:Hide() end
  end
end)

local function IfShown(fn)
  return function(...)
    if win and win:IsShown() then fn(...) end
  end
end

ns.On("BAG_UPDATE_DELAYED", IfShown(Layout))
for _, event in ipairs({ "BAG_CONTAINER_UPDATE", "PLAYERBANKSLOTS_CHANGED",
    "BANK_TABS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" }) do
  ns.On(event, IfShown(Soon))
end
ns.On("PLAYER_REGEN_ENABLED", IfShown(function() if grid.waitCombat then Layout() end end))
