-- Options panel (Esc > Options > AddOns > MeioBags), slash commands and the public API
local _, ns = ...

local category
local settings = {}

local function Register(key, name, kind)
  local setting = Settings.RegisterAddOnSetting(category, "MEIOBAGS_" .. key:upper(), key,
    ns.db, kind or Settings.VarType.Boolean, name, ns.DEFAULTS[key])
  settings[key] = setting
  return setting
end

local function Checkbox(key, name, tip) Settings.CreateCheckbox(category, Register(key, name), tip) end

local function Slider(key, name, min, max, step, format, tip, changed)
  local setting = Register(key, name, Settings.VarType.Number)
  local options = Settings.CreateSliderOptions(min, max, step)
  if MinimalSliderWithSteppersMixin then
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
  end
  Settings.CreateSlider(category, setting, options, tip)
  if setting.SetValueChangedCallback then setting:SetValueChangedCallback(changed) end
end

local function Header(layout, title, tip)
  if CreateSettingsListSectionHeaderInitializer then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title, tip))
  end
end

local function RegisterSettings()
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  local layout
  category, layout = Settings.RegisterVerticalLayoutCategory("MeioBags")
  Header(layout, "Delete key", "One item per press, only when you press the key ("
    .. ns.KEY_PATH .. "), click the button below or type /meiobags delete. Junk: grey items, "
    .. "plus /meiobags junk <item> and quest leftovers, minus /meiobags keep <item>. Never in "
    .. "combat, never other quest items, never a stack that sells for more than " .. GetMoneyString(ns.MAX_VALUE, true)
    .. ". Junk goes first from a bag your loot can use (not the reagent bag, soul bag or "
    .. "quiver, unless the loot goes there); with the loot window open, it then loots. "
    .. "Baganator marks the same junk when its junk plugin is MeioBags.")
  if ns.HasMeioShards() then
    Checkbox("shards", "Shards first", "A press first deletes the Soul Shards MeioShards "
      .. "counts as extra (above its cap, or loose with a full soul bag). Only once none are "
      .. "left does it delete junk. /meiobags shards on||off does the same.")
  end
  Checkbox("quest", "Quest leftovers", "Quest items left over when you hand a quest in "
    .. "(extra Gnoll Paws) count as junk, unless a quest still in your log wants them. They "
    .. "sell for nothing, so the key deletes them first. Abandoned quests never count. "
    .. "/meiobags quest on||off does the same.")
  if CreateSettingsButtonInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer("Cheapest junk", "Delete now",
      function() ns.DeleteJunk() end, "Deletes the junk stack that sells for least (same as "
      .. "/meiobags delete)." .. (ns.HasMeioShards() and " Soul Shards are left alone." or ""),
      true))
  end
  Header(layout, "Vendors", "Opening a vendor sells all your junk (the same junk as the "
    .. "key, at any value). Hold Shift while opening to skip it.")
  Checkbox("sell", "Sell junk", "Sells your junk when you open a vendor. Turns FlareUI's Sell "
    .. "Junk off, which sells only grey items, kept ones too. /meiobags sell on||off does the "
    .. "same.")
  Header(layout, "Containers", "Clams, sacks and unlocked lockboxes.")
  Checkbox("open", "Open containers", "Bag items that hold loot are opened one at a time, on "
    .. "your next click in the world or key press. Never in combat, while looting, at a "
    .. "vendor, bank, mailbox, trade window or auction house, or with no free bag slot. "
    .. "/meiobags open on||off does the same.")
  Header(layout, "Bag window (new)", "MeioBags' own bag window: every bag in one window, "
    .. "soul bag, quiver, ammo pouch and reagent bag in their own rows with their free slots, "
    .. "junk marked with a coin and the next delete with a red X, search and the game's sort. "
    .. "Baganator is left as it is. Its own key: " .. ns.KEY_PATH .. ", or /meiobags bags. "
    .. "At a banker, a bank window in the same style (/meiobags bank).")
  local bagkey = Register("bagkey", "Open on bag key")
  Settings.CreateCheckbox(category, bagkey, "The keys you use for your bags (B) open this "
    .. "window instead of the game's bags, and it opens at vendors, mailboxes, trades and the "
    .. "auction house too. Off while Baganator is loaded: it keeps the bag key. "
    .. "/meiobags bagkey on||off does the same.")
  if bagkey.SetValueChangedCallback then bagkey:SetValueChangedCallback(ns.BindBagKey) end
  local cats = Register("categoryview", "Categories")
  Settings.CreateCheckbox(category, cats, "Items in the bag and bank windows grouped: new, "
    .. "quest leftovers, junk, gear sets, then by type (equipment, consumables, trade goods "
    .. "and so on), one empty slot to drop on. Your own categories from a search go first: "
    .. "/meiobags category. Soul bag, quiver and reagent bag keep their rows. "
    .. "/meiobags categories on||off does the same.")
  if cats.SetValueChangedCallback then cats:SetValueChangedCallback(ns.WindowSettingsChanged) end
  Slider("columns", "Columns", 6, 24, 1, function(v) return ("%d"):format(v) end,
    "How many slots side by side. /meiobags columns <6-24> does the same.",
    ns.WindowSettingsChanged)
  Slider("scale", "Size", 0.6, 1.5, 0.05, function(v) return ("%d%%"):format(v * 100 + 0.5) end,
    "How big the bag window is. /meiobags scale <60-150> does the same.",
    ns.WindowSettingsChanged)
  Checkbox("bankopen", "Open at the bank", "Visiting a banker opens MeioBags' bank window "
    .. "beside the game's bank, and the bag window with it. Right-click moves items between "
    .. "them. Off while Baganator is loaded: it opens its own bank. /meiobags bankopen on||off "
    .. "does the same.")
  local byBag = Register("bankbybag", "Bank by bag")
  Settings.CreateCheckbox(category, byBag, "Every bank bag in its own row. Off: normal bank "
    .. "bags in one grid, soul bags and quivers in their own rows. /meiobags bankbybag on||off "
    .. "does the same.")
  if byBag.SetValueChangedCallback then byBag:SetValueChangedCallback(ns.BankViewChanged) end
  Header(layout, "Alts", "Each character's bags, bank and gear are saved as they play (the "
    .. "bank each time they visit a banker). The bag window's character button shows an "
    .. "alt's bags and bank; /meiobags bank shows your saved bank anywhere.")
  Checkbox("alttips", "Tooltip counts","Item tooltips list how many each of your "
    .. "characters on this realm has, when anyone other than your bags holds some. Shift: "
    .. "bags, bank and worn for each, and the total. Off while Baganator is loaded. "
    .. "/meiobags alttips on||off does the same.")
  if CreateSettingsButtonInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer("Bag window", "Open",
      function() ns.ShowWindow() end, "Opens the bag window (same as /meiobags bags).", true))
    layout:AddInitializer(CreateSettingsButtonInitializer("Position", "Reset",
      function() ns.ResetWindow() end, "Puts the bag and bank windows back where they first "
      .. "opened (same as /meiobags reset).", true))
  end
  Settings.RegisterAddOnCategory(category)
end

ns.On("PLAYER_LOGIN", function()
  local ok, err = pcall(RegisterSettings)
  if not ok then geterrorhandler()(err) end
end)

------------------------------------------------------------------------------ slash
local function Help()
  ns.Say(ns.KeyName() .. " with one key; containers opened for you")
  ns.Line(ns.Cmd(ns.SLASH .. " delete") .. " - delete the cheapest junk item now, from a bag "
    .. "your loot can use, then loot (not in combat, not worth over "
    .. GetMoneyString(ns.MAX_VALUE, true) .. "; key: " .. ns.KEY_PATH .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " next") .. " - what the key deletes next (also a red X on it in "
    .. "Baganator, and a line in its tooltip)")
  ns.Line(ns.Cmd(ns.SLASH .. " junk <item>") .. " - always junk, whatever the quality; "
    .. "Shift-click the item into chat, or its item ID (again to undo)")
  ns.Line(ns.Cmd(ns.SLASH .. " keep <item>") .. " - never junk, even if grey or a quest "
    .. "leftover (again to undo)")
  ns.Line(ns.Cmd(ns.SLASH .. " list") .. " - the junk and keep lists")
  ns.Line(ns.Cmd(ns.SLASH .. " quest on||off") .. " - quest items left over from a quest you "
    .. "handed in are junk, unless a log quest wants them (now " .. ns.OnOff(ns.db.quest) .. ")")
  if ns.HasMeioShards() then
    ns.Line(ns.Cmd(ns.SLASH .. " shards on||off") .. " - the key deletes extra Soul Shards "
      .. "first (now " .. ns.OnOff(ns.db.shards) .. ")")
  end
  ns.Line(ns.Cmd(ns.SLASH .. " sell on||off") .. " - sell your junk when you open a vendor, "
    .. "Shift to skip (now " .. ns.OnOff(ns.db.sell) .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " open on||off") .. " - open containers on your next click or "
    .. "key press (now " .. ns.OnOff(ns.db.open) .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " bags") .. " - open or close MeioBags' own bag window (new; "
    .. "key: " .. ns.KEY_PATH .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " bagkey on||off") .. " - your bag key (B) opens that window "
    .. "instead of the game's bags, and it opens at vendors and mailboxes; not while Baganator "
    .. "is loaded (now " .. ns.OnOff(ns.db.bagkey)
    .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " categories on||off") .. " - group items in the bag and bank "
    .. "windows: new, junk, equipment, consumables and so on (now "
    .. ns.OnOff(ns.db.categoryview) .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " category <name> = <search>") .. " - your own category, ahead "
    .. "of the others: " .. ns.Cmd(ns.SLASH .. " category Cloth = cloth & !gear"))
  ns.Line(ns.Cmd(ns.SLASH .. " category") .. " - list the categories in order; "
    .. ns.Cmd(ns.SLASH .. " category remove <name>") .. " drops one of yours")
  ns.Line(ns.Cmd(ns.SLASH .. " bank") .. " - open or close MeioBags' bank window: live at a "
    .. "banker, the saved copy anywhere else (new)")
  ns.Line(ns.Cmd(ns.SLASH .. " bankopen on||off") .. " - a banker opens that window with the "
    .. "bag window, not while Baganator is loaded (now " .. ns.OnOff(ns.db.bankopen) .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " bankbybag on||off") .. " - every bank bag in its own row (now "
    .. ns.OnOff(ns.db.bankbybag) .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " alts [name]") .. " - your saved characters, or show one's bags "
    .. "and bank in the windows")
  ns.Line(ns.Cmd(ns.SLASH .. " alttips on||off") .. " - item tooltips count your other "
    .. "characters' items, not while Baganator is loaded (now " .. ns.OnOff(ns.db.alttips) .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " forget <name>") .. " - drop a deleted or renamed character's "
    .. "saved bags")
  ns.Line(ns.Cmd(ns.SLASH .. " columns <6-24>") .. " - slots side by side in the windows (now "
    .. ns.db.columns .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " scale <60-150>") .. " - window size in percent (now "
    .. math.floor(ns.db.scale * 100 + 0.5) .. ")")
  ns.Line(ns.Cmd(ns.SLASH .. " reset") .. " - put the bag and bank windows back")
  if ns.HasRXP() then
    ns.Line(ns.Cmd(ns.SLASH .. " rxp") .. " - turn RestedXP's Inventory Manager off and move "
      .. "its delete key and junk marks here (its vendor auto-sell stops too)")
  end
  ns.Line("Settings: " .. ns.SETTINGS_PATH .. " (" .. ns.Cmd(ns.SLASH .. " settings") .. ")")
end

local function OpenSettings()
  if category then Settings.OpenToCategory(category:GetID()) else Help() end
end

local function Name(id)
  return select(2, C_Item.GetItemInfo(id)) or ("item " .. id)
end

local function List()
  for _, list in ipairs({ "junk", "keep" }) do
    local names = {}
    for id in pairs(ns.db[list]) do names[#names + 1] = Name(id) end
    table.sort(names)
    ns.Say((list == "junk" and "always junk" or "never junk") .. ": "
      .. (#names > 0 and table.concat(names, " ") or ns.MUTED .. "none|r"))
  end
end

-- no name: the list; a name: that character's bags (and bank) in the windows
local function ShowAlts(name)
  local chars = ns.Characters()
  if name == "" then
    ns.Say(("%d character%s saved on this realm"):format(#chars, ns.Plural(#chars)))
    for _, c in ipairs(chars) do
      ns.Line(("%s %s- bags %s, bank %s|r"):format(ns.ClassName(c.name, c.class), ns.MUTED,
        c.me and "live" or ns.Ago(c.at), ns.Ago(c.bankAt)))
    end
    return
  end
  for _, c in ipairs(chars) do
    if c.name:lower() == name:lower() then
      ns.ShowCharacter(c.key)
      return
    end
  end
  ns.Say(('no saved character "%s": log in on it once'):format(name))
end

local function ViewOffNote()
  if ns.db.categoryview then return "" end
  return ns.MUTED .. " (shown once the view is on: " .. ns.SLASH .. " categories on)|r"
end

-- "" lists; "remove <name>"; "<name> = <search>" adds or changes one
local function CategoryCommand(arg)
  if arg == "" then
    local mine, defaults = {}, {}
    for _, c in ipairs(ns.db.categories) do
      mine[#mine + 1] = c.name .. ns.MUTED .. " (" .. c.search:gsub("|", "||") .. ")|r"
    end
    for _, c in ipairs(ns.CATEGORIES) do defaults[#defaults + 1] = c.name end
    ns.Say("categories in order, an item goes in the first that takes it" .. ViewOffNote())
    ns.Line("yours: " .. (#mine > 0 and table.concat(mine, ", ") or ns.MUTED .. "none|r"))
    ns.Line("then: " .. table.concat(defaults, ", "))
    return
  end
  local gone = arg:match("^[Rr][Ee][Mm][Oo][Vv][Ee]%s+(.+)$")
  if gone then
    local name = ns.RemoveCategory(strtrim(gone))
    ns.Say(name and ("category " .. name .. " removed")
      or ('no category of yours called "' .. gone .. '"'))
    return
  end
  local name, search = arg:match("^(.-)%s*=%s*(.*)$")
  name, search = strtrim(name or ""), strtrim(((search or ""):gsub("||", "|")))
  if name == "" or search == "" then
    ns.Say("category takes a name and a search: "
      .. ns.Cmd(ns.SLASH .. " category Cloth = cloth & !gear"))
    return
  end
  local new = ns.SetCategory(name, search)
  ns.Say(("category %s %s: %s"):format(name, new and "added" or "changed",
    search:gsub("|", "||")) .. ViewOffNote())
end

local function Set(key, value)
  if settings[key] then settings[key]:SetValue(value) else ns.db[key] = value end
end
ns.SetOption = Set

SLASH_MEIOBAGS1 = ns.SLASH
SlashCmdList.MEIOBAGS = function(msg)
  local word, arg = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
  word = word:lower()
  if word == "" or word == "settings" or word == "options" then
    OpenSettings()
  elseif word == "help" or word == "?" then
    Help()
  elseif word == "delete" then
    ns.DeleteJunk()
  elseif word == "next" then
    ns.SayNext()
  elseif word == "junk" or word == "keep" then
    local id = tonumber(arg) or tonumber(arg:match("item:(%d+)"))
    if not id then
      ns.Say(word .. " takes an item: Shift-click it into chat, or its item ID")
      return
    end
    if word == "junk" and not ns.db.junk[id] and ns.IsQuestItem(id) then
      ns.Say(Name(id) .. " is a quest item: never junk")
      return
    end
    local on = ns.Mark(word, id)
    local what = word == "junk" and "always junk" or "never junk"
    ns.Say(Name(id) .. (on and (" is now " .. what) or (" is no longer " .. what)))
  elseif word == "list" then
    List()
  elseif word == "bags" then
    ns.ToggleWindow()
  elseif word == "reset" then
    ns.ResetWindow()
    ns.Say("bag and bank windows put back")
  elseif word == "bank" then
    ns.ToggleBank()
  elseif word == "bankopen" and (arg == "on" or arg == "off") then
    Set("bankopen", arg == "on")
    local note = ""
    if arg == "on" and ns.BaganatorLoaded() then
      note = ns.MUTED .. " (Baganator is loaded and opens its own bank; " .. ns.SLASH
        .. " bank opens this one)|r"
    end
    ns.Say("bank window at a banker " .. ns.OnOff(arg == "on") .. note)
  elseif word == "bankbybag" and (arg == "on" or arg == "off") then
    ns.SetBankByBag(arg == "on")
    ns.Say("bank by bag " .. ns.OnOff(arg == "on"))
  elseif word == "bagkey" and (arg == "on" or arg == "off") then
    Set("bagkey", arg == "on")
    ns.BindBagKey()
    local note = ""
    if arg == "on" and ns.BaganatorLoaded() then
      note = ns.MUTED .. " (Baganator is loaded and keeps the bag key)|r"
    end
    ns.Say("bag key opens the bag window " .. ns.OnOff(arg == "on") .. note)
  elseif word == "categories" and (arg == "on" or arg == "off") then
    ns.SetCategoryView(arg == "on")
    ns.Say("categories in the bag and bank windows " .. ns.OnOff(arg == "on"))
  elseif word == "category" then
    CategoryCommand(arg)
  elseif word == "columns" or word == "scale" then
    local n = tonumber(arg)
    local lo, hi = 6, 24
    if word == "scale" then lo, hi = 60, 150 end
    if not n or n < lo or n > hi then
      ns.Say(word .. " takes a number from " .. lo .. " to " .. hi)
      return
    end
    n = math.floor(n + 0.5)
    Set(word, word == "scale" and n / 100 or n)
    ns.WindowSettingsChanged()
    ns.Say(("bag window %s %d%s"):format(word, n, word == "scale" and "%" or ""))
  elseif word == "alts" then
    ShowAlts(arg)
  elseif word == "alttips" and (arg == "on" or arg == "off") then
    Set("alttips", arg == "on")
    local note = ""
    if arg == "on" and ns.BaganatorLoaded() then
      note = ns.MUTED .. " (not while Baganator is loaded)|r"
    end
    ns.Say("counts in item tooltips " .. ns.OnOff(arg == "on") .. note)
  elseif word == "forget" then
    if arg == "" then
      ns.Say("forget takes a character name: " .. ns.Cmd(ns.SLASH .. " forget Name"))
      return
    end
    local gone = ns.Forget(arg)
    ns.Say(#gone > 0 and ("forgot " .. table.concat(gone, ", "))
      or ('no saved character "' .. arg .. '" (yours is kept)'))
  elseif word == "rxp" then
    ns.TakeOverRXP()
  elseif (word == "shards" or word == "open" or word == "sell" or word == "quest")
      and (arg == "on" or arg == "off") then
    Set(word, arg == "on")
    local what = { shards = "extra Soul Shards first ", open = "opening containers ",
      sell = "selling junk at vendors ", quest = "quest leftovers as junk " }
    ns.Say(what[word] .. ns.OnOff(arg == "on"))
    if word == "sell" then ns.TakeOverFlare() end
    if word == "quest" or word == "shards" then ns.RefreshBags() end
  else
    ns.Say('unknown command "' .. word .. '"')
    Help()
  end
end

function MeioBags_OnAddonCompartmentClick() OpenSettings() end

MeioBags = {
  Key = function() ns.Key() end,
  ToggleWindow = function() ns.ToggleWindow() end,
  DeleteJunk = function() ns.DeleteJunk() end,
  IsJunk = function(itemID) return ns.db ~= nil and ns.IsJunk(itemID) end,
  IsKept = function(itemID) return ns.db ~= nil and ns.db.keep[itemID] == true end,
  -- -> bag, slot of the item the key deletes next, or nil
  Next = function()
    local j = ns.Next()
    if j then return j.bag, j.slot end
  end,
  -- Saved characters (read only; tables are copies, safe to keep or change)
  -- -> this realm's characters, you first: { { key, name, realm, class, level, money, at,
  -- bankAt, me } }; at / bankAt: time() of the last bag / bank save
  Characters = function() return ns.db and ns.Characters() or {} end,
  -- place "bags" | "bank" | "equipped" | "account" (account bank tabs; key ignored)
  -- -> { { id, count, link, quality, bound, bag, slot } } or nil when never saved
  Items = function(key, place)
    if not ns.db then return nil end
    local source
    if place == "account" then
      source = ns.db.account and ns.db.account.bags
    else
      local c = ns.Character(key)
      source = c and (place == "equipped" and { [0] = { items = c.equipped } } or c[place])
    end
    if not source then return nil end
    local out = {}
    for bag, s in pairs(source) do
      for slot, it in pairs(s.items or {}) do
        out[#out + 1] = { id = it.id, count = it.n, link = it.link, quality = it.q,
          bound = it.b == true, bag = place ~= "equipped" and bag or nil, slot = slot }
      end
    end
    return out
  end,
  -- -> { { key, name, class, me, bags, bank, gear, total } } for characters holding it (you
  -- first), and the account bank's count
  ItemCounts = function(itemID)
    if not ns.db then return {}, 0 end
    local list, account = ns.ItemCounts(itemID)
    local out = {}
    for i, t in ipairs(list) do out[i] = CopyTable(t) end
    return out, account
  end,
  ShowCharacter = function(key) ns.ShowCharacter(key) end,
}
BINDING_HEADER_MEIOBAGS = "MeioBags"
BINDING_NAME_MEIOBAGS_DELETE = ns.KeyName()
BINDING_NAME_MEIOBAGS_WINDOW = "Open or close the bag window"
