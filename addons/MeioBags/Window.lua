-- Own bag window (opt-in, Baganator untouched): every bag in one movable window, special bags
-- (soul bag, quiver, ammo pouch, reagent bag, keyring) in labelled rows with their own free
-- count, junk and next-delete marks, search, the game's sort. Buttons and taint: Grid.lua.
local _, ns = ...

local LEFT, RIGHT, TOP, BOTTOM = 14, 14, 64, 34
-- Blizzard's bags sit bottom right; Baganator's open there too
local HOME = { "RIGHT", "RIGHT", -380, 40 }

local win, grid
ns.gridWindows = {}

------------------------------------------------------------------------------ bags
local function IsSpecial(bag)
  return bag == ns.KEYRING or bag == ns.REAGENT_BAG or ns.BagFamily(bag) ~= 0
end

-- -> normal bag IDs, special bag IDs (a keyring only while it holds something)
local function Bags()
  local main, special = {}, {}
  for bag = 0, ns.LastBag() do
    if ns.BagSize(bag) > 0 then
      local list = IsSpecial(bag) and special or main
      list[#list + 1] = bag
    end
  end
  if ns.BagSize(ns.KEYRING) > 0 and ns.BagHasItems(ns.KEYRING) then
    special[#special + 1] = ns.KEYRING
  end
  return main, special
end

function ns.RowLabel(name, free) return ("%s |cffffffff(%d free)|r"):format(name, free) end

local function Sections()
  local main, special = Bags()
  local sections = { { bags = main } }
  for _, bag in ipairs(special) do
    sections[#sections + 1] = { bags = { bag },
      label = ns.RowLabel(ns.ContainerName(bag), ns.BagFree(bag)) }
  end
  return sections, main
end

-- saved bags (Alts.lua) -> sections as the live windows lay them out (normal bags in one
-- grid, special ones in labelled rows, or every bag its own row), free and total normal slots
function ns.SavedSections(bags, byBag)
  local ids = {}
  for bag in pairs(bags or {}) do ids[#ids + 1] = bag end
  table.sort(ids, function(a, b)
    if (a < 0) ~= (b < 0) then return b < 0 end
    return a < b
  end)
  local main, sections, free, total = {}, {}, 0, 0
  for _, bag in ipairs(ids) do
    local s = bags[bag]
    local special = s.family ~= 0 or bag == ns.REAGENT_BAG or bag == ns.KEYRING
    if not special then free, total = free + ns.SavedFree(s), total + s.size end
    if byBag or special then
      sections[#sections + 1] = { bags = { bag }, label = ns.RowLabel(s.name, ns.SavedFree(s)) }
    else
      main[#main + 1] = bag
    end
  end
  if #main > 0 or not byBag then table.insert(sections, 1, { bags = main }) end
  return sections, free, total
end

local function Columns() return math.max(6, math.min(30, ns.db.columns or 10)) end
ns.Columns = Columns

function ns.FreeText(free, total, saved)
  local text = ("%s%d of %d free|r"):format(free == 0 and total > 0 and ns.BAD or "|cffffffff",
    free, total)
  if saved then text = text .. ns.MUTED .. " - saved " .. ns.Ago(saved) .. "|r" end
  return text
end

local function UpdateFree(main)
  local alt = ns.ViewKey and ns.Character(ns.ViewKey)
  if alt then
    win.money:SetText(GetMoneyString(alt.money or 0, true))
    return
  end
  if not main then main = Bags() end
  local free, total = 0, 0
  for _, bag in ipairs(main) do
    free, total = free + ns.BagFree(bag), total + ns.BagSize(bag)
  end
  win.free:SetText(ns.FreeText(free, total))
  win.money:SetText(GetMoneyString(GetMoney(), true))
end

local function Layout()
  local alt = ns.ViewKey and ns.Character(ns.ViewKey)
  grid:SetSaved(alt and (alt.bags or {}) or nil)
  if ns.HoldCategories(grid) then return UpdateFree() end
  local sections, main
  if alt then
    local free, total
    sections, free, total = ns.SavedSections(alt.bags)
    win.free:SetText(ns.FreeText(free, total, alt.at))
  else
    sections, main = Sections()
  end
  local w, h = grid:Layout(ns.Categorise(grid, sections), Columns())
  if w then win:SetSize(w, h) end
  UpdateFree(main)
  ns.UpdateWho(win, alt and alt.name)
  win.view:SetText(ns.db.categoryview and "One grid" or "Categories")
end

------------------------------------------------------------------------------ window
local function Sort()
  if InCombatLockdown() then
    ns.Say(ns.BAD .. "not in combat|r")
    return
  end
  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  C_Container.SortBags()
end

-- a ButtonFrameTemplate window, movable by its title, Esc closes, position in db[posKey];
-- search box and sort button at the top
function ns.MakeWindow(name, title, posKey, home, sortTip, onSort)
  local f = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
  ButtonFrameTemplate_HidePortrait(f)
  if f.SetTitle then f:SetTitle(title) end
  f:SetToplevel(true)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  local bar = f.TitleContainer or f
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() f:StartMoving() end)
  bar:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, rel, x, y = f:GetPoint(1)
    ns.db[posKey] = { point, rel, x, y }
  end)
  tinsert(UISpecialFrames, name)

  local sort = CreateFrame("Button", nil, f)
  sort:SetSize(28, 26)
  sort:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -28)
  sort:SetNormalAtlas("bags-button-autosort-up")
  sort:SetPushedAtlas("bags-button-autosort-down")
  sort:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  sort:SetScript("OnClick", onSort)
  sort:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(sortTip[1])
    GameTooltip:AddLine(sortTip[2], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  sort:SetScript("OnLeave", GameTooltip_Hide)
  f.sort = sort

  local who = CreateFrame("Button", name .. "Who", f, "UIPanelButtonTemplate")
  who:SetSize(96, 22)
  who:SetPoint("RIGHT", sort, "LEFT", -6, 0)
  who:SetScript("OnClick", function(self) ns.PickCharacter(self) end)
  who:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Character")
    GameTooltip:AddLine("Show another character's bags and bank, as they were when that "
      .. "character last played (and last visited a banker).", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  who:SetScript("OnLeave", GameTooltip_Hide)
  who:Hide()
  f.who = who

  local search = CreateFrame("EditBox", name .. "Search", f, "SearchBoxTemplate")
  search:SetHeight(20)
  search:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT + 6, -32)
  search:SetPoint("RIGHT", sort, "LEFT", -8, 0)
  search.Instructions:SetText("Search: name, junk, quest, boe, >20")
  f.search = search
  f.title = title

  f.free = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.free:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", LEFT, 9)
  f.home = home
  f.posKey = posKey
  f:SetScale(ns.db.scale or 1)
  f:Hide()
  return f
end

function ns.PositionWindow(f)
  local p = ns.db[f.posKey] or f.home
  f:ClearAllPoints()
  f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

------------------------------------------------------------------------------ characters
-- ns.ViewKey: the character both windows show from the saved copy; nil = you, live (the
-- bank window still shows your saved bank away from a banker). Back to you when they close.
ns.ViewKey = nil

-- the character button (only with more than one character saved), title, sort, search
function ns.UpdateWho(f, altName)
  local many = #ns.Characters() > 1
  f.who:SetShown(many)
  f.who:SetText(altName or UnitName("player"))
  f.who:SetWidth(math.max(60, math.min(130, f.who:GetFontString():GetStringWidth() + 24)))
  f.sort:SetShown(altName == nil)
  f.search:SetPoint("RIGHT", many and f.who or f.sort, "LEFT", -8, 0)
  if f.SetTitle then f:SetTitle(altName and (f.title .. ": " .. altName) or f.title) end
end

function ns.SetView(key)
  if key == ns.MyKey() then key = nil end
  ns.ViewKey = key
  if win and win:IsShown() then Layout() end
  if ns.BankViewChanged then ns.BankViewChanged() end
end

function ns.ShowCharacter(key)
  ns.SetView(key)
  if not (win and win:IsShown()) then ns.ShowWindow() end
end

local function ResetView()
  local bank = ns.BankWindow and ns.BankWindow()
  if ns.ViewKey and not (win and win:IsShown()) and not (bank and bank:IsShown()) then
    ns.ViewKey = nil
  end
end
ns.ResetViewIfClosed = ResetView

function ns.PickCharacter(owner)
  local chars = ns.Characters()
  local current = ns.ViewKey or ns.MyKey()
  if not (MenuUtil and MenuUtil.CreateContextMenu) then
    for i, c in ipairs(chars) do
      if c.key == current then
        local nextOne = chars[i % #chars + 1]
        ns.SetView(nextOne.key)
        return
      end
    end
    return
  end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    for _, c in ipairs(chars) do
      local text = ns.ClassName(c.name, c.class)
      if not c.me then text = text .. ns.MUTED .. "  " .. ns.Ago(c.at) .. "|r" end
      root:CreateRadio(text, function() return c.key == current end,
        function() ns.SetView(c.key) end)
    end
  end)
end

local function Make()
  win = ns.MakeWindow("MeioBagsFrame", "MeioBags", "win", HOME,
    { "Sort bags", "The game's own sort, as the bag button does." }, Sort)
  -- kept for scripts and scenarios that type into it
  _G.MeioBagsSearch = win.search
  grid = ns.NewGrid(win, { LEFT, RIGHT, TOP, BOTTOM })
  win.grid = grid
  ns.gridWindows[#ns.gridWindows + 1] = win
  win.search:HookScript("OnTextChanged", function(self) grid:SetSearch(self:GetText()) end)
  win.view = ns.CategoryButton(win, RIGHT)
  win.money = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  win.money:SetPoint("RIGHT", win.view, "LEFT", -8, 1)
  win.relayout = Layout
  win:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    Layout()
  end)
  win:SetScript("OnHide", function()
    PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
    ResetView()
  end)
  ns.PositionWindow(win)
end

local function Open()
  if not win then Make() end
  return win
end

function ns.ToggleWindow()
  Open():SetShown(not win:IsShown())
end

function ns.ShowWindow() Open():Show() end
function ns.BagWindow() return win end

function ns.ResetWindow()
  ns.db.win = nil
  if win then ns.PositionWindow(win) end
  if ns.ResetBankWindow then ns.ResetBankWindow() end
end

function ns.WindowSettingsChanged()
  if win then
    win:SetScale(ns.db.scale or 1)
    grid:Relayout()
    if win:IsShown() then Layout() end
  end
  if ns.BankSettingsChanged then ns.BankSettingsChanged() end
end

-- marks only (junk lists, the next delete moved)
function ns.WindowRefresh()
  if win and win:IsShown() then grid:MarkAll() end
  if ns.BankRefresh then ns.BankRefresh() end
end

------------------------------------------------------------------------------ events
-- event -> fn(window, ...) for every shown window with a grid (bags, bank)
function ns.OnGrid(event, fn)
  ns.On(event, function(...)
    for _, f in ipairs(ns.gridWindows) do
      if f:IsShown() then fn(f, ...) end
    end
  end)
end

local function IfShown(fn)
  return function(...)
    if win and win:IsShown() then fn(...) end
  end
end

ns.On("BAG_UPDATE_DELAYED", IfShown(Layout))
ns.On("BAG_CONTAINER_UPDATE", IfShown(Layout))
ns.On("PLAYER_REGEN_ENABLED", IfShown(function() if grid.waitCombat then Layout() end end))
ns.On("PLAYER_MONEY", IfShown(function() UpdateFree() end))
ns.OnGrid("ITEM_LOCK_CHANGED", function(f, bag, slot) f.grid:Lock(bag, slot) end)
ns.OnGrid("BAG_UPDATE_COOLDOWN", function(f) f.grid:Cooldowns() end)
ns.OnGrid("QUEST_LOG_UPDATE", function(f) f.grid:PaintAll() end)
ns.OnGrid("BAG_NEW_ITEMS_UPDATED", function(f) f.grid:PaintAll() end)
local infoPending = false
ns.OnGrid("GET_ITEM_INFO_RECEIVED", function()
  if infoPending then return end
  infoPending = true
  C_Timer.After(0.2, function()
    infoPending = false
    for _, f in ipairs(ns.gridWindows) do
      if f:IsShown() and f.grid.match then f.grid:MarkAll() end
    end
  end)
end)

------------------------------------------------------------------------------ bag key
-- Opt-in: keys bound to the game's bag commands open this window instead, through override
-- bindings (the player's own bindings are never changed). Not while Baganator is loaded: it
-- owns those keys, and only one bag window may open on B.
local binder = CreateFrame("Frame")
local BAG_COMMANDS = { "OPENALLBAGS", "TOGGLEBACKPACK" }
local bound, bindWait = nil, false

function ns.BaganatorLoaded()
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Baganator") or false
end

function ns.BagKeyActive() return ns.db.bagkey and not ns.BaganatorLoaded() end

function ns.BindBagKey()
  if InCombatLockdown() then
    bindWait = true
    return
  end
  bindWait = false
  local keys = {}
  if ns.BagKeyActive() then
    for _, cmd in ipairs(BAG_COMMANDS) do
      for _, key in ipairs({ GetBindingKey(cmd) }) do keys[#keys + 1] = key end
    end
  end
  local sig = table.concat(keys, ",")
  if sig == bound then return end
  bound = sig
  ClearOverrideBindings(binder)
  for _, key in ipairs(keys) do SetOverrideBinding(binder, false, key, "MEIOBAGS_WINDOW") end
end

-- With the bag key on, places where the game opens its bags open this window too, and close it
-- again if they opened it. The game's bags still open there: hiding them would need a hook
-- on Blizzard's container frames (taint check in game first).
local AUTO = { MERCHANT_SHOW = "MERCHANT_CLOSED", MAIL_SHOW = "MAIL_CLOSED",
  TRADE_SHOW = "TRADE_CLOSED", AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED" }
local autoOpened
for show, close in pairs(AUTO) do
  ns.On(show, function()
    if not ns.BagKeyActive() or (win and win:IsShown()) then return end
    ns.ShowWindow()
    autoOpened = show
  end)
  ns.On(close, function()
    if autoOpened ~= show then return end
    autoOpened = nil
    if win then win:Hide() end
  end)
end

ns.On("PLAYER_LOGIN", ns.BindBagKey)
ns.On("UPDATE_BINDINGS", function()
  if ns.db and ns.db.bagkey then ns.BindBagKey() end
end)
ns.On("PLAYER_REGEN_ENABLED", function() if bindWait then ns.BindBagKey() end end)
